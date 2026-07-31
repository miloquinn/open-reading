import 'dart:io';

import 'package:xxread/book_sources/legado/legado_book_source.dart';
import 'package:xxread/book_sources/legado/legado_runtime.dart';

Future<void> main(List<String> paths) async {
  final runtime = LegadoRuntime();
  try {
    for (final path in paths) {
      final sources =
          parseLegadoSources(File(path).readAsStringSync()).sources
              .where(
                (source) =>
                    const LegadoCompatibilityScanner().scan(source).canRun,
              )
              .toList()
            ..sort(
              (left, right) =>
                  right.lastUpdateTime.compareTo(left.lastUpdateTime),
            );
      for (final source in sources.take(40)) {
        final registered = source.toRegisteredSource();
        try {
          final search = await runtime.search(registered, '斗破苍穹');
          if (search.items.isEmpty) {
            stdout.writeln('EMPTY ${source.name} ${source.url}');
            continue;
          }
          final match = search.items.first;
          try {
            final book = await runtime.getBook(registered, match.id);
            try {
              final chapters = await runtime.getChapters(registered, book.id);
              try {
                final content = await runtime.getChapterContent(
                  registered,
                  bookId: book.id,
                  chapterId: chapters.first.id,
                );
                stdout.writeln(
                  'PASS ${source.name} chapters=${chapters.length} '
                  'content=${content.content.length}',
                );
              } catch (error) {
                stdout.writeln('CONTENT ${source.name} ${source.url}: $error');
              }
            } catch (error) {
              stdout.writeln('TOC ${source.name} ${source.url}: $error');
            }
          } catch (error) {
            stdout.writeln('DETAIL ${source.name} ${source.url}: $error');
          }
        } catch (error) {
          stdout.writeln(
            'SEARCH ${source.name} ${source.url} ${source.searchUrl}: $error',
          );
        }
      }
    }
  } finally {
    runtime.close();
  }
}
