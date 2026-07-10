// 文件说明：首页底部导航动画组件，为导航项提供弹跳反馈。
// 技术要点：Flutter UI。

import 'package:flutter/material.dart';

import 'home_navigation_item.dart';
import '../../utils/ui_style.dart';

/// 底部导航单个按钮（带按压回弹动效）。
class HomeBounceNavigationItem extends StatefulWidget {
  final HomeNavigationItem item;
  final bool isSelected;
  final VoidCallback onTap;

  const HomeBounceNavigationItem({
    super.key,
    required this.item,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<HomeBounceNavigationItem> createState() =>
      _HomeBounceNavigationItemState();
}

class _HomeBounceNavigationItemState extends State<HomeBounceNavigationItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 120),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuint,
      ),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isMaterial3Style = Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCirc,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: widget.isSelected
                    ? (isMaterial3Style
                        ? scheme.primaryContainer
                        : scheme.primary.withValues(alpha: 0.15))
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(28),
                border: isMaterial3Style
                    ? Border.all(
                        color: widget.isSelected
                            ? scheme.primary.withValues(alpha: 0.32)
                            : Colors.transparent,
                        width: 0.8,
                      )
                    : null,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.isSelected
                        ? widget.item.selectedIcon
                        : widget.item.icon,
                    color: widget.isSelected
                        ? (isMaterial3Style
                            ? scheme.onPrimaryContainer
                            : scheme.primary)
                        : scheme.onSurface.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  const SizedBox(height: 2),
                  AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 150),
                    curve: Curves.easeOutCirc,
                    style: TextStyle(
                      fontSize: widget.isSelected ? 9 : 8.5,
                      fontWeight:
                          widget.isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: widget.isSelected
                          ? (isMaterial3Style
                              ? scheme.onPrimaryContainer
                              : scheme.primary)
                          : scheme.onSurface.withValues(alpha: 0.6),
                    ),
                    child: Text(
                      widget.item.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
