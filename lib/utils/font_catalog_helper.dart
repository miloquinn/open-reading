// 文件说明：字体资源目录，定义字体原语及 App/阅读两套语义字体域。
// 技术要点：稳定 ID、作用域隔离、旧 family 迁移、字体回退链。

import '../l10n/app_localizations.dart';

enum FontTone { system, serif, sansSerif, monospace }

enum FontDomain { app, reader }

class FontOption {
  final String id;
  final String? family;
  final List<String> fallbackFamilies;
  final FontTone tone;
  final String? displayName;
  final String? sourceFileName;
  final int? fileSize;
  final bool isCustom;
  final bool isAvailable;

  const FontOption({
    required this.id,
    required this.family,
    required this.fallbackFamilies,
    required this.tone,
    this.displayName,
    this.sourceFileName,
    this.fileSize,
    this.isCustom = false,
    this.isAvailable = true,
  });
}

class FontCatalog {
  static const String systemId = 'system';
  static const String sourceHanSerifId = 'source_han_serif';
  static const String sourceHanSansId = 'source_han_sans';
  static const String instrumentSansId = 'instrument_sans';
  static const String newsreaderId = 'newsreader';
  static const String jetBrainsMonoId = 'jetbrains_mono';

  static const FontOption systemFont = FontOption(
    id: systemId,
    family: null,
    fallbackFamilies: [],
    tone: FontTone.system,
  );
  static const FontOption sourceHanSerif = FontOption(
    id: sourceHanSerifId,
    family: 'SourceHanSerifCN',
    fallbackFamilies: ['SourceHanSansCN'],
    tone: FontTone.serif,
  );
  static const FontOption sourceHanSans = FontOption(
    id: sourceHanSansId,
    family: 'SourceHanSansCN',
    fallbackFamilies: [],
    tone: FontTone.sansSerif,
  );
  static const FontOption instrumentSans = FontOption(
    id: instrumentSansId,
    family: 'InstrumentSans',
    fallbackFamilies: ['SourceHanSansCN'],
    tone: FontTone.sansSerif,
  );
  static const FontOption newsreader = FontOption(
    id: newsreaderId,
    family: 'Newsreader',
    fallbackFamilies: ['SourceHanSerifCN', 'SourceHanSansCN'],
    tone: FontTone.serif,
  );
  static const FontOption jetBrainsMono = FontOption(
    id: jetBrainsMonoId,
    family: 'JetBrainsMono',
    fallbackFamilies: ['SourceHanSansCN'],
    tone: FontTone.monospace,
  );

  static const FontOption defaultAppFont = sourceHanSerif;
  static const FontOption defaultReaderFont = systemFont;

  static const List<FontOption> appFonts = [
    sourceHanSerif,
    systemFont,
    sourceHanSans,
    instrumentSans,
    jetBrainsMono,
  ];

  static const List<FontOption> readerFonts = [
    systemFont,
    sourceHanSerif,
    newsreader,
    sourceHanSans,
    jetBrainsMono,
  ];

  static FontOption appFontForId(
    String? id, {
    List<FontOption> customFonts = const <FontOption>[],
  }) =>
      _fontForId(
        id,
        options: <FontOption>[...appFonts, ...customFonts],
        fallback: defaultAppFont,
      );

  static FontOption readerFontForId(
    String? id, {
    List<FontOption> customFonts = const <FontOption>[],
  }) =>
      _fontForId(
        id,
        options: <FontOption>[...readerFonts, ...customFonts],
        fallback: defaultReaderFont,
      );

  static FontOption appFontForFamily(String? family) => _fontForFamily(
        family,
        options: appFonts,
        fallback: defaultAppFont,
      );

  static FontOption readerFontForFamily(String? family) => _fontForFamily(
        family,
        options: readerFonts,
        fallback: defaultReaderFont,
      );

  static FontOption _fontForId(
    String? id, {
    required List<FontOption> options,
    required FontOption fallback,
  }) {
    return options.firstWhere(
      (option) => option.id == id,
      orElse: () => fallback,
    );
  }

  static FontOption _fontForFamily(
    String? family, {
    required List<FontOption> options,
    required FontOption fallback,
  }) {
    return options.firstWhere(
      (option) => option.family == family,
      orElse: () => fallback,
    );
  }

  static List<String> appFallbacks(String? family) =>
      appFontForFamily(family).fallbackFamilies;

  static String labelFor(AppLocalizations l10n, FontOption option) {
    if (option.displayName != null && option.displayName!.isNotEmpty) {
      return option.displayName!;
    }
    switch (option.id) {
      case systemId:
        return l10n.fontSystem;
      case sourceHanSerifId:
        return l10n.fontSourceHanSerif;
      case sourceHanSansId:
        return l10n.fontSourceHanSans;
      case instrumentSansId:
        return l10n.fontInstrumentSans;
      case newsreaderId:
        return l10n.fontNewsreader;
      case jetBrainsMonoId:
        return l10n.fontJetBrainsMono;
      default:
        return l10n.fontSystem;
    }
  }

  static String descriptionFor(AppLocalizations l10n, FontOption option) {
    switch (option.tone) {
      case FontTone.system:
        return l10n.fontSystemDescription;
      case FontTone.serif:
        return l10n.fontSerifDescription;
      case FontTone.sansSerif:
        return l10n.fontSansSerifDescription;
      case FontTone.monospace:
        return l10n.fontMonospaceDescription;
    }
  }
}
