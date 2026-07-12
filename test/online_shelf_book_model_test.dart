import 'package:flutter_test/flutter_test.dart';

import 'package:xxread/models/book.dart';

void main() {
  test('online shelf metadata survives database serialization', () {
    final book = Book(
      title: '在线书',
      author: '作者',
      filePath: '',
      format: 'source',
      storageType: 'online',
      sourceId: 'source-id',
      sourceBookId: 'book-id',
      sourceJson: '{"id":"source-id"}',
      sourceBookJson: '{"id":"book-id"}',
    );

    final restored = Book.fromMap(book.toMap());

    expect(restored.isOnline, isTrue);
    expect(restored.sourceId, 'source-id');
    expect(restored.sourceBookId, 'book-id');
  });
}
