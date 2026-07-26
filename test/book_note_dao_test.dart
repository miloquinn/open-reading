import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/services/books/book_note_dao.dart';

void main() {
  late Database database;
  late BookNoteDao dao;

  setUp(() async {
    sqfliteFfiInit();
    database = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    await database.execute('''
      CREATE TABLE book_notes(
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        annotation_id TEXT NOT NULL,
        book_id INTEGER NOT NULL,
        content TEXT NOT NULL,
        cfi TEXT NOT NULL,
        canonical_locator TEXT,
        payload_json TEXT,
        chapter TEXT NOT NULL,
        type TEXT NOT NULL,
        color TEXT NOT NULL,
        reader_note TEXT,
        page_number INTEGER,
        start_offset INTEGER,
        end_offset INTEGER,
        create_time TEXT,
        update_time TEXT NOT NULL
      )
    ''');
    await database.execute(
      'CREATE UNIQUE INDEX idx_book_notes_annotation_id_unique '
      'ON book_notes(annotation_id)',
    );
    dao = BookNoteDao(databaseProvider: () async => database);
  });

  tearDown(() => database.close());

  test(
    'text annotations still merge by CFI and can be found by UUID',
    () async {
      final first = _note(
        annotationId: '66c5d9ce-cf3f-4dd2-81d5-d3981de53321',
        readerNote: 'first note',
      );
      final firstId = await dao.insertBookNote(first);
      final mergedId = await dao.insertBookNote(
        _note(
          annotationId: '18695a10-46a4-46ee-ad00-1aa45504dc63',
          type: 'underline',
          readerNote: 'second note',
        ),
      );

      expect(mergedId, firstId);
      expect(await database.rawQuery('SELECT COUNT(*) count FROM book_notes'), [
        {'count': 1},
      ]);
      final restored = await dao.selectBookNoteByAnnotationId(
        first.annotationId,
      );
      expect(restored.type, 'underline');
      expect(restored.readerNote, 'first note\n\nsecond note');
    },
  );

  test('ink annotations at the same CFI remain distinct', () async {
    final first = _note(
      annotationId: '9ba810b2-fd44-4105-a7fd-fdaa73092a54',
      type: 'ink',
      payloadJson: '{"stroke":1}',
    );
    final second = _note(
      annotationId: '73859813-ccf1-4e48-b3a6-95f3b1a694ec',
      type: 'ink',
      payloadJson: '{"stroke":2}',
    );

    await dao.insertBookNote(first);
    await dao.insertBookNote(second);

    final notes = await dao.selectBookNoteByCfiAndBookId('shared-cfi', 1);
    expect(notes, hasLength(2));
    expect(notes.map((note) => note.annotationId).toSet(), {
      first.annotationId,
      second.annotationId,
    });
  });
}

BookNote _note({
  required String annotationId,
  String type = 'highlight',
  String? readerNote,
  String? payloadJson,
}) {
  return BookNote(
    annotationId: annotationId,
    bookId: 1,
    content: type == 'ink' ? '' : 'selected text',
    cfi: 'shared-cfi',
    canonicalLocator: '{"progression":0.5}',
    payloadJson: payloadJson,
    chapter: 'chapter',
    type: type,
    color: '66CCFF',
    readerNote: readerNote,
    updateTime: DateTime.utc(2026),
  );
}
