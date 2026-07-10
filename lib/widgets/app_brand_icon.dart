// 文件说明：应用品牌图标组件，统一渲染开元阅读的品牌标识。
// 技术要点：Flutter UI。

import 'package:flutter/material.dart';

const String kAppBrandIconAsset = 'assets/images/app_icon.png';

class AppBrandIcon extends StatelessWidget {
  const AppBrandIcon({
    super.key,
    required this.size,
    this.borderRadius = 12,
    this.padding = EdgeInsets.zero,
    this.backgroundColor,
    this.border,
    this.boxShadow,
    this.fit = BoxFit.cover,
  });

  final double size;
  final double borderRadius;
  final EdgeInsets padding;
  final Color? backgroundColor;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        border: border,
        boxShadow: boxShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius - padding.left / 2),
        child: Image.asset(
          kAppBrandIconAsset,
          fit: fit,
          errorBuilder: (context, error, stackTrace) {
            return ColoredBox(
              color:
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              child: Icon(
                Icons.auto_stories_rounded,
                color: Theme.of(context).colorScheme.primary,
                size: size * 0.52,
              ),
            );
          },
        ),
      ),
    );
  }
}
