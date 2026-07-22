import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_import_models.dart';

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
    expect(restored.sourceLocator, 'content://tree/root/document/book-1');
    expect(restored.sourceModifiedTime, 1721184000000);
  });

  test('withBytes 防御性复制并暴露不可变字节', () {
    final original = Uint8List.fromList(<int>[1, 2, 3]);
    final source = BookImportSource.withBytes(
      id: 'file_picker:web-book://hash',
      kind: BookImportSourceKind.filePicker,
      ownership: BookImportOwnership.externalCopy,
      displayName: 'book.txt',
      extension: 'txt',
      locator: 'web-book://hash',
      bytes: original,
    );

    original[0] = 9;

    expect(source.bytes, <int>[1, 2, 3]);
    expect(() => source.bytes![0] = 8, throwsUnsupportedError);
    expect(
      source.copyWithLocalPath('web-book://hash').bytes,
      same(source.bytes),
    );
  });
}
