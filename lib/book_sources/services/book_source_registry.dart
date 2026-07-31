import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';
import 'book_source_client.dart';
import '../../services/core/app_settings_service.dart';

class BookSourceRegistry {
  static const String _storageKey = 'open_reading_book_sources_v1';
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();
  static Future<void> _mutationTail = Future<void>.value();

  Stream<void> get changes => _changesController.stream;

  Future<List<RegisteredBookSource>> load() async {
    return _load(filterUnverified: true);
  }

  Future<List<RegisteredBookSource>> _load({
    required bool filterUnverified,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final sources = <RegisteredBookSource>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        try {
          sources.add(
            RegisteredBookSource.fromJson(
              item.map((key, value) => MapEntry('$key', value)),
            ),
          );
        } catch (_) {
          // Skip a damaged entry instead of making the whole registry unusable.
        }
      }
      sources.sort((a, b) => a.name.compareTo(b.name));
      if (!filterUnverified) return sources;
      return sources
          .where(
            (source) =>
                source.sourceProtocol == BookSourceProtocolKind.orsp ||
                (source.capabilities.isNotEmpty &&
                    source.sourceConfig?['_openReadingReadingChainVerifiedAt']
                        is String),
          )
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  /// Returns sources that may participate in runtime requests right now.
  /// Compatible sources stay stored while the global advanced feature is off.
  Future<List<RegisteredBookSource>> loadRunnable() async {
    final preferences = await SharedPreferences.getInstance();
    final additionalEnabled =
        preferences.getBool(additionalSourceProtocolsPreferenceKey) ?? false;
    final sources = await load();
    if (additionalEnabled) return sources;
    return sources
        .where((source) => source.sourceProtocol == BookSourceProtocolKind.orsp)
        .toList(growable: false);
  }

  Future<List<RegisteredBookSource>> upsert(RegisteredBookSource source) async {
    return _mutate(() async {
      final sources = (await _load(filterUnverified: false)).toList();
      final index = sources.indexWhere((item) => item.id == source.id);
      if (index >= 0) {
        final previous = sources[index];
        // 防止书源 id 劫持：清单 id 由服务端自报，若同 id 的源来自
        // 不同域名，则拒绝静默覆盖已注册源的 API 地址。用户如确要
        // 更换域名，需先删除旧源再添加。
        final sameOrigin =
            previous.manifestUrl.host == source.manifestUrl.host &&
            previous.apiBaseUrl.host == source.apiBaseUrl.host;
        if (!sameOrigin) {
          throw BookSourceProtocolException(
            'A source with id "${source.id}" is already registered from '
            '${previous.manifestUrl.host}. Remove it first before adding a '
            'source with the same id from a different host.',
          );
        }
        sources[index] = RegisteredBookSource(
          id: source.id,
          name: source.name,
          description: source.description,
          manifestUrl: source.manifestUrl,
          apiBaseUrl: source.apiBaseUrl,
          iconUrl: source.iconUrl,
          websiteUrl: source.websiteUrl,
          operatorName: source.operatorName,
          contactUrl: source.contactUrl,
          contentLicense: source.contentLicense,
          rightsStatement: source.rightsStatement,
          protocolVersion: source.protocolVersion,
          languages: source.languages,
          capabilities: source.capabilities,
          maxCatalogPageSize: source.maxCatalogPageSize,
          enabled: previous.enabled,
          addedAt: previous.addedAt,
          sourceProtocol: source.sourceProtocol,
          sourceConfig: source.sourceConfig,
        );
      } else {
        sources.add(source);
      }
      await _save(sources);
      _changesController.add(null);
      return load();
    });
  }

  /// Adds or refreshes a bounded import batch in one serialized write.
  /// Existing entries keep their local enabled state and original add time.
  Future<List<RegisteredBookSource>> upsertAll(
    Iterable<RegisteredBookSource> imported,
  ) async {
    return _mutate(() async {
      final sources = (await _load(filterUnverified: false)).toList();
      final indexes = <String, int>{
        for (var index = 0; index < sources.length; index++)
          sources[index].id: index,
      };
      for (final source in imported) {
        final index = indexes[source.id];
        if (index == null) {
          indexes[source.id] = sources.length;
          sources.add(source);
          continue;
        }
        final previous = sources[index];
        final sameOrigin =
            previous.manifestUrl.host == source.manifestUrl.host &&
            previous.apiBaseUrl.host == source.apiBaseUrl.host &&
            previous.sourceProtocol == source.sourceProtocol;
        if (!sameOrigin) {
          throw BookSourceProtocolException(
            'A source with id "${source.id}" is already registered from a '
            'different origin or protocol.',
          );
        }
        sources[index] = RegisteredBookSource(
          id: source.id,
          name: source.name,
          description: source.description,
          manifestUrl: source.manifestUrl,
          apiBaseUrl: source.apiBaseUrl,
          iconUrl: source.iconUrl,
          websiteUrl: source.websiteUrl,
          operatorName: source.operatorName,
          contactUrl: source.contactUrl,
          contentLicense: source.contentLicense,
          rightsStatement: source.rightsStatement,
          protocolVersion: source.protocolVersion,
          languages: source.languages,
          capabilities: source.capabilities,
          maxCatalogPageSize: source.maxCatalogPageSize,
          enabled: source.enabled && source.capabilities.isNotEmpty,
          addedAt: previous.addedAt,
          sourceProtocol: source.sourceProtocol,
          sourceConfig: source.sourceConfig,
        );
      }
      await _save(sources);
      _changesController.add(null);
      return load();
    });
  }

  Future<List<RegisteredBookSource>> setEnabled(String id, bool enabled) async {
    return _mutate(() async {
      final sources = (await _load(filterUnverified: false))
          .map((source) {
            if (source.id != id) return source;
            if (enabled && source.capabilities.isEmpty) {
              throw const BookSourceProtocolException(
                'This source cannot be enabled because its rules are unsupported.',
              );
            }
            return source.copyWith(enabled: enabled);
          })
          .toList(growable: false);
      await _save(sources);
      _changesController.add(null);
      return load();
    });
  }

  /// Re-fetches a saved source's manifest while retaining local user choices.
  /// A manifest is not allowed to change the registered source identity.
  Future<List<RegisteredBookSource>> refresh(
    RegisteredBookSource source,
    BookSourceClient client,
  ) async {
    final discovered = await client.discover(source.manifestUrl.toString());
    final refreshed = RegisteredBookSource.fromManifest(
      manifest: discovered.manifest,
      manifestUrl: discovered.manifestUrl,
    );
    if (refreshed.id != source.id) {
      throw const BookSourceProtocolException(
        'The refreshed manifest changed the source ID. Remove the old source before adding it again.',
      );
    }
    return upsert(refreshed);
  }

  Future<List<RegisteredBookSource>> remove(String id) async {
    return _mutate(() async {
      final sources = (await _load(
        filterUnverified: false,
      )).where((source) => source.id != id).toList();
      await _save(sources);
      _changesController.add(null);
      return load();
    });
  }

  Future<List<RegisteredBookSource>> removeAll(Iterable<String> ids) async {
    final removed = ids.toSet();
    return _mutate(() async {
      final sources = (await _load(filterUnverified: false))
          .where((source) => !removed.contains(source.id))
          .toList(growable: false);
      await _save(sources);
      _changesController.add(null);
      return load();
    });
  }

  Future<List<RegisteredBookSource>> setEnabledAll(
    Iterable<String> ids,
    bool enabled,
  ) async {
    final selected = ids.toSet();
    return _mutate(() async {
      final sources = (await _load(filterUnverified: false))
          .map((source) {
            if (!selected.contains(source.id)) return source;
            final canEnable = source.capabilities.isNotEmpty;
            return source.copyWith(enabled: enabled && canEnable);
          })
          .toList(growable: false);
      await _save(sources);
      _changesController.add(null);
      return load();
    });
  }

  /// Applies an exact record-level winner received from the user's sync space.
  ///
  /// Unlike manifest refresh, sync must preserve the remote device's enabled
  /// state and added time because those fields are part of the synced record.
  Future<List<RegisteredBookSource>> applySynced(
    RegisteredBookSource source,
  ) async {
    return _mutate(() async {
      final sources = (await _load(filterUnverified: false)).toList();
      final index = sources.indexWhere((item) => item.id == source.id);
      if (index < 0) {
        sources.add(source);
      } else {
        sources[index] = source;
      }
      await _save(sources);
      _changesController.add(null);
      return load();
    });
  }

  Future<T> _mutate<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    Future<void> run(_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    }

    _mutationTail = _mutationTail.then<void>(run, onError: run);
    return completer.future;
  }

  Future<void> _save(List<RegisteredBookSource> sources) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(sources.map((source) => source.toJson()).toList()),
    );
  }
}
