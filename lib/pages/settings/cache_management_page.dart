// 文件说明：缓存管理二级页面，集中展示安全缓存占用并提供分类清理操作。
// 技术要点：白名单缓存统计、环形占用图、分类与全量清理确认。

import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:xxread/services/core/cache_management_service.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/widgets/side_toast.dart';

class CacheManagementPage extends StatefulWidget {
  const CacheManagementPage({super.key, this.cacheManager});

  final AppCacheManager? cacheManager;

  @override
  State<CacheManagementPage> createState() => _CacheManagementPageState();
}

class _CacheManagementPageState extends State<CacheManagementPage> {
  late final AppCacheManager _cacheManager;
  AppCacheUsage? _usage;
  bool _loading = true;
  final Set<AppCacheCategory> _clearingCategories = {};
  bool _clearingAll = false;

  bool get _isBusy => _clearingAll || _clearingCategories.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _cacheManager = widget.cacheManager ?? AppCacheManager();
    unawaited(_refreshUsage());
  }

  Future<void> _refreshUsage() async {
    try {
      final usage = await _cacheManager.usage();
      if (!mounted) return;
      setState(() {
        _usage = usage;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _clearCategory(AppCacheCategory category) async {
    if (_isBusy) return;
    final confirmed = await _confirmClear(title: _categoryTitle(category));
    if (!confirmed || !mounted) return;
    setState(() => _clearingCategories.add(category));
    try {
      await _cacheManager.clear(category);
      await _refreshUsage();
      if (mounted) {
        showSideToast(
          context,
          context.l10n.settingsCacheCleared,
          kind: SideToastKind.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showSideToast(
          context,
          context.l10n.settingsCacheClearFailed,
          kind: SideToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _clearingCategories.remove(category));
    }
  }

  Future<void> _clearAll() async {
    if (_isBusy) return;
    final confirmed = await _confirmClear(
      title: context.l10n.settingsCacheClearAll,
    );
    if (!confirmed || !mounted) return;
    setState(() => _clearingAll = true);
    try {
      await _cacheManager.clearAll();
      await _refreshUsage();
      if (mounted) {
        showSideToast(
          context,
          context.l10n.settingsCacheCleared,
          kind: SideToastKind.success,
        );
      }
    } catch (_) {
      if (mounted) {
        showSideToast(
          context,
          context.l10n.settingsCacheClearFailed,
          kind: SideToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _clearingAll = false);
    }
  }

  Future<bool> _confirmClear({required String title}) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(context.l10n.settingsCacheClearConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(
                  MaterialLocalizations.of(context).cancelButtonLabel,
                ),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: Text(context.l10n.settingsCacheClearAction),
              ),
            ],
          ),
        ) ??
        false;
  }

  String _categoryTitle(AppCacheCategory category) => switch (category) {
    AppCacheCategory.sourceCovers => context.l10n.settingsCacheSourceCovers,
    AppCacheCategory.sourceData => context.l10n.settingsCacheSourceData,
    AppCacheCategory.temporaryFiles => context.l10n.settingsCacheTemporaryFiles,
  };

  String _categorySubtitle(AppCacheCategory category) {
    final size = _loading
        ? context.l10n.settingsCacheCalculating
        : AppCacheManager.formatBytes(_usage?.bytesFor(category) ?? 0);
    return switch (category) {
      AppCacheCategory.sourceCovers =>
        context.l10n.settingsCacheSourceCoversSubtitle(size),
      AppCacheCategory.sourceData =>
        context.l10n.settingsCacheSourceDataSubtitle(size),
      AppCacheCategory.temporaryFiles =>
        context.l10n.settingsCacheTemporaryFilesSubtitle(size),
    };
  }

  IconData _categoryIcon(AppCacheCategory category) => switch (category) {
    AppCacheCategory.sourceCovers => Icons.image_outlined,
    AppCacheCategory.sourceData => Icons.travel_explore_outlined,
    AppCacheCategory.temporaryFiles => Icons.folder_delete_outlined,
  };

  List<Color> _categoryColors(ColorScheme scheme) => [
    scheme.primary,
    scheme.tertiary,
    scheme.secondary,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsCacheManagementTitle)),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: RefreshIndicator(
          onRefresh: _refreshUsage,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: [
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 620),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _CacheUsageCard(
                        usage: _usage,
                        loading: _loading,
                        categoryColors: _categoryColors(
                          Theme.of(context).colorScheme,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.settingsCacheSafeHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CacheActionsCard(
                        usage: _usage,
                        categoryColors: _categoryColors(
                          Theme.of(context).colorScheme,
                        ),
                        categoryTitle: _categoryTitle,
                        categorySubtitle: _categorySubtitle,
                        categoryIcon: _categoryIcon,
                        clearingCategories: _clearingCategories,
                        clearingAll: _clearingAll,
                        onClearCategory: (category) =>
                            unawaited(_clearCategory(category)),
                        onClearAll: () => unawaited(_clearAll()),
                      ),
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
}

class _CacheUsageCard extends StatelessWidget {
  const _CacheUsageCard({
    required this.usage,
    required this.loading,
    required this.categoryColors,
  });

  final AppCacheUsage? usage;
  final bool loading;
  final List<Color> categoryColors;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final totalBytes = usage?.totalBytes ?? 0;
    final chartSections = <PieChartSectionData>[];
    for (var index = 0; index < AppCacheCategory.values.length; index++) {
      final bytes = usage?.bytesFor(AppCacheCategory.values[index]) ?? 0;
      if (bytes == 0) continue;
      chartSections.add(
        PieChartSectionData(
          value: bytes.toDouble(),
          color: categoryColors[index],
          radius: 18,
          showTitle: false,
        ),
      );
    }
    if (chartSections.isEmpty) {
      chartSections.add(
        PieChartSectionData(
          value: 1,
          color: scheme.surfaceContainerHighest,
          radius: 18,
          showTitle: false,
        ),
      );
    }

    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsCacheUsageTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 210,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Semantics(
                    label: l10n.settingsCacheManagementSubtitle(
                      AppCacheManager.formatBytes(totalBytes),
                    ),
                    child: PieChart(
                      key: const ValueKey('cache-usage-chart'),
                      PieChartData(
                        sections: chartSections,
                        centerSpaceRadius: 64,
                        sectionsSpace: totalBytes == 0 ? 0 : 4,
                        startDegreeOffset: -90,
                        borderData: FlBorderData(show: false),
                        pieTouchData: PieTouchData(enabled: false),
                      ),
                      duration: const Duration(milliseconds: 380),
                      curve: Curves.easeOutCubic,
                    ),
                  ),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loading
                            ? l10n.settingsCacheCalculating
                            : AppCacheManager.formatBytes(totalBytes),
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.settingsCacheTotalUsage,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 16,
              runSpacing: 10,
              children: [
                for (
                  var index = 0;
                  index < AppCacheCategory.values.length;
                  index++
                )
                  _ChartLegendItem(
                    color: categoryColors[index],
                    label: _legendLabel(
                      context,
                      AppCacheCategory.values[index],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _legendLabel(BuildContext context, AppCacheCategory category) =>
      switch (category) {
        AppCacheCategory.sourceCovers => context.l10n.settingsCacheSourceCovers,
        AppCacheCategory.sourceData => context.l10n.settingsCacheSourceData,
        AppCacheCategory.temporaryFiles =>
          context.l10n.settingsCacheTemporaryFiles,
      };
}

class _ChartLegendItem extends StatelessWidget {
  const _ChartLegendItem({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 9,
          height: 9,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

class _CacheActionsCard extends StatelessWidget {
  const _CacheActionsCard({
    required this.usage,
    required this.categoryColors,
    required this.categoryTitle,
    required this.categorySubtitle,
    required this.categoryIcon,
    required this.clearingCategories,
    required this.clearingAll,
    required this.onClearCategory,
    required this.onClearAll,
  });

  final AppCacheUsage? usage;
  final List<Color> categoryColors;
  final String Function(AppCacheCategory category) categoryTitle;
  final String Function(AppCacheCategory category) categorySubtitle;
  final IconData Function(AppCacheCategory category) categoryIcon;
  final Set<AppCacheCategory> clearingCategories;
  final bool clearingAll;
  final ValueChanged<AppCacheCategory> onClearCategory;
  final VoidCallback onClearAll;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final busy = clearingAll || clearingCategories.isNotEmpty;
    return Material(
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (
            var index = 0;
            index < AppCacheCategory.values.length;
            index++
          ) ...[
            if (index > 0)
              Divider(height: 1, indent: 68, color: scheme.outlineVariant),
            _CacheCategoryAction(
              key: ValueKey(
                'cache-category-${AppCacheCategory.values[index].name}',
              ),
              category: AppCacheCategory.values[index],
              title: categoryTitle(AppCacheCategory.values[index]),
              subtitle: categorySubtitle(AppCacheCategory.values[index]),
              icon: categoryIcon(AppCacheCategory.values[index]),
              color: categoryColors[index],
              clearing: clearingCategories.contains(
                AppCacheCategory.values[index],
              ),
              enabled:
                  !busy &&
                  (usage?.bytesFor(AppCacheCategory.values[index]) ?? 0) > 0,
              onClear: () => onClearCategory(AppCacheCategory.values[index]),
            ),
          ],
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const ValueKey('cache-clear-all'),
                onPressed: busy || (usage?.totalBytes ?? 0) == 0
                    ? null
                    : onClearAll,
                icon: clearingAll
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_sweep_outlined),
                label: Text(context.l10n.settingsCacheClearAll),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CacheCategoryAction extends StatelessWidget {
  const _CacheCategoryAction({
    super.key,
    required this.category,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.clearing,
    required this.enabled,
    required this.onClear,
  });

  final AppCacheCategory category;
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool clearing;
  final bool enabled;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton.icon(
            key: ValueKey('cache-clear-${category.name}'),
            onPressed: enabled ? onClear : null,
            icon: clearing
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.delete_outline_rounded, size: 18),
            label: Text(context.l10n.settingsCacheClearAction),
          ),
        ],
      ),
    );
  }
}
