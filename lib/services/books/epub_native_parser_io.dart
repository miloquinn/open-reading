// Native EPUB indexing and chapter parsing for the Flutter text reader.
// The index is cheap and persistent; XHTML, images, and fonts are materialized
// one chapter at a time so opening a large book never transfers the whole book
// or every image across an isolate boundary.

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:crypto/crypto.dart';
import 'package:gbk_codec/gbk_codec.dart';
import 'package:html/dom.dart' as html_dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;

const int epubNativeCacheVersion = 3;

Map<String, dynamic> extractEpubNativeMetadata(Map<String, dynamic> arguments) {
  final epubPath = arguments['epubPath'] as String;
  final input = InputFileStream(epubPath);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    final files = _archiveFilesByPath(archive);
    final containerDocument = html_parser.parse(
      _readArchiveText(files, 'META-INF/container.xml'),
    );
    final packagePath = containerDocument
        .querySelector('rootfile')
        ?.attributes['full-path'];
    if (packagePath == null || packagePath.trim().isEmpty) {
      throw const FormatException('EPUB container has no package document.');
    }
    final normalizedPackagePath = _normalizeArchivePath(packagePath);
    final packageDocument = html_parser.parse(
      _readArchiveText(files, normalizedPackagePath),
    );
    final metadata = packageDocument.querySelector('metadata');
    final manifestById = <String, _ManifestEntry>{};
    for (final item in packageDocument.querySelectorAll('manifest item')) {
      final id = item.attributes['id'];
      final href = item.attributes['href'];
      if (id == null || href == null) continue;
      manifestById[id] = _ManifestEntry(
        id: id,
        href: _decodeEpubPath(href),
        archivePath: _resolveArchivePath(normalizedPackagePath, href),
        mediaType: (item.attributes['media-type'] ?? '').toLowerCase(),
        properties: item.attributes['properties'] ?? '',
      );
    }

    _ManifestEntry? cover;
    for (final item in manifestById.values) {
      if (item.properties.split(RegExp(r'\s+')).contains('cover-image')) {
        cover = item;
        break;
      }
    }
    if (cover == null && metadata != null) {
      String? coverId;
      for (final meta in metadata.querySelectorAll('meta')) {
        if ((meta.attributes['name'] ?? '').toLowerCase() == 'cover') {
          coverId = meta.attributes['content'];
          break;
        }
      }
      if (coverId != null) cover = manifestById[coverId];
    }
    final coverFile = cover == null ? null : files[cover.archivePath];
    final coverImage = coverFile == null
        ? null
        : Uint8List.fromList(coverFile.content as List<int>);

    final spine = packageDocument.querySelector('spine');
    final spineEntries = <_ManifestEntry>[];
    for (final itemRef in spine?.querySelectorAll('itemref') ?? const []) {
      final idRef = itemRef.attributes['idref'];
      final item = idRef == null ? null : manifestById[idRef];
      if (item != null && _isHtmlMediaType(item.mediaType)) {
        spineEntries.add(item);
      }
    }
    if (spineEntries.isEmpty) {
      spineEntries.addAll(
        manifestById.values.where((item) => _isHtmlMediaType(item.mediaType)),
      );
    }
    final htmlBytes = spineEntries.fold<int>(
      0,
      (total, item) => total + (files[item.archivePath]?.size ?? 0),
    );

    var description = _metadataText(metadata, 'description');
    if ((description ?? '').trim().isEmpty) {
      for (final item in spineEntries) {
        final file = files[item.archivePath];
        if (file == null) continue;
        final document = html_parser.parse(
          _decodeEpubText(file.content as List<int>),
        );
        final text = document.body?.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text != null && text.isNotEmpty) {
          description = text.length <= 500
              ? text
              : '${text.substring(0, 497)}...';
          break;
        }
      }
    }

    String? isbn;
    for (final identifier in _metadataElements(metadata, 'identifier')) {
      final scheme = _attributeValue(identifier, 'scheme')?.toLowerCase();
      if (scheme?.contains('isbn') == true) {
        isbn = identifier.text.trim();
        break;
      }
    }
    final authors = _metadataElements(metadata, 'creator')
        .map((element) => element.text.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return <String, dynamic>{
      'title': _metadataText(metadata, 'title') ?? '',
      'author': authors.join(', '),
      'description': description,
      'language': _metadataText(metadata, 'language'),
      'publisher': _metadataText(metadata, 'publisher'),
      'publishDate': _metadataText(metadata, 'date'),
      'isbn': isbn,
      'coverImage': coverImage,
      'estimatedPages': (htmlBytes / 3000).ceil().clamp(1, 9999),
      'tags': _metadataElements(metadata, 'subject')
          .map((element) => element.text.trim())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      'additionalInfo': <String, dynamic>{
        'format': 'EPUB',
        'hasImages': manifestById.values.any(
          (item) => item.mediaType.startsWith('image/'),
        ),
        'chapterCount': spineEntries.length,
      },
    };
  } finally {
    input.closeSync();
  }
}

List<html_dom.Element> _metadataElements(
  html_dom.Element? metadata,
  String localName,
) =>
    metadata
        ?.querySelectorAll('*')
        .where((element) {
          final name = (element.localName ?? '').toLowerCase();
          return name == localName || name.endsWith(':$localName');
        })
        .toList(growable: false) ??
    const <html_dom.Element>[];

String? _metadataText(html_dom.Element? metadata, String localName) {
  for (final element in _metadataElements(metadata, localName)) {
    final text = element.text.trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

String? _attributeValue(html_dom.Element element, String localName) {
  for (final entry in element.attributes.entries) {
    final name = entry.key.toString().toLowerCase();
    if (name == localName || name.endsWith(':$localName')) return entry.value;
  }
  return null;
}

html_dom.Element? _nearestAncestor(html_dom.Element element, String localName) {
  var ancestor = element.parent;
  while (ancestor != null) {
    if (ancestor.localName == localName) return ancestor;
    ancestor = ancestor.parent;
  }
  return null;
}

Map<String, dynamic>? readEpubNativeIndex(Map<String, dynamic> arguments) {
  try {
    final file = File(arguments['indexPath'] as String);
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != epubNativeCacheVersion ||
        decoded['sourceSize'] != arguments['sourceSize'] ||
        decoded['sourceModifiedMillis'] != arguments['sourceModifiedMillis']) {
      return null;
    }
    final chapters = decoded['chapters'];
    final navigation = decoded['navigation'];
    final cssPaths = decoded['cssPaths'];
    if (chapters is! List || navigation is! List || cssPaths is! List) {
      return null;
    }
    final cacheDirectory = arguments['cacheDirectory'] as String?;
    if (cacheDirectory != null && cacheDirectory.isNotEmpty) {
      _relocateIndexCachePaths(decoded, cacheDirectory);
    }
    return decoded;
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> buildEpubNativeIndex(Map<String, dynamic> arguments) {
  final epubPath = arguments['epubPath'] as String;
  final cacheDirectory = Directory(arguments['cacheDirectory'] as String)
    ..createSync(recursive: true);
  final sourceFile = File(epubPath);
  final sourceSize = sourceFile.lengthSync();
  final sourceModifiedMillis = sourceFile
      .lastModifiedSync()
      .millisecondsSinceEpoch;
  final input = InputFileStream(epubPath);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    final files = _archiveFilesByPath(archive);
    final container = _readArchiveText(files, 'META-INF/container.xml');
    final containerDocument = html_parser.parse(container);
    final packagePath = containerDocument
        .querySelector('rootfile')
        ?.attributes['full-path'];
    if (packagePath == null || packagePath.trim().isEmpty) {
      throw const FormatException('EPUB container has no package document.');
    }
    final normalizedPackagePath = _normalizeArchivePath(packagePath);
    final packageDocument = html_parser.parse(
      _readArchiveText(files, normalizedPackagePath),
    );

    final manifestById = <String, _ManifestEntry>{};
    for (final item in packageDocument.querySelectorAll('manifest item')) {
      final id = item.attributes['id'];
      final href = item.attributes['href'];
      if (id == null || href == null) continue;
      manifestById[id] = _ManifestEntry(
        id: id,
        href: _decodeEpubPath(href),
        archivePath: _resolveArchivePath(normalizedPackagePath, href),
        mediaType: (item.attributes['media-type'] ?? '').toLowerCase(),
        properties: item.attributes['properties'] ?? '',
      );
    }

    final titleByArchivePath = <String, String>{};
    final depthByArchivePath = <String, int>{};
    var navigationEntries = <_EpubNavigationEntry>[];
    final spine = packageDocument.querySelector('spine');
    final tocId = spine?.attributes['toc'];
    final tocEntry = tocId == null ? null : manifestById[tocId];
    if (tocEntry != null && files.containsKey(tocEntry.archivePath)) {
      navigationEntries = _navigationEntriesFromDocument(
        navigation: html_parser.parse(
          _readArchiveText(files, tocEntry.archivePath),
        ),
        navigationArchivePath: tocEntry.archivePath,
      );
    }
    for (final navEntry in manifestById.values.where(
      (entry) =>
          entry.properties.toLowerCase().split(RegExp(r'\s+')).contains('nav'),
    )) {
      if (!files.containsKey(navEntry.archivePath)) continue;
      final epub3Navigation = _navigationEntriesFromDocument(
        navigation: html_parser.parse(
          _readArchiveText(files, navEntry.archivePath),
        ),
        navigationArchivePath: navEntry.archivePath,
      );
      if (epub3Navigation.isNotEmpty) navigationEntries = epub3Navigation;
    }
    for (final entry in navigationEntries) {
      titleByArchivePath[entry.archivePath] = entry.title;
      depthByArchivePath[entry.archivePath] = entry.depth;
    }

    final orderedReadingEntries = <_ManifestEntry>[];
    for (final itemRef in spine?.querySelectorAll('itemref') ?? const []) {
      final idRef = itemRef.attributes['idref'];
      final manifest = idRef == null ? null : manifestById[idRef];
      if (manifest == null || !_isHtmlMediaType(manifest.mediaType)) continue;
      if (files.containsKey(manifest.archivePath)) {
        orderedReadingEntries.add(manifest);
      }
    }
    if (orderedReadingEntries.isEmpty) {
      orderedReadingEntries.addAll(
        manifestById.values.where(
          (entry) =>
              _isHtmlMediaType(entry.mediaType) &&
              !entry.properties
                  .toLowerCase()
                  .split(RegExp(r'\s+'))
                  .contains('nav') &&
              files.containsKey(entry.archivePath),
        ),
      );
    }

    final cssDirectory = Directory(path.join(cacheDirectory.path, 'styles'))
      ..createSync(recursive: true);
    final cssPaths = <Map<String, dynamic>>[];
    for (final entry in manifestById.values.where(
      (entry) => entry.mediaType == 'text/css',
    )) {
      final archiveFile = files[entry.archivePath];
      if (archiveFile == null) continue;
      final cachePath = path.join(
        cssDirectory.path,
        '${sha1.convert(utf8.encode(entry.archivePath))}.css',
      );
      File(cachePath).writeAsStringSync(
        _decodeEpubText(archiveFile.content as List<int>),
        flush: true,
      );
      cssPaths.add(<String, dynamic>{
        'archivePath': entry.archivePath,
        'cachePath': cachePath,
      });
    }

    final chapters = <Map<String, dynamic>>[];
    final chapterIndexByArchivePath = <String, int>{};
    var chapterIndex = 0;
    for (final manifest in orderedReadingEntries) {
      chapterIndexByArchivePath.putIfAbsent(
        manifest.archivePath,
        () => chapterIndex,
      );
      chapters.add(<String, dynamic>{
        'id': manifest.href,
        'title': titleByArchivePath[manifest.archivePath] ?? '',
        'depth': depthByArchivePath[manifest.archivePath] ?? 0,
        'archivePath': manifest.archivePath,
        'cachePath': path.join(
          cacheDirectory.path,
          'chapters',
          'chapter-${chapterIndex.toString().padLeft(6, '0')}.json',
        ),
      });
      chapterIndex++;
    }
    final navigation = <Map<String, dynamic>>[
      for (final entry in navigationEntries)
        if (chapterIndexByArchivePath[entry.archivePath] case final target?)
          <String, dynamic>{
            'title': entry.title,
            'depth': entry.depth,
            'chapterIndex': target,
          },
    ];

    final result = <String, dynamic>{
      'version': epubNativeCacheVersion,
      'sourceSize': sourceSize,
      'sourceModifiedMillis': sourceModifiedMillis,
      'cssPaths': cssPaths,
      'chapters': chapters,
      'navigation': navigation,
    };
    _writeJsonAtomically(
      File(path.join(cacheDirectory.path, 'index.json')),
      result,
    );
    return result;
  } finally {
    input.closeSync();
  }
}

Map<String, dynamic> loadEpubNativeChapter(Map<String, dynamic> arguments) {
  final chapter = Map<String, dynamic>.from(arguments['chapter'] as Map);
  final window = loadEpubNativeChapterWindow(<String, dynamic>{
    ...arguments,
    'chapters': <Map<String, dynamic>>[chapter],
  });
  return (window['results'] as List).first as Map<String, dynamic>;
}

Map<String, dynamic> loadEpubNativeChapterWindow(
  Map<String, dynamic> arguments,
) {
  final chapters = (arguments['chapters'] as List<dynamic>? ?? const [])
      .map((chapter) => Map<String, dynamic>.from(chapter as Map))
      .toList(growable: false);
  final results = List<Map<String, dynamic>?>.filled(chapters.length, null);
  final misses = <int>[];
  final cacheDirectory = arguments['cacheDirectory'] as String;
  for (var index = 0; index < chapters.length; index++) {
    final cached = _readChapterCache(
      chapters[index]['cachePath'] as String,
      cacheDirectory,
    );
    if (cached == null) {
      misses.add(index);
    } else {
      results[index] = cached;
    }
  }
  if (misses.isEmpty) {
    return <String, dynamic>{'results': results.cast<Map<String, dynamic>>()};
  }

  final epubPath = arguments['epubPath'] as String;
  final familyPrefix = _identifier(arguments['familyPrefix'] as String? ?? '');
  final cssPaths = (arguments['cssPaths'] as List<dynamic>? ?? const [])
      .map((entry) => Map<String, dynamic>.from(entry as Map))
      .toList(growable: false);
  final parsedStylesByKey = <String, _ParsedStyles>{};
  final input = InputFileStream(epubPath);
  try {
    final archive = ZipDecoder().decodeBuffer(input);
    final files = _archiveFilesByPath(archive);
    for (final index in misses) {
      final chapter = chapters[index];
      final chapterArchivePath = chapter['archivePath'] as String;
      final document = html_parser.parse(
        _readArchiveText(files, chapterArchivePath),
      );
      final stylesheets = _stylesheetsForDocument(
        document: document,
        chapterArchivePath: chapterArchivePath,
        cssPaths: cssPaths,
      );
      final styleKey = stylesheets
          .map(
            (source) =>
                '${source.archivePath}:'
                '${sha1.convert(utf8.encode(source.css))}',
          )
          .join('|');
      final parsedStyles = parsedStylesByKey.putIfAbsent(
        styleKey,
        () => _parseStyleSources(stylesheets, familyPrefix: familyPrefix),
      );
      final parsedChapter = _parseChapterDocument(
        chapter,
        document,
        chapterArchivePath: chapterArchivePath,
        rules: parsedStyles.rules,
        fontFaces: parsedStyles.fontFaces,
        files: files,
        cacheDirectory: cacheDirectory,
      );
      final result = <String, dynamic>{
        'version': epubNativeCacheVersion,
        'chapter': parsedChapter.chapter,
        'fonts': parsedChapter.fonts,
      };
      _writeJsonAtomically(File(chapter['cachePath'] as String), result);
      results[index] = result;
    }
    return <String, dynamic>{'results': results.cast<Map<String, dynamic>>()};
  } finally {
    input.closeSync();
  }
}

/// Test/diagnostic helper. Production opens a bounded chapter window with
/// [loadEpubNativeChapter] and never transfers all chapters at once.
Map<String, dynamic> loadEpubNativeChapters(Map<String, dynamic> arguments) {
  final chapters = (arguments['chapters'] as List<dynamic>? ?? const [])
      .map((chapter) => Map<String, dynamic>.from(chapter as Map))
      .toList(growable: false);
  final parsed = <Map<String, dynamic>>[];
  final fonts = <String, String>{};
  final window = loadEpubNativeChapterWindow(<String, dynamic>{
    ...arguments,
    'chapters': chapters,
  });
  for (final result in (window['results'] as List).cast<Map>()) {
    parsed.add(Map<String, dynamic>.from(result['chapter'] as Map));
    fonts.addAll(Map<String, String>.from(result['fonts'] as Map? ?? const {}));
  }
  return <String, dynamic>{'chapters': parsed, 'fonts': fonts};
}

Map<String, dynamic>? _readChapterCache(
  String cachePath,
  String cacheDirectory,
) {
  try {
    final file = File(cachePath);
    if (!file.existsSync()) return null;
    final decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic> ||
        decoded['version'] != epubNativeCacheVersion ||
        decoded['chapter'] is! Map ||
        decoded['fonts'] is! Map) {
      return null;
    }
    return _relocateChapterCachePaths(decoded, cacheDirectory);
  } catch (_) {
    return null;
  }
}

void _relocateIndexCachePaths(
  Map<String, dynamic> index,
  String cacheDirectory,
) {
  final stylesDirectory = path.join(cacheDirectory, 'styles');
  for (final raw in index['cssPaths'] as List<dynamic>) {
    final entry = raw as Map;
    final archivePath = entry['archivePath'] as String;
    entry['cachePath'] = path.join(
      stylesDirectory,
      '${sha1.convert(utf8.encode(archivePath))}.css',
    );
  }
  final chapters = index['chapters'] as List<dynamic>;
  for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
    final chapter = chapters[chapterIndex] as Map;
    chapter['cachePath'] = path.join(
      cacheDirectory,
      'chapters',
      'chapter-${chapterIndex.toString().padLeft(6, '0')}.json',
    );
  }
}

Map<String, dynamic>? _relocateChapterCachePaths(
  Map<String, dynamic> cached,
  String cacheDirectory,
) {
  final fonts = cached['fonts'] as Map;
  for (final key in fonts.keys.toList()) {
    final oldPath = fonts[key] as String?;
    if (oldPath == null || oldPath.isEmpty) return null;
    final relocated = path.join(
      cacheDirectory,
      'fonts',
      path.basename(oldPath),
    );
    if (!File(relocated).existsSync()) return null;
    fonts[key] = relocated;
  }
  final chapter = cached['chapter'] as Map;
  final blocks = chapter['blocks'];
  if (blocks is! List) return null;
  for (final raw in blocks) {
    if (raw is! Map || raw['type'] != 'image') continue;
    final oldPath = raw['imagePath'] as String?;
    if (oldPath == null || oldPath.isEmpty) return null;
    final relocated = path.join(
      cacheDirectory,
      'images',
      path.basename(oldPath),
    );
    if (!File(relocated).existsSync()) return null;
    raw['imagePath'] = relocated;
  }
  return cached;
}

Map<String, ArchiveFile> _archiveFilesByPath(Archive archive) {
  final result = <String, ArchiveFile>{};
  for (final file in archive.files.where((file) => file.isFile)) {
    final normalized = _normalizeArchivePath(file.name);
    result[normalized] = file;
    result.putIfAbsent(_decodeEpubPath(normalized), () => file);
  }
  return result;
}

String _readArchiveText(Map<String, ArchiveFile> files, String archivePath) {
  final normalized = _normalizeArchivePath(archivePath);
  final file = files[normalized];
  if (file == null) {
    throw FormatException('EPUB resource is missing: $normalized');
  }
  return _decodeEpubText(file.content as List<int>);
}

String _decodeEpubText(List<int> bytes) {
  if (bytes.length >= 2) {
    if (bytes[0] == 0xff && bytes[1] == 0xfe) {
      return _decodeUtf16(bytes, littleEndian: true, offset: 2);
    }
    if (bytes[0] == 0xfe && bytes[1] == 0xff) {
      return _decodeUtf16(bytes, littleEndian: false, offset: 2);
    }
  }
  final withoutBom =
      bytes.length >= 3 &&
          bytes[0] == 0xef &&
          bytes[1] == 0xbb &&
          bytes[2] == 0xbf
      ? bytes.sublist(3)
      : bytes;
  try {
    return utf8.decode(withoutBom, allowMalformed: false);
  } on FormatException {
    // EPUB requires Unicode, but older Chinese books in the wild sometimes
    // declare or contain GBK. Decoding them is preferable to dropping the
    // entire chapter because of one invalid UTF-8 byte sequence.
    return gbk_bytes.decode(withoutBom);
  }
}

String _decodeUtf16(
  List<int> bytes, {
  required bool littleEndian,
  required int offset,
}) {
  final codeUnits = <int>[];
  for (var index = offset; index + 1 < bytes.length; index += 2) {
    codeUnits.add(
      littleEndian
          ? bytes[index] | (bytes[index + 1] << 8)
          : (bytes[index] << 8) | bytes[index + 1],
    );
  }
  return String.fromCharCodes(codeUnits);
}

List<_EpubNavigationEntry> _navigationEntriesFromDocument({
  required html_dom.Document navigation,
  required String navigationArchivePath,
}) {
  final entries = <_EpubNavigationEntry>[];
  final labels = <html_dom.Element, String>{};
  for (final label in navigation.querySelectorAll('navlabel')) {
    final point = _nearestAncestor(label, 'navpoint');
    if (point != null) labels[point] = label.text.trim();
  }
  for (final content in navigation.querySelectorAll('content')) {
    final point = _nearestAncestor(content, 'navpoint');
    final source = content.attributes['src'];
    if (point == null || source == null) continue;
    var depth = 0;
    var ancestor = point.parent;
    while (ancestor != null) {
      if (ancestor.localName == 'navpoint') depth++;
      ancestor = ancestor.parent;
    }
    final archivePath = _resolveArchivePath(navigationArchivePath, source);
    final title = labels[point] ?? '';
    if (title.isNotEmpty) {
      entries.add(_EpubNavigationEntry(title, archivePath, depth));
    }
  }
  if (entries.isNotEmpty) return entries;

  final tocRoots = navigation
      .querySelectorAll('nav')
      .where((element) {
        final type = _attributeValue(element, 'type')?.toLowerCase() ?? '';
        return type.split(RegExp(r'\s+')).contains('toc') ||
            (element.attributes['role'] ?? '').toLowerCase() == 'doc-toc';
      })
      .toList(growable: false);
  final roots = tocRoots.isEmpty
      ? navigation.querySelectorAll('nav').toList(growable: false)
      : tocRoots;
  for (final root in roots) {
    for (final anchor in root.querySelectorAll('a')) {
      final reference = anchor.attributes['href'];
      if (reference == null || reference.trim().isEmpty) continue;
      final item = _nearestAncestor(anchor, 'li');
      var depth = 0;
      var ancestor = item?.parent;
      while (ancestor != null && !identical(ancestor, root)) {
        if (ancestor.localName == 'li') depth++;
        ancestor = ancestor.parent;
      }
      final archivePath = _resolveArchivePath(navigationArchivePath, reference);
      final title = anchor.text.trim();
      if (title.isNotEmpty) {
        entries.add(_EpubNavigationEntry(title, archivePath, depth));
      }
    }
  }
  return entries;
}

class _EpubNavigationEntry {
  const _EpubNavigationEntry(this.title, this.archivePath, this.depth);

  final String title;
  final String archivePath;
  final int depth;
}

String _normalizeArchivePath(String value) {
  final normalized = path.posix.normalize(
    _decodeEpubPath(
      value.split('#').first.split('?').first,
    ).replaceAll('\\', '/'),
  );
  return normalized.startsWith('/') ? normalized.substring(1) : normalized;
}

String _resolveArchivePath(String ownerPath, String reference) {
  final uriPath = reference.split('#').first.split('?').first;
  return _normalizeArchivePath(
    path.posix.join(path.posix.dirname(ownerPath), _decodeEpubPath(uriPath)),
  );
}

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

bool _isHtmlMediaType(String mediaType) =>
    mediaType == 'application/xhtml+xml' ||
    mediaType == 'text/html' ||
    mediaType == 'application/x-dtbook+xml' ||
    mediaType == 'text/x-oeb1-document';

List<_StyleSource> _stylesheetsForDocument({
  required html_dom.Document document,
  required String chapterArchivePath,
  required List<Map<String, dynamic>> cssPaths,
}) {
  final cssByArchivePath = <String, String>{
    for (final css in cssPaths)
      css['archivePath'] as String: css['cachePath'] as String,
  };
  final result = <_StyleSource>[];
  for (final link in document.querySelectorAll('link')) {
    final relationship = (link.attributes['rel'] ?? '').toLowerCase();
    final href = link.attributes['href'];
    if (!relationship.split(RegExp(r'\s+')).contains('stylesheet') ||
        href == null) {
      continue;
    }
    final archivePath = _resolveArchivePath(chapterArchivePath, href);
    final cachePath = cssByArchivePath[archivePath];
    if (cachePath == null) continue;
    final file = File(cachePath);
    if (file.existsSync()) {
      result.add(_StyleSource(archivePath, file.readAsStringSync()));
    }
  }
  for (final style in document.querySelectorAll('style')) {
    result.add(_StyleSource(chapterArchivePath, style.text));
  }
  if (result.isEmpty) {
    for (final css in cssPaths) {
      final file = File(css['cachePath'] as String);
      if (file.existsSync()) {
        result.add(
          _StyleSource(css['archivePath'] as String, file.readAsStringSync()),
        );
      }
    }
  }
  return result;
}

_ParsedStyles _parseStyleSources(
  List<_StyleSource> sources, {
  required String familyPrefix,
}) {
  final rules = <_CssRule>[];
  final fontFaces = <String, _FontFace>{};
  var order = 0;
  for (final source in sources) {
    var css = source.css.replaceAll(RegExp(r'/\*.*?\*/', dotAll: true), '');
    final fontFacePattern = RegExp(
      r'@font-face\s*\{([^{}]*)\}',
      caseSensitive: false,
      dotAll: true,
    );
    for (final match in fontFacePattern.allMatches(css)) {
      final declarations = _declarations(match.group(1) ?? '');
      final alias = _firstFontFamily(declarations['font-family']);
      final sourceValue = declarations['src'];
      final url = sourceValue == null
          ? null
          : RegExp(r'url\(\s*([^)]+?)\s*\)', caseSensitive: false)
                .firstMatch(sourceValue)
                ?.group(1)
                ?.replaceAll(RegExp(r'''^['"]|['"]$'''), '');
      if (alias == null || url == null || _isExternalResource(url)) continue;
      final registered = 'epub_${familyPrefix}_${_identifier(alias)}';
      fontFaces[alias.toLowerCase()] = _FontFace(
        registeredFamily: registered,
        archivePath: _resolveArchivePath(source.archivePath, url),
      );
    }
    css = css.replaceAll(fontFacePattern, '');
    for (final match in RegExp(
      r'([^{}]+)\{([^{}]*)\}',
      dotAll: true,
    ).allMatches(css)) {
      final declarations = _declarations(match.group(2) ?? '');
      if (declarations.isEmpty) continue;
      for (final rawSelector in (match.group(1) ?? '').split(',')) {
        final selector = rawSelector.trim().toLowerCase();
        if (selector.isEmpty || selector.startsWith('@')) continue;
        rules.add(
          _CssRule(
            selector: selector,
            declarations: declarations,
            specificity: _specificity(selector),
            order: order++,
          ),
        );
      }
    }
  }
  return _ParsedStyles(rules, fontFaces);
}

Map<String, String> _declarations(String source) {
  final result = <String, String>{};
  for (final declaration in source.split(';')) {
    final separator = declaration.indexOf(':');
    if (separator <= 0) continue;
    final property = declaration.substring(0, separator).trim().toLowerCase();
    final value = declaration.substring(separator + 1).trim();
    if (property.isNotEmpty && value.isNotEmpty) result[property] = value;
  }
  return result;
}

_ParsedChapter _parseChapterDocument(
  Map<String, dynamic> chapter,
  html_dom.Document document, {
  required String chapterArchivePath,
  required List<_CssRule> rules,
  required Map<String, _FontFace> fontFaces,
  required Map<String, ArchiveFile> files,
  required String cacheDirectory,
}) {
  final plainText = StringBuffer();
  final blocks = <Map<String, dynamic>>[];
  final fonts = <String, String>{};
  final styleCache = <html_dom.Element, _EpubTextStyle>{};

  _EpubTextStyle styleFor(html_dom.Element element) {
    return styleCache.putIfAbsent(element, () {
      final parent = element.parent;
      final inherited = parent == null
          ? const _EpubTextStyle()
          : styleFor(parent);
      var style = inherited.forElement(element.localName ?? '');
      final matching =
          rules
              .where((rule) => _matchesSelector(element, rule.selector))
              .toList()
            ..sort((a, b) {
              final specificity = a.specificity.compareTo(b.specificity);
              return specificity != 0
                  ? specificity
                  : a.order.compareTo(b.order);
            });
      for (final rule in matching) {
        style = style.apply(rule.declarations, fontFaces);
      }
      final inline = element.attributes['style'];
      if (inline != null) style = style.apply(_declarations(inline), fontFaces);
      return style;
    });
  }

  void extractFont(String family) {
    final face = fontFaces.values
        .where((face) => face.registeredFamily == family)
        .firstOrNull;
    if (face == null || fonts.containsKey(family)) return;
    final archiveFile = files[face.archivePath];
    if (archiveFile == null) return;
    final extension = path.posix.extension(face.archivePath).toLowerCase();
    final fontDirectory = Directory(path.join(cacheDirectory, 'fonts'))
      ..createSync(recursive: true);
    final fontPath = path.join(
      fontDirectory.path,
      '${sha1.convert(utf8.encode(face.archivePath))}$extension',
    );
    final file = File(fontPath);
    if (!file.existsSync()) {
      file.writeAsBytesSync(
        List<int>.from(archiveFile.content as List<int>),
        flush: true,
      );
    }
    fonts[family] = fontPath;
  }

  void addImage(String resourcePath, int offset) {
    final archiveFile = files[resourcePath];
    if (archiveFile == null) return;
    final extension = path.posix.extension(resourcePath).toLowerCase();
    final imageDirectory = Directory(path.join(cacheDirectory, 'images'))
      ..createSync(recursive: true);
    final imagePath = path.join(
      imageDirectory.path,
      '${sha1.convert(utf8.encode(resourcePath))}$extension',
    );
    final file = File(imagePath);
    if (!file.existsSync()) {
      file.writeAsBytesSync(
        List<int>.from(archiveFile.content as List<int>),
        flush: true,
      );
    }
    blocks.add(<String, dynamic>{
      'type': 'image',
      'resourcePath': resourcePath,
      'imagePath': imagePath,
      'startOffset': offset,
      'endOffset': offset,
    });
  }

  final body = document.body;
  if (body != null) {
    final content = _collectInlineContent(
      body,
      styleFor: styleFor,
      chapterArchivePath: chapterArchivePath,
    );
    plainText.write(content.text);
    for (final run in content.runs) {
      final family = run.style.fontFamily;
      if (family != null) extractFont(family);
      final block = <String, dynamic>{
        'type': 'text',
        'content': run.text,
        'startOffset': run.start,
        'endOffset': run.end,
        'fontScale': run.style.fontScale,
        'bold': run.style.bold,
        'italic': run.style.italic,
      };
      if (family != null) block['fontFamily'] = family;
      if (run.style.color != null) block['color'] = run.style.color;
      blocks.add(block);
    }
    for (final image in content.images) {
      addImage(image.resourcePath, image.offset);
    }
  }

  blocks.sort((a, b) {
    final offset = (a['startOffset'] as int).compareTo(b['startOffset'] as int);
    if (offset != 0) return offset;
    return a['type'] == 'image' ? -1 : 1;
  });
  return _ParsedChapter(<String, dynamic>{
    'id': chapter['id'] as String? ?? '',
    'title': chapter['title'] as String? ?? '',
    'depth': chapter['depth'] as int? ?? 0,
    'plainText': plainText.toString(),
    'blocks': blocks,
  }, fonts);
}

_InlineContent _collectInlineContent(
  html_dom.Element root, {
  required _EpubTextStyle Function(html_dom.Element) styleFor,
  required String chapterArchivePath,
}) {
  final output = StringBuffer();
  final runs = <_InlineRun>[];
  final images = <_InlineImage>[];
  var pendingSpace = false;
  var trailingNewlines = 0;
  const paragraphStyle = _EpubTextStyle();

  void append(String text, _EpubTextStyle style) {
    if (text.isEmpty) return;
    final start = output.length;
    output.write(text);
    final end = output.length;
    if (runs.isNotEmpty && runs.last.end == start && runs.last.style == style) {
      runs[runs.length - 1] = _InlineRun(
        runs.last.start,
        end,
        '${runs.last.text}$text',
        style,
      );
    } else {
      runs.add(_InlineRun(start, end, text, style));
    }
    trailingNewlines = 0;
    for (var index = text.length - 1; index >= 0; index--) {
      if (text.codeUnitAt(index) != 0x0a) break;
      trailingNewlines++;
    }
  }

  void appendText(
    String value,
    _EpubTextStyle style, {
    bool preformatted = false,
  }) {
    if (preformatted) {
      append(value.replaceAll(RegExp(r'\r\n?'), '\n'), style);
      pendingSpace = false;
      return;
    }
    for (final match in RegExp(r'\s+|\S+').allMatches(value)) {
      final token = match.group(0)!;
      if (RegExp(r'^\s+$').hasMatch(token)) {
        if (output.isNotEmpty) pendingSpace = true;
        continue;
      }
      if (pendingSpace && output.isNotEmpty && trailingNewlines == 0) {
        append(' ', style);
      }
      pendingSpace = false;
      append(token, style);
    }
  }

  void appendParagraphBoundary() {
    if (output.isEmpty) return;
    if (trailingNewlines >= 2) return;
    append(trailingNewlines == 1 ? '\n' : '\n\n', paragraphStyle);
    pendingSpace = false;
  }

  void visit(html_dom.Node node, _EpubTextStyle inherited, bool preformatted) {
    for (final child in node.nodes) {
      if (child is html_dom.Text) {
        appendText(child.data, inherited, preformatted: preformatted);
        continue;
      }
      if (child is! html_dom.Element) continue;
      final tag = (child.localName ?? '').toLowerCase();
      if (tag == 'script' || tag == 'style' || tag == 'head') continue;
      if (tag == 'br') {
        append('\n', inherited);
        pendingSpace = false;
        continue;
      }
      if (_isImageElement(child)) {
        final source = _imageSource(child);
        if (source != null && !_isExternalResource(source)) {
          images.add(
            _InlineImage(
              output.length,
              _resolveArchivePath(chapterArchivePath, source),
            ),
          );
        }
        continue;
      }
      final style = styleFor(child);
      final isBlock = _textBlockTags.contains(tag);
      if (isBlock) appendParagraphBoundary();
      visit(child, style, preformatted || tag == 'pre');
      if (isBlock) appendParagraphBoundary();
    }
  }

  visit(root, styleFor(root), root.localName == 'pre');
  var text = output.toString();
  final leading = text.length - text.trimLeft().length;
  final trailing = text.length - text.trimRight().length;
  if (leading > 0 || trailing > 0) {
    text = text.trim();
    final adjustedRuns = <_InlineRun>[];
    for (final run in runs) {
      final start = (run.start - leading).clamp(0, text.length);
      final end = (run.end - leading).clamp(start, text.length);
      if (end <= start) continue;
      adjustedRuns.add(
        _InlineRun(start, end, text.substring(start, end), run.style),
      );
    }
    runs
      ..clear()
      ..addAll(adjustedRuns);
    for (var index = 0; index < images.length; index++) {
      final image = images[index];
      images[index] = _InlineImage(
        (image.offset - leading).clamp(0, text.length),
        image.resourcePath,
      );
    }
  }
  return _InlineContent(text, runs, images);
}

bool _isImageElement(html_dom.Element element) {
  final name = (element.localName ?? '').toLowerCase();
  return name == 'img' || name == 'image';
}

String? _imageSource(html_dom.Element element) {
  for (final entry in element.attributes.entries) {
    final name = entry.key.toString().toLowerCase();
    if (name == 'src' || name == 'href' || name == 'xlink:href') {
      return entry.value;
    }
  }
  return null;
}

const _textBlockTags = <String>{
  'address',
  'article',
  'blockquote',
  'dd',
  'div',
  'dt',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'li',
  'p',
  'pre',
  'section',
  'stanza',
  'subtitle',
  'v',
};

bool _matchesSelector(html_dom.Element element, String selector) {
  final normalized = selector
      .replaceAll(RegExp(r'::?[a-z-]+(?:\([^)]*\))?', caseSensitive: false), '')
      .replaceAll('>', ' ')
      .trim();
  if (normalized.isEmpty) return false;
  final parts = normalized.split(RegExp(r'\s+'));
  html_dom.Element? candidate = element;
  for (var index = parts.length - 1; index >= 0; index--) {
    while (candidate != null && !_matchesCompound(candidate, parts[index])) {
      if (index == parts.length - 1) return false;
      candidate = candidate.parent;
    }
    if (candidate == null) return false;
    candidate = candidate.parent;
  }
  return true;
}

bool _matchesCompound(html_dom.Element element, String compound) {
  final tag = RegExp(r'^[a-z][a-z0-9_-]*|^\*').firstMatch(compound)?.group(0);
  if (tag != null && tag != '*' && element.localName?.toLowerCase() != tag) {
    return false;
  }
  for (final match in RegExp(r'\.([a-z0-9_-]+)').allMatches(compound)) {
    if (!element.classes
        .map((name) => name.toLowerCase())
        .contains(match.group(1))) {
      return false;
    }
  }
  final id = RegExp(r'#([a-z0-9_-]+)').firstMatch(compound)?.group(1);
  return id == null || element.id.toLowerCase() == id;
}

int _specificity(String selector) {
  final ids = RegExp(r'#[a-z0-9_-]+').allMatches(selector).length;
  final classes = RegExp(r'\.[a-z0-9_-]+').allMatches(selector).length;
  final tags = selector
      .split(RegExp(r'\s+|>'))
      .where((part) => RegExp(r'^[a-z]').hasMatch(part))
      .length;
  return ids * 100 + classes * 10 + tags;
}

String? _firstFontFamily(String? value) {
  if (value == null) return null;
  final first = value.split(',').first.trim();
  final unquoted = first.replaceAll(RegExp(r'''^['"]|['"]$'''), '').trim();
  if (unquoted.isEmpty ||
      const {
        'serif',
        'sans-serif',
        'monospace',
        'cursive',
        'fantasy',
      }.contains(unquoted.toLowerCase())) {
    return null;
  }
  return unquoted;
}

bool _isExternalResource(String value) {
  final normalized = value.trim().toLowerCase();
  return normalized.startsWith('data:') ||
      normalized.startsWith('http:') ||
      normalized.startsWith('https:') ||
      normalized.startsWith('file:') ||
      normalized.startsWith('res:');
}

String _identifier(String value) {
  final normalized = value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');
  return normalized.isEmpty ? 'book' : normalized;
}

void _writeJsonAtomically(File file, Map<String, dynamic> value) {
  file.parent.createSync(recursive: true);
  final temporary = File('${file.path}.tmp');
  temporary.writeAsStringSync(jsonEncode(value), flush: true);
  if (file.existsSync()) file.deleteSync();
  temporary.renameSync(file.path);
}

class _ManifestEntry {
  const _ManifestEntry({
    required this.id,
    required this.href,
    required this.archivePath,
    required this.mediaType,
    required this.properties,
  });

  final String id;
  final String href;
  final String archivePath;
  final String mediaType;
  final String properties;
}

class _StyleSource {
  const _StyleSource(this.archivePath, this.css);

  final String archivePath;
  final String css;
}

class _CssRule {
  const _CssRule({
    required this.selector,
    required this.declarations,
    required this.specificity,
    required this.order,
  });

  final String selector;
  final Map<String, String> declarations;
  final int specificity;
  final int order;
}

class _FontFace {
  const _FontFace({required this.registeredFamily, required this.archivePath});

  final String registeredFamily;
  final String archivePath;
}

class _ParsedStyles {
  const _ParsedStyles(this.rules, this.fontFaces);

  final List<_CssRule> rules;
  final Map<String, _FontFace> fontFaces;
}

class _EpubTextStyle {
  const _EpubTextStyle({
    this.fontScale = 1,
    this.bold = false,
    this.italic = false,
    this.fontFamily,
    this.color,
  });

  final double fontScale;
  final bool bold;
  final bool italic;
  final String? fontFamily;
  final String? color;

  _EpubTextStyle forElement(String tag) {
    const headingScales = <String, double>{
      'h1': 1.75,
      'h2': 1.5,
      'h3': 1.3,
      'h4': 1.18,
      'h5': 1.1,
      'h6': 1.05,
    };
    return _EpubTextStyle(
      fontScale: headingScales[tag] ?? fontScale,
      bold:
          bold ||
          headingScales.containsKey(tag) ||
          tag == 'b' ||
          tag == 'strong',
      italic: italic || tag == 'i' || tag == 'em',
      fontFamily: fontFamily,
      color: color,
    );
  }

  _EpubTextStyle apply(
    Map<String, String> declarations,
    Map<String, _FontFace> fontFaces,
  ) {
    var nextScale = fontScale;
    final fontSize = declarations['font-size']?.trim().toLowerCase();
    if (fontSize != null) {
      final em = RegExp(r'^([0-9.]+)em$').firstMatch(fontSize)?.group(1);
      final percent = RegExp(r'^([0-9.]+)%$').firstMatch(fontSize)?.group(1);
      if (em != null) {
        nextScale = double.tryParse(em) ?? nextScale;
      } else if (percent != null) {
        nextScale = (double.tryParse(percent) ?? 100) / 100;
      } else {
        nextScale =
            const <String, double>{
              'xx-small': 0.6,
              'x-small': 0.75,
              'small': 0.89,
              'medium': 1,
              'large': 1.2,
              'x-large': 1.5,
              'xx-large': 2,
            }[fontSize] ??
            nextScale;
      }
    }
    var nextBold = bold;
    final weight = declarations['font-weight']?.trim().toLowerCase();
    if (weight == 'normal' || weight == '400') {
      nextBold = false;
    } else if (weight == 'bold' || weight == 'bolder') {
      nextBold = true;
    } else if (weight != null) {
      nextBold = (int.tryParse(weight) ?? 0) >= 600;
    }
    var nextItalic = italic;
    final fontStyle = declarations['font-style']?.trim().toLowerCase();
    if (fontStyle == 'normal') {
      nextItalic = false;
    } else if (fontStyle == 'italic' || fontStyle == 'oblique') {
      nextItalic = true;
    }
    var nextFamily = fontFamily;
    final family = _firstFontFamily(declarations['font-family']);
    if (family != null) {
      nextFamily = fontFaces[family.toLowerCase()]?.registeredFamily ?? family;
    }
    return _EpubTextStyle(
      fontScale: nextScale,
      bold: nextBold,
      italic: nextItalic,
      fontFamily: nextFamily,
      color: declarations['color']?.trim() ?? color,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is _EpubTextStyle &&
      other.fontScale == fontScale &&
      other.bold == bold &&
      other.italic == italic &&
      other.fontFamily == fontFamily &&
      other.color == color;

  @override
  int get hashCode => Object.hash(fontScale, bold, italic, fontFamily, color);
}

class _InlineRun {
  const _InlineRun(this.start, this.end, this.text, this.style);

  final int start;
  final int end;
  final String text;
  final _EpubTextStyle style;
}

class _InlineImage {
  const _InlineImage(this.offset, this.resourcePath);

  final int offset;
  final String resourcePath;
}

class _InlineContent {
  const _InlineContent(this.text, this.runs, this.images);

  final String text;
  final List<_InlineRun> runs;
  final List<_InlineImage> images;
}

class _ParsedChapter {
  const _ParsedChapter(this.chapter, this.fonts);

  final Map<String, dynamic> chapter;
  final Map<String, String> fonts;
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
