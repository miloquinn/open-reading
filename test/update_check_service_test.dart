import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/core/app_update_download_service.dart';
import 'package:xxread/services/core/update_check_service.dart';

void main() {
  group('compareVersions', () {
    test('compares stable semantic versions', () {
      expect(compareVersions('v1.2.0', '1.1.9'), greaterThan(0));
      expect(compareVersions('1.0', '1.0.0'), 0);
      expect(compareVersions('0.9.1', '0.10.0'), lessThan(0));
    });

    test('treats stable versions as newer than prereleases', () {
      expect(compareVersions('1.0.0', '1.0.0-beta.2'), greaterThan(0));
      expect(compareVersions('1.0.0-beta.2', '1.0.0-beta.1'), greaterThan(0));
    });
  });

  test('parses the GitHub release payload used by the update dialog', () {
    final release = AppRelease.fromGithubJson({
      'tag_name': 'v1.2.3',
      'name': 'Open Reading v1.2.3',
      'body': 'Bug fixes and improvements',
      'html_url':
          'https://github.com/miloquinn/open-reading/releases/tag/v1.2.3',
      'published_at': '2026-07-12T00:00:00Z',
    });

    expect(release.version, '1.2.3');
    expect(release.notes, 'Bug fixes and improvements');
    expect(release.releaseUrl.host, 'github.com');
    expect(release.publishedAt, DateTime.utc(2026, 7, 12));
  });

  test('parses and validates official website APK metadata', () {
    final release = AppRelease.fromWebsiteJson(
      {
        'schema_version': 1,
        'version': '2.2.0',
        'build_number': '14119',
        'platform': 'android',
        'architecture': 'arm64-v8a',
        'package_type': 'apk',
        'release_notes': 'Official website updates.',
        'download_url':
            'https://open.xxread.top/download/file/open-reading-arm64.apk',
        'github_release_url':
            'https://github.com/miloquinn/open-reading/releases/tag/v2.2.0',
        'website_url': 'https://open.xxread.top/download',
        'sha256': 'a' * 64,
        'file_size': 63400000,
        'published_at': '2026-07-19T00:00:00Z',
        'mandatory': false,
      },
      targetPlatform: 'android',
      targetArchitecture: 'arm64-v8a',
    );

    expect(release.version, '2.2.0');
    expect(release.releaseUrl.host, 'github.com');
    expect(release.websiteAsset?.architecture, 'arm64-v8a');
    expect(release.websiteAsset?.fileSize, 63400000);
  });

  test('rejects APK download URLs outside the official HTTPS host', () {
    expect(
      () => AppRelease.fromWebsiteJson({
        'version': '2.2.0',
        'build_number': '14119',
        'platform': 'android',
        'architecture': 'arm64-v8a',
        'package_type': 'apk',
        'download_url': 'https://example.com/open-reading.apk',
        'github_release_url':
            'https://github.com/miloquinn/open-reading/releases/tag/v2.2.0',
        'website_url': 'https://open.xxread.top/download',
        'sha256': 'a' * 64,
        'file_size': 42,
      }),
      throwsFormatException,
    );
  });

  test('rejects official metadata for the wrong platform or ABI', () {
    expect(
      () => AppRelease.fromWebsiteJson(
        {..._websitePayload(), 'platform': 'windows'},
        targetPlatform: 'android',
        targetArchitecture: 'arm64-v8a',
      ),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromWebsiteJson(
        {..._websitePayload(), 'architecture': 'x86_64'},
        targetPlatform: 'android',
        targetArchitecture: 'arm64-v8a',
      ),
      throwsFormatException,
    );
  });

  test('rejects an assets payload without an exact ABI match', () {
    final topLevel = _websitePayload()
      ..remove('architecture')
      ..remove('download_url')
      ..remove('sha256')
      ..remove('file_size')
      ..['assets'] = [
        {
          'platform': 'android',
          'architecture': 'x86_64',
          'package_type': 'apk',
          'build_number': '16119',
          'download_url':
              'https://open.xxread.top/download/file/open-reading-x64.apk',
          'sha256': 'b' * 64,
          'file_size': 42,
        },
      ];

    expect(
      () => AppRelease.fromWebsiteJson(
        topLevel,
        targetPlatform: 'android',
        targetArchitecture: 'arm64-v8a',
      ),
      throwsFormatException,
    );
  });

  test('rejects GitHub links outside the canonical repository', () {
    expect(
      () => AppRelease.fromGithubJson({
        'tag_name': 'v2.2.0',
        'html_url':
            'https://github.com/attacker/open-reading/releases/tag/v2.2.0',
      }),
      throwsFormatException,
    );
    expect(
      () => AppRelease.fromWebsiteJson({
        ..._websitePayload(),
        'github_release_url':
            'https://github.com/attacker/open-reading/releases/tag/v2.2.0',
      }),
      throwsFormatException,
    );
  });

  test('selects the higher source version and merges equal releases', () {
    final website = AppRelease.fromWebsiteJson(
      _websitePayload(),
      targetPlatform: 'android',
      targetArchitecture: 'arm64-v8a',
    );
    AppRelease github(String version) => AppRelease(
          version: version,
          name: 'Open Reading v$version',
          notes: 'GitHub notes',
          releaseUrl: Uri.parse(
            'https://github.com/miloquinn/open-reading/releases/tag/v$version',
          ),
          publishedAt: null,
        );

    expect(
      selectLatestRelease(website: website, github: github('2.1.0')),
      same(website),
    );
    expect(
      selectLatestRelease(website: website, github: github('2.3.0'))
          .websiteAsset,
      isNull,
    );
    expect(
      selectLatestRelease(website: website, github: github('2.2.0'))
          .websiteAsset
          ?.architecture,
      'arm64-v8a',
    );
  });

  test('rejects official APK metadata above the hard size limit', () {
    expect(
      () => AppRelease.fromWebsiteJson(
        {
          ..._websitePayload(),
          'file_size': maxOfficialApkSizeBytes + 1,
        },
        targetPlatform: 'android',
        targetArchitecture: 'arm64-v8a',
      ),
      throwsFormatException,
    );
  });

  test('detects received bytes or content length above metadata immediately',
      () {
    expect(
      isUpdateDownloadProgressOverLimit(
        received: 101,
        total: -1,
        expectedFileSize: 100,
      ),
      isTrue,
    );
    expect(
      isUpdateDownloadProgressOverLimit(
        received: 1,
        total: 101,
        expectedFileSize: 100,
      ),
      isTrue,
    );
    expect(
      isUpdateDownloadProgressOverLimit(
        received: 100,
        total: 100,
        expectedFileSize: 100,
      ),
      isFalse,
    );
  });
}

Map<String, dynamic> _websitePayload() => {
      'schema_version': 1,
      'version': '2.2.0',
      'build_number': '14119',
      'platform': 'android',
      'architecture': 'arm64-v8a',
      'package_type': 'apk',
      'release_notes': 'Official website updates.',
      'download_url':
          'https://open.xxread.top/download/file/open-reading-arm64.apk',
      'github_release_url':
          'https://github.com/miloquinn/open-reading/releases/tag/v2.2.0',
      'website_url': 'https://open.xxread.top/download',
      'sha256': 'a' * 64,
      'file_size': 63400000,
      'published_at': '2026-07-19T00:00:00Z',
      'mandatory': false,
    };
