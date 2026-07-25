// 文件说明：书籍重命名服务，修改书名的同时（若存在本地文件）同步重命名磁盘文件。
// 技术要点：安全文件名清洗、文件系统重命名、DAO 持久化。

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';

class BookRenameService {
  BookRenameService({BookDao? bookDao}) : _bookDao = bookDao ?? BookDao();

  final BookDao _bookDao;

  /// 将 [book] 的书名改为 [newTitle]。
  ///
  /// 若书籍存在本地文件，会一并把磁盘文件重命名为新书名（保留扩展名），
  /// 并在目标文件名已存在时自动追加序号避免覆盖。仅在线、尚未下载的书籍
  /// 没有本地文件，只更新数据库中的书名。
  Future<Book> rename(Book book, String newTitle) async {
    final title = newTitle.trim();
    if (title.isEmpty) {
      throw ArgumentError('书名不能为空');
    }
    var updated = book.copyWith(title: title);

    final currentPath = book.filePath.trim();
    if (currentPath.isNotEmpty) {
      final file = File(currentPath);
      if (await file.exists()) {
        final newPath = await _uniqueRenamedPath(file, title);
        if (newPath != currentPath) {
          final renamedFile = await file.rename(newPath);
          updated = updated.copyWith(filePath: renamedFile.path);
        }
      }
    }

    await _bookDao.updateBook(updated);
    return updated;
  }

  Future<String> _uniqueRenamedPath(File file, String title) async {
    final dir = path.dirname(file.path);
    final extension = path.extension(file.path);
    final baseName = _safeFileName(title);
    var candidate = path.join(dir, '$baseName$extension');
    if (candidate == file.path) return candidate;
    var suffix = 1;
    while (await File(candidate).exists()) {
      candidate = path.join(dir, '$baseName ($suffix)$extension');
      suffix++;
    }
    return candidate;
  }

  String _safeFileName(String title) {
    var candidate = title
        .replaceAll(RegExp(r'[\x00-\x1f<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (candidate.isEmpty) candidate = 'book';
    return _truncateByUtf8Bytes(candidate, 150);
  }

  String _truncateByUtf8Bytes(String value, int maxBytes) {
    if (utf8.encode(value).length <= maxBytes) return value;
    final buffer = StringBuffer();
    var bytes = 0;
    for (final rune in value.runes) {
      final character = String.fromCharCode(rune);
      final nextBytes = utf8.encode(character).length;
      if (bytes + nextBytes > maxBytes) break;
      buffer.write(character);
      bytes += nextBytes;
    }
    return buffer.isEmpty ? 'book' : buffer.toString();
  }
}
