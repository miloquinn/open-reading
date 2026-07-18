import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ReaderCustomTheme {
  const ReaderCustomTheme({
    required this.background,
    required this.text,
    required this.controlBar,
  });

  static const String themeId = 'custom';
  static const ReaderCustomTheme defaults = ReaderCustomTheme(
    background: Color(0xFFF6F0E4),
    text: Color(0xFF342D25),
    controlBar: Color(0xFFE6D9C5),
  );

  final Color background;
  final Color text;
  final Color controlBar;

  ReaderCustomTheme copyWith({
    Color? background,
    Color? text,
    Color? controlBar,
  }) {
    return ReaderCustomTheme(
      background: background ?? this.background,
      text: text ?? this.text,
      controlBar: controlBar ?? this.controlBar,
    );
  }

  Map<String, Object> toMap() => <String, Object>{
        'background': background.toARGB32(),
        'text': text.toARGB32(),
        'controlBar': controlBar.toARGB32(),
      };

  factory ReaderCustomTheme.fromMap(Map<String, Object?> map) {
    int colorValue(String key, Color fallback) {
      final value = map[key];
      return value is int ? value : fallback.toARGB32();
    }

    return ReaderCustomTheme(
      background: Color(colorValue('background', defaults.background)),
      text: Color(colorValue('text', defaults.text)),
      controlBar: Color(colorValue('controlBar', defaults.controlBar)),
    );
  }
}

class ReaderCustomThemeStore {
  static const String storageKey = 'reader_custom_theme_v1';

  const ReaderCustomThemeStore();

  Future<ReaderCustomTheme?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return ReaderCustomTheme.fromMap(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save(ReaderCustomTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(storageKey, jsonEncode(theme.toMap()));
  }
}
