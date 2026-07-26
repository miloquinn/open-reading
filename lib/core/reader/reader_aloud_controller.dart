import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

bool get isReaderAloudPlatformSupported =>
    kIsWeb ||
    defaultTargetPlatform == TargetPlatform.android ||
    defaultTargetPlatform == TargetPlatform.iOS ||
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.windows;

enum ReaderAloudPlaybackState { stopped, loading, playing, paused, error }

enum ReaderAloudControl { previous, playPause, next, stop }

class ReaderAloudPosition {
  const ReaderAloudPosition({required this.chapterIndex, required this.offset});

  final int chapterIndex;
  final int offset;

  @override
  bool operator ==(Object other) =>
      other is ReaderAloudPosition &&
      other.chapterIndex == chapterIndex &&
      other.offset == offset;

  @override
  int get hashCode => Object.hash(chapterIndex, offset);
}

class ReaderAloudChapter {
  const ReaderAloudChapter({
    required this.index,
    required this.id,
    required this.title,
    required this.text,
  });

  final int index;
  final String id;
  final String title;
  final String text;
}

class ReaderAloudSegment {
  const ReaderAloudSegment({
    required this.chapterIndex,
    required this.chapterId,
    required this.chapterTitle,
    required this.startOffset,
    required this.endOffset,
    required this.text,
  });

  final int chapterIndex;
  final String chapterId;
  final String chapterTitle;
  final int startOffset;
  final int endOffset;
  final String text;
}

@immutable
class ReaderAloudHighlight {
  const ReaderAloudHighlight({
    required this.chapterIndex,
    required this.chapterId,
    required this.startOffset,
    required this.endOffset,
  });

  final int chapterIndex;
  final String chapterId;
  final int startOffset;
  final int endOffset;

  bool matches({required int chapterIndex, required String chapterId}) =>
      this.chapterIndex == chapterIndex && this.chapterId == chapterId;

  @override
  bool operator ==(Object other) =>
      other is ReaderAloudHighlight &&
      other.chapterIndex == chapterIndex &&
      other.chapterId == chapterId &&
      other.startOffset == startOffset &&
      other.endOffset == endOffset;

  @override
  int get hashCode =>
      Object.hash(chapterIndex, chapterId, startOffset, endOffset);
}

abstract interface class ReaderAloudEngine implements Listenable {
  bool get isPlaying;
  bool get isPaused;
  int get currentPosition;

  Future<void> speak(String text);
  Future<void> pause();
  Future<void> stop();
}

abstract interface class ReaderAloudAdjustableEngine
    implements ReaderAloudEngine {
  double get speechRate;
  double get speechVolume;
}

abstract interface class ReaderAloudSource {
  String get bookTitle;
  int get chapterCount;

  Future<ReaderAloudPosition> currentPosition();
  Future<ReaderAloudChapter?> loadChapter(int index);
  Future<void> revealPosition(ReaderAloudPosition position);
  Future<void> persistPosition(ReaderAloudPosition position);
}

class CallbackReaderAloudSource implements ReaderAloudSource {
  factory CallbackReaderAloudSource({
    required String bookTitle,
    required int Function() chapterCount,
    required Future<ReaderAloudPosition> Function() currentPosition,
    required Future<ReaderAloudChapter?> Function(int index) loadChapter,
    required Future<void> Function(ReaderAloudPosition position) revealPosition,
    required Future<void> Function(ReaderAloudPosition position)
    persistPosition,
  }) => CallbackReaderAloudSource._(
    bookTitle,
    chapterCount,
    currentPosition,
    loadChapter,
    revealPosition,
    persistPosition,
  );

  const CallbackReaderAloudSource._(
    this.bookTitle,
    this._chapterCount,
    this._currentPosition,
    this._loadChapter,
    this._revealPosition,
    this._persistPosition,
  );

  @override
  final String bookTitle;
  final int Function() _chapterCount;
  final Future<ReaderAloudPosition> Function() _currentPosition;
  final Future<ReaderAloudChapter?> Function(int index) _loadChapter;
  final Future<void> Function(ReaderAloudPosition position) _revealPosition;
  final Future<void> Function(ReaderAloudPosition position) _persistPosition;

  @override
  int get chapterCount => _chapterCount();

  @override
  Future<ReaderAloudPosition> currentPosition() => _currentPosition();

  @override
  Future<ReaderAloudChapter?> loadChapter(int index) => _loadChapter(index);

  @override
  Future<void> persistPosition(ReaderAloudPosition position) =>
      _persistPosition(position);

  @override
  Future<void> revealPosition(ReaderAloudPosition position) =>
      _revealPosition(position);
}

class ReaderAloudNotificationData {
  const ReaderAloudNotificationData({
    required this.bookTitle,
    required this.chapterTitle,
    required this.state,
    required this.chapterIndex,
    required this.chapterCount,
    required this.progress,
  });

  final String bookTitle;
  final String chapterTitle;
  final ReaderAloudPlaybackState state;
  final int chapterIndex;
  final int chapterCount;
  final double progress;
}

abstract interface class ReaderAloudNotificationSink {
  Stream<ReaderAloudControl> get controls;

  Future<void> show(ReaderAloudNotificationData data);
  Future<void> stop();
}

class NoopReaderAloudNotificationSink implements ReaderAloudNotificationSink {
  const NoopReaderAloudNotificationSink();

  @override
  Stream<ReaderAloudControl> get controls => const Stream.empty();

  @override
  Future<void> show(ReaderAloudNotificationData data) async {}

  @override
  Future<void> stop() async {}
}

typedef ReaderAloudSegmentBuilder =
    List<ReaderAloudSegment> Function(ReaderAloudChapter chapter);

class ReaderAloudSegmenter {
  const ReaderAloudSegmenter._();

  static const String _boundaries = '。！？!?；;：:\n';

  static List<ReaderAloudSegment> split({
    required int chapterIndex,
    required String chapterId,
    required String chapterTitle,
    required String text,
    int maxCharacters = 320,
    int minimumCharacters = 1,
  }) {
    if (text.trim().isEmpty) return const [];
    final safeMax = math.max(1, maxCharacters);
    final safeMinimum = minimumCharacters.clamp(1, safeMax);
    final segments = <ReaderAloudSegment>[];
    var cursor = 0;

    while (cursor < text.length) {
      while (cursor < text.length && _isWhitespace(text.codeUnitAt(cursor))) {
        cursor++;
      }
      if (cursor >= text.length) break;

      final start = cursor;
      final hardEnd = math.min(text.length, start + safeMax);
      var end = -1;
      for (var index = start; index < hardEnd; index++) {
        final character = text[index];
        if (_boundaries.contains(character) &&
            index + 1 - start >= safeMinimum) {
          end = index + 1;
          break;
        }
      }
      if (end < 0) {
        end = hardEnd;
        if (hardEnd < text.length) {
          for (var index = hardEnd - 1; index > start; index--) {
            if (_isWhitespace(text.codeUnitAt(index))) {
              end = index;
              break;
            }
          }
        }
      }
      if (end > start &&
          end < text.length &&
          _isHighSurrogate(text.codeUnitAt(end - 1))) {
        end--;
      }
      if (end <= start) end = math.min(text.length, start + 1);

      var trimmedEnd = end;
      while (trimmedEnd > start &&
          _isWhitespace(text.codeUnitAt(trimmedEnd - 1))) {
        trimmedEnd--;
      }
      if (trimmedEnd > start) {
        segments.add(
          ReaderAloudSegment(
            chapterIndex: chapterIndex,
            chapterId: chapterId,
            chapterTitle: chapterTitle,
            startOffset: start,
            endOffset: trimmedEnd,
            text: text.substring(start, trimmedEnd),
          ),
        );
      }
      cursor = end;
    }

    return segments;
  }

  static bool _isWhitespace(int codeUnit) =>
      codeUnit == 0x20 ||
      codeUnit == 0x09 ||
      codeUnit == 0x0A ||
      codeUnit == 0x0D ||
      codeUnit == 0x3000;

  static bool _isHighSurrogate(int codeUnit) =>
      codeUnit >= 0xD800 && codeUnit <= 0xDBFF;
}

class ReaderAloudController extends ChangeNotifier {
  ReaderAloudController({
    required this.engine,
    required this.source,
    this.notificationSink = const NoopReaderAloudNotificationSink(),
    ReaderAloudSegmentBuilder? segmenter,
  }) : _segmenter =
           segmenter ??
           ((chapter) => ReaderAloudSegmenter.split(
             chapterIndex: chapter.index,
             chapterId: chapter.id,
             chapterTitle: chapter.title,
             text: chapter.text,
           )) {
    engine.addListener(_handleEngineChanged);
    _controlSubscription = notificationSink.controls.listen(_handleControl);
  }

  final ReaderAloudEngine engine;
  final ReaderAloudSource source;
  final ReaderAloudNotificationSink notificationSink;
  final ReaderAloudSegmentBuilder _segmenter;

  StreamSubscription<ReaderAloudControl>? _controlSubscription;
  Timer? _notificationTimer;
  Timer? _progressSaveTimer;
  Timer? _sleepTimer;
  ReaderAloudPlaybackState _state = ReaderAloudPlaybackState.stopped;
  ReaderAloudChapter? _currentChapter;
  List<ReaderAloudSegment> _segments = const [];
  int _segmentIndex = 0;
  int _utteranceBaseOffset = 0;
  int _resumeOffset = 0;
  int _generation = 0;
  bool _disposed = false;
  Object? _lastError;
  Duration? _sleepDuration;
  DateTime? _sleepDeadline;

  ReaderAloudPlaybackState get state => _state;
  ReaderAloudChapter? get currentChapter => _currentChapter;
  ReaderAloudSegment? get currentSegment =>
      _segments.isEmpty ? null : _segments[_segmentIndex];
  ReaderAloudHighlight? get highlight {
    if (!isActive) return null;
    final segment = currentSegment;
    if (segment == null) return null;
    return ReaderAloudHighlight(
      chapterIndex: segment.chapterIndex,
      chapterId: segment.chapterId,
      startOffset: segment.startOffset,
      endOffset: segment.endOffset,
    );
  }

  Object? get lastError => _lastError;
  Duration? get sleepDuration => _sleepDuration;
  Duration? get sleepRemaining {
    final deadline = _sleepDeadline;
    if (deadline == null) return null;
    final remaining = deadline.difference(DateTime.now());
    return remaining.isNegative ? Duration.zero : remaining;
  }

  bool get isActive =>
      _state == ReaderAloudPlaybackState.loading ||
      _state == ReaderAloudPlaybackState.playing ||
      _state == ReaderAloudPlaybackState.paused;

  int get currentOffset {
    final segment = currentSegment;
    if (segment == null) return 0;
    final relative = _state == ReaderAloudPlaybackState.playing
        ? _utteranceBaseOffset + engine.currentPosition
        : _resumeOffset;
    return (segment.startOffset + relative).clamp(
      segment.startOffset,
      segment.endOffset,
    );
  }

  double get chapterProgress {
    final chapter = _currentChapter;
    if (chapter == null || chapter.text.isEmpty) return 0;
    return (currentOffset / chapter.text.length).clamp(0.0, 1.0);
  }

  Future<void> start() async {
    if (_disposed) return;
    if (_state == ReaderAloudPlaybackState.paused) {
      await resume();
      return;
    }
    final generation = ++_generation;
    _setState(ReaderAloudPlaybackState.loading);
    _lastError = null;
    await engine.stop();
    try {
      final position = await source.currentPosition();
      if (!_isCurrent(generation)) return;
      final loaded = await _loadChapterAt(
        position.chapterIndex,
        startOffset: position.offset,
      );
      if (!loaded || !_isCurrent(generation)) {
        await stop();
        return;
      }
      _setState(ReaderAloudPlaybackState.playing);
      unawaited(_playCurrent(generation));
    } catch (error) {
      _fail(error, generation);
    }
  }

  Future<void> pause() async {
    if (_state != ReaderAloudPlaybackState.playing) return;
    _resumeOffset = (_utteranceBaseOffset + engine.currentPosition).clamp(
      0,
      currentSegment?.text.length ?? 0,
    );
    final generation = ++_generation;
    _setState(ReaderAloudPlaybackState.paused);
    try {
      await engine.pause();
    } catch (error) {
      _fail(error, generation);
      return;
    }
    await _persistCurrentPosition();
    await _showNotification();
  }

  Future<void> resume() async {
    if (_state != ReaderAloudPlaybackState.paused || currentSegment == null) {
      return;
    }
    final generation = ++_generation;
    _setState(ReaderAloudPlaybackState.playing);
    unawaited(_playCurrent(generation));
  }

  /// Restarts the active sentence from the engine's current UTF-16 position.
  ///
  /// Platform TTS engines generally apply rate, pitch and voice changes only
  /// to the next utterance. Restarting the remaining text makes those changes
  /// audible immediately without replaying the beginning of the sentence.
  Future<void> refreshPlayback() async {
    if (_disposed ||
        _state != ReaderAloudPlaybackState.playing ||
        currentSegment == null) {
      return;
    }
    _resumeOffset = (_utteranceBaseOffset + engine.currentPosition).clamp(
      0,
      currentSegment!.text.length,
    );
    final generation = ++_generation;
    try {
      await engine.stop();
    } catch (error) {
      _fail(error, generation);
      return;
    }
    if (!_isCurrent(generation) || _state != ReaderAloudPlaybackState.playing) {
      return;
    }
    notifyListeners();
    unawaited(_playCurrent(generation));
  }

  Future<void> previous() => _moveBy(-1);

  Future<void> next() => _moveBy(1);

  Future<void> stop() async {
    if (_state == ReaderAloudPlaybackState.playing) {
      _resumeOffset = math.max(
        _resumeOffset,
        (_utteranceBaseOffset + engine.currentPosition).clamp(
          0,
          currentSegment?.text.length ?? 0,
        ),
      );
    }
    ++_generation;
    _notificationTimer?.cancel();
    _progressSaveTimer?.cancel();
    _sleepTimer?.cancel();
    _sleepTimer = null;
    _sleepDuration = null;
    _sleepDeadline = null;
    if (!_disposed) {
      _setState(ReaderAloudPlaybackState.stopped);
    }
    await engine.stop();
    await _persistCurrentPosition();
    await _stopNotification();
  }

  void setSleepTimer(Duration? duration) {
    _sleepTimer?.cancel();
    final normalized = duration != null && duration > Duration.zero
        ? duration
        : null;
    _sleepDuration = normalized;
    _sleepDeadline = normalized == null ? null : DateTime.now().add(normalized);
    if (normalized != null) {
      _sleepTimer = Timer(normalized, () => unawaited(stop()));
    }
    notifyListeners();
  }

  Future<void> _moveBy(int delta) async {
    if (_disposed) return;
    if (currentSegment == null) {
      await start();
      return;
    }
    final generation = ++_generation;
    await engine.stop();
    if (!_isCurrent(generation)) return;
    bool moved;
    try {
      moved = delta < 0 ? await _movePrevious() : await _moveNext();
    } catch (error) {
      _fail(error, generation);
      return;
    }
    if (!moved || !_isCurrent(generation)) {
      if (delta > 0) {
        _resumeOffset = currentSegment?.text.length ?? _resumeOffset;
        await stop();
      } else if (_isCurrent(generation)) {
        _resumeOffset = 0;
        _setState(ReaderAloudPlaybackState.playing);
        unawaited(_playCurrent(generation));
      }
      return;
    }
    _resumeOffset = 0;
    _setState(ReaderAloudPlaybackState.playing);
    unawaited(_playCurrent(generation));
  }

  Future<bool> _movePrevious() async {
    if (_segmentIndex > 0) {
      _segmentIndex--;
      notifyListeners();
      return true;
    }
    final chapterIndex = (_currentChapter?.index ?? 0) - 1;
    if (chapterIndex < 0) return false;
    final loaded = await _loadChapterAt(chapterIndex, startFromEnd: true);
    return loaded;
  }

  Future<bool> _moveNext() async {
    if (_segmentIndex + 1 < _segments.length) {
      _segmentIndex++;
      notifyListeners();
      return true;
    }
    final chapterIndex = (_currentChapter?.index ?? -1) + 1;
    if (chapterIndex >= source.chapterCount) return false;
    return _loadChapterAt(chapterIndex);
  }

  Future<bool> _loadChapterAt(
    int chapterIndex, {
    int startOffset = 0,
    bool startFromEnd = false,
  }) async {
    var index = chapterIndex;
    while (index >= 0 && index < source.chapterCount) {
      final chapter = await source.loadChapter(index);
      if (chapter == null) return false;
      final segments = _segmenter(chapter);
      if (segments.isNotEmpty) {
        _currentChapter = chapter;
        _segments = segments;
        if (startFromEnd) {
          _segmentIndex = segments.length - 1;
        } else {
          final matching = segments.indexWhere(
            (segment) => startOffset < segment.endOffset,
          );
          _segmentIndex = matching < 0 ? segments.length - 1 : matching;
        }
        final segment = _segments[_segmentIndex];
        _resumeOffset = startFromEnd
            ? 0
            : (startOffset - segment.startOffset).clamp(0, segment.text.length);
        notifyListeners();
        return true;
      }
      index += startFromEnd ? -1 : 1;
      startOffset = 0;
    }
    return false;
  }

  Future<void> _playCurrent(int generation) async {
    while (_isCurrent(generation) &&
        _state == ReaderAloudPlaybackState.playing) {
      final segment = currentSegment;
      if (segment == null) return;
      final startAt = _resumeOffset.clamp(0, segment.text.length);
      final spokenText = segment.text.substring(startAt);
      if (spokenText.trim().isEmpty) {
        bool moved;
        try {
          moved = await _moveNext();
        } catch (error) {
          _fail(error, generation);
          return;
        }
        if (!moved) {
          _resumeOffset = segment.text.length;
          await stop();
          return;
        }
        _resumeOffset = 0;
        continue;
      }

      _utteranceBaseOffset = startAt;
      try {
        await source.revealPosition(
          ReaderAloudPosition(
            chapterIndex: segment.chapterIndex,
            offset: segment.startOffset + startAt,
          ),
        );
      } catch (error) {
        debugPrint('reveal reader aloud position failed: $error');
      }
      if (!_isCurrent(generation)) return;
      await _persistCurrentPosition();
      await _showNotification();

      try {
        await engine.speak(spokenText);
      } catch (error) {
        _fail(error, generation);
        return;
      }
      if (!_isCurrent(generation) ||
          _state != ReaderAloudPlaybackState.playing) {
        return;
      }

      _resumeOffset = segment.text.length;
      await _persistPosition(
        ReaderAloudPosition(
          chapterIndex: segment.chapterIndex,
          offset: segment.endOffset,
        ),
      );
      bool moved;
      try {
        moved = await _moveNext();
      } catch (error) {
        _fail(error, generation);
        return;
      }
      if (!moved) {
        await stop();
        return;
      }
      _resumeOffset = 0;
    }
  }

  void _handleEngineChanged() {
    if (_disposed || _state != ReaderAloudPlaybackState.playing) return;
    notifyListeners();
    _notificationTimer ??= Timer(const Duration(milliseconds: 450), () {
      _notificationTimer = null;
      unawaited(_showNotification());
    });
    _progressSaveTimer ??= Timer(const Duration(seconds: 2), () {
      _progressSaveTimer = null;
      unawaited(_persistCurrentPosition());
    });
  }

  Future<void> _persistCurrentPosition() async {
    final segment = currentSegment;
    if (segment == null) return;
    await _persistPosition(
      ReaderAloudPosition(
        chapterIndex: segment.chapterIndex,
        offset: currentOffset,
      ),
    );
  }

  Future<void> _persistPosition(ReaderAloudPosition position) async {
    try {
      await source.persistPosition(position);
    } catch (error) {
      debugPrint('persist reader aloud position failed: $error');
    }
  }

  Future<void> _showNotification() async {
    final chapter = _currentChapter;
    if (chapter == null || _state == ReaderAloudPlaybackState.stopped) return;
    try {
      await notificationSink.show(
        ReaderAloudNotificationData(
          bookTitle: source.bookTitle,
          chapterTitle: chapter.title,
          state: _state,
          chapterIndex: chapter.index,
          chapterCount: source.chapterCount,
          progress: chapterProgress,
        ),
      );
    } catch (error) {
      debugPrint('show reader aloud notification failed: $error');
    }
  }

  Future<void> _stopNotification() async {
    try {
      await notificationSink.stop();
    } catch (error) {
      debugPrint('stop reader aloud notification failed: $error');
    }
  }

  void _handleControl(ReaderAloudControl control) {
    switch (control) {
      case ReaderAloudControl.previous:
        unawaited(previous());
      case ReaderAloudControl.playPause:
        if (_state == ReaderAloudPlaybackState.playing) {
          unawaited(pause());
        } else if (_state == ReaderAloudPlaybackState.paused) {
          unawaited(resume());
        } else {
          unawaited(start());
        }
      case ReaderAloudControl.next:
        unawaited(next());
      case ReaderAloudControl.stop:
        unawaited(stop());
    }
  }

  void _fail(Object error, int generation) {
    if (!_isCurrent(generation)) return;
    _lastError = error;
    _setState(ReaderAloudPlaybackState.error);
    unawaited(engine.stop());
    unawaited(_stopNotification());
  }

  void _setState(ReaderAloudPlaybackState value) {
    if (_state == value || _disposed) return;
    _state = value;
    notifyListeners();
  }

  bool _isCurrent(int generation) => !_disposed && generation == _generation;

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    ++_generation;
    _notificationTimer?.cancel();
    _progressSaveTimer?.cancel();
    _sleepTimer?.cancel();
    engine.removeListener(_handleEngineChanged);
    unawaited(_controlSubscription?.cancel());
    unawaited(_persistCurrentPosition());
    unawaited(engine.stop());
    unawaited(_stopNotification());
    super.dispose();
  }
}
