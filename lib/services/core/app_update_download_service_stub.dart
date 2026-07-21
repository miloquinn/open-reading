import 'package:dio/dio.dart';

import 'update_check_service.dart';

enum AppUpdateFailure {
  cancelled,
  download,
  fileSize,
  checksum,
  install,
  unsupported,
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.failure, [this.cause]);

  final AppUpdateFailure failure;
  final Object? cause;

  @override
  String toString() => 'AppUpdateException($failure, $cause)';
}

typedef UpdateDownloadProgress = void Function(int received, int total);

class AppUpdateDownloadService {
  AppUpdateDownloadService({Dio? dio});

  static Future<String> installDownloadedApk(
    String path, {
    required String expectedBuildNumber,
  }) =>
      throw const AppUpdateException(AppUpdateFailure.unsupported);

  Future<String> downloadAndInstall(
    WebsiteReleaseAsset asset, {
    UpdateDownloadProgress? onProgress,
    CancelToken? cancelToken,
  }) =>
      throw const AppUpdateException(AppUpdateFailure.unsupported);
}
