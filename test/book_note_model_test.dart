import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book_note.dart';

void main() {
  test('database map round-trip preserves annotation persistence fields', () {
    final createdAt = DateTime.utc(2026, 7, 26, 9);
    final updatedAt = DateTime.utc(2026, 7, 26, 10);
    final note = BookNote(
      annotationId: 'c4407285-9f57-4cf7-9c30-b1a2ef57cd46',
      id: 7,
      bookId: 3,
      content: '',
      cfi: 'epubcfi(/6/4!/4/2)',
      canonicalLocator: '{"href":"chapter-1.xhtml","progression":0.4}',
      payloadJson: '{"strokes":[{"points":[[1,2],[3,4]]}]}',
      chapter: 'Chapter 1',
      type: 'ink',
      color: 'FF0000',
      pageNumber: 5,
      createTime: createdAt,
      updateTime: updatedAt,
    );

    final restored = BookNote.fromMap(note.toMap());

    expect(restored.annotationId, note.annotationId);
    expect(restored.canonicalLocator, note.canonicalLocator);
    expect(restored.payloadJson, note.payloadJson);
    expect(restored.type, 'ink');
    expect(restored.createTime, createdAt);
    expect(restored.updateTime, updatedAt);
  });

  test('new and legacy-loaded notes receive stable UUID identities', () {
    final note = BookNote(
      bookId: 1,
      content: 'text',
      cfi: 'cfi',
      chapter: 'chapter',
      type: 'highlight',
      color: '66CCFF',
    );
    final legacy = BookNote.fromMap({
      'id': 2,
      'book_id': 1,
      'content': 'legacy',
      'cfi': 'legacy-cfi',
      'chapter': 'chapter',
      'type': 'note',
      'color': '66CCFF',
      'reader_note': null,
      'page_number': null,
      'start_offset': null,
      'end_offset': null,
      'create_time': null,
      'update_time': DateTime.utc(2026).toIso8601String(),
    });

    expect(note.annotationId, matches(_uuidPattern));
    expect(note.copyWith().annotationId, note.annotationId);
    expect(legacy.annotationId, matches(_uuidPattern));
    expect(
      BookNote(
        annotationId: '',
        bookId: 1,
        content: 'text',
        cfi: 'cfi',
        chapter: 'chapter',
        type: 'highlight',
        color: '66CCFF',
      ).annotationId,
      matches(_uuidPattern),
    );
  });

  test('legacy ink remains readable but is not exposed for creation', () {
    expect(
      BookNote.noteTypes.map((entry) => entry['type']),
      isNot(contains('ink')),
    );
    expect(BookNote.getTypeName('ink'), 'ink');
  });
}

final _uuidPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
  caseSensitive: false,
);
