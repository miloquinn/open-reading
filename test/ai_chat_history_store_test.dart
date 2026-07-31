import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/services/ai/ai_chat_history_store.dart';

AiChatHistorySession _session(
  String id, {
  String bookTitle = '测试书',
  String? bookId,
  DateTime? updatedAt,
}) {
  final at = updatedAt ?? DateTime(2026, 7, 26, 12);
  return AiChatHistorySession(
    id: id,
    bookTitle: bookTitle,
    bookId: bookId,
    createdAt: at,
    updatedAt: at,
    messages: [
      AiChatHistoryMessage(role: 'user', text: '问题 $id', at: at),
      AiChatHistoryMessage(role: 'assistant', text: '回答 $id', at: at),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AiChatHistoryStore().debugResetForTest();
  });

  test('sessions persist across reloads and keep newest first', () async {
    final store = AiChatHistoryStore();
    await store.upsertSession(
      _session('a', updatedAt: DateTime(2026, 7, 26, 10)),
    );
    await store.upsertSession(
      _session('b', bookId: '42', updatedAt: DateTime(2026, 7, 26, 11)),
    );

    store.debugResetForTest();
    await store.ensureLoaded();

    expect(store.sessions.map((s) => s.id), ['b', 'a']);
    expect(store.sessions.first.firstQuestion, '问题 b');
    expect(store.sessions.first.bookTitle, '测试书');
    expect(store.sessions.first.bookId, '42');
    expect(store.sessions.last.bookId, isNull);
    expect(store.sessions.first.messages, hasLength(2));
  });

  test('upsert replaces an existing session by id', () async {
    final store = AiChatHistoryStore();
    await store.upsertSession(_session('a'));
    final updated = AiChatHistorySession(
      id: 'a',
      bookTitle: '测试书',
      createdAt: DateTime(2026, 7, 26, 12),
      updatedAt: DateTime(2026, 7, 26, 13),
      messages: [
        AiChatHistoryMessage(
          role: 'user',
          text: '追问',
          at: DateTime(2026, 7, 26, 13),
        ),
      ],
    );
    await store.upsertSession(updated);

    expect(store.sessions, hasLength(1));
    expect(store.sessions.single.firstQuestion, '追问');
  });

  test('delete and clear remove sessions permanently', () async {
    final store = AiChatHistoryStore();
    await store.upsertSession(_session('a'));
    await store.upsertSession(_session('b'));

    await store.deleteSession('a');
    expect(store.sessions.map((s) => s.id), ['b']);

    await store.clearAll();
    expect(store.sessions, isEmpty);

    store.debugResetForTest();
    await store.ensureLoaded();
    expect(store.sessions, isEmpty);
  });

  test('session count is capped at the configured maximum', () async {
    final store = AiChatHistoryStore();
    for (var index = 0; index < AiChatHistoryStore.maxSessions + 5; index++) {
      await store.upsertSession(
        _session('s$index', updatedAt: DateTime(2026, 7, 26, 0, index)),
      );
    }
    expect(store.sessions, hasLength(AiChatHistoryStore.maxSessions));
    expect(store.sessions.first.id, 's${AiChatHistoryStore.maxSessions + 4}');
  });

  test('corrupt stored payload degrades to an empty history', () async {
    SharedPreferences.setMockInitialValues({
      'reader_ai_chat_history_v1': '{not json]',
    });
    final store = AiChatHistoryStore();
    store.debugResetForTest();
    await store.ensureLoaded();
    expect(store.sessions, isEmpty);
  });
}
