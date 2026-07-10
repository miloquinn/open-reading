// 文件说明：字体目录辅助工具，维护阅读字体选项与展示文案。
// 技术要点：工具方法。

import '../l10n/app_localizations.dart';

class FontOption {
  final String id;
  final String? family;

  const FontOption({
    required this.id,
    required this.family,
  });
}

class FontCatalog {
  static const String systemId = 'system';
  static const String sourceHanSansId = 'source_han_sans';
  static const String jetBrainsMonoId = 'jetbrains_mono';

  static const List<FontOption> appFonts = [
    FontOption(id: systemId, family: null),
    FontOption(id: sourceHanSansId, family: 'SourceHanSansCN'),
  ];

  static const List<FontOption> readerFonts = [
    FontOption(id: systemId, family: null),
    FontOption(id: sourceHanSansId, family: 'SourceHanSansCN'),
    FontOption(id: jetBrainsMonoId, family: 'JetBrainsMono'),
  ];

  static FontOption appFontForFamily(String? family) {
    return appFonts.firstWhere(
      (option) => option.family == family,
      orElse: () => appFonts.first,
    );
  }

  static FontOption readerFontForFamily(String? family) {
    return readerFonts.firstWhere(
      (option) => option.family == family,
      orElse: () => readerFonts.first,
    );
  }

  static List<String> appFallbacks(String? family) {
    return _fallbacksFor(family);
  }

  static List<String> readerFallbacks(String? family) {
    return _fallbacksFor(family);
  }

  static List<String> _fallbacksFor(String? family) {
    return const ['SourceHanSansCN'];
  }

  static String labelFor(AppLocalizations l10n, FontOption option) {
    switch (option.id) {
      case systemId:
        return l10n.fontSystem;
      case sourceHanSansId:
        return l10n.fontSourceHanSans;
      case jetBrainsMonoId:
        return l10n.fontJetBrainsMono;
      default:
        return l10n.fontSystem;
    }
  }
}
