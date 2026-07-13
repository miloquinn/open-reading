import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/legado/legado_book_source.dart';
import 'package:xxread/book_sources/legado/legado_compatibility_scanner.dart';
import 'package:xxread/book_sources/legado/legado_source_registry.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('persists, replaces, and removes imported Legado sources', () async {
    const registry = LegadoSourceRegistry();
    final original = _source('Original');
    final updated = _source('Updated');

    await registry.upsertAll([original]);
    final firstLoad = await registry.load();
    expect(firstLoad.single.source.name, 'Original');
    expect(
      firstLoad.single.compatibility.level,
      LegadoCompatibilityLevel.lite,
    );

    await registry.upsertAll([updated]);
    final secondLoad = await registry.load();
    expect(secondLoad, hasLength(1));
    expect(secondLoad.single.source.name, 'Updated');
    expect(secondLoad.single.importedAt, firstLoad.single.importedAt);

    expect(await registry.remove(updated.url), isEmpty);
  });
}

LegadoBookSource _source(String name) => LegadoBookSource.fromJson({
      'bookSourceUrl': 'https://example.org',
      'bookSourceName': name,
      'searchUrl': 'https://example.org/search?q={key}',
      'ruleBookInfo': <String, Object?>{},
      'ruleToc': <String, Object?>{},
      'ruleContent': <String, Object?>{},
    });
