// 文件说明：应用主题定义文件，集中维护主题色板与 ThemeData 生成逻辑。
// 技术要点：工具方法、Flutter。

import 'package:flutter/material.dart';

// 应用主题数据结构（与阅读主题分离）
class AppTheme {
  final String name;
  final String displayName;
  final ColorScheme lightColorScheme;
  final ColorScheme darkColorScheme;

  const AppTheme({
    required this.name,
    required this.displayName,
    required this.lightColorScheme,
    required this.darkColorScheme,
  });
}

// 预设应用主题
class AppThemes {
  // 默认蓝色主题
  static const AppTheme blueTheme = AppTheme(
    name: 'blue',
    displayName: 'blue',
    lightColorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF1976D2),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFD1E4FF),
      onPrimaryContainer: Color(0xFF001D36),
      secondary: Color(0xFF535F70),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFD7E3F7),
      onSecondaryContainer: Color(0xFF101C2B),
      tertiary: Color(0xFF6B5B92),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFF2DAFF),
      onTertiaryContainer: Color(0xFF251431),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFDFCFF),
      onSurface: Color(0xFF1A1C1E),
      surfaceContainerHighest: Color(0xFFE3E2E6),
      onSurfaceVariant: Color(0xFF44474F),
      outline: Color(0xFF74777F),
      outlineVariant: Color(0xFFC4C7CF),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF2F3033),
      onInverseSurface: Color(0xFFF1F0F4),
      inversePrimary: Color(0xFF9ECAFF),
      surfaceTint: Color(0xFF1976D2),
    ),
    darkColorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF9ECAFF),
      onPrimary: Color(0xFF003258),
      primaryContainer: Color(0xFF004881),
      onPrimaryContainer: Color(0xFFD1E4FF),
      secondary: Color(0xFFBBC7DB),
      onSecondary: Color(0xFF253140),
      secondaryContainer: Color(0xFF3B4858),
      onSecondaryContainer: Color(0xFFD7E3F7),
      tertiary: Color(0xFFD6BEE4),
      onTertiary: Color(0xFF3B2948),
      tertiaryContainer: Color(0xFF523F6F),
      onTertiaryContainer: Color(0xFFF2DAFF),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF111318),
      onSurface: Color(0xFFE3E2E6),
      surfaceContainerHighest: Color(0xFF44474F),
      onSurfaceVariant: Color(0xFFC4C7CF),
      outline: Color(0xFF8E9099),
      outlineVariant: Color(0xFF44474F),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE3E2E6),
      onInverseSurface: Color(0xFF2F3033),
      inversePrimary: Color(0xFF1976D2),
      surfaceTint: Color(0xFF9ECAFF),
    ),
  );

  // 紫色主题
  static const AppTheme purpleTheme = AppTheme(
    name: 'purple',
    displayName: 'purple',
    lightColorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF6A4C93),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFEDDBFF),
      onPrimaryContainer: Color(0xFF22005D),
      secondary: Color(0xFF625B71),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFE8DEF8),
      onSecondaryContainer: Color(0xFF1D192B),
      tertiary: Color(0xFF7D5260),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFFD8E4),
      onTertiaryContainer: Color(0xFF31111D),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFEF7FF),
      onSurface: Color(0xFF1D1B20),
      surfaceContainerHighest: Color(0xFFE6E0E9),
      onSurfaceVariant: Color(0xFF49454F),
      outline: Color(0xFF79747E),
      outlineVariant: Color(0xFFCAC4D0),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF322F35),
      onInverseSurface: Color(0xFFF5EFF7),
      inversePrimary: Color(0xFFD0BCFF),
      surfaceTint: Color(0xFF6A4C93),
    ),
    darkColorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFD0BCFF),
      onPrimary: Color(0xFF381E72),
      primaryContainer: Color(0xFF4F378B),
      onPrimaryContainer: Color(0xFFEDDBFF),
      secondary: Color(0xFFCCC2DC),
      onSecondary: Color(0xFF332D41),
      secondaryContainer: Color(0xFF4A4458),
      onSecondaryContainer: Color(0xFFE8DEF8),
      tertiary: Color(0xFFEFB8C8),
      onTertiary: Color(0xFF492532),
      tertiaryContainer: Color(0xFF633B48),
      onTertiaryContainer: Color(0xFFFFD8E4),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF141218),
      onSurface: Color(0xFFE6E0E9),
      surfaceContainerHighest: Color(0xFF49454F),
      onSurfaceVariant: Color(0xFFCAC4D0),
      outline: Color(0xFF938F99),
      outlineVariant: Color(0xFF49454F),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE6E0E9),
      onInverseSurface: Color(0xFF322F35),
      inversePrimary: Color(0xFF6A4C93),
      surfaceTint: Color(0xFFD0BCFF),
    ),
  );

  // 绿色主题
  static const AppTheme greenTheme = AppTheme(
    name: 'green',
    displayName: 'green',
    lightColorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFF2E7D32),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFA8F5AA),
      onPrimaryContainer: Color(0xFF002106),
      secondary: Color(0xFF52634F),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFD5E8D0),
      onSecondaryContainer: Color(0xFF101F10),
      tertiary: Color(0xFF38656A),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFBCEBF0),
      onTertiaryContainer: Color(0xFF002023),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFF8FAF0),
      onSurface: Color(0xFF191D16),
      surfaceContainerHighest: Color(0xFFDFE4D6),
      onSurfaceVariant: Color(0xFF424940),
      outline: Color(0xFF72796F),
      outlineVariant: Color(0xFFC2C8BC),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF2E322A),
      onInverseSurface: Color(0xFFF0F1E8),
      inversePrimary: Color(0xFF8DD990),
      surfaceTint: Color(0xFF2E7D32),
    ),
    darkColorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFF8DD990),
      onPrimary: Color(0xFF00390C),
      primaryContainer: Color(0xFF14571F),
      onPrimaryContainer: Color(0xFFA8F5AA),
      secondary: Color(0xFFB9CCB4),
      onSecondary: Color(0xFF253424),
      secondaryContainer: Color(0xFF3B4B39),
      onSecondaryContainer: Color(0xFFD5E8D0),
      tertiary: Color(0xFFA0CFD4),
      onTertiary: Color(0xFF00363A),
      tertiaryContainer: Color(0xFF1F4D52),
      onTertiaryContainer: Color(0xFFBCEBF0),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF11140E),
      onSurface: Color(0xFFE1E4D9),
      surfaceContainerHighest: Color(0xFF424940),
      onSurfaceVariant: Color(0xFFC2C8BC),
      outline: Color(0xFF8C9388),
      outlineVariant: Color(0xFF424940),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFE1E4D9),
      onInverseSurface: Color(0xFF2E322A),
      inversePrimary: Color(0xFF2E7D32),
      surfaceTint: Color(0xFF8DD990),
    ),
  );

  // 橙色主题
  static const AppTheme orangeTheme = AppTheme(
    name: 'orange',
    displayName: 'orange',
    lightColorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFFF6F00),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFDBCC),
      onPrimaryContainer: Color(0xFF2C1600),
      secondary: Color(0xFF77574A),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFFDBCC),
      onSecondaryContainer: Color(0xFF2C150C),
      tertiary: Color(0xFF6B5E2F),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFF4E2A7),
      onTertiaryContainer: Color(0xFF221B00),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFFFBFF),
      onSurface: Color(0xFF221A15),
      surfaceContainerHighest: Color(0xFFF0DDD1),
      onSurfaceVariant: Color(0xFF53433C),
      outline: Color(0xFF85736B),
      outlineVariant: Color(0xFFD8C2B5),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF382E29),
      onInverseSurface: Color(0xFFFFEDE5),
      inversePrimary: Color(0xFFFFB68A),
      surfaceTint: Color(0xFFFF6F00),
    ),
    darkColorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFB68A),
      onPrimary: Color(0xFF4A2800),
      primaryContainer: Color(0xFF693D00),
      onPrimaryContainer: Color(0xFFFFDBCC),
      secondary: Color(0xFFE7BDB0),
      onSecondary: Color(0xFF442A20),
      secondaryContainer: Color(0xFF5D4035),
      onSecondaryContainer: Color(0xFFFFDBCC),
      tertiary: Color(0xFFD7C68D),
      onTertiary: Color(0xFF3A2F05),
      tertiaryContainer: Color(0xFF52461A),
      onTertiaryContainer: Color(0xFFF4E2A7),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF19120D),
      onSurface: Color(0xFFF0DDD1),
      surfaceContainerHighest: Color(0xFF53433C),
      onSurfaceVariant: Color(0xFFD8C2B5),
      outline: Color(0xFFA08D84),
      outlineVariant: Color(0xFF53433C),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFF0DDD1),
      onInverseSurface: Color(0xFF382E29),
      inversePrimary: Color(0xFFFF6F00),
      surfaceTint: Color(0xFFFFB68A),
    ),
  );

  // 红色主题
  static const AppTheme redTheme = AppTheme(
    name: 'red',
    displayName: 'red',
    lightColorScheme: ColorScheme(
      brightness: Brightness.light,
      primary: Color(0xFFD32F2F),
      onPrimary: Color(0xFFFFFFFF),
      primaryContainer: Color(0xFFFFDAD6),
      onPrimaryContainer: Color(0xFF410002),
      secondary: Color(0xFF775652),
      onSecondary: Color(0xFFFFFFFF),
      secondaryContainer: Color(0xFFFFDAD6),
      onSecondaryContainer: Color(0xFF2C1512),
      tertiary: Color(0xFF705D2E),
      onTertiary: Color(0xFFFFFFFF),
      tertiaryContainer: Color(0xFFFCE1A6),
      onTertiaryContainer: Color(0xFF251A00),
      error: Color(0xFFBA1A1A),
      onError: Color(0xFFFFFFFF),
      errorContainer: Color(0xFFFFDAD6),
      onErrorContainer: Color(0xFF410002),
      surface: Color(0xFFFFFBFF),
      onSurface: Color(0xFF221918),
      surfaceContainerHighest: Color(0xFFF1DDD9),
      onSurfaceVariant: Color(0xFF534341),
      outline: Color(0xFF857371),
      outlineVariant: Color(0xFFD8C2BF),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFF382E2C),
      onInverseSurface: Color(0xFFFFEDEA),
      inversePrimary: Color(0xFFFFB4AB),
      surfaceTint: Color(0xFFD32F2F),
    ),
    darkColorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: Color(0xFFFFB4AB),
      onPrimary: Color(0xFF690005),
      primaryContainer: Color(0xFF93000A),
      onPrimaryContainer: Color(0xFFFFDAD6),
      secondary: Color(0xFFE7BDB7),
      onSecondary: Color(0xFF442926),
      secondaryContainer: Color(0xFF5D3F3C),
      onSecondaryContainer: Color(0xFFFFDAD6),
      tertiary: Color(0xFFDFC58C),
      onTertiary: Color(0xFF3E2D04),
      tertiaryContainer: Color(0xFF564319),
      onTertiaryContainer: Color(0xFFFCE1A6),
      error: Color(0xFFFFB4AB),
      onError: Color(0xFF690005),
      errorContainer: Color(0xFF93000A),
      onErrorContainer: Color(0xFFFFDAD6),
      surface: Color(0xFF19110F),
      onSurface: Color(0xFFF1DDD9),
      surfaceContainerHighest: Color(0xFF534341),
      onSurfaceVariant: Color(0xFFD8C2BF),
      outline: Color(0xFFA08C89),
      outlineVariant: Color(0xFF534341),
      shadow: Color(0xFF000000),
      scrim: Color(0xFF000000),
      inverseSurface: Color(0xFFF1DDD9),
      onInverseSurface: Color(0xFF382E2C),
      inversePrimary: Color(0xFFD32F2F),
      surfaceTint: Color(0xFFFFB4AB),
    ),
  );

  // 所有主题列表
  static const List<AppTheme> allThemes = [
    blueTheme,
    purpleTheme,
    greenTheme,
    orangeTheme,
    redTheme,
  ];

  // 根据名称获取主题
  static AppTheme getThemeByName(String name) {
    return allThemes.firstWhere(
      (theme) => theme.name == name,
      orElse: () => blueTheme,
    );
  }

  // 获取主题对应的图标
  static IconData getThemeIcon(String themeName) {
    switch (themeName) {
      case 'blue':
        return Icons.water_drop;
      case 'purple':
        return Icons.auto_awesome;
      case 'green':
        return Icons.park;
      case 'orange':
        return Icons.wb_sunny;
      case 'red':
        return Icons.favorite;
      case 'custom':
        return Icons.color_lens;
      default:
        return Icons.palette;
    }
  }

  // 从种子颜色创建自定义主题
  static AppTheme createCustomTheme(Color seedColor) {
    final lightScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.light,
    );
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: Brightness.dark,
    );

    return AppTheme(
      name: 'custom',
      displayName: 'custom',
      lightColorScheme: lightScheme,
      darkColorScheme: darkScheme,
    );
  }

  // 常用的强调色选项
  static const List<Color> accentColors = [
    Color(0xFF1976D2), // 蓝色
    Color(0xFF6A4C93), // 紫色
    Color(0xFF2E7D32), // 绿色
    Color(0xFFFF6F00), // 橙色
    Color(0xFFD32F2F), // 红色
    Color(0xFFE91E63), // 粉色
    Color(0xFF00BCD4), // 青色
    Color(0xFF795548), // 棕色
    Color(0xFF607D8B), // 蓝灰色
    Color(0xFF9C27B0), // 深紫色
    Color(0xFFFF9800), // 琥珀色
    Color(0xFF4CAF50), // 浅绿色
    Color(0xFFFFEB3B), // 黄色
    Color(0xFF9E9E9E), // 灰色
    Color(0xFF3F51B5), // 靛蓝色
    Color(0xFFFF5722), // 深橙色
  ];

  // 强调色名称对应（值为稳定 code，由 UI 层通过 accentColorDisplayName 翻译）
  static final Map<Color, String> accentColorNames = {
    const Color(0xFF1976D2): 'blue',
    const Color(0xFF6A4C93): 'purple',
    const Color(0xFF2E7D32): 'green',
    const Color(0xFFFF6F00): 'orange',
    const Color(0xFFD32F2F): 'red',
    const Color(0xFFE91E63): 'pink',
    const Color(0xFF00BCD4): 'cyan',
    const Color(0xFF795548): 'brown',
    const Color(0xFF607D8B): 'grey',
    const Color(0xFF9C27B0): 'deepPurple',
    const Color(0xFFFF9800): 'amber',
    const Color(0xFF4CAF50): 'lightGreen',
    const Color(0xFFFFEB3B): 'yellow',
    const Color(0xFF9E9E9E): 'neutralGrey',
    const Color(0xFF3F51B5): 'indigo',
    const Color(0xFFFF5722): 'deepOrange',
  };

  // 获取强调色名称 code（未匹配时返回 'custom'，由 UI 层翻译）
  static String getAccentColorName(Color color) {
    return accentColorNames[color] ?? 'custom';
  }

  // 全局强调色管理（与应用主题分离）
  static Color? _globalAccentColor;

  // 设置全局强调色
  static void setGlobalAccentColor(Color? color) {
    _globalAccentColor = color;
  }

  // 获取全局强调色
  static Color? getGlobalAccentColor() {
    return _globalAccentColor;
  }

  // 获取带全局强调色的ColorScheme
  static ColorScheme getColorSchemeWithAccent(
    ColorScheme baseScheme,
    Color? accentColor,
  ) {
    if (accentColor == null) return baseScheme;

    // 只修改强调色相关属性，保持其他颜色不变
    // 使用强调色生成相关的色调变化
    final HSLColor accentHSL = HSLColor.fromColor(accentColor);
    final bool isDark = baseScheme.brightness == Brightness.dark;

    // 为深色和浅色模式生成合适的变体
    final Color primaryColor = accentColor;
    final Color onPrimaryColor = _getContrastingColor(primaryColor);
    final Color primaryContainerColor = isDark
        ? accentHSL
              .withLightness((accentHSL.lightness * 0.2).clamp(0.0, 1.0))
              .toColor()
        : accentHSL
              .withLightness((accentHSL.lightness * 0.9).clamp(0.0, 1.0))
              .toColor();
    final Color onPrimaryContainerColor = _getContrastingColor(
      primaryContainerColor,
    );

    // 生成secondary颜色（基于primary的相似色调）
    final Color secondaryColor = accentHSL
        .withHue((accentHSL.hue + 30) % 360)
        .withSaturation((accentHSL.saturation * 0.7).clamp(0.0, 1.0))
        .toColor();

    return baseScheme.copyWith(
      primary: primaryColor,
      onPrimary: onPrimaryColor,
      primaryContainer: primaryContainerColor,
      onPrimaryContainer: onPrimaryContainerColor,
      secondary: secondaryColor,
      onSecondary: _getContrastingColor(secondaryColor),
      inversePrimary: isDark
          ? primaryColor
          : accentHSL.withLightness(0.8).toColor(),
      surfaceTint: primaryColor,
    );
  }

  // 获取对比色（黑色或白色）
  static Color _getContrastingColor(Color color) {
    // 计算颜色的相对亮度
    final double luminance = color.computeLuminance();
    // 如果亮度大于0.5，返回黑色，否则返回白色
    return luminance > 0.5 ? Colors.black : Colors.white;
  }
}
