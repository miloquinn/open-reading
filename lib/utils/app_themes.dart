// 文件说明：应用主题定义文件，使用单一强调色生成完整 Material 3 色板。
// 技术要点：ColorScheme.fromSeed、历史主题配置迁移。

import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme({
    required this.seedColor,
    required this.lightColorScheme,
    required this.darkColorScheme,
  });

  final Color seedColor;
  final ColorScheme lightColorScheme;
  final ColorScheme darkColorScheme;
}

class AppThemes {
  static const Color defaultAccentColor = Color(0xFF1976D2);

  /// 设置页中的快捷强调色。任意颜色仍可通过色盘或十六进制输入选择。
  static const List<Color> accentColors = [
    Color(0xFF1976D2),
    Color(0xFF3F51B5),
    Color(0xFF6750A4),
    Color(0xFF8E24AA),
    Color(0xFFD81B60),
    Color(0xFFE53935),
    Color(0xFFF4511E),
    Color(0xFFFB8C00),
    Color(0xFFF9A825),
    Color(0xFF7CB342),
    Color(0xFF2E7D32),
    Color(0xFF00897B),
    Color(0xFF0097A7),
    Color(0xFF0288D1),
    Color(0xFF5E6C84),
    Color(0xFF795548),
    Color(0xFFB26A00),
    Color(0xFF7D5260),
  ];

  static final Map<int, String> _accentColorNames = {
    const Color(0xFF1976D2).toARGB32(): 'blue',
    const Color(0xFF3F51B5).toARGB32(): 'indigo',
    const Color(0xFF6750A4).toARGB32(): 'purple',
    const Color(0xFF8E24AA).toARGB32(): 'deepPurple',
    const Color(0xFFD81B60).toARGB32(): 'pink',
    const Color(0xFFE53935).toARGB32(): 'red',
    const Color(0xFFF4511E).toARGB32(): 'deepOrange',
    const Color(0xFFFB8C00).toARGB32(): 'orange',
    const Color(0xFFF9A825).toARGB32(): 'amber',
    const Color(0xFF7CB342).toARGB32(): 'lightGreen',
    const Color(0xFF2E7D32).toARGB32(): 'green',
    const Color(0xFF00897B).toARGB32(): 'teal',
    const Color(0xFF0097A7).toARGB32(): 'cyan',
    const Color(0xFF0288D1).toARGB32(): 'lightBlue',
    const Color(0xFF5E6C84).toARGB32(): 'grey',
    const Color(0xFF795548).toARGB32(): 'brown',
    const Color(0xFFB26A00).toARGB32(): 'ochre',
    const Color(0xFF7D5260).toARGB32(): 'rosewood',
  };

  static AppTheme fromAccentColor(Color seedColor) {
    return AppTheme(
      seedColor: seedColor,
      lightColorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.light,
      ),
      darkColorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: Brightness.dark,
      ),
    );
  }

  /// 保留旧方法名，避免一次性破坏仍在使用的调用方。
  static AppTheme createCustomTheme(Color seedColor) =>
      fromAccentColor(seedColor);

  /// 将旧版“应用主题”名称折叠为统一强调色，用于首次升级迁移。
  static Color accentColorForLegacyTheme(String? name) {
    return switch (name) {
      'purple' => const Color(0xFF6A4C93),
      'green' => const Color(0xFF2E7D32),
      'orange' => const Color(0xFFFF6F00),
      'red' => const Color(0xFFD32F2F),
      _ => defaultAccentColor,
    };
  }

  static String getAccentColorName(Color color) {
    return _accentColorNames[color.toARGB32()] ?? 'custom';
  }
}
