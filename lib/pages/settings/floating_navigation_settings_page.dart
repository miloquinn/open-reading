// 文件说明：悬浮导航栏配置页，提供实时预览、显示模式与入口排序。
// 技术要点：稳定目的地 ID、ReorderableListView、SharedPreferences 状态联动。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'package:xxread/models/home_navigation_destination.dart';
import 'package:xxread/pages/home/home_mobile_chrome.dart';
import 'package:xxread/pages/home/widgets/home_bounce_navigation_item.dart';
import 'package:xxread/pages/home/widgets/home_navigation_item.dart';
import 'package:xxread/services/core/app_settings_service.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/utils/ui_style.dart';
import 'package:xxread/widgets/side_toast.dart';

class FloatingNavigationSettingsPage extends StatelessWidget {
  const FloatingNavigationSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsFloatingNavigationTitle)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: Consumer<AppSettingsNotifier>(
          builder: (context, settings, _) => ReorderableListView.builder(
            key: const ValueKey('floating-navigation-order-list'),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            buildDefaultDragHandles: false,
            itemCount: settings.homeNavigationOrder.length,
            onReorderStart: (_) => HapticFeedback.mediumImpact(),
            onReorderItem: (oldIndex, newIndex) => _reorder(
              settings: settings,
              oldIndex: oldIndex,
              newIndex: newIndex,
            ),
            proxyDecorator: (child, _, animation) => AnimatedBuilder(
              animation: animation,
              builder: (context, _) => Material(
                color: Colors.transparent,
                elevation: 10 * animation.value,
                borderRadius: BorderRadius.circular(18),
                child: child,
              ),
            ),
            header: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionLabel(label: l10n.floatingNavigationPreviewTitle),
                const SizedBox(height: 10),
                _NavigationPreview(settings: settings),
                const SizedBox(height: 24),
                _SectionLabel(label: l10n.floatingNavigationSizeTitle),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    key: const ValueKey('floating-navigation-size-mode'),
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.auto_awesome_outlined),
                        label: Text(l10n.floatingNavigationSizeAutomatic),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.tune_rounded),
                        label: Text(l10n.floatingNavigationSizeCustom),
                      ),
                    ],
                    selected: {settings.customizeFloatingNavigationSize},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      unawaited(
                        settings.setCustomizeFloatingNavigationSize(
                          selection.first,
                        ),
                      );
                    },
                  ),
                ),
                if (settings.customizeFloatingNavigationSize) ...[
                  const SizedBox(height: 14),
                  _NavigationSizeSlider(
                    sliderKey: const ValueKey(
                      'floating-navigation-height-slider',
                    ),
                    icon: Icons.height_rounded,
                    label: l10n.floatingNavigationHeightLabel,
                    value: settings.floatingNavigationHeight,
                    min: kHomeMobileFloatingNavMinHeight,
                    max: kHomeMobileFloatingNavMaxHeight,
                    onChanged: settings.setFloatingNavigationHeight,
                  ),
                  _NavigationSizeSlider(
                    sliderKey: const ValueKey(
                      'floating-navigation-margin-slider',
                    ),
                    icon: Icons.horizontal_distribute_rounded,
                    label: l10n.floatingNavigationSideMarginLabel,
                    value: settings.floatingNavigationHorizontalMargin,
                    min: kHomeMobileFloatingNavMinHorizontalMargin,
                    max: kHomeMobileFloatingNavMaxHorizontalMargin,
                    onChanged: settings.setFloatingNavigationHorizontalMargin,
                  ),
                ],
                const SizedBox(height: 24),
                _SectionLabel(label: l10n.floatingNavigationDisplayModeTitle),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<bool>(
                    key: const ValueKey('floating-navigation-display-mode'),
                    showSelectedIcon: false,
                    expandedInsets: EdgeInsets.zero,
                    segments: [
                      ButtonSegment(
                        value: false,
                        icon: const Icon(Icons.apps_rounded),
                        label: Text(l10n.floatingNavigationIconsOnly),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: const Icon(Icons.label_outline_rounded),
                        label: Text(l10n.floatingNavigationIconsAndLabels),
                      ),
                    ],
                    selected: {settings.showNavigationLabels},
                    onSelectionChanged: (selection) {
                      if (selection.isEmpty) return;
                      unawaited(
                        settings.setShowNavigationLabels(selection.first),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),
                _SectionLabel(label: l10n.floatingNavigationOrderTitle),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.drag_indicator_rounded,
                      size: 17,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.floatingNavigationOrderHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.visibility_off_outlined,
                      size: 17,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        l10n.floatingNavigationVisibilityHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.sync_alt_rounded,
                        size: 17,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          l10n.floatingNavigationSyncHint,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                height: 1.4,
                              ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    key: const ValueKey('floating-navigation-reset-order'),
                    onPressed: () => unawaited(_reset(context, settings)),
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: Text(l10n.floatingNavigationResetOrder),
                  ),
                ],
              ),
            ),
            itemBuilder: (context, index) {
              final destination = settings.homeNavigationOrder[index];
              return Padding(
                key: ValueKey(
                  'floating-navigation-order-${destination.storageId}',
                ),
                padding: const EdgeInsets.only(bottom: 10),
                child: _NavigationOrderTile(
                  destination: destination,
                  index: index,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _reorder({
    required AppSettingsNotifier settings,
    required int oldIndex,
    required int newIndex,
  }) {
    final order = List<HomeNavigationDestination>.of(
      settings.homeNavigationOrder,
    );
    final destination = order.removeAt(oldIndex);
    order.insert(newIndex, destination);
    HapticFeedback.selectionClick();
    unawaited(settings.setHomeNavigationOrder(order));
  }

  Future<void> _reset(
    BuildContext context,
    AppSettingsNotifier settings,
  ) async {
    await settings.resetHomeNavigationOrder();
    if (!context.mounted) return;
    showSideToast(
      context,
      context.l10n.floatingNavigationResetDone,
      kind: SideToastKind.success,
    );
  }
}

class _NavigationPreview extends StatelessWidget {
  const _NavigationPreview({required this.settings});

  final AppSettingsNotifier settings;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMaterial3Style =
        Theme.of(
          context,
        ).extension<UiStyleThemeExtension>()?.isMaterial3Style ??
        false;
    final visibleOrder = settings.visibleHomeNavigationOrder;
    final mediaQuery = MediaQuery.of(context);
    final dimensions = homeMobileFloatingNavDimensionsFor(
      screenWidth: mediaQuery.size.width,
      itemCount: visibleOrder.length,
      platform: Theme.of(context).platform,
      systemBottomInset: mediaQuery.viewPadding.bottom,
      customHeight: settings.customizeFloatingNavigationSize
          ? settings.floatingNavigationHeight
          : null,
      customHorizontalMargin: settings.customizeFloatingNavigationSize
          ? settings.floatingNavigationHorizontalMargin
          : null,
    );

    return Center(
      child: Container(
        key: const ValueKey('floating-navigation-live-preview'),
        width: dimensions.width,
        height: dimensions.height,
        padding: const EdgeInsets.symmetric(
          horizontal: kHomeMobileFloatingNavHorizontalPadding,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isMaterial3Style
              ? scheme.surfaceContainerHigh
              : GlassEffectConfig.chromeSurfaceColor(context),
          borderRadius: BorderRadius.circular(dimensions.height / 2),
          border: Border.all(
            color: scheme.outline.withValues(
              alpha: isMaterial3Style ? 0.18 : 0.1,
            ),
            width: 0.6,
          ),
          boxShadow: [
            BoxShadow(
              color: scheme.shadow.withValues(alpha: 0.12),
              blurRadius: 22,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: ExcludeSemantics(
          child: IgnorePointer(
            child: Row(
              children: [
                for (final destination in visibleOrder)
                  Expanded(
                    child: HomeBounceNavigationItem(
                      item: _navigationItem(context, destination),
                      isSelected:
                          destination == HomeNavigationDestination.settings,
                      showLabel: settings.showNavigationLabels,
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavigationSizeSlider extends StatelessWidget {
  const _NavigationSizeSlider({
    required this.sliderKey,
    required this.icon,
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
  });

  final Key sliderKey;
  final IconData icon;
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(icon, size: 20, color: scheme.onSurfaceVariant),
        const SizedBox(width: 8),
        SizedBox(width: 76, child: Text(label)),
        Expanded(
          child: Slider(
            key: sliderKey,
            value: value,
            min: min,
            max: max,
            divisions: (max - min).round(),
            label: value.round().toString(),
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 34,
          child: Text(
            value.round().toString(),
            textAlign: TextAlign.end,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _NavigationOrderTile extends StatelessWidget {
  const _NavigationOrderTile({required this.destination, required this.index});

  final HomeNavigationDestination destination;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final settings = context.watch<AppSettingsNotifier>();
    final visible = settings.isHomeNavigationDestinationVisible(destination);
    final lockedVisible = destination == HomeNavigationDestination.settings;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: ListTile(
        minTileHeight: 64,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: scheme.outlineVariant),
        ),
        leading: Icon(
          _destinationIcon(destination),
          color: visible
              ? scheme.primary
              : scheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        title: Text(
          _destinationLabel(context, destination),
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: visible
                ? null
                : scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Switch(
              key: ValueKey(
                'floating-navigation-visible-${destination.storageId}',
              ),
              value: visible,
              onChanged: lockedVisible
                  ? null
                  : (value) => unawaited(
                      settings.setHomeNavigationDestinationVisible(
                        destination,
                        value,
                      ),
                    ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: Icon(
                  Icons.drag_handle_rounded,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
    );
  }
}

HomeNavigationItem _navigationItem(
  BuildContext context,
  HomeNavigationDestination destination,
) {
  return HomeNavigationItem(
    destination: destination,
    icon: _destinationIcon(destination),
    selectedIcon: _destinationSelectedIcon(destination),
    label: _destinationLabel(context, destination),
    page: const SizedBox.shrink(),
  );
}

String _destinationLabel(
  BuildContext context,
  HomeNavigationDestination destination,
) {
  final l10n = context.l10n;
  return switch (destination) {
    HomeNavigationDestination.home => l10n.home,
    HomeNavigationDestination.library => l10n.library,
    HomeNavigationDestination.discover => l10n.discover,
    HomeNavigationDestination.ai => l10n.navAi,
    HomeNavigationDestination.settings => l10n.settings,
  };
}

IconData _destinationIcon(HomeNavigationDestination destination) {
  return switch (destination) {
    HomeNavigationDestination.home => Icons.home_outlined,
    HomeNavigationDestination.library => Icons.library_books_outlined,
    HomeNavigationDestination.discover => Icons.explore_outlined,
    HomeNavigationDestination.ai => Icons.auto_awesome_outlined,
    HomeNavigationDestination.settings => Icons.settings_outlined,
  };
}

IconData _destinationSelectedIcon(HomeNavigationDestination destination) {
  return switch (destination) {
    HomeNavigationDestination.home => Icons.home,
    HomeNavigationDestination.library => Icons.library_books,
    HomeNavigationDestination.discover => Icons.explore_rounded,
    HomeNavigationDestination.ai => Icons.auto_awesome,
    HomeNavigationDestination.settings => Icons.settings,
  };
}
