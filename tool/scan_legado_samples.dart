import 'dart:io';

import 'package:xxread/book_sources/legado/legado_book_source.dart';

void main(List<String> paths) {
  for (final path in paths) {
    final parsed = parseLegadoSources(File(path).readAsStringSync());
    final counts = <LegadoCompatibilityLevel, int>{};
    for (final source in parsed.sources) {
      final level = const LegadoCompatibilityScanner().scan(source).level;
      counts[level] = (counts[level] ?? 0) + 1;
    }
    stdout.writeln(
      '${path.split('/').last}: parsed=${parsed.sources.length} '
      'errors=${parsed.errors.length} '
      'supported=${counts[LegadoCompatibilityLevel.supported] ?? 0} '
      'partial=${counts[LegadoCompatibilityLevel.partial] ?? 0} '
      'unsupported=${counts[LegadoCompatibilityLevel.unsupported] ?? 0}',
    );
  }
}
