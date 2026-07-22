import 'dart:convert';
import 'dart:ui';

import 'package:flutter/services.dart';

class ChangelogEntry {
  const ChangelogEntry({required this.version, required this.items});

  final String version;
  final List<String> items;
}

class ChangelogService {
  ChangelogService({AssetBundle? bundle}) : _bundle = bundle ?? rootBundle;

  static const assetPath = 'assets/changelog/changelog.json';

  final AssetBundle _bundle;

  Future<List<ChangelogEntry>> load(Locale locale) async {
    final source = await _bundle.loadString(assetPath);
    return parse(source, locale);
  }

  static List<ChangelogEntry> parse(String source, Locale locale) {
    final decoded = jsonDecode(source);
    if (decoded is! Map<String, dynamic> || decoded['schemaVersion'] != 1) {
      throw const FormatException('Unsupported changelog schema.');
    }

    final rawEntries = decoded['entries'];
    if (rawEntries is! List || rawEntries.isEmpty) {
      throw const FormatException('Changelog entries are missing.');
    }

    final versions = <String>{};
    return List<ChangelogEntry>.unmodifiable(
      rawEntries.indexed.map((indexedEntry) {
        final (index, rawEntry) = indexedEntry;
        if (rawEntry is! Map<String, dynamic>) {
          throw FormatException('Invalid changelog entry at index $index.');
        }

        final version = rawEntry['version'];
        if (version is! String || version.trim().isEmpty) {
          throw FormatException('Invalid changelog version at index $index.');
        }
        final normalizedVersion = version.trim();
        if (!versions.add(normalizedVersion)) {
          throw FormatException(
            'Duplicate changelog version: $normalizedVersion.',
          );
        }

        final notes = rawEntry['notes'];
        if (notes is! Map<String, dynamic>) {
          throw FormatException(
            'Missing localized changelog notes for $normalizedVersion.',
          );
        }

        return ChangelogEntry(
          version: normalizedVersion,
          items: _localizedItems(notes, locale, normalizedVersion),
        );
      }),
    );
  }

  static List<String> _localizedItems(
    Map<String, dynamic> notes,
    Locale locale,
    String version,
  ) {
    final candidates = <String>[
      locale.toLanguageTag(),
      if (locale.countryCode case final countryCode?)
        '${locale.languageCode}-$countryCode',
      locale.languageCode,
      'en',
    ];

    for (final candidate in candidates) {
      final items = _stringItems(notes[candidate]);
      if (items.isNotEmpty) return items;
    }
    for (final value in notes.values) {
      final items = _stringItems(value);
      if (items.isNotEmpty) return items;
    }
    throw FormatException('Changelog notes are empty for $version.');
  }

  static List<String> _stringItems(Object? value) {
    if (value is! List) return const [];
    return List<String>.unmodifiable(
      value
          .whereType<String>()
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty),
    );
  }
}
