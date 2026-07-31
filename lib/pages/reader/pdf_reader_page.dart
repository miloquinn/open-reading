// 文件说明：PDF 专用阅读页（整页位图渲染，不走文本行盒）。
// 技术要点：pdfx PdfDocument 打开文档；页渲染严格串行（Android 平台
// 不允许并行渲染，见 pdfx PdfPage.close 文档）；按屏幕像素密度选择
// 渲染分辨率，LRU 页缓存；UI 骨架复用 paged_image_reader.dart；
// 进度写回 currentPage。pdfx 无 Linux 实现，入口在 NativeReaderService 拦截。
// 格式能力矩阵见 docs/book-format-support.md

import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pdfx/pdfx.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/web_book_file_store.dart';
import 'package:xxread/services/reading/reading_resume_service.dart';
import 'package:xxread/pages/reader/paged_image_reader.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_transitions.dart';
import 'package:xxread/utils/reader_themes.dart';

class PdfReaderPage extends StatefulWidget {
  const PdfReaderPage({
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
      PdfReaderPage(book: book, initialTheme: initialTheme),
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
  State<PdfReaderPage> createState() => _PdfReaderPageState();
}

class _PdfReaderPageState extends State<PdfReaderPage> {
  /// 一页 A4 在 2x 密度下解码约 10MB，缓存别开太大。
  static const int _pageCacheLimit = 5;

  /// 渲染位图的最大宽度（像素）；超清屏也够锐利，同时限制内存。
  static const double _maxRenderWidth = 2160;

  late final Future<PdfDocument> _documentFuture;
  final LinkedHashMap<int, Uint8List> _pageCache = LinkedHashMap();
  final Map<int, Future<Uint8List>> _pendingPages = {};

  /// pdfx 要求前一页 close 后才能开下一页（Android 并行渲染会崩），
  /// 所有渲染任务串到这条链上依次执行。
  Future<void> _renderChain = Future<void>.value();

  /// 目标渲染宽度，首帧布局后由屏幕宽 × 像素密度确定。
  double _renderWidth = 1080;

  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    unawaited(ReadingResumeService.markReading(widget.book.id));
    _documentFuture = _openDocument();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _renderWidth = (media.size.width * media.devicePixelRatio).clamp(
      480,
      _maxRenderWidth,
    );
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(ReadingResumeService.markClosed(widget.book.id));
    // 等在途渲染排空后再关文档，避免 close 与 render 竞争。
    unawaited(
      _renderChain.whenComplete(() async {
        try {
          final document = await _documentFuture;
          await document.close();
        } catch (_) {
          // 文档没打开成功就无需关闭。
        }
      }),
    );
    super.dispose();
  }

  Future<PdfDocument> _openDocument() async {
    if (kIsWeb) {
      final bytes = await WebBookFileStore().read(widget.book.filePath);
      if (bytes == null) {
        throw StateError('Web 书籍文件不存在');
      }
      return PdfDocument.openData(bytes);
    }
    return PdfDocument.openFile(widget.book.filePath);
  }

  Future<Uint8List> _loadPage(PdfDocument document, int index) {
    final cached = _pageCache.remove(index);
    if (cached != null) {
      _pageCache[index] = cached; // 触碰后移到末尾（LRU 最新）。
      return SynchronousFuture<Uint8List>(cached);
    }
    final pending = _pendingPages[index];
    if (pending != null) return pending;

    final completer = Completer<Uint8List>();
    _pendingPages[index] = completer.future;
    _renderChain = _renderChain.then((_) async {
      try {
        if (_disposed) {
          throw StateError('reader disposed');
        }
        final bytes = await _renderPage(document, index);
        _pageCache[index] = bytes;
        while (_pageCache.length > _pageCacheLimit) {
          _pageCache.remove(_pageCache.keys.first);
        }
        completer.complete(bytes);
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingPages.remove(index);
      }
    });
    return completer.future;
  }

  Future<Uint8List> _renderPage(PdfDocument document, int index) async {
    final page = await document.getPage(index + 1); // pdfx 页码 1-based。
    try {
      final scale = _renderWidth / page.width;
      final image = await page.render(
        width: page.width * scale,
        height: page.height * scale,
        format: PdfPageImageFormat.png,
        // PDF 常见透明底，铺白底避免黑色背景下内容不可读。
        backgroundColor: '#FFFFFF',
      );
      if (image == null) {
        throw StateError('PDF page ${index + 1} render returned null');
      }
      return image.bytes;
    } finally {
      await page.close();
    }
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
          .catchError((Object error) => debugPrint('保存 PDF 进度失败: $error')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<PdfDocument>(
        future: _documentFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return PagedReaderMessageScaffold(
              title: widget.book.title,
              message: l10n.readerOpenFailed(snapshot.error.toString()),
              palette: widget.initialTheme,
            );
          }
          final document = snapshot.data;
          if (document == null) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            );
          }
          if (document.pagesCount <= 0) {
            return PagedReaderMessageScaffold(
              title: widget.book.title,
              message: l10n.readerComicNoPages,
              palette: widget.initialTheme,
            );
          }
          return PagedImageReader(
            title: widget.book.title,
            pageCount: document.pagesCount,
            initialPage: widget.book.currentPage,
            loadPage: (index) => _loadPage(document, index),
            onPageChanged: (index) => _saveProgress(index, document.pagesCount),
            bookId: widget.book.id,
          );
        },
      ),
    );
  }
}
