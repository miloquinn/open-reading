import 'dart:async';

import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:xxread/core/reader/reader_custom_theme.dart';
import 'package:xxread/core/reader/reader_theme_order.dart';
import 'package:xxread/services/core/reader_theme_background_service.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_theme_background.dart';

import 'reader_custom_theme_page.dart';

@immutable
class ReaderCustomThemesResult {
  const ReaderCustomThemesResult({
    required this.themes,
    required this.themeOrder,
    required this.selectedThemeId,
  });

  final List<ReaderCustomTheme> themes;
  final List<String> themeOrder;
  final String? selectedThemeId;
}

class ReaderCustomThemesPage extends StatefulWidget {
  const ReaderCustomThemesPage({
    super.key,
    required this.initialThemes,
    required this.initialSelectedThemeId,
    this.initialThemeOrder = const [],
    this.store = const ReaderCustomThemeStore(),
    this.orderStore = const ReaderThemeOrderStore(),
  });

  final List<ReaderCustomTheme> initialThemes;
  final String? initialSelectedThemeId;
  final List<String> initialThemeOrder;
  final ReaderCustomThemeStore store;
  final ReaderThemeOrderStore orderStore;

  @override
  State<ReaderCustomThemesPage> createState() => _ReaderCustomThemesPageState();
}

class _ReaderCustomThemesPageState extends State<ReaderCustomThemesPage> {
  final ReaderThemeBackgroundService _backgroundService =
      ReaderThemeBackgroundService();
  late final List<ReaderCustomTheme> _themes;
  late final List<String> _themeOrder;
  late String? _selectedThemeId;
  bool _allowPop = false;
  Future<void> _persistQueue = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _themes = [...widget.initialThemes];
    _themeOrder = ReaderThemes.resolveThemeOrder(
      widget.initialThemeOrder,
      _themes,
    );
    _selectedThemeId = _themeOrder.contains(widget.initialSelectedThemeId)
        ? widget.initialSelectedThemeId
        : ReaderThemes.day.id;
  }

  Future<void> _persist() {
    final snapshot = List<ReaderCustomTheme>.of(_themes);
    final orderSnapshot = List<String>.of(_themeOrder);
    _persistQueue = _persistQueue.then((_) async {
      await Future.wait<void>([
        widget.store.saveAll(snapshot),
        widget.orderStore.save(orderSnapshot),
      ]);
    });
    return _persistQueue;
  }

  Future<void> _finish() async {
    if (_allowPop || !mounted) return;
    await _persistQueue;
    if (!mounted) return;
    setState(() => _allowPop = true);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) return;
    Navigator.of(context).pop(
      ReaderCustomThemesResult(
        themes: List.unmodifiable(_themes),
        themeOrder: List.unmodifiable(_themeOrder),
        selectedThemeId: _selectedThemeId,
      ),
    );
  }

  Future<void> _addTheme() async {
    final number = _themes.length + 1;
    final draft = ReaderCustomTheme.defaults.copyWith(
      id: '${ReaderCustomTheme.themeIdPrefix}${const Uuid().v4()}',
      name: '${context.l10n.readerThemeCustom} $number',
    );
    final created = await Navigator.of(context).push<ReaderCustomTheme>(
      MaterialPageRoute(
        builder: (_) =>
            ReaderCustomThemePage(initialTheme: draft, isNewTheme: true),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _themes.add(created);
      _themeOrder.add(created.id);
      _selectedThemeId = created.id;
    });
    await _persist();
  }

  Future<void> _editTheme(ReaderCustomTheme theme) async {
    final edited = await Navigator.of(context).push<ReaderCustomTheme>(
      MaterialPageRoute(
        builder: (_) => ReaderCustomThemePage(initialTheme: theme),
      ),
    );
    if (edited == null || !mounted) return;
    final index = _themes.indexWhere((item) => item.id == theme.id);
    if (index < 0) return;
    setState(() => _themes[index] = edited);
    await _persist();
    if (theme.backgroundImagePath != edited.backgroundImagePath) {
      await _backgroundService.delete(theme.backgroundImagePath);
    }
  }

  Future<void> _deleteTheme(ReaderCustomTheme theme) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.readerCustomThemeDeleteTitle),
        content: Text(
          context.l10n.readerCustomThemeDeleteMessage(
            _displayName(theme, _themes.indexOf(theme)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(context.l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(context.l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final index = _themes.indexWhere((item) => item.id == theme.id);
    if (index < 0) return;
    final orderIndex = _themeOrder.indexOf(theme.id);
    setState(() {
      _themes.removeAt(index);
      _themeOrder.remove(theme.id);
      if (_selectedThemeId == theme.id) {
        if (_themeOrder.isEmpty) {
          _selectedThemeId = null;
        } else {
          _selectedThemeId =
              _themeOrder[orderIndex.clamp(0, _themeOrder.length - 1)];
        }
      }
    });
    await _persist();
    await _backgroundService.delete(theme.backgroundImagePath);
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final themeId = _themeOrder.removeAt(oldIndex);
      _themeOrder.insert(newIndex, themeId);
      final customThemesById = {for (final theme in _themes) theme.id: theme};
      _themes
        ..clear()
        ..addAll(
          _themeOrder
              .map((id) => customThemesById[id])
              .whereType<ReaderCustomTheme>(),
        );
    });
    unawaited(_persist());
  }

  String _displayName(ReaderCustomTheme theme, int index) {
    final name = theme.name.trim();
    return name.isEmpty
        ? '${context.l10n.readerThemeCustom} ${index + 1}'
        : name;
  }

  String _displayNameForId(String themeId) {
    final customTheme = _customThemeById(themeId);
    if (customTheme != null) {
      return _displayName(customTheme, _themes.indexOf(customTheme));
    }
    return switch (themeId) {
      ReaderThemes.systemId => context.l10n.readerThemeFollowSystem,
      'mist' => context.l10n.readerThemeMist,
      'green' => context.l10n.readerThemeGreen,
      'rose' => context.l10n.readerThemeRose,
      'navy' => context.l10n.readerThemeNavy,
      'night' => context.l10n.readerThemeNight,
      'pureBlack' => context.l10n.readerThemePureBlack,
      'parchment' => context.l10n.readerThemeParchment,
      _ => context.l10n.readerThemeDay,
    };
  }

  ReaderCustomTheme? _customThemeById(String themeId) {
    for (final theme in _themes) {
      if (theme.id == themeId) return theme;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_finish());
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: _finish,
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
          title: Text(context.l10n.readerThemeTitle),
          actions: [
            IconButton(
              key: const ValueKey('add-custom-reader-theme'),
              onPressed: _addTheme,
              icon: const Icon(Icons.add_rounded),
              tooltip: context.l10n.readerCustomThemeAdd,
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 10),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: colors.secondaryContainer.withValues(alpha: 0.52),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.drag_indicator_rounded,
                        color: colors.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          context.l10n.readerCustomThemeReorderHint,
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(
                                color: colors.onSecondaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(18, 4, 18, 120),
                  buildDefaultDragHandles: false,
                  itemCount: _themeOrder.length,
                  onReorderItem: _reorder,
                  proxyDecorator: (child, _, animation) => AnimatedBuilder(
                    animation: animation,
                    builder: (context, _) => Material(
                      color: Colors.transparent,
                      elevation: 12 * animation.value,
                      borderRadius: BorderRadius.circular(22),
                      child: child,
                    ),
                  ),
                  itemBuilder: (context, index) {
                    final themeId = _themeOrder[index];
                    final customTheme = _customThemeById(themeId);
                    final palette = customTheme == null
                        ? ReaderThemes.byId(themeId)
                        : ReaderThemes.fromCustomTheme(customTheme);
                    return Padding(
                      key: ValueKey('theme-order-list-$themeId'),
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _ThemeManagementCard(
                        palette: palette,
                        customTheme: customTheme,
                        name: _displayNameForId(themeId),
                        selected: _selectedThemeId == themeId,
                        dragHandle: ReorderableDragStartListener(
                          index: index,
                          child: const Padding(
                            padding: EdgeInsets.all(10),
                            child: Icon(Icons.drag_handle_rounded),
                          ),
                        ),
                        onTap: () => setState(() => _selectedThemeId = themeId),
                        onEdit: customTheme == null
                            ? null
                            : () => _editTheme(customTheme),
                        onDelete: customTheme == null
                            ? null
                            : () => _deleteTheme(customTheme),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SafeArea(
          minimum: const EdgeInsets.fromLTRB(18, 10, 18, 14),
          child: FilledButton.icon(
            key: const ValueKey('use-selected-custom-reader-theme'),
            onPressed: _selectedThemeId == null ? null : _finish,
            icon: const Icon(Icons.auto_stories_rounded),
            label: Text(context.l10n.readerCustomThemeUse),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ThemeManagementCard extends StatelessWidget {
  const _ThemeManagementCard({
    required this.palette,
    required this.customTheme,
    required this.name,
    required this.selected,
    required this.dragHandle,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final ReaderThemePalette palette;
  final ReaderCustomTheme? customTheme;
  final String name;
  final bool selected;
  final Widget dragHandle;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final cardRadius = BorderRadius.circular(22);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: cardRadius,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 116,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: cardRadius,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: palette.shadow.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: cardRadius,
            border: Border.all(
              color: selected ? palette.accent : palette.border,
              width: selected ? 2.4 : 1,
            ),
          ),
          child: ReaderThemeBackground(
            palette: palette,
            child: Row(
              children: [
                Container(
                  width: 78,
                  margin: const EdgeInsets.all(10),
                  padding: const EdgeInsets.all(11),
                  decoration: BoxDecoration(
                    color: palette.controlBar.withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: palette.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aa',
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const Spacer(),
                      for (final width in [1.0, 0.74, 0.88]) ...[
                        FractionallySizedBox(
                          widthFactor: width,
                          child: Container(
                            height: 3,
                            decoration: BoxDecoration(
                              color: palette.text.withValues(alpha: 0.38),
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: palette.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (selected)
                              Icon(
                                Icons.check_circle_rounded,
                                color: palette.accent,
                                size: 21,
                              ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            if (customTheme?.hasBackgroundImage ?? false) ...[
                              Icon(
                                Icons.image_rounded,
                                color: palette.secondaryText,
                                size: 17,
                              ),
                              const SizedBox(width: 5),
                            ],
                            for (final color in [
                              palette.background,
                              palette.text,
                              palette.controlBar,
                            ])
                              Container(
                                width: 18,
                                height: 18,
                                margin: const EdgeInsets.only(right: 5),
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: palette.border),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (customTheme != null)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: onEdit,
                        icon: Icon(Icons.edit_rounded, color: palette.text),
                        tooltip: context.l10n.edit,
                      ),
                      IconButton(
                        onPressed: onDelete,
                        icon: Icon(
                          Icons.delete_outline_rounded,
                          color: palette.secondaryText,
                        ),
                        tooltip: context.l10n.delete,
                      ),
                    ],
                  ),
                IconTheme(
                  data: IconThemeData(color: palette.secondaryText),
                  child: dragHandle,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
