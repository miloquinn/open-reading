import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/pages/reader/paged_image_reader.dart';

/// 1x1 透明 PNG，Image.memory 可解码的最小合法图片。
final Uint8List _tinyPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00, //
  0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00, //
  0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49, //
  0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

Widget _buildReader({
  required int pageCount,
  required int initialPage,
  required List<int> requested,
  ValueChanged<int>? onPageChanged,
}) {
  return MaterialApp(
    home: Scaffold(
      body: PagedImageReader(
        title: '测试书',
        pageCount: pageCount,
        initialPage: initialPage,
        loadPage: (index) async {
          requested.add(index);
          return _tinyPng;
        },
        onPageChanged: onPageChanged,
      ),
    ),
  );
}

void main() {
  testWidgets('初始页越界时收敛到最后一页，页码指示正确', (tester) async {
    final requested = <int>[];
    await tester.pumpWidget(
      _buildReader(pageCount: 3, initialPage: 99, requested: requested),
    );
    await tester.pumpAndSettle();

    expect(find.text('3 / 3'), findsOneWidget);
    // 当前页与相邻页都发起过加载（预载 index-1）。
    expect(requested, contains(2));
    expect(requested, contains(1));
  });

  testWidgets('翻页触发 onPageChanged 并更新页码', (tester) async {
    final requested = <int>[];
    final changes = <int>[];
    await tester.pumpWidget(
      _buildReader(
        pageCount: 3,
        initialPage: 0,
        requested: requested,
        onPageChanged: changes.add,
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1 / 3'), findsOneWidget);

    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(changes, [1]);
    expect(find.text('2 / 3'), findsOneWidget);
  });
}
