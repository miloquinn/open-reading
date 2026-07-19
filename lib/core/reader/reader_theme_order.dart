import 'package:shared_preferences/shared_preferences.dart';

class ReaderThemeOrderStore {
  static const String storageKey = 'reader_theme_order_v1';

  const ReaderThemeOrderStore();

  Future<List<String>> load() async {
    final prefs = await SharedPreferences.getInstance();
    return _sanitize(prefs.getStringList(storageKey) ?? const []);
  }

  Future<void> save(List<String> themeIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(storageKey, _sanitize(themeIds));
  }

  List<String> _sanitize(Iterable<String> themeIds) {
    final result = <String>[];
    final seen = <String>{};
    for (final id in themeIds) {
      final normalized = id.trim();
      if (normalized.isNotEmpty && seen.add(normalized)) {
        result.add(normalized);
      }
    }
    return result;
  }
}
