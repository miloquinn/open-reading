// 文件说明：发现页，聚合展示已启用书源的推荐、分类与最新书籍。
// 技术要点：Flutter UI、按 Tab 缓存的书源请求、下拉刷新。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/pages/home/home_mobile_chrome.dart';
import 'package:xxread/pages/home/home_shell_page.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';

import 'book_source_management_page.dart';
import 'source_search_page.dart';
import 'widgets/sourced_book_widgets.dart';

/// 发现页：只负责展示书籍内容。
///
/// 搜索收纳在顶栏的搜索按钮里（独立页面），书源配置收纳在管理页。
class BookSourcesPage extends StatefulWidget {
  final BookSourceClient? client;

  static const int maxLatestItemsPerSource = 12;

  const BookSourcesPage({super.key, this.client});

  @visibleForTesting
  static List<RegisteredBookSource> searchTargets(
    Iterable<RegisteredBookSource> sources,
    String? selectedSourceId,
  ) => SourceSearchPage.searchTargets(sources, selectedSourceId);

  /// 保留每个书源自己的 latest 顺序，再按来源轮流穿插。
  ///
  /// 首轮优先展示头部更新时间较新的书源；随后每轮每源最多贡献一本，
  /// 避免单一书源依靠时间戳或返回数量占满聚合列表。
  @visibleForTesting
  static List<SourcedBook> interleaveLatestBatches(
    Iterable<List<SourcedBook>> batches, {
    int maxItemsPerSource = maxLatestItemsPerSource,
  }) {
    if (maxItemsPerSource <= 0) return const [];
    final queues = batches
        .where((batch) => batch.isNotEmpty)
        .map((batch) => batch.take(maxItemsPerSource).toList(growable: false))
        .toList();
    queues.sort((left, right) {
      final leftTime = left.first.book.updatedAt;
      final rightTime = right.first.book.updatedAt;
      if (leftTime != null && rightTime != null) {
        final byTime = rightTime.compareTo(leftTime);
        if (byTime != 0) return byTime;
      } else if (leftTime != null) {
        return -1;
      } else if (rightTime != null) {
        return 1;
      }
      return left.first.source.name.compareTo(right.first.source.name);
    });

    final results = <SourcedBook>[];
    for (var index = 0; index < maxItemsPerSource; index++) {
      var added = false;
      for (final queue in queues) {
        if (index >= queue.length) continue;
        results.add(queue[index]);
        added = true;
      }
      if (!added) break;
    }
    return results;
  }

  @override
  State<BookSourcesPage> createState() => _BookSourcesPageState();
}

class _BookSourcesPageState extends State<BookSourcesPage> {
  final BookSourceRegistry _registry = BookSourceRegistry();
  late final BookSourceClient _client;
  late final BookSourceShelfService _shelfService = BookSourceShelfService(
    client: _client,
  );
  late final SourcedBookActions _actions = SourcedBookActions(
    context: context,
    client: _client,
    shelfService: _shelfService,
  );
  StreamSubscription<void>? _registrySubscription;

  List<RegisteredBookSource> _sources = const [];
  bool _loadingSources = true;
  _DiscoverSection _section = _DiscoverSection.recommended;
  String? _selectedSourceId;

  // 每个 Tab 的内容独立缓存，切换回来不再重新请求。
  final Map<_DiscoverSection, _SectionCache> _cache = {};
  _SourcedCategory? _selectedCategory;
  List<SourcedBook> _categoryBooks = const [];
  bool _loadingCategoryBooks = false;

  @override
  void initState() {
    super.initState();
    _client = widget.client ?? BookSourceClient();
    _registrySubscription = _registry.changes.listen((_) => _reloadAll());
    unawaited(_loadSources());
  }

  @override
  void dispose() {
    _registrySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSources() async {
    final sources = await _registry.load();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loadingSources = false;
    });
    await _loadSection(_section);
  }

  Future<void> _reloadAll() async {
    _cache.clear();
    _selectedSourceId = null;
    _selectedCategory = null;
    _categoryBooks = const [];
    _loadingCategoryBooks = false;
    await _loadSources();
  }

  List<RegisteredBookSource> _targets(String capability) => _sources
      .where((source) => source.enabled)
      .where((source) => source.capabilities.contains(capability))
      .toList(growable: false);

  String _capabilityFor(_DiscoverSection section) => switch (section) {
    _DiscoverSection.recommended => 'discover',
    _DiscoverSection.categories => 'categories',
    _DiscoverSection.latest => 'browse',
  };

  List<RegisteredBookSource> _sourcesFor(_DiscoverSection section) =>
      _targets(_capabilityFor(section));

  bool _matchesSelectedSource(RegisteredBookSource source) =>
      _selectedSourceId == null || source.id == _selectedSourceId;

  Future<void> _loadSection(
    _DiscoverSection section, {
    bool force = false,
  }) async {
    if (!force && _cache[section] != null) return;
    setState(() => _cache[section] = const _SectionCache.loading());
    _SectionCache next;
    try {
      next = switch (section) {
        _DiscoverSection.recommended => _SectionCache.shelves(
          await _fetchShelves(),
        ),
        _DiscoverSection.categories => _SectionCache.categories(
          await _fetchCategories(),
        ),
        _DiscoverSection.latest => _SectionCache.books(await _fetchLatest()),
      };
    } catch (error) {
      next = _SectionCache.error(error.toString());
    }
    if (!mounted) return;
    setState(() => _cache[section] = next);
    if (section == _DiscoverSection.categories) {
      _autoSelectFirstCategory();
    }
  }

  Future<List<_DiscoveryShelf>> _fetchShelves() async {
    final batches = await Future.wait(
      _targets('discover').map((source) async {
        try {
          final page = await _client.getDiscovery(source);
          return page.sections
              .where((section) => section.items.isNotEmpty)
              .map(
                (section) => _DiscoveryShelf(
                  source: source,
                  title: section.title,
                  items: section.items,
                ),
              )
              .toList(growable: false);
        } catch (_) {
          return const <_DiscoveryShelf>[];
        }
      }),
    );
    return batches.expand((items) => items).toList(growable: false);
  }

  Future<List<_SourcedCategory>> _fetchCategories() async {
    final batches = await Future.wait(
      _targets('categories').map((source) async {
        try {
          final categories = await _client.getCategories(source);
          return categories
              .map(
                (category) => _SourcedCategory(
                  source: source,
                  id: category.id,
                  name: category.name,
                ),
              )
              .toList(growable: false);
        } catch (_) {
          return const <_SourcedCategory>[];
        }
      }),
    );
    return batches.expand((items) => items).toList(growable: false);
  }

  Future<List<SourcedBook>> _fetchLatest() async {
    final batches = await Future.wait(
      _targets('browse').map((source) async {
        try {
          final page = await _client.browse(source, sort: 'latest');
          return page.items
              .map((book) => SourcedBook(source: source, book: book))
              .toList(growable: false);
        } catch (_) {
          return const <SourcedBook>[];
        }
      }),
    );
    return BookSourcesPage.interleaveLatestBatches(batches);
  }

  void _autoSelectFirstCategory() {
    final cache = _cache[_DiscoverSection.categories];
    final categories = (cache?.categories ?? const <_SourcedCategory>[])
        .where((category) => _matchesSelectedSource(category.source))
        .toList(growable: false);
    if (_selectedCategory != null || categories.isEmpty) return;
    unawaited(_selectCategory(categories.first));
  }

  void _changeSourceScope(String? sourceId) {
    if (_selectedSourceId == sourceId) return;
    setState(() {
      _selectedSourceId = sourceId;
      _selectedCategory = null;
      _categoryBooks = const [];
      _loadingCategoryBooks = false;
    });
    if (_section == _DiscoverSection.categories) {
      _autoSelectFirstCategory();
    }
  }

  Future<void> _changeSection(_DiscoverSection section) async {
    final selectedSourceStillAvailable =
        _selectedSourceId == null ||
        _sourcesFor(section).any((source) => source.id == _selectedSourceId);
    setState(() {
      _section = section;
      if (!selectedSourceStillAvailable) {
        _selectedSourceId = null;
        _selectedCategory = null;
        _categoryBooks = const [];
        _loadingCategoryBooks = false;
      }
    });
    await _loadSection(section);
    if (mounted && section == _DiscoverSection.categories) {
      _autoSelectFirstCategory();
    }
  }

  Future<void> _selectCategory(_SourcedCategory category) async {
    setState(() {
      _selectedCategory = category;
      _categoryBooks = const [];
      _loadingCategoryBooks = category.source.capabilities.contains('browse');
    });
    if (!category.source.capabilities.contains('browse')) return;
    try {
      final page = await _client.browse(
        category.source,
        category: category.id,
        sort: 'popular',
      );
      if (!mounted || _selectedCategory != category) return;
      setState(() {
        _categoryBooks = page.items
            .map((book) => SourcedBook(source: category.source, book: book))
            .toList(growable: false);
        _loadingCategoryBooks = false;
      });
    } catch (_) {
      if (!mounted || _selectedCategory != category) return;
      setState(() => _loadingCategoryBooks = false);
    }
  }

  Future<void> _openCategoryPicker(List<_SourcedCategory> categories) async {
    final size = MediaQuery.sizeOf(context);
    final picker = _CategoryPickerPanel(
      categories: categories,
      selectedCategory: _selectedCategory,
      title: context.l10n.discoverCategories,
      searchLabel: context.l10n.search,
      noResultsLabel: context.l10n.bookSourcesNoResults,
    );
    final _SourcedCategory? selected;
    if (size.width >= 720) {
      selected = await showDialog<_SourcedCategory>(
        context: context,
        builder: (context) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: (size.width - 48).clamp(320, 520).toDouble(),
            height: (size.height - 48).clamp(320, 680).toDouble(),
            child: picker,
          ),
        ),
      );
    } else {
      selected = await showModalBottomSheet<_SourcedCategory>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        clipBehavior: Clip.antiAlias,
        builder: (context) => SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.82,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: picker,
          ),
        ),
      );
    }
    if (selected != null && mounted && selected != _selectedCategory) {
      await _selectCategory(selected);
    }
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SourceSearchPage(
          sources: _sources,
          client: _client,
          shelfService: _shelfService,
        ),
      ),
    );
  }

  Future<void> _openSourceManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BookSourceManagementPage()),
    );
    if (mounted) await _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    final useRailNavigation =
        NavigationContext.of(context)?.useRailNavigation ?? false;
    final mobileChrome = HomeMobileChromeScope.of(context);
    final bottomPadding = useRailNavigation
        ? 32.0
        : mobileChrome.pageBottomPadding;

    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: SafeArea(
        top: useRailNavigation,
        bottom: false,
        child: RefreshIndicator(
          edgeOffset: useRailNavigation ? 90 : mobileChrome.topBarHeight,
          onRefresh: () => _loadSection(_section, force: true),
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        useRailNavigation ? 16 : mobileChrome.pageTopPadding,
                        16,
                        0,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (useRailNavigation) _buildRailHeader(),
                          _buildSectionTabs(),
                          if (_sourcesFor(_section).length > 1) ...[
                            const SizedBox(height: 8),
                            _buildSourceScope(_sourcesFor(_section)),
                          ],
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ..._buildSectionSlivers(bottomPadding),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRailHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        children: [
          Expanded(
            child: Text(
              context.l10n.discover,
              style: TextStyle(
                fontSize: 36,
                height: 1.05,
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          IconButton.filledTonal(
            key: const Key('bookSourceSearchEntry'),
            tooltip: context.l10n.bookSourcesSearch,
            onPressed: _openSearch,
            icon: const Icon(Icons.search_rounded),
          ),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            tooltip: context.l10n.bookSourceManagementTitle,
            onPressed: _openSourceManagement,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTabs() {
    final scheme = Theme.of(context).colorScheme;
    return SegmentedButton<_DiscoverSection>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: _DiscoverSection.recommended,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(context.l10n.discoverRecommended),
        ),
        ButtonSegment(
          value: _DiscoverSection.categories,
          icon: const Icon(Icons.category_outlined),
          label: Text(context.l10n.discoverCategories),
        ),
        ButtonSegment(
          value: _DiscoverSection.latest,
          icon: const Icon(Icons.update_rounded),
          label: Text(context.l10n.discoverLatest),
        ),
      ],
      selected: {_section},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        unawaited(_changeSection(selection.first));
      },
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
        side: WidgetStatePropertyAll(BorderSide(color: scheme.outlineVariant)),
      ),
    );
  }

  Widget _buildSourceScope(List<RegisteredBookSource> sources) {
    return SizedBox(
      key: const Key('bookSourceDiscoverScopeControl'),
      height: 42,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            key: const Key('bookSourceDiscoverScopeAll'),
            selected: _selectedSourceId == null,
            label: Text(context.l10n.statsRangeAll),
            onSelected: (_) => _changeSourceScope(null),
          ),
          const SizedBox(width: 8),
          for (final source in sources) ...[
            ChoiceChip(
              key: Key('bookSourceDiscoverScope-${source.id}'),
              selected: _selectedSourceId == source.id,
              label: Text(source.name),
              onSelected: (_) => _changeSourceScope(source.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildSectionSlivers(double bottomPadding) {
    if (_loadingSources) {
      return [
        _paddedSectionSliver(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 44),
            child: Center(child: CircularProgressIndicator()),
          ),
          bottomPadding: bottomPadding,
        ),
      ];
    }
    final cache = _cache[_section];
    if (cache == null || cache.loading) {
      return [
        _paddedSectionSliver(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 44),
            child: Center(child: CircularProgressIndicator()),
          ),
          bottomPadding: bottomPadding,
        ),
      ];
    }
    if (cache.error != null) {
      return [
        _paddedSectionSliver(
          _buildMessageCard(
            icon: Icons.cloud_off_outlined,
            title: context.l10n.discoverLoadFailed,
            message: cache.error!,
            actionLabel: context.l10n.discoverRetry,
            onAction: () => _loadSection(_section, force: true),
          ),
          bottomPadding: bottomPadding,
        ),
      ];
    }
    return switch (_section) {
      _DiscoverSection.recommended => _buildShelvesSlivers(
        cache,
        bottomPadding,
      ),
      _DiscoverSection.categories => _buildCategoriesSlivers(
        cache,
        bottomPadding,
      ),
      _DiscoverSection.latest => _buildLatestSlivers(cache, bottomPadding),
    };
  }

  List<Widget> _buildShelvesSlivers(_SectionCache cache, double bottomPadding) {
    final shelves = (cache.shelves ?? const <_DiscoveryShelf>[])
        .where((shelf) => _matchesSelectedSource(shelf.source))
        .toList(growable: false);
    if (shelves.isEmpty) {
      return [
        _paddedSectionSliver(
          _buildUnsupportedMessage('discover'),
          bottomPadding: bottomPadding,
        ),
      ];
    }
    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
        sliver: SliverList.builder(
          itemCount: shelves.length,
          itemBuilder: (context, index) =>
              _centerSectionChild(_buildShelf(shelves[index])),
        ),
      ),
    ];
  }

  Widget _buildShelf(_DiscoveryShelf shelf) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  shelf.title,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
              ),
              _buildSourceBadge(shelf.source.name),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 242,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: shelf.items.length,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (context, index) {
                final result = SourcedBook(
                  source: shelf.source,
                  book: shelf.items[index],
                );
                return SourcedBookCard(
                  result: result,
                  onTap: () => _actions.showBookDetails(result),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoriesSlivers(
    _SectionCache cache,
    double bottomPadding,
  ) {
    final categories = (cache.categories ?? const <_SourcedCategory>[])
        .where((category) => _matchesSelectedSource(category.source))
        .toList(growable: false);
    if (categories.isEmpty) {
      return [
        _paddedSectionSliver(
          _buildUnsupportedMessage('categories'),
          bottomPadding: bottomPadding,
        ),
      ];
    }
    final selectedCategory = _selectedCategory ?? categories.first;
    final slivers = <Widget>[
      _paddedSectionSliver(
        _CategoryPickerButton(
          category: selectedCategory,
          onTap: () => _openCategoryPicker(categories),
        ),
        bottomPadding: 18,
      ),
    ];
    if (_loadingCategoryBooks) {
      slivers.add(
        _paddedSectionSliver(
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          ),
          topPadding: 0,
          bottomPadding: bottomPadding,
        ),
      );
    } else if (_categoryBooks.isEmpty) {
      slivers.add(
        _paddedSectionSliver(
          _buildMessageCard(
            icon: Icons.menu_book_outlined,
            title: context.l10n.bookSourcesNoResults,
            message: context.l10n.discoverCategoryEmpty,
          ),
          topPadding: 0,
          bottomPadding: bottomPadding,
        ),
      );
    } else {
      slivers.add(
        _bookListSliver(_categoryBooks, bottomPadding: bottomPadding),
      );
    }
    return slivers;
  }

  List<Widget> _buildLatestSlivers(_SectionCache cache, double bottomPadding) {
    final books = (cache.books ?? const <SourcedBook>[])
        .where((result) => _matchesSelectedSource(result.source))
        .toList(growable: false);
    if (books.isEmpty) {
      return [
        _paddedSectionSliver(
          _buildUnsupportedMessage('browse'),
          bottomPadding: bottomPadding,
        ),
      ];
    }
    return [_bookListSliver(books, bottomPadding: bottomPadding)];
  }

  Widget _bookListSliver(
    List<SourcedBook> books, {
    required double bottomPadding,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
      sliver: SliverList.separated(
        itemCount: books.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final result = books[index];
          return _centerSectionChild(
            SourcedBookListTile(
              result: result,
              onTap: () => _actions.showBookDetails(result),
            ),
          );
        },
      ),
    );
  }

  Widget _paddedSectionSliver(
    Widget child, {
    double topPadding = 8,
    required double bottomPadding,
  }) {
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(16, topPadding, 16, bottomPadding),
      sliver: SliverToBoxAdapter(child: _centerSectionChild(child)),
    );
  }

  Widget _centerSectionChild(Widget child) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1048),
      child: child,
    ),
  );

  Widget _buildUnsupportedMessage(String capability) {
    final hasEnabledSources = _sources.any((source) => source.enabled);
    return _buildMessageCard(
      icon: hasEnabledSources
          ? Icons.extension_off_outlined
          : Icons.travel_explore_outlined,
      title: hasEnabledSources
          ? context.l10n.discoverUnsupportedTitle
          : context.l10n.bookSourcesNoSourcesTitle,
      message: hasEnabledSources
          ? context.l10n.discoverUnsupportedMessage(capability)
          : context.l10n.bookSourcesNoSourcesDescription,
      actionLabel: context.l10n.bookSourceManagementTitle,
      onAction: _openSourceManagement,
    );
  }

  Widget _buildMessageCard({
    required IconData icon,
    required String title,
    required String message,
    String? actionLabel,
    FutureOr<void> Function()? onAction,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: bookSourcePanelDecoration(context, radius: 22),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(icon, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: scheme.onSurfaceVariant, height: 1.45),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => onAction(),
              icon: const Icon(Icons.tune_rounded),
              label: Text(actionLabel),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceBadge(String label) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

enum _DiscoverSection { recommended, categories, latest }

/// 一个 Tab 的缓存态：loading / error / 三种内容之一。
class _SectionCache {
  final bool loading;
  final String? error;
  final List<_DiscoveryShelf>? shelves;
  final List<_SourcedCategory>? categories;
  final List<SourcedBook>? books;

  const _SectionCache.loading()
    : loading = true,
      error = null,
      shelves = null,
      categories = null,
      books = null;

  const _SectionCache.error(String this.error)
    : loading = false,
      shelves = null,
      categories = null,
      books = null;

  const _SectionCache.shelves(List<_DiscoveryShelf> this.shelves)
    : loading = false,
      error = null,
      categories = null,
      books = null;

  const _SectionCache.categories(List<_SourcedCategory> this.categories)
    : loading = false,
      error = null,
      shelves = null,
      books = null;

  const _SectionCache.books(List<SourcedBook> this.books)
    : loading = false,
      error = null,
      shelves = null,
      categories = null;
}

class _DiscoveryShelf {
  final RegisteredBookSource source;
  final String title;
  final List<BookSourceBook> items;

  const _DiscoveryShelf({
    required this.source,
    required this.title,
    required this.items,
  });
}

class _SourcedCategory {
  final RegisteredBookSource source;
  final String id;
  final String name;

  const _SourcedCategory({
    required this.source,
    required this.id,
    required this.name,
  });
}

class _CategoryPickerButton extends StatelessWidget {
  final _SourcedCategory category;
  final VoidCallback onTap;

  const _CategoryPickerButton({required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: const Key('bookSourceCategoryPickerButton'),
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Icon(Icons.category_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.source.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.unfold_more_rounded, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryPickerPanel extends StatefulWidget {
  final List<_SourcedCategory> categories;
  final _SourcedCategory? selectedCategory;
  final String title;
  final String searchLabel;
  final String noResultsLabel;

  const _CategoryPickerPanel({
    required this.categories,
    required this.selectedCategory,
    required this.title,
    required this.searchLabel,
    required this.noResultsLabel,
  });

  @override
  State<_CategoryPickerPanel> createState() => _CategoryPickerPanelState();
}

class _CategoryPickerPanelState extends State<_CategoryPickerPanel> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_CategoryPickerEntry> _entries() {
    final query = _query.trim().toLowerCase();
    final matches = widget.categories.where((category) {
      if (query.isEmpty) return true;
      return category.name.toLowerCase().contains(query) ||
          category.source.name.toLowerCase().contains(query);
    });
    final entries = <_CategoryPickerEntry>[];
    String? sourceId;
    for (final category in matches) {
      if (category.source.id != sourceId) {
        sourceId = category.source.id;
        entries.add(_CategoryPickerEntry.header(category.source.name));
      }
      entries.add(_CategoryPickerEntry.category(category));
    }
    return entries;
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries();
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 8, 10),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              key: const Key('bookSourceCategorySearchField'),
              controller: _searchController,
              autofocus: false,
              textInputAction: TextInputAction.search,
              onChanged: (value) => setState(() => _query = value),
              decoration: InputDecoration(
                hintText: widget.searchLabel,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                        icon: const Icon(Icons.clear_rounded),
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      widget.noResultsLabel,
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    key: const Key('bookSourceCategoryLazyList'),
                    itemCount: entries.length,
                    itemBuilder: (context, index) {
                      final entry = entries[index];
                      final category = entry.category;
                      if (category == null) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                          child: Text(
                            entry.header!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        );
                      }
                      final selected = category == widget.selectedCategory;
                      return ListTile(
                        key: Key(
                          'bookSourceCategory-${category.source.id}-${category.id}',
                        ),
                        selected: selected,
                        title: Text(
                          category.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: selected
                            ? Icon(Icons.check_rounded, color: scheme.primary)
                            : null,
                        onTap: () => Navigator.of(context).pop(category),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryPickerEntry {
  final String? header;
  final _SourcedCategory? category;

  const _CategoryPickerEntry.header(this.header) : category = null;

  const _CategoryPickerEntry.category(this.category) : header = null;
}
