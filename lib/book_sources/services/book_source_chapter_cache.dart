import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../protocol/book_source_protocol.dart';

class BookSourceChapterCache {
  static const String directoryName = 'book_source_chapters';
  static const _memoryLimit = 24;
  static const _diskLifetime = Duration(hours: 12);
  static final Map<String, BookSourceChapterContent> _memory = {};
  static final Map<String, Future<BookSourceChapterContent>> _inFlight = {};

  const BookSourceChapterCache();

  static void clearMemory() {
    _memory.clear();
  }

  Future<BookSourceChapterContent> getOrLoad({
    required String sourceId,
    required String bookId,
    required String chapterId,
    required Future<BookSourceChapterContent> Function() loader,
  }) async {
    final key = _key(sourceId, bookId, chapterId);
    final memory = _memory.remove(key);
    if (memory != null) {
      _memory[key] = memory;
      return memory;
    }
    final pending = _inFlight[key];
    if (pending != null) return pending;

    final future = _load(key, loader);
    _inFlight[key] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(key);
    }
  }

  Future<BookSourceChapterContent> _load(
    String key,
    Future<BookSourceChapterContent> Function() loader,
  ) async {
    final disk = await _readDisk(key);
    if (disk != null) {
      _remember(key, disk);
      return disk;
    }
    final content = await loader();
    _remember(key, content);
    await _writeDisk(key, content);
    return content;
  }

  void _remember(String key, BookSourceChapterContent content) {
    _memory[key] = content;
    while (_memory.length > _memoryLimit) {
      _memory.remove(_memory.keys.first);
    }
  }

  Future<BookSourceChapterContent?> _readDisk(String key) async {
    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;
      final age = DateTime.now().difference(await file.lastModified());
      if (age > _diskLifetime) {
        await file.delete();
        return null;
      }
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      return BookSourceChapterContent.fromJson(
        decoded.map((key, value) => MapEntry('$key', value)),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _writeDisk(String key, BookSourceChapterContent content) async {
    try {
      final file = await _fileFor(key);
      await file.parent.create(recursive: true);
      await file.writeAsString(
        jsonEncode({
          'bookId': content.bookId,
          'chapterId': content.chapterId,
          'title': content.title,
          'content': content.content,
          'contentType': content.contentType,
        }),
        flush: true,
      );
    } catch (_) {
      // Cache failures must never interrupt reading.
    }
  }

  Future<File> _fileFor(String key) async {
    final temp = await getTemporaryDirectory();
    return File(path.join(temp.path, directoryName, '${_hash(key)}.json'));
  }

  String _key(String sourceId, String bookId, String chapterId) =>
      '$sourceId\u0000$bookId\u0000$chapterId';

  String _hash(String value) => sha256.convert(utf8.encode(value)).toString();
}
