import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'app_update_download_policy.dart';
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
  AppUpdateDownloadService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(minutes: 10),
                followRedirects: false,
                headers: {
                  if (!kIsWeb) 'User-Agent': 'OpenReading-AppUpdate',
                },
              ),
            );

  static const _channel = MethodChannel('com.niki.xxread/app_update');

  final Dio _dio;

  Future<String> downloadAndInstall(
    WebsiteReleaseAsset asset, {
    UpdateDownloadProgress? onProgress,
    CancelToken? cancelToken,
  }) async {
    if (!Platform.isAndroid) {
      throw const AppUpdateException(AppUpdateFailure.unsupported);
    }
    if (!isValidOfficialApkFileSize(asset.fileSize)) {
      throw const AppUpdateException(AppUpdateFailure.fileSize);
    }
    if (cancelToken?.isCancelled == true) {
      throw const AppUpdateException(AppUpdateFailure.cancelled);
    }

    final cacheDirectory = await getTemporaryDirectory();
    final updatesDirectory = Directory('${cacheDirectory.path}/updates');
    await updatesDirectory.create(recursive: true);
    await _clearOldUpdateFiles(updatesDirectory);
    final safeVersion =
        asset.buildNumber.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final baseName = safeVersion.isEmpty
        ? 'open-reading-update'
        : 'open-reading-$safeVersion';
    final partialFile = File('${updatesDirectory.path}/$baseName.apk.part');
    final apkFile = File('${updatesDirectory.path}/$baseName.apk');
    final internalCancelToken = CancelToken();
    _DownloadCancellation? cancellation;
    var active = true;
    final externalCancellation = cancelToken?.whenCancel;
    if (externalCancellation != null) {
      unawaited(
        externalCancellation.then((_) {
          if (!active || internalCancelToken.isCancelled) return;
          cancellation = _DownloadCancellation.user;
          internalCancelToken.cancel('Cancelled by user');
        }),
      );
    }

    try {
      try {
        var currentUrl = asset.downloadUrl;
        var completed = false;
        for (var redirectCount = 0; redirectCount <= 5; redirectCount++) {
          if (!_isAllowedDownloadUri(currentUrl)) {
            throw const AppUpdateException(AppUpdateFailure.download);
          }
          await partialFile.deleteIfExists();
          final response = await _dio.download(
            currentUrl.toString(),
            partialFile.path,
            cancelToken: internalCancelToken,
            deleteOnError: false,
            onReceiveProgress: (received, total) {
              if (isUpdateDownloadProgressOverLimit(
                received: received,
                total: total,
                expectedFileSize: asset.fileSize,
              )) {
                if (!internalCancelToken.isCancelled) {
                  cancellation = _DownloadCancellation.limit;
                  internalCancelToken.cancel('Update download exceeded limit');
                }
                return;
              }
              onProgress?.call(received, total);
            },
            options: Options(
              followRedirects: false,
              validateStatus: (status) =>
                  status != null && status >= 200 && status < 400,
              headers: const {
                'Accept': 'application/vnd.android.package-archive',
              },
            ),
          );
          final status = response.statusCode ?? 0;
          if (status >= 300 && status < 400) {
            final location = response.headers.value('location');
            if (location == null || redirectCount == 5) {
              throw const AppUpdateException(AppUpdateFailure.download);
            }
            currentUrl = currentUrl.resolve(location);
            continue;
          }
          if (status < 200 ||
              status >= 300 ||
              !_isAllowedDownloadUri(response.realUri)) {
            throw const AppUpdateException(AppUpdateFailure.download);
          }
          completed = true;
          break;
        }
        if (!completed) {
          throw const AppUpdateException(AppUpdateFailure.download);
        }
      } on AppUpdateException {
        rethrow;
      } on DioException catch (error) {
        if (cancellation == _DownloadCancellation.limit) {
          throw AppUpdateException(AppUpdateFailure.fileSize, error);
        }
        if (cancellation == _DownloadCancellation.user ||
            CancelToken.isCancel(error)) {
          throw AppUpdateException(AppUpdateFailure.cancelled, error);
        }
        throw AppUpdateException(AppUpdateFailure.download, error);
      }

      final actualSize = await partialFile.length();
      if (actualSize != asset.fileSize) {
        throw AppUpdateException(
          AppUpdateFailure.fileSize,
          'Expected ${asset.fileSize} bytes, received $actualSize',
        );
      }

      final digest = await sha256.bind(partialFile.openRead()).first;
      if (digest.toString().toLowerCase() != asset.sha256.toLowerCase()) {
        throw const AppUpdateException(AppUpdateFailure.checksum);
      }

      final completedFile = await partialFile.rename(apkFile.path);
      try {
        return await _channel.invokeMethod<String>(
              'installApk',
              {
                'path': completedFile.path,
                'expectedBuildNumber': asset.buildNumber,
              },
            ) ??
            'installer_opened';
      } on PlatformException catch (error) {
        await completedFile.deleteIfExists();
        throw AppUpdateException(AppUpdateFailure.install, error);
      } catch (error) {
        await completedFile.deleteIfExists();
        throw AppUpdateException(AppUpdateFailure.install, error);
      }
    } finally {
      active = false;
      await partialFile.deleteIfExists();
    }
  }
}

enum _DownloadCancellation { user, limit }

Future<void> _clearOldUpdateFiles(Directory updatesDirectory) async {
  await for (final entity in updatesDirectory.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.path.toLowerCase();
    if (name.endsWith('.apk') || name.endsWith('.apk.part')) {
      await entity.deleteIfExists();
    }
  }
}

bool _isAllowedDownloadUri(Uri uri) =>
    uri.scheme == 'https' && uri.host.toLowerCase() == 'open.xxread.top';

extension on File {
  Future<void> deleteIfExists() async {
    if (await exists()) await delete();
  }
}
