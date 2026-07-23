import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/indexed_text_reader.dart';

void main() {
  test('reads the requested UTF-8 byte range asynchronously', () async {
    final directory = Directory.systemTemp.createTempSync(
      'open-reading-indexed-text-',
    );
    final file = File('${directory.path}/chapters.data');
    addTearDown(() => directory.deleteSync(recursive: true));
    file.writeAsStringSync('序章第一章正文尾声');

    final firstChapterStart = utf8.encode('序章').length;
    final firstChapterEnd = firstChapterStart + utf8.encode('第一章正文').length;

    expect(
      await readIndexedUtf8Range(
        path: file.path,
        startOffset: firstChapterStart,
        endOffset: firstChapterEnd,
      ),
      '第一章正文',
    );
  });
}
