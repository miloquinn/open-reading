import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/widgets/reader_chapter_title_page.dart';

void main() {
  test('title font follows the 1.8x scale within editorial bounds', () {
    expect(ReaderChapterTitlePage.titleFontSizeFor(14), 28);
    expect(ReaderChapterTitlePage.titleFontSizeFor(17.5), 31.5);
    expect(ReaderChapterTitlePage.titleFontSizeFor(24), 34);
  });

  testWidgets('title page uses body color and centered elevated layout',
      (tester) async {
    const bodyColor = Color(0xFF302B25);
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox.expand(
          child: ReaderChapterTitlePage(
            title: '第十二章  风暴将至',
            bodyStyle: TextStyle(
              fontSize: 17.5,
              color: bodyColor,
            ),
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(
      find.byKey(ReaderChapterTitlePage.contentKey),
    );
    expect(title.data, '第十二章  风暴将至');
    expect(title.textAlign, TextAlign.center);
    expect(title.style?.fontSize, 31.5);
    expect(title.style?.color, bodyColor);

    final elevatedAlign =
        tester.widgetList<Align>(find.byType(Align)).singleWhere(
              (align) => align.alignment == const Alignment(0, -0.16),
            );
    expect(elevatedAlign.alignment, const Alignment(0, -0.16));
  });
}
