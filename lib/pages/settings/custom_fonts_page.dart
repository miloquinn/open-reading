// 文件说明：用户字体库管理页面，负责导入、应用、重命名与删除自定义字体。
// 技术要点：共享字体资产、App/阅读两套独立选择、删除安全回退。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:xxread/services/core/core_services.dart';
import 'package:xxread/utils/font_catalog_helper.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

enum _CustomFontAction { app, reader, both, rename, delete }

class CustomFontsPage extends StatelessWidget {
  const CustomFontsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.customFonts),
        actions: [
          Consumer<AppSettingsNotifier>(
            builder: (context, settings, _) => IconButton(
              tooltip: l10n.importFont,
              onPressed: settings.customFontImportSupported
                  ? () => unawaited(_importFont(context, settings))
                  : null,
              icon: const Icon(Icons.add_rounded),
            ),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: Consumer<AppSettingsNotifier>(
          builder: (context, settings, _) {
            final fonts = settings.customFonts;
            if (fonts.isEmpty) {
              return _EmptyFontLibrary(
                importSupported: settings.customFontImportSupported,
                onImport: () => unawaited(_importFont(context, settings)),
              );
            }
            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                Text(
                  l10n.customFontsLocalOnly,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 14),
                for (final font in fonts)
                  _CustomFontCard(
                    font: font,
                    appInUse: settings.isAppFont(font.id),
                    readerInUse: settings.isReaderFont(font.id),
                    onAction: (action) => unawaited(
                      _handleAction(context, settings, font, action),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: Consumer<AppSettingsNotifier>(
        builder: (context, settings, _) => FloatingActionButton.extended(
          onPressed: settings.customFontImportSupported
              ? () => unawaited(_importFont(context, settings))
              : null,
          icon: const Icon(Icons.file_download_outlined),
          label: Text(l10n.importFont),
        ),
      ),
    );
  }

  Future<void> _importFont(
    BuildContext context,
    AppSettingsNotifier settings,
  ) async {
    final l10n = context.l10n;
    try {
      final result = await settings.importCustomFont();
      if (!context.mounted ||
          result.status == CustomFontImportStatus.cancelled) {
        return;
      }
      final message = result.status == CustomFontImportStatus.duplicate
          ? l10n.customFontAlreadyImported
          : l10n.customFontImported;
      showSideToast(
        context,
        message,
        kind: SideToastKind.success,
      );
    } on CustomFontException catch (error) {
      if (!context.mounted) return;
      showSideToast(
        context,
        _errorText(context, error),
        kind: SideToastKind.error,
      );
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    AppSettingsNotifier settings,
    FontOption font,
    _CustomFontAction action,
  ) async {
    switch (action) {
      case _CustomFontAction.app:
        await settings.setAppFontId(font.id);
        break;
      case _CustomFontAction.reader:
        await settings.setReaderFontId(font.id);
        break;
      case _CustomFontAction.both:
        await settings.setAppFontId(font.id);
        await settings.setReaderFontId(font.id);
        break;
      case _CustomFontAction.rename:
        await _renameFont(context, settings, font);
        return;
      case _CustomFontAction.delete:
        await _deleteFont(context, settings, font);
        return;
    }
    if (!context.mounted) return;
    showSideToast(
      context,
      context.l10n.customFontApplied,
      kind: SideToastKind.success,
    );
  }

  Future<void> _renameFont(
    BuildContext context,
    AppSettingsNotifier settings,
    FontOption font,
  ) async {
    final controller = TextEditingController(text: font.displayName);
    final l10n = context.l10n;
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.renameFont),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 60,
          decoration: InputDecoration(labelText: l10n.fontFamilyLabel),
          onSubmitted: (value) => Navigator.of(dialogContext).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim().isEmpty) return;
    await settings.renameCustomFont(font.id, name);
  }

  Future<void> _deleteFont(
    BuildContext context,
    AppSettingsNotifier settings,
    FontOption font,
  ) async {
    final l10n = context.l10n;
    final appInUse = settings.isAppFont(font.id);
    final readerInUse = settings.isReaderFont(font.id);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteCustomFontTitle(font.displayName ?? '')),
        content: Text(
          appInUse || readerInUse
              ? l10n.deleteCustomFontInUse
              : l10n.deleteCustomFontMessage,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(
              appInUse || readerInUse ? l10n.deleteAndReset : l10n.delete,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await settings.deleteCustomFont(font.id);
  }

  String _errorText(BuildContext context, CustomFontException error) {
    final l10n = context.l10n;
    switch (error.code) {
      case CustomFontErrorCode.unsupported:
        return l10n.customFontImportUnsupported;
      case CustomFontErrorCode.unsupportedFormat:
        return l10n.customFontUnsupportedFormat;
      case CustomFontErrorCode.invalidFont:
        return l10n.customFontInvalid;
      case CustomFontErrorCode.fileTooLarge:
        return l10n.customFontTooLarge;
      case CustomFontErrorCode.readFailed:
        return l10n.customFontReadFailed;
      case CustomFontErrorCode.loadFailed:
        return l10n.customFontLoadFailed;
      case CustomFontErrorCode.storageFailed:
        return l10n.customFontStorageFailed;
    }
  }
}

class _EmptyFontLibrary extends StatelessWidget {
  const _EmptyFontLibrary({
    required this.importSupported,
    required this.onImport,
  });

  final bool importSupported;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.font_download_outlined,
              size: 54,
              color: colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.customFontsEmpty,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              importSupported
                  ? l10n.customFontsEmptyHint
                  : l10n.customFontImportUnsupported,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: importSupported ? onImport : null,
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.importFont),
            ),
          ],
        ),
      ),
    );
  }
}

class _CustomFontCard extends StatelessWidget {
  const _CustomFontCard({
    required this.font,
    required this.appInUse,
    required this.readerInUse,
    required this.onAction,
  });

  final FontOption font;
  final bool appInUse;
  final bool readerInUse;
  final ValueChanged<_CustomFontAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    font.displayName ?? '',
                    style: TextStyle(
                      inherit: false,
                      fontFamily: font.family,
                      fontFamilyFallback: font.fallbackFamilies,
                      color: colorScheme.onSurface,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.fontPreviewText,
                    style: TextStyle(
                      inherit: false,
                      fontFamily: font.family,
                      fontFamilyFallback: font.fallbackFamilies,
                      color: colorScheme.onSurface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${font.sourceFileName} · ${_size(font.fileSize ?? 0)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                  ),
                  if (!font.isAvailable) ...[
                    const SizedBox(height: 8),
                    Text(
                      l10n.customFontUnavailable,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: colorScheme.error,
                          ),
                    ),
                  ],
                  if (appInUse || readerInUse) ...[
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        if (appInUse) Chip(label: Text(l10n.appFont)),
                        if (readerInUse) Chip(label: Text(l10n.readerFont)),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            PopupMenuButton<_CustomFontAction>(
              onSelected: onAction,
              itemBuilder: (context) => [
                if (font.isAvailable) ...[
                  PopupMenuItem(
                    value: _CustomFontAction.app,
                    child: Text(l10n.setAsAppFont),
                  ),
                  PopupMenuItem(
                    value: _CustomFontAction.reader,
                    child: Text(l10n.setAsReaderFont),
                  ),
                  PopupMenuItem(
                    value: _CustomFontAction.both,
                    child: Text(l10n.setAsBothFonts),
                  ),
                ],
                PopupMenuItem(
                  value: _CustomFontAction.rename,
                  child: Text(l10n.renameFont),
                ),
                PopupMenuItem(
                  value: _CustomFontAction.delete,
                  child: Text(l10n.delete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _size(int bytes) {
    if (bytes >= 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }
}
