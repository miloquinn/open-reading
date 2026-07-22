import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'sync_clock.dart';
import 'sync_models.dart';

class SyncOperation {
  const SyncOperation({
    required this.dataset,
    required this.recordId,
    required this.entityKey,
    required this.hlc,
    required this.deleted,
    this.payload,
  });

  final String dataset;
  final String recordId;
  final String entityKey;
  final String hlc;
  final bool deleted;
  final Map<String, dynamic>? payload;

  Map<String, Object?> toJson() => {
    'dataset': dataset,
    'record_id': recordId,
    'entity_key': entityKey,
    'hlc': hlc,
    'deleted': deleted,
    'payload': payload,
  };

  factory SyncOperation.fromJson(Map<String, dynamic> json) => SyncOperation(
    dataset: json['dataset'] as String,
    recordId: json['record_id'] as String,
    entityKey: json['entity_key'] as String,
    hlc: json['hlc'] as String,
    deleted: json['deleted'] as bool? ?? false,
    payload: (json['payload'] as Map?)?.cast<String, dynamic>(),
  );
}

class SyncBatch {
  const SyncBatch({
    required this.deviceId,
    required this.sequence,
    required this.createdHlc,
    required this.operations,
    required this.sha256,
  });

  static const schemaVersion = 1;
  static const maxOperations = 500;
  static const maxEncodedBytes = 1024 * 1024;

  final String deviceId;
  final int sequence;
  final String createdHlc;
  final List<SyncOperation> operations;
  final String sha256;

  factory SyncBatch.create({
    required String deviceId,
    required int sequence,
    required String createdHlc,
    required List<SyncOperation> operations,
  }) {
    if (operations.isEmpty || operations.length > maxOperations) {
      throw ArgumentError('A batch must contain 1-$maxOperations operations');
    }
    final payload = _unsignedJson(deviceId, sequence, createdHlc, operations);
    final checksum = sha256OfCanonicalJson(payload);
    final batch = SyncBatch(
      deviceId: deviceId,
      sequence: sequence,
      createdHlc: createdHlc,
      operations: List.unmodifiable(operations),
      sha256: checksum,
    );
    if (utf8.encode(batch.encode()).length > maxEncodedBytes) {
      throw ArgumentError('Encoded batch exceeds 1 MiB');
    }
    return batch;
  }

  factory SyncBatch.decode(String raw) {
    final json = jsonDecode(raw);
    if (json is! Map<String, dynamic>) {
      throw const FormatException('Batch must be a JSON object');
    }
    if (json['schema_version'] != schemaVersion) {
      throw const FormatException('Unsupported batch schema');
    }
    final operations = (json['operations'] as List)
        .map((item) => SyncOperation.fromJson((item as Map).cast()))
        .toList(growable: false);
    if (operations.isEmpty || operations.length > maxOperations) {
      throw const FormatException('Invalid operation count');
    }
    final deviceId = json['device_id'] as String;
    final sequence = json['sequence'] as int;
    final createdHlc = json['created_hlc'] as String;
    HybridLogicalTimestamp.parse(createdHlc);
    for (final operation in operations) {
      HybridLogicalTimestamp.parse(operation.hlc);
    }
    final expected = sha256OfCanonicalJson(
      _unsignedJson(deviceId, sequence, createdHlc, operations),
    );
    if (json['sha256'] != expected) {
      throw const FormatException('Batch checksum mismatch');
    }
    return SyncBatch(
      deviceId: deviceId,
      sequence: sequence,
      createdHlc: createdHlc,
      operations: operations,
      sha256: expected,
    );
  }

  String encode() => jsonEncode({
    ..._unsignedJson(deviceId, sequence, createdHlc, operations),
    'sha256': sha256,
  });

  static Map<String, Object?> _unsignedJson(
    String deviceId,
    int sequence,
    String createdHlc,
    List<SyncOperation> operations,
  ) => {
    'schema_version': schemaVersion,
    'device_id': deviceId,
    'sequence': sequence,
    'created_hlc': createdHlc,
    'operations': operations.map((operation) => operation.toJson()).toList(),
  };
}

class RemoteDeviceHead {
  const RemoteDeviceHead({
    required this.deviceId,
    required this.latestSequence,
    required this.latestHlc,
    required this.updatedAt,
  });

  final String deviceId;
  final int latestSequence;
  final String latestHlc;
  final DateTime updatedAt;

  Map<String, Object?> toJson() => {
    'device_id': deviceId,
    'latest_sequence': latestSequence,
    'latest_hlc': latestHlc,
    'updated_at': updatedAt.toUtc().toIso8601String(),
  };

  factory RemoteDeviceHead.decode(String raw) {
    final json = (jsonDecode(raw) as Map).cast<String, dynamic>();
    return RemoteDeviceHead(
      deviceId: json['device_id'] as String,
      latestSequence: json['latest_sequence'] as int,
      latestHlc: json['latest_hlc'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String).toUtc(),
    );
  }

  String encode() => jsonEncode(toJson());
}

String sha256OfCanonicalJson(Object? value) =>
    sha256.convert(utf8.encode(_canonicalJson(value))).toString();

String _canonicalJson(Object? value) {
  if (value == null || value is bool || value is num || value is String) {
    return jsonEncode(value);
  }
  if (value is List) {
    return '[${value.map(_canonicalJson).join(',')}]';
  }
  if (value is Map) {
    final entries =
        value.entries
            .map((entry) => MapEntry(entry.key.toString(), entry.value))
            .toList()
          ..sort((a, b) => a.key.compareTo(b.key));
    return '{${entries.map((entry) => '${jsonEncode(entry.key)}:${_canonicalJson(entry.value)}').join(',')}}';
  }
  throw ArgumentError('Unsupported canonical JSON value: ${value.runtimeType}');
}

WebDavSyncFailure corruptBatchFailure(Object error) => WebDavSyncFailure(
  WebDavSyncErrorCode.corruptRemoteData,
  'A remote metadata batch is invalid and was not applied.',
);
