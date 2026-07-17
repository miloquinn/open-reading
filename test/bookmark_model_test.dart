import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/bookmark.dart';

void main() {
  test('bookmark preserves stable locator and display metadata', () {
    final createdAt = DateTime(2026, 7, 17, 12, 30);
    final bookmark = Bookmark(
      id: 7,
      bookId: 42,
      pageNumber: 3,
      note: '重点',
      createDate: createdAt,
      canonicalLocator: '{"chapterId":"chapter-4"}',
      anchorKey: 'chapter-4:128',
      chapterIndex: 3,
      chapterTitle: '第四章 重逢',
      excerpt: '那天傍晚，雨终于停了。',
    );

    final restored = Bookmark.fromMap(bookmark.toMap());

    expect(restored.id, 7);
    expect(restored.bookId, 42);
    expect(restored.canonicalLocator, bookmark.canonicalLocator);
    expect(restored.anchorKey, 'chapter-4:128');
    expect(restored.chapterIndex, 3);
    expect(restored.chapterTitle, '第四章 重逢');
    expect(restored.excerpt, '那天傍晚，雨终于停了。');
    expect(restored.createDate, createdAt);
  });
}
