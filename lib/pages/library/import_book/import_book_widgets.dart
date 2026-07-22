// 文件说明：书籍导入页的来源区、队列卡片、空状态和底部操作栏。
// 技术要点：Material 3、自适应布局、状态语义与进度反馈。

import 'package:flutter/material.dart';
import 'package:xxread/services/books/book_import_translator.dart';

import 'import_book_controller.dart';

class ImportSourceAction {
  const ImportSourceAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
}

class ImportFolderEntry {
  const ImportFolderEntry({
    required this.name,
    required this.status,
    required this.available,
    required this.removeTooltip,
    this.onScan,
    this.onRemove,
  });

  final String name;
  final String status;
  final bool available;
  final String removeTooltip;
  final VoidCallback? onScan;
  final VoidCallback? onRemove;
}

class ImportSourcePanel extends StatelessWidget {
  const ImportSourcePanel({
    super.key,
    required this.title,
    required this.description,
    required this.actions,
    required this.isBusy,
    required this.busyLabel,
    this.folderEntries = const [],
  });

  final String title;
  final String description;
  final List<ImportSourceAction> actions;
  final bool isBusy;
  final String busyLabel;
  final List<ImportFolderEntry> folderEntries;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.library_add_rounded,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 6),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            for (var index = 0; index < actions.length; index++) ...[
              SizedBox(
                width: double.infinity,
                child: index == 0
                    ? FilledButton.icon(
                        onPressed: isBusy ? null : actions[index].onPressed,
                        icon: Icon(actions[index].icon),
                        label: Text(actions[index].label),
                      )
                    : OutlinedButton.icon(
                        onPressed: isBusy ? null : actions[index].onPressed,
                        icon: Icon(actions[index].icon),
                        label: Text(actions[index].label),
                      ),
              ),
              if (index != actions.length - 1) const SizedBox(height: 10),
            ],
            if (isBusy) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                busyLabel,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (folderEntries.isNotEmpty) ...[
              const SizedBox(height: 18),
              for (final entry in folderEntries) ...[
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: entry.available
                          ? scheme.outlineVariant
                          : scheme.error.withValues(alpha: 0.35),
                    ),
                  ),
                  child: ListTile(
                    dense: true,
                    leading: Icon(
                      entry.available
                          ? Icons.folder_rounded
                          : Icons.folder_off_outlined,
                      color: entry.available ? scheme.primary : scheme.error,
                    ),
                    title: Text(
                      entry.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(entry.status),
                    onTap: entry.available ? entry.onScan : null,
                    trailing: entry.onRemove == null
                        ? null
                        : IconButton(
                            tooltip: entry.removeTooltip,
                            onPressed: entry.onRemove,
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                  ),
                ),
                if (entry != folderEntries.last) const SizedBox(height: 8),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class ImportQueueCard extends StatelessWidget {
  const ImportQueueCard({
    super.key,
    required this.item,
    required this.statusLabel,
    required this.sizeLabel,
    required this.removeLabel,
    required this.retryLabel,
    this.onRemove,
    this.onRetry,
  });

  final ImportQueueItem item;
  final String statusLabel;
  final String sizeLabel;
  final String removeLabel;
  final String retryLabel;
  final VoidCallback? onRemove;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final visual = _statusVisual(scheme, item.status);
    final showProgress =
        item.status == ImportQueueItemStatus.preparing ||
        item.status == ImportQueueItemStatus.importing;

    return Semantics(
      label: '${item.source.displayName}, $statusLabel',
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: item.status == ImportQueueItemStatus.failed
                ? scheme.error.withValues(alpha: 0.35)
                : scheme.outlineVariant.withValues(alpha: 0.55),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 50,
                decoration: BoxDecoration(
                  color: visual.background,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(visual.icon, color: visual.foreground, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.source.displayName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      sizeLabel.isEmpty
                          ? item.source.extension.toUpperCase()
                          : '${item.source.extension.toUpperCase()} · $sizeLabel',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(visual.icon, size: 15, color: visual.foreground),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            item.failure == null
                                ? statusLabel
                                : translateBookImportFailure(
                                    context,
                                    item.failure!,
                                  ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: visual.foreground,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                    if (showProgress) ...[
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                        value: item.status == ImportQueueItemStatus.preparing
                            ? null
                            : item.progress,
                        minHeight: 5,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ],
                  ],
                ),
              ),
              if (onRetry != null)
                IconButton(
                  tooltip: retryLabel,
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                )
              else if (onRemove != null)
                IconButton(
                  tooltip: removeLabel,
                  onPressed: onRemove,
                  icon: const Icon(Icons.close_rounded),
                ),
            ],
          ),
        ),
      ),
    );
  }

  _ImportStatusVisual _statusVisual(
    ColorScheme scheme,
    ImportQueueItemStatus status,
  ) {
    return switch (status) {
      ImportQueueItemStatus.queued => _ImportStatusVisual(
        Icons.schedule_rounded,
        scheme.surfaceContainerHighest,
        scheme.onSurfaceVariant,
      ),
      ImportQueueItemStatus.preparing ||
      ImportQueueItemStatus.importing => _ImportStatusVisual(
        Icons.downloading_rounded,
        scheme.primaryContainer,
        scheme.onPrimaryContainer,
      ),
      ImportQueueItemStatus.imported => _ImportStatusVisual(
        Icons.check_circle_rounded,
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      ImportQueueItemStatus.skipped => _ImportStatusVisual(
        Icons.fast_forward_rounded,
        scheme.secondaryContainer,
        scheme.onSecondaryContainer,
      ),
      ImportQueueItemStatus.failed => _ImportStatusVisual(
        Icons.error_rounded,
        scheme.errorContainer,
        scheme.onErrorContainer,
      ),
    };
  }
}

class ImportQueueEmptyState extends StatelessWidget {
  const ImportQueueEmptyState({
    super.key,
    required this.title,
    required this.body,
  });

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.menu_book_outlined,
              size: 52,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 16),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ImportBottomBar extends StatelessWidget {
  const ImportBottomBar({
    super.key,
    required this.summary,
    required this.primaryLabel,
    required this.retryLabel,
    required this.doneLabel,
    required this.isRunning,
    this.onPrimary,
    this.onRetry,
    this.onDone,
  });

  final String summary;
  final String primaryLabel;
  final String retryLabel;
  final String doneLabel;
  final bool isRunning;
  final VoidCallback? onPrimary;
  final VoidCallback? onRetry;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('import-bottom-action-area'),
      color: scheme.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: scheme.outlineVariant.withValues(alpha: 0.65),
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Center(
            heightFactor: 1,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final buttons = _buildButtons();
                  if (constraints.maxWidth < 620) {
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (summary.isNotEmpty) ...[
                          Text(
                            summary,
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                          const SizedBox(height: 10),
                        ],
                        for (
                          var index = 0;
                          index < buttons.length;
                          index++
                        ) ...[
                          SizedBox(
                            width: double.infinity,
                            child: buttons[index],
                          ),
                          if (index != buttons.length - 1)
                            const SizedBox(height: 8),
                        ],
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(
                        child: Text(
                          summary,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ),
                      for (final button in buttons) ...[
                        const SizedBox(width: 10),
                        button,
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildButtons() {
    return <Widget>[
      if (onRetry != null)
        OutlinedButton.icon(
          onPressed: isRunning ? null : onRetry,
          icon: const Icon(Icons.refresh_rounded),
          label: Text(retryLabel),
        ),
      if (onPrimary != null)
        FilledButton.icon(
          key: const ValueKey('import-primary-action'),
          onPressed: isRunning ? null : onPrimary,
          icon: isRunning
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_done_rounded),
          label: Text(primaryLabel),
        ),
      if (onDone != null)
        FilledButton(
          key: const ValueKey('import-done-action'),
          onPressed: isRunning ? null : onDone,
          child: Text(doneLabel),
        ),
    ];
  }
}

class _ImportStatusVisual {
  const _ImportStatusVisual(this.icon, this.background, this.foreground);

  final IconData icon;
  final Color background;
  final Color foreground;
}
