import 'dart:convert';
import 'dart:io';

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

import '../../models/book.dart';
import '../../services/books/book_dao.dart';
import '../../services/books/cover_generator_service.dart';
import '../../services/library/library_event_bus_service.dart';
import '../models/registered_book_source.dart';
import '../protocol/book_source_protocol.dart';
import 'book_download_cancellation.dart';
import 'book_source_client.dart';
import 'source_cover_cache.dart';

class BookSourceShelfService {
  static const int _downloadBatchSize = 3;

  /// 在线书源书籍的进度编码单位：currentPage/totalPages 存储的是
  /// "章节序号 * unitsPerChapter + 章内进度"，而不是真实页码。
  /// UI 展示总量/当前值时需要除以该常量换算回章节数，避免把它当作页数显示。
  static const int unitsPerChapter = 1000;

  BookSourceShelfService({
    BookDao? bookDao,
    BookSourceClient? client,
    SourceCoverCache? sourceCoverCache,
    Directory? downloadDirectory,
  }) : _downloadDirectory = downloadDirectory,
       _bookDao = bookDao ?? BookDao(),
       _client = client ?? BookSourceClient(),
       _sourceCoverCache = sourceCoverCache ?? SourceCoverCache.instance;

  final BookDao _bookDao;
  final BookSourceClient _client;
  final SourceCoverCache _sourceCoverCache;
  final Directory? _downloadDirectory;

  Future<Book?> findShelfBook({
    required String sourceId,
    required String sourceBookId,
  }) =>
      _bookDao.getBookBySource(sourceId: sourceId, sourceBookId: sourceBookId);

  Future<Book> addOnline({
    required RegisteredBookSource source,
    required BookSourceBook book,
  }) async {
    final existing = await findShelfBook(
      sourceId: source.id,
      sourceBookId: book.id,
    );
    if (existing != null) return existing;
    final generatedCoverPath = await _storedCoverPath(source, book);
    final shelfBook = Book(
      title: book.title,
      author: book.author,
      filePath: '',
      format: 'source',
      storageType: 'online',
      sourceId: source.id,
      sourceBookId: book.id,
      sourceJson: jsonEncode(source.toJson()),
      sourceBookJson: jsonEncode(book.toJson()),
      coverImagePath: generatedCoverPath,
    );
    final id = await _bookDao.insertBook(shelfBook);
    LibraryEventBus().notifyLibraryChanged();
    return shelfBook.copyWith(id: id);
  }

  Future<void> updateShelfProgress({
    required int shelfBookId,
    required int chapterIndex,
    required int chapterCount,
    required double chapterProgress,
  }) async {
    final currentUnits =
        chapterIndex * unitsPerChapter +
        (chapterProgress.clamp(0, 1) * unitsPerChapter).round();
    final totalUnits = chapterCount * unitsPerChapter;
    await _bookDao.updateBookProgress(
      shelfBookId,
      currentUnits,
      readingProgress: totalUnits <= 0 ? 0 : currentUnits / totalUnits,
    );
    await _bookDao.updateBookTotalPages(shelfBookId, totalUnits);
  }

  Future<Book> downloadToLocal({
    required RegisteredBookSource source,
    required BookSourceBook book,
    void Function(int completed, int total)? onProgress,
    BookDownloadCancellation? cancellation,
  }) async {
    cancellation?.throwIfCancelled();
    final chapters = [
      ...await _client.getChaptersForDownload(
        source,
        book.id,
        cancellation: cancellation,
      ),
    ]..sort(compareBookSourceChapters);
    cancellation?.throwIfCancelled();
    if (chapters.isEmpty) {
      throw const BookSourceProtocolException(
        'This book source returned an empty chapter catalog.',
      );
    }

    final documents =
        _downloadDirectory ?? await getApplicationDocumentsDirectory();
    final directory = Directory(path.join(documents.path, 'books'));
    await directory.create(recursive: true);
    final file = File(
      path.join(
        directory.path,
        '${_safeFileName(book.title)}-${_downloadIdentity(source, book)}.txt',
      ),
    );
    final temporaryFile = File(
      '${file.path}.${DateTime.now().microsecondsSinceEpoch}.part',
    );
    IOSink? sink;
    var completed = 0;
    onProgress?.call(0, chapters.length);

    try {
      sink = temporaryFile.openWrite(mode: FileMode.write, encoding: utf8);
      for (
        var offset = 0;
        offset < chapters.length;
        offset += _downloadBatchSize
      ) {
        cancellation?.throwIfCancelled();
        final end = (offset + _downloadBatchSize).clamp(0, chapters.length);
        final batch = chapters.sublist(offset, end);
        final contents = await Future.wait(
          batch.map((chapter) async {
            final content = await _client.getChapterContentForDownload(
              source,
              bookId: book.id,
              chapterId: chapter.id,
              cancellation: cancellation,
            );
            cancellation?.throwIfCancelled();
            completed++;
            onProgress?.call(completed, chapters.length);
            return content;
          }),
        );
        cancellation?.throwIfCancelled();
        for (var index = 0; index < batch.length; index++) {
          sink
            ..writeln(batch[index].title)
            ..writeln()
            ..writeln(_plainText(contents[index]))
            ..writeln()
            ..writeln();
        }
        await sink.flush();
      }
      cancellation?.throwIfCancelled();
      await sink.close();
      sink = null;
      cancellation?.throwIfCancelled();
      await _commitDownloadedFile(temporaryFile, file);
    } catch (_) {
      try {
        await sink?.close();
      } catch (_) {
        // Preserve the download error; cleanup is best effort.
      }
      try {
        if (await temporaryFile.exists()) await temporaryFile.delete();
      } catch (_) {
        // Preserve the download error; cleanup is best effort.
      }
      rethrow;
    }

    if (cancellation?.isCancelled ?? false) {
      throw const BookDownloadCancelledException();
    }

    final existing = await findShelfBook(
      sourceId: source.id,
      sourceBookId: book.id,
    );
    final generatedCoverPath =
        existing?.coverImagePath ?? await _storedCoverPath(source, book);
    cancellation?.throwIfCancelled();
    if (existing != null) {
      final downloaded = existing.copyWith(
        title: book.title,
        author: book.author,
        filePath: file.path,
        format: 'txt',
        totalPages: chapters.length,
        storageType: 'local',
        sourceJson: jsonEncode(source.toJson()),
        sourceBookJson: jsonEncode(book.toJson()),
        coverImagePath: generatedCoverPath,
      );
      await _bookDao.updateBook(downloaded);
      LibraryEventBus().notifyLibraryChanged();
      return downloaded;
    }

    final downloaded = Book(
      title: book.title,
      author: book.author,
      filePath: file.path,
      format: 'txt',
      totalPages: chapters.length,
      storageType: 'local',
      sourceId: source.id,
      sourceBookId: book.id,
      sourceJson: jsonEncode(source.toJson()),
      sourceBookJson: jsonEncode(book.toJson()),
      coverImagePath: generatedCoverPath,
    );
    final id = await _bookDao.insertBook(downloaded);
    LibraryEventBus().notifyLibraryChanged();
    return downloaded.copyWith(id: id);
  }

  RegisteredBookSource sourceFrom(Book book) {
    final json = jsonDecode(book.sourceJson!);
    return RegisteredBookSource.fromJson(
      (json as Map).map((key, value) => MapEntry('$key', value)),
    );
  }

  BookSourceBook sourceBookFrom(Book book) {
    final json = jsonDecode(book.sourceBookJson!);
    return BookSourceBook.fromJson(
      (json as Map).map((key, value) => MapEntry('$key', value)),
    );
  }

  String _safeFileName(String value) {
    final safe = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return safe.isEmpty ? 'book' : safe.substring(0, safe.length.clamp(0, 80));
  }

  String _downloadIdentity(RegisteredBookSource source, BookSourceBook book) =>
      sha256
          .convert(utf8.encode('${source.id}\u0000${book.id}'))
          .toString()
          .substring(0, 20);

  Future<void> _commitDownloadedFile(File temporary, File destination) async {
    final backup = File('${destination.path}.backup');
    final hadDestination = await destination.exists();
    if (await backup.exists()) await backup.delete();
    try {
      if (hadDestination) await destination.rename(backup.path);
      await temporary.rename(destination.path);
      if (await backup.exists()) await backup.delete();
    } catch (_) {
      if (!await destination.exists() && await backup.exists()) {
        await backup.rename(destination.path);
      }
      rethrow;
    }
  }

  String _plainText(BookSourceChapterContent content) {
    if (content.contentType != 'text/html') return content.content.trim();
    final fragment = html_parser.parseFragment(content.content);
    final paragraphs = <String>[];

    void visit(dom.Node node) {
      if (node is dom.Element &&
          const {'p', 'div', 'li', 'blockquote'}.contains(node.localName)) {
        final text = node.text.replaceAll(RegExp(r'\s+'), ' ').trim();
        if (text.isNotEmpty) paragraphs.add(text);
        return;
      }
      for (final child in node.nodes) {
        visit(child);
      }
    }

    for (final node in fragment.nodes) {
      visit(node);
    }
    return paragraphs.isEmpty
        ? (fragment.text ?? '').trim()
        : paragraphs.join('\n');
  }

  Future<String?> _storedCoverPath(
    RegisteredBookSource source,
    BookSourceBook book,
  ) async {
    try {
      final documents =
          _downloadDirectory ?? await getApplicationDocumentsDirectory();
      if (book.coverUrl != null) {
        final bytes = await _sourceCoverCache.load(book.coverUrl!);
        return CoverGenerator.saveCover(
          bytes,
          '${source.id}_${book.id}',
          documentsDirectory: documents,
          fileTag: 'source',
          fileExtension: 'img',
        );
      }
      final bytes = await CoverGenerator.generateTextCover(
        title: book.title,
        author: book.author,
      );
      return CoverGenerator.saveCover(
        bytes,
        '${source.id}_${book.id}.png',
        documentsDirectory: documents,
      );
    } catch (_) {
      // 持久化失败不应阻止用户加入书架；UI 会继续使用同一绘制器实时兜底。
      return null;
    }
  }
}
