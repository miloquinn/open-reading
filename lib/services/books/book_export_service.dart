// 文件说明：校验本地书籍并协调跨平台导出后端。
// 技术要点：安全文件名、MIME 映射、稳定结果、依赖注入。

import 'dart:convert';

import 'package:path/path.dart' as path;
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_export_backend.dart';
import 'package:xxread/services/books/book_export_models.dart';
import 'package:xxread/services/books/book_export_source.dart';

typedef BookExportSourceExists = Future<bool> Function(String path);

class BookExportService {
  BookExportService({
    BookExportBackend? backend,
    BookExportSourceExists? sourceExists,
  })  : _backend = backend ?? createDefaultBookExportBackend(),
        _sourceExists = sourceExists ?? bookExportSourceExists;

  final BookExportBackend _backend;
  final BookExportSourceExists _sourceExists;

  Future<BookExportResult> export(Book book) async {
    if (book.isOnline || book.filePath.trim().isEmpty) {
      return const BookExportResult.notDownloaded();
    }
    try {
      if (!await _sourceExists(book.filePath)) {
        return const BookExportResult.sourceMissing();
      }
    } catch (error) {
      return BookExportResult.failure(error);
    }

    final suggestedName = _safeFileName(book);
    final request = BookExportRequest(
      sourcePath: book.filePath,
      suggestedName: suggestedName,
      mimeType: mimeTypeForBookFile(suggestedName, fallback: book.format),
    );
    try {
      final result = await _backend.export(request);
      return switch (result.status) {
        BookExportStatus.success => BookExportResult.success(
            displayName: result.displayName?.isNotEmpty == true
                ? result.displayName!
                : suggestedName,
            location: result.location,
            uri: result.uri,
          ),
        BookExportStatus.cancelled => const BookExportResult.cancelled(),
        BookExportStatus.unsupported => const BookExportResult.unsupported(),
        _ => BookExportResult.failure(result.error),
      };
    } catch (error) {
      return BookExportResult.failure(error);
    }
  }

  String _safeFileName(Book book) {
    var candidate = path.basename(book.filePath.trim());
    final format = _normalizedExtension(
      path.extension(candidate).isNotEmpty
          ? path.extension(candidate)
          : book.format,
    );
    if (candidate.isEmpty || candidate == '.' || candidate == path.separator) {
      candidate = '${book.title}.${format.isEmpty ? 'bin' : format}';
    } else if (path.extension(candidate).isEmpty && format.isNotEmpty) {
      candidate = '$candidate.$format';
    }
    candidate = candidate
        .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (candidate.isEmpty) {
      candidate = 'book.${format.isEmpty ? 'bin' : format}';
    }
    return _truncateFileNameByUtf8Bytes(candidate, 180);
  }
}

String _truncateFileNameByUtf8Bytes(String value, int maxBytes) {
  if (utf8.encode(value).length <= maxBytes) return value;
  final extension = path.extension(value);
  final suffixBytes = utf8.encode(extension).length;
  final stemLimit = (maxBytes - suffixBytes).clamp(1, maxBytes);
  final buffer = StringBuffer();
  var bytes = 0;
  for (final rune in path.basenameWithoutExtension(value).runes) {
    final character = String.fromCharCode(rune);
    final nextBytes = utf8.encode(character).length;
    if (bytes + nextBytes > stemLimit) break;
    buffer.write(character);
    bytes += nextBytes;
  }
  final stem = buffer.isEmpty ? 'book' : buffer.toString();
  return '$stem$extension';
}

String mimeTypeForBookFile(String fileName, {String fallback = ''}) {
  final extension = _normalizedExtension(
    path.extension(fileName).isNotEmpty ? path.extension(fileName) : fallback,
  );
  return switch (extension) {
    'txt' || 'md' || 'markdown' => 'text/plain',
    'epub' => 'application/epub+zip',
    'pdf' => 'application/pdf',
    'mobi' => 'application/x-mobipocket-ebook',
    'azw' || 'azw3' => 'application/vnd.amazon.ebook',
    'fb2' => 'application/x-fictionbook+xml',
    'rtf' => 'application/rtf',
    'doc' => 'application/msword',
    'docx' =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'html' || 'htm' || 'xhtml' => 'text/html',
    'cbz' => 'application/vnd.comicbook+zip',
    'cbr' => 'application/vnd.comicbook-rar',
    _ => 'application/octet-stream',
  };
}

String _normalizedExtension(String raw) =>
    raw.trim().toLowerCase().replaceFirst(RegExp(r'^\.'), '');
