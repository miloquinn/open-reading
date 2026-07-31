// 文件说明：书库独立配置页，收纳布局和书籍打开动画设置。
// 技术要点：Provider 状态联动、响应式选择控件。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:xxread/l10n/app_localizations.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_transitions.dart';
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
              const SizedBox(height: 16),
              _SettingsSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.settingsLibraryOpenAnimationTitle,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.settingsLibraryOpenAnimationSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<LibraryBookOpenAnimation>(
                      groupValue: settings.libraryBookOpenAnimation,
                      onChanged: (value) {
                        if (value == null) return;
                        unawaited(settings.setLibraryBookOpenAnimation(value));
                      },
                      child: Column(
                        children: [
                          for (final animation
                              in LibraryBookOpenAnimation.values)
                            RadioListTile<LibraryBookOpenAnimation>(
                              key: ValueKey(
                                'settings-library-open-animation-${animation.name}',
                              ),
                              contentPadding: EdgeInsets.zero,
                              dense: true,
                              value: animation,
                              title: Text(_animationTitle(l10n, animation)),
                              subtitle: Text(
                                _animationSubtitle(l10n, animation),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _animationTitle(
    AppLocalizations l10n,
    LibraryBookOpenAnimation animation,
  ) => switch (animation) {
    LibraryBookOpenAnimation.classicCover =>
      l10n.settingsLibraryOpenAnimationClassicCover,
    LibraryBookOpenAnimation.minimalFade =>
      l10n.settingsLibraryOpenAnimationMinimal,
    LibraryBookOpenAnimation.paperRise =>
      l10n.settingsLibraryOpenAnimationPaperRise,
    LibraryBookOpenAnimation.pageSlide =>
      l10n.settingsLibraryOpenAnimationPageSlide,
    LibraryBookOpenAnimation.bookSpread =>
      l10n.settingsLibraryOpenAnimationBookSpread,
  };

  String _animationSubtitle(
    AppLocalizations l10n,
    LibraryBookOpenAnimation animation,
  ) => switch (animation) {
    LibraryBookOpenAnimation.classicCover =>
      l10n.settingsLibraryOpenAnimationClassicCoverHint,
    LibraryBookOpenAnimation.minimalFade =>
      l10n.settingsLibraryOpenAnimationMinimalHint,
    LibraryBookOpenAnimation.paperRise =>
      l10n.settingsLibraryOpenAnimationPaperRiseHint,
    LibraryBookOpenAnimation.pageSlide =>
      l10n.settingsLibraryOpenAnimationPageSlideHint,
    LibraryBookOpenAnimation.bookSpread =>
      l10n.settingsLibraryOpenAnimationBookSpreadHint,
  };
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
