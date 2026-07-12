import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

class AppRelease {
  const AppRelease({
    required this.version,
    required this.name,
    required this.notes,
    required this.releaseUrl,
    required this.publishedAt,
  });

  final String version;
  final String name;
  final String notes;
  final Uri releaseUrl;
  final DateTime? publishedAt;

  factory AppRelease.fromGithubJson(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String? ?? '').trim();
    final htmlUrl = (json['html_url'] as String? ?? '').trim();
    if (tagName.isEmpty || htmlUrl.isEmpty) {
      throw const FormatException('GitHub release is missing tag or URL');
    }

    return AppRelease(
      version: normalizeVersion(tagName),
      name: (json['name'] as String? ?? tagName).trim(),
      notes: (json['body'] as String? ?? '').trim(),
      releaseUrl: Uri.parse(htmlUrl),
      publishedAt: DateTime.tryParse(
        (json['published_at'] as String? ?? '').trim(),
      ),
    );
  }
}

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.currentVersion,
    required this.latestRelease,
  });

  final String currentVersion;
  final AppRelease latestRelease;

  bool get hasUpdate =>
      compareVersions(latestRelease.version, currentVersion) > 0;
}

class UpdateCheckService {
  UpdateCheckService({Dio? dio})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  'Accept': 'application/vnd.github+json',
                  'X-GitHub-Api-Version': '2022-11-28',
                  if (!kIsWeb) 'User-Agent': 'OpenReading-UpdateCheck',
                },
              ),
            );

  static const latestReleaseUrl =
      'https://api.github.com/repos/miloquinn/open-reading/releases/latest';

  final Dio _dio;

  Future<UpdateCheckResult> check({String? currentVersion}) async {
    final installedVersion = normalizeVersion(
      currentVersion ?? (await PackageInfo.fromPlatform()).version,
    );
    final response = await _dio.get<Map<String, dynamic>>(latestReleaseUrl);
    final data = response.data;
    if (data == null) {
      throw const FormatException('GitHub returned an empty release');
    }

    return UpdateCheckResult(
      currentVersion: installedVersion,
      latestRelease: AppRelease.fromGithubJson(data),
    );
  }
}

String normalizeVersion(String value) {
  final trimmed = value.trim();
  if (trimmed.startsWith('v') || trimmed.startsWith('V')) {
    return trimmed.substring(1);
  }
  return trimmed;
}

int compareVersions(String left, String right) {
  final leftVersion = _ParsedVersion.parse(left);
  final rightVersion = _ParsedVersion.parse(right);

  for (var index = 0; index < 3; index++) {
    final difference = leftVersion.numbers[index] - rightVersion.numbers[index];
    if (difference != 0) return difference.sign;
  }

  if (leftVersion.preRelease == null && rightVersion.preRelease != null) {
    return 1;
  }
  if (leftVersion.preRelease != null && rightVersion.preRelease == null) {
    return -1;
  }
  return _comparePreRelease(
    leftVersion.preRelease,
    rightVersion.preRelease,
  );
}

int _comparePreRelease(String? left, String? right) {
  if (left == null && right == null) return 0;
  final leftParts = left!.split('.');
  final rightParts = right!.split('.');
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < length; index++) {
    if (index >= leftParts.length) return -1;
    if (index >= rightParts.length) return 1;
    final leftNumber = int.tryParse(leftParts[index]);
    final rightNumber = int.tryParse(rightParts[index]);
    if (leftNumber != null && rightNumber != null) {
      if (leftNumber != rightNumber) return (leftNumber - rightNumber).sign;
      continue;
    }
    if (leftNumber != null) return -1;
    if (rightNumber != null) return 1;
    final comparison = leftParts[index].compareTo(rightParts[index]);
    if (comparison != 0) return comparison.sign;
  }
  return 0;
}

class _ParsedVersion {
  const _ParsedVersion(this.numbers, this.preRelease);

  final List<int> numbers;
  final String? preRelease;

  factory _ParsedVersion.parse(String value) {
    final normalized = normalizeVersion(value).split('+').first;
    final separator = normalized.indexOf('-');
    final numericPart =
        separator == -1 ? normalized : normalized.substring(0, separator);
    final preRelease =
        separator == -1 ? null : normalized.substring(separator + 1).trim();
    final rawNumbers = numericPart.split('.');
    final numbers = List<int>.generate(
      3,
      (index) =>
          index < rawNumbers.length ? int.tryParse(rawNumbers[index]) ?? 0 : 0,
    );
    return _ParsedVersion(
        numbers, preRelease?.isEmpty == true ? null : preRelease);
  }
}
