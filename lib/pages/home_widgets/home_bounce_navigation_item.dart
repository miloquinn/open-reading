// 文件说明：首页底部导航动画组件，为导航项提供弹跳反馈。
// 技术要点：Flutter UI。

import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'home_navigation_item.dart';
import '../../utils/ui_style.dart';

/// 底部导航单个按钮（带按压回弹动效）。
class HomeBounceNavigationItem extends StatefulWidget {
  final HomeNavigationItem item;
  final bool isSelected;
  final bool showLabel;
  final VoidCallback onTap;

  const HomeBounceNavigationItem({
    super.key,
    required this.item,
    required this.isSelected,
    this.showLabel = false,
    required this.onTap,
  });

  @override
  State<HomeBounceNavigationItem> createState() =>
      _HomeBounceNavigationItemState();
}

class _HomeBounceNavigationItemState extends State<HomeBounceNavigationItem>
    with TickerProviderStateMixin {
  static const _selectionDuration = Duration(milliseconds: 260);
  static const _deselectionDuration = Duration(milliseconds: 180);
  static const _labelModeDuration = Duration(milliseconds: 220);
  static const _pressDuration = Duration(milliseconds: 120);
  static const _iconSize = 28.0;

  late final AnimationController _pressController;
  late final AnimationController _selectionController;
  late final AnimationController _labelController;
  late final Animation<double> _pressAnimation;
  late final Listenable _combinedAnimation;

  @override
  void initState() {
    super.initState();

    _pressController = AnimationController(
      duration: _pressDuration,
      vsync: this,
    );
    _pressAnimation = CurvedAnimation(
      parent: _pressController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutCubic,
    );

    _selectionController = AnimationController(
      duration: _selectionDuration,
      reverseDuration: _deselectionDuration,
      value: widget.isSelected ? 1 : 0,
      vsync: this,
    );
    _labelController = AnimationController(
      duration: _labelModeDuration,
      value: widget.showLabel ? 1 : 0,
      vsync: this,
    );
    _combinedAnimation = Listenable.merge([
      _pressController,
      _selectionController,
      _labelController,
    ]);
  }

  @override
  void didUpdateWidget(covariant HomeBounceNavigationItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isSelected != widget.isSelected) {
      if (widget.isSelected) {
        _selectionController.animateTo(
          1,
          duration: _selectionDuration,
          curve: Curves.easeOutCubic,
        );
      } else {
        _selectionController.animateBack(
          0,
          duration: _deselectionDuration,
          curve: Curves.easeInOutCubic,
        );
      }
    }

    if (oldWidget.showLabel != widget.showLabel) {
      if (widget.showLabel) {
        _labelController.animateTo(
          1,
          duration: _labelModeDuration,
          curve: Curves.easeOutCubic,
        );
      } else {
        _labelController.animateBack(
          0,
          duration: _labelModeDuration,
          curve: Curves.easeInOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _pressController.dispose();
    _selectionController.dispose();
    _labelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMaterial3Style = Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
    final isLightTheme = scheme.brightness == Brightness.light;
    final selectedSurface = Color.lerp(
      isMaterial3Style ? scheme.surfaceContainerHighest : scheme.surface,
      scheme.primary,
      isLightTheme ? 0.13 : 0.24,
    )!;
    final selectedForeground = scheme.primary;
    final unselectedForeground = scheme.onSurface.withValues(
      alpha: isLightTheme ? 0.9 : 0.88,
    );
    final selectedBorder = scheme.primary.withValues(
      alpha: isLightTheme ? 0.08 : 0.16,
    );

    return Semantics(
      button: true,
      selected: widget.isSelected,
      label: widget.item.label,
      child: Tooltip(
        message: widget.item.label,
        excludeFromSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => _pressController.forward(),
          onTapUp: (_) => _pressController.reverse(),
          onTapCancel: () => _pressController.reverse(),
          onTap: widget.onTap,
          child: AnimatedBuilder(
            animation: _combinedAnimation,
            builder: (context, child) {
              final selection = _selectionController.value;
              final labelProgress = _labelController.value;
              final pressScale = 1 - (_pressAnimation.value * 0.06);
              final indicatorScale = 0.92 + (selection * 0.08);
              final iconScale = 0.96 + (selection * 0.04);
              final renderedIconSize = _iconSize - labelProgress;
              final iconOffsetY = (-1.25 * selection) - (8.5 * labelProgress);
              final iconColor = Color.lerp(
                unselectedForeground,
                selectedForeground,
                selection,
              )!;

              return Transform.scale(
                key: ValueKey('home-nav-press-${widget.item.label}'),
                scale: pressScale,
                child: SizedBox.expand(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final hiddenIndicatorHeight = math.min(
                        54.0,
                        math.max(0, constraints.maxHeight - 2),
                      );
                      final labeledIndicatorHeight = math.min(
                        56.0,
                        constraints.maxHeight,
                      );
                      final hiddenIndicatorInset =
                          (constraints.maxHeight - hiddenIndicatorHeight) / 2;
                      final labeledIndicatorInset =
                          (constraints.maxHeight - labeledIndicatorHeight) / 2;
                      final hiddenIndicatorWidth = math.max(
                        0,
                        constraints.maxWidth - (hiddenIndicatorInset * 2),
                      );
                      final labeledIndicatorWidth = math.max(
                        0,
                        constraints.maxWidth - (labeledIndicatorInset * 2),
                      );
                      final indicatorWidth = hiddenIndicatorWidth +
                          ((labeledIndicatorWidth - hiddenIndicatorWidth) *
                              labelProgress);
                      final indicatorHeight = hiddenIndicatorHeight +
                          ((labeledIndicatorHeight - hiddenIndicatorHeight) *
                              labelProgress);
                      final indicatorRadius = indicatorHeight / 2;

                      return Stack(
                        fit: StackFit.expand,
                        alignment: Alignment.center,
                        children: [
                          Center(
                            child: Transform.scale(
                              key: ValueKey(
                                'home-nav-indicator-scale-${widget.item.label}',
                              ),
                              scale: indicatorScale,
                              child: SizedBox(
                                key: ValueKey(
                                  'home-nav-indicator-${widget.item.label}',
                                ),
                                width: indicatorWidth,
                                height: indicatorHeight,
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    color: Color.lerp(
                                      selectedSurface.withValues(alpha: 0),
                                      selectedSurface,
                                      selection,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                      indicatorRadius,
                                    ),
                                    border: Border.all(
                                      color: Color.lerp(
                                        selectedBorder.withValues(alpha: 0),
                                        selectedBorder,
                                        selection,
                                      )!,
                                      width: 0.8,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(0, iconOffsetY),
                            child: Transform.scale(
                              scale: iconScale,
                              child: SizedBox.square(
                                dimension: renderedIconSize,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    Opacity(
                                      key: ValueKey(
                                        'home-nav-unselected-${widget.item.label}',
                                      ),
                                      opacity: 1 - selection,
                                      child: Icon(
                                        widget.item.icon,
                                        color: iconColor,
                                        size: renderedIconSize,
                                      ),
                                    ),
                                    Opacity(
                                      key: ValueKey(
                                        'home-nav-selected-${widget.item.label}',
                                      ),
                                      opacity: selection,
                                      child: Icon(
                                        widget.item.selectedIcon,
                                        color: iconColor,
                                        size: renderedIconSize,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          if (widget.showLabel || labelProgress > 0)
                            Positioned(
                              left: 2,
                              right: 2,
                              bottom: 5,
                              child: Opacity(
                                key: ValueKey(
                                  'home-nav-label-${widget.item.label}',
                                ),
                                opacity: labelProgress,
                                child: Transform.translate(
                                  offset: Offset(
                                    0,
                                    2 * (1 - labelProgress),
                                  ),
                                  child: ExcludeSemantics(
                                    child: Text(
                                      widget.item.label,
                                      maxLines: 1,
                                      softWrap: false,
                                      overflow: TextOverflow.fade,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: iconColor,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.lerp(
                                          FontWeight.w700,
                                          FontWeight.w800,
                                          selection,
                                        ),
                                        height: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
