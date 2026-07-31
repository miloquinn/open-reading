import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';

void main() {
  test('normalized progress wins over incompatible legacy page units', () {
    final book = Book(
      title: '章节书',
      filePath: '/books/chapters.epub',
      format: 'EPUB',
      currentPage: 34,
      totalPages: 100,
      readingProgress: 1,
    );

    expect(book.progress, 1);
    expect(Book.fromMap(book.toMap()).progress, 1);
  });

  test('legacy books keep their current page fallback', () {
    final book = Book(
      title: '旧书',
      filePath: '/books/legacy.pdf',
      format: 'PDF',
      currentPage: 34,
      totalPages: 100,
    );

    expect(book.progress, 0.34);
    expect(Book.fromMap(book.toMap()).readingProgress, isNull);
  });

  test('normalized progress is clamped when reading persisted data', () {
    final book = Book.fromMap({
      'title': '异常数据',
      'filePath': '/books/broken.txt',
      'format': 'TXT',
      'currentPage': 0,
      'totalPages': 1,
      'importDate': 0,
      'reading_progress': 1.5,
    });

    expect(book.progress, 1);
  });
}
