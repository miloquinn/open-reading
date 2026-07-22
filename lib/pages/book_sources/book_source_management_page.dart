import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xxread/book_sources/models/registered_book_source.dart';
import 'package:xxread/book_sources/protocol/book_source_protocol.dart';
import 'package:xxread/book_sources/services/book_source_client.dart';
import 'package:xxread/book_sources/services/book_source_registry.dart';
import 'package:xxread/utils/layout_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

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
  final BookSourceClient _client = BookSourceClient();

  List<RegisteredBookSource> _sources = const [];
  bool _loading = true;

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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
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
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.all(36),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_sources.isEmpty)
                        _buildNoSourcesCard()
                      else
                        ..._sources.map(_buildSourceCard),
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

  Widget _buildSourceCard(RegisteredBookSource source) {
    final scheme = Theme.of(context).colorScheme;
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
                              onChanged: (enabled) =>
                                  _setSourceEnabled(source, enabled),
                            ),
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
                      Switch.adaptive(
                        value: source.enabled,
                        onChanged: (enabled) =>
                            _setSourceEnabled(source, enabled),
                      ),
                      IconButton(
                        tooltip: context.l10n.bookSourcesRefresh,
                        onPressed: () => _refreshSource(source),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                      _buildSourceMenu(source),
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
    final fallback = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(size * 0.29),
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
      borderRadius: BorderRadius.circular(size * 0.29),
      child: Image.network(
        source.iconUrl.toString(),
        width: size,
        height: size,
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
      final sources = await _registry.refresh(source, _client);
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
    String? errorText;

    Future<void> connect(
      BuildContext routeContext,
      StateSetter setRouteState,
    ) async {
      setRouteState(() {
        connecting = true;
        errorText = null;
      });
      try {
        final discovered = await _client.discover(controller.text);
        final source = RegisteredBookSource.fromManifest(
          manifest: discovered.manifest,
          manifestUrl: discovered.manifestUrl,
        );
        final sources = await _registry.upsert(source);
        if (!mounted || !routeContext.mounted) return;
        Navigator.pop(routeContext);
        setState(() => _sources = sources);
        showSideToast(
          context,
          '${context.l10n.bookSourcesAdded}: ${source.name}',
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
        errorText: errorText,
        sheet: sheet,
        onResponsibilityChanged: (value) =>
            setRouteState(() => responsibilityAccepted = value),
        onCancel: () => Navigator.pop(routeContext),
        onConnect: () => connect(routeContext, setRouteState),
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

class _AddBookSourcePanel extends StatelessWidget {
  final TextEditingController controller;
  final bool connecting;
  final bool responsibilityAccepted;
  final String? errorText;
  final bool sheet;
  final ValueChanged<bool> onResponsibilityChanged;
  final VoidCallback onCancel;
  final VoidCallback onConnect;

  const _AddBookSourcePanel({
    required this.controller,
    required this.connecting,
    required this.responsibilityAccepted,
    required this.errorText,
    required this.sheet,
    required this.onResponsibilityChanged,
    required this.onCancel,
    required this.onConnect,
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
              context.l10n.bookSourcesAddTitle,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 20),
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
                border: const OutlineInputBorder(),
              ),
            ),
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
                        : onConnect,
                    child: Text(context.l10n.bookSourcesConnect),
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
