import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xxread/book_sources/legado/legado_source_import_service.dart';
import 'package:xxread/book_sources/legado/legado_source_verifier.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_import_analyzer.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/utils/layout_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/widgets/side_toast.dart';
import 'package:xxread/widgets/source_cover_image.dart';

/// Low-frequency configuration for online content providers.
///
/// Discovery remains user-facing; adding, enabling and removing providers lives
/// here so technical configuration does not interrupt the book-browsing flow.
class BookSourceManagementPage extends StatefulWidget {
  const BookSourceManagementPage({super.key});

  @override
  State<BookSourceManagementPage> createState() =>
      _BookSourceManagementPageState();
}

class _BookSourceManagementPageState extends State<BookSourceManagementPage> {
  final BookSourceRegistry _registry = BookSourceRegistry();
  BookSourceClient? _client;
  LegadoSourceImportService? _importService;
  BookSourceImportAnalyzer? _importAnalyzer;
  LegadoSourceVerifier? _sourceVerifier;

  BookSourceClient get _sourceClient => _client ??= BookSourceClient();
  LegadoSourceImportService get _additionalImportService =>
      _importService ??= LegadoSourceImportService();
  BookSourceImportAnalyzer get _sourceImportAnalyzer => _importAnalyzer ??=
      BookSourceImportAnalyzer(additionalImporter: _additionalImportService);
  LegadoSourceVerifier get _additionalSourceVerifier =>
      _sourceVerifier ??= LegadoSourceVerifier();

  List<RegisteredBookSource> _sources = const [];
  final Set<String> _selectedSourceIds = {};
  bool _loading = true;
  bool _selectionMode = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSources());
  }

  Future<void> _loadSources() async {
    final sources = await _registry.load();
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _loading = false;
    });
  }

  @override
  void dispose() {
    _client?.close();
    _importService?.close();
    _sourceVerifier?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    var additionalProtocolsEnabled = false;
    try {
      additionalProtocolsEnabled = context
          .watch<AppSettingsNotifier>()
          .additionalSourceProtocolsEnabled;
    } on ProviderNotFoundException {
      // Standalone embeds without app settings retain the default-off state.
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(context.l10n.bookSourceManagementTitle),
        actions: [
          IconButton(
            tooltip: context.l10n.bookSourcesAdd,
            onPressed: _showAddSourceDialog,
            icon: const Icon(Icons.add_link_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 36),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 920),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        context.l10n.bookSourceManagementSubtitle,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              context.l10n.bookSourcesManageTitle,
                              style: Theme.of(context).textTheme.titleLarge
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: _showAddSourceDialog,
                            icon: const Icon(Icons.add_rounded),
                            label: Text(context.l10n.bookSourcesAdd),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            key: const Key('bookSourcesSelectionModeButton'),
                            tooltip: context.l10n.bookSourcesSelect,
                            onPressed: () => setState(() {
                              _selectionMode = !_selectionMode;
                              _selectedSourceIds.clear();
                            }),
                            icon: Icon(
                              _selectionMode
                                  ? Icons.close_rounded
                                  : Icons.checklist_rounded,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_selectionMode) ...[
                        _buildBulkActions(additionalProtocolsEnabled),
                        const SizedBox(height: 12),
                      ],
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(36),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_sources.isEmpty)
                        _buildNoSourcesCard()
                      else
                        ..._buildSourceGroups(additionalProtocolsEnabled),
                      const SizedBox(height: 22),
                      _buildProtocolCard(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
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
                  style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSourceGroups(bool additionalProtocolsEnabled) {
    final orsp = _sources
        .where((source) => source.sourceProtocol == BookSourceProtocolKind.orsp)
        .toList(growable: false);
    final additional = _sources
        .where((source) => source.sourceProtocol != BookSourceProtocolKind.orsp)
        .toList(growable: false);
    return [
      if (orsp.isNotEmpty)
        ..._buildSourceGroup(
          title: context.l10n.bookSourcesProtocolGroupOrsp,
          sources: orsp,
          additionalProtocolsEnabled: additionalProtocolsEnabled,
        ),
      if (additional.isNotEmpty)
        ..._buildSourceGroup(
          title: context.l10n.bookSourcesProtocolGroupAdditional,
          sources: additional,
          additionalProtocolsEnabled: additionalProtocolsEnabled,
        ),
    ];
  }

  Widget _buildBulkActions(bool additionalProtocolsEnabled) {
    final allIds = _sources.map((source) => source.id).toSet();
    final allSelected =
        allIds.isNotEmpty && _selectedSourceIds.containsAll(allIds);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        OutlinedButton.icon(
          onPressed: () => setState(() {
            if (allSelected) {
              _selectedSourceIds.clear();
            } else {
              _selectedSourceIds
                ..clear()
                ..addAll(allIds);
            }
          }),
          icon: Icon(
            allSelected ? Icons.deselect_rounded : Icons.select_all_rounded,
          ),
          label: Text(
            allSelected
                ? context.l10n.bookSourcesClearSelection
                : context.l10n.bookSourcesSelectAll,
          ),
        ),
        FilledButton.tonalIcon(
          onPressed: _selectedSourceIds.isEmpty
              ? null
              : () => _setSelectedSourcesEnabled(
                  true,
                  additionalProtocolsEnabled,
                ),
          icon: const Icon(Icons.toggle_on_outlined),
          label: Text(context.l10n.bookSourcesEnableSelected),
        ),
        OutlinedButton.icon(
          onPressed: _selectedSourceIds.isEmpty
              ? null
              : () => _setSelectedSourcesEnabled(
                  false,
                  additionalProtocolsEnabled,
                ),
          icon: const Icon(Icons.toggle_off_outlined),
          label: Text(context.l10n.bookSourcesDisableSelected),
        ),
        TextButton.icon(
          onPressed: _selectedSourceIds.isEmpty ? null : _removeSelectedSources,
          icon: const Icon(Icons.delete_outline_rounded),
          label: Text(context.l10n.bookSourcesDeleteSelected),
        ),
      ],
    );
  }

  void _toggleSourceSelection(RegisteredBookSource source) {
    setState(() {
      if (!_selectedSourceIds.add(source.id)) {
        _selectedSourceIds.remove(source.id);
      }
    });
  }

  Future<void> _setSelectedSourcesEnabled(
    bool enabled,
    bool additionalProtocolsEnabled,
  ) async {
    final allowedIds = _sources
        .where(
          (source) =>
              _selectedSourceIds.contains(source.id) &&
              (!enabled ||
                  source.sourceProtocol == BookSourceProtocolKind.orsp ||
                  additionalProtocolsEnabled),
        )
        .map((source) => source.id);
    final sources = await _registry.setEnabledAll(allowedIds, enabled);
    if (!mounted) return;
    setState(() => _sources = sources);
  }

  Future<void> _removeSelectedSources() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.bookSourcesDeleteSelected),
        content: Text(
          context.l10n.bookSourcesDeleteSelectedMessage(
            _selectedSourceIds.length,
          ),
        ),
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
    final sources = await _registry.removeAll(_selectedSourceIds);
    if (!mounted) return;
    setState(() {
      _sources = sources;
      _selectedSourceIds.clear();
      _selectionMode = false;
    });
  }

  List<Widget> _buildSourceGroup({
    required String title,
    required List<RegisteredBookSource> sources,
    required bool additionalProtocolsEnabled,
  }) {
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
            Text(
              '${sources.length}',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      ...sources.map(
        (source) => _buildSourceCard(
          source,
          additionalProtocolsEnabled: additionalProtocolsEnabled,
        ),
      ),
    ];
  }

  Widget _buildSourceCard(
    RegisteredBookSource source, {
    required bool additionalProtocolsEnabled,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final canEnable =
        source.capabilities.isNotEmpty &&
        (source.sourceProtocol == BookSourceProtocolKind.orsp ||
            additionalProtocolsEnabled);
    final selected = _selectedSourceIds.contains(source.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 640;
          return Container(
            key: ValueKey('bookSourceCard-${source.id}'),
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 18,
              compact ? 16 : 14,
              compact ? 10 : 8,
              compact ? 12 : 14,
            ),
            decoration: _panelDecoration(radius: 20),
            child: compact
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_selectionMode)
                            Checkbox(
                              value: selected,
                              onChanged: (_) => _toggleSourceSelection(source),
                            )
                          else
                            _buildSourceIcon(source, size: 52),
                          const SizedBox(width: 13),
                          Expanded(child: _buildSourceSummary(source)),
                          _buildSourceMenu(source),
                        ],
                      ),
                      if (source.capabilities.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _buildCapabilityChips(source),
                      ],
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.only(left: 12),
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                source.enabled
                                    ? context.l10n.bookSourcesEnabled
                                    : context.l10n.bookSourcesDisabled,
                                style: TextStyle(
                                  color: source.enabled
                                      ? scheme.primary
                                      : scheme.onSurfaceVariant,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Switch.adaptive(
                              value: source.enabled,
                              onChanged: !canEnable
                                  ? null
                                  : (enabled) =>
                                        _setSourceEnabled(source, enabled),
                            ),
                            if (source.sourceProtocol ==
                                BookSourceProtocolKind.orsp)
                              IconButton(
                                tooltip: context.l10n.bookSourcesRefresh,
                                onPressed: () => _refreshSource(source),
                                icon: const Icon(Icons.refresh_rounded),
                              ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      if (_selectionMode)
                        Checkbox(
                          value: selected,
                          onChanged: (_) => _toggleSourceSelection(source),
                        )
                      else
                        _buildSourceIcon(source),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSourceSummary(source),
                            if (source.capabilities.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildCapabilityChips(source),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        source.enabled
                            ? context.l10n.bookSourcesEnabled
                            : context.l10n.bookSourcesDisabled,
                        style: TextStyle(
                          color: source.enabled
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      if (!_selectionMode)
                        Switch.adaptive(
                          value: source.enabled,
                          onChanged: !canEnable
                              ? null
                              : (enabled) => _setSourceEnabled(source, enabled),
                        ),
                      if (!_selectionMode &&
                          source.sourceProtocol == BookSourceProtocolKind.orsp)
                        IconButton(
                          tooltip: context.l10n.bookSourcesRefresh,
                          onPressed: () => _refreshSource(source),
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      if (!_selectionMode) _buildSourceMenu(source),
                    ],
                  ),
          );
        },
      ),
    );
  }

  Widget _buildSourceSummary(RegisteredBookSource source) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          source.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w800,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          source.description.isEmpty
              ? source.apiBaseUrl.host
              : source.description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: scheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildCapabilityChips(RegisteredBookSource source) {
    final scheme = Theme.of(context).colorScheme;
    final capabilities = source.capabilities.toList()..sort();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: capabilities
          .map(
            (capability) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: scheme.secondaryContainer.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                capability,
                style: TextStyle(
                  color: scheme.onSecondaryContainer,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildSourceMenu(RegisteredBookSource source) {
    return PopupMenuButton<String>(
      tooltip: context.l10n.bookSourcesRemove,
      onSelected: (value) {
        if (value == 'rights') _showSourceRightsDialog(source);
        if (value == 'remove') _confirmRemoveSource(source);
      },
      itemBuilder: (context) => [
        if (source.sourceProtocol == BookSourceProtocolKind.orsp)
          PopupMenuItem(
            value: 'rights',
            child: Text(context.l10n.bookSourcesRightsDetails),
          ),
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
    );
  }

  Widget _buildSourceIcon(RegisteredBookSource source, {double size = 48}) {
    final scheme = Theme.of(context).colorScheme;
    final initial = source.name.characters.firstOrNull?.toUpperCase() ?? '?';
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(size * 0.29),
      ),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    if (source.iconUrl == null) return fallback;
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.29),
      child: SourceCoverImage(
        url: source.iconUrl!,
        fallback: fallback,
        width: size,
        height: size,
        fit: BoxFit.cover,
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
                    TextButton.icon(
                      onPressed: _openRightsReport,
                      icon: const Icon(Icons.report_outlined, size: 18),
                      label: Text(context.l10n.bookSourcesRightsReport),
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

  BoxDecoration _panelDecoration({required double radius}) {
    final palette = PageStyleHelper.palette(context);
    return BoxDecoration(
      color: palette.card,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: palette.border),
    );
  }

  Future<void> _setSourceEnabled(
    RegisteredBookSource source,
    bool enabled,
  ) async {
    final sources = await _registry.setEnabled(source.id, enabled);
    if (!mounted) return;
    setState(() => _sources = sources);
  }

  Future<void> _refreshSource(RegisteredBookSource source) async {
    try {
      final sources = await _registry.refresh(source, _sourceClient);
      if (!mounted) return;
      setState(() => _sources = sources);
      showSideToast(
        context,
        context.l10n.bookSourcesRefreshed,
        kind: SideToastKind.success,
      );
    } on BookSourceProtocolException {
      if (!mounted) return;
      showSideToast(
        context,
        context.l10n.bookSourcesRefreshFailed,
        kind: SideToastKind.error,
      );
    } catch (_) {
      if (!mounted) return;
      showSideToast(
        context,
        context.l10n.bookSourcesRefreshFailed,
        kind: SideToastKind.error,
      );
    }
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
    setState(() => _sources = sources);
  }

  Future<void> _showSourceRightsDialog(RegisteredBookSource source) async {
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.bookSourcesRightsDetails),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _rightsField(
                  context.l10n.bookSourcesOperator,
                  source.operatorName,
                ),
                _rightsField(
                  context.l10n.bookSourcesContentLicense,
                  source.contentLicense,
                ),
                _rightsField(
                  context.l10n.bookSourcesRightsStatement,
                  source.rightsStatement,
                ),
                const SizedBox(height: 8),
                Text(
                  context.l10n.bookSourcesRightsUnverifiedNotice,
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
                    if (source.contactUrl != null)
                      TextButton.icon(
                        onPressed: () => _openExternalUrl(source.contactUrl!),
                        icon: const Icon(
                          Icons.contact_support_outlined,
                          size: 18,
                        ),
                        label: Text(context.l10n.bookSourcesContactOperator),
                      ),
                    TextButton.icon(
                      onPressed: _openRightsReport,
                      icon: const Icon(Icons.report_outlined, size: 18),
                      label: Text(context.l10n.bookSourcesRightsReport),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(context.l10n.bookSourcesClose),
          ),
        ],
      ),
    );
  }

  Widget _rightsField(String label, String value) {
    final displayed = value.trim().isEmpty
        ? context.l10n.bookSourcesRightsNotProvided
        : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          SelectableText(displayed, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }

  Future<void> _showAddSourceDialog() async {
    final controller = TextEditingController();
    var connecting = false;
    var responsibilityAccepted = false;
    var mode = _AddSourceMode.link;
    BookSourceImportAnalysis? analysis;
    var verificationCompleted = 0;
    var verificationTotal = 0;
    var verificationAvailable = 0;
    String? errorText;

    Future<void> analyzeLink(
      BuildContext routeContext,
      StateSetter setRouteState,
    ) async {
      setRouteState(() {
        connecting = true;
        errorText = null;
      });
      try {
        final result = await _sourceImportAnalyzer.analyzeUrl(controller.text);
        if (!routeContext.mounted) return;
        setRouteState(() {
          analysis = result;
          connecting = false;
        });
      } catch (error) {
        if (!routeContext.mounted) return;
        setRouteState(() {
          connecting = false;
          errorText = error.toString();
        });
      }
    }

    Future<void> chooseFile(
      BuildContext routeContext,
      StateSetter setRouteState,
    ) async {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['json'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      if (file.size > LegadoSourceImportService.maxImportBytes) {
        setRouteState(() => errorText = 'Source file exceeds 64 MiB.');
        return;
      }
      final bytes = file.bytes;
      if (bytes == null) {
        setRouteState(() => errorText = 'Could not read source file.');
        return;
      }
      setRouteState(() {
        connecting = true;
        errorText = null;
        analysis = null;
      });
      try {
        final detected = _sourceImportAnalyzer.analyzeBytes(bytes);
        if (!routeContext.mounted) return;
        setRouteState(() {
          analysis = detected;
          connecting = false;
        });
      } catch (error) {
        if (!routeContext.mounted) return;
        setRouteState(() {
          connecting = false;
          errorText = error.toString();
        });
      }
    }

    Future<void> addDetected(
      BuildContext routeContext,
      StateSetter setRouteState,
    ) async {
      final noWorkingSourcesMessage = context.l10n.bookSourcesNoWorkingSources;
      final detected = analysis;
      if (detected == null) return;
      if (detected.kind == BookSourceImportKind.additional &&
          !_additionalProtocolsEnabled()) {
        setRouteState(() {
          errorText = context.l10n.bookSourcesAdvancedFeatureRequired;
        });
        return;
      }
      setRouteState(() {
        connecting = true;
        errorText = null;
      });
      try {
        late final List<RegisteredBookSource> sources;
        var importedAdditionalCount = 0;
        if (detected.kind == BookSourceImportKind.orsp) {
          sources = await _registry.upsert(detected.sources.single);
        } else {
          final preview = detected.additionalPreview!;
          final verified = await _additionalSourceVerifier.verify(
            preview.sources,
            onProgress: (completed, total, available) {
              if (!routeContext.mounted) return;
              setRouteState(() {
                verificationCompleted = completed;
                verificationTotal = total;
                verificationAvailable = available;
              });
            },
          );
          if (verified.available.isEmpty) {
            throw BookSourceProtocolException(noWorkingSourcesMessage);
          }
          importedAdditionalCount = verified.available.length;
          sources = await _registry.upsertAll(verified.available);
        }
        if (!mounted || !routeContext.mounted) return;
        Navigator.pop(routeContext);
        setState(() => _sources = sources);
        showSideToast(
          context,
          detected.kind == BookSourceImportKind.orsp
              ? '${context.l10n.bookSourcesAdded}: ${detected.sources.single.name}'
              : context.l10n.additionalSourcesImported(importedAdditionalCount),
          kind: SideToastKind.success,
        );
      } catch (error) {
        if (!routeContext.mounted) return;
        setRouteState(() {
          connecting = false;
          errorText = error.toString();
        });
      }
    }

    Widget buildPanel(
      BuildContext routeContext,
      StateSetter setRouteState, {
      required bool sheet,
    }) {
      return _AddBookSourcePanel(
        controller: controller,
        connecting: connecting,
        responsibilityAccepted: responsibilityAccepted,
        mode: mode,
        analysis: analysis,
        verificationCompleted: verificationCompleted,
        verificationTotal: verificationTotal,
        verificationAvailable: verificationAvailable,
        errorText: errorText,
        sheet: sheet,
        onModeChanged: (value) => setRouteState(() {
          mode = value;
          analysis = null;
          errorText = null;
        }),
        onResponsibilityChanged: (value) =>
            setRouteState(() => responsibilityAccepted = value),
        onCancel: () => Navigator.pop(routeContext),
        onAnalyzeLink: () => analyzeLink(routeContext, setRouteState),
        onChooseFile: () => chooseFile(routeContext, setRouteState),
        onAdd: () => addDetected(routeContext, setRouteState),
      );
    }

    if (LayoutHelper.isMobile(context)) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (context, setSheetState) => AnimatedPadding(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.92,
              ),
              child: buildPanel(sheetContext, setSheetState, sheet: true),
            ),
          ),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        barrierDismissible: !connecting,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, setDialogState) => Dialog(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520, maxHeight: 720),
              child: buildPanel(dialogContext, setDialogState, sheet: false),
            ),
          ),
        ),
      );
    }
    controller.dispose();
  }

  bool _additionalProtocolsEnabled() {
    try {
      return context
          .read<AppSettingsNotifier>()
          .additionalSourceProtocolsEnabled;
    } on ProviderNotFoundException {
      return false;
    }
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
    final opened = await _openExternalUrl(
      Uri.parse(openReadingSourceProtocolRepositoryUrl),
    );
    if (!opened && mounted) {
      showSideToast(
        context,
        context.l10n.bookSourcesProtocolRepositoryOpenFailed,
        kind: SideToastKind.error,
      );
    }
  }

  Future<void> _openRightsReport() async {
    final opened = await _openExternalUrl(
      Uri.parse(openReadingRightsReportUrl),
    );
    if (!opened && mounted) {
      showSideToast(
        context,
        context.l10n.bookSourcesRightsReportOpenFailed,
        kind: SideToastKind.error,
      );
    }
  }

  Future<bool> _openExternalUrl(Uri url) {
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }
}

enum _AddSourceMode { link, file }

class _AddBookSourcePanel extends StatelessWidget {
  final TextEditingController controller;
  final bool connecting;
  final bool responsibilityAccepted;
  final _AddSourceMode mode;
  final BookSourceImportAnalysis? analysis;
  final int verificationCompleted;
  final int verificationTotal;
  final int verificationAvailable;
  final String? errorText;
  final bool sheet;
  final ValueChanged<_AddSourceMode> onModeChanged;
  final ValueChanged<bool> onResponsibilityChanged;
  final VoidCallback onCancel;
  final VoidCallback onAnalyzeLink;
  final VoidCallback onChooseFile;
  final VoidCallback onAdd;

  const _AddBookSourcePanel({
    required this.controller,
    required this.connecting,
    required this.responsibilityAccepted,
    required this.mode,
    required this.analysis,
    required this.verificationCompleted,
    required this.verificationTotal,
    required this.verificationAvailable,
    required this.errorText,
    required this.sheet,
    required this.onModeChanged,
    required this.onResponsibilityChanged,
    required this.onCancel,
    required this.onAnalyzeLink,
    required this.onChooseFile,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Material(
      type: MaterialType.transparency,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20, sheet ? 4 : 24, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.bookSourcesAdd,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<_AddSourceMode>(
              key: const Key('bookSourceAddMode'),
              segments: [
                ButtonSegment(
                  value: _AddSourceMode.link,
                  icon: const Icon(Icons.link_rounded),
                  label: Text(context.l10n.bookSourcesImportLink),
                ),
                ButtonSegment(
                  value: _AddSourceMode.file,
                  icon: const Icon(Icons.upload_file_outlined),
                  label: Text(context.l10n.additionalSourcesChooseFile),
                ),
              ],
              selected: {mode},
              onSelectionChanged: connecting
                  ? null
                  : (selection) => onModeChanged(selection.first),
            ),
            const SizedBox(height: 20),
            if (mode == _AddSourceMode.link) ...[
              TextField(
                key: const Key('bookSourceUnifiedUrlField'),
                controller: controller,
                enabled: !connecting,
                autofocus: false,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.done,
                decoration: InputDecoration(
                  labelText: context.l10n.bookSourcesUrlLabel,
                  hintText: context.l10n.bookSourcesUrlHint,
                  prefixIcon: const Icon(Icons.link_rounded),
                  border: const OutlineInputBorder(),
                ),
              ),
            ] else
              OutlinedButton.icon(
                key: const Key('bookSourceChooseJsonButton'),
                onPressed: connecting ? null : onChooseFile,
                icon: const Icon(Icons.upload_file_outlined),
                label: Text(context.l10n.additionalSourcesChooseFile),
              ),
            if (analysis case final detected?) ...[
              const SizedBox(height: 14),
              _DetectedSourceSummary(analysis: detected),
            ],
            if (errorText != null) ...[
              const SizedBox(height: 10),
              Text(errorText!, style: TextStyle(color: scheme.error)),
            ],
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.primary.withValues(alpha: 0.18),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, size: 21, color: scheme.primary),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      context.l10n.bookSourcesNoOfficialSourcesNotice,
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              key: const Key('bookSourceResponsibilityCheckbox'),
              value: responsibilityAccepted,
              enabled: !connecting,
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                context.l10n.bookSourcesResponsibilityAck,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              onChanged: connecting
                  ? null
                  : (value) => onResponsibilityChanged(value ?? false),
            ),
            if (connecting) ...[
              const SizedBox(height: 8),
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
              if (verificationTotal > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: verificationCompleted / verificationTotal,
                ),
                const SizedBox(height: 6),
                Text(
                  context.l10n.bookSourcesVerificationProgress(
                    verificationCompleted,
                    verificationTotal,
                    verificationAvailable,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: connecting ? null : onCancel,
                    child: Text(context.l10n.bookSourcesCancel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    key: const Key('bookSourceConnectButton'),
                    onPressed: connecting || !responsibilityAccepted
                        ? null
                        : analysis == null
                        ? mode == _AddSourceMode.link
                              ? onAnalyzeLink
                              : null
                        : onAdd,
                    child: Text(
                      analysis == null
                          ? context.l10n.bookSourcesAnalyze
                          : context.l10n.bookSourcesConfirm,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DetectedSourceSummary extends StatelessWidget {
  const _DetectedSourceSummary({required this.analysis});

  final BookSourceImportAnalysis analysis;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final preview = analysis.additionalPreview;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            analysis.kind == BookSourceImportKind.orsp
                ? context.l10n.bookSourcesDetectedOrsp
                : context.l10n.bookSourcesDetectedAdditional,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          if (analysis.kind == BookSourceImportKind.orsp)
            Text(analysis.sources.single.name)
          else if (preview != null)
            Text(
              context.l10n.additionalSourcesPreview(
                preview.supported,
                preview.partial,
                preview.unsupported,
              ),
            ),
        ],
      ),
    );
  }
}
