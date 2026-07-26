import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/reader_core/ai/ai_service.dart';
import 'package:xxread/services/ai/ai_request_coordinator.dart';
import 'package:xxread/services/ai/book_preprocess_service.dart';
import 'package:xxread/services/ai/global_ai_reading_service.dart';
import 'package:xxread/services/books/book_text_extraction_service.dart';

/// 记录调用并按外部指令放行的假 AI 服务；可预置若干次失败。
class _RecordingAIService implements AIService {
  final List<String> chatCalls = <String>[];

  /// 每次 chat 调用先消费一个预置错误；耗尽后正常返回。
  final List<AIServiceException> pendingErrors = <AIServiceException>[];

  @override
  Future<String> chat({
    required List<AIChatMessage> history,
    required String pageText,
    required AIRequestMeta meta,
  }) async {
    chatCalls.add(meta.chapterId);
    if (pendingErrors.isNotEmpty) {
      throw pendingErrors.removeAt(0);
    }
    return '总结：${meta.chapterId}';
  }

  @override
  Future<String> askSelection({
    required String selectedText,
    required String contextBefore,
    required String contextAfter,
    required AIRequestMeta meta,
  }) async => 'selection';

  @override
  Future<String> analyzePage({
    required String pageText,
    required AIRequestMeta meta,
  }) async => 'page';
}

class _FakeExtractor extends BookTextExtractionService {
  const _FakeExtractor();

  @override
  Future<List<BookChapterText>> extractChapters(Book book) async {
    return const [BookChapterText(chapterId: 'c1', title: '第一章', text: '正文内容')];
  }
}

class _MemoryKnowledge extends GlobalAIReadingService {
  _MemoryKnowledge() : super.forTesting();

  final Map<String, String> summaries = <String, String>{};

  @override
  Future<void> saveBookSummary({
    required String bookId,
    required String summary,
  }) async {
    summaries[bookId] = summary;
  }
}

Book _testBook() =>
    Book(id: 7, title: '并发测试', filePath: 'test.txt', format: 'txt');

/// 测试用预处理服务：去掉请求间隔，退避序列可注入。
BookPreprocessService _testService({
  required _RecordingAIService ai,
  required _MemoryKnowledge knowledge,
  required AiRequestCoordinator coordinator,
  List<Duration> retryDelays = const [],
}) {
  return BookPreprocessService(
    ai: ai,
    extractor: const _FakeExtractor(),
    knowledge: knowledge,
    coordinator: coordinator,
    requestGap: Duration.zero,
    retryDelays: retryDelays,
  );
}

void main() {
  group('AiRequestCoordinator', () {
    test('无交互请求时 waitUntilInteractiveIdle 立即完成', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      var idle = false;
      unawaited(
        coordinator.waitUntilInteractiveIdle().then((_) => idle = true),
      );
      await pumpEventQueue();
      expect(idle, isTrue);
    });

    test('交互请求在途时等待，全部结束后才放行', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final first = Completer<String>();
      final second = Completer<String>();
      unawaited(coordinator.runInteractive(() => first.future));
      unawaited(coordinator.runInteractive(() => second.future));
      var idle = false;
      unawaited(
        coordinator.waitUntilInteractiveIdle().then((_) => idle = true),
      );

      await pumpEventQueue();
      expect(coordinator.hasInteractiveRequests, isTrue);
      expect(idle, isFalse);

      first.complete('a');
      await pumpEventQueue();
      expect(idle, isFalse);

      second.complete('b');
      await pumpEventQueue();
      expect(idle, isTrue);
      expect(coordinator.hasInteractiveRequests, isFalse);
    });

    test('交互请求抛错也会释放计数并唤醒等待者', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final failing = Completer<String>();
      final run = coordinator.runInteractive(() => failing.future);
      var idle = false;
      unawaited(
        coordinator.waitUntilInteractiveIdle().then((_) => idle = true),
      );

      await pumpEventQueue();
      expect(idle, isFalse);

      failing.completeError(StateError('provider down'));
      await expectLater(run, throwsStateError);
      await pumpEventQueue();
      expect(idle, isTrue);
      expect(coordinator.hasInteractiveRequests, isFalse);
    });

    test('等待期间来了新交互请求会继续等待', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final first = Completer<String>();
      unawaited(coordinator.runInteractive(() => first.future));
      var idle = false;
      unawaited(
        coordinator.waitUntilInteractiveIdle().then((_) => idle = true),
      );
      await pumpEventQueue();

      // 第一个请求完成的同时插入第二个：等待者不应误醒。
      final second = Completer<String>();
      first.complete('a');
      unawaited(coordinator.runInteractive(() => second.future));
      await pumpEventQueue();
      expect(idle, isFalse);

      second.complete('b');
      await pumpEventQueue();
      expect(idle, isTrue);
    });
  });

  group('BookPreprocessService 与对话并发', () {
    test('预处理让行：对话请求在途时分块请求暂停，结束后继续', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final ai = _RecordingAIService();
      final knowledge = _MemoryKnowledge();
      final service = _testService(
        ai: ai,
        knowledge: knowledge,
        coordinator: coordinator,
      );

      final chatGate = Completer<String>();
      unawaited(coordinator.runInteractive(() => chatGate.future));
      await pumpEventQueue();

      final preprocess = service.preprocessBook(book: _testBook());
      await pumpEventQueue();
      expect(ai.chatCalls, isEmpty, reason: '对话在途时预处理不应发出请求');

      chatGate.complete('答案');
      final summary = await preprocess;
      expect(ai.chatCalls, hasLength(2));
      expect(ai.chatCalls.last, 'preprocess-merge');
      expect(summary, isNotEmpty);
      expect(knowledge.summaries['7'], summary);
    });

    test('让行等待期间取消任务：不再发出任何请求', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final ai = _RecordingAIService();
      final knowledge = _MemoryKnowledge();
      final service = _testService(
        ai: ai,
        knowledge: knowledge,
        coordinator: coordinator,
      );

      final chatGate = Completer<String>();
      unawaited(coordinator.runInteractive(() => chatGate.future));
      await pumpEventQueue();

      final cancelToken = BookPreprocessCancelToken();
      final preprocess = service.preprocessBook(
        book: _testBook(),
        cancelToken: cancelToken,
      );
      await pumpEventQueue();

      cancelToken.cancel();
      chatGate.complete('答案');
      await expectLater(preprocess, throwsA(isA<BookPreprocessCancelled>()));
      expect(ai.chatCalls, isEmpty);
      expect(knowledge.summaries, isEmpty);
    });

    test('无对话在途时预处理立即执行', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final ai = _RecordingAIService();
      final knowledge = _MemoryKnowledge();
      final service = _testService(
        ai: ai,
        knowledge: knowledge,
        coordinator: coordinator,
      );

      final summary = await service.preprocessBook(book: _testBook());
      expect(ai.chatCalls, hasLength(2));
      expect(summary, isNotEmpty);
    });
  });

  group('BookPreprocessService 限流重试', () {
    test('429 限流按退避重试，成功后任务继续', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final ai = _RecordingAIService()
        ..pendingErrors.addAll(const [
          AIServiceException(code: 'request_failed_generic', status: '429'),
          AIServiceException(code: 'request_failed_generic', status: '429'),
        ]);
      final knowledge = _MemoryKnowledge();
      final service = _testService(
        ai: ai,
        knowledge: knowledge,
        coordinator: coordinator,
        retryDelays: const [Duration.zero, Duration.zero, Duration.zero],
      );

      final summary = await service.preprocessBook(book: _testBook());
      // 第一块失败 2 次 + 成功 1 次，合并 1 次。
      expect(ai.chatCalls, hasLength(4));
      expect(summary, isNotEmpty);
      expect(knowledge.summaries['7'], summary);
    });

    test('网络传输失败同样重试', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final ai = _RecordingAIService()
        ..pendingErrors.add(
          const AIServiceException(code: 'network_request_failed'),
        );
      final knowledge = _MemoryKnowledge();
      final service = _testService(
        ai: ai,
        knowledge: knowledge,
        coordinator: coordinator,
        retryDelays: const [Duration.zero],
      );

      final summary = await service.preprocessBook(book: _testBook());
      expect(ai.chatCalls, hasLength(3));
      expect(summary, isNotEmpty);
    });

    test('配置类错误不重试，立即失败', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final ai = _RecordingAIService()
        ..pendingErrors.add(const AIServiceException(code: 'api_key_required'));
      final knowledge = _MemoryKnowledge();
      final service = _testService(
        ai: ai,
        knowledge: knowledge,
        coordinator: coordinator,
        retryDelays: const [Duration.zero, Duration.zero],
      );

      await expectLater(
        service.preprocessBook(book: _testBook()),
        throwsA(
          isA<AIServiceException>().having(
            (e) => e.code,
            'code',
            'api_key_required',
          ),
        ),
      );
      expect(ai.chatCalls, hasLength(1), reason: '不应对配置错误重试');
      expect(knowledge.summaries, isEmpty);
    });

    test('重试次数耗尽后抛出最后一次错误', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final ai = _RecordingAIService()
        ..pendingErrors.addAll(const [
          AIServiceException(code: 'request_failed_generic', status: '429'),
          AIServiceException(code: 'request_failed_generic', status: '503'),
        ]);
      final knowledge = _MemoryKnowledge();
      final service = _testService(
        ai: ai,
        knowledge: knowledge,
        coordinator: coordinator,
        retryDelays: const [Duration.zero],
      );

      await expectLater(
        service.preprocessBook(book: _testBook()),
        throwsA(
          isA<AIServiceException>().having((e) => e.status, 'status', '503'),
        ),
      );
      expect(ai.chatCalls, hasLength(2));
    });

    test('退避等待期间取消任务立即生效', () async {
      final coordinator = AiRequestCoordinator.forTesting();
      final ai = _RecordingAIService()
        ..pendingErrors.add(
          const AIServiceException(
            code: 'request_failed_generic',
            status: '429',
          ),
        );
      final knowledge = _MemoryKnowledge();
      final service = _testService(
        ai: ai,
        knowledge: knowledge,
        coordinator: coordinator,
        retryDelays: const [Duration(seconds: 30)],
      );

      final cancelToken = BookPreprocessCancelToken();
      final preprocess = service.preprocessBook(
        book: _testBook(),
        cancelToken: cancelToken,
      );
      // 等第一次请求抛出 429 并进入退避等待。
      await pumpEventQueue();
      expect(ai.chatCalls, hasLength(1));

      cancelToken.cancel();
      await expectLater(preprocess, throwsA(isA<BookPreprocessCancelled>()));
    });
  });
}
