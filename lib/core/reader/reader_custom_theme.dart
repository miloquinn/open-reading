import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class ReaderCustomTheme {
  const ReaderCustomTheme({
    this.id = legacyThemeId,
    this.name = '',
    required this.background,
    required this.text,
    required this.controlBar,
    this.backgroundImagePath,
    this.backgroundImageOpacity = defaultBackgroundImageOpacity,
  });

  static const String legacyThemeId = 'custom';
  static const String themeId = legacyThemeId;
  static const String themeIdPrefix = 'custom:';
  static const double defaultBackgroundImageOpacity = 0.28;
  static const ReaderCustomTheme defaults = ReaderCustomTheme(
    background: Color(0xFFF6F0E4),
    text: Color(0xFF342D25),
    controlBar: Color(0xFFE6D9C5),
  );
  static const Object _unchanged = Object();

  final String id;
  final String name;
  final Color background;
  final Color text;
  final Color controlBar;
  final String? backgroundImagePath;
  final double backgroundImageOpacity;

  bool get hasBackgroundImage =>
      backgroundImagePath != null && backgroundImagePath!.isNotEmpty;

  static bool isCustomThemeId(String? id) =>
      id == legacyThemeId || (id?.startsWith(themeIdPrefix) ?? false);

  ReaderCustomTheme copyWith({
    String? id,
    String? name,
    Color? background,
    Color? text,
    Color? controlBar,
    Object? backgroundImagePath = _unchanged,
    double? backgroundImageOpacity,
  }) {
    return ReaderCustomTheme(
      id: id ?? this.id,
      name: name ?? this.name,
      background: background ?? this.background,
      text: text ?? this.text,
      controlBar: controlBar ?? this.controlBar,
      backgroundImagePath: identical(backgroundImagePath, _unchanged)
          ? this.backgroundImagePath
          : backgroundImagePath as String?,
      backgroundImageOpacity:
          (backgroundImageOpacity ?? this.backgroundImageOpacity)
              .clamp(0.0, 0.75),
    );
  }

  Map<String, Object?> toMap() => <String, Object?>{
        'id': id,
        'name': name,
        'background': background.toARGB32(),
        'text': text.toARGB32(),
        'controlBar': controlBar.toARGB32(),
        'backgroundImagePath': backgroundImagePath,
        'backgroundImageOpacity': backgroundImageOpacity,
      };

  factory ReaderCustomTheme.fromMap(Map<String, Object?> map) {
    int colorValue(String key, Color fallback) {
      final value = map[key];
      return value is int ? value : fallback.toARGB32();
    }

    final storedOpacity = map['backgroundImageOpacity'];
    return ReaderCustomTheme(
      id: switch (map['id']) {
        final String value when value.isNotEmpty => value,
        _ => legacyThemeId,
      },
      name: map['name'] is String ? map['name']! as String : '',
      background: Color(colorValue('background', defaults.background)),
      text: Color(colorValue('text', defaults.text)),
      controlBar: Color(colorValue('controlBar', defaults.controlBar)),
      backgroundImagePath: switch (map['backgroundImagePath']) {
        final String value when value.isNotEmpty => value,
        _ => null,
      },
      backgroundImageOpacity: storedOpacity is num
          ? storedOpacity.toDouble().clamp(0.0, 0.75)
          : defaultBackgroundImageOpacity,
    );
  }
}

class ReaderCustomThemeStore {
  static const String storageKey = 'reader_custom_themes_v2';
  static const String legacyStorageKey = 'reader_custom_theme_v1';

  const ReaderCustomThemeStore();

  Future<List<ReaderCustomTheme>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null) return _decodeList(raw);

    final legacyRaw = prefs.getString(legacyStorageKey);
    if (legacyRaw == null || legacyRaw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(legacyRaw);
      if (decoded is! Map<String, dynamic>) return const [];
      final migrated = ReaderCustomTheme.fromMap(decoded);
      await saveAll([migrated]);
      return [migrated];
    } catch (_) {
      return const [];
    }
  }

  Future<ReaderCustomTheme?> load() async {
    final themes = await loadAll();
    return themes.isEmpty ? null : themes.first;
  }

  Future<void> save(ReaderCustomTheme theme) async {
    final themes = [...await loadAll()];
    final index = themes.indexWhere((item) => item.id == theme.id);
    if (index < 0) {
      themes.add(theme);
    } else {
      themes[index] = theme;
    }
    await saveAll(themes);
  }

  Future<void> saveAll(List<ReaderCustomTheme> themes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode(themes.map((theme) => theme.toMap()).toList()),
    );
  }

  Future<void> delete(String themeId) async {
    final themes = [...await loadAll()]
      ..removeWhere((theme) => theme.id == themeId);
    await saveAll(themes);
  }

  List<ReaderCustomTheme> _decodeList(String raw) {
    if (raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List<Object?>) return const [];
      final result = <ReaderCustomTheme>[];
      final ids = <String>{};
      for (final item in decoded) {
        if (item is! Map<String, dynamic>) continue;
        final theme = ReaderCustomTheme.fromMap(item);
        if (!ReaderCustomTheme.isCustomThemeId(theme.id) ||
            !ids.add(theme.id)) {
          continue;
        }
        result.add(theme);
      }
      return result;
    } catch (_) {
      return const [];
    }
  }
}
