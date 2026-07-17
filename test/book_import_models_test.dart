import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';

void main() {
  test('书籍来源身份可以完整地写入并恢复', () {
    final book = Book(
      title: '示例书籍',
      filePath: '/managed/example.epub',
      format: 'EPUB',
      sourceKind: 'android_tree',
      sourceLocator: 'content://tree/root/document/book-1',
      sourceModifiedTime: 1721184000000,
    );

    final restored = Book.fromMap(book.toMap());

    expect(restored.sourceKind, 'android_tree');
    expect(
      restored.sourceLocator,
      'content://tree/root/document/book-1',
    );
    expect(restored.sourceModifiedTime, 1721184000000);
  });
}
