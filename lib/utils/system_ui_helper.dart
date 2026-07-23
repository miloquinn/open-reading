// 文件说明：系统 UI 辅助工具，统一处理状态栏与导航栏样式。
// 技术要点：工具方法、Flutter。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SystemUiHelper {
  static SystemUiOverlayStyle overlayStyleForBackground(
    Color background, {
    bool transparentSystemBars = true,
  }) {
    final brightness = ThemeData.estimateBrightnessForColor(background);
    return overlayStyleForBrightness(
      brightness,
      systemBarColor: transparentSystemBars ? Colors.transparent : background,
    );
  }

  static SystemUiOverlayStyle overlayStyleForBrightness(
    Brightness backgroundBrightness, {
    Color systemBarColor = Colors.transparent,
  }) {
    final iconBrightness = backgroundBrightness == Brightness.dark
        ? Brightness.light
        : Brightness.dark;

    return SystemUiOverlayStyle(
      statusBarColor: systemBarColor,
      statusBarIconBrightness: iconBrightness,
      statusBarBrightness: backgroundBrightness,
      systemNavigationBarColor: systemBarColor,
      systemNavigationBarIconBrightness: iconBrightness,
      systemNavigationBarDividerColor: Colors.transparent,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarContrastEnforced: false,
    );
  }
}
