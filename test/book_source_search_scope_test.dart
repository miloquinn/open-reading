import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/pages/book_sources_page.dart';

void main() {
  test('all-source scope searches every enabled source', () {
    final sources = [
      _source('source-a', enabled: true),
      _source('source-b', enabled: false),
      _source('source-c', enabled: true),
    ];

    final targets = BookSourcesPage.searchTargets(sources, null);

    expect(targets.map((source) => source.id), ['source-a', 'source-c']);
  });

  test('single-source scope searches only the selected enabled source', () {
    final sources = [
      _source('source-a', enabled: true),
      _source('source-b', enabled: true),
    ];

    final targets = BookSourcesPage.searchTargets(sources, 'source-b');

    expect(targets.map((source) => source.id), ['source-b']);
  });

  test('single-source scope never searches a disabled source', () {
    final sources = [_source('source-a', enabled: false)];

    expect(BookSourcesPage.searchTargets(sources, 'source-a'), isEmpty);
  });
}

RegisteredBookSource _source(String id, {required bool enabled}) {
  return RegisteredBookSource(
    id: id,
    name: id,
    description: '',
    manifestUrl: Uri.parse('https://example.org/$id/source.json'),
    apiBaseUrl: Uri.parse('https://example.org/$id/api/'),
    protocolVersion: '1.0',
    languages: const ['zh-CN'],
    capabilities: const {'search'},
    enabled: enabled,
    addedAt: DateTime.utc(2026, 7, 12),
  );
}
