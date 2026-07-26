import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/core/reader/reader_aloud_controller.dart';

void main() {
  group('ReaderAloudSegmenter', () {
    test('uses sentence boundaries by default for spoken highlighting', () {
      const text = '甲句。乙句很短！丙句？';

      final segments = ReaderAloudSegmenter.split(
        chapterIndex: 0,
        chapterId: 'chapter-1',
        chapterTitle: '第一章',
        text: text,
      );

      expect(segments.map((segment) => segment.text), ['甲句。', '乙句很短！', '丙句？']);
    });

    test('keeps UTF-16 offsets while splitting readable sentences', () {
      const text = '  第一句。第二句很短！\n\n第三段继续。';

      final segments = ReaderAloudSegmenter.split(
        chapterIndex: 2,
        chapterId: 'chapter-3',
        chapterTitle: '第三章',
        text: text,
        maxCharacters: 8,
        minimumCharacters: 1,
      );

      expect(segments, isNotEmpty);
      expect(segments.first.startOffset, 2);
      expect(
        segments.map((segment) => segment.text).join(),
        '第一句。第二句很短！第三段继续。',
      );
      for (final segment in segments) {
        expect(
          text.substring(segment.startOffset, segment.endOffset).trim(),
          segment.text,
        );
      }
    });
  });

  group('ReaderAloudController', () {
    late _FakeReaderAloudEngine engine;
    late _FakeReaderAloudSource source;
    late _FakeReaderAloudNotificationSink notifications;
    late ReaderAloudController controller;

    setUp(() {
      engine = _FakeReaderAloudEngine();
      source = _FakeReaderAloudSource(
        chapters: const [
          ReaderAloudChapter(index: 0, id: 'c1', title: '第一章', text: '甲句。乙句。'),
          ReaderAloudChapter(index: 1, id: 'c2', title: '第二章', text: '丙句。丁句。'),
        ],
        initialPosition: const ReaderAloudPosition(chapterIndex: 0, offset: 3),
      );
      notifications = _FakeReaderAloudNotificationSink();
      controller = ReaderAloudController(
        engine: engine,
        source: source,
        notificationSink: notifications,
        segmenter: (chapter) => ReaderAloudSegmenter.split(
          chapterIndex: chapter.index,
          chapterId: chapter.id,
          chapterTitle: chapter.title,
          text: chapter.text,
          maxCharacters: 3,
          minimumCharacters: 1,
        ),
      );
    });

    tearDown(() async {
      await controller.stop();
      controller.dispose();
      await notifications.dispose();
    });

    test('starts from the segment containing the current offset', () async {
      unawaited(controller.start());
      await _flush();

      expect(controller.state, ReaderAloudPlaybackState.playing);
      expect(engine.spokenTexts, ['乙句。']);
      expect(
        controller.highlight,
        const ReaderAloudHighlight(
          chapterIndex: 0,
          chapterId: 'c1',
          startOffset: 3,
          endOffset: 6,
        ),
      );
      expect(
        source.revealed.last,
        const ReaderAloudPosition(chapterIndex: 0, offset: 3),
      );
    });

    test('pause retains the sentence highlight and stop clears it', () async {
      source.initialPosition = const ReaderAloudPosition(
        chapterIndex: 0,
        offset: 0,
      );
      unawaited(controller.start());
      await _flush();

      await controller.pause();
      expect(controller.highlight?.startOffset, 0);

      await controller.stop();
      expect(controller.highlight, isNull);
    });

    test(
      'sleep timer accepts arbitrary durations and exposes remaining time',
      () {
        const duration = Duration(hours: 2, minutes: 7);

        controller.setSleepTimer(duration);

        expect(controller.sleepDuration, duration);
        expect(controller.sleepRemaining, isNotNull);
        expect(controller.sleepRemaining!, lessThanOrEqualTo(duration));
        expect(
          controller.sleepRemaining!,
          greaterThan(const Duration(hours: 2, minutes: 6, seconds: 55)),
        );

        controller.setSleepTimer(Duration.zero);
        expect(controller.sleepDuration, isNull);
        expect(controller.sleepRemaining, isNull);
      },
    );

    test('advances through the next chapter after completion', () async {
      source.initialPosition = const ReaderAloudPosition(
        chapterIndex: 0,
        offset: 0,
      );
      unawaited(controller.start());
      await _flush();

      engine.completeUtterance();
      await _flush();
      expect(engine.spokenTexts, ['甲句。', '乙句。']);

      engine.completeUtterance();
      await _flush();
      expect(engine.spokenTexts, ['甲句。', '乙句。', '丙句。']);
      expect(controller.currentChapter?.id, 'c2');
      expect(
        source.persisted,
        contains(const ReaderAloudPosition(chapterIndex: 1, offset: 0)),
      );
    });

    test(
      'resumes from the engine progress without replaying earlier text',
      () async {
        source.initialPosition = const ReaderAloudPosition(
          chapterIndex: 0,
          offset: 0,
        );
        unawaited(controller.start());
        await _flush();

        engine.reportProgress(2);
        await controller.pause();
        await _flush();
        expect(controller.state, ReaderAloudPlaybackState.paused);

        unawaited(controller.resume());
        await _flush();
        expect(engine.spokenTexts.last, '。');
        expect(controller.currentOffset, 2);
      },
    );

    test(
      'refreshes live settings from the current sentence position',
      () async {
        source.initialPosition = const ReaderAloudPosition(
          chapterIndex: 0,
          offset: 0,
        );
        unawaited(controller.start());
        await _flush();

        engine.reportProgress(2);
        await controller.refreshPlayback();
        await _flush();

        expect(engine.spokenTexts, ['甲句。', '。']);
        expect(controller.currentOffset, 2);
        expect(controller.currentSegment?.startOffset, 0);
      },
    );

    test(
      'routes Android notification controls to the active session',
      () async {
        source.initialPosition = const ReaderAloudPosition(
          chapterIndex: 0,
          offset: 0,
        );
        unawaited(controller.start());
        await _flush();

        notifications.sendControl(ReaderAloudControl.next);
        await _flush();

        expect(engine.spokenTexts.last, '乙句。');
        expect(controller.currentSegment?.startOffset, 3);
      },
    );

    test('preserves the end position after the final utterance', () async {
      source.initialPosition = const ReaderAloudPosition(
        chapterIndex: 1,
        offset: 3,
      );
      unawaited(controller.start());
      await _flush();

      engine.completeUtterance();
      await _flush();

      expect(controller.state, ReaderAloudPlaybackState.stopped);
      expect(
        source.persisted.last,
        const ReaderAloudPosition(chapterIndex: 1, offset: 6),
      );
    });

    test('does not advance when the speech engine fails', () async {
      source.initialPosition = const ReaderAloudPosition(
        chapterIndex: 0,
        offset: 0,
      );
      engine.failNextSpeak = true;

      await controller.start();
      await _flush();

      expect(controller.state, ReaderAloudPlaybackState.error);
      expect(controller.currentSegment?.startOffset, 0);
      expect(engine.spokenTexts, ['甲句。']);
      expect(
        source.persisted,
        isNot(contains(const ReaderAloudPosition(chapterIndex: 0, offset: 3))),
      );
    });
  });
}

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}

class _FakeReaderAloudEngine extends ChangeNotifier
    implements ReaderAloudEngine {
  final List<String> spokenTexts = [];
  Completer<void>? _utterance;
  int _position = 0;
  bool _playing = false;
  bool _paused = false;
  bool failNextSpeak = false;

  @override
  int get currentPosition => _position;

  @override
  bool get isPaused => _paused;

  @override
  bool get isPlaying => _playing;

  @override
  Future<void> pause() async {
    _playing = false;
    _paused = true;
    _utterance?.complete();
    _utterance = null;
    notifyListeners();
  }

  @override
  Future<void> speak(String text) async {
    spokenTexts.add(text);
    if (failNextSpeak) {
      failNextSpeak = false;
      throw StateError('tts_call_failed');
    }
    _position = 0;
    _playing = true;
    _paused = false;
    notifyListeners();
    final utterance = Completer<void>();
    _utterance = utterance;
    await utterance.future;
    if (identical(_utterance, utterance)) {
      _utterance = null;
    }
    _playing = false;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    _playing = false;
    _paused = false;
    _position = 0;
    _utterance?.complete();
    _utterance = null;
    notifyListeners();
  }

  void completeUtterance() {
    _position = 0;
    _utterance?.complete();
    _utterance = null;
    notifyListeners();
  }

  void reportProgress(int position) {
    _position = position;
    notifyListeners();
  }
}

class _FakeReaderAloudSource implements ReaderAloudSource {
  _FakeReaderAloudSource({
    required this.chapters,
    required this.initialPosition,
  });

  final List<ReaderAloudChapter> chapters;
  ReaderAloudPosition initialPosition;
  final List<ReaderAloudPosition> revealed = [];
  final List<ReaderAloudPosition> persisted = [];

  @override
  String get bookTitle => '测试书籍';

  @override
  int get chapterCount => chapters.length;

  @override
  Future<ReaderAloudPosition> currentPosition() async => initialPosition;

  @override
  Future<ReaderAloudChapter?> loadChapter(int index) async =>
      index >= 0 && index < chapters.length ? chapters[index] : null;

  @override
  Future<void> persistPosition(ReaderAloudPosition position) async {
    persisted.add(position);
  }

  @override
  Future<void> revealPosition(ReaderAloudPosition position) async {
    revealed.add(position);
  }
}

class _FakeReaderAloudNotificationSink implements ReaderAloudNotificationSink {
  final StreamController<ReaderAloudControl> _controls =
      StreamController<ReaderAloudControl>.broadcast();
  final List<ReaderAloudNotificationData> updates = [];
  int stopCount = 0;

  @override
  Stream<ReaderAloudControl> get controls => _controls.stream;

  @override
  Future<void> show(ReaderAloudNotificationData data) async {
    updates.add(data);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  void sendControl(ReaderAloudControl control) => _controls.add(control);

  Future<void> dispose() => _controls.close();
}
