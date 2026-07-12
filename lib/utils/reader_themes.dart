import 'package:flutter/material.dart';

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
      ),
    );
  }
}

class ReaderThemes {
  ReaderThemes._();

  static const day = ReaderThemePalette(
    id: 'day',
    brightness: Brightness.light,
    background: Color(0xFFF8F5ED),
    text: Color(0xFF26231E),
    secondaryText: Color(0xFF696257),
    surface: Color(0xFFFFFCF5),
    controlBar: Color(0xFFF0EADF),
    controlFill: Color(0xFFE3D7C7),
    accent: Color(0xFF765234),
    onAccent: Color(0xFFFFFFFF),
    border: Color(0xFFB8AC9C),
    shadow: Color(0xFF241B13),
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

  static const all = <ReaderThemePalette>[day, night, parchment];

  static ReaderThemePalette byId(String? id) {
    return all.firstWhere(
      (theme) => theme.id == id,
      orElse: () => day,
    );
  }
}
