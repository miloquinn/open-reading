import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/book_sources/legado/legado_book_source.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/services/core/app_settings_service.dart';

Map<String, dynamic> _source({
  String name = 'Declarative source',
  String url = 'https://books.example',
  int type = 0,
  bool cookies = false,
  String contentRule = '#content@text',
}) => {
  'bookSourceName': name,
  'bookSourceUrl': url,
  'bookSourceType': type,
  'enabledCookieJar': cookies,
  'searchUrl': '/search?q={{key}}',
  'ruleSearch': {'bookList': '.book', 'bookUrl': 'a@href', 'name': 'a@text'},
  'ruleBookInfo': {'name': 'h1@text'},
  'ruleToc': {
    'chapterList': '.chapters a',
    'chapterName': 'text',
    'chapterUrl': 'href',
  },
  'ruleContent': {'content': contentRule},
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('parses object, list, wrappers, BOM, and isolates bad items', () {
    final object = parseLegadoSources(jsonEncode(_source()));
    expect(object.sources, hasLength(1));

    final list = parseLegadoSources(
      '\ufeff${jsonEncode([
        _source(),
        {'bookSourceName': 'Broken'},
        'not-an-object',
      ])}',
    );
    expect(list.sources, hasLength(1));
    expect(list.errors, hasLength(2));

    final wrapper = parseLegadoSources(
      jsonEncode({
        'sources': [_source(name: 'Wrapped')],
      }),
    );
    expect(wrapper.sources.single.name, 'Wrapped');
  });

  test('deduplicates by source URL and accepts nested URL bundles', () {
    final parsed = parseLegadoSources(
      jsonEncode([_source(name: 'Old'), _source(name: 'New')]),
    );
    expect(parsed.sources.single.name, 'New');

    final nested = parseLegadoSources(
      jsonEncode({
        'sourceUrls': [
          'https://example.org/a.json',
          'https://example.org/b.json',
        ],
      }),
    );
    expect(nested.sourceUrls, hasLength(2));
  });

  test('preflight distinguishes runnable, partial, and blocked sources', () {
    const scanner = LegadoCompatibilityScanner();
    final supported = scanner.scan(LegadoBookSource.fromJson(_source()));
    expect(supported.level, LegadoCompatibilityLevel.supported);

    final image = scanner.scan(
      LegadoBookSource.fromJson(_source(type: 2, name: 'Images')),
    );
    expect(image.level, LegadoCompatibilityLevel.partial);
    expect(image.canRun, isFalse);

    for (final raw in [
      _source(type: 1, name: 'Audio'),
      _source(type: 4, name: 'Video'),
      _source(cookies: true, name: 'Cookies'),
      _source(contentRule: '@js:result', name: 'Script'),
    ]) {
      expect(
        scanner.scan(LegadoBookSource.fromJson(raw)).level,
        LegadoCompatibilityLevel.unsupported,
      );
    }
  });

  test('metadata comments do not get interpreted as executable rules', () {
    final source = LegadoBookSource.fromJson({
      ..._source(),
      'bookSourceComment':
          '// Error: failed to connect to an old mirror during testing',
    });

    expect(const LegadoCompatibilityScanner().scan(source).canRun, isTrue);
  });

  test('malformed serialized rules are unsupported instead of crashing', () {
    final raw = _source();
    raw['ruleToc'] = '{not-json';
    final source = LegadoBookSource.fromJson(raw);

    expect(source.rule('ruleToc'), isEmpty);
    expect(
      const LegadoCompatibilityScanner().scan(source).level,
      LegadoCompatibilityLevel.unsupported,
    );
  });

  test('registered compatible source round-trips with config', () {
    final registered = LegadoBookSource.fromJson(
      _source(),
    ).toRegisteredSource();
    final restored = RegisteredBookSource.fromJson(registered.toJson());

    expect(restored.sourceProtocol, BookSourceProtocolKind.legado);
    expect(restored.sourceConfig?['bookSourceName'], 'Declarative source');
    expect(restored.enabled, isFalse);
  });

  test(
    'registry hides legacy compatible imports without live verification',
    () async {
      final source = LegadoBookSource.fromJson(_source()).toRegisteredSource();
      SharedPreferences.setMockInitialValues({
        'open_reading_book_sources_v1': jsonEncode([source.toJson()]),
      });

      expect(await BookSourceRegistry().load(), isEmpty);
    },
  );

  test(
    'verified bulk import stays enabled and respects runtime gate',
    () async {
      final registry = BookSourceRegistry();
      final original = LegadoBookSource.fromJson(
        _source(),
      ).toRegisteredSource(enabled: true, readingChainVerified: true);
      await registry.upsertAll([original]);
      await registry.setEnabled(original.id, true);

      final updated = LegadoBookSource.fromJson(
        _source(name: 'Updated'),
      ).toRegisteredSource(enabled: true, readingChainVerified: true);
      final saved = await registry.upsertAll([updated]);
      expect(saved.single.name, 'Updated');
      expect(saved.single.enabled, isTrue);
      expect(await registry.loadRunnable(), isEmpty);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(additionalSourceProtocolsPreferenceKey, true);
      expect(await registry.loadRunnable(), hasLength(1));
    },
  );
}
