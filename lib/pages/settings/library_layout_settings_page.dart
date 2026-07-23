// 文件说明：书库布局独立配置页，收纳卡片/网格及网格细节设置。
// 技术要点：Provider 状态联动、响应式 SegmentedButton。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';

class LibraryLayoutSettingsPage extends StatelessWidget {
  const LibraryLayoutSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsLibraryLayoutTitle)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: Consumer<AppSettingsNotifier>(
          builder: (context, settings, _) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Text(
                l10n.settingsLibraryLayoutSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _SettingsSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<LibraryLayoutMode>(
                        key: const ValueKey('settings-library-layout-selector'),
                        showSelectedIcon: false,
                        expandedInsets: EdgeInsets.zero,
                        segments: [
                          ButtonSegment(
                            value: LibraryLayoutMode.card,
                            icon: const Icon(Icons.view_agenda_outlined),
                            label: Text(l10n.settingsLibraryLayoutCard),
                          ),
                          ButtonSegment(
                            value: LibraryLayoutMode.grid,
                            icon: const Icon(Icons.grid_view_rounded),
                            label: Text(l10n.settingsLibraryLayoutGrid),
                          ),
                        ],
                        selected: {settings.libraryLayoutMode},
                        onSelectionChanged: (selection) {
                          if (selection.isEmpty) return;
                          unawaited(
                            settings.setLibraryLayoutMode(selection.first),
                          );
                        },
                      ),
                    ),
                    if (settings.libraryLayoutMode ==
                        LibraryLayoutMode.grid) ...[
                      const SizedBox(height: 22),
                      Text(
                        l10n.settingsLibraryGridColumnsTitle,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<int>(
                          key: const ValueKey('settings-library-grid-columns'),
                          showSelectedIcon: false,
                          expandedInsets: EdgeInsets.zero,
                          segments: [
                            ButtonSegment(
                              value: 2,
                              icon: const Icon(Icons.view_column_outlined),
                              label: Text(l10n.settingsLibraryGridTwoColumns),
                            ),
                            ButtonSegment(
                              value: 3,
                              icon: const Icon(Icons.view_week_outlined),
                              label: Text(l10n.settingsLibraryGridThreeColumns),
                            ),
                          ],
                          selected: {settings.libraryGridColumns},
                          onSelectionChanged: (selection) {
                            if (selection.isEmpty) return;
                            unawaited(
                              settings.setLibraryGridColumns(selection.first),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 8),
                      SwitchListTile.adaptive(
                        key: const ValueKey(
                          'settings-library-grid-show-details',
                        ),
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          l10n.settingsLibraryGridShowDetailsTitle,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          l10n.settingsLibraryGridShowDetailsSubtitle,
                        ),
                        value: settings.libraryGridShowDetails,
                        onChanged: (value) => unawaited(
                          settings.setLibraryGridShowDetails(value),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(padding: const EdgeInsets.all(16), child: child),
    );
  }
}
