// 文件说明：书库页面，负责书籍列表、筛选、排序和进入阅读。
// 技术要点：Flutter UI、文件系统、渲染层。

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollCacheExtent;
import 'package:flutter/services.dart';
import '../models/book.dart';
import '../services/books/book_services.dart';
import '../services/library/library_services.dart';
import '../core/reader/native_reader_service.dart';
import '../widgets/side_toast.dart';
import 'import_book_page.dart';
import 'home_layout_constants.dart';
import 'home_shell_page.dart';
import '../utils/layout_helper.dart';
import '../widgets/scrolling_text.dart';
import '../utils/glass_config.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import '../utils/system_ui_helper.dart';
import '../utils/ui_style.dart';
import '../widgets/app_brand_icon.dart';

enum _LibraryFilter {
  all,
  reading,
  finished,
}

class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Book> _books = [];
  bool _isLoading = true;
  final _bookDao = BookDao();
  StreamSubscription<void>? _librarySubscription;
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  String _searchQuery = '';
  _LibraryFilter _selectedFilter = _LibraryFilter.all;

  bool get _isMaterial3Style {
    return Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
  }

  BoxDecoration _panelDecoration({
    double radius = 16,
    bool stronger = false,
    bool addShadow = false,
    double borderAlpha = 0.12,
    Color? color,
  }) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = PageStyleHelper.palette(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMaterial3Style = _isMaterial3Style;
    return BoxDecoration(
      color: color ??
          (isMaterial3Style
              ? (stronger
                  ? scheme.surfaceContainer
                  : scheme.surfaceContainerLow)
              : (stronger ? palette.cardStrong : palette.card)),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: scheme.outline.withValues(
          alpha: isMaterial3Style ? 0.22 : borderAlpha,
        ),
        width: 0.9,
      ),
      boxShadow: addShadow
          ? [
              BoxShadow(
                color: scheme.shadow.withValues(
                  alpha: isMaterial3Style
                      ? (isDark ? 0.16 : 0.07)
                      : (isDark ? 0.24 : 0.09),
                ),
                blurRadius: isMaterial3Style ? 12 : 16,
                offset: Offset(0, isMaterial3Style ? 6 : 8),
              ),
            ]
          : null,
    );
  }

  @override
  void initState() {
    super.initState();
    _loadBooks();
    _librarySubscription = LibraryEventBus().stream.listen((_) {
      if (mounted) {
        _loadBooks();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _setupThemeBasedImmersiveMode();
  }

  @override
  void dispose() {
    _librarySubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 120), () {
      if (!mounted) return;
      if (_searchQuery == value) return;
      setState(() => _searchQuery = value);
    });
  }

  bool _shouldApplySystemUI() {
    final route = ModalRoute.of(context);
    return route?.isCurrent ?? true;
  }

  void _setupThemeBasedImmersiveMode() {
    if (!_shouldApplySystemUI()) {
      return;
    }
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      Theme.of(context).brightness,
    );
    SystemChrome.setSystemUIOverlayStyle(overlayStyle);
  }

  Future<void> _loadBooks() async {
    setState(() => _isLoading = true);
    try {
      final books = await _bookDao.getAllBooks();
      if (mounted) {
        setState(() {
          _books = books;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
      // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    // 检查是否在侧边导航栏模式下
    final navContext = NavigationContext.of(context);
    final useRailNavigation = navContext?.useRailNavigation ?? false;
    final scheme = Theme.of(context).colorScheme;
    final appBarColor = _isMaterial3Style ? scheme.surface : Colors.transparent;

    // 在侧边导航栏模式下，不显示 Scaffold 和 AppBar
    if (useRailNavigation) {
      return _buildContent(context, useRailNavigation: useRailNavigation);
    }

    // 手机模式：显示完整的 Scaffold + AppBar
    return Scaffold(
      extendBody: true, // 让内容延伸到导航区，配合手势小白条
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: appBarColor,
        elevation: 0,
        toolbarHeight: 0,
        surfaceTintColor: appBarColor,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiHelper.overlayStyleForBrightness(
          Theme.of(context).brightness,
        ),
      ),
      body: _buildContent(context, useRailNavigation: useRailNavigation),
      // 手机端改为顶部“+”按钮入口，宽屏继续保留FAB
      floatingActionButton:
          LayoutHelper.getNavigationType(context) == NavigationType.rail
              ? _buildFloatingActionButton()
              : null,
    );
  }

  // 提取页面内容部分，在两种模式下共用
  Widget _buildContent(BuildContext context,
      {required bool useRailNavigation}) {
    final books = _visibleBooks;
    final palette = PageStyleHelper.palette(context);
    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (useRailNavigation) ...[
              _buildTopBar(),
              const SizedBox(height: 10),
            ] else ...[
              const SizedBox(height: kHomeMobileTopBarHeight + 8),
            ],
            _buildSearchBar(),
            const SizedBox(height: 10),
            _buildShelfSummaryCard(),
            const SizedBox(height: 8),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _books.isEmpty
                      ? _buildEmptyLibrary()
                      : books.isEmpty
                          ? _buildNoSearchResult()
                          : RefreshIndicator(
                              onRefresh: _loadBooks,
                              strokeWidth: 2.5,
                              displacement: 48,
                              color: Theme.of(context).colorScheme.primary,
                              backgroundColor: palette.cardStrong,
                              child: _buildBooksGrid(books),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  List<Book> get _visibleBooks {
    final filteredByStatus =
        _books.where((book) => _matchesSelectedFilter(book)).toList();
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return filteredByStatus;
    return filteredByStatus.where((book) {
      return book.title.toLowerCase().contains(query) ||
          book.author.toLowerCase().contains(query);
    }).toList();
  }

  bool _matchesSelectedFilter(Book book) {
    switch (_selectedFilter) {
      case _LibraryFilter.all:
        return true;
      case _LibraryFilter.reading:
        return _isReadingBook(book);
      case _LibraryFilter.finished:
        return _isFinishedBook(book);
    }
  }

  bool _isFinishedBook(Book book) {
    if (book.totalPages <= 0) {
      return false;
    }
    return book.currentPage >= book.totalPages;
  }

  bool _isReadingBook(Book book) {
    return book.currentPage > 0 && !_isFinishedBook(book);
  }

  Widget _buildTopBar() {
    final palette = PageStyleHelper.palette(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(
            context.l10n.library,
            style: TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.w700,
              color: Theme.of(context).colorScheme.onSurface,
              height: 1.05,
            ),
          ),
          const Spacer(),
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImportBookPage()),
              );
              if (result == true && mounted) {
                _loadBooks();
              }
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: _panelDecoration(
                radius: 22,
                stronger: true,
                color:
                    _isMaterial3Style ? scheme.surfaceContainer : palette.card,
              ),
              child: Icon(
                Icons.add_rounded,
                color: palette.iconMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    final palette = PageStyleHelper.palette(context);
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        height: 52,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: _panelDecoration(
          radius: 14,
          stronger: true,
          color: _isMaterial3Style ? scheme.surfaceContainerLow : palette.card,
        ),
        child: Row(
          children: [
            Icon(
              Icons.search_rounded,
              size: 18,
              color: palette.textMuted,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _searchController,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: context.l10n.librarySearchHint,
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              InkWell(
                onTap: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: palette.textMuted,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildShelfSummaryCard() {
    final palette = PageStyleHelper.palette(context);
    final scheme = Theme.of(context).colorScheme;
    final total = _books.length;
    final inReading = _books.where(_isReadingBook).length;
    final finished = _books.where(_isFinishedBook).length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: _panelDecoration(
          radius: 18,
          stronger: true,
          color: _isMaterial3Style ? scheme.surfaceContainerHigh : palette.hero,
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _buildStatChip(
              label: context.l10n.libraryFilterAll(total),
              active: _selectedFilter == _LibraryFilter.all,
              onTap: () => setState(() => _selectedFilter = _LibraryFilter.all),
            ),
            _buildStatChip(
              label: context.l10n.libraryFilterReading(inReading),
              active: _selectedFilter == _LibraryFilter.reading,
              onTap: () =>
                  setState(() => _selectedFilter = _LibraryFilter.reading),
            ),
            _buildStatChip(
              label: context.l10n.libraryFilterFinished(finished),
              active: _selectedFilter == _LibraryFilter.finished,
              onTap: () =>
                  setState(() => _selectedFilter = _LibraryFilter.finished),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatChip({
    required String label,
    required bool active,
    required VoidCallback onTap,
  }) {
    final palette = PageStyleHelper.palette(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: active
                ? (_isMaterial3Style
                    ? scheme.primaryContainer
                    : scheme.primary.withValues(alpha: 0.16))
                : (_isMaterial3Style
                    ? scheme.surfaceContainerLow
                    : palette.cardStrong),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: active
                  ? scheme.primary
                      .withValues(alpha: _isMaterial3Style ? 0.30 : 0.2)
                  : scheme.outline
                      .withValues(alpha: _isMaterial3Style ? 0.18 : 0.08),
              width: 0.8,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: active ? FontWeight.w700 : FontWeight.w600,
              color: active
                  ? Theme.of(context).colorScheme.primary
                  : palette.textMuted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final isTablet = LayoutHelper.isTablet(context);
    final isDesktop = LayoutHelper.isDesktop(context);
    final useRailNav = isTablet || isDesktop;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final scheme = Theme.of(context).colorScheme;

    // 侧边导航栏模式：FAB 在右下角，边距较小
    // 底部导航栏模式：FAB 需要避开导航栏
    final double bottomMargin = useRailNav
        ? bottomPadding + 16 // 侧边导航：只需避开安全区域
        : 68 + 25 + bottomPadding.clamp(0.0, 50.0) + 15; // 底部导航：避开悬浮导航栏

    if (_isMaterial3Style) {
      return Container(
        margin: EdgeInsets.only(bottom: bottomMargin),
        child: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const ImportBookPage(),
              ),
            );
            if (result == true && mounted) {
              _loadBooks();
            }
          },
          backgroundColor: scheme.primaryContainer,
          foregroundColor: scheme.onPrimaryContainer,
          elevation: 2,
          heroTag: "add_book_fab",
          child: const Icon(Icons.add, size: 28),
        ),
      );
    }

    return Container(
      margin: EdgeInsets.only(bottom: bottomMargin),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          enabled: !GlassEffectConfig.shouldDisableBlur,
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: FloatingActionButton(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImportBookPage(),
                ),
              );
              // 导入完成后刷新书籍列表
              if (result == true && mounted) {
                _loadBooks();
              }
            },
            backgroundColor: Theme.of(
              context,
            ).colorScheme.primary.withValues(
                  alpha: GlassEffectConfig.effectiveOpacity(0.9),
                ),
            foregroundColor: Colors.white,
            elevation: 0,
            heroTag: "add_book_fab", // 添加唯一标识避免冲突
            child: const Icon(Icons.add, size: 28),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyLibrary() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const AppBrandIcon(size: 56, borderRadius: 14),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ImportBookPage(),
                ),
              );
              _loadBooks();
            },
            icon: const Icon(Icons.add),
            label: Text(context.l10n.importBooks),
          ),
        ],
      ),
    );
  }

  Widget _buildNoSearchResult() {
    final palette = PageStyleHelper.palette(context);
    final hasSearch = _searchQuery.trim().isNotEmpty;
    final message = hasSearch
        ? context.l10n.libraryNoMatchingBooks
        : switch (_selectedFilter) {
            _LibraryFilter.reading => context.l10n.libraryNoReadingBooks,
            _LibraryFilter.finished => context.l10n.libraryNoFinishedBooks,
            _LibraryFilter.all => context.l10n.libraryNoBooks,
          };

    return Center(
      child: Text(
        message,
        style: TextStyle(
          fontSize: 16,
          color: palette.textMuted,
        ),
      ),
    );
  }

  Widget _buildBooksGrid(List<Book> books) {
    final useRail =
        LayoutHelper.getNavigationType(context) == NavigationType.rail;
    if (!useRail) {
      return _buildBooksList(books);
    }

    final isDesktop = LayoutHelper.isDesktop(context);
    final isTablet = LayoutHelper.isTablet(context);
    final media = MediaQuery.of(context);
    final isTabletLandscape = isTablet && media.size.width > media.size.height;

    // 毛玻璃效果增强 - 网格容器背景
    // 为整个书籍网格添加细微的毛玻璃背景层

    // 使用 LayoutHelper 获取响应式列数和纵横比
    int crossAxisCount = LayoutHelper.getBookGridColumns(context);

    // 根据屏幕类型调整间距
    double spacing;
    if (isDesktop) {
      spacing = 16;
    } else if (isTablet) {
      spacing = 14;
    } else {
      spacing = 12;
    }

    final gap = isTabletLandscape
        ? 6.0
        : isTablet
            ? 5.0
            : 6.0;
    final textHeight = isTabletLandscape
        ? 50.0
        : isTablet
            ? 40.0
            : 36.0;
    final coverWidthScale = isTabletLandscape ? 0.75 : 1.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 让网格高度为 2:3 封面 + 文本区域预留高度（更接近常见书封比例）
        const double horizontalPadding = 32.0;
        final totalSpacing = spacing * (crossAxisCount - 1);
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - horizontalPadding - totalSpacing,
        );
        final itemWidth = availableWidth / crossAxisCount;
        final itemHeight =
            ((itemWidth * coverWidthScale) * 3 / 2) + textHeight + gap;
        final childAspectRatio = itemWidth > 0 ? itemWidth / itemHeight : 0.75;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: const [0.0, 0.3, 0.7, 1.0],
              colors: [
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
                Theme.of(
                  context,
                ).colorScheme.primaryContainer.withValues(alpha: 0.03),
                Theme.of(
                  context,
                ).colorScheme.secondaryContainer.withValues(alpha: 0.03),
                Theme.of(context).colorScheme.surface.withValues(alpha: 0.0),
              ],
            ),
          ),
          child: GridView.builder(
            scrollCacheExtent: const ScrollCacheExtent.pixels(720),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              // 精确计算悬浮导航栏占用空间：导航栏68px + 边距25px + 底部安全区域(限制最大值) + 10px缓冲
              68 +
                  25 +
                  (MediaQuery.of(context).padding.bottom).clamp(0.0, 50.0) +
                  10,
            ),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              crossAxisSpacing: spacing,
              mainAxisSpacing: spacing + 8,
              childAspectRatio: childAspectRatio,
            ),
            itemCount: books.length,
            itemBuilder: (context, index) {
              final book = books[index];
              return RepaintBoundary(
                child: _BookCoverItem(
                  book: book,
                  onTap: () async {
                    final fullBook = await _bookDao.getBookById(book.id!);
                    if (fullBook != null && mounted && context.mounted) {
                      // 直接打开沉浸式阅读器
                      await NativeReaderService.openBook(context, fullBook);
                      _loadBooks();
                    }
                  },
                  onLongPress: () => _showBookOptions(book),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildBooksList(List<Book> books) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView.builder(
      scrollCacheExtent: const ScrollCacheExtent.pixels(720),
      padding: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        68 + 25 + MediaQuery.of(context).padding.bottom.clamp(0.0, 50.0) + 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final progress = book.totalPages > 0
            ? (book.currentPage / book.totalPages).clamp(0.0, 1.0)
            : 0.0;
        final progressText =
            context.l10n.libraryProgressContinue((progress * 100).round());

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Material(
            color: _isMaterial3Style
                ? scheme.surfaceContainerLow
                : scheme.surface.withValues(alpha: 0.86),
            surfaceTintColor: Colors.transparent,
            elevation: _isMaterial3Style ? 1 : 0,
            shadowColor:
                scheme.shadow.withValues(alpha: _isMaterial3Style ? 0.07 : 0.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: scheme.outline
                    .withValues(alpha: _isMaterial3Style ? 0.2 : 0.12),
                width: 0.8,
              ),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final fullBook = await _bookDao.getBookById(book.id!);
                if (fullBook != null && mounted && context.mounted) {
                  await NativeReaderService.openBook(context, fullBook);
                  _loadBooks();
                }
              },
              onLongPress: () => _showBookOptions(book),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 64,
                      height: 92,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: _buildListCover(context, book),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            book.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            progressText,
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.58),
                            ),
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: Theme.of(context)
                                  .colorScheme
                                  .primary
                                  .withValues(alpha: 0.12),
                              valueColor: AlwaysStoppedAnimation(
                                  Theme.of(context).colorScheme.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.35),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildListCover(BuildContext context, Book book) {
    if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
      final fit = Platform.isAndroid ? BoxFit.contain : BoxFit.cover;
      // 列表封面显示宽度固定 64，按屏幕像素密度限制解码尺寸即可
      return Image.file(
        File(book.coverImagePath!),
        fit: fit,
        cacheWidth: (64 * MediaQuery.of(context).devicePixelRatio).round(),
        gaplessPlayback: true,
        errorBuilder: (context, error, stackTrace) =>
            _buildListDefaultCover(context, book),
      );
    }
    return _buildListDefaultCover(context, book);
  }

  Widget _buildListDefaultCover(BuildContext context, Book book) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: const Center(
        child: AppBrandIcon(
          size: 40,
          borderRadius: 9,
        ),
      ),
    );
  }

  void _showBookOptions(Book book) {
    final scheme = Theme.of(context).colorScheme;
    final isMaterial3Style = _isMaterial3Style;
    final useBlur = !isMaterial3Style && !GlassEffectConfig.shouldDisableBlur;
    showModalBottomSheet(
      context: context,
      backgroundColor:
          isMaterial3Style ? scheme.surfaceContainerHigh : Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        final localScheme = Theme.of(context).colorScheme;
        final content = Container(
          decoration: BoxDecoration(
            color: isMaterial3Style
                ? localScheme.surfaceContainerHigh
                : GlassEffectConfig.surfaceColor(context, opacity: 0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                color: localScheme.outline.withValues(
                  alpha: isMaterial3Style ? 0.24 : 0.2,
                ),
                width: 1,
              ),
            ),
            boxShadow: isMaterial3Style
                ? [
                    BoxShadow(
                      color: localScheme.shadow.withValues(alpha: 0.08),
                      blurRadius: 16,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : null,
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: localScheme.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Row(
                    children: [
                      Container(
                        width: 50,
                        height: 70,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              localScheme.primary.withValues(alpha: 0.8),
                              localScheme.secondary.withValues(alpha: 0.6),
                            ],
                          ),
                          border: Border.all(
                            color: localScheme.outline.withValues(
                              alpha: isMaterial3Style ? 0.22 : 0.12,
                            ),
                            width: 0.8,
                          ),
                          boxShadow: isMaterial3Style
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                        ),
                        child: book.coverImagePath != null &&
                                book.coverImagePath!.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.file(
                                  File(book.coverImagePath!),
                                  fit: Platform.isAndroid
                                      ? BoxFit.contain
                                      : BoxFit.cover,
                                  cacheWidth: (50 *
                                          MediaQuery.of(context)
                                              .devicePixelRatio)
                                      .round(),
                                ),
                              )
                            : const Center(
                                child: AppBrandIcon(
                                  size: 24,
                                  borderRadius: 6,
                                ),
                              ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              book.title,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleMedium
                                  ?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              book.author,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: localScheme.onSurface
                                        .withValues(alpha: 0.6),
                                  ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                AppBrandIcon(
                                  size: 14,
                                  borderRadius: 4,
                                  border: Border.all(
                                    color: localScheme.primary
                                        .withValues(alpha: 0.22),
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${((book.currentPage / (book.totalPages > 0 ? book.totalPages : 1)) * 100).toStringAsFixed(1)}%',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: localScheme.primary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Divider(
                  height: 1,
                  thickness: 1,
                  color: localScheme.outline.withValues(alpha: 0.15),
                ),
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Column(
                    children: [
                      _buildOptionItem(
                        context: context,
                        icon: Icons.play_circle_outline,
                        iconColor: localScheme.primary,
                        title: context.l10n.continueReading,
                        subtitle: book.currentPage > 0
                            ? context.l10n.libraryPageNumber(book.currentPage)
                            : context.l10n.libraryStartFromBeginning,
                        backgroundColor:
                            localScheme.primaryContainer.withValues(
                          alpha: isMaterial3Style ? 0.42 : 0.15,
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          final fullBook = await _bookDao.getBookById(book.id!);
                          if (fullBook != null && context.mounted) {
                            await NativeReaderService.openBook(
                                context, fullBook);
                            _loadBooks();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildOptionItem(
                        context: context,
                        icon: Icons.info_outline,
                        iconColor: localScheme.tertiary,
                        title: context.l10n.libraryBookInfo,
                        subtitle: context.l10n.libraryFormatAndPages(
                          book.format.toUpperCase(),
                          book.totalPages,
                        ),
                        backgroundColor:
                            localScheme.tertiaryContainer.withValues(
                          alpha: isMaterial3Style ? 0.44 : 0.15,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _showBookInfo(book);
                        },
                      ),
                      const SizedBox(height: 8),
                      _buildOptionItem(
                        context: context,
                        icon: Icons.delete_outline_rounded,
                        iconColor: localScheme.error,
                        title: context.l10n.deleteBook,
                        subtitle: context.l10n.libraryDeleteBookHint,
                        backgroundColor: localScheme.errorContainer.withValues(
                          alpha: isMaterial3Style ? 0.46 : 0.15,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          _confirmDeleteBook(book);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );

        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: useBlur
              ? BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 25, sigmaY: 25),
                  child: content,
                )
              : content,
        );
      },
    );
  }

  /// 构建操作选项项
  Widget _buildOptionItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required VoidCallback onTap,
  }) {
    final isMaterial3Style = Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: iconColor.withValues(alpha: isMaterial3Style ? 0.28 : 0.2),
              width: isMaterial3Style ? 0.9 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.6),
                          ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: Theme.of(context)
                    .colorScheme
                    .onSurface
                    .withValues(alpha: 0.4),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 显示书籍详细信息
  void _showBookInfo(Book book) {
    final scheme = Theme.of(context).colorScheme;
    final isMaterial3Style = _isMaterial3Style;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isMaterial3Style
            ? scheme.surfaceContainerHigh
            : scheme.surface.withValues(alpha: 0.95),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(context.l10n.libraryBookInfo),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(context.l10n.libraryBookTitle, book.title),
            const SizedBox(height: 12),
            _buildInfoRow(context.l10n.author, book.author),
            const SizedBox(height: 12),
            _buildInfoRow(
                context.l10n.libraryFormat, book.format.toUpperCase()),
            const SizedBox(height: 12),
            _buildInfoRow(context.l10n.totalPages,
                context.l10n.libraryPagesCount(book.totalPages)),
            const SizedBox(height: 12),
            _buildInfoRow(context.l10n.currentPage,
                context.l10n.libraryPagesCount(book.currentPage)),
            const SizedBox(height: 12),
            _buildInfoRow(
              context.l10n.readingProgress,
              '${((book.currentPage / (book.totalPages > 0 ? book.totalPages : 1)) * 100).toStringAsFixed(1)}%',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.libraryClose),
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteBook(Book book) {
    final isMaterial3Style = _isMaterial3Style;
    final scheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (context) {
        final dialog = AlertDialog(
          backgroundColor: isMaterial3Style
              ? scheme.surfaceContainerHigh
              : GlassEffectConfig.surfaceColor(
                  context,
                  opacity: 0.95,
                ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            context.l10n.libraryConfirmDeleteTitle,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          content: Text(context.l10n.libraryDeleteBookMessage(book.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(context.l10n.cancel),
            ),
            TextButton(
              onPressed: () async {
                final navigator = Navigator.of(context);
                final toastContext = this.context;
                navigator.pop();

                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (context) => PopScope(
                    canPop: false,
                    child: AlertDialog(
                      backgroundColor: isMaterial3Style
                          ? scheme.surfaceContainerHigh
                          : Theme.of(
                              context,
                            ).colorScheme.surface.withValues(alpha: 0.95),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      content: Row(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Text(
                              context.l10n.libraryDeletingBook(book.title),
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );

                try {
                  await _performBookDeletion(book);
                  if (!mounted) return;

                  navigator.pop();
                  _loadBooks();
                  if (!toastContext.mounted) return;
                  showSideToast(toastContext,
                      toastContext.l10n.libraryBookDeletedToast(book.title));
                } catch (e) {
                  if (!mounted) return;
                  navigator.pop();

                  if (!toastContext.mounted) return;
                  showSideToast(toastContext,
                      toastContext.l10n.libraryDeleteFailed('$e'));
                }
              },
              child: Text(
                context.l10n.delete,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                ),
              ),
            ),
          ],
        );

        if (isMaterial3Style || GlassEffectConfig.shouldDisableBlur) {
          return dialog;
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: dialog,
          ),
        );
      },
    );
  }

  /// 执行书籍删除操作（在后台执行）
  ///
  /// 彻底删除书籍及其所有相关文件和缓存：
  /// 1. 删除书籍原文件
  /// 2. 删除封面图片文件
  /// 3. 删除分页缓存文件
  /// 4. 删除数据库记录（会级联删除笔记、书签等）
  ///
  /// 参数 [onProgress] 进度回调，用于更新UI提示信息
  Future<void> _performBookDeletion(
    Book book, {
    void Function(String message)? onProgress,
  }) async {
    debugPrint('🗑️ 开始删除书籍: ${book.title}');
    final l10n = context.l10n;
    final startTime = DateTime.now();

    try {
      // 1. 删除书籍文件
      onProgress?.call(l10n.libraryDeletingBookFile);
      final file = File(book.filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('✅ 已删除书籍文件: ${book.filePath}');
      } else {
        debugPrint('⚠️ 书籍文件不存在: ${book.filePath}');
      }

      // 2. 删除封面图片文件
      onProgress?.call(l10n.libraryDeletingCoverImage);
      if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
        final coverFile = File(book.coverImagePath!);
        if (await coverFile.exists()) {
          await coverFile.delete();
          debugPrint('✅ 已删除封面图片: ${book.coverImagePath}');
        }
      }

      // 3. 删除数据库记录（会级联删除笔记、书签等）
      onProgress?.call(l10n.libraryCleaningDatabase);
      await _bookDao.deleteBook(book.id!);
      debugPrint('✅ 已删除数据库记录');

      final duration = DateTime.now().difference(startTime).inMilliseconds;
      debugPrint('🎉 书籍删除完成: ${book.title} (总耗时: ${duration}ms)');
      onProgress?.call(l10n.libraryDeleteComplete);
    } catch (e, stackTrace) {
      debugPrint('❌ 删除书籍失败: $e');
      debugPrint('堆栈跟踪: $stackTrace');
      rethrow;
    }
  }
}

class _BookCoverItem extends StatelessWidget {
  final Book book;
  final Future<void> Function() onTap;
  final VoidCallback onLongPress;

  const _BookCoverItem({
    required this.book,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final progress =
        book.currentPage / (book.totalPages > 0 ? book.totalPages : 1);

    return InkWell(
      onTap: () => unawaited(onTap()),
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final theme = Theme.of(context);
          final scheme = theme.colorScheme;
          final isMaterial3Style =
              theme.extension<UiStyleThemeExtension>()?.isMaterial3Style ??
                  false;
          final isTablet = LayoutHelper.isTablet(context);
          final media = MediaQuery.of(context);
          final isTabletLandscape =
              isTablet && media.size.width > media.size.height;
          final gap = isTabletLandscape
              ? 6.0
              : isTablet
                  ? 5.0
                  : 6.0;
          final textHeight = isTabletLandscape
              ? 50.0
              : isTablet
                  ? 40.0
                  : 36.0;
          final coverWidthScale = isTabletLandscape ? 0.75 : 1.0;
          final maxWidth = constraints.maxWidth;
          final maxHeight = constraints.maxHeight;
          final coverWidth = maxWidth * coverWidthScale;
          final targetCoverHeight = coverWidth * 3 / 2;
          final availableCoverHeight =
              math.max(0.0, maxHeight - textHeight - gap);
          final coverHeight = math.min(availableCoverHeight, targetCoverHeight);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 书籍封面区域 - 2:3比例，但不超过可用高度
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: coverWidth,
                  height: coverHeight,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: scheme.shadow.withValues(
                            alpha: isMaterial3Style ? 0.08 : 0.15,
                          ),
                          blurRadius: isMaterial3Style ? 6 : 8,
                          offset: const Offset(0, 3),
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // 封面图片或默认图标
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _buildCoverImage(context, book),
                        ),
                        // 阅读进度指示器（仅在有进度时显示）
                        if (progress > 0)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 4,
                              decoration: BoxDecoration(
                                color: scheme.scrim.withValues(
                                  alpha: isMaterial3Style ? 0.2 : 0.3,
                                ),
                                borderRadius: const BorderRadius.only(
                                  bottomLeft: Radius.circular(12),
                                  bottomRight: Radius.circular(12),
                                ),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: scheme.primary,
                                    borderRadius: const BorderRadius.only(
                                      bottomLeft: Radius.circular(12),
                                      bottomRight: Radius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        // "在读"标签
                        if (book.currentPage > 0)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isMaterial3Style
                                    ? null
                                    : [
                                        BoxShadow(
                                          color: Colors.black
                                              .withValues(alpha: 0.2),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                              ),
                              child: Text(
                                context.l10n.libraryReadingBadge,
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: gap),
              // 书籍信息区域 - 固定高度
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  width: coverWidth,
                  height: textHeight,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(2, 0, 2, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 书名：超长时自动滚动
                        Expanded(
                          child: ScrollingText(
                            text: book.title,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                      height: 1.15,
                                    ),
                            duration: const Duration(seconds: 5),
                            pauseDuration: const Duration(milliseconds: 1200),
                          ),
                        ),
                        SizedBox(height: isTabletLandscape ? 1.5 : 2),
                        // 作者信息
                        Text(
                          book.author,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant
                                        .withValues(alpha: 0.78),
                                    fontSize: 11,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCoverImage(BuildContext context, Book book) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isMaterial3Style =
        theme.extension<UiStyleThemeExtension>()?.isMaterial3Style ?? false;
    if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
      final fit = Platform.isAndroid ? BoxFit.contain : BoxFit.cover;
      // 有封面图片时，直接显示真实的书籍封面
      // cacheWidth 限制解码分辨率：网格封面显示宽度不会超过 ~240 逻辑像素，
      // 全分辨率解码原图会占用大量内存并在滑动切页时造成掉帧。
      final cacheWidth =
          (240 * MediaQuery.of(context).devicePixelRatio).round();
      return SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: ColoredBox(
          color:
              scheme.surface.withValues(alpha: isMaterial3Style ? 0.2 : 0.12),
          child: Image.file(
            File(book.coverImagePath!),
            fit: fit,
            cacheWidth: cacheWidth,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) {
              return _buildDefaultCover(context);
            },
          ),
        ),
      );
    } else {
      // 没有封面图片时，显示默认封面设计
      return _buildDefaultCover(context);
    }
  }

  /// 构建默认封面设计
  Widget _buildDefaultCover(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            Theme.of(context).colorScheme.secondary.withValues(alpha: 0.6),
          ],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const AppBrandIcon(
            size: 48,
            borderRadius: 12,
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              book.title,
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                height: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
