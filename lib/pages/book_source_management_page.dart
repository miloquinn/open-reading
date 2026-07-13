import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../book_sources/legado/legado_book_source.dart';
import '../book_sources/legado/legado_compatibility_scanner.dart';
import '../book_sources/legado/legado_source_registry.dart';
import '../book_sources/models/registered_book_source.dart';
import '../book_sources/protocol/book_source_protocol.dart';
import '../book_sources/services/book_source_client.dart';
import '../book_sources/services/book_source_registry.dart';
import '../utils/localization_extension.dart';
import '../utils/page_style_helper.dart';

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
  final LegadoSourceRegistry _legadoRegistry = const LegadoSourceRegistry();

  List<RegisteredBookSource> _sources = const [];
  List<RegisteredLegadoSource> _legadoSources = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSources());
  }

  Future<void> _loadSources() async {
    final results = await Future.wait<Object>([
      _registry.load(),
      _legadoRegistry.load(),
    ]);
    if (!mounted) return;
    setState(() {
      _sources = results[0] as List<RegisteredBookSource>;
      _legadoSources = results[1] as List<RegisteredLegadoSource>;
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
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
                      _buildLegadoSection(),
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
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: source.capabilities
                        .map(
                          (capability) => Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: scheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              capability,
                              style: TextStyle(
                                color: scheme.onSecondaryContainer,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        )
                        .toList(growable: false),
                  ),
                ],
              ),
            ),
            Switch.adaptive(
              value: source.enabled,
              onChanged: (enabled) => _setSourceEnabled(source, enabled),
            ),
            PopupMenuButton<String>(
              tooltip: context.l10n.bookSourcesRemove,
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
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(14),
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
      borderRadius: BorderRadius.circular(14),
      child: Image.network(
        source.iconUrl.toString(),
        width: 48,
        height: 48,
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

  Widget _buildLegadoSection() {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.legadoCompatibilityTitle,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    context.l10n.legadoCompatibilitySubtitle,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            OutlinedButton.icon(
              key: const Key('legadoImportButton'),
              onPressed: _showLegadoImportDialog,
              icon: const Icon(Icons.file_open_outlined),
              label: Text(context.l10n.legadoImport),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_legadoSources.isEmpty)
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _panelDecoration(radius: 18),
            child: Row(
              children: [
                Icon(Icons.rule_folder_outlined, color: scheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    context.l10n.legadoNoSources,
                    style: TextStyle(color: scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          )
        else
          ..._legadoSources.map(_buildLegadoSourceCard),
      ],
    );
  }

  Widget _buildLegadoSourceCard(RegisteredLegadoSource registered) {
    final scheme = Theme.of(context).colorScheme;
    final status = _legadoStatus(registered.compatibility.level);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        decoration: _panelDecoration(radius: 18),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: status.$2.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(status.$3, color: status.$2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    registered.source.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    registered.source.url,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: [
                      _buildLegadoBadge(status.$1, status.$2),
                      ...registered.compatibility.risks
                          .take(3)
                          .map((risk) => _buildLegadoBadge(risk.name, null)),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              tooltip: context.l10n.bookSourcesRemove,
              onSelected: (value) {
                if (value == 'remove') {
                  unawaited(_removeLegadoSource(registered));
                }
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

  Widget _buildLegadoBadge(String label, Color? color) {
    final scheme = Theme.of(context).colorScheme;
    final foreground = color ?? scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color?.withValues(alpha: 0.12) ?? scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  (String, Color, IconData) _legadoStatus(LegadoCompatibilityLevel level) {
    final scheme = Theme.of(context).colorScheme;
    return switch (level) {
      LegadoCompatibilityLevel.lite => (
          context.l10n.legadoLite,
          Colors.green.shade700,
          Icons.check_circle_outline_rounded,
        ),
      LegadoCompatibilityLevel.adapterRequired => (
          context.l10n.legadoAdapterRequired,
          Colors.orange.shade800,
          Icons.extension_outlined,
        ),
      LegadoCompatibilityLevel.unsupported => (
          context.l10n.legadoUnsupported,
          scheme.error,
          Icons.block_rounded,
        ),
    };
  }

  Future<void> _showLegadoImportDialog() async {
    final controller = TextEditingController();
    String? errorText;
    var importing = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: !importing,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(context.l10n.legadoImportTitle),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    context.l10n.legadoImportNotice,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: importing
                        ? null
                        : () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: const ['json'],
                              allowMultiple: false,
                              withData: true,
                            );
                            if (result == null || result.files.isEmpty) return;
                            final file = result.files.single;
                            if (file.size > 2 * 1024 * 1024) {
                              setDialogState(() {
                                errorText = context.l10n.legadoFileTooLarge;
                              });
                              return;
                            }
                            final bytes = file.bytes;
                            if (bytes == null) {
                              setDialogState(() {
                                errorText = context.l10n.legadoFileReadFailed;
                              });
                              return;
                            }
                            setDialogState(() {
                              controller.text = utf8.decode(
                                bytes,
                                allowMalformed: true,
                              );
                              errorText = null;
                            });
                          },
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(context.l10n.legadoChooseFile),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('legadoJsonField'),
                    controller: controller,
                    enabled: !importing,
                    minLines: 5,
                    maxLines: 10,
                    decoration: InputDecoration(
                      labelText: context.l10n.legadoJsonLabel,
                      hintText: context.l10n.legadoImportHint,
                      errorText: errorText,
                      alignLabelWithHint: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: importing ? null : () => Navigator.pop(dialogContext),
              child: Text(context.l10n.bookSourcesCancel),
            ),
            FilledButton(
              onPressed: importing
                  ? null
                  : () async {
                      setDialogState(() {
                        importing = true;
                        errorText = null;
                      });
                      try {
                        final result = parseLegadoSources(controller.text);
                        if (result.sources.isEmpty) {
                          throw FormatException(result.errors.join('\n'));
                        }
                        final sources =
                            await _legadoRegistry.upsertAll(result.sources);
                        if (!mounted || !dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        setState(() => _legadoSources = sources);
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              this
                                  .context
                                  .l10n
                                  .legadoImportedCount(result.sources.length),
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          importing = false;
                          errorText = error.toString();
                        });
                      }
                    },
              child: Text(context.l10n.legadoImport),
            ),
          ],
        ),
      ),
    );
    unawaited(
      Future<void>.delayed(const Duration(milliseconds: 300))
          .then((_) => controller.dispose()),
    );
  }

  Future<void> _removeLegadoSource(RegisteredLegadoSource source) async {
    final sources = await _legadoRegistry.remove(source.source.url);
    if (!mounted) return;
    setState(() => _legadoSources = sources);
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
}
