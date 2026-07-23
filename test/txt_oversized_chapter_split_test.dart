import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/txt_chapter_parser.dart';

void main() {
  test('splits every oversized recognized TXT chapter', () {
    final firstBody = List.filled(20, '第一章很长的正文。').join('\n');
    final secondBody = List.filled(18, '第二章也很长。').join('\n');
    final source = '第1章 开始\n$firstBody\n第2章 继续\n$secondBody';
    final parsed = parseTxtChapterSections(
      source,
      fallbackTitle: '测试书',
      prefaceTitle: '前言',
    );
    final sections = splitOversizedTxtSections(
      source,
      parsed,
      maxCharsPerSection: 64,
    );

    expect(sections.length, greaterThan(2));
    expect(sections.first.id, 'txt-0');
    expect(sections.first.isNeedSplitTitle, isTrue);
    expect(sections.any((section) => section.id == 'txt-0-part-1'), isTrue);
    expect(sections.any((section) => section.id == 'txt-1-part-1'), isTrue);
    expect(
      sections
          .take(sections.length - 1)
          .every((section) => section.bodyEnd - section.bodyStart <= 64),
      isTrue,
    );
    expect(
      sections.map((section) => section.bodyIn(source)).join(),
      '$firstBody$secondBody',
    );
  });
}
