// 文件说明：CBZ/CBT/CBR/CB7 漫画专用阅读页（整页图片渲染，不走文本行盒）。
// 技术要点：isolate 内按文件头识别容器并建页索引、按需解压单页避免整本驻留内存；
// 真 RAR/7z 显示本地化「转 CBZ」提示；LRU 页缓存；UI 骨架复用
// paged_image_reader.dart；进度写回 currentPage。
// 解析逻辑见 comic_book_parser.dart；格式能力矩阵见 docs/book-format-support.md。

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/comic_book_parser.dart';
import 'package:xxread/services/books/web_book_file_store.dart';
import 'package:xxread/services/reading/reading_resume_service.dart';
import 'package:xxread/pages/reader/paged_image_reader.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_transitions.dart';
import 'package:xxread/utils/reader_themes.dart';

class ComicReaderPage extends StatefulWidget {
  const ComicReaderPage({
    super.key,
    required this.book,
    required this.initialTheme,
  });

  final Book book;
  final ReaderThemePalette initialTheme;

  /// 与 [NativeReaderService.openBook] 相同的封面展开转场入口。
  static Future<void> open(
    BuildContext context,
    Book book, {
    BookOpenAnimation? animation,
    LibraryBookOpenAnimation? libraryAnimation,
    bool waitForReaderClose = true,
  }) async {
    final initialTheme = await ReaderThemes.loadSavedPalette();
    if (!context.mounted) return;
    final route = BookOpenTransition.createRoute<void>(
      ComicReaderPage(book: book, initialTheme: initialTheme),
      animation: animation,
      libraryAnimation: libraryAnimation,
      readerBackgroundColor: Colors.black,
    );
    final navigation = BookOpenTransition.push<void>(context, route);
    if (waitForReaderClose) {
      await navigation;
    } else {
      unawaited(navigation);
    }
  }

  @override
  State<ComicReaderPage> createState() => _ComicReaderPageState();
}

class _ComicReaderPageState extends State<ComicReaderPage> {
  static const int _pageCacheLimit = 8;

  late final Future<List<String>> _pagesFuture;
  final LinkedHashMap<int, Uint8List> _pageCache = LinkedHashMap();
  final Map<int, Future<Uint8List>> _pendingPages = {};

  /// Web 端文件存于 IndexedDB，读一次后驻留；IO 端始终走文件路径。
  Uint8List? _webBytes;

  @override
  void initState() {
    super.initState();
    unawaited(ReadingResumeService.markReading(widget.book.id));
    _pagesFuture = _loadPages();
  }

  @override
  void dispose() {
    unawaited(ReadingResumeService.markClosed(widget.book.id));
    super.dispose();
  }

  Future<List<String>> _loadPages() async {
    Map<String, dynamic> args;
    if (kIsWeb) {
      _webBytes = await WebBookFileStore().read(widget.book.filePath);
      if (_webBytes == null) {
        throw StateError('Web 书籍文件不存在');
      }
      args = <String, dynamic>{'bytes': _webBytes, 'ext': widget.book.format};
    } else {
      args = <String, dynamic>{
        'path': widget.book.filePath,
        'ext': widget.book.format,
      };
    }
    return compute(indexComicPages, args);
  }

  Future<Uint8List> _loadPage(List<String> pages, int index) {
    final cached = _pageCache.remove(index);
    if (cached != null) {
      _pageCache[index] = cached; // 触碰后移到末尾（LRU 最新）。
      return SynchronousFuture<Uint8List>(cached);
    }
    final pending = _pendingPages[index];
    if (pending != null) return pending;
    final future = compute(extractComicPage, <String, dynamic>{
      if (kIsWeb) 'bytes': _webBytes else 'path': widget.book.filePath,
      'ext': widget.book.format,
      'name': pages[index],
    });
    _pendingPages[index] = future;
    future
        .then((bytes) {
          _pageCache[index] = bytes;
          while (_pageCache.length > _pageCacheLimit) {
            _pageCache.remove(_pageCache.keys.first);
          }
        })
        .whenComplete(() => _pendingPages.remove(index));
    return future;
  }

  void _saveProgress(int index, int pageCount) {
    final bookId = widget.book.id;
    if (bookId == null) return;
    unawaited(
      BookDao()
          .updateBookProgress(
            bookId,
            index,
            readingProgress: (index + 1) / pageCount,
          )
          .catchError((Object error) => debugPrint('保存漫画进度失败: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<List<String>>(
        future: _pagesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            final error = snapshot.error;
            // 真 RAR/7z 等无法解压的容器给「转 CBZ」引导，其余按原始错误展示。
            final message = error is ComicArchiveUnsupportedException
                ? (error.container == ComicContainerFormat.rar
                      ? l10n.readerComicCbrUnsupported
                      : l10n.readerComicArchiveUnsupported)
                : l10n.readerOpenFailed(error.toString());
            return PagedReaderMessageScaffold(
              title: widget.book.title,
              message: message,
              palette: widget.initialTheme,
            );
          }
          final pages = snapshot.data;
          if (pages == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          if (pages.isEmpty) {
            return PagedReaderMessageScaffold(
              title: widget.book.title,
              message: l10n.readerComicNoPages,
              palette: widget.initialTheme,
            );
          }
          return PagedImageReader(
            title: widget.book.title,
            pageCount: pages.length,
            initialPage: widget.book.currentPage,
            loadPage: (index) => _loadPage(pages, index),
            onPageChanged: (index) => _saveProgress(index, pages.length),
            bookId: widget.book.id,
          );
        },
      ),
    );
  }
}
