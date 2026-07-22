import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'adapters/metadata_sync_adapters.dart';
import 'secure_sync_config.dart';
import 'sync_change_store.dart';
import 'sync_clock.dart';
import 'sync_models.dart';
import 'sync_protocol.dart';
import 'webdav_client.dart';

typedef WebDavClientFactory = WebDavClient Function(
  StoredSyncCredentials credentials,
);

class SyncEngine {
  SyncEngine({
    required SecureSyncConfigStore configStore,
    required SyncChangeStore changeStore,
    MetadataSyncAdapters? adapters,
    WebDavClientFactory? clientFactory,
  })  : _configStore = configStore,
        _changeStore = changeStore,
        _adapters = adapters ?? MetadataSyncAdapters(store: changeStore),
        _clientFactory = clientFactory ?? WebDavClient.standard;

  final SecureSyncConfigStore _configStore;
  final SyncChangeStore _changeStore;
  final MetadataSyncAdapters _adapters;
  final WebDavClientFactory _clientFactory;

  Future<WebDavSyncRunResult> run({
    void Function(WebDavSyncPhase phase)? onPhase,
  }) async {
    final credentials = await _configStore.readCredentials();
    if (credentials == null) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.authentication,
        'WebDAV is not configured or its secure password is unavailable.',
      );
    }
    final scope = await _configStore.readScope();
    final deviceId = await _deviceId();
    final clock = HybridLogicalClock(deviceId: deviceId);
    final latestLocalTimestamp = await _changeStore.latestTimestamp();
    if (latestLocalTimestamp != null) clock.observe(latestLocalTimestamp);
    final client = _clientFactory(credentials);

    onPhase?.call(WebDavSyncPhase.connecting);
    await client.ensureProtocolCollections(deviceId);
    _checkClockSkew(client.lastServerDate);
    await _ensureSpace(client);

    onPhase?.call(WebDavSyncPhase.scanningLocal);
    await _adapters.scan(scope, clock);

    onPhase?.call(WebDavSyncPhase.readingRemote);
    var downloaded = 0;
    var conflicts = 0;
    final deviceUris = await client.list(client.path(const ['devices']));
    final remoteDeviceIds = <String>{};
    for (final uri in deviceUris) {
      final segments =
          uri.pathSegments.where((part) => part.isNotEmpty).toList();
      final devicesIndex = segments.lastIndexOf('devices');
      if (devicesIndex < 0 || devicesIndex + 1 >= segments.length) continue;
      final remoteDeviceId = Uri.decodeComponent(segments[devicesIndex + 1]);
      if (remoteDeviceId == deviceId) continue;
      remoteDeviceIds.add(remoteDeviceId);
    }
    for (final remoteDeviceId in remoteDeviceIds) {
      final rawHead = await client.getText(
        client.path(['devices', remoteDeviceId, 'head.json']),
        allowNotFound: true,
      );
      if (rawHead == null) continue;
      late final RemoteDeviceHead head;
      try {
        head = RemoteDeviceHead.decode(rawHead);
      } catch (_) {
        throw const WebDavSyncFailure(
          WebDavSyncErrorCode.corruptRemoteData,
          'A remote device head is invalid.',
        );
      }
      if (head.deviceId != remoteDeviceId) {
        throw const WebDavSyncFailure(
          WebDavSyncErrorCode.corruptRemoteData,
          'A remote device head does not match its directory.',
        );
      }
      var cursor = await _changeStore.cursorFor(remoteDeviceId);
      while (cursor < head.latestSequence) {
        final sequence = cursor + 1;
        final rawBatch = await client.getText(
          client.path([
            'devices',
            remoteDeviceId,
            'changes',
            '${sequence.toString().padLeft(12, '0')}.json',
          ]),
        );
        late final SyncBatch batch;
        try {
          batch = SyncBatch.decode(rawBatch!);
        } catch (_) {
          throw const WebDavSyncFailure(
            WebDavSyncErrorCode.corruptRemoteData,
            'A remote metadata batch is missing or invalid.',
          );
        }
        if (batch.deviceId != remoteDeviceId || batch.sequence != sequence) {
          throw const WebDavSyncFailure(
            WebDavSyncErrorCode.corruptRemoteData,
            'A remote metadata batch has an invalid identity.',
          );
        }
        for (final operation in batch.operations) {
          clock.observe(HybridLogicalTimestamp.parse(operation.hlc));
        }
        onPhase?.call(WebDavSyncPhase.applyingRemote);
        final applied = await _changeStore.applyRemoteBatch(
          batch,
          applyWinner: _adapters.apply,
        );
        downloaded += applied;
        conflicts += batch.operations.length - applied;
        cursor = sequence;
      }
    }

    // Reconciliation after applying remote changes avoids turning those writes
    // back into local changes, while preserving locally newer winners as dirty.
    onPhase?.call(WebDavSyncPhase.scanningLocal);
    await _adapters.scan(scope, clock);

    onPhase?.call(WebDavSyncPhase.uploadingLocal);
    var uploaded = 0;
    while (true) {
      final published = await _publish(client, deviceId, clock);
      if (published == 0) break;
      uploaded += published;
    }
    onPhase?.call(WebDavSyncPhase.finishing);
    return WebDavSyncRunResult(
      uploaded: uploaded,
      downloaded: downloaded,
      skipped: conflicts,
      conflictsResolved: conflicts,
      completedAt: DateTime.now(),
    );
  }

  Future<void> _ensureSpace(WebDavClient client) async {
    final uri = client.path(const ['space.json']);
    final existing = await client.getText(uri, allowNotFound: true);
    if (existing == null) {
      try {
        await client.putText(
          uri,
          jsonEncode({
            'protocol': 'open-reading-webdav',
            'schema_version': 1,
            'space_id': const Uuid().v4(),
            'created_at': DateTime.now().toUtc().toIso8601String(),
            'encoding': 'json',
            'encryption': 'none',
          }),
          immutable: true,
        );
      } on WebDavSyncFailure catch (error) {
        if (error.code != WebDavSyncErrorCode.conflict) rethrow;
        final concurrentlyCreated = await client.getText(uri);
        _validateSpace(concurrentlyCreated!);
      }
      return;
    }
    _validateSpace(existing);
  }

  void _validateSpace(String existing) {
    try {
      final json = (jsonDecode(existing) as Map).cast<String, dynamic>();
      if (json['protocol'] != 'open-reading-webdav' ||
          json['schema_version'] != 1 ||
          json['encoding'] != 'json') {
        throw const FormatException();
      }
    } catch (_) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.serverIncompatible,
        'This remote folder contains an unsupported Open Reading sync space.',
      );
    }
  }

  Future<int> _publish(
    WebDavClient client,
    String deviceId,
    HybridLogicalClock clock,
  ) async {
    final pendingRaw = await _changeStore.getState('pending_batch');
    SyncBatch? batch;
    List<SyncRecord> records = const [];
    if (pendingRaw != null && pendingRaw.isNotEmpty) {
      batch = SyncBatch.decode(pendingRaw);
      final dirty = await _changeStore.dirtyRecords();
      final ids = batch.operations
          .map((operation) =>
              '${operation.dataset}\u0000${operation.recordId}\u0000${operation.hlc}')
          .toSet();
      records = dirty
          .where((record) => ids.contains(
              '${record.dataset}\u0000${record.recordId}\u0000${record.hlc}'))
          .toList(growable: false);
    } else {
      final dirty = await _changeStore.dirtyRecords();
      if (dirty.isEmpty) return 0;
      final sequence = int.tryParse(
            await _changeStore.getState('local_sequence') ?? '',
          ) ??
          0;
      final selected = <SyncRecord>[];
      for (final record in dirty) {
        final candidate = [...selected, record];
        try {
          SyncBatch.create(
            deviceId: deviceId,
            sequence: sequence + 1,
            createdHlc: clock.tick().toString(),
            operations: candidate.map((item) => item.toOperation()).toList(),
          );
          selected.add(record);
        } on ArgumentError {
          break;
        }
      }
      if (selected.isEmpty) {
        throw const WebDavSyncFailure(
          WebDavSyncErrorCode.invalidConfiguration,
          'A local metadata record exceeds the 1 MiB sync batch limit.',
        );
      }
      records = selected;
      batch = SyncBatch.create(
        deviceId: deviceId,
        sequence: sequence + 1,
        createdHlc: clock.tick().toString(),
        operations: selected.map((item) => item.toOperation()).toList(),
      );
      await _changeStore.setState('pending_batch', batch.encode());
    }

    final sequenceName = '${batch.sequence.toString().padLeft(12, '0')}.json';
    await client.putText(
      client.path(['devices', deviceId, 'changes', sequenceName]),
      batch.encode(),
      immutable: true,
    );
    await client.putText(
      client.path(['devices', deviceId, 'head.json']),
      RemoteDeviceHead(
        deviceId: deviceId,
        latestSequence: batch.sequence,
        latestHlc: batch.createdHlc,
        updatedAt: DateTime.now().toUtc(),
      ).encode(),
    );
    await _changeStore.markUploaded(records);
    await _changeStore.setState('local_sequence', '${batch.sequence}');
    await _changeStore.setState('pending_batch', '');
    return records.length;
  }

  Future<String> _deviceId() async {
    final existing = await _changeStore.getState('device_id');
    if (existing != null && existing.isNotEmpty) return existing;
    final created = const Uuid().v4();
    await _changeStore.setState('device_id', created);
    return created;
  }

  void _checkClockSkew(DateTime? serverDate) {
    if (serverDate == null) return;
    final skew = DateTime.now().toUtc().difference(serverDate).abs();
    if (skew > const Duration(hours: 24)) {
      throw const WebDavSyncFailure(
        WebDavSyncErrorCode.clockSkew,
        'The device clock differs from the WebDAV server by more than 24 hours.',
      );
    }
  }
}
