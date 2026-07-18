import 'package:flutter/material.dart';

import '../core/reader/reader_custom_theme.dart';

/// A reader-only color system. It is intentionally separate from AppThemes so
/// changing the reading canvas never changes the rest of the application.
class ReaderThemePalette {
  const ReaderThemePalette({
    required this.id,
    required this.brightness,
    required this.background,
    required this.text,
    required this.secondaryText,
    required this.surface,
    required this.controlBar,
    required this.controlFill,
    required this.accent,
    required this.onAccent,
    required this.border,
    required this.shadow,
  });

  final String id;
  final Brightness brightness;
  final Color background;
  final Color text;
  final Color secondaryText;
  final Color surface;
  final Color controlBar;
  final Color controlFill;
  final Color accent;
  final Color onAccent;
  final Color border;
  final Color shadow;

  String get cacheKey => '$id:'
      '${background.toARGB32()}:'
      '${text.toARGB32()}:'
      '${controlBar.toARGB32()}';

  ThemeData toThemeData({TextTheme? typography}) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: brightness,
    );
    final scheme = baseScheme.copyWith(
      primary: accent,
      onPrimary: onAccent,
      primaryContainer: controlFill,
      onPrimaryContainer: text,
      secondary: accent,
      onSecondary: onAccent,
      secondaryContainer: controlFill,
      onSecondaryContainer: text,
      surface: surface,
      onSurface: text,
      surfaceContainerHighest: controlBar,
      onSurfaceVariant: secondaryText,
      outline: border,
      outlineVariant: border.withValues(alpha: 0.58),
      shadow: shadow,
    );
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
    );
    final textTheme = (typography ?? base.textTheme).apply(
      bodyColor: text,
      displayColor: text,
    );

    return base.copyWith(
      scaffoldBackgroundColor: background,
      canvasColor: background,
      cardColor: surface,
      dividerColor: border.withValues(alpha: 0.62),
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      iconTheme: IconThemeData(color: text),
      appBarTheme: AppBarTheme(
        backgroundColor: controlBar,
        foregroundColor: text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surface,
        modalBackgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        dragHandleColor: secondaryText,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: controlBar,
        indicatorColor: controlFill,
        labelTextStyle: WidgetStatePropertyAll(
          textTheme.labelMedium?.copyWith(color: text),
        ),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected) ? accent : text,
          );
        }),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: text,
        unselectedLabelColor: secondaryText,
        indicatorColor: accent,
        dividerColor: border,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        textStyle: textTheme.bodyMedium,
      ),
      sliderTheme: base.sliderTheme.copyWith(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: border,
        overlayColor: accent.withValues(alpha: 0.12),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
      ),
    );
  }
}

class ReaderThemes {
  ReaderThemes._();

  static ReaderCustomTheme? _customTheme;

  static ReaderCustomTheme? get customTheme => _customTheme;

  static ReaderThemePalette? get custom =>
      _customTheme == null ? null : _fromCustomTheme(_customTheme!);

  static void setCustomTheme(ReaderCustomTheme? theme) {
    _customTheme = theme;
  }

  static const day = ReaderThemePalette(
    id: 'day',
    brightness: Brightness.light,
    background: Color(0xFFFFFFFF),
    text: Color(0xFF202124),
    secondaryText: Color(0xFF666A70),
    surface: Color(0xFFFFFFFF),
    controlBar: Color(0xFFF7F7F8),
    controlFill: Color(0xFFE8EAED),
    accent: Color(0xFF3F63B8),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFFD5D8DD),
    shadow: Color(0xFF202124),
  );

  static const mist = ReaderThemePalette(
    id: 'mist',
    brightness: Brightness.light,
    background: Color(0xFFF3F5F7),
    text: Color(0xFF27313A),
    secondaryText: Color(0xFF65717C),
    surface: Color(0xFFF9FAFB),
    controlBar: Color(0xFFE8EDF1),
    controlFill: Color(0xFFD8E0E7),
    accent: Color(0xFF55758E),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFFC3CDD5),
    shadow: Color(0xFF23313D),
  );

  static const green = ReaderThemePalette(
    id: 'green',
    brightness: Brightness.light,
    background: Color(0xFFE9F1E5),
    text: Color(0xFF263126),
    secondaryText: Color(0xFF5F6E5E),
    surface: Color(0xFFF0F6ED),
    controlBar: Color(0xFFDDE9D8),
    controlFill: Color(0xFFC9DBC2),
    accent: Color(0xFF527451),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFFAFC2A9),
    shadow: Color(0xFF213020),
  );

  static const rose = ReaderThemePalette(
    id: 'rose',
    brightness: Brightness.light,
    background: Color(0xFFF4E8E7),
    text: Color(0xFF3A292B),
    secondaryText: Color(0xFF765F62),
    surface: Color(0xFFFAF1F0),
    controlBar: Color(0xFFEBDAD9),
    controlFill: Color(0xFFDEC7C7),
    accent: Color(0xFF8B5A60),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFFC9AEAF),
    shadow: Color(0xFF382326),
  );

  static const night = ReaderThemePalette(
    id: 'night',
    brightness: Brightness.dark,
    background: Color(0xFF151816),
    text: Color(0xFFEAE5D9),
    secondaryText: Color(0xFFB9B3A7),
    surface: Color(0xFF202420),
    controlBar: Color(0xFF272C27),
    controlFill: Color(0xFF3B433A),
    accent: Color(0xFFD4B77E),
    onAccent: Color(0xFF2B2112),
    border: Color(0xFF596057),
    shadow: Color(0xFF000000),
  );

  static const pureBlack = ReaderThemePalette(
    id: 'pureBlack',
    brightness: Brightness.dark,
    background: Color(0xFF000000),
    text: Color(0xFFF2F2F2),
    secondaryText: Color(0xFFB8B8B8),
    surface: Color(0xFF000000),
    controlBar: Color(0xFF101010),
    controlFill: Color(0xFF202020),
    accent: Color(0xFFE2E2E2),
    onAccent: Color(0xFF000000),
    border: Color(0xFF4A4A4A),
    shadow: Color(0xFF000000),
  );

  static const parchment = ReaderThemePalette(
    id: 'parchment',
    brightness: Brightness.light,
    background: Color(0xFFDDC99F),
    text: Color(0xFF38291C),
    secondaryText: Color(0xFF67513A),
    surface: Color(0xFFE7D4AC),
    controlBar: Color(0xFFCAB184),
    controlFill: Color(0xFFB99A69),
    accent: Color(0xFF70451F),
    onAccent: Color(0xFFFFF7E7),
    border: Color(0xFF92754F),
    shadow: Color(0xFF49331F),
  );

  static const navy = ReaderThemePalette(
    id: 'navy',
    brightness: Brightness.dark,
    background: Color(0xFF15202B),
    text: Color(0xFFDDE7F0),
    secondaryText: Color(0xFFAAB9C7),
    surface: Color(0xFF1B2A38),
    controlBar: Color(0xFF223443),
    controlFill: Color(0xFF304A5E),
    accent: Color(0xFF85B7D6),
    onAccent: Color(0xFF102330),
    border: Color(0xFF526A7C),
    shadow: Color(0xFF000000),
  );

  static const all = <ReaderThemePalette>[
    day,
    mist,
    green,
    rose,
    parchment,
    navy,
    night,
    pureBlack,
  ];

  static ReaderThemePalette byId(String? id) {
    if (id == ReaderCustomTheme.themeId && custom != null) return custom!;
    return all.firstWhere(
      (theme) => theme.id == id,
      orElse: () => day,
    );
  }

  static ReaderThemePalette _fromCustomTheme(ReaderCustomTheme custom) {
    final background = custom.background;
    final text = custom.text;
    final controlBar = custom.controlBar;
    final brightness = background.computeLuminance() < 0.34
        ? Brightness.dark
        : Brightness.light;
    final surface = Color.alphaBlend(
      text.withValues(alpha: brightness == Brightness.dark ? 0.07 : 0.035),
      background,
    );
    final controlFill = Color.alphaBlend(
      text.withValues(alpha: brightness == Brightness.dark ? 0.18 : 0.11),
      controlBar,
    );
    final secondaryText = Color.alphaBlend(
      text.withValues(alpha: 0.68),
      background,
    );
    final border = Color.alphaBlend(
      text.withValues(alpha: brightness == Brightness.dark ? 0.32 : 0.22),
      background,
    );
    return ReaderThemePalette(
      id: ReaderCustomTheme.themeId,
      brightness: brightness,
      background: background,
      text: text,
      secondaryText: secondaryText,
      surface: surface,
      controlBar: controlBar,
      controlFill: controlFill,
      accent: text,
      onAccent: background,
      border: border,
      shadow: const Color(0xFF000000),
    );
  }
}
