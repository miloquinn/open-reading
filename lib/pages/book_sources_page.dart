import 'dart:async';

import 'package:flutter/material.dart';

import '../book_sources/models/registered_book_source.dart';
import '../book_sources/protocol/book_source_protocol.dart';
import '../book_sources/services/book_source_client.dart';
import '../book_sources/services/book_source_registry.dart';
import '../book_sources/services/book_source_shelf_service.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import '../utils/ui_style.dart';
import 'book_source_management_page.dart';
import 'book_source_reader_page.dart';
import 'home_layout_constants.dart';
import 'home_shell_page.dart';

class BookSourcesPage extends StatefulWidget {
  const BookSourcesPage({super.key});

  @visibleForTesting
  static List<RegisteredBookSource> searchTargets(
    Iterable<RegisteredBookSource> sources,
    String? selectedSourceId,
  ) {
    final enabled = sources.where((source) => source.enabled);
    if (selectedSourceId == null) return enabled.toList(growable: false);
    return enabled
        .where((source) => source.id == selectedSourceId)
        .toList(growable: false);
  }

  @override
  State<BookSourcesPage> createState() => _BookSourcesPageState();
}

class _BookSourcesPageState extends State<BookSourcesPage> {
  final BookSourceRegistry _registry = BookSourceRegistry();
  final BookSourceClient _client = BookSourceClient();
  late final BookSourceShelfService _shelfService =
      BookSourceShelfService(client: _client);
  final TextEditingController _searchController = TextEditingController();
  StreamSubscription<void>? _registrySubscription;

  List<RegisteredBookSource> _sources = const [];
  List<_SourcedBook> _results = const [];
  List<_DiscoveryShelf> _discoveryShelves = const [];
  List<_SourcedCategory> _categories = const [];
  List<_SourcedBook> _browseResults = const [];
  String? _selectedSourceId;
  _DiscoverSection _discoverSection = _DiscoverSection.recommended;
  _SourcedCategory? _selectedCategory;
  bool _loadingSources = true;
  bool _searching = false;
  bool _hasSearched = false;
  bool _loadingDiscovery = false;
  String? _discoveryError;
  int _failedSourceCount = 0;

  bool get _isMaterial3Style =>
      Theme.of(context).extension<UiStyleThemeExtension>()?.isMaterial3Style ??
      false;

  @override
  void initState() {
    super.initState();
    _registrySubscription = _registry.changes.listen((_) => _loadSources());
    unawaited(_loadSources());
  }

  @override
  void dispose() {
    _registrySubscription?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSources() async {
    final sources = await _registry.load();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loadingSources = false;
    });
    await _loadDiscoverySection();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    final targetSources = BookSourcesPage.searchTargets(
      _sources,
      _selectedSourceId,
    );
    if (query.isEmpty || targetSources.isEmpty || _searching) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _hasSearched = true;
      _failedSourceCount = 0;
    });

    final batches = await Future.wait(
      targetSources.map((source) async {
        try {
          final page = await _client.search(source, query);
          return _SearchBatch(
            items: page.items
                .map((book) => _SourcedBook(source: source, book: book))
                .toList(growable: false),
          );
        } catch (_) {
          return const _SearchBatch(items: [], failed: true);
        }
      }),
    );

    if (!mounted) return;
    setState(() {
      _results = batches.expand((batch) => batch.items).toList(growable: false);
      _failedSourceCount = batches.where((batch) => batch.failed).length;
      _searching = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final useRailNavigation =
        NavigationContext.of(context)?.useRailNavigation ?? false;
    final bottomPadding = useRailNavigation ? 32.0 : 118.0;
    final palette = PageStyleHelper.palette(context);

    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1080),
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      useRailNavigation ? 16 : kHomeMobileTopBarHeight + 8,
                      16,
                      0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (useRailNavigation) _buildRailHeader(),
                        _buildHeroCard(),
                        const SizedBox(height: 14),
                        _buildSearchPanel(),
                        const SizedBox(height: 18),
                        _buildDiscoveryTabs(),
                        if (_hasSearched) ...[
                          const SizedBox(height: 22),
                          _buildResultHeader(),
                          if (_failedSourceCount > 0) ...[
                            const SizedBox(height: 8),
                            Text(
                              context.l10n
                                  .bookSourcesFailedCount(_failedSourceCount),
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ],
                        const SizedBox(height: 10),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_searching)
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            else if (!_hasSearched)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1048),
                      child: _buildDiscoveryBody(),
                    ),
                  ),
                ),
              )
            else if (_results.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, bottomPadding),
                  child: _buildResultEmptyState(),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, bottomPadding),
                sliver: SliverList.separated(
                  itemCount: _results.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 1048),
                        child: _buildBookResult(_results[index]),
                      ),
                    );
                  },
                ),
              ),
            SliverToBoxAdapter(
              child: ColoredBox(
                color: palette.backgroundEnd.withValues(alpha: 0.01),
                child: const SizedBox(height: 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRailHeader() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Text(
        context.l10n.discover,
        style: TextStyle(
          fontSize: 36,
          height: 1.05,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildHeroCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(stronger: true, radius: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 560;
          final copy = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: scheme.primaryContainer,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      Icons.hub_outlined,
                      color: scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      context.l10n.discover,
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                context.l10n.discoverSubtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          );
          final button = FilledButton.tonalIcon(
            onPressed: _openSourceManagement,
            icon: const Icon(Icons.tune_rounded),
            label: Text(context.l10n.bookSourceManagementTitle),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [copy, const SizedBox(height: 16), button],
            );
          }
          return Row(
            children: [
              Expanded(child: copy),
              const SizedBox(width: 24),
              button
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchPanel() {
    final enabledSources =
        _sources.where((source) => source.enabled).toList(growable: false);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(radius: 22, stronger: true),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.manage_search_rounded,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.bookSourcesSearch,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      context.l10n.bookSourcesSearchHint,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (_searching)
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.4),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 620;
              final scopeControl = _buildSearchScopeControl(enabledSources);
              final queryControl = _buildSearchQueryControl(enabledSources);
              if (compact) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    scopeControl,
                    const SizedBox(height: 12),
                    queryControl,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(width: 280, child: scopeControl),
                  const SizedBox(width: 12),
                  Expanded(child: queryControl),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchScopeControl(
    List<RegisteredBookSource> enabledSources,
  ) {
    return SizedBox(
      key: const Key('bookSourceScopeControl'),
      height: 56,
      child: DropdownButtonFormField<String>(
        key: ValueKey(_selectedSourceId ?? _allSourcesMenuValue),
        initialValue: _selectedSourceId ?? _allSourcesMenuValue,
        isExpanded: true,
        borderRadius: BorderRadius.circular(16),
        decoration: _searchControlDecoration(
          labelText: context.l10n.bookSources,
          prefixIcon: Icons.hub_outlined,
        ),
        onChanged: enabledSources.isEmpty || _searching
            ? null
            : (value) {
                setState(() {
                  _selectedSourceId =
                      value == _allSourcesMenuValue ? null : value;
                  _results = const [];
                  _hasSearched = false;
                  _failedSourceCount = 0;
                });
                unawaited(_loadDiscoverySection());
              },
        items: [
          DropdownMenuItem(
            value: _allSourcesMenuValue,
            child: Text(context.l10n.statsRangeAll),
          ),
          ...enabledSources.map(
            (source) => DropdownMenuItem(
              value: source.id,
              child: Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchQueryControl(
    List<RegisteredBookSource> enabledSources,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final canSearch = enabledSources.isNotEmpty && !_searching;
    return SizedBox(
      key: const Key('bookSourceQueryControl'),
      height: 56,
      child: TextField(
        controller: _searchController,
        enabled: canSearch,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: _searchControlDecoration(
          hintText: context.l10n.bookSourcesSearchHint,
          prefixIcon: Icons.search_rounded,
        ).copyWith(
          suffixIconConstraints: const BoxConstraints(
            minWidth: 52,
            minHeight: 52,
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.all(4),
            child: IconButton.filled(
              tooltip: context.l10n.bookSourcesSearch,
              onPressed: canSearch ? _search : null,
              icon: const Icon(Icons.arrow_forward_rounded),
              style: IconButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                disabledBackgroundColor:
                    scheme.onSurface.withValues(alpha: 0.08),
                disabledForegroundColor:
                    scheme.onSurface.withValues(alpha: 0.32),
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _searchControlDecoration({
    String? labelText,
    String? hintText,
    required IconData prefixIcon,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.72),
      ),
    );
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: Icon(prefixIcon, size: 21),
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      border: border,
      enabledBorder: border,
      disabledBorder: border.copyWith(
        borderSide: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      focusedBorder: border.copyWith(
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    );
  }

  Widget _buildDiscoveryTabs() {
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
      selected: {_discoverSection},
      onSelectionChanged: (selection) {
        if (selection.isEmpty) return;
        setState(() {
          _discoverSection = selection.first;
          _hasSearched = false;
        });
        unawaited(_loadDiscoverySection());
      },
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(44, 48)),
        side: WidgetStatePropertyAll(
          BorderSide(color: scheme.outlineVariant),
        ),
      ),
    );
  }

  Widget _buildDiscoveryBody() {
    if (_loadingSources || _loadingDiscovery) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 44),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_discoveryError != null) {
      return _buildDiscoveryMessage(
        icon: Icons.cloud_off_outlined,
        title: context.l10n.discoverLoadFailed,
        message: _discoveryError!,
        actionLabel: context.l10n.discoverRetry,
        onAction: _loadDiscoverySection,
      );
    }

    return switch (_discoverSection) {
      _DiscoverSection.recommended => _buildRecommendationContent(),
      _DiscoverSection.categories => _buildCategoryContent(),
      _DiscoverSection.latest => _buildLatestContent(),
    };
  }

  Widget _buildRecommendationContent() {
    if (_discoveryShelves.isEmpty) {
      return _buildUnsupportedDiscoveryMessage('discover');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _discoveryShelves.map(_buildDiscoveryShelf).toList(),
    );
  }

  Widget _buildDiscoveryShelf(_DiscoveryShelf shelf) {
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
                final result = _SourcedBook(
                  source: shelf.source,
                  book: shelf.items[index],
                );
                return _buildDiscoveryBookCard(result);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryContent() {
    if (_categories.isEmpty) {
      return _buildUnsupportedDiscoveryMessage('categories');
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _categories.map((category) {
            final selected = _selectedCategory == category;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) => _selectCategory(category),
              avatar:
                  selected ? const Icon(Icons.check_rounded, size: 16) : null,
              label: Text(
                _hasMultipleCategorySources
                    ? '${category.name} · ${category.source.name}'
                    : category.name,
              ),
            );
          }).toList(growable: false),
        ),
        const SizedBox(height: 18),
        if (_selectedCategory == null)
          _buildDiscoveryMessage(
            icon: Icons.touch_app_outlined,
            title: context.l10n.discoverChooseCategory,
            message: context.l10n.discoverChooseCategoryHint,
          )
        else if (_browseResults.isEmpty)
          _buildDiscoveryMessage(
            icon: Icons.menu_book_outlined,
            title: context.l10n.bookSourcesNoResults,
            message: context.l10n.discoverCategoryEmpty,
          )
        else
          ..._browseResults.map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildBookResult(result),
            ),
          ),
      ],
    );
  }

  Widget _buildLatestContent() {
    if (_browseResults.isEmpty) {
      return _buildUnsupportedDiscoveryMessage('browse');
    }
    return Column(
      children: _browseResults
          .map(
            (result) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildBookResult(result),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildUnsupportedDiscoveryMessage(String capability) {
    final hasEnabledSources = _sources.any((source) => source.enabled);
    return _buildDiscoveryMessage(
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

  Widget _buildDiscoveryMessage({
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
      decoration: _panelDecoration(radius: 22),
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

  Widget _buildDiscoveryBookCard(_SourcedBook result) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 132,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => _showBookDetails(result),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 2 / 3,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: result.book.coverUrl == null
                        ? Container(
                            color: scheme.secondaryContainer,
                            child: Icon(
                              Icons.menu_book_rounded,
                              color: scheme.onSecondaryContainer,
                            ),
                          )
                        : Image.network(
                            result.book.coverUrl.toString(),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: scheme.secondaryContainer,
                              child: Icon(
                                Icons.broken_image_outlined,
                                color: scheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  result.book.author.isEmpty
                      ? result.source.name
                      : result.book.author,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
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

  bool get _hasMultipleCategorySources =>
      _categories.map((category) => category.source.id).toSet().length > 1;

  List<RegisteredBookSource> _discoveryTargets(String capability) {
    return BookSourcesPage.searchTargets(_sources, _selectedSourceId)
        .where((source) => source.capabilities.contains(capability))
        .toList(growable: false);
  }

  Future<void> _loadDiscoverySection() async {
    if (!mounted) return;
    setState(() {
      _loadingDiscovery = true;
      _discoveryError = null;
      _discoveryShelves = const [];
      _categories = const [];
      _browseResults = const [];
      _selectedCategory = null;
    });

    try {
      switch (_discoverSection) {
        case _DiscoverSection.recommended:
          await _loadRecommendations();
        case _DiscoverSection.categories:
          await _loadCategories();
        case _DiscoverSection.latest:
          await _loadLatest();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _discoveryError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingDiscovery = false);
    }
  }

  Future<void> _loadRecommendations() async {
    final targets = _discoveryTargets('discover');
    final batches = await Future.wait(
      targets.map((source) async {
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
    if (!mounted) return;
    setState(() {
      _discoveryShelves = batches.expand((items) => items).toList();
    });
  }

  Future<void> _loadCategories() async {
    final targets = _discoveryTargets('categories');
    final batches = await Future.wait(
      targets.map((source) async {
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
    if (!mounted) return;
    setState(() => _categories = batches.expand((items) => items).toList());
  }

  Future<void> _loadLatest() async {
    final targets = _discoveryTargets('browse');
    final batches = await Future.wait(
      targets.map((source) async {
        try {
          final page = await _client.browse(source, sort: 'latest');
          return page.items
              .map((book) => _SourcedBook(source: source, book: book))
              .toList(growable: false);
        } catch (_) {
          return const <_SourcedBook>[];
        }
      }),
    );
    final results = batches.expand((items) => items).toList();
    results.sort((a, b) {
      final left = a.book.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final right = b.book.updatedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      return right.compareTo(left);
    });
    if (!mounted) return;
    setState(() => _browseResults = results);
  }

  Future<void> _selectCategory(_SourcedCategory category) async {
    if (!category.source.capabilities.contains('browse')) {
      setState(() {
        _selectedCategory = category;
        _browseResults = const [];
      });
      return;
    }
    setState(() {
      _selectedCategory = category;
      _browseResults = const [];
      _loadingDiscovery = true;
      _discoveryError = null;
    });
    try {
      final page = await _client.browse(
        category.source,
        category: category.id,
        sort: 'popular',
      );
      if (!mounted) return;
      setState(() {
        _browseResults = page.items
            .map(
              (book) => _SourcedBook(source: category.source, book: book),
            )
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _discoveryError = error.toString());
    } finally {
      if (mounted) setState(() => _loadingDiscovery = false);
    }
  }

  Future<void> _openSourceManagement() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const BookSourceManagementPage(),
      ),
    );
    if (mounted) await _loadSources();
  }

  Widget _buildResultHeader() {
    var scopeLabel = context.l10n.statsRangeAll;
    for (final source in _sources) {
      if (source.id == _selectedSourceId) {
        scopeLabel = source.name;
        break;
      }
    }
    final title = _searching
        ? context.l10n.bookSourcesSearching
        : '${context.l10n.bookSourcesSearch} · $scopeLabel · ${_results.length}';
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
    );
  }

  Widget _buildResultEmptyState() {
    final scheme = Theme.of(context).colorScheme;
    final hasQuery = _searchController.text.trim().isNotEmpty;
    return Column(
      children: [
        Icon(
          hasQuery ? Icons.search_off_rounded : Icons.auto_stories_outlined,
          size: 42,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
        ),
        const SizedBox(height: 10),
        Text(
          hasQuery
              ? context.l10n.bookSourcesNoResults
              : context.l10n.bookSourcesSearchPrompt,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }

  Widget _buildBookResult(_SourcedBook result) {
    final scheme = Theme.of(context).colorScheme;
    final book = result.book;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _showBookDetails(result),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: _panelDecoration(radius: 18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildBookCover(book),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    [book.author, result.source.name]
                        .where((item) => item.isNotEmpty)
                        .join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (book.description.isNotEmpty) ...[
                    const SizedBox(height: 7),
                    Text(
                      book.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: scheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }

  Widget _buildBookCover(BookSourceBook book) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: 58,
      height: 78,
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(Icons.menu_book_rounded, color: scheme.onTertiaryContainer),
    );
    if (book.coverUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        book.coverUrl.toString(),
        width: 58,
        height: 78,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  BoxDecoration _panelDecoration({
    double radius = 16,
    bool stronger = false,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final palette = PageStyleHelper.palette(context);
    return BoxDecoration(
      color: _isMaterial3Style
          ? (stronger ? scheme.surfaceContainer : scheme.surfaceContainerLow)
          : (stronger ? palette.cardStrong : palette.card),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: scheme.outline.withValues(
          alpha: _isMaterial3Style ? 0.22 : 0.12,
        ),
        width: 0.8,
      ),
    );
  }

  void _showBookDetails(_SourcedBook result) {
    final book = result.book;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.9,
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    key: const Key('bookSourceDetailsScroll'),
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          book.title,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          [book.author, result.source.name]
                              .where((item) => item.isNotEmpty)
                              .join(' · '),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        if (book.description.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            book.description,
                            style: const TextStyle(height: 1.5),
                          ),
                        ],
                        const SizedBox(height: 18),
                        Text(
                          context.l10n.bookSourcesIdentity(
                            result.source.id,
                            book.id,
                          ),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton.icon(
                          key: const Key('bookSourceAddToShelfButton'),
                          onPressed: () {
                            Navigator.pop(context);
                            unawaited(_showAddToShelfOptions(result));
                          },
                          icon: const Icon(Icons.add_to_photos_outlined),
                          label: Text(context.l10n.bookSourceAddToShelf),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          key: const Key('bookSourceReadButton'),
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.of(this.context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => BookSourceReaderPage(
                                  source: result.source,
                                  book: book,
                                  client: _client,
                                  shelfService: _shelfService,
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.menu_book_rounded),
                          label: Text(context.l10n.reading),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddToShelfOptions(_SourcedBook result) async {
    final choice = await showModalBottomSheet<_ShelfAddMode>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.cloud_outlined),
                title: Text(context.l10n.bookSourceAddOnline),
                subtitle: Text(context.l10n.bookSourceAddOnlineHint),
                onTap: () => Navigator.pop(context, _ShelfAddMode.online),
              ),
              ListTile(
                leading: const Icon(Icons.download_for_offline_outlined),
                title: Text(context.l10n.bookSourceDownloadLocal),
                subtitle: Text(context.l10n.bookSourceDownloadLocalHint),
                onTap: () => Navigator.pop(context, _ShelfAddMode.local),
              ),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    if (choice == _ShelfAddMode.online) {
      final existing = await _shelfService.findShelfBook(
        sourceId: result.source.id,
        sourceBookId: result.book.id,
      );
      if (existing == null) {
        await _shelfService.addOnline(
          source: result.source,
          book: result.book,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            existing == null
                ? context.l10n.bookSourceAddedOnline
                : context.l10n.bookSourceAlreadyOnShelf,
          ),
        ),
      );
      return;
    }
    await _downloadSourceBook(result);
  }

  Future<void> _downloadSourceBook(_SourcedBook result) async {
    final progress = ValueNotifier<(int, int)>((0, 0));
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text(context.l10n.bookSourceDownloading),
          content: ValueListenableBuilder<(int, int)>(
            valueListenable: progress,
            builder: (context, value, _) {
              final total = value.$2;
              final ratio = total <= 0 ? null : value.$1 / total;
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LinearProgressIndicator(value: ratio),
                  const SizedBox(height: 12),
                  Text(
                    total <= 0
                        ? context.l10n.bookSourceFetchingCatalog
                        : context.l10n.bookSourceDownloadProgress(
                            value.$1,
                            total,
                          ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    try {
      await _shelfService.downloadToLocal(
        source: result.source,
        book: result.book,
        onProgress: (completed, total) {
          progress.value = (completed, total);
        },
      );
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.bookSourceDownloadComplete)),
      );
    } catch (error) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(context.l10n.bookSourceDownloadFailed('$error'))),
      );
    } finally {
      progress.dispose();
    }
  }
}

enum _ShelfAddMode { online, local }

enum _DiscoverSection { recommended, categories, latest }

class _SourcedBook {
  final RegisteredBookSource source;
  final BookSourceBook book;

  const _SourcedBook({required this.source, required this.book});
}

class _SearchBatch {
  final List<_SourcedBook> items;
  final bool failed;

  const _SearchBatch({required this.items, this.failed = false});
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

const String _allSourcesMenuValue = '__all_enabled_sources__';
