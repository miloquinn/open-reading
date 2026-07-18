class ReaderThemeBackgroundService {
  ReaderThemeBackgroundService();

  bool get isSupported => false;

  Future<String?> pickAndStore() async => null;

  Future<void> delete(String? imagePath) async {}
}

enum ReaderThemeBackgroundError {
  unsupportedFormat,
  fileTooLarge,
  readFailed,
  storageFailed,
}

class ReaderThemeBackgroundException implements Exception {
  const ReaderThemeBackgroundException(this.code, [this.cause]);

  final ReaderThemeBackgroundError code;
  final Object? cause;
}
