// 文件说明：字体资源目录，定义字体原语及 App/阅读两套语义字体域。
// 技术要点：稳定 ID、作用域隔离、旧 family 迁移、字体回退链、在线下载元数据。

import '../l10n/app_localizations.dart';
import '../services/core/online_font_models.dart';

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

  /// 在线字体下载文件清单（空表示系统字体或用户导入的字体）。
  ///
  /// 非空时，AppSettingsNotifier 会通过 OnlineFontService 下载这些文件，
  /// 下载完成并通过 FontLoader 注册 [family] 之后才能在 UI 上应用。
  /// 每个在线字体通常下载 1 个变量字体文件以覆盖全部字重；italic 由系统合成。
  final List<OnlineFontFile> downloadFiles;

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
    this.downloadFiles = const <OnlineFontFile>[],
  });

  /// 是否为在线下载字体（系统/自定义字体为 false）。
  bool get isOnline => downloadFiles.isNotEmpty;

  /// 在线字体总下载字节数；非在线字体返回 0。
  int get onlineTotalBytes =>
      downloadFiles.fold<int>(0, (sum, file) => sum + file.size);
}

class FontCatalog {
  static const String systemId = 'system';
  static const String sourceHanSerifId = 'source_han_serif';
  static const String sourceHanSansId = 'source_han_sans';
  static const String instrumentSansId = 'instrument_sans';
  static const String newsreaderId = 'newsreader';
  static const String jetBrainsMonoId = 'jetbrains_mono';

  /// 在线字体源 URL（jsDelivr CDN 取 google/fonts 仓库，NotoSerifSC 因 25MB
  /// 文件触发 jsDelivr 403，回退到 raw.githubusercontent.com）。
  /// URL 中的方括号需 URL-encode 为 %5B %5D，逗号 encode 为 %2C。
  static const String _notoSerifSCUrl =
      'https://raw.githubusercontent.com/google/fonts/main/ofl/notoserifsc/NotoSerifSC%5Bwght%5D.ttf';
  static const String _notoSansSCUrl =
      'https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/notosanssc/NotoSansSC%5Bwght%5D.ttf';
  static const String _instrumentSansUrl =
      'https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/instrumentsans/InstrumentSans%5Bwdth%2Cwght%5D.ttf';
  static const String _newsreaderUrl =
      'https://cdn.jsdelivr.net/gh/google/fonts@main/ofl/newsreader/Newsreader%5Bopsz%2Cwght%5D.ttf';
  static const String _jetBrainsMonoUrl =
      'https://cdn.jsdelivr.net/gh/JetBrains/JetBrainsMono@2.304/fonts/ttf/JetBrainsMono-Regular.ttf';

  /// 各在线字体的预期字节数（与上游仓库当前 HEAD 一致，用于进度展示与超额保护）。
  /// 实际下载完成后由 OnlineFontService 计算并存储 SHA-256，无需与这些数字匹配。
  static const int _notoSerifSCBytes = 25_125_512;
  static const int _notoSansSCBytes = 17_772_300;
  static const int _instrumentSansBytes = 194_336;
  static const int _newsreaderBytes = 451_664;
  static const int _jetBrainsMonoBytes = 273_900;

  static const FontOption systemFont = FontOption(
    id: systemId,
    family: null,
    fallbackFamilies: [],
    tone: FontTone.system,
  );

  /// 思源宋体（Noto Serif SC 变量字体，覆盖字重 300–700）。
  /// 文件 25MB，jsDelivr 因大文件 403，使用 raw.githubusercontent.com 直连。
  static const FontOption sourceHanSerif = FontOption(
    id: sourceHanSerifId,
    family: 'SourceHanSerifCN',
    fallbackFamilies: ['SourceHanSansCN'],
    tone: FontTone.serif,
    downloadFiles: <OnlineFontFile>[
      OnlineFontFile(
        url: _notoSerifSCUrl,
        fileName: 'source_han_serif.ttf',
        size: _notoSerifSCBytes,
      ),
    ],
  );

  /// 思源黑体（Noto Sans SC 变量字体，覆盖字重 100–900）。
  /// 用 Google 的 Noto Sans SC 替代 Adobe 的 SourceHanSansCN，因为 google/fonts
  /// 仓库通过 jsDelivr 可正常下载，且 Noto Sans SC 与 Source Han Sans SC 同源同字形。
  static const FontOption sourceHanSans = FontOption(
    id: sourceHanSansId,
    family: 'SourceHanSansCN',
    fallbackFamilies: [],
    tone: FontTone.sansSerif,
    downloadFiles: <OnlineFontFile>[
      OnlineFontFile(
        url: _notoSansSCUrl,
        fileName: 'source_han_sans.ttf',
        size: _notoSansSCBytes,
      ),
    ],
  );

  /// Instrument Sans（变量字体，含宽度轴 wdth 与字重轴 wght）。
  static const FontOption instrumentSans = FontOption(
    id: instrumentSansId,
    family: 'InstrumentSans',
    fallbackFamilies: ['SourceHanSansCN'],
    tone: FontTone.sansSerif,
    downloadFiles: <OnlineFontFile>[
      OnlineFontFile(
        url: _instrumentSansUrl,
        fileName: 'instrument_sans.ttf',
        size: _instrumentSansBytes,
      ),
    ],
  );

  /// Newsreader（变量字体，含光学尺寸轴 opsz 与字重轴 wght，仅 Roman）。
  /// Italic 字形未下载，由系统合成斜体；Bold 由变量字体内部 wght 轴覆盖。
  static const FontOption newsreader = FontOption(
    id: newsreaderId,
    family: 'Newsreader',
    fallbackFamilies: ['SourceHanSerifCN', 'SourceHanSansCN'],
    tone: FontTone.serif,
    downloadFiles: <OnlineFontFile>[
      OnlineFontFile(
        url: _newsreaderUrl,
        fileName: 'newsreader.ttf',
        size: _newsreaderBytes,
      ),
    ],
  );

  /// JetBrains Mono（静态 Regular，Bold 由系统合成加粗）。
  static const FontOption jetBrainsMono = FontOption(
    id: jetBrainsMonoId,
    family: 'JetBrainsMono',
    fallbackFamilies: ['SourceHanSansCN'],
    tone: FontTone.monospace,
    downloadFiles: <OnlineFontFile>[
      OnlineFontFile(
        url: _jetBrainsMonoUrl,
        fileName: 'jetbrains_mono.ttf',
        size: _jetBrainsMonoBytes,
      ),
    ],
  );

  /// 默认 App 字体（系统字体，无需下载，离线可用）。
  static const FontOption defaultAppFont = systemFont;

  /// 默认阅读字体（系统字体）。
  static const FontOption defaultReaderFont = systemFont;

  /// App 字体选项（系统字体在最前，其他为在线下载字体）。
  static const List<FontOption> appFonts = [
    systemFont,
    sourceHanSerif,
    sourceHanSans,
    instrumentSans,
    jetBrainsMono,
  ];

  /// 阅读字体选项。
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
