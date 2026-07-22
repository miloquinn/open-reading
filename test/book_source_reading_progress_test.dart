import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/book_sources/services/book_source_reading_progress.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'persists chapter identity and normalized in-chapter progress',
    () async {
      const store = BookSourceReadingProgressStore();
      final progress = BookSourceReadingProgress(
        chapterId: 'chapter-25',
        chapterIndex: 24,
        chapterProgress: 0.42,
        updatedAt: DateTime.utc(2026, 7, 12),
      );

      await store.save(
        sourceId: 'source-a',
        bookId: 'book-a',
        progress: progress,
      );
      final restored = await store.load(sourceId: 'source-a', bookId: 'book-a');

      expect(restored?.chapterId, 'chapter-25');
      expect(restored?.chapterIndex, 24);
      expect(restored?.chapterProgress, closeTo(0.42, 0.001));
      expect(await store.load(sourceId: 'source-a', bookId: 'book-b'), isNull);
    },
  );
}
