import 'dart:io';

import 'package:xxread/book_sources/legado/legado_book_source.dart';
import 'package:xxread/book_sources/legado/legado_source_verifier.dart';

Future<void> main(List<String> paths) async {
  final verifier = LegadoSourceVerifier(
    maxCandidates: 120,
    maxAvailable: 5,
    maxConcurrency: 10,
  );
  try {
    for (final path in paths) {
      final parsed = parseLegadoSources(File(path).readAsStringSync());
      final result = await verifier.verify(
        parsed.sources,
        onProgress: (completed, total, available) {
          if (completed % 10 == 0 || completed == total) {
            stdout.writeln(
              '${path.split('/').last}: $completed/$total checked, '
              '$available available',
            );
          }
        },
      );
      for (final source in result.available) {
        stdout.writeln('  PASS ${source.name} ${source.apiBaseUrl}');
      }
    }
  } finally {
    verifier.close();
  }
}
