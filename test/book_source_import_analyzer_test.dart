import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/services/book_source_import_analyzer.dart';
import 'package:xxread/book_sources/legado/legado_source_import_service.dart';

Uint8List _bytes(Object value) =>
    Uint8List.fromList(utf8.encode(jsonEncode(value)));

void main() {
  test('detects an ORSP discovery document', () {
    final result = BookSourceImportAnalyzer().analyzeBytes(
      _bytes({
        'protocol': 'open-reading-source',
        'protocolVersion': '1.5',
        'id': 'org.example.books',
        'name': 'Example Books',
        'description': '',
        'apiBaseUrl': 'https://example.org/api/',
        'languages': ['en'],
        'capabilities': ['search', 'detail', 'catalog', 'content'],
      }),
      documentUri: Uri.parse('https://example.org/source.json'),
    );

    expect(result.kind, BookSourceImportKind.orsp);
    expect(result.sources.single.sourceProtocol, BookSourceProtocolKind.orsp);
    expect(result.sources.single.enabled, isTrue);
  });

  test('detects aggregate compatible JSON without claiming it works', () {
    final result = BookSourceImportAnalyzer().analyzeBytes(
      _bytes([
        {
          'bookSourceName': 'Compatible source',
          'bookSourceUrl': 'https://books.example',
          'searchUrl': '/search?q={{key}}',
          'ruleSearch': {'bookList': '.book'},
          'ruleToc': {'chapterList': '.chapter'},
          'ruleContent': {'content': '#content'},
        },
      ]),
    );

    expect(result.kind, BookSourceImportKind.additional);
    expect(result.sources, isEmpty);
    expect(result.additionalPreview?.sources, hasLength(1));
  });

  test('accepts realistic aggregate files larger than the old 4 MiB limit', () {
    expect(LegadoSourceImportService.maxImportBytes, 64 * 1024 * 1024);
    expect(
      LegadoSourceImportService.maxImportBytes,
      greaterThan(25 * 1024 * 1024),
    );
  });
}
