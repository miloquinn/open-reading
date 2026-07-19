// 文件说明：书库页面，负责书籍列表、筛选、排序和进入阅读。
// 技术要点：Flutter UI、文件系统、渲染层。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/core/reader/native_reader_service.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/pages/home/home_mobile_chrome.dart';
import 'package:xxread/pages/home/home_shell_page.dart';
import 'package:xxread/pages/reader/book_source_reader_page.dart';
import 'package:xxread/services/books/book_services.dart';
import 'package:xxread/services/library/library_services.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/layout_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/utils/ui_style.dart';
import 'package:xxread/widgets/app_brand_icon.dart';
import 'package:xxread/widgets/generated_book_cover.dart';
import 'package:xxread/widgets/scrolling_text.dart';
import 'package:xxread/widgets/side_toast.dart';

import 'import_book/import_book_page.dart';

enum _LibraryFilter {
  all,
  reading,
  finished,
}

/// 首页壳层顶栏与书库页之间的桥：顶栏按钮触发搜索/筛选，
/// 书库页把筛选是否生效同步回来点亮按钮。
class LibraryPageController {
  _LibraryPageState? _state;

  /// 当前是否有生效的筛选（非“全部”）。顶栏据此点亮筛选按钮。
  final ValueNotifier<bool> filterActive = ValueNotifier<bool>(false);

  void toggleSearch() => _state?._toggleSearchBar();

  Future<void> showFilterMenu(Rect anchor) async =>
      _state?._showFilterMenu(anchor);

  void dispose() => filterActive.dispose();
}

class LibraryPage extends StatefulWidget {
  final LibraryPageController? controller;

  const LibraryPage({super.key, this.controller});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  List<Book> _books = [];
  bool _isInitialLoading = true;
  final _bookDao = BookDao();
  final _sourceShelfService = BookSourceShelfService();
  StreamSubscription<void>? _librarySubscription;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  Timer? _searchDebounce;
  String _searchQuery = '';
  bool _searchBarVisible = false;
  _LibraryFilter _selectedFilter = _LibraryFilter.all;

  /// 每本书封面组件的 key，用于打开/退出动画捕获与回溯封面位置。
  final Map<int, GlobalKey> _coverKeys = <int, GlobalKey>{};

  GlobalKey _coverKeyFor(Book book) =>
      _coverKeys.putIfAbsent(book.id!, () => GlobalKey());

  bool get _isMaterial3Style {
    return Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
  }

  Future<void> _openBook(Book book, {BookOpenAnimation? animation}) async {
    final fullBook = await _bookDao.getBookById(book.id!);
    if (fullBook == null || !mounted) return;
    if (fullBook.isOnline) {
      try {
        final source = _sourceShelfService.sourceFrom(fullBook);
        final sourceBook = _sourceShelfService.sourceBookFrom(fullBook);
        await Navigator.of(context).push<void>(
          BookOpenTransition.createRoute<void>(
            BookSourceReaderPage(
              source: source,
              book: sourceBook,
              shelfService: _sourceShelfService,
            ),
            animation: animation,
          ),
        );
      } catch (error) {
        if (mounted) {
          showSideToast(
            context,
            context.l10n.bookSourceOnlineDataBroken('$error'),
          );
        }
      }
    } else {
      await NativeReaderService.openBook(context, fullBook,
          animation: animation);
    }
    if (mounted) _loadBooks();
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
    widget.controller?._state = this;
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
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    _librarySubscription?.cancel();
    _searchDebounce?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _toggleSearchBar() {
    setState(() {
      _searchBarVisible = !_searchBarVisible;
      if (_searchBarVisible) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchFocus.requestFocus();
        });
      } else {
        _searchController.clear();
        _searchQuery = '';
      }
    });
  }

  Future<void> _showFilterMenu(Rect anchor) async {
    final overlay =
        Navigator.of(context).overlay!.context.findRenderObject()! as RenderBox;
    final selected = await showMenu<_LibraryFilter>(
      context: context,
      position: RelativeRect.fromRect(
        anchor,
        Offset.zero & overlay.size,
      ),
      initialValue: _selectedFilter,
      items: [
        _buildFilterMenuItem(
          _LibraryFilter.all,
          context.l10n.libraryFilterAll(_books.length),
        ),
        _buildFilterMenuItem(
          _LibraryFilter.reading,
          context.l10n.libraryFilterReading(
            _books.where(_isReadingBook).length,
          ),
        ),
        _buildFilterMenuItem(
          _LibraryFilter.finished,
          context.l10n.libraryFilterFinished(
            _books.where(_isFinishedBook).length,
          ),
        ),
      ],
    );
    if (selected == null || !mounted) return;
    setState(() => _selectedFilter = selected);
    _syncFilterActive();
  }

  PopupMenuItem<_LibraryFilter> _buildFilterMenuItem(
    _LibraryFilter filter,
    String label,
  ) {
    final selected = _selectedFilter == filter;
    final scheme = Theme.of(context).colorScheme;
    return PopupMenuItem<_LibraryFilter>(
      value: filter,
      child: Row(
        children: [
          Icon(
            selected ? Icons.radio_button_checked : Icons.radio_button_off,
            size: 18,
            color: selected ? scheme.primary : scheme.onSurfaceVariant,
          ),
          const SizedBox(width: 10),
          Text(label),
        ],
      ),
    );
  }

  void _syncFilterActive() {
    widget.controller?.filterActive.value =
        _selectedFilter != _LibraryFilter.all;
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
    try {
      final books = await _bookDao.getAllBooks();
      if (mounted) {
        setState(() {
          _books = books;
          _isInitialLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isInitialLoading = false);
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
    final mobileChrome = HomeMobileChromeScope.of(context);
    // 手机模式：内容从屏幕顶端开始、滚动时穿过毛玻璃顶栏，
    // 顶栏的模糊层才有真实内容可以取样；用内边距避开首屏遮挡。
    final mobileTopInset = mobileChrome.pageTopPadding;
    final listTopPadding =
        useRailNavigation ? 8.0 : (_searchBarVisible ? 10.0 : mobileTopInset);
    final content = Column(
      children: [
        if (useRailNavigation) ...[
          _buildTopBar(),
          const SizedBox(height: 10),
        ],
        if (_searchBarVisible) ...[
          if (!useRailNavigation) SizedBox(height: mobileTopInset),
          _buildSearchBar(),
        ],
        Expanded(
          child: _isInitialLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: _loadBooks,
                  strokeWidth: 2.5,
                  displacement: 40,
                  // 与首页/发现页对齐：出场裁剪线贴住毛玻璃顶栏下边缘，
                  // 圆圈看起来从顶栏底下滑出；用 pageTopPadding 会让裁剪线
                  // 悬在顶栏下方 8dp，圆圈在半空被“隐形层”切头。
                  edgeOffset: useRailNavigation || _searchBarVisible
                      ? 0
                      : mobileChrome.topBarHeight,
                  color: Theme.of(context).colorScheme.primary,
                  backgroundColor: palette.cardStrong,
                  child: _books.isEmpty
                      ? _buildRefreshableState(_buildEmptyLibrary())
                      : books.isEmpty
                          ? _buildRefreshableState(_buildNoSearchResult())
                          : _buildBooksGrid(books, topPadding: listTopPadding),
                ),
        ),
      ],
    );
    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child:
          useRailNavigation ? SafeArea(bottom: false, child: content) : content,
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
          _buildTopBarIcon(
            icon: Icons.search_rounded,
            active: _searchBarVisible,
            tooltip: context.l10n.bookSourcesSearch,
            onTap: _toggleSearchBar,
          ),
          const SizedBox(width: 8),
          _LibraryFilterButton(
            active: _selectedFilter != _LibraryFilter.all,
            decoration: (active) => _panelDecoration(
              radius: 22,
              stronger: true,
              color: active
                  ? scheme.primaryContainer
                  : (_isMaterial3Style
                      ? scheme.surfaceContainer
                      : palette.card),
            ),
            iconColor: _selectedFilter != _LibraryFilter.all
                ? scheme.onPrimaryContainer
                : palette.iconMuted,
            onTapWithRect: _showFilterMenu,
          ),
          const SizedBox(width: 8),
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

  Widget _buildTopBarIcon({
    required IconData icon,
    required bool active,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    final palette = PageStyleHelper.palette(context);
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: _panelDecoration(
            radius: 22,
            stronger: true,
            color: active
                ? scheme.primaryContainer
                : (_isMaterial3Style ? scheme.surfaceContainer : palette.card),
          ),
          child: Icon(
            icon,
            color: active ? scheme.onPrimaryContainer : palette.iconMuted,
          ),
        ),
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
                focusNode: _searchFocus,
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

  Widget _buildFloatingActionButton() {
    final isTablet = LayoutHelper.isTablet(context);
    final isDesktop = LayoutHelper.isDesktop(context);
    final useRailNav = isTablet || isDesktop;
    final bottomPadding = MediaQuery.viewPaddingOf(context).bottom;
    final mobileChrome = HomeMobileChromeScope.of(context);
    final scheme = Theme.of(context).colorScheme;

    // 侧边导航栏模式：FAB 在右下角，边距较小
    // 底部导航栏模式：FAB 需要避开导航栏
    final double bottomMargin = useRailNav
        ? bottomPadding + 16 // 侧边导航：只需避开安全区域
        : mobileChrome.floatingActionBottomMargin; // 底部导航：避开悬浮导航栏

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

  Widget _buildRefreshableState(Widget state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          children: [
            SizedBox(
              height: constraints.maxHeight,
              child: state,
            ),
          ],
        );
      },
    );
  }

  Widget _buildBooksGrid(List<Book> books, {required double topPadding}) {
    final useRail =
        LayoutHelper.getNavigationType(context) == NavigationType.rail;
    if (!useRail) {
      return _buildBooksList(books, topPadding: topPadding);
    }

    final spacing = LayoutHelper.isDesktop(context) ? 16.0 : 14.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        // 列数由可用宽度和目标封面宽度推导：旋转屏幕时封面大小基本不变，
        // 只是列数重排，不再按断点写死列数。
        const double horizontalPadding = 32.0;
        final crossAxisCount =
            LayoutHelper.bookGridColumnsForWidth(constraints.maxWidth);
        final totalSpacing = spacing * (crossAxisCount - 1);
        final availableWidth = math.max(
          0.0,
          constraints.maxWidth - horizontalPadding - totalSpacing,
        );
        final itemWidth = availableWidth / crossAxisCount;
        // 网格高度为 2:3 封面 + 文本区域预留高度（更接近常见书封比例）
        final itemHeight = (itemWidth * 3 / 2) +
            _BookCoverItem.textHeight +
            _BookCoverItem.gap;
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
            cacheExtent: 720,
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              12,
              16,
              MediaQuery.viewPaddingOf(context).bottom + 24,
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
              final coverKey = _coverKeyFor(book);
              return RepaintBoundary(
                child: _BookCoverItem(
                  book: book,
                  coverKey: coverKey,
                  onTap: () async {
                    // 在点击瞬间捕获封面位置，随后直接打开沉浸式阅读器
                    final animation = BookOpenAnimation.fromCoverKey(
                      coverKey,
                      radius: BorderRadius.circular(12),
                      coverBuilder: (context) => _gridCoverArt(context, book),
                    );
                    await _openBook(book, animation: animation);
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

  Widget _buildBooksList(List<Book> books, {required double topPadding}) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return ListView.builder(
      cacheExtent: 720,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: EdgeInsets.fromLTRB(
        16,
        topPadding,
        16,
        HomeMobileChromeScope.of(context).pageBottomPadding,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        final coverKey = _coverKeyFor(book);
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
                final animation = BookOpenAnimation.fromCoverKey(
                  coverKey,
                  radius: BorderRadius.circular(11),
                  coverBuilder: (context) => _buildListCover(context, book),
                );
                await _openBook(book, animation: animation);
              },
              onLongPress: () => _showBookOptions(book),
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Row(
                  children: [
                    SizedBox(
                      key: coverKey,
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
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  book.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              if (book.isOnline) ...[
                                const SizedBox(width: 8),
                                _onlineBadge(context),
                              ],
                            ],
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
    final sourceCover = _sourceCoverUrl(book);
    if (sourceCover != null) {
      return Image.network(
        sourceCover.toString(),
        fit: BoxFit.cover,
        cacheWidth: (64 * MediaQuery.of(context).devicePixelRatio).round(),
        errorBuilder: (context, error, stackTrace) =>
            _buildListDefaultCover(context, book),
      );
    }
    return _buildListDefaultCover(context, book);
  }

  Widget _buildListDefaultCover(BuildContext context, Book book) {
    return GeneratedBookCover(
      title: book.title,
      author: book.author,
    );
  }

  Widget _onlineBadge(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          context.l10n.bookSourceOnlineBadge,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      );

  Future<void> _downloadOnlineBook(Book book) async {
    final progress = ValueNotifier<(int, int)>((0, 0));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(context.l10n.bookSourceDownloading),
          content: ValueListenableBuilder<(int, int)>(
            valueListenable: progress,
            builder: (context, value, _) => Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: value.$2 <= 0 ? null : value.$1 / value.$2,
                ),
                const SizedBox(height: 12),
                Text(
                  value.$2 <= 0
                      ? context.l10n.bookSourceFetchingCatalog
                      : context.l10n.bookSourceDownloadProgress(
                          value.$1,
                          value.$2,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    try {
      final source = _sourceShelfService.sourceFrom(book);
      final sourceBook = _sourceShelfService.sourceBookFrom(book);
      await _sourceShelfService.downloadToLocal(
        source: source,
        book: sourceBook,
        onProgress: (completed, total) => progress.value = (completed, total),
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showSideToast(context, context.l10n.bookSourceDownloadConverted);
      await _loadBooks();
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      showSideToast(
        context,
        context.l10n.bookSourceDownloadFailed('$error'),
      );
    } finally {
      progress.dispose();
    }
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
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: _buildListCover(context, book),
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
                        subtitle: book.isOnline
                            ? context.l10n.bookSourceOnlineBadge
                            : book.currentPage > 0
                                ? context.l10n
                                    .libraryPageNumber(book.currentPage)
                                : context.l10n.libraryStartFromBeginning,
                        backgroundColor:
                            localScheme.primaryContainer.withValues(
                          alpha: isMaterial3Style ? 0.42 : 0.15,
                        ),
                        onTap: () async {
                          Navigator.pop(context);
                          final fullBook = await _bookDao.getBookById(book.id!);
                          if (fullBook != null && context.mounted) {
                            await _openBook(fullBook);
                            _loadBooks();
                          }
                        },
                      ),
                      const SizedBox(height: 8),
                      if (book.isOnline) ...[
                        _buildOptionItem(
                          context: context,
                          icon: Icons.download_for_offline_outlined,
                          iconColor: localScheme.secondary,
                          title: context.l10n.bookSourceDownloadLocal,
                          subtitle: context.l10n.bookSourceDownloadLocalHint,
                          backgroundColor:
                              localScheme.secondaryContainer.withValues(
                            alpha: isMaterial3Style ? 0.44 : 0.15,
                          ),
                          onTap: () {
                            Navigator.pop(context);
                            unawaited(_downloadOnlineBook(book));
                          },
                        ),
                        const SizedBox(height: 8),
                      ],
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
      if (book.filePath.isNotEmpty) {
        final file = File(book.filePath);
        if (await file.exists()) {
          await file.delete();
          debugPrint('✅ 已删除书籍文件: ${book.filePath}');
        } else {
          debugPrint('⚠️ 书籍文件不存在: ${book.filePath}');
        }

        // 2. 删除封面图片文件
      }
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
  final GlobalKey coverKey;
  final Future<void> Function() onTap;
  final VoidCallback onLongPress;

  const _BookCoverItem({
    required this.book,
    required this.coverKey,
    required this.onTap,
    required this.onLongPress,
  });

  /// 封面下方文本区域高度与间距，网格计算格子高度时复用。
  static const double textHeight = 44.0;
  static const double gap = 6.0;

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
          final coverWidth = constraints.maxWidth;
          final targetCoverHeight = coverWidth * 3 / 2;
          final availableCoverHeight =
              math.max(0.0, constraints.maxHeight - textHeight - gap);
          final coverHeight = math.min(availableCoverHeight, targetCoverHeight);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 书籍封面区域 - 2:3比例，但不超过可用高度
              Align(
                alignment: Alignment.topCenter,
                child: SizedBox(
                  key: coverKey,
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
                          child: _gridCoverArt(context, book),
                        ),
                        if (book.isOnline)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: scheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                context.l10n.bookSourceOnlineBadge,
                                style: TextStyle(
                                  color: scheme.onPrimary,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
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
                            left: book.isOnline ? 6 : null,
                            right: book.isOnline ? null : 6,
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
              const SizedBox(height: gap),
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
                        const SizedBox(height: 2),
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
}

/// 网格封面画面（真实封面或默认设计），不带圆角：
/// 由格子里的 ClipRRect 或打开动画的飞行图层负责裁剪。
Widget _gridCoverArt(BuildContext context, Book book) {
  final theme = Theme.of(context);
  final scheme = theme.colorScheme;
  final isMaterial3Style =
      theme.extension<UiStyleThemeExtension>()?.isMaterial3Style ?? false;
  if (book.coverImagePath != null && book.coverImagePath!.isNotEmpty) {
    final fit = Platform.isAndroid ? BoxFit.contain : BoxFit.cover;
    // 有封面图片时，直接显示真实的书籍封面
    // cacheWidth 限制解码分辨率：网格封面显示宽度不会超过 ~240 逻辑像素，
    // 全分辨率解码原图会占用大量内存并在滑动切页时造成掉帧。
    // 打开动画复用同一 provider，展开时无需重新解码即可立即上屏。
    final cacheWidth = (240 * MediaQuery.of(context).devicePixelRatio).round();
    return SizedBox(
      width: double.infinity,
      height: double.infinity,
      child: ColoredBox(
        color: scheme.surface.withValues(alpha: isMaterial3Style ? 0.2 : 0.12),
        child: Image.file(
          File(book.coverImagePath!),
          fit: fit,
          cacheWidth: cacheWidth,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) {
            return _gridDefaultCover(context, book);
          },
        ),
      ),
    );
  }
  final sourceCover = _sourceCoverUrl(book);
  if (sourceCover != null) {
    return Image.network(
      sourceCover.toString(),
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      cacheWidth: (240 * MediaQuery.of(context).devicePixelRatio).round(),
      errorBuilder: (context, error, stackTrace) =>
          _gridDefaultCover(context, book),
    );
  }
  // 没有封面图片时，显示默认封面设计
  return _gridDefaultCover(context, book);
}

/// 构建默认封面设计
Widget _gridDefaultCover(BuildContext context, Book book) {
  return GeneratedBookCover(
    title: book.title,
    author: book.author,
  );
}

Uri? _sourceCoverUrl(Book book) {
  final raw = book.sourceBookJson;
  if (raw == null || raw.isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is! Map) return null;
    final value = decoded['coverUrl'];
    return value is String && value.isNotEmpty ? Uri.tryParse(value) : null;
  } catch (_) {
    return null;
  }
}

/// 顶栏筛选按钮：点击时把自身在屏幕上的位置传给菜单定位。
class _LibraryFilterButton extends StatelessWidget {
  final bool active;
  final BoxDecoration Function(bool active) decoration;
  final Color iconColor;
  final Future<void> Function(Rect anchor) onTapWithRect;

  const _LibraryFilterButton({
    required this.active,
    required this.decoration,
    required this.iconColor,
    required this.onTapWithRect,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.libraryFilterTooltip,
      child: Builder(
        builder: (buttonContext) => InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () {
            final box = buttonContext.findRenderObject()! as RenderBox;
            final rect = box.localToGlobal(Offset.zero) & box.size;
            unawaited(onTapWithRect(rect));
          },
          child: Container(
            width: 44,
            height: 44,
            decoration: decoration(active),
            child: Icon(
              active ? Icons.filter_alt_rounded : Icons.filter_alt_outlined,
              color: iconColor,
            ),
          ),
        ),
      ),
    );
  }
}
