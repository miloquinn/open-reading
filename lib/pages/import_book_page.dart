// 文件说明：多书籍暂存与顺序导入页面。
// 技术要点：自适应布局、导入队列、单书状态、失败重试。

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xxread/pages/import_book/import_book_controller.dart';
import 'package:xxread/pages/import_book/import_book_widgets.dart';
import 'package:xxread/services/books/book_services.dart';
import 'package:xxread/services/storage/android_book_folder_registry.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/system_ui_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

class ImportBookPage extends StatefulWidget {
  const ImportBookPage({
    super.key,
    this.initialSources = const [],
  });

  final List<BookImportSource> initialSources;

  @override
  State<ImportBookPage> createState() => _ImportBookPageState();
}

class _ImportBookPageState extends State<ImportBookPage> {
  late final BookImportSourceService _sourceService;
  late final ImportBookController _controller;
  late final AndroidBookFolderRegistry _androidFolderRegistry;
  bool _isDiscovering = false;
  bool? _iCloudAvailable;
  List<AndroidBookFolder> _androidFolders = const [];

  @override
  void initState() {
    super.initState();
    _sourceService = BookImportSourceService();
    _androidFolderRegistry = AndroidBookFolderRegistry(
      sourceService: _sourceService,
    );
    _controller = ImportBookController(
      importer: BookImportService(),
      sourcePreparer: _sourceService,
    );
    _controller.addSources(widget.initialSources);
    if (!kIsWeb && Platform.isIOS) {
      unawaited(_loadICloudAvailability());
    }
    if (!kIsWeb && Platform.isAndroid) {
      unawaited(_loadAndroidFolders());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _discover(
    Future<List<BookImportSource>> Function() operation,
  ) async {
    if (_isDiscovering || _controller.isRunning) return;
    setState(() => _isDiscovering = true);
    try {
      final sources = await operation();
      if (!mounted) return;
      _controller.addSources(sources);
      if (sources.isEmpty) {
        showSideToast(context, context.l10n.importNoSupportedFiles);
      }
    } catch (error) {
      if (mounted) {
        showSideToast(
          context,
          context.l10n.importFailedWithError(error.toString()),
        );
      }
    } finally {
      if (mounted) setState(() => _isDiscovering = false);
    }
  }

  Future<void> _requestExit() async {
    if (_controller.isRunning) return;
    Navigator.of(context).pop(_controller.succeededCount > 0);
  }

  Future<void> _loadICloudAvailability() async {
    try {
      final available = await _sourceService.isICloudAvailable();
      if (mounted) setState(() => _iCloudAvailable = available);
    } catch (_) {
      if (mounted) setState(() => _iCloudAvailable = false);
    }
  }

  Future<void> _loadAndroidFolders() async {
    try {
      final folders = await _androidFolderRegistry.registeredDirectories();
      if (mounted) setState(() => _androidFolders = folders);
    } catch (_) {
      if (mounted) setState(() => _androidFolders = const []);
    }
  }

  Future<void> _pickAndroidFolder() async {
    await _discover(_androidFolderRegistry.pickAndScan);
    await _loadAndroidFolders();
  }

  Future<void> _removeAndroidFolder(AndroidBookFolder folder) async {
    await _androidFolderRegistry.removeDirectory(folder.treeUri);
    await _loadAndroidFolders();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final mediaQuery = _sanitizedMediaQuery(MediaQuery.of(context));
    final overlayStyle = SystemUiHelper.overlayStyleForBrightness(
      theme.brightness,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: MediaQuery(
        data: mediaQuery,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            return PopScope(
              canPop: !_controller.isRunning,
              onPopInvokedWithResult: (didPop, _) {
                if (!didPop && !_controller.isRunning) {
                  unawaited(_requestExit());
                }
              },
              child: Scaffold(
                // This page has no text input. File pickers on a few Android
                // variants can return stale keyboard/window insets, so the page
                // owns a stable safe-area layout instead of using Scaffold's
                // bottomNavigationBar slot.
                resizeToAvoidBottomInset: false,
                backgroundColor: scheme.surface,
                body: SafeArea(
                  bottom: false,
                  child: Column(
                    children: [
                      _buildPageHeader(),
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth >= 840) {
                              return _buildWideLayout();
                            }
                            return _buildCompactLayout();
                          },
                        ),
                      ),
                      if (_buildBottomBar() case final bottomBar?) bottomBar,
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  MediaQueryData _sanitizedMediaQuery(MediaQueryData mediaQuery) {
    double clampInset(double value, double maximum) =>
        math.min(math.max(value, 0), maximum);

    EdgeInsets clampPadding(EdgeInsets padding) => EdgeInsets.fromLTRB(
          clampInset(padding.left, 96),
          clampInset(padding.top, 96),
          clampInset(padding.right, 96),
          clampInset(padding.bottom, 64),
        );

    return mediaQuery.copyWith(
      padding: clampPadding(mediaQuery.padding),
      viewPadding: clampPadding(mediaQuery.viewPadding),
      viewInsets: EdgeInsets.zero,
    );
  }

  Widget _buildPageHeader() {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      key: const ValueKey('import-page-header'),
      height: 64,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
            onPressed: _controller.isRunning ? null : _requestExit,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              context.l10n.importBooks,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 330,
            child: SingleChildScrollView(child: _buildSourcePanel()),
          ),
          const SizedBox(width: 28),
          Expanded(child: _buildQueuePane()),
        ],
      ),
    );
  }

  Widget _buildCompactLayout() {
    if (_controller.totalCount == 0) {
      return SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSourcePanel(),
            const SizedBox(height: 28),
            ImportQueueEmptyState(
              title: context.l10n.importQueueEmptyTitle,
              body: context.l10n.importQueueEmptyBody,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 12),
      child: _buildQueuePane(onAddMore: _showSourcePicker),
    );
  }

  Future<void> _showSourcePicker() async {
    if (_controller.isRunning) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: false,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return MediaQuery(
          data: _sanitizedMediaQuery(MediaQuery.of(sheetContext)),
          child: SafeArea(
            top: false,
            child: DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.78,
              minChildSize: 0.5,
              maxChildSize: 0.94,
              builder: (context, scrollController) {
                return Material(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(28),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 28),
                    children: [
                      _buildSourcePanel(dismissContext: sheetContext),
                    ],
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildSourcePanel({BuildContext? dismissContext}) {
    VoidCallback? sourceAction(VoidCallback? action) {
      if (action == null) return null;
      if (dismissContext == null) return action;
      return () {
        Navigator.of(dismissContext).pop();
        action();
      };
    }

    final actions = <ImportSourceAction>[
      ImportSourceAction(
        icon: Icons.file_open_rounded,
        label: context.l10n.importSelectFiles,
        onPressed: sourceAction(() => _discover(_sourceService.pickFiles)),
      ),
    ];
    if (!kIsWeb && Platform.isIOS) {
      actions.addAll(<ImportSourceAction>[
        ImportSourceAction(
          icon: Icons.phone_iphone_rounded,
          label: context.l10n.importIosSharedDocuments,
          onPressed: sourceAction(
            () => _discover(_sourceService.scanIosSharedDocuments),
          ),
        ),
        if (_iCloudAvailable == true)
          ImportSourceAction(
            icon: Icons.cloud_outlined,
            label: context.l10n.importICloudDrive,
            onPressed: sourceAction(
              () => _discover(_sourceService.scanICloudDocuments),
            ),
          )
        else if (_iCloudAvailable == false)
          ImportSourceAction(
            icon: Icons.cloud_off_outlined,
            label: context.l10n.importICloudUnavailable,
            onPressed: null,
          ),
      ]);
    }
    if (!kIsWeb && Platform.isAndroid) {
      actions.addAll(<ImportSourceAction>[
        ImportSourceAction(
          icon: Icons.create_new_folder_outlined,
          label: context.l10n.importAndroidFolder,
          onPressed: sourceAction(_pickAndroidFolder),
        ),
        ImportSourceAction(
          icon: Icons.folder_copy_outlined,
          label: context.l10n.importAndroidRescan,
          onPressed: sourceAction(
            () => _discover(_androidFolderRegistry.scanRegisteredDirectories),
          ),
        ),
      ]);
    }
    return ImportSourcePanel(
      title: context.l10n.importSourceTitle,
      description: context.l10n.importSourceDescription,
      actions: actions,
      isBusy: _isDiscovering,
      busyLabel: context.l10n.importScanning,
      folderEntries: _androidFolders
          .map(
            (folder) => ImportFolderEntry(
              name: folder.displayName,
              status: folder.permissionAvailable
                  ? context.l10n.importFolderPermissionAvailable
                  : context.l10n.importFolderPermissionLost,
              available: folder.permissionAvailable,
              removeTooltip: context.l10n.importRemoveFolder,
              onScan: folder.permissionAvailable
                  ? sourceAction(
                      () => _discover(
                        () => _sourceService.scanAndroidTree(folder.treeUri),
                      ),
                    )
                  : null,
              onRemove: sourceAction(() => _removeAndroidFolder(folder)),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildQueuePane({VoidCallback? onAddMore}) {
    final items = _controller.items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                context.l10n.importQueueTitle(items.length),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (_controller.completedCount > 0 && !_controller.isRunning)
              TextButton(
                onPressed: _controller.clearCompleted,
                child: Text(context.l10n.importClearCompleted),
              )
            else if (onAddMore != null)
              TextButton.icon(
                onPressed: _controller.isRunning ? null : onAddMore,
                icon: const Icon(Icons.add_rounded, size: 19),
                label: Text(context.l10n.importSelectFiles),
              ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          context.l10n.importQueueHint,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: items.isEmpty
              ? ImportQueueEmptyState(
                  title: context.l10n.importQueueEmptyTitle,
                  body: context.l10n.importQueueEmptyBody,
                )
              : ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return ImportQueueCard(
                      key: ValueKey(item.source.id),
                      item: item,
                      statusLabel: _statusLabel(item),
                      sizeLabel: _formatBytes(item.source.sizeBytes),
                      removeLabel: context.l10n.importRemove,
                      retryLabel: context.l10n.importRetry,
                      onRemove: !_controller.isRunning &&
                              (item.status == ImportQueueItemStatus.queued ||
                                  item.status == ImportQueueItemStatus.failed)
                          ? () => _controller.removeQueued(item.source.id)
                          : null,
                      onRetry: !_controller.isRunning &&
                              item.status == ImportQueueItemStatus.failed
                          ? () => _controller.retryOne(item.source.id)
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget? _buildBottomBar() {
    if (_controller.totalCount == 0) return null;
    final hasCompleted = _controller.completedCount > 0;
    final primaryLabel = _controller.isRunning
        ? context.l10n.importProcessing
        : context.l10n.importAction(_controller.queuedCount);
    return ImportBottomBar(
      summary: hasCompleted
          ? context.l10n.importSummary(
              _controller.succeededCount,
              _controller.skippedCount,
              _controller.failedCount,
            )
          : '',
      primaryLabel: primaryLabel,
      retryLabel: context.l10n.importRetryFailed(_controller.failedCount),
      doneLabel: context.l10n.importDone,
      isRunning: _controller.isRunning,
      onPrimary: _controller.isRunning
          ? () {}
          : _controller.queuedCount == 0
              ? null
              : () => _controller.start(),
      onRetry: !_controller.isRunning && _controller.failedCount > 0
          ? () => _controller.retryFailed()
          : null,
      onDone: !_controller.isRunning &&
              _controller.queuedCount == 0 &&
              _controller.completedCount > 0
          ? _requestExit
          : null,
    );
  }

  String _statusLabel(ImportQueueItem item) {
    return switch (item.status) {
      ImportQueueItemStatus.queued => context.l10n.importStatusQueued,
      ImportQueueItemStatus.preparing => context.l10n.importStatusPreparing,
      ImportQueueItemStatus.importing => switch (item.phase) {
          BookImportPhase.queued => context.l10n.importStatusQueued,
          BookImportPhase.checking => context.l10n.importStatusChecking,
          BookImportPhase.copying => context.l10n.importStatusCopying,
          BookImportPhase.analyzing => context.l10n.importStatusAnalyzing,
          BookImportPhase.saving => context.l10n.importStatusSaving,
        },
      ImportQueueItemStatus.imported => context.l10n.importStatusImported,
      ImportQueueItemStatus.skipped => context.l10n.importStatusSkipped,
      ImportQueueItemStatus.failed => context.l10n.importStatusFailed,
    };
  }

  String _formatBytes(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    final kilobytes = bytes / 1024;
    if (kilobytes < 1024) return '${kilobytes.toStringAsFixed(1)} KB';
    return '${(kilobytes / 1024).toStringAsFixed(1)} MB';
  }
}
