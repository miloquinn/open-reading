import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/book_sources/legado/legado_book_source.dart';
import 'package:xxread/book_sources/legado/legado_compatibility_scanner.dart';

void main() {
  const scanner = LegadoCompatibilityScanner();

  test('imports single, list, and wrapped Legado source JSON', () {
    final single = parseLegadoSources(_jsonSource());
    final list = parseLegadoSources('[${_jsonSource()}]');
    final wrapped = parseLegadoSources('{"bookSourceList":[${_jsonSource()}]}');

    expect(single.sources.single.name, 'Example');
    expect(list.sources.single.url, 'https://example.org');
    expect(wrapped.sources, hasLength(1));
    expect(single.errors, isEmpty);
  });

  test('keeps valid sources when another imported item is malformed', () {
    final result = parseLegadoSources('[${_jsonSource()},{"foo":"bar"}]');

    expect(result.sources, hasLength(1));
    expect(result.errors, hasLength(1));
  });

  test('classifies declarative text source as Lite compatible', () {
    final source = parseLegadoSources(_jsonSource()).sources.single;

    final report = scanner.scan(source);

    expect(report.level, LegadoCompatibilityLevel.lite);
    expect(report.risks, isEmpty);
  });

  test('does not treat key and page placeholders as JavaScript', () {
    final source = LegadoBookSource.fromJson({
      'bookSourceUrl': 'https://example.org',
      'bookSourceName': 'Placeholders',
      'searchUrl': 'https://example.org/search?q={{key}}&page={{page}}',
      'ruleBookInfo': <String, Object?>{},
      'ruleToc': <String, Object?>{},
      'ruleContent': <String, Object?>{},
    });

    final report = scanner.scan(source);

    expect(report.level, LegadoCompatibilityLevel.lite);
    expect(report.risks, isNot(contains(LegadoCapabilityRisk.javascript)));
  });

  test('requires isolated adapter for JavaScript and cookie sources', () {
    final source = parseLegadoSources(
      _jsonSource(
        extra: ',"enabledCookieJar":true,"jsLib":"function sign(){}"',
      ),
    ).sources.single;

    final report = scanner.scan(source);

    expect(report.level, LegadoCompatibilityLevel.adapterRequired);
    expect(report.risks, contains(LegadoCapabilityRisk.javascript));
    expect(report.risks, contains(LegadoCapabilityRisk.cookies));
  });

  test('rejects audio sources and incomplete reading pipelines', () {
    final source = LegadoBookSource.fromJson({
      'bookSourceUrl': 'https://audio.example.org',
      'bookSourceName': 'Audio',
      'bookSourceType': 1,
      'searchUrl': 'https://audio.example.org/search?q={{key}}',
    });

    final report = scanner.scan(source);

    expect(report.level, LegadoCompatibilityLevel.unsupported);
    expect(report.risks, contains(LegadoCapabilityRisk.audioSource));
    expect(report.risks, contains(LegadoCapabilityRisk.missingReadingRules));
  });

  test('bundled Gutenberg public-domain test source stays Lite compatible', () {
    final source = parseLegadoSources(
      File('docs/examples/legado-gutenberg-test-source.json')
          .readAsStringSync(),
    ).sources.single;

    final report = scanner.scan(source);

    expect(source.name, contains('Project Gutenberg'));
    expect(report.level, LegadoCompatibilityLevel.lite);
    expect(report.risks, isEmpty);
  });
}

String _jsonSource({String extra = ''}) => '''
{
  "bookSourceUrl": "https://example.org",
  "bookSourceName": "Example",
  "bookSourceType": 0,
  "searchUrl": "https://example.org/search?q={key}",
  "ruleSearch": {"bookList": ".book", "name": ".name@text", "bookUrl": "a@href"},
  "ruleBookInfo": {"name": "h1@text", "tocUrl": ".toc@href"},
  "ruleToc": {"chapterList": ".chapter", "chapterName": "@text", "chapterUrl": "@href"},
  "ruleContent": {"content": ".content@html"}
  $extra
}
''';
