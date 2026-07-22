import 'dart:async';

enum BackgroundDownloadKind { book, update }

class BackgroundDownloadTask {
  const BackgroundDownloadTask({
    required this.id,
    required this.kind,
    required this.title,
    this.bookId,
  });

  final String id;
  final BackgroundDownloadKind kind;
  final String title;
  final int? bookId;
}

class BackgroundDownloadTap {
  const BackgroundDownloadTap({
    required this.kind,
    this.bookId,
    this.apkPath,
    this.expectedBuildNumber,
  });

  final BackgroundDownloadKind kind;
  final int? bookId;
  final String? apkPath;
  final String? expectedBuildNumber;
}

class BackgroundDownloadNotifier {
  BackgroundDownloadNotifier._();

  static final StreamController<BackgroundDownloadTap> _taps =
      StreamController<BackgroundDownloadTap>.broadcast();

  static Stream<BackgroundDownloadTap> get taps => _taps.stream;

  static Future<void> initialize() async {}

  static Future<void> begin(BackgroundDownloadTask task) async {}

  static Future<void> progress(
    BackgroundDownloadTask task, {
    required int completed,
    required int total,
  }) async {}

  static Future<void> completeBook(BackgroundDownloadTask task) async {}

  static Future<void> completeUpdate(
    BackgroundDownloadTask task, {
    required String apkPath,
    required String expectedBuildNumber,
  }) async {}

  static Future<void> fail(BackgroundDownloadTask task) async {}

  static Future<void> cancel(BackgroundDownloadTask task) async {}
}
