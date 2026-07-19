import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'app_update_download_policy.dart';

class WebsiteReleaseAsset {
  const WebsiteReleaseAsset({
    required this.downloadUrl,
    required this.websiteUrl,
    required this.sha256,
    required this.fileSize,
    required this.platform,
    required this.architecture,
    required this.packageType,
    required this.buildNumber,
    required this.mandatory,
  });

  final Uri downloadUrl;
  final Uri websiteUrl;
  final String sha256;
  final int fileSize;
  final String platform;
  final String architecture;
  final String packageType;
  final String buildNumber;
  final bool mandatory;
}

class AppRelease {
  const AppRelease({
    required this.version,
    required this.name,
    required this.notes,
    required this.releaseUrl,
    required this.publishedAt,
    this.websiteAsset,
  });

  final String version;
  final String name;
  final String notes;
  final Uri releaseUrl;
  final DateTime? publishedAt;
  final WebsiteReleaseAsset? websiteAsset;

  factory AppRelease.fromGithubJson(Map<String, dynamic> json) {
    final tagName = (json['tag_name'] as String? ?? '').trim();
    final htmlUrl = (json['html_url'] as String? ?? '').trim();
    if (!_isValidVersion(normalizeVersion(tagName)) ||
        !_isAllowedGithubReleaseUrl(htmlUrl)) {
      throw const FormatException('GitHub release is missing tag or HTTPS URL');
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

  factory AppRelease.fromWebsiteJson(
    Map<String, dynamic> json, {
    String? targetPlatform,
    String? targetArchitecture,
  }) {
    final releasePayload = json['release'] is Map<String, dynamic>
        ? json['release'] as Map<String, dynamic>
        : json;
    final assets = releasePayload['assets'];
    final assetMaps = assets is List
        ? assets
            .whereType<Map>()
            .map(Map<String, dynamic>.from)
            .toList(growable: false)
        : const <Map<String, dynamic>>[];
    Map<String, dynamic>? firstAsset;
    for (final asset in assetMaps) {
      final assetPlatform = _string(asset, 'platform');
      final assetArchitecture = _string(asset, 'architecture');
      if ((targetPlatform == null || assetPlatform == targetPlatform) &&
          (targetArchitecture == null ||
              assetArchitecture == targetArchitecture)) {
        firstAsset = asset;
        break;
      }
    }
    if (assetMaps.isNotEmpty && firstAsset == null) {
      throw const FormatException('Website release has no matching asset');
    }
    final payload = <String, dynamic>{
      ...releasePayload,
      ...?firstAsset,
    };
    final version =
        normalizeVersion(_firstString(payload, ['version', 'tag_name']));
    final githubUrl =
        _firstString(payload, ['github_release_url', 'github_url', 'html_url']);
    final downloadUrl =
        _firstString(payload, ['download_url', 'file_url', 'url']);
    final websiteUrl = _firstString(payload, ['website_url']).isEmpty
        ? 'https://open.xxread.top/download'
        : _firstString(payload, ['website_url']);
    final sha256 = _string(payload, 'sha256').toLowerCase();
    final fileSize = _integer(payload['file_size'] ?? payload['size']);
    final platform = _string(payload, 'platform');
    final architecture = _string(payload, 'architecture');
    final packageType = _string(payload, 'package_type');
    final buildNumber = _string(payload, 'build_number');
    final parsedBuildNumber = int.tryParse(buildNumber) ?? 0;
    if (!_isValidVersion(version) ||
        !_isAllowedGithubReleaseUrl(githubUrl) ||
        !_isAllowedOfficialUrl(downloadUrl) ||
        !_isAllowedOfficialUrl(websiteUrl) ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(sha256) ||
        !isValidOfficialApkFileSize(fileSize) ||
        platform.isEmpty ||
        packageType.isEmpty ||
        parsedBuildNumber <= 0 ||
        (targetPlatform != null && platform != targetPlatform) ||
        (targetPlatform == 'android' &&
            (targetArchitecture == null ||
                architecture != targetArchitecture ||
                packageType != 'apk'))) {
      throw const FormatException('Website release metadata is incomplete');
    }

    return AppRelease(
      version: version,
      name: 'Open Reading v$version',
      notes: _firstString(payload, ['release_notes', 'notes', 'body']),
      releaseUrl: Uri.parse(githubUrl),
      publishedAt: DateTime.tryParse(_string(payload, 'published_at')),
      websiteAsset: WebsiteReleaseAsset(
        downloadUrl: Uri.parse(downloadUrl),
        websiteUrl: Uri.parse(websiteUrl),
        sha256: sha256,
        fileSize: fileSize,
        platform: platform,
        architecture: architecture,
        packageType: packageType,
        buildNumber: buildNumber,
        mandatory: payload['mandatory'] == true,
      ),
    );
  }

  AppRelease withWebsiteAsset(WebsiteReleaseAsset asset) => AppRelease(
        version: version,
        name: name,
        notes: notes,
        releaseUrl: releaseUrl,
        publishedAt: publishedAt,
        websiteAsset: asset,
      );
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

typedef UpdateTargetResolver = Future<UpdateTarget> Function();

class UpdateTarget {
  const UpdateTarget({required this.platform, this.architecture});

  final String platform;
  final String? architecture;

  static const _channel = MethodChannel('com.niki.xxread/app_update');

  static Future<UpdateTarget> current() async {
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.fuchsia => 'fuchsia',
    };
    if (platform != 'android' || kIsWeb) {
      return UpdateTarget(platform: platform);
    }
    final abis = await _channel
            .invokeListMethod<String>('getSupportedAbis')
            .catchError((_) => null) ??
        const <String>[];
    return UpdateTarget(
      platform: platform,
      architecture: _preferredAndroidAbi(abis),
    );
  }
}

class UpdateCheckService {
  UpdateCheckService({Dio? dio, UpdateTargetResolver? targetResolver})
      : _dio = dio ??
            Dio(
              BaseOptions(
                connectTimeout: const Duration(seconds: 8),
                receiveTimeout: const Duration(seconds: 8),
                headers: {
                  if (!kIsWeb) 'User-Agent': 'OpenReading-UpdateCheck',
                },
              ),
            ),
        _targetResolver = targetResolver ?? UpdateTarget.current;

  static const githubLatestReleaseUrl =
      'https://api.github.com/repos/miloquinn/open-reading/releases/latest';
  static const websiteLatestReleaseUrl =
      'https://open.xxread.top/api/v1/releases/latest';

  final Dio _dio;
  final UpdateTargetResolver _targetResolver;

  Future<UpdateCheckResult> check({String? currentVersion}) async {
    final installedVersion = normalizeVersion(
      currentVersion ?? (await PackageInfo.fromPlatform()).version,
    );
    UpdateTarget? target;
    try {
      target = await _targetResolver();
    } catch (_) {
      target = null;
    }
    final releases = await Future.wait<AppRelease?>([
      target == null
          ? Future<AppRelease?>.value()
          : _fetchWebsiteRelease(target),
      _fetchGithubRelease(),
    ]);
    final website = releases[0];
    final github = releases[1];
    final latest = selectLatestRelease(website: website, github: github);

    return UpdateCheckResult(
      currentVersion: installedVersion,
      latestRelease: latest,
    );
  }

  Future<AppRelease?> _fetchWebsiteRelease(UpdateTarget target) async {
    if (target.platform == 'android' && target.architecture == null) {
      return null;
    }
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        websiteLatestReleaseUrl,
        queryParameters: {
          'platform': target.platform,
          if (target.architecture case final architecture?)
            'architecture': architecture,
          'channel': 'stable',
        },
        options: Options(headers: {'Accept': 'application/json'}),
      );
      final data = response.data;
      return data == null
          ? null
          : AppRelease.fromWebsiteJson(
              data,
              targetPlatform: target.platform,
              targetArchitecture: target.architecture,
            );
    } catch (_) {
      return null;
    }
  }

  Future<AppRelease?> _fetchGithubRelease() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        githubLatestReleaseUrl,
        options: Options(
          headers: {
            'Accept': 'application/vnd.github+json',
            'X-GitHub-Api-Version': '2022-11-28',
          },
        ),
      );
      final data = response.data;
      return data == null ? null : AppRelease.fromGithubJson(data);
    } catch (_) {
      return null;
    }
  }
}

AppRelease selectLatestRelease({AppRelease? website, AppRelease? github}) {
  if (website == null && github == null) {
    throw const FormatException('No valid update source is available');
  }
  if (website == null) return github!;
  if (github == null) return website;

  final comparison = compareVersions(website.version, github.version);
  if (comparison > 0) return website;
  if (comparison < 0) return github;
  if (website.websiteAsset == null) return github;

  var latest = github.withWebsiteAsset(website.websiteAsset!);
  if (latest.notes.isEmpty && website.notes.isNotEmpty) {
    latest = AppRelease(
      version: latest.version,
      name: latest.name,
      notes: website.notes,
      releaseUrl: latest.releaseUrl,
      publishedAt: latest.publishedAt ?? website.publishedAt,
      websiteAsset: latest.websiteAsset,
    );
  }
  return latest;
}

String? _preferredAndroidAbi(List<String> abis) {
  const supported = ['arm64-v8a', 'armeabi-v7a', 'x86_64'];
  for (final abi in abis) {
    if (supported.contains(abi)) return abi;
  }
  return null;
}

String _string(Map<String, dynamic> json, String key) =>
    (json[key]?.toString() ?? '').trim();

String _firstString(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    final value = _string(json, key);
    if (value.isNotEmpty) return value;
  }
  return '';
}

int _integer(Object? value) => switch (value) {
      int number => number,
      num number => number.toInt(),
      _ => int.tryParse(value?.toString() ?? '') ?? 0,
    };

bool _isAllowedGithubReleaseUrl(String value) {
  final uri = Uri.tryParse(value);
  final path = uri?.path.toLowerCase() ?? '';
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.toLowerCase() == 'github.com' &&
      (path == '/miloquinn/open-reading/releases' ||
          path.startsWith('/miloquinn/open-reading/releases/'));
}

bool _isAllowedOfficialUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null &&
      uri.scheme == 'https' &&
      uri.host.toLowerCase() == 'open.xxread.top';
}

bool _isValidVersion(String value) => RegExp(
      r'^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$',
    ).hasMatch(value);

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
      numbers,
      preRelease?.isEmpty == true ? null : preRelease,
    );
  }
}
