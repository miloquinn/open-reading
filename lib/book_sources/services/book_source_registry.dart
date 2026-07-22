import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';
import 'book_source_client.dart';

class BookSourceRegistry {
  static const String _storageKey = 'open_reading_book_sources_v1';
  static final StreamController<void> _changesController =
      StreamController<void>.broadcast();

  Stream<void> get changes => _changesController.stream;

  Future<List<RegisteredBookSource>> load() async {
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
      return sources;
    } catch (_) {
      return const [];
    }
  }

  Future<List<RegisteredBookSource>> upsert(RegisteredBookSource source) async {
    final sources = (await load()).toList();
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
        protocolVersion: source.protocolVersion,
        languages: source.languages,
        capabilities: source.capabilities,
        enabled: previous.enabled,
        addedAt: previous.addedAt,
      );
    } else {
      sources.add(source);
    }
    await _save(sources);
    _changesController.add(null);
    return load();
  }

  Future<List<RegisteredBookSource>> setEnabled(String id, bool enabled) async {
    final sources = (await load())
        .map(
          (source) =>
              source.id == id ? source.copyWith(enabled: enabled) : source,
        )
        .toList(growable: false);
    await _save(sources);
    _changesController.add(null);
    return load();
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
    final sources = (await load()).where((source) => source.id != id).toList();
    await _save(sources);
    _changesController.add(null);
    return load();
  }

  Future<void> _save(List<RegisteredBookSource> sources) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(sources.map((source) => source.toJson()).toList()),
    );
  }
}
