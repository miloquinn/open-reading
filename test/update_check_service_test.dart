import 'package:flutter_test/flutter_test.dart';
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
}
