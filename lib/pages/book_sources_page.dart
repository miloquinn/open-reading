// 文件说明：发现页，聚合展示已启用书源的推荐、分类与最新书籍。
// 技术要点：Flutter UI、按 Tab 缓存的书源请求、下拉刷新。

import 'dart:async';

import 'package:flutter/material.dart';

import '../book_sources/models/registered_book_source.dart';
import '../book_sources/protocol/book_source_protocol.dart';
import '../book_sources/services/book_source_client.dart';
import '../book_sources/services/book_source_registry.dart';
import '../book_sources/services/book_source_shelf_service.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import 'book_source_management_page.dart';
import 'book_source_search_page.dart';
import 'book_source_widgets.dart';
import 'home_layout_constants.dart';
import 'home_shell_page.dart';

/// 发现页：只负责展示书籍内容。
///
/// 搜索收纳在顶栏的搜索按钮里（独立页面），书源配置收纳在管理页。
class BookSourcesPage extends StatefulWidget {
  final BookSourceClient? client;

  const BookSourcesPage({super.key, this.client});

  @visibleForTesting
  static List<RegisteredBookSource> searchTargets(
    Iterable<RegisteredBookSource> sources,
    String? selectedSourceId,
  ) =>
      SourceSearchPage.searchTargets(sources, selectedSourceId);

  @override
  State<BookSourcesPage> createState() => _BookSourcesPageState();
}

class _BookSourcesPageState extends State<BookSourcesPage> {
  final BookSourceRegistry _registry = BookSourceRegistry();
  late final BookSourceClient _client;
  late final BookSourceShelfService _shelfService =
      BookSourceShelfService(client: _client);
  late final SourcedBookActions _actions = SourcedBookActions(
    context: context,
    client: _client,
    shelfService: _shelfService,
  );
  StreamSubscription<void>? _registrySubscription;

  List<RegisteredBookSource> _sources = const [];
  bool _loadingSources = true;
  _DiscoverSection _section = _DiscoverSection.recommended;

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
    _selectedCategory = null;
    _categoryBooks = const [];
    await _loadSources();
  }

  List<RegisteredBookSource> _targets(String capability) => _sources
      .where((source) => source.enabled)
      .where((source) => source.capabilities.contains(capability))
      .toList(growable: false);

  Future<void> _loadSection(
    _DiscoverSection section, {
    bool force = false,
  }) async {
    if (!force && _cache[section] != null) return;
    setState(() => _cache[section] = const _SectionCache.loading());
    _SectionCache next;
    try {
      next = switch (section) {
        _DiscoverSection.recommended =>
          _SectionCache.shelves(await _fetchShelves()),
        _DiscoverSection.categories =>
          _SectionCache.categories(await _fetchCategories()),
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
    final results = batches.expand((items) => items).toList();
    results.sort((a, b) {
      final left = a.book.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.book.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    return results;
  }

  void _autoSelectFirstCategory() {
    final cache = _cache[_DiscoverSection.categories];
    final categories = cache?.categories ?? const <_SourcedCategory>[];
    if (_selectedCategory != null || categories.isEmpty) return;
    unawaited(_selectCategory(categories.first));
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
      MaterialPageRoute<void>(
        builder: (_) => const BookSourceManagementPage(),
      ),
    );
    if (mounted) await _reloadAll();
  }

  @override
  Widget build(BuildContext context) {
    final useRailNavigation =
        NavigationContext.of(context)?.useRailNavigation ?? false;
    final mobileChrome = HomeMobileChromeScope.of(context);
    final bottomPadding =
        useRailNavigation ? 32.0 : mobileChrome.pageBottomPadding;

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
                          const SizedBox(height: 4),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 8, 16, bottomPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1048),
                      child: _buildSectionBody(),
                    ),
                  ),
                ),
              ),
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
        setState(() => _section = selection.first);
        unawaited(_loadSection(selection.first));
      },
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildSectionBody() {
    if (_loadingSources) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 44),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final cache = _cache[_section];
    if (cache == null || cache.loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 44),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (cache.error != null) {
      return _buildMessageCard(
        icon: Icons.cloud_off_outlined,
        title: context.l10n.discoverLoadFailed,
        message: cache.error!,
        actionLabel: context.l10n.discoverRetry,
        onAction: () => _loadSection(_section, force: true),
      );
    }
    return switch (_section) {
      _DiscoverSection.recommended => _buildShelvesBody(cache),
      _DiscoverSection.categories => _buildCategoriesBody(cache),
      _DiscoverSection.latest => _buildLatestBody(cache),
    };
  }

  Widget _buildShelvesBody(_SectionCache cache) {
    final shelves = cache.shelves ?? const <_DiscoveryShelf>[];
    if (shelves.isEmpty) {
      return _buildUnsupportedMessage('discover');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: shelves.map(_buildShelf).toList(growable: false),
    );
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
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _buildSourceBadge(shelf.source.name),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 238,
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

  Widget _buildCategoriesBody(_SectionCache cache) {
    final categories = cache.categories ?? const <_SourcedCategory>[];
    if (categories.isEmpty) {
      return _buildUnsupportedMessage('categories');
    }
    final multipleSources =
        categories.map((category) => category.source.id).toSet().length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: categories.map((category) {
            final selected = _selectedCategory == category;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => unawaited(_selectCategory(category)),
              avatar:
                  selected ? const Icon(Icons.check_rounded, size: 16) : null,
              label: Text(
                multipleSources
                    ? '${category.name} · ${category.source.name}'
                    : category.name,
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 18),
        if (_loadingCategoryBooks)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_categoryBooks.isEmpty)
          _buildMessageCard(
            icon: Icons.menu_book_outlined,
            title: context.l10n.bookSourcesNoResults,
            message: context.l10n.discoverCategoryEmpty,
          )
        else
          ..._categoryBooks.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SourcedBookListTile(
                result: result,
                onTap: () => _actions.showBookDetails(result),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLatestBody(_SectionCache cache) {
    final books = cache.books ?? const <SourcedBook>[];
    if (books.isEmpty) {
      return _buildUnsupportedMessage('browse');
    }
    return Column(
      children: books
          .map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: SourcedBookListTile(
                result: result,
                onTap: () => _actions.showBookDetails(result),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

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
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
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
