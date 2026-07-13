import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'legado_book_source.dart';
import 'legado_compatibility_scanner.dart';

class RegisteredLegadoSource {
  final LegadoBookSource source;
  final DateTime importedAt;
  final LegadoCompatibilityReport compatibility;

  const RegisteredLegadoSource({
    required this.source,
    required this.importedAt,
    required this.compatibility,
  });

  Map<String, dynamic> toJson() => {
        'source': source.toJson(),
        'importedAt': importedAt.toIso8601String(),
      };
}

class LegadoSourceRegistry {
  static const String _storageKey = 'open_reading_legado_sources_v1';
  final LegadoCompatibilityScanner _scanner;

  const LegadoSourceRegistry({
    LegadoCompatibilityScanner scanner = const LegadoCompatibilityScanner(),
  }) : _scanner = scanner;

  Future<List<RegisteredLegadoSource>> load() async {
    final preferences = await SharedPreferences.getInstance();
    final raw = preferences.getString(_storageKey);
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final sources = <RegisteredLegadoSource>[];
      for (final item in decoded) {
        if (item is! Map || item['source'] is! Map) continue;
        try {
          final source = LegadoBookSource.fromJson(
            (item['source'] as Map)
                .map((key, value) => MapEntry('$key', value)),
          );
          sources.add(
            RegisteredLegadoSource(
              source: source,
              importedAt:
                  DateTime.tryParse('${item['importedAt']}') ?? DateTime.now(),
              compatibility: _scanner.scan(source),
            ),
          );
        } catch (_) {
          // Keep one damaged source from hiding the rest of the import.
        }
      }
      sources.sort((a, b) => a.source.name.compareTo(b.source.name));
      return List.unmodifiable(sources);
    } catch (_) {
      return const [];
    }
  }

  Future<List<RegisteredLegadoSource>> upsertAll(
    Iterable<LegadoBookSource> imported,
  ) async {
    final existing = await load();
    final byUrl = <String, RegisteredLegadoSource>{
      for (final item in existing) item.source.url: item,
    };
    final now = DateTime.now();
    for (final source in imported) {
      final previous = byUrl[source.url];
      byUrl[source.url] = RegisteredLegadoSource(
        source: source,
        importedAt: previous?.importedAt ?? now,
        compatibility: _scanner.scan(source),
      );
    }
    await _save(byUrl.values);
    return load();
  }

  Future<List<RegisteredLegadoSource>> remove(String sourceUrl) async {
    final remaining = (await load())
        .where((item) => item.source.url != sourceUrl)
        .toList(growable: false);
    await _save(remaining);
    return load();
  }

  Future<void> _save(Iterable<RegisteredLegadoSource> sources) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _storageKey,
      jsonEncode(sources.map((source) => source.toJson()).toList()),
    );
  }
}
