import 'dart:convert';
import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;
import 'package:xxread/services/books/epub_native_parser.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tool/benchmark_epub_native_parser.dart '
      '[--full] <book.epub> [...book.epub]',
    );
    exitCode = 64;
    return;
  }
  final full = arguments.contains('--full');
  final books = arguments.where((argument) => argument != '--full').toList();
  for (final bookPath in books) {
    final source = File(bookPath);
    if (!source.existsSync()) {
      stderr.writeln('Missing EPUB: $bookPath');
      exitCode = 66;
      continue;
    }
    await _benchmark(source, full: full);
  }
}

Future<void> _benchmark(File source, {required bool full}) async {
  final cache = Directory.systemTemp.createTempSync('open-reading-epub-bench-');
  try {
    final sourceSize = source.lengthSync();
    final sourceModifiedMillis = source
        .lastModifiedSync()
        .millisecondsSinceEpoch;
    final common = <String, dynamic>{
      'epubPath': source.path,
      'cacheDirectory': cache.path,
      'indexPath': path.join(cache.path, 'index.json'),
      'sourceSize': sourceSize,
      'sourceModifiedMillis': sourceModifiedMillis,
      'familyPrefix': 'benchmark',
    };

    final coldIndexWatch = Stopwatch()..start();
    final metadataWatch = Stopwatch()..start();
    final metadata = extractEpubNativeMetadata(<String, dynamic>{
      'epubPath': source.path,
    });
    metadataWatch.stop();
    final index = buildEpubNativeIndex(common);
    coldIndexWatch.stop();
    final chapters = (index['chapters'] as List<dynamic>).cast<Map>();
    final navigation = (index['navigation'] as List<dynamic>? ?? const [])
        .cast<Map>();
    final firstWindow = chapters.take(7).toList(growable: false);

    final coldWindowWatch = Stopwatch()..start();
    final coldWindow = loadEpubNativeChapterWindow(<String, dynamic>{
      ...common,
      'cssPaths': index['cssPaths'],
      'chapters': firstWindow,
    });
    coldWindowWatch.stop();

    final warmIndexWatch = Stopwatch()..start();
    final warmIndex = readEpubNativeIndex(common);
    warmIndexWatch.stop();
    if (warmIndex == null) {
      throw StateError('Warm index was not reusable.');
    }

    final warmWindowWatch = Stopwatch()..start();
    final warmWindow = loadEpubNativeChapterWindow(<String, dynamic>{
      ...common,
      'cssPaths': index['cssPaths'],
      'chapters': firstWindow,
    });
    warmWindowWatch.stop();

    final coldStats = _statsForResults(coldWindow['results'] as List<dynamic>);
    final warmStats = _statsForResults(warmWindow['results'] as List<dynamic>);
    if (coldStats != warmStats) {
      throw StateError('Cold and warm chapter results differ.');
    }

    stdout.writeln('BOOK ${source.path}');
    stdout.writeln(
      'size=${(sourceSize / 1024 / 1024).toStringAsFixed(1)}MB '
      'chapters=${chapters.length} navigation=${navigation.length}',
    );
    stdout.writeln(
      'metadata_ms=${metadataWatch.elapsedMilliseconds} '
      'title=${jsonEncode(metadata['title'])} '
      'author=${jsonEncode(metadata['author'])} '
      'metadata_chapters=${(metadata['additionalInfo'] as Map)['chapterCount']} '
      'cover_bytes=${(metadata['coverImage'] as List<int>?)?.length ?? 0} '
      'estimated_pages=${metadata['estimatedPages']}',
    );
    stdout.writeln(
      'cold_index_ms=${coldIndexWatch.elapsedMilliseconds} '
      'cold_first7_ms=${coldWindowWatch.elapsedMilliseconds} '
      'warm_index_ms=${warmIndexWatch.elapsedMilliseconds} '
      'warm_first7_ms=${warmWindowWatch.elapsedMilliseconds}',
    );
    stdout.writeln('first7=$coldStats');
    stdout.writeln(
      'navigation_first15=${jsonEncode(navigation.take(15).toList())}',
    );

    if (full) {
      final fullWatch = Stopwatch()..start();
      final parsed = loadEpubNativeChapters(<String, dynamic>{
        ...common,
        'cssPaths': index['cssPaths'],
        'chapters': chapters,
      });
      fullWatch.stop();
      final results = (parsed['chapters'] as List<dynamic>).cast<Map>();
      final audit = _auditText(source, chapters, results);
      final stats = _statsForChapters(results);
      stdout.writeln(
        'full_parse_ms=${fullWatch.elapsedMilliseconds} '
        'text_audit=$audit',
      );
      stdout.writeln('full=$stats');
      if (audit.mismatches != 0 || audit.missingResources != 0) {
        exitCode = 1;
      }
    }
  } finally {
    if (cache.existsSync()) cache.deleteSync(recursive: true);
  }
}

_EpubStats _statsForResults(List<dynamic> results) => _statsForChapters(
  results
      .map((result) => Map<String, dynamic>.from(result as Map))
      .map((result) => Map<String, dynamic>.from(result['chapter'] as Map))
      .toList(growable: false),
);

_EpubStats _statsForChapters(List<Map> chapters) {
  var characters = 0;
  var textBlocks = 0;
  var headings = 0;
  var bold = 0;
  var italic = 0;
  var fontRuns = 0;
  var imageBlocks = 0;
  final imageResources = <String>{};
  final fontFamilies = <String>{};
  for (final chapter in chapters) {
    characters += (chapter['plainText'] as String).length;
    for (final rawBlock in chapter['blocks'] as List<dynamic>) {
      final block = rawBlock as Map;
      if (block['type'] == 'image') {
        imageBlocks++;
        final resource = block['resourcePath'] as String?;
        if (resource != null) imageResources.add(resource);
        continue;
      }
      textBlocks++;
      if ((block['fontScale'] as num? ?? 1) > 1) headings++;
      if (block['bold'] == true) bold++;
      if (block['italic'] == true) italic++;
      final family = block['fontFamily'] as String?;
      if (family != null) {
        fontRuns++;
        fontFamilies.add(family);
      }
    }
  }
  return _EpubStats(
    characters: characters,
    textBlocks: textBlocks,
    headingRuns: headings,
    boldRuns: bold,
    italicRuns: italic,
    fontRuns: fontRuns,
    fontFamilies: fontFamilies.length,
    imageBlocks: imageBlocks,
    imageResources: imageResources.length,
  );
}

_TextAudit _auditText(File source, List<Map> descriptors, List<Map> chapters) {
  final input = InputFileStream(source.path);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    final files = <String, ArchiveFile>{
      for (final file in archive.files.where((file) => file.isFile))
        path.posix.normalize(_decodeEpubPath(file.name)): file,
    };
    var mismatches = 0;
    var missingResources = 0;
    var sourceCharacters = 0;
    var parsedCharacters = 0;
    for (var index = 0; index < descriptors.length; index++) {
      final archivePath = descriptors[index]['archivePath'] as String;
      final file = files[archivePath];
      if (file == null) {
        missingResources++;
        continue;
      }
      final html = utf8.decode(
        file.content as List<int>,
        allowMalformed: false,
      );
      final sourceText = _withoutWhitespace(
        html_parser.parse(html).body?.text ?? '',
      );
      final parsedText = _withoutWhitespace(
        chapters[index]['plainText'] as String,
      );
      sourceCharacters += sourceText.length;
      parsedCharacters += parsedText.length;
      if (sourceText != parsedText) mismatches++;
    }
    return _TextAudit(
      sourceCharacters: sourceCharacters,
      parsedCharacters: parsedCharacters,
      mismatches: mismatches,
      missingResources: missingResources,
    );
  } finally {
    input.closeSync();
  }
}

String _withoutWhitespace(String value) => value.replaceAll(RegExp(r'\s+'), '');

String _decodeEpubPath(String value) {
  final output = StringBuffer();
  var index = 0;
  while (index < value.length) {
    if (!_hasPercentByteAt(value, index)) {
      output.write(value[index]);
      index++;
      continue;
    }
    final start = index;
    final bytes = <int>[];
    while (_hasPercentByteAt(value, index)) {
      bytes.add(int.parse(value.substring(index + 1, index + 3), radix: 16));
      index += 3;
    }
    try {
      output.write(utf8.decode(bytes, allowMalformed: false));
    } on FormatException {
      output.write(value.substring(start, index));
    }
  }
  return output.toString();
}

bool _hasPercentByteAt(String value, int index) =>
    index + 2 < value.length &&
    value.codeUnitAt(index) == 0x25 &&
    _isHexDigit(value.codeUnitAt(index + 1)) &&
    _isHexDigit(value.codeUnitAt(index + 2));

bool _isHexDigit(int codeUnit) =>
    (codeUnit >= 0x30 && codeUnit <= 0x39) ||
    (codeUnit >= 0x41 && codeUnit <= 0x46) ||
    (codeUnit >= 0x61 && codeUnit <= 0x66);

class _EpubStats {
  const _EpubStats({
    required this.characters,
    required this.textBlocks,
    required this.headingRuns,
    required this.boldRuns,
    required this.italicRuns,
    required this.fontRuns,
    required this.fontFamilies,
    required this.imageBlocks,
    required this.imageResources,
  });

  final int characters;
  final int textBlocks;
  final int headingRuns;
  final int boldRuns;
  final int italicRuns;
  final int fontRuns;
  final int fontFamilies;
  final int imageBlocks;
  final int imageResources;

  @override
  bool operator ==(Object other) =>
      other is _EpubStats &&
      other.characters == characters &&
      other.textBlocks == textBlocks &&
      other.headingRuns == headingRuns &&
      other.boldRuns == boldRuns &&
      other.italicRuns == italicRuns &&
      other.fontRuns == fontRuns &&
      other.fontFamilies == fontFamilies &&
      other.imageBlocks == imageBlocks &&
      other.imageResources == imageResources;

  @override
  int get hashCode => Object.hash(
    characters,
    textBlocks,
    headingRuns,
    boldRuns,
    italicRuns,
    fontRuns,
    fontFamilies,
    imageBlocks,
    imageResources,
  );

  @override
  String toString() =>
      'chars=$characters text=$textBlocks headings=$headingRuns bold=$boldRuns '
      'italic=$italicRuns font_runs=$fontRuns font_families=$fontFamilies '
      'image_blocks=$imageBlocks image_resources=$imageResources';
}

class _TextAudit {
  const _TextAudit({
    required this.sourceCharacters,
    required this.parsedCharacters,
    required this.mismatches,
    required this.missingResources,
  });

  final int sourceCharacters;
  final int parsedCharacters;
  final int mismatches;
  final int missingResources;

  @override
  String toString() =>
      'source_chars=$sourceCharacters parsed_chars=$parsedCharacters '
      'mismatches=$mismatches missing_resources=$missingResources';
}
