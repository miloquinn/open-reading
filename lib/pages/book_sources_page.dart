import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../book_sources/models/registered_book_source.dart';
import '../book_sources/protocol/book_source_protocol.dart';
import '../book_sources/services/book_source_client.dart';
import '../book_sources/services/book_source_registry.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';
import '../utils/ui_style.dart';
import 'home_layout_constants.dart';
import 'home_shell_page.dart';

class BookSourcesPage extends StatefulWidget {
  const BookSourcesPage({super.key});

  @override
  State<BookSourcesPage> createState() => _BookSourcesPageState();
}

class _BookSourcesPageState extends State<BookSourcesPage> {
  final BookSourceRegistry _registry = BookSourceRegistry();
  final BookSourceClient _client = BookSourceClient();
  final TextEditingController _searchController = TextEditingController();

  List<RegisteredBookSource> _sources = const [];
  List<_SourcedBook> _results = const [];
  bool _loadingSources = true;
  bool _searching = false;
  int _failedSourceCount = 0;

  bool get _isMaterial3Style =>
      Theme.of(context).extension<UiStyleThemeExtension>()?.isMaterial3Style ??
      false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSources());
  }

  @override
  void dispose() {
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
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    final enabledSources =
        _sources.where((source) => source.enabled).toList(growable: false);
    if (query.isEmpty || enabledSources.isEmpty || _searching) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _searching = true;
      _failedSourceCount = 0;
    });

    final batches = await Future.wait(
      enabledSources.map((source) async {
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
                        _buildSourceSection(),
                        const SizedBox(height: 18),
                        _buildProtocolCard(),
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
        context.l10n.bookSources,
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
                      context.l10n.bookSources,
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
                context.l10n.bookSourcesSubtitle,
                style: TextStyle(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: _showAddSourceDialog,
            icon: const Icon(Icons.add_link_rounded),
            label: Text(context.l10n.bookSourcesAdd),
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
    final enabledCount = _sources.where((source) => source.enabled).length;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _panelDecoration(radius: 20),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              enabled: enabledCount > 0 && !_searching,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: context.l10n.bookSourcesSearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: context.l10n.bookSourcesSearch,
            onPressed: enabledCount > 0 && !_searching ? _search : null,
            icon: _searching
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Icon(Icons.arrow_forward_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.bookSourcesManageTitle,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 10),
        if (_loadingSources)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_sources.isEmpty)
          _buildNoSourcesCard()
        else
          ..._sources.map(_buildSourceCard),
      ],
    );
  }

  Widget _buildNoSourcesCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: _panelDecoration(radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.travel_explore_rounded, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.bookSourcesNoSourcesTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 5),
                Text(
                  context.l10n.bookSourcesNoSourcesDescription,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSourceCard(RegisteredBookSource source) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: _panelDecoration(radius: 18),
        child: Row(
          children: [
            _buildSourceIcon(source),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    source.description.isEmpty
                        ? source.apiBaseUrl.host
                        : source.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: source.enabled,
              onChanged: (enabled) => _setSourceEnabled(source, enabled),
            ),
            PopupMenuButton<String>(
              tooltip: '',
              onSelected: (value) {
                if (value == 'remove') _confirmRemoveSource(source);
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'remove',
                  child: Row(
                    children: [
                      const Icon(Icons.delete_outline_rounded),
                      const SizedBox(width: 10),
                      Text(context.l10n.bookSourcesRemove),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSourceIcon(RegisteredBookSource source) {
    final scheme = Theme.of(context).colorScheme;
    final fallback = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(13),
      ),
      alignment: Alignment.center,
      child: Text(
        source.name.characters.first.toUpperCase(),
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (source.iconUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Image.network(
        source.iconUrl.toString(),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => fallback,
      ),
    );
  }

  Widget _buildProtocolCard() {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(radius: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.api_rounded, color: scheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.bookSourcesProtocolTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.bookSourcesProtocolDescription,
                  style: TextStyle(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    TextButton.icon(
                      onPressed: _showProtocolDialog,
                      icon: const Icon(Icons.schema_outlined, size: 18),
                      label: Text(context.l10n.bookSourcesProtocolDetails),
                    ),
                    TextButton.icon(
                      onPressed: _openProtocolRepository,
                      icon: const Icon(Icons.open_in_new_rounded, size: 18),
                      label: Text(context.l10n.bookSourcesProtocolRepository),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultHeader() {
    final title = _searching
        ? context.l10n.bookSourcesSearching
        : '${context.l10n.bookSourcesSearch} · ${_results.length}';
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

  Future<void> _setSourceEnabled(
    RegisteredBookSource source,
    bool enabled,
  ) async {
    final sources = await _registry.setEnabled(source.id, enabled);
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _results = const [];
      _failedSourceCount = 0;
    });
  }

  Future<void> _confirmRemoveSource(RegisteredBookSource source) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.bookSourcesRemoveTitle),
        content: Text(context.l10n.bookSourcesRemoveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.bookSourcesCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.bookSourcesConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final sources = await _registry.remove(source.id);
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _results = _results
          .where((result) => result.source.id != source.id)
          .toList(growable: false);
    });
  }

  Future<void> _showAddSourceDialog() async {
    final controller = TextEditingController();
    var connecting = false;
    String? errorText;
    await showDialog<void>(
      context: context,
      barrierDismissible: !connecting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.bookSourcesAddTitle),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: controller,
                  enabled: !connecting,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    labelText: context.l10n.bookSourcesUrlLabel,
                    hintText: context.l10n.bookSourcesUrlHint,
                    errorText: errorText,
                    prefixIcon: const Icon(Icons.link_rounded),
                  ),
                ),
                if (connecting) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 10),
                      Text(context.l10n.bookSourcesConnecting),
                    ],
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: connecting ? null : () => Navigator.pop(dialogContext),
              child: Text(context.l10n.bookSourcesCancel),
            ),
            FilledButton(
              onPressed: connecting
                  ? null
                  : () async {
                      setDialogState(() {
                        connecting = true;
                        errorText = null;
                      });
                      try {
                        final discovered =
                            await _client.discover(controller.text);
                        final source = RegisteredBookSource.fromManifest(
                          manifest: discovered.manifest,
                          manifestUrl: discovered.manifestUrl,
                        );
                        final sources = await _registry.upsert(source);
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        setState(() => _sources = sources);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${this.context.l10n.bookSourcesAdded}: '
                              '${source.name}',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          connecting = false;
                          errorText = error.toString();
                        });
                      }
                    },
              child: Text(context.l10n.bookSourcesConnect),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
  }

  void _showProtocolDialog() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.bookSourcesProtocolDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.bookSourcesProtocolDialogBody,
                style: const TextStyle(height: 1.5),
              ),
              const SizedBox(height: 18),
              Text(
                context.l10n.bookSourcesProtocolRepository,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SelectableText(
                openReadingSourceProtocolRepositoryUrl,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: _openProtocolRepository,
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: Text(context.l10n.bookSourcesProtocolRepositoryOpen),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.bookSourcesClose),
          ),
        ],
      ),
    );
  }

  Future<void> _openProtocolRepository() async {
    final opened = await launchUrl(
      Uri.parse(openReadingSourceProtocolRepositoryUrl),
      mode: LaunchMode.externalApplication,
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.bookSourcesProtocolRepositoryOpenFailed),
        ),
      );
    }
  }

  void _showBookDetails(_SourcedBook result) {
    final book = result.book;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                book.title,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                [book.author, result.source.name]
                    .where((item) => item.isNotEmpty)
                    .join(' · '),
                style: TextStyle(color: Theme.of(context).colorScheme.primary),
              ),
              if (book.description.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(book.description, style: const TextStyle(height: 1.5)),
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
    );
  }
}

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
