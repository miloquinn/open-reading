// 文件说明：跨书源聚合搜索页，由发现页右上角搜索按钮进入。
// 技术要点：Flutter UI、并发书源请求、按源分页加载更多。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_shelf_service.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';

import 'widgets/sourced_book_widgets.dart';

/// 跨已启用书源的聚合搜索页。
///
/// 搜索范围与分页状态都在本页内维护；发现页只负责展示书籍。
class SourceSearchPage extends StatefulWidget {
  final List<RegisteredBookSource> sources;
  final BookSourceClient client;
  final BookSourceShelfService shelfService;

  const SourceSearchPage({
    super.key,
    required this.sources,
    required this.client,
    required this.shelfService,
  });

  /// 解析实际参与搜索的书源集合；发现页与测试也复用这份规则。
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
  State<SourceSearchPage> createState() => _SourceSearchPageState();
}

class _SourceSearchPageState extends State<SourceSearchPage> {
  final TextEditingController _queryController = TextEditingController();
  final FocusNode _queryFocus = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final SourcedBookActions _actions = SourcedBookActions(
    context: context,
    client: widget.client,
    shelfService: widget.shelfService,
  );

  String? _selectedSourceId;
  List<SourcedBook> _results = const [];
  Map<String, _SearchPageState> _pageStates = const {};
  bool _searching = false;
  bool _hasSearched = false;
  bool _loadingMore = false;
  bool _loadMoreFailed = false;
  int _failedSourceCount = 0;
  String _activeQuery = '';

  bool get _hasMore => _pageStates.values.any((state) => state.hasMore);

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_handleScroll);
    // 进入搜索页直接聚焦输入框，用户可立即输入。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _queryFocus.requestFocus();
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    _queryController.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _handleScroll() {
    if (_loadMoreFailed ||
        !_scrollController.hasClients ||
        _scrollController.position.extentAfter > 600) {
      return;
    }
    unawaited(_loadMore());
  }

  List<RegisteredBookSource> get _targets =>
      SourceSearchPage.searchTargets(widget.sources, _selectedSourceId);

  Future<void> _search() async {
    final query = _queryController.text.trim();
    final targetSources = _targets;
    if (query.isEmpty || targetSources.isEmpty || _searching) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _hasSearched = true;
      _failedSourceCount = 0;
      _activeQuery = query;
      _results = const [];
      _pageStates = const {};
      _loadingMore = false;
      _loadMoreFailed = false;
    });

    final batches = await Future.wait(
      targetSources.map((source) async {
        try {
          final page = await widget.client.search(source, query);
          return _SearchBatch(
            source: source,
            items: page.items
                .map((book) => SourcedBook(source: source, book: book))
                .toList(growable: false),
            page: page.page,
            hasMore: page.hasMore && page.items.isNotEmpty,
          );
        } catch (_) {
          return _SearchBatch(source: source, items: const [], failed: true);
        }
      }),
    );

    if (!mounted) return;
    setState(() {
      _results = batches.expand((batch) => batch.items).toList(growable: false);
      _pageStates = {
        for (final batch in batches)
          if (!batch.failed)
            batch.source.id: _SearchPageState(
              source: batch.source,
              page: batch.page,
              hasMore: batch.hasMore,
            ),
      };
      _failedSourceCount = batches.where((batch) => batch.failed).length;
      _searching = false;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleScroll());
  }

  Future<void> _loadMore() async {
    if (_searching || _loadingMore || !_hasSearched || _activeQuery.isEmpty) {
      return;
    }
    final targets = _pageStates.values
        .where((state) => state.hasMore)
        .toList(growable: false);
    if (targets.isEmpty) return;

    final query = _activeQuery;
    setState(() {
      _loadingMore = true;
      _loadMoreFailed = false;
    });

    final batches = await Future.wait(
      targets.map((state) async {
        try {
          final page = await widget.client.search(
            state.source,
            query,
            page: state.page + 1,
          );
          return _SearchBatch(
            source: state.source,
            items: page.items
                .map((book) => SourcedBook(source: state.source, book: book))
                .toList(growable: false),
            page: page.page,
            hasMore: page.hasMore && page.items.isNotEmpty,
          );
        } catch (_) {
          return _SearchBatch(
            source: state.source,
            items: const [],
            failed: true,
          );
        }
      }),
    );

    if (!mounted || query != _activeQuery) return;
    final seen = _results
        .map((item) => '${item.source.id}\u0000${item.book.id}')
        .toSet();
    final appended = <SourcedBook>[];
    final nextStates = Map<String, _SearchPageState>.from(_pageStates);
    for (final batch in batches) {
      if (batch.failed) continue;
      nextStates[batch.source.id] = _SearchPageState(
        source: batch.source,
        page: batch.page,
        hasMore: batch.hasMore,
      );
      for (final item in batch.items) {
        final key = '${item.source.id}\u0000${item.book.id}';
        if (seen.add(key)) appended.add(item);
      }
    }

    setState(() {
      _results = [..._results, ...appended];
      _pageStates = nextStates;
      _loadingMore = false;
      _loadMoreFailed = batches.any((batch) => batch.failed);
    });
  }

  void _clearSearch() {
    _queryController.clear();
    setState(() {
      _results = const [];
      _pageStates = const {};
      _hasSearched = false;
      _failedSourceCount = 0;
      _activeQuery = '';
      _loadingMore = false;
      _loadMoreFailed = false;
    });
    _queryFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final enabledSources =
        widget.sources.where((source) => source.enabled).toList(
              growable: false,
            );
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: _buildQueryField(enabledSources),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (enabledSources.isNotEmpty) _buildScopeChips(enabledSources),
              Expanded(child: _buildBody(enabledSources)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQueryField(List<RegisteredBookSource> enabledSources) {
    final canSearch = enabledSources.isNotEmpty && !_searching;
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: TextField(
        key: const Key('bookSourceQueryControl'),
        controller: _queryController,
        focusNode: _queryFocus,
        enabled: canSearch,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _search(),
        decoration: InputDecoration(
          hintText: context.l10n.bookSourcesSearchHint,
          border: InputBorder.none,
          suffixIcon: _queryController.text.isEmpty
              ? null
              : IconButton(
                  key: const Key('bookSourceSearchClearButton'),
                  tooltip:
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                  icon: const Icon(Icons.close_rounded),
                  onPressed: _clearSearch,
                ),
        ),
        onChanged: (_) => setState(() {}),
      ),
    );
  }

  Widget _buildScopeChips(List<RegisteredBookSource> enabledSources) {
    return SizedBox(
      key: const Key('bookSourceScopeControl'),
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          ChoiceChip(
            selected: _selectedSourceId == null,
            label: Text(context.l10n.statsRangeAll),
            onSelected: (_) => _changeScope(null),
          ),
          const SizedBox(width: 8),
          for (final source in enabledSources) ...[
            ChoiceChip(
              selected: _selectedSourceId == source.id,
              label: Text(source.name),
              onSelected: (_) => _changeScope(source.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  void _changeScope(String? sourceId) {
    if (_selectedSourceId == sourceId) return;
    setState(() => _selectedSourceId = sourceId);
    if (_hasSearched && _activeQuery.isNotEmpty) {
      _queryController.text = _activeQuery;
      unawaited(_search());
    }
  }

  Widget _buildBody(List<RegisteredBookSource> enabledSources) {
    final scheme = Theme.of(context).colorScheme;
    if (enabledSources.isEmpty) {
      return _buildMessage(
        icon: Icons.travel_explore_outlined,
        title: context.l10n.bookSourcesNoSourcesTitle,
        message: context.l10n.bookSourcesNoSourcesDescription,
      );
    }
    if (_searching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!_hasSearched) {
      return _buildMessage(
        icon: Icons.manage_search_rounded,
        title: context.l10n.bookSourcesSearch,
        message: context.l10n.bookSourcesSearchHint,
      );
    }
    if (_results.isEmpty) {
      return _buildMessage(
        icon: Icons.search_off_rounded,
        title: context.l10n.bookSourcesNoResults,
        message: _failedSourceCount > 0
            ? context.l10n.bookSourcesFailedCount(_failedSourceCount)
            : '',
      );
    }
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
          sliver: SliverToBoxAdapter(
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${context.l10n.bookSourcesSearch}'
                    ' · ${_scopeLabel()} · ${_results.length}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_failedSourceCount > 0)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            sliver: SliverToBoxAdapter(
              child: Text(
                context.l10n.bookSourcesFailedCount(_failedSourceCount),
                style: TextStyle(color: scheme.error, fontSize: 12),
              ),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
          sliver: SliverList.separated(
            itemCount: _results.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final result = _results[index];
              return Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1048),
                  child: SourcedBookListTile(
                    result: result,
                    onTap: () => _actions.showBookDetails(result),
                  ),
                ),
              );
            },
          ),
        ),
        if (_hasMore || _loadingMore || _loadMoreFailed)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            sliver: SliverToBoxAdapter(
              child: Center(
                child: _loadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : OutlinedButton.icon(
                        key: const Key('bookSourceLoadMoreButton'),
                        onPressed: _loadMore,
                        icon: Icon(
                          _loadMoreFailed
                              ? Icons.refresh_rounded
                              : Icons.expand_more_rounded,
                        ),
                        label: Text(
                          _loadMoreFailed
                              ? context.l10n.retry
                              : context.l10n.bookSourcesLoadMore,
                        ),
                      ),
              ),
            ),
          ),
      ],
    );
  }

  String _scopeLabel() {
    for (final source in widget.sources) {
      if (source.id == _selectedSourceId) return source.name;
    }
    return context.l10n.statsRangeAll;
  }

  Widget _buildMessage({
    required IconData icon,
    required String title,
    required String message,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 42,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.55),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            if (message.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SearchBatch {
  final RegisteredBookSource source;
  final List<SourcedBook> items;
  final bool failed;
  final int page;
  final bool hasMore;

  const _SearchBatch({
    required this.source,
    required this.items,
    this.failed = false,
    this.page = 1,
    this.hasMore = false,
  });
}

class _SearchPageState {
  final RegisteredBookSource source;
  final int page;
  final bool hasMore;

  const _SearchPageState({
    required this.source,
    required this.page,
    required this.hasMore,
  });
}
