// 文件说明：移动端首页顶部栏组件，承载品牌展示与顶部操作入口。
// 技术要点：Flutter UI、渲染层。

import 'dart:ui';

import 'package:flutter/material.dart';

import '../../utils/glass_config.dart';
import '../../utils/ui_style.dart';
import '../home_layout_constants.dart';

/// 手机首页顶部毛玻璃标题栏。
///
/// 只负责显示标题和视觉样式，不处理页面业务逻辑。
class HomeMobileTopBarWidget extends StatelessWidget {
  final String title;
  final Widget? trailing;
  final double titleFontSize;
  final FontWeight titleFontWeight;
  final double horizontalPadding;

  const HomeMobileTopBarWidget({
    super.key,
    required this.title,
    this.trailing,
    this.titleFontSize = 34,
    this.titleFontWeight = FontWeight.w700,
    this.horizontalPadding = 16,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final metrics = HomeMobileChromeScope.of(context);
    final isMaterial3Style = Theme.of(context)
            .extension<UiStyleThemeExtension>()
            ?.isMaterial3Style ??
        false;
    final useBlur = !isMaterial3Style && !GlassEffectConfig.shouldDisableBlur;
    final content = Container(
      height: metrics.topBarHeight,
      decoration: BoxDecoration(
        color: isMaterial3Style
            ? scheme.surfaceContainerHigh
            : GlassEffectConfig.surfaceColor(
                context,
                opacity: GlassEffectConfig.appBarOpacity,
              ),
        border: Border(
          bottom: BorderSide(
            color:
                scheme.outline.withValues(alpha: isMaterial3Style ? 0.24 : 0.2),
            width: isMaterial3Style ? 0.7 : 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          horizontalPadding,
          metrics.systemTopInset + 8,
          horizontalPadding,
          8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: titleFontWeight,
                  color: scheme.onSurface,
                  height: 1.0,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );

    return ClipRRect(
      child: useBlur
          ? BackdropFilter(
              enabled: useBlur,
              filter: ImageFilter.blur(
                sigmaX: GlassEffectConfig.appBarBlur,
                sigmaY: GlassEffectConfig.appBarBlur,
              ),
              child: content,
            )
          : content,
    );
  }
}
