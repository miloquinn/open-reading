const int epubNativeCacheVersion = 2;

Never _unsupported() =>
    throw UnsupportedError('File-backed EPUB parsing is unavailable on Web.');

Map<String, dynamic> extractEpubNativeMetadata(
  Map<String, dynamic> arguments,
) => _unsupported();

Map<String, dynamic>? readEpubNativeIndex(Map<String, dynamic> arguments) =>
    _unsupported();

Map<String, dynamic> buildEpubNativeIndex(Map<String, dynamic> arguments) =>
    _unsupported();

Map<String, dynamic> loadEpubNativeChapter(Map<String, dynamic> arguments) =>
    _unsupported();

Map<String, dynamic> loadEpubNativeChapterWindow(
  Map<String, dynamic> arguments,
) => _unsupported();

Map<String, dynamic> loadEpubNativeChapters(Map<String, dynamic> arguments) =>
    _unsupported();
