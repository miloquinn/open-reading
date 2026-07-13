import 'dart:convert';

class LegadoBookSource {
  final Map<String, dynamic> raw;

  const LegadoBookSource._(this.raw);

  factory LegadoBookSource.fromJson(Map<String, dynamic> json) {
    final normalized = <String, dynamic>{
      for (final entry in json.entries) entry.key: entry.value,
    };
    if (_string(normalized['bookSourceUrl']).isEmpty ||
        _string(normalized['bookSourceName']).isEmpty) {
      throw const FormatException(
        'Legado source requires bookSourceUrl and bookSourceName.',
      );
    }
    return LegadoBookSource._(Map.unmodifiable(normalized));
  }

  String get url => _string(raw['bookSourceUrl']);
  String get name => _string(raw['bookSourceName']);
  String get group => _string(raw['bookSourceGroup']);
  int get type => _integer(raw['bookSourceType']);
  String get searchUrl => _string(raw['searchUrl']);
  String get exploreUrl => _string(raw['exploreUrl']);
  bool get enabledCookieJar => raw['enabledCookieJar'] == true;

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}

class LegadoSourceImportResult {
  final List<LegadoBookSource> sources;
  final List<String> errors;

  const LegadoSourceImportResult({
    required this.sources,
    required this.errors,
  });
}

LegadoSourceImportResult parseLegadoSources(String input) {
  final text = input.replaceFirst('\ufeff', '').trim();
  if (text.isEmpty) {
    throw const FormatException('Legado source JSON is empty.');
  }
  final decoded = jsonDecode(text);
  final candidates = _sourceCandidates(decoded);
  final sources = <LegadoBookSource>[];
  final errors = <String>[];
  for (var index = 0; index < candidates.length; index++) {
    final candidate = candidates[index];
    if (candidate is! Map) {
      errors.add('Item ${index + 1} is not a JSON object.');
      continue;
    }
    try {
      sources.add(
        LegadoBookSource.fromJson(
          candidate.map((key, value) => MapEntry('$key', value)),
        ),
      );
    } on FormatException catch (error) {
      errors.add('Item ${index + 1}: ${error.message}');
    }
  }
  if (sources.isEmpty && errors.isEmpty) {
    errors.add('No Legado sources were found.');
  }
  return LegadoSourceImportResult(
    sources: List.unmodifiable(sources),
    errors: List.unmodifiable(errors),
  );
}

List<Object?> _sourceCandidates(Object? decoded) {
  if (decoded is List) return decoded;
  if (decoded is Map) {
    if (decoded.containsKey('bookSourceUrl')) return [decoded];
    for (final key in const ['bookSourceList', 'sources', 'data']) {
      final value = decoded[key];
      if (value is List) return value;
    }
  }
  throw const FormatException(
    'Expected a Legado source object or a list of source objects.',
  );
}

String _string(Object? value) => value is String ? value.trim() : '';

int _integer(Object? value) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? 0;
  return 0;
}
