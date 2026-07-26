import 'package:flutter/material.dart';

import '../core/reader/reader_tap_zones.dart';
import '../utils/localization_extension.dart';
import '../utils/reader_themes.dart';

/// 全屏点击区域编辑层。
///
/// 盖在真实阅读页上方展示九宫格与各区域当前动作，点任一格弹出
/// 动作选择面板，修改立即回传宿主；宿主负责持久化与关闭。
class ReaderTapZoneEditorOverlay extends StatelessWidget {
  const ReaderTapZoneEditorOverlay({
    super.key,
    required this.palette,
    required this.zones,
    required this.onZonesChanged,
    required this.onClose,
  });

  /// 动作选择面板按屏幕语义排序：翻页在前，章节次之，菜单和无操作在后。
  static const List<ReaderTapZoneAction> _pickerActions = [
    ReaderTapZoneAction.nextPage,
    ReaderTapZoneAction.previousPage,
    ReaderTapZoneAction.nextChapter,
    ReaderTapZoneAction.previousChapter,
    ReaderTapZoneAction.menu,
    ReaderTapZoneAction.none,
  ];

  final ReaderThemePalette palette;
  final ReaderTapZones zones;
  final ValueChanged<ReaderTapZones> onZonesChanged;
  final VoidCallback onClose;

  static String actionLabel(BuildContext context, ReaderTapZoneAction action) {
    switch (action) {
      case ReaderTapZoneAction.previousPage:
        return context.l10n.tapZonePreviousPage;
      case ReaderTapZoneAction.nextPage:
        return context.l10n.tapZoneNextPage;
      case ReaderTapZoneAction.previousChapter:
        return context.l10n.tapZonePreviousChapter;
      case ReaderTapZoneAction.nextChapter:
        return context.l10n.tapZoneNextChapter;
      case ReaderTapZoneAction.menu:
        return context.l10n.tapZoneMenu;
      case ReaderTapZoneAction.none:
        return context.l10n.tapZoneNone;
    }
  }

  Future<void> _editZone(BuildContext context, int zoneIndex) async {
    final current = zones[zoneIndex];
    final theme = palette.toThemeData(typography: Theme.of(context).textTheme);
    final selected = await showModalBottomSheet<ReaderTapZoneAction>(
      context: context,
      backgroundColor: palette.surface,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (sheetContext) => Theme(
        data: theme,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sheetContext.l10n.tapZoneChooseAction,
                  style: theme.textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                for (final action in _pickerActions)
                  ListTile(
                    key: ValueKey('tap-zone-action-${action.name}'),
                    contentPadding: EdgeInsets.zero,
                    title: Text(actionLabel(sheetContext, action)),
                    trailing: action == current
                        ? Icon(Icons.check_rounded, color: palette.accent)
                        : null,
                    onTap: () => Navigator.of(sheetContext).pop(action),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    if (selected == null || selected == current) return;
    onZonesChanged(zones.withAction(zoneIndex, selected));
  }

  @override
  Widget build(BuildContext context) {
    const labelColor = Colors.white;
    final theme = Theme.of(context);
    return Material(
      key: const ValueKey('reader-tap-zone-editor'),
      color: Colors.black.withValues(alpha: 0.45),
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      context.l10n.tapZoneSettings,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: labelColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('tap-zone-editor-close'),
                    onPressed: onClose,
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).closeButtonTooltip,
                    icon: const Icon(Icons.close_rounded, color: labelColor),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Text(
                context.l10n.tapZoneMenuRequiredHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: labelColor.withValues(alpha: 0.78),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Column(
                  children: [
                    for (var row = 0; row < ReaderTapZones.rows; row++)
                      Expanded(
                        child: Row(
                          children: [
                            for (
                              var column = 0;
                              column < ReaderTapZones.columns;
                              column++
                            )
                              Expanded(
                                child: _buildZoneCell(
                                  context,
                                  row * ReaderTapZones.columns + column,
                                ),
                              ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton.icon(
                key: const ValueKey('tap-zone-editor-reset'),
                onPressed: () => onZonesChanged(ReaderTapZones.defaults),
                style: TextButton.styleFrom(foregroundColor: labelColor),
                icon: const Icon(Icons.restart_alt_rounded, size: 18),
                label: Text(context.l10n.tapZoneReset),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoneCell(BuildContext context, int zoneIndex) {
    final action = zones[zoneIndex];
    final isMenu = action == ReaderTapZoneAction.menu;
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Material(
        color: Colors.white.withValues(alpha: isMenu ? 0.14 : 0.06),
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: ValueKey('tap-zone-cell-$zoneIndex'),
          onTap: () => _editZone(context, zoneIndex),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: Colors.white.withValues(alpha: isMenu ? 0.55 : 0.28),
              ),
            ),
            child: Center(
              child: Text(
                actionLabel(context, action),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
