import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/services/core/changelog_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'bundled catalog has the same complete history in every locale',
    () async {
      final service = ChangelogService();
      const locales = [
        Locale('en'),
        Locale('zh'),
        Locale('zh', 'TW'),
        Locale('ja'),
      ];

      final catalogs = await Future.wait(locales.map(service.load));
      final versions = catalogs.first.map((entry) => entry.version).toList();

      expect(versions, isNotEmpty);
      for (final catalog in catalogs) {
        expect(catalog.map((entry) => entry.version), versions);
        expect(catalog.every((entry) => entry.items.isNotEmpty), isTrue);
      }
    },
  );

  test('selects the exact locale and falls back to English', () {
    final source = jsonEncode({
      'schemaVersion': 1,
      'entries': [
        {
          'version': '9.1.0',
          'notes': {
            'en': ['English note'],
            'zh-TW': ['繁體中文說明'],
          },
        },
      ],
    });

    final traditional = ChangelogService.parse(
      source,
      const Locale('zh', 'TW'),
    );
    final fallback = ChangelogService.parse(source, const Locale('fr'));

    expect(traditional.single.items, ['繁體中文說明']);
    expect(fallback.single.items, ['English note']);
  });

  test('rejects duplicate versions', () {
    final source = jsonEncode({
      'schemaVersion': 1,
      'entries': [
        {
          'version': '9.1.0',
          'notes': {
            'en': ['First'],
          },
        },
        {
          'version': '9.1.0',
          'notes': {
            'en': ['Duplicate'],
          },
        },
      ],
    });

    expect(
      () => ChangelogService.parse(source, const Locale('en')),
      throwsFormatException,
    );
  });
}
