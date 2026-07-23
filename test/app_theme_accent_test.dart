import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/main.dart';
import 'package:xxread/utils/app_themes.dart';

Future<ThemeNotifier> _loadNotifier() async {
  final notifier = ThemeNotifier();
  if (notifier.isInitialized) return notifier;

  final initialized = Completer<void>();
  void listener() {
    if (notifier.isInitialized && !initialized.isCompleted) {
      initialized.complete();
    }
  }

  notifier.addListener(listener);
  listener();
  await initialized.future;
  notifier.removeListener(listener);
  return notifier;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test(
    'defaults to one accent seed that generates both color schemes',
    () async {
      final notifier = await _loadNotifier();
      addTearDown(notifier.dispose);

      expect(notifier.accentColor, AppThemes.defaultAccentColor);
      expect(
        notifier.currentAppTheme.lightColorScheme,
        ColorScheme.fromSeed(
          seedColor: AppThemes.defaultAccentColor,
          brightness: Brightness.light,
        ),
      );
      expect(
        notifier.currentAppTheme.darkColorScheme,
        ColorScheme.fromSeed(
          seedColor: AppThemes.defaultAccentColor,
          brightness: Brightness.dark,
        ),
      );
    },
  );

  test(
    'setting an accent persists the unified value and clears legacy keys',
    () async {
      SharedPreferences.setMockInitialValues({
        'appTheme': 'green',
        'globalAccentColor': const Color(0xFF445566).toARGB32(),
        'customAccentColor': const Color(0xFF112233).toARGB32(),
        'last_preset_app_theme': 'green',
      });
      final notifier = await _loadNotifier();
      addTearDown(notifier.dispose);

      const selected = Color(0xFF8A3FFC);
      await notifier.setAccentColor(selected);

      final prefs = await SharedPreferences.getInstance();
      expect(notifier.accentColor, selected);
      expect(prefs.getInt('appAccentColorV2'), selected.toARGB32());
      expect(prefs.containsKey('appTheme'), isFalse);
      expect(prefs.containsKey('globalAccentColor'), isFalse);
      expect(prefs.containsKey('customAccentColor'), isFalse);
      expect(prefs.containsKey('last_preset_app_theme'), isFalse);
    },
  );

  test(
    'migration prefers the old global accent over the old app theme',
    () async {
      const legacyAccent = Color(0xFF123456);
      SharedPreferences.setMockInitialValues({
        'appTheme': 'red',
        'globalAccentColor': legacyAccent.toARGB32(),
      });

      final notifier = await _loadNotifier();
      addTearDown(notifier.dispose);

      final prefs = await SharedPreferences.getInstance();
      expect(notifier.accentColor, legacyAccent);
      expect(prefs.getInt('appAccentColorV2'), legacyAccent.toARGB32());
      expect(prefs.containsKey('appTheme'), isFalse);
      expect(prefs.containsKey('globalAccentColor'), isFalse);
    },
  );

  test('migration keeps custom theme colors and maps named themes', () async {
    const legacyCustom = Color(0xFF654321);
    SharedPreferences.setMockInitialValues({
      'appTheme': 'custom',
      'customAccentColor': legacyCustom.toARGB32(),
    });
    final customNotifier = await _loadNotifier();
    expect(customNotifier.accentColor, legacyCustom);
    customNotifier.dispose();

    SharedPreferences.setMockInitialValues({'appTheme': 'purple'});
    final namedNotifier = await _loadNotifier();
    addTearDown(namedNotifier.dispose);
    expect(
      namedNotifier.accentColor,
      AppThemes.accentColorForLegacyTheme('purple'),
    );
  });
}
