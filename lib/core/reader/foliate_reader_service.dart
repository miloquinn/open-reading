// 文件说明：Foliate 阅读器统一入口——所有格式走 Foliate-direct 路径，取代 WebReaderSourceService 和简化 ReadingRouterService。
// 技术要点：服务层、CanonicalLocator 双轨定位、TXTManifestBuilder、LocalReaderFileServer、Flutter 导航。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/foliate_bridge.dart';
import 'package:xxread/core/reader/txt_manifest_builder.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/foliate_reader_page.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/book_storage_repair_service.dart';
import 'package:xxread/services/core/app_state_service.dart';
import 'package:xxread/services/library/library_event_bus_service.dart';
import 'package:xxread/services/reading/local_reader_file_server.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

/// Foliate 阅读器统一入口服务。
///
/// 取代 WebReaderSourceService 和 ReadingRouterService 的组合职责：
/// - 所有格式统一走 Foliate-direct 阅读路径
/// - EPUB/MOBI/FB2/PDF 等视觉型格式通过 LocalReaderFileServer 提供本地 URL
/// - TXT 走 TXTManifestBuilder + LocalReaderFileServer 资源包路径
/// - 阅读进度基于 CanonicalLocator 持久化，取代纯 page_index
class FoliateReaderService {
  FoliateReaderService._();

  static const Set<String> _supportedFormats = <String>{
    'txt',
    'epub',
    'mobi',
    'azw',
    'azw3',
    'fb2',
    'rtf',
    'docx',
    'pdf',
  };

  /// TXT 走 Foliate manifest 路径的格式集合。
  static const Set<String> _txtDirectFormats = <String>{
    'txt',
  };

  /// 通过 LocalReaderFileServer 直接提供 URL 的格式集合。
  static const Set<String> _urlDirectFormats = <String>{
    'epub',
    'mobi',
    'azw',
    'azw3',
    'fb2',
    'pdf',
  };

  // ---- 公开 API ----

  /// 为书籍构建 FoliateOpenPayload，不含导航逻辑。
  ///
  /// 这是核心路由逻辑：
  /// - TXT: TXTManifestBuilder.buildPackage() 创建 manifest 和 XHTML 资源，
  ///   LocalReaderFileServer 为 manifest 和每个 XHTML 文件注册 URL，
  ///   payload 包含 manifestURL 指向 manifest.json 的本地 URL。
  /// - EPUB/MOBI/FB2/PDF: LocalReaderFileServer 为书籍文件注册 URL，
  ///   payload 不设 manifestURL，JS host 将从 URL 直接加载原始格式。
  /// - 其他文本型格式（RTF/DOCX）: 当前走 URL-direct 路径，
  ///   后续可按 TXT 同样模式迁到 manifest 路径。
  static Future<FoliateOpenPayload> resolveBook(Book book) async {
    final format = book.format.toLowerCase();
    final bookId = (book.id ?? 0).toString();
    final bookTitle = book.title;
    final language = _resolveLanguage(book);

    if (_txtDirectFormats.contains(format)) {
      return _resolveTXT(book, bookId, bookTitle, language);
    }

    if (_urlDirectFormats.contains(format)) {
      return _resolveURLDirect(book, bookId, bookTitle, language);
    }

    // 其他文本型格式暂走 URL-direct（RTF/DOCX 等）
    // 后续可按性能与批注需求迁到 manifest 模式
    return _resolveURLDirect(book, bookId, bookTitle, language);
  }

  /// 打开书籍：校验 → 修复 → 构建 payload → 导航到 FoliateReaderPage。
  static Future<void> openBook(BuildContext context, Book book) async {
    final repairedBook =
        await BookStorageRepairService().repairSingleBookIfNeeded(book);

    final file = File(repairedBook.filePath);
    if (!await file.exists()) {
      if (context.mounted) {
        showSideToast(context, '书籍文件不存在，可能已被移动或删除。请重新导入或从 WebDAV 恢复。');
      }
      debugPrint('[FoliateReaderService] 打开失败，书籍文件不存在: ${repairedBook.filePath}');
      return;
    }

    final format = repairedBook.format.toLowerCase();
    if (!_supportedFormats.contains(format)) {
      if (context.mounted) {
        showSideToast(
          context,
          '暂不支持 ${repairedBook.format.toUpperCase()}，当前支持 TXT / EPUB / MOBI / AZW / AZW3 / FB2 / RTF / DOCX / PDF。',
        );
      }
      return;
    }

    if (!context.mounted) return;

    await _navigateToReader(context, repairedBook);
  }

  /// 基于 CanonicalLocator 持久化阅读进度。
  ///
  /// 同时保存 canonical 和 rendered 信息：
  /// - canonical: 布局无关定位真相源，跨设备/跨排版可恢复
  /// - rendered: 当前设备/排版参数下的位置，仅用于 UI 快速恢复
  /// - 仍然更新 currentPage 以兼容旧链路
  static Future<void> saveProgress(
    String bookId,
    CanonicalLocator locator,
    RenderedLocator? rendered,
  ) async {
    final id = int.tryParse(bookId);
    if (id == null) return;

    try {
      final canonicalJson = LocatorCodec.encodeCanonicalLocator(locator);
      final currentPage = rendered?.position ?? locator.positionHint ?? 0;
      final renderedJson = rendered != null
          ? LocatorCodec.encodeRenderedLocator(rendered)
          : null;
      final layoutSig = rendered != null
          ? _computeLayoutSignature(rendered)
          : null;

      await BookDao().updateBookCanonicalLocator(
        id,
        canonicalJson,
        renderedJson,
        layoutSig,
        currentPage,
      );
    } catch (e) {
      debugPrint('[FoliateReaderService] 保存阅读进度失败: $e');
    }
  }

  /// 从数据库加载上次持久化的 CanonicalLocator。
  ///
  /// 返回 null 表示该书籍尚无 canonical 进度记录。
  static Future<CanonicalLocator?> loadProgress(String bookId) async {
    final id = int.tryParse(bookId);
    if (id == null) return null;

    try {
      final db = BookDao();
      final book = await db.getBookById(id);
      if (book == null || book.lastCanonicalLocator == null) return null;

      return book.toCanonicalLocator();
    } catch (e) {
      debugPrint('[FoliateReaderService] 加载阅读进度失败: $e');
      return null;
    }
  }

  /// 清理临时缓存：释放 LocalReaderFileServer 资源和 TXTManifestBuilder 旧缓存。
  static Future<void> cleanup() async {
    // LocalReaderFileServer 是持久单例，不做清理
    // TXTManifestBuilder 缓存按签名自动管理
    // 此方法保留为未来扩展点（如清理特定书籍的临时文件）
  }

  // ---- 内部实现 ----

  /// TXT 格式：通过 TXTManifestBuilder 构建资源包，
  /// LocalReaderFileServer 为 manifest 和 XHTML 文件注册 URL，
  /// payload 使用 manifestURL 让 JS host 直接读取 manifest。
  static Future<FoliateOpenPayload> _resolveTXT(
    Book book,
    String bookId,
    String bookTitle,
    String language,
  ) async {
    final file = File(book.filePath);
    final bytes = await file.readAsBytes();
    final stat = await file.stat();
    final content = TXTManifestBuilder.detectAndDecode(
      bytes,
      encodingOverride: book.textEncoding,
    );

    final chapters = TXTManifestBuilder.detectChapters(content);
    final totalUTF16Length = content.length;

    final sourceChapters = <TXTFoliateSourceChapter>[];
    for (final ch in chapters) {
      final start = ch.startUTF16Offset;
      final end = ch.endUTF16Offset.clamp(0, totalUTF16Length);
      final text = start < end
          ? content.substring(start, end)
          : '';
      sourceChapters.add(TXTFoliateSourceChapter(
        id: ch.id,
        chapterIndex: ch.chapterIndex,
        title: ch.title,
        level: ch.level,
        startUTF16Offset: start,
        endUTF16Offset: end,
        text: text,
      ));
    }

    final fingerprint = TXTSourceFingerprint(
      path: book.filePath,
      fileSize: stat.size,
      modifiedAt: stat.modified.millisecondsSinceEpoch,
    );

    final package = await TXTManifestBuilder.buildPackage(
      bookId: bookId,
      bookTitle: bookTitle,
      language: language,
      sourceFingerprint: fingerprint,
      sourceChapters: sourceChapters,
      totalUTF16Length: totalUTF16Length,
    );

    // 为 manifest.json 注册本地 URL
    final manifestURL =
        await LocalReaderFileServer.instance.registerBookFile(package.manifestPath);

    // 为每个 XHTML 章节文件注册本地 URL
    // JS host 通过 manifest 中的 href 引用章节，需要能通过本地 URL 访问
    for (final asset in package.chapterAssets) {
      final xhtmlPath = '${package.rootPath}/${asset.href}';
      await LocalReaderFileServer.instance.registerBookFile(xhtmlPath);
    }

    // 为 host index.html 注册本地 URL（JS host 入口）
    await LocalReaderFileServer.instance.registerBookFile(package.hostIndexPath);

    // 查找上次阅读位置
    final lastCanonical = book.lastCanonicalLocator;

    return FoliateOpenPayload(
      manifestURL: manifestURL,
      bookId: bookId,
      bookTitle: bookTitle,
      language: language,
      direction: 'ltr',
      estimatedTotalPages: package.chapterAssets.length,
      initialCanonicalLocator: lastCanonical,
      initialRenderedLocator: book.lastRenderedLocator,
    );
  }

  /// EPUB/MOBI/FB2/PDF 等视觉型格式：
  /// LocalReaderFileServer 为书籍文件注册 URL，
  /// payload 不设 manifestURL，JS host 从文件 URL 直接加载。
  static Future<FoliateOpenPayload> _resolveURLDirect(
    Book book,
    String bookId,
    String bookTitle,
    String language,
  ) async {
    await LocalReaderFileServer.instance.registerBookFile(book.filePath);

    // 查找上次阅读位置
    final lastCanonical = book.lastCanonicalLocator;

    return FoliateOpenPayload(
      manifestURL: null,
      bookId: bookId,
      bookTitle: bookTitle,
      language: language,
      direction: _resolveDirection(book),
      estimatedTotalPages: book.totalPages > 0 ? book.totalPages : 1,
      initialCanonicalLocator: lastCanonical,
      initialRenderedLocator: book.lastRenderedLocator,
    );
  }

  /// 导航到 FoliateReaderPage，含阅读前/后的记录与系统 UI 管理。
  static Future<void> _navigateToReader(BuildContext context, Book book) async {
    final hostBrightness = Theme.of(context).brightness;

    FoliateOpenPayload? payload;
    try {
      payload = await resolveBook(book);
    } catch (e) {
      debugPrint('[FoliateReaderService] Foliate 阅读资源准备失败: $e');
      if (context.mounted) {
        showSideToast(
          context,
          'Foliate 阅读资源准备失败：$e',
          icon: Icons.error_outline_rounded,
        );
      }
      return;
    }

    // payload 目前仅用于触发 resolveBook 的副作用（注册本地文件服务），
    // FoliateReaderPage 内部自行构建 openPayload。
    debugPrint('[FoliateReaderService] resolved payload for book: ${payload.bookId}');

    final page = FoliateReaderPage(
      book: book,
      sourceFilePath: book.filePath,
    );

    await _recordRecentReading(book);
    if (!context.mounted) return;

    await Navigator.push(
      context,
      _buildReaderOpenRoute(page: page),
    );

    _restoreHostSystemUI(hostBrightness);
    await _recordRecentReadingFromDatabase(book.id);
    LibraryEventBus().notifyLibraryChanged();
  }

  /// 构建阅读器打开路由动画。
  static Route<void> _buildReaderOpenRoute({required Widget page}) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final scale = Tween<double>(begin: 0.985, end: 1.0).animate(curve);
        return FadeTransition(
          opacity: curve,
          child: ScaleTransition(
            scale: scale,
            child: child,
          ),
        );
      },
    );
  }

  /// 恢复宿主页面的系统 UI。
  static void _restoreHostSystemUI(Brightness hostBrightness) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiHelper.overlayStyleForBrightness(hostBrightness),
    );
  }

  /// 阅读前记录最近阅读。
  static Future<void> _recordRecentReading(Book book) async {
    final bookId = book.id;
    if (bookId == null) return;
    try {
      final appState = AppStateService();
      if (!appState.isInitialized) {
        await appState.initialize();
      }
      await appState.setCurrentBook(bookId, book.title, book.currentPage);
    } catch (e) {
      debugPrint('[FoliateReaderService] 更新最近阅读失败: $e');
    }
  }

  /// 阅读结束后从数据库回写最近阅读。
  static Future<void> _recordRecentReadingFromDatabase(int? bookId) async {
    if (bookId == null) return;
    try {
      final latest = await BookDao().getBookById(bookId);
      if (latest == null) return;
      final appState = AppStateService();
      if (!appState.isInitialized) {
        await appState.initialize();
      }
      await appState.setCurrentBook(bookId, latest.title, latest.currentPage);
    } catch (e) {
      debugPrint('[FoliateReaderService] 回写最近阅读失败: $e');
    }
  }

  /// 推断书籍语言。
  static String _resolveLanguage(Book book) {
    // 优先使用书籍自带的语言信息
    // TXT 默认中文，EPUB/PDF 通常自带语言声明
    final format = book.format.toLowerCase();
    if (format == 'txt') return 'zh-Hans';
    return 'zh-Hans'; // 当前默认中文，后续可从元数据提取
  }

  /// 推断文字方向。
  static String _resolveDirection(Book book) {
    // 大多数中文书籍从左到右
    // 后续可从 EPUB 元数据或用户设置获取方向
    return 'ltr';
  }

  /// 计算布局签名——基于排版参数的确定性指纹。
  ///
  /// 任何影响分页结果的设置变更（字号、行高、边距、视口、翻页模式）
  /// 都会导致布局签名变化，旧分页缓存失效。
  /// 当前实现基于 rendered locator 中的隐含参数。
  /// 后续应从 FoliatePreferencesPayload 直接计算。
  static String _computeLayoutSignature(RenderedLocator rendered) {
    // 当前简化实现：使用 renderer + format + 总页数作为签名基础
    // 生产环境应从实际排版参数（字号/行高/边距/视口/翻页模式）计算
    final components = [
      rendered.renderer.name,
      rendered.format.name,
      rendered.totalPositions.toString(),
    ];
    return components.join('|');
  }
}
