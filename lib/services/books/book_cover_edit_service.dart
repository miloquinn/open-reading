// 文件说明：自定义书籍封面服务，挑选本地图片替换封面并支持恢复默认封面。
// 技术要点：FilePicker 图片选择、封面唯一命名避免 Image.file 缓存陈旧、原封面备份恢复、DAO 持久化。

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';

/// 自定义封面操作的失败原因，由 UI 层解析为本地化文案。
enum BookCoverEditError {
  unsupportedFormat,
  fileTooLarge,
  readFailed,
  storageFailed,
}

class BookCoverEditException implements Exception {
  const BookCoverEditException(this.code, [this.cause]);

  final BookCoverEditError code;
  final Object? cause;
}

/// 用户自定义封面：
///
/// - 新封面写入 `<documents>/covers/custom_<bookId>_<毫秒时间戳>.<ext>`，
///   每次替换路径都不同，`Image.file` 的解码缓存按路径失效，无需手动 evict。
/// - 首次替换时把原封面文件改名为 `covers/original_<bookId>.<ext>` 备份，
///   "恢复默认封面"据此无损还原导入时提取的真实封面。
class BookCoverEditService {
  BookCoverEditService({
    BookDao? bookDao,
    Future<FilePickerResult?> Function()? imagePicker,
    Future<Directory> Function()? documentsDirectory,
  }) : _bookDao = bookDao ?? BookDao(),
       _imagePicker = imagePicker ?? _pickCoverImage,
       _documentsDirectory =
           documentsDirectory ?? getApplicationDocumentsDirectory;

  static const int maxImageBytes = 20 * 1024 * 1024;
  static const List<String> supportedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'gif',
    'bmp',
  ];

  final BookDao _bookDao;
  final Future<FilePickerResult?> Function() _imagePicker;
  final Future<Directory> Function() _documentsDirectory;

  static Future<FilePickerResult?> _pickCoverImage() {
    return FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: supportedExtensions,
      allowMultiple: false,
      withData: true,
    );
  }

  /// [book] 当前是否使用用户自定义封面。
  static bool hasCustomCover(Book book) {
    final bookId = book.id;
    final coverPath = book.coverImagePath;
    if (bookId == null || coverPath == null || coverPath.trim().isEmpty) {
      return false;
    }
    return _isCustomCoverName(bookId, path.basename(coverPath));
  }

  /// 让用户挑选一张图片作为 [book] 的封面。
  ///
  /// 返回 true 表示封面已替换，false 表示用户取消挑选。
  /// 挑选的文件不合法或写入失败时抛出 [BookCoverEditException]。
  Future<bool> pickAndApplyCover(Book book) async {
    final bookId = ArgumentError.checkNotNull(book.id, 'book.id');
    final result = await _imagePicker();
    if (result == null || result.files.isEmpty) return false;
    final selected = result.files.single;
    final extension = path.extension(selected.name).toLowerCase();
    if (!supportedExtensions.contains(extension.replaceFirst('.', ''))) {
      throw const BookCoverEditException(BookCoverEditError.unsupportedFormat);
    }
    final bytes = selected.bytes ?? await _readSelectedFile(selected.path);
    if (bytes == null || bytes.isEmpty) {
      throw const BookCoverEditException(BookCoverEditError.readFailed);
    }
    if (bytes.length > maxImageBytes) {
      throw const BookCoverEditException(BookCoverEditError.fileTooLarge);
    }

    final coversDir = await _coversDirectory();
    final destination = File(
      path.join(
        coversDir.path,
        'custom_${bookId}_${DateTime.now().millisecondsSinceEpoch}$extension',
      ),
    );
    try {
      await destination.writeAsBytes(bytes, flush: true);
    } catch (error) {
      await _deleteIfExists(destination);
      throw BookCoverEditException(BookCoverEditError.storageFailed, error);
    }
    try {
      await _bookDao.updateBookCoverPath(bookId, destination.path);
    } catch (error) {
      await _deleteIfExists(destination);
      throw BookCoverEditException(BookCoverEditError.storageFailed, error);
    }
    await _archivePreviousCover(bookId, book.coverImagePath, coversDir);
    return true;
  }

  /// 恢复默认封面：删除自定义封面文件；有原封面备份则还原备份，
  /// 否则清空封面路径，回退到在线书源封面或生成封面。
  Future<void> resetCover(Book book) async {
    final bookId = book.id;
    if (bookId == null || !hasCustomCover(book)) return;
    final coversDir = await _coversDirectory();
    final backup = await _findBackup(bookId, coversDir);
    await _bookDao.updateBookCoverPath(bookId, backup?.path);
    final previousPath = book.coverImagePath;
    if (previousPath != null &&
        _isCustomCoverName(bookId, path.basename(previousPath))) {
      await _deleteIfExists(File(previousPath));
    }
  }

  /// 删除书籍后清理该书遗留的自定义封面与原封面备份。
  ///
  /// 删除流程本身只删 `coverImagePath` 指向的文件；换过封面的书还会
  /// 留下 `original_<id>` 备份（以及异常情况下的多余 `custom_<id>_` 文件）。
  Future<void> cleanupForDeletedBook(Book book) async {
    final bookId = book.id;
    if (bookId == null) return;
    try {
      final documents = await _documentsDirectory();
      final coversDir = Directory(path.join(documents.path, 'covers'));
      if (!await coversDir.exists()) return;
      await for (final entity in coversDir.list()) {
        if (entity is! File) continue;
        final name = path.basename(entity.path);
        if (_isCustomCoverName(bookId, name) || _isBackupName(bookId, name)) {
          await _deleteIfExists(entity);
        }
      }
    } catch (_) {
      // 清理残留失败不阻塞删除流程。
    }
  }

  /// 把被替换的旧封面归档：自定义封面直接删除；原封面改名备份。
  Future<void> _archivePreviousCover(
    int bookId,
    String? previousPath,
    Directory coversDir,
  ) async {
    if (previousPath == null || previousPath.trim().isEmpty) return;
    final previous = File(previousPath);
    if (!await previous.exists()) return;
    final name = path.basename(previousPath);
    if (_isCustomCoverName(bookId, name)) {
      await _deleteIfExists(previous);
      return;
    }
    // 旧封面本身就是备份（恢复默认后再次自定义），保持原样。
    if (_isBackupName(bookId, name)) return;
    final backupPath = path.join(
      coversDir.path,
      'original_$bookId${path.extension(previousPath)}',
    );
    if (await File(backupPath).exists()) return;
    try {
      await previous.rename(backupPath);
    } on FileSystemException {
      try {
        await previous.copy(backupPath);
      } catch (_) {
        // 备份失败只影响"恢复默认封面"，不阻塞换封面。
      }
    }
  }

  Future<File?> _findBackup(int bookId, Directory coversDir) async {
    if (!await coversDir.exists()) return null;
    await for (final entity in coversDir.list()) {
      if (entity is File && _isBackupName(bookId, path.basename(entity.path))) {
        return entity;
      }
    }
    return null;
  }

  static bool _isCustomCoverName(int bookId, String fileName) {
    return RegExp('^custom_${bookId}_\\d+\\.[A-Za-z0-9]+\$').hasMatch(fileName);
  }

  static bool _isBackupName(int bookId, String fileName) {
    return path.basenameWithoutExtension(fileName) == 'original_$bookId';
  }

  Future<Directory> _coversDirectory() async {
    final documents = await _documentsDirectory();
    final coversDir = Directory(path.join(documents.path, 'covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }
    return coversDir;
  }

  Future<Uint8List?> _readSelectedFile(String? filePath) async {
    if (filePath == null || filePath.isEmpty) return null;
    try {
      return await File(filePath).readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> _deleteIfExists(File file) async {
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 旧封面文件删除失败只留下孤儿文件，不影响功能。
    }
  }
}
