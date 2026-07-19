// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '开元阅读';

  @override
  String get home => '首页';

  @override
  String get library => '书架';

  @override
  String get bookSources => '书源';

  @override
  String get discover => '发现';

  @override
  String get discoverRecommended => '推荐';

  @override
  String get discoverCategories => '分类';

  @override
  String get discoverLatest => '最新';

  @override
  String get discoverLoadFailed => '发现内容加载失败';

  @override
  String get discoverRetry => '重新加载';

  @override
  String get discoverUnsupportedTitle => '当前书源暂不支持此栏目';

  @override
  String discoverUnsupportedMessage(String capability) {
    return '需要书源提供 $capability 能力；现有书源仍可继续用于搜索。';
  }

  @override
  String get discoverCategoryEmpty => '这个分类暂时没有可展示的书籍。';

  @override
  String get bookSourceManagementTitle => '书源管理';

  @override
  String get bookSourceManagementSubtitle => '管理内容来源的添加、启停与协议信息。发现页只保留找书体验。';

  @override
  String get settingsContentSourcesTitle => '内容来源';

  @override
  String get settingsContentSourcesSubtitle => '添加、启用或移除开放书源';

  @override
  String get bookSourcesSubtitle => '连接开放书源，跨来源搜索可阅读内容';

  @override
  String get bookSourcesAdd => '添加书源';

  @override
  String get bookSourcesSearchHint => '输入书名或作者，搜索已启用书源';

  @override
  String get bookSourcesSearch => '搜索';

  @override
  String get bookSourcesLoadMore => '加载更多';

  @override
  String bookSourcesFailedCount(int count) {
    return '$count 个书源请求失败';
  }

  @override
  String get bookSourcesSearchPrompt => '添加并启用书源后，即可在这里统一搜索';

  @override
  String get bookSourcesNoResults => '没有找到匹配的书籍';

  @override
  String get bookSourcesNoSourcesTitle => '还没有书源';

  @override
  String get bookSourcesNoSourcesDescription =>
      '粘贴兼容 Open Reading Source Protocol 的服务地址即可接入。';

  @override
  String get bookSourcesManageTitle => '已接入书源';

  @override
  String get bookSourcesEnabled => '已启用';

  @override
  String get bookSourcesDisabled => '已停用';

  @override
  String get bookSourcesRemove => '移除';

  @override
  String get bookSourcesRemoveTitle => '移除书源';

  @override
  String get bookSourcesRemoveMessage => '此操作只移除书源配置，不会删除本地书籍。';

  @override
  String get bookSourcesCancel => '取消';

  @override
  String get bookSourcesConfirm => '确认';

  @override
  String get bookSourcesAddTitle => '添加开放书源';

  @override
  String get bookSourcesUrlLabel => '书源地址';

  @override
  String get bookSourcesUrlHint => 'https://example.com 或发现文档 URL';

  @override
  String get bookSourcesNoOfficialSourcesNotice =>
      '开元阅读不预装任何书源，也不运营、推荐或背书第三方书源服务。每个书源地址都由你主动添加。';

  @override
  String get bookSourcesResponsibilityAck =>
      '我确认自己有权访问相关内容，且不会利用书源绕过登录、付费、DRM 或其他访问控制。';

  @override
  String get bookSourcesConnect => '连接并校验';

  @override
  String get bookSourcesConnecting => '正在校验协议…';

  @override
  String get bookSourcesAdded => '书源已添加';

  @override
  String get bookSourcesProtocolTitle => 'Open Reading Source Protocol';

  @override
  String get bookSourcesProtocolDescription =>
      '统一发现、搜索、书籍详情、目录与章节正文接口。开发者可搭建原生书源，也可为已有合法内容服务编写适配网关。';

  @override
  String get bookSourcesProtocolDetails => '查看协议';

  @override
  String get bookSourcesProtocolRepository => '协议开源仓库';

  @override
  String get bookSourcesProtocolRepositoryOpen => '在 GitHub 查看';

  @override
  String get bookSourcesProtocolRepositoryOpenFailed => '无法打开书源协议仓库';

  @override
  String get bookSourcesProtocolDialogTitle => '开放书源协议 v1.2';

  @override
  String get bookSourcesProtocolDialogBody =>
      '服务在 /.well-known/open-reading-source.json 发布发现文档，并实现搜索、书籍详情、章节目录与章节正文接口。v1.2 为公开、无需登录的 HTTP(S) 书源增加运营者、联系方式、内容许可与权利声明元数据。';

  @override
  String get bookSourcesRightsDetails => '运营者与权利信息';

  @override
  String get bookSourcesOperator => '书源运营者';

  @override
  String get bookSourcesContentLicense => '内容许可';

  @override
  String get bookSourcesRightsStatement => '权利声明';

  @override
  String get bookSourcesRightsNotProvided => '该书源未提供';

  @override
  String get bookSourcesRightsUnverifiedNotice =>
      '上述信息由独立书源运营者自行声明。开元阅读仅为提高透明度而展示，不负责核验，也不构成推荐或背书。';

  @override
  String get bookSourcesContactOperator => '联系运营者';

  @override
  String get bookSourcesRightsReport => '权利投诉';

  @override
  String get bookSourcesRightsReportOpenFailed => '无法打开权利投诉表单';

  @override
  String get bookSourcesClose => '关闭';

  @override
  String get settings => '设置';

  @override
  String get statistics => '统计';

  @override
  String get reading => '阅读';

  @override
  String get importBooks => '导入书籍';

  @override
  String get darkMode => '深色模式';

  @override
  String get lightMode => '浅色模式';

  @override
  String get systemMode => '跟随系统';

  @override
  String get theme => '主题';

  @override
  String get accent => '强调色';

  @override
  String get bookmarks => '书签';

  @override
  String get notes => '笔记';

  @override
  String get highlights => '高亮';

  @override
  String get ttsReading => '语音朗读';

  @override
  String get share => '分享';

  @override
  String get shareContent => '分享内容';

  @override
  String get shareCurrentPage => '分享当前页面';

  @override
  String get shareSelectedText => '分享选中文本';

  @override
  String get shareProgress => '分享阅读进度';

  @override
  String get play => '播放';

  @override
  String get pause => '暂停';

  @override
  String get stop => '停止';

  @override
  String get speed => '语速';

  @override
  String get pitch => '音调';

  @override
  String get language => '语言';

  @override
  String get fontSize => '字体大小';

  @override
  String get readingProgress => '阅读进度';

  @override
  String get totalPages => '总页数';

  @override
  String get currentPage => '当前页';

  @override
  String get readingTime => '阅读时长';

  @override
  String get booksRead => '已读书籍';

  @override
  String get todayReading => '今日阅读';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '确认';

  @override
  String get delete => '删除';

  @override
  String get edit => '编辑';

  @override
  String get save => '保存';

  @override
  String get back => '返回';

  @override
  String get next => '下一页';

  @override
  String get previous => '上一页';

  @override
  String get search => '搜索';

  @override
  String get noResults => '未找到结果';

  @override
  String get loading => '加载中...';

  @override
  String get error => '错误';

  @override
  String get initializationFailed => '初始化失败';

  @override
  String get unknownError => '未知错误';

  @override
  String get retry => '重试';

  @override
  String get appearanceSettings => '外观设置';

  @override
  String get readingTips => '阅读提示';

  @override
  String get readingFontSettingsMoved => '阅读字体设置已移至阅读界面';

  @override
  String get readingFontSettingsHint =>
      '打开任意书籍，点击屏幕中央，在底部控制栏中点击「设置」按钮，即可调整字体大小、行间距、字符间距、页面边距与阅读字体。';

  @override
  String get readingSettings => '阅读设置';

  @override
  String get enableTts => '启用朗读功能';

  @override
  String get enableTtsHint => '开启文本转语音朗读';

  @override
  String get ttsSpeedLabel => '朗读速度';

  @override
  String get ttsSpeedHint => '调整朗读的快慢';

  @override
  String get ttsVolumeLabel => '朗读音量';

  @override
  String get ttsVolumeHint => '调整朗读音量大小';

  @override
  String get ttsPitchLabel => '音调高低';

  @override
  String get ttsPitchHint => '调整朗读音调';

  @override
  String get appSettings => '应用设置';

  @override
  String get appFont => 'App 字体';

  @override
  String get appFontDescription => '用于导航、按钮、设置等界面文字，不影响书籍正文。';

  @override
  String get readerFont => '阅读字体';

  @override
  String get readerFontDescription => '仅用于书籍正文和章节标题，不影响 App 界面。';

  @override
  String get fontSystem => '系统默认';

  @override
  String get fontSourceHanSerif => '思源宋体';

  @override
  String get fontSourceHanSans => '思源黑体';

  @override
  String get fontJetBrainsMono => 'JetBrains Mono';

  @override
  String get fontInstrumentSans => 'Instrument Sans';

  @override
  String get fontNewsreader => 'Newsreader';

  @override
  String get fontSystemDescription => '跟随当前设备和操作系统的原生字体。';

  @override
  String get fontSerifDescription => '沉静、有出版物气质的衬线字体，适合长时间阅读。';

  @override
  String get fontSansSerifDescription => '清晰简洁的无衬线字体，适合紧凑界面和日常阅读。';

  @override
  String get fontMonospaceDescription => '等宽字体，适合代码、技术内容和专注排版。';

  @override
  String get fontPreviewText => 'Open Reading · 自由阅读，开卷有益';

  @override
  String get customFonts => '我的字体';

  @override
  String get customFontsEmpty => '还没有导入字体';

  @override
  String get customFontsEmptyHint => '导入一次 TTF 或 OTF 文件，即可用于 App 界面或阅读正文。';

  @override
  String customFontsCount(int count) {
    return '已导入 $count 款字体';
  }

  @override
  String get customFontsLocalOnly => '导入的字体只保存在当前设备，不会自动同步。';

  @override
  String get builtInFonts => '内置字体';

  @override
  String get importFont => '导入字体';

  @override
  String get importingFont => '正在导入字体…';

  @override
  String get customFontImported => '字体已导入';

  @override
  String get customFontAlreadyImported => '该字体已经导入，可以直接使用';

  @override
  String get customFontApplied => '字体设置已更新';

  @override
  String get customFontAppliedToApp => '已导入并设为 App 字体';

  @override
  String get customFontAppliedToReader => '已导入并设为阅读字体';

  @override
  String get customFontImportUnsupported => '当前平台暂不支持持久化导入字体。';

  @override
  String get customFontUnsupportedFormat => '请选择 TTF 或 OTF 字体文件。';

  @override
  String get customFontInvalid => '该文件不是有效或受支持的字体。';

  @override
  String get customFontTooLarge => '字体文件不能超过 50 MB。';

  @override
  String get customFontReadFailed => '无法读取字体文件。';

  @override
  String get customFontLoadFailed => '无法加载该字体。';

  @override
  String get customFontStorageFailed => '无法将字体保存到当前设备。';

  @override
  String get customFontUnavailable => '字体文件不可用，请删除后重新导入。';

  @override
  String get setAsAppFont => '设为 App 字体';

  @override
  String get setAsReaderFont => '设为阅读字体';

  @override
  String get setAsBothFonts => '同时用于两者';

  @override
  String get renameFont => '重命名字体';

  @override
  String deleteCustomFontTitle(String name) {
    return '删除“$name”？';
  }

  @override
  String get deleteCustomFontMessage => '字体文件将从当前设备删除。';

  @override
  String get deleteCustomFontInUse => '该字体正在使用。删除后，受影响的字体设置将恢复为默认值。';

  @override
  String get deleteAndReset => '删除并恢复默认';

  @override
  String get settingsTelegramChannel => 'Telegram';

  @override
  String get settingsTelegramSubtitle => 'Telegram 官方频道';

  @override
  String get settingsTelegramOpenFailed => '无法打开 Telegram 链接';

  @override
  String get settingsQqChannel => 'QQ 频道';

  @override
  String get settingsQqChannelSubtitle => '开元阅读 · OpenReading6';

  @override
  String get settingsQqChannelOpenFailed => '无法打开 QQ 频道邀请链接';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get typographySettings => '排版设置';

  @override
  String get fontFamilyLabel => '字体';

  @override
  String get fontSizeLabel => '字体大小';

  @override
  String get lineSpacingLabel => '行距';

  @override
  String get letterSpacingLabel => '字间距';

  @override
  String get firstLineIndentLabel => '首行缩进';

  @override
  String get paragraphSpacingLabel => '段落间距';

  @override
  String get pageMarginLabel => '页边距';

  @override
  String get resetDefault => '恢复默认';

  @override
  String get ttsPanelTitle => '语音朗读';

  @override
  String get ttsPreviewEffect => '预览效果';

  @override
  String get ttsVolume => '音量';

  @override
  String get ttsPitch => '音调';

  @override
  String get ttsSpeed => '语速';

  @override
  String get ttsPreviousSentence => '上一句';

  @override
  String get ttsNextSentence => '下一句';

  @override
  String get ttsTimerStop => '定时停止';

  @override
  String get ttsTimerOff => '不限时';

  @override
  String ttsTimerMinutes(Object minutes) {
    return '$minutes 分钟后停止';
  }

  @override
  String get ttsPlaying => '正在播放';

  @override
  String get ttsPaused => '已暂停';

  @override
  String get ttsStopped => '已停止';

  @override
  String get ttsPreviousSentenceFailed => '上一句失败';

  @override
  String get ttsNextSentenceFailed => '下一句失败';

  @override
  String get ttsEmptyContentError => '当前页面内容为空';

  @override
  String get ttsPlaybackFailed => '播放失败';

  @override
  String get ttsOperationFailed => '操作失败';

  @override
  String get pageTurningMode => '翻页模式';

  @override
  String get pageTurningSlide => '水平滑动';

  @override
  String get pageTurningScroll => '上下翻页';

  @override
  String get tapZoneSettings => '点击翻页区域';

  @override
  String get tapZoneNextPage => '下一页';

  @override
  String get tapZonePreviousPage => '上一页';

  @override
  String get tapZoneMenu => '菜单';

  @override
  String get tapZoneLegend => '图例';

  @override
  String get highlightColor => '荧光笔颜色';

  @override
  String get highlightPreview => '预览效果';

  @override
  String get highlightSampleText => '这是一段示例文本，';

  @override
  String get highlightSampleText2 => '这部分将被高亮显示，';

  @override
  String get highlightSampleText3 => '展示荧光笔效果。';

  @override
  String get colorLightBlue => '浅蓝色';

  @override
  String get colorRed => '红色';

  @override
  String get colorGreen => '绿色';

  @override
  String get colorPurple => '紫色';

  @override
  String get colorGold => '金色';

  @override
  String get colorOrange => '橙色';

  @override
  String get colorYellow => '黄色';

  @override
  String get colorDarkGreen => '深绿色';

  @override
  String get colorCustom => '自定义';

  @override
  String get noteTypeHighlight => '高亮';

  @override
  String get noteTypeUnderline => '下划线';

  @override
  String get noteTypeNote => '笔记';

  @override
  String get noteTypeUnknown => '未知';

  @override
  String get bookFormatTXT => 'TXT';

  @override
  String get bookFormatEPUB => 'EPUB';

  @override
  String get bookFormatPDF => 'PDF';

  @override
  String get importBook => '导入书籍';

  @override
  String get importFromFiles => '从文件导入';

  @override
  String get importNoBooks => '还没有导入任何书籍';

  @override
  String get importSuccess => '书籍导入成功';

  @override
  String get importFailed => '导入失败';

  @override
  String get importProcessing => '正在处理书籍...';

  @override
  String get author => '作者';

  @override
  String get progress => '进度';

  @override
  String get continueReading => '继续阅读';

  @override
  String get recentBooks => '最近阅读';

  @override
  String get allBooks => '全部书籍';

  @override
  String get emptyLibrary => '书库是空的';

  @override
  String get deleteBook => '删除书籍';

  @override
  String get deleteBookConfirm => '确定要删除这本书吗？';

  @override
  String get bookDeleted => '书籍已删除';

  @override
  String get userAgreement => '用户协议';

  @override
  String get acceptAgreement => '我已阅读并同意';

  @override
  String get declineAgreement => '不同意';

  @override
  String get statsToday => '今日';

  @override
  String get statsThisWeek => '本周';

  @override
  String get statsTotal => '总计';

  @override
  String statsMinutes(Object minutes) {
    return '$minutes 分钟';
  }

  @override
  String statsHours(Object hours) {
    return '$hours 小时';
  }

  @override
  String statsBooks(Object count) {
    return '$count 本';
  }

  @override
  String get statsConsecutiveDays => '连续阅读';

  @override
  String get statsFocusTime => '专注时长';

  @override
  String get statsThisWeekTotal => '本周总计';

  @override
  String get statsKeepReading => '坚持每日阅读';

  @override
  String get statsMaxSession => '最长单次';

  @override
  String get statsWeeklyTrend => '周阅读趋势';

  @override
  String get statsAchievements => '阅读成就';

  @override
  String get readerToolbarMenu => '菜单';

  @override
  String get readerToolbarTOC => '目录';

  @override
  String get readerToolbarSettings => '设置';

  @override
  String get readerAddBookmark => '添加书签';

  @override
  String get readerAddNote => '添加笔记';

  @override
  String get readerShare => '分享';

  @override
  String get bookmarkAdded => '已添加书签';

  @override
  String get bookmarkRemoved => '已移除书签';

  @override
  String get readerNavigationTitle => '阅读导航';

  @override
  String readerNavigationPosition(int current, int total) {
    return '第 $current/$total 章';
  }

  @override
  String get readerSearchChapters => '搜索章节';

  @override
  String get readerBackToCurrentChapter => '回到当前章节';

  @override
  String get readerCurrentChapter => '当前';

  @override
  String get readerCurrentPosition => '当前位置';

  @override
  String get readerNoChapterResults => '没有找到相关章节';

  @override
  String get readerNoChapterResultsHint => '尝试使用章节标题中的其他关键词。';

  @override
  String get readerNoBookmarks => '还没有书签';

  @override
  String get readerNoBookmarksHint => '阅读时点击右上角的书签按钮，即可保存当前位置。';

  @override
  String get readerBookmarkRequiresShelf => '加入书架后才能保存书签';

  @override
  String get themeBlue => '海洋蓝';

  @override
  String get themePurple => '神秘紫';

  @override
  String get themeGreen => '森林绿';

  @override
  String get themeOrange => '活力橙';

  @override
  String get themeRed => '热情红';

  @override
  String get themeCustom => '自定义';

  @override
  String get tapZoneLeftRight => '左/右';

  @override
  String get tapZoneLeftCenterRight => '左/中/右';

  @override
  String get homeTagline => '优雅阅读';

  @override
  String get homeReadingStatsTitle => '阅读统计';

  @override
  String get homeTodayReadingMoment => '今日阅读时光';

  @override
  String homeReadMinutesKeepGoing(int minutes) {
    return '已阅读 $minutes 分钟，继续保持';
  }

  @override
  String get homeTodayReadingJourneyStart => '开始今天的阅读之旅吧';

  @override
  String get homeTodayReadingKeepRhythm => '已完成今日阅读，保持节奏';

  @override
  String get homeTodayReadingPrompt => '今天也要留点时间给阅读';

  @override
  String homeTotalReadingHours(String hours) {
    return '累计阅读 $hours 小时';
  }

  @override
  String get homeWeeklyReading => '本周阅读';

  @override
  String get homeTotalReading => '累计阅读';

  @override
  String get homeLibraryCount => '书架藏书';

  @override
  String get homeCollectionCount => '藏书';

  @override
  String get homeKeyMetrics => '关键指标';

  @override
  String get homeReadingRhythm => '阅读节奏';

  @override
  String get homeAchievements => '阅读成就';

  @override
  String get homeConsecutiveReading => '连续阅读';

  @override
  String get homeConsecutiveReadingDesc => '保持每日阅读习惯';

  @override
  String get homeFocusDuration => '专注时长';

  @override
  String get homeFocusDurationDesc => '单次最长阅读时间';

  @override
  String get homeWeeklyTotal => '本周总计';

  @override
  String get homeWeeklyTotalDesc => '本周阅读时长';

  @override
  String get homeRecentReading => '最近阅读';

  @override
  String get homeWeeklyTrend => '本周阅读趋势';

  @override
  String homeBarTooltipMinutes(int minutes) {
    return '$minutes 分钟';
  }

  @override
  String get unitMinute => '分钟';

  @override
  String get unitHour => '小时';

  @override
  String get unitBook => '本';

  @override
  String get unitDay => '天';

  @override
  String get weekdayMonShort => '一';

  @override
  String get weekdayTueShort => '二';

  @override
  String get weekdayWedShort => '三';

  @override
  String get weekdayThuShort => '四';

  @override
  String get weekdayFriShort => '五';

  @override
  String get weekdaySatShort => '六';

  @override
  String get weekdaySunShort => '日';

  @override
  String get agreementTagline => '沉浸阅读 · AI 助手 · 本地优先';

  @override
  String get agreementCardTitle => '用户服务协议';

  @override
  String get agreementCardSubtitle => '请仔细阅读以下内容';

  @override
  String get agreementWelcomeTitle => '欢迎使用开元阅读';

  @override
  String get agreementWelcomeBody => '为保证你获得稳定、可预期的阅读体验，请先阅读并同意以下协议内容。';

  @override
  String get agreementFeatureFormatsTitle => '多格式支持';

  @override
  String get agreementFeatureFormatsBody => 'EPUB、PDF、TXT、MOBI等多种格式';

  @override
  String get agreementFeatureCustomizationTitle => '个性化阅读';

  @override
  String get agreementFeatureCustomizationBody => '自定义字体、颜色、排版等阅读体验';

  @override
  String get agreementFeatureSyncTitle => '本地优先';

  @override
  String get agreementFeatureSyncBody => '书籍、进度与笔记保存在当前设备，由你掌控';

  @override
  String get agreementFeatureTtsTitle => 'TTS朗读';

  @override
  String get agreementFeatureTtsBody => '智能语音朗读，解放双眼，听书更自由';

  @override
  String get agreementTapToAgreeHint => '点击\"同意并继续\"即表示您已阅读并同意使用该应用';

  @override
  String get agreementExitApp => '退出应用';

  @override
  String get agreementAgreeAndContinue => '同意并继续';

  @override
  String get agreementExitDialogContent => '如果您不同意用户协议，将无法使用本应用。确定要退出吗？';

  @override
  String get agreementConfirmExit => '确定退出';

  @override
  String get readerFileMissing => '书籍文件不存在，请重新导入';

  @override
  String get readerUnsupportedFormat => '原生阅读器当前仅支持 EPUB 和 TXT';

  @override
  String get bootstrapDataServiceFailed => '数据系统初始化失败';

  @override
  String get bootstrapImageManagerFailed => '图片管理器初始化失败';

  @override
  String homeFocusCompleted(int minutes) {
    return '$minutes 分钟专注已完成，做得很好。';
  }

  @override
  String get homeDailyReadingGoal => '每日阅读目标';

  @override
  String get homeAiAdviceSection => 'AI 阅读建议';

  @override
  String get homeTodayGlance => '今日速览';

  @override
  String get homeTodayReadingPlan => '今日阅读计划';

  @override
  String get homeViewAll => '查看全部';

  @override
  String get homeSyncingReadingPlan => '正在同步你的阅读计划';

  @override
  String get homeGoalDoneSuggestReview => '今日目标已完成，建议做一次阅读复盘';

  @override
  String homeRemainingToGoal(int minutes) {
    return '还差 $minutes 分钟即可完成今日目标';
  }

  @override
  String get homePickBookHint => '从书架选一本想继续的书，先完成 1 个专注番茄。';

  @override
  String homeContinueBookHint(String title) {
    return '优先继续《$title》，完成后再切换其他书籍。';
  }

  @override
  String get homeTodayActionAdvice => '今日行动建议';

  @override
  String homeProgressPercent(int percent) {
    return '$percent% 进度';
  }

  @override
  String homeStreakDays(int days) {
    return '连读 $days 天';
  }

  @override
  String homeWeekMinutes(int minutes) {
    return '本周 $minutes 分钟';
  }

  @override
  String get homePlanLoading => '计划加载中';

  @override
  String homeGoalMinutesPerDay(int minutes) {
    return '目标 $minutes 分钟/天';
  }

  @override
  String get homeAiAdviceForYou => 'AI 给你的阅读建议';

  @override
  String homeBasedOnBook(String title) {
    return '基于《$title》';
  }

  @override
  String get homeTodayReadingMinutesLabel => '今日阅读（分钟）';

  @override
  String get homeTotalReadingMinutesLabel => '累计阅读（分钟）';

  @override
  String get homeGeneratingPlan => '正在生成今日阅读计划...';

  @override
  String get homeCompletedLabel => '完成';

  @override
  String get homeTodayGoalAchieved => '今日目标已达成';

  @override
  String homeMinutesRemaining(int minutes) {
    return '还差 $minutes 分钟';
  }

  @override
  String homeReadOfGoalMinutes(int read, int goal) {
    return '已读 $read / $goal 分钟';
  }

  @override
  String homeSessionsToFinishGoal(int sessions) {
    return '约 $sessions 次专注可完成今日目标';
  }

  @override
  String get homeStreakLabel => '连击';

  @override
  String get homeWeekAchievedLabel => '周达标';

  @override
  String get homeFocusLabel => '专注';

  @override
  String homeDaysCount(int days) {
    return '$days天';
  }

  @override
  String homeTimesCount(int times) {
    return '$times次';
  }

  @override
  String homeFocusCountdown(String time) {
    return '专注倒计时 $time';
  }

  @override
  String get homeGoLibraryRead => '去书库阅读';

  @override
  String get homeEndFocus => '结束专注';

  @override
  String homeFocusMinutesButton(int minutes) {
    return '专注$minutes分钟';
  }

  @override
  String homeAdjustGoalMinutes(int minutes) {
    return '调整目标：$minutes 分钟';
  }

  @override
  String get homeNoRecentReading => '暂无最近阅读记录，去书库打开一本书开始阅读吧。';

  @override
  String homeReadingProgressPercent(String percent) {
    return '阅读进度 $percent%';
  }

  @override
  String get librarySearchHint => '搜索书名、作者';

  @override
  String libraryFilterAll(int count) {
    return '全部 $count';
  }

  @override
  String libraryFilterReading(int count) {
    return '在读 $count';
  }

  @override
  String libraryFilterFinished(int count) {
    return '已读 $count';
  }

  @override
  String get libraryFilterTooltip => '按阅读状态筛选';

  @override
  String get libraryNoMatchingBooks => '没有匹配的书籍';

  @override
  String get libraryNoReadingBooks => '当前没有在读书籍';

  @override
  String get libraryNoFinishedBooks => '当前没有已读书籍';

  @override
  String get libraryNoBooks => '暂无书籍';

  @override
  String libraryProgressContinue(int percent) {
    return '$percent% · 继续阅读';
  }

  @override
  String libraryPageNumber(int page) {
    return '第 $page 页';
  }

  @override
  String get libraryStartFromBeginning => '从头开始';

  @override
  String get libraryBookInfo => '书籍信息';

  @override
  String libraryFormatAndPages(String format, int pages) {
    return '$format · $pages 页';
  }

  @override
  String get libraryDeleteBookHint => '将永久删除此书籍';

  @override
  String get libraryBookTitle => '书名';

  @override
  String get libraryFormat => '格式';

  @override
  String libraryPagesCount(int pages) {
    return '$pages 页';
  }

  @override
  String get libraryClose => '关闭';

  @override
  String get libraryConfirmDeleteTitle => '确认删除';

  @override
  String libraryDeleteBookMessage(String title) {
    return '确定要删除《$title》吗？文件将从设备中永久移除。';
  }

  @override
  String libraryDeletingBook(String title) {
    return '正在删除《$title》...';
  }

  @override
  String libraryBookDeletedToast(String title) {
    return '《$title》已删除';
  }

  @override
  String libraryDeleteFailed(String error) {
    return '删除失败: $error';
  }

  @override
  String get libraryReadingBadge => '在读';

  @override
  String get libraryDeletingBookFile => '删除书籍文件...';

  @override
  String get libraryDeletingCoverImage => '删除封面图片...';

  @override
  String get libraryCleaningDatabase => '清理数据库记录...';

  @override
  String get libraryDeleteComplete => '删除完成';

  @override
  String get readerPrefaceTitle => '正文前';

  @override
  String get readerModeHorizontalPage => '无动画';

  @override
  String get readerModeVerticalScrollHint => '预分页内容上下连续滑动，左右滑动切换章节';

  @override
  String get readerModeWholeBookScrollHint => '全书预分页后组成可定位的纵向列表';

  @override
  String get readerScrollByChapterTitle => '按章节滚动';

  @override
  String get readerScrollByChapterOnHint => '单章内按页上下滑动，左右滑动切换章节';

  @override
  String get readerScrollByChapterOffHint => '所有章节按页连接为可定位的纵向列表';

  @override
  String get readerModeHorizontalPageHint => '点击左侧上一页，点击右侧下一页';

  @override
  String get readerModeHorizontalSlideHint => '页面跟随手指横向移动并吸附翻页';

  @override
  String get readerModePageCurl => '仿真翻页';

  @override
  String get readerModePageCurlHint => '左右拖动卷起页面，松手后完成翻页或回弹';

  @override
  String readerFontSizeValue(int size) {
    return '字体大小  $size';
  }

  @override
  String readerHorizontalMarginValue(int margin) {
    return '左右页边距  $margin';
  }

  @override
  String get readerHorizontalMarginLabel => '左右页边距';

  @override
  String get readerTopMarginLabel => '上页边距';

  @override
  String get readerBottomMarginLabel => '下页边距';

  @override
  String get readerVerticalMarginLabel => '上下页边距';

  @override
  String readerVerticalMarginValue(int margin) {
    return '上下页边距  $margin';
  }

  @override
  String readerChapterCount(int count) {
    return '$count 章';
  }

  @override
  String readerChapterFallback(int number) {
    return '第 $number 章';
  }

  @override
  String readerOpenFailed(String error) {
    return '打开失败：$error';
  }

  @override
  String get readerNoContent => '书籍没有可显示的正文';

  @override
  String readerStatusPaged(
      int chapter, int chapterCount, int page, int pageCount) {
    return '第 $chapter/$chapterCount 章 · $page/$pageCount 页';
  }

  @override
  String readerStatusScroll(int chapter, int chapterCount) {
    return '第 $chapter/$chapterCount 章 · 纵向滚动';
  }

  @override
  String get importPreparing => '准备导入...';

  @override
  String importFailedWithError(String error) {
    return '导入失败: $error';
  }

  @override
  String get importLocalFile => '本地文件';

  @override
  String get settingsAiTempHintMinimax => 'Temperature: MiniMax 建议 0.01 ~ 1.00';

  @override
  String get settingsAiCustomConfigTitle => '自定义 AI 配置';

  @override
  String settingsAiCurrentProvider(String provider) {
    return '当前服务商：$provider';
  }

  @override
  String get settingsAiTempErrorMinimax =>
      'MiniMax 的 Temperature 必须在 0.01 ~ 1.00 之间';

  @override
  String get settingsAiTempErrorOutOfRange => 'Temperature 超出范围，请按提示填写';

  @override
  String get settingsApply => '应用';

  @override
  String get settingsAiCustomApplied => '已应用自定义参数，记得保存配置';

  @override
  String get settingsAiApiKeyRequired => 'API Key 不能为空';

  @override
  String get settingsAiModelRequired => 'Model 不能为空';

  @override
  String get settingsAiBaseUrlInvalid => 'Base URL 必须是合法的 http/https 地址';

  @override
  String get settingsAiSettingsSaved => 'AI 设置已保存';

  @override
  String settingsSaveFailed(String error) {
    return '保存失败: $error';
  }

  @override
  String get settingsVolumeKeyTurnTitle => '音量键翻页';

  @override
  String get settingsVolumeKeyTurnSubtitle => '在非滚动翻页模式下使用音量键翻页';

  @override
  String get settingsShowStatusBarTitle => '阅读时显示系统状态栏';

  @override
  String get settingsShowStatusBarOnSubtitle => '已隐藏阅读页电量/时间 UI';

  @override
  String get settingsShowStatusBarOffSubtitle => '使用阅读页电量/时间 UI';

  @override
  String get readerTopBarStyleTitle => '顶部信息';

  @override
  String get readerTopBarStyleSystem => '系统状态栏';

  @override
  String get readerTopBarStyleSystemHint => '显示系统时间、信号与电量';

  @override
  String get readerTopBarStyleReader => '阅读信息栏';

  @override
  String get readerTopBarStyleReaderHint => '显示时间、章节标题与电量';

  @override
  String get readerTopBarStyleHidden => '完全沉浸';

  @override
  String get readerTopBarStyleHiddenHint => '顶部不显示任何信息';

  @override
  String get settingsAiAssistantTitle => 'AI 阅读助手';

  @override
  String get settingsSystemSettingsTitle => '系统设置';

  @override
  String get settingsKeepScreenOnTitle => '保持屏幕常亮';

  @override
  String get settingsKeepScreenOnSubtitle => '阅读时防止屏幕自动关闭';

  @override
  String get settingsAutoSaveTitle => '自动保存';

  @override
  String get settingsAutoSaveSubtitle => '自动保存阅读进度';

  @override
  String get settingsHelpPlaceholder => '这里可以放帮助说明';

  @override
  String get settingsAiConfigured => 'AI 已配置';

  @override
  String get settingsAiNotConfigured => '尚未配置 API Key';

  @override
  String get settingsAiReadyToUse => '可直接使用';

  @override
  String get settingsAiPendingConfig => '待配置';

  @override
  String settingsAiCurrentPreset(String preset) {
    return '当前预设：$preset';
  }

  @override
  String settingsAiCurrentCustom(String model) {
    return '当前配置：自定义 · $model';
  }

  @override
  String get settingsAiPresetIntro => '已内置常用服务商和模型，通常只需要选择预设并输入 API Key。';

  @override
  String get settingsAiProviderLabel => '服务商';

  @override
  String get settingsAiPresetHint => '选择预设模型';

  @override
  String get settingsAiPresetLabel => '预设模型';

  @override
  String get settingsAiCustomButton => '自定义';

  @override
  String get settingsAiPresetSelectedHint => '选择预设后只需输入 API Key 即可使用。';

  @override
  String get settingsAiCustomActiveHint => '当前使用自定义参数，可随时切回预设。';

  @override
  String get settingsAiApiKeyHint => '输入后即可启用当前预设';

  @override
  String get settingsShow => '显示';

  @override
  String get settingsHide => '隐藏';

  @override
  String get settingsAiSaving => '保存中...';

  @override
  String get settingsAiSaveConfig => '保存 AI 配置';

  @override
  String get settingsPageIntro => '只保留真正影响阅读体验的选项。';

  @override
  String get settingsDeveloperProductsTitle => '开发者的其他产品';

  @override
  String get settingsXiaoyuanReadingTitle => '小元读书';

  @override
  String get settingsXiaoyuanReadingSubtitle => '面向用户的阅读产品，目前仅提供 iOS 版本';

  @override
  String get settingsXiaoyuanCommunityTitle => '小元读书社区';

  @override
  String get settingsXiaoyuanCommunitySubtitle => '阅读、创作与交流社区';

  @override
  String get settingsDeveloperProductOpenFailed => '无法打开产品网站';

  @override
  String get settingsSupportDevelopmentTitle => '支持开发';

  @override
  String get firstHomeSupportNow => '立即支持';

  @override
  String get firstHomeSupportLater => '再说吧';

  @override
  String get firstHomeSupportPaperSemanticLabel => '开元阅读开发者的自愿支持说明';

  @override
  String get settingsSupportDevelopmentCardTitle => '支持持续开发';

  @override
  String get settingsSupportDevelopmentCardSubtitle =>
      '开发和维护投入了大量时间与精力。如果开元阅读对你有帮助，欢迎自愿捐赠支持。';

  @override
  String get settingsDonationAction => '微信捐赠';

  @override
  String get settingsAlipayDonationAction => '支付宝捐赠';

  @override
  String get settingsDonationDialogTitle => '微信捐赠';

  @override
  String get settingsDonationDialogHint => '请使用微信扫描二维码。感谢你对持续开发的支持。';

  @override
  String get settingsAlipayDonationDialogTitle => '支付宝捐赠';

  @override
  String get settingsAlipayDonationDialogHint => '请使用支付宝扫描二维码。感谢你对持续开发的支持。';

  @override
  String get settingsDonationVoluntaryNotice => '捐赠完全自愿，不影响任何功能，也不构成购买或服务承诺。';

  @override
  String get settingsDonationQrCodeLabel => '微信捐赠二维码';

  @override
  String get settingsAlipayDonationQrCodeLabel => '支付宝捐赠二维码';

  @override
  String get settingsAiSwipeHint => '左右滑动选择模型，点击卡片即可切换。';

  @override
  String get settingsAiLegacyIntro => '选择服务商和模型，填写 API Key 即可。其余参数保持默认。';

  @override
  String get settingsAiModelLabel => '模型';

  @override
  String get settingsAiUsingCustomParams => '正在使用自定义模型参数';

  @override
  String get settingsAiApiKeyStoredLocally => '仅保存在当前设备';

  @override
  String get settingsAiSaveAndEnable => '保存并启用';

  @override
  String get settingsAboutTagline => '开源、跨平台、专注阅读';

  @override
  String get settingsVersionLabel => '版本';

  @override
  String get changelogHistoryTitle => '历史更新日志';

  @override
  String get changelogHistorySubtitle => '查看各版本更新内容';

  @override
  String get openSourceLicensesTitle => '开源许可';

  @override
  String get openSourceLicensesSubtitle => '查看应用、内置字体与第三方组件的许可';

  @override
  String get openSourceLicensesIntro =>
      '以下许可文本随应用离线提供。Open Reading、内置字体及第三方软件分别遵循各自的许可条款。';

  @override
  String get openSourceProjectSection => '项目许可';

  @override
  String get openSourceLegacyLicenseTitle => '历史版本';

  @override
  String get openSourceFontsSection => '内置字体';

  @override
  String get openSourceDependenciesSection => '第三方软件';

  @override
  String get openSourceDependenciesTitle => 'Flutter 与 Dart 依赖';

  @override
  String get openSourceDependenciesSubtitle => '查看由 Flutter 自动收集的第三方软件许可';

  @override
  String get openSourceLicenseLegalese => 'Open Reading 与第三方组件分别遵循各自的许可条款。';

  @override
  String get openSourceLicenseLoadFailed => '无法加载许可文本。';

  @override
  String get changelogPageTitle => '版本更新记录';

  @override
  String get changelogCurrentVersion => '当前版本';

  @override
  String get changelog220TabletSpread => '平板新增可关闭的横屏双页布局，左右页顶部信息分工显示';

  @override
  String get changelog220PageCurl => '重做仿真翻页跟手、跨书脊层级与回弹收尾，修复闪跳、甩尾和遮挡';

  @override
  String get changelog220ReaderPerformance =>
      '优化 TXT 打开转场、书源章节预取和分页复用，降低打开与跨章等待';

  @override
  String get changelog220NavigationThemes => '手机悬浮导航支持图标文字切换，预设与自定义阅读主题可统一排序';

  @override
  String get changelog220ReadingStats => '阅读统计详情页采用统一书卷风格并重新设计各项统计内容';

  @override
  String get changelog220PageOrganization => '页面源码按功能域重新整理，统一文件命名、模块边界和跨域引用';

  @override
  String get changelog220OfficialUpdates =>
      '更新检查新增 GitHub 与官网双来源；Android 可在应用内下载、校验并请求系统安装官网 APK';

  @override
  String get changelog220ReleaseDistribution =>
      '官网新增安装包镜像与下载统计，发布流程强化资产、校验和、APK 版本与签名核验';

  @override
  String get changelog220SourcePolicy => '明确第三方书源责任边界，并新增开发者产品和自愿支持入口';

  @override
  String get changelog203DeveloperProducts => '设置页新增小元读书和小元读书社区入口';

  @override
  String get changelog203Donation => '新增自愿微信和支付宝捐赠入口，并明确不影响任何功能';

  @override
  String get changelog202PaperInformation => '阅读信息栏嵌入每张纸页，横滑和仿真翻页时随页面一起移动';

  @override
  String get changelog202PageNumberInset => '页码向屏幕内侧留出安全距离，避免被圆角遮挡';

  @override
  String get changelog201BackwardPageTurn => '优化上一页仿真翻页，中间起手立即跟手，纵向晃动不再带偏装订边';

  @override
  String get changelog201SnapshotPreheat => '前后相邻页同步预热，减少首次反向翻页卡顿';

  @override
  String get changelog201SourceFilters => '发现页支持全部或单一书源筛选，最新书籍在多个书源间均衡穿插';

  @override
  String get changelog120CustomFonts => '完善自定义字体，支持导入与管理';

  @override
  String get changelog120SystemBars => '美化状态栏与阅读控制栏';

  @override
  String get changelog120BookAnimations => '重做书籍打开与关闭动画';

  @override
  String get changelog120TabletLibrary => '优化平板书库布局';

  @override
  String get changelog120Typography => '优化阅读排版，支持零边距与同页更多文字';

  @override
  String get changelog120VolumeKeys => '接入音量键翻页';

  @override
  String get changelog120Import => '重构书籍导入，适配安全区更易用';

  @override
  String get changelog120Covers => '无封面书籍统一生成简约封面';

  @override
  String get changelog120Licenses => '新增应用内开源许可查看';

  @override
  String get changelog121ContinuousScroll => '在线书源补齐按章节滚动与整书连续滚动';

  @override
  String get changelog121Typography => '修复中文正文左右留白不对称并统一分页绘制';

  @override
  String get changelog124PaperLeaf => '新增纸页化页脚、经典折页动画与阅读排版设置';

  @override
  String get changelog122ContinuousTap => '修复在线连续滚动无法中间点击呼出控制栏';

  @override
  String get changelog200ReaderExperience => '升级顶部信息、纸页页码与仿真翻页体验';

  @override
  String get changelog200CustomThemes => '支持多套自定义阅读主题、图片背景与拖拽排序';

  @override
  String get changelog200Navigation => '优化 EPUB 分页与可折叠多级目录';

  @override
  String get changelog200KeepScreenOn => 'Android 阅读时保持屏幕常亮正式生效';

  @override
  String get changelog110CustomFonts => '新增自定义字体';

  @override
  String get changelog110Bookmarks => '新增加入书签';

  @override
  String get changelog102Summary => '优化发现页、独立搜索和阅读设置';

  @override
  String get changelog101Summary => '新增发现功能、分页搜索和开源许可说明';

  @override
  String get changelog100Summary => '新增开放书源、多主题和仿真翻页';

  @override
  String get changelog091Summary => '新增平板双页布局和跨平台发布支持';

  @override
  String get settingsMaintainerLabel => '维护者';

  @override
  String get settingsLicenseLabel => '许可证';

  @override
  String get settingsViewSourceSubtitle => '查看开源项目';

  @override
  String get settingsJoinQqGroup => '加入 QQ 群';

  @override
  String get settingsQqOpenFailed => '无法打开 QQ，请确认已安装 QQ';

  @override
  String get contributorsTitle => '贡献者';

  @override
  String get contributorsSubtitle => '感谢每一位让 Open Reading 变得更好的人';

  @override
  String get contributorsOpenProfileFailed => '无法打开贡献者主页';

  @override
  String get contributorsEmpty => '暂时没有可展示的贡献者';

  @override
  String get contributorsLoadFailed => '贡献者加载失败，请检查网络后重试';

  @override
  String get settingsDarkModeTitle => '夜间模式';

  @override
  String settingsCurrentValue(String value) {
    return '当前：$value';
  }

  @override
  String get settingsUiStyleTitle => '玻璃效果';

  @override
  String get settingsGlassEffectSubtitle => '开启半透明、背景模糊和悬浮层次效果';

  @override
  String get settingsHideNavigationLabelsTitle => '隐藏底部导航文字';

  @override
  String get settingsHideNavigationLabelsSubtitle => '开启后，手机底部导航栏仅显示图标';

  @override
  String get settingsAccentFollowTheme => '强调色：跟随主题';

  @override
  String settingsAccentValue(String name) {
    return '强调色：$name';
  }

  @override
  String get settingsAppThemeTitle => '应用主题';

  @override
  String settingsCurrentThemeSummary(String theme, String accent) {
    return '当前: $theme · $accent';
  }

  @override
  String get settingsFollowAppTheme => '跟随应用主题';

  @override
  String get settingsAccentColorTitle => '强调色';

  @override
  String get settingsThemeModeSystemHint => '跟随系统外观自动切换';

  @override
  String get settingsThemeModeLightHint => '始终使用浅色外观';

  @override
  String get settingsThemeModeDarkHint => '始终使用深色外观';

  @override
  String get settingsSelectAppTheme => '选择应用主题';

  @override
  String get settingsDone => '完成';

  @override
  String get settingsAccentColorAdvice => '推荐优先选择应用主题，再按需覆盖强调色。';

  @override
  String get settingsAccentFollowThemeOption => '跟随主题';

  @override
  String get settingsAccentFollowThemeDesc => '使用当前应用主题默认强调色';

  @override
  String get settingsAboutTitle => '关于应用';

  @override
  String get settingsAppName => '开元阅读';

  @override
  String get settingsAuthor => '维护者：小元Niki';

  @override
  String get settingsGithubRepo => 'GitHub 仓库';

  @override
  String get settingsNewYearGreeting => '一个专注、克制、可自由修改的跨平台阅读器。';

  @override
  String get settingsGithubOpenFailed => '无法打开 GitHub 链接';

  @override
  String get updateCheckNow => '检查更新';

  @override
  String get updateCheckNowSubtitle => '从 GitHub 或官网获取最新版本';

  @override
  String get updateAvailableTitle => '发现新版本';

  @override
  String updateVersionSummary(String currentVersion, String latestVersion) {
    return '当前版本：$currentVersion\n最新版本：$latestVersion';
  }

  @override
  String get updateNotesTitle => '更新说明';

  @override
  String get updateNotesEmpty => '此版本暂未提供更新说明。';

  @override
  String get updateLater => '稍后';

  @override
  String get updateGoToDownload => '前往更新';

  @override
  String get updateFromGithub => '从 GitHub 更新';

  @override
  String get updateFromWebsite => '前往官网更新';

  @override
  String get updateFromWebsiteInstall => '从官网下载并安装';

  @override
  String get updateWebsiteUnavailable => '官网暂未提供适用于此设备的安装包';

  @override
  String get updateDownloadingTitle => '正在下载更新';

  @override
  String updateDownloadProgress(int percent) {
    return '已下载 $percent%';
  }

  @override
  String get updatePreparingInstaller => '正在校验安装包并准备系统安装程序…';

  @override
  String get updateDownloadFailed => '无法从官网下载更新，请稍后重试';

  @override
  String get updateIntegrityFailed => '安装包完整性校验失败，已删除此次下载';

  @override
  String get updateInstallFailed => '无法安装更新，请检查安装未知应用权限后重试';

  @override
  String get updateAlreadyLatest => '当前已是最新版本';

  @override
  String get updateCheckFailed => '检查更新失败，请稍后重试';

  @override
  String get updateOpenFailed => '无法打开 GitHub Release 下载页面';

  @override
  String get settingsIosOnlyFeature => '该功能仅支持 iOS';

  @override
  String settingsIosSyncResult(String storage, int books, int files) {
    return '已同步到$storage\n书籍 $books 本，文件复制 $files 个';
  }

  @override
  String get settingsRestartRequiredReason => '该设置变更需要重启应用才能完全生效。';

  @override
  String get settingsRestartRequiredTitle => '需要重启应用';

  @override
  String settingsRestartPrompt(String reason) {
    return '$reason\n\n是否现在重启应用？';
  }

  @override
  String get settingsRestartLater => '稍后';

  @override
  String get settingsRestartNow => '重启';

  @override
  String get statsDetailedTitle => '详细统计';

  @override
  String get statsRange7Days => '7天';

  @override
  String get statsRange30Days => '30天';

  @override
  String get statsRange90Days => '90天';

  @override
  String get statsRange1Year => '1年';

  @override
  String get statsRangeAll => '全部';

  @override
  String get statsTabOverview => '总览';

  @override
  String get statsTabCharts => '图表';

  @override
  String get statsTabBooks => '书籍';

  @override
  String get statsTabAchievements => '成就';

  @override
  String get statsReadingOverview => '阅读总览';

  @override
  String statsCumulativeHours(Object hours) {
    return '累计 $hours 小时';
  }

  @override
  String statsStreakEncouragement(Object days) {
    return '保持节奏，你已经连续阅读 $days 天';
  }

  @override
  String get statsTotalDuration => '总时长';

  @override
  String get statsAvgSession => '平均单次';

  @override
  String statsDaysCount(Object count) {
    return '$count 天';
  }

  @override
  String get statsNoData => '暂无数据';

  @override
  String get statsPeriodEarlyMorning => '清晨 05:00-08:59';

  @override
  String get statsPeriodMorning => '上午 09:00-11:59';

  @override
  String get statsPeriodAfternoon => '下午 12:00-17:59';

  @override
  String get statsPeriodEvening => '晚上 18:00-21:59';

  @override
  String get statsPeriodLateNight => '深夜 22:00-04:59';

  @override
  String get statsTotalReadingTime => '总阅读时长';

  @override
  String get statsTotalPagesRead => '总阅读页数';

  @override
  String get statsBooksReadCount => '阅读书籍数';

  @override
  String get statsUnitPage => '页';

  @override
  String get statsTodayProgress => '今日阅读进度';

  @override
  String statsMinutesOfTarget(Object current, Object target) {
    return '$current / $target 分钟';
  }

  @override
  String get statsPagesRead => '阅读页数';

  @override
  String statsPagesOfTarget(Object current, Object target) {
    return '$current / $target 页';
  }

  @override
  String get statsReadingHabits => '阅读习惯分析';

  @override
  String get statsBestReadingPeriod => '最佳阅读时段';

  @override
  String get statsAvgSessionReading => '平均单次阅读';

  @override
  String get statsMaxStreakDays => '最高连读天数';

  @override
  String get statsFocusScore => '阅读专注度';

  @override
  String get statsBookCount => '书籍数量';

  @override
  String get statsTrendAnalysis => '阅读趋势分析';

  @override
  String statsAxisMinutes(Object value) {
    return '$value分';
  }

  @override
  String statsAxisPages(Object value) {
    return '$value页';
  }

  @override
  String statsAxisBooks(Object value) {
    return '$value本';
  }

  @override
  String statsAxisHour(Object hour) {
    return '$hour时';
  }

  @override
  String get statsTimeDistribution => '阅读时间分布';

  @override
  String get statsFormatDistribution => '书籍格式分布';

  @override
  String get statsCompleted => '已完成';

  @override
  String get statsInProgress => '阅读中';

  @override
  String get statsDurationRanking => '阅读时长排行';

  @override
  String get statsProgressRanking => '阅读进度排行';

  @override
  String statsPagesCount(Object count) {
    return '$count页';
  }

  @override
  String statsSessionCount(Object count) {
    return '$count 次会话';
  }

  @override
  String statsAchievementsSummary(Object achieved, Object remaining) {
    return '已获得 $achieved 个成就，还有 $remaining 个等待解锁';
  }

  @override
  String get statsAchievementFirstReadTitle => '初次阅读';

  @override
  String get statsAchievementFirstReadDesc => '完成第一次阅读记录';

  @override
  String get statsAchievementNoviceTitle => '阅读新手';

  @override
  String get statsAchievementNoviceDesc => '累计阅读时长达到10小时';

  @override
  String get statsAchievementBookwormTitle => '书虫';

  @override
  String get statsAchievementBookwormDesc => '累计阅读时长达到100小时';

  @override
  String get statsAchievementExpertTitle => '阅读达人';

  @override
  String get statsAchievementExpertDesc => '连续阅读7天';

  @override
  String get statsAchievementOceanTitle => '知识海洋';

  @override
  String get statsAchievementOceanDesc => '阅读页数达到10000页';

  @override
  String get statsAchievementScholarTitle => '博学者';

  @override
  String get statsAchievementScholarDesc => '阅读10本不同的书籍';

  @override
  String get statsAchievementMarathonTitle => '阅读马拉松';

  @override
  String get statsAchievementMarathonDesc => '连续阅读30天';

  @override
  String get statsAchievementFocusTitle => '专注达人';

  @override
  String get statsAchievementFocusDesc => '累计阅读时长达到500小时';

  @override
  String statsProgressPercent(Object percent) {
    return '进度: $percent%';
  }

  @override
  String get statsGoalProgress => '阅读目标进度';

  @override
  String get statsMonthlyReadingTime => '本月阅读时长';

  @override
  String get statsWeeklyReadingTime => '本周阅读时长';

  @override
  String get statsAvgDailyPages7d => '近7天日均页数';

  @override
  String statsHoursCount(Object count) {
    return '$count小时';
  }

  @override
  String get statsSpeedTrend => '阅读速度趋势';

  @override
  String statsAvgSpeed(Object speed) {
    return '平均: $speed页/分钟';
  }

  @override
  String get statsReadingContinuity => '阅读连续性';

  @override
  String statsCurrentStreak(Object days) {
    return '当前连读: $days天';
  }

  @override
  String get statsHeatmapLess => '少';

  @override
  String get statsHeatmapMore => '多';

  @override
  String statsWeekNumber(Object week) {
    return '第$week周';
  }

  @override
  String get bookSourceAddToShelf => '加入书架';

  @override
  String get bookSourceAddOnline => '在线加入书架';

  @override
  String get bookSourceAddOnlineHint => '不下载全书，阅读时从书源获取并缓存章节';

  @override
  String get bookSourceDownloadLocal => '下载到本地';

  @override
  String get bookSourceDownloadLocalHint => '下载全部章节并作为本地 TXT 加入书架';

  @override
  String get bookSourceAddedOnline => '已在线加入书架';

  @override
  String get bookSourceAlreadyOnShelf => '这本书已在书架中';

  @override
  String get bookSourceDownloading => '正在下载到本地';

  @override
  String get bookSourceFetchingCatalog => '正在获取章节目录…';

  @override
  String bookSourceDownloadProgress(int completed, int total) {
    return '$completed/$total 章';
  }

  @override
  String get bookSourceDownloadComplete => '下载完成，已加入本地书架';

  @override
  String get bookSourceDownloadConverted => '下载完成，已转为本地书籍';

  @override
  String bookSourceDownloadFailed(String error) {
    return '下载失败：$error';
  }

  @override
  String get bookSourceExitAddTitle => '加入书架？';

  @override
  String bookSourceExitAddMessage(String title) {
    return '要把《$title》作为在线书籍加入书架吗？阅读进度会继续保留。';
  }

  @override
  String get bookSourceNotNow => '暂不';

  @override
  String get bookSourceOnlineBadge => '在线';

  @override
  String bookSourceOnlineDataBroken(String error) {
    return '在线书籍信息损坏：$error';
  }

  @override
  String get readerThemeTitle => '阅读主题';

  @override
  String get readerThemeDescription => '仅改变阅读页面与阅读控制栏，不影响应用主题';

  @override
  String get readerThemeDay => '白天';

  @override
  String get readerThemeMist => '晨雾';

  @override
  String get readerThemeGreen => '护眼';

  @override
  String get readerThemeRose => '豆沙';

  @override
  String get readerThemeNavy => '深蓝';

  @override
  String get readerThemeNight => '黑夜';

  @override
  String get readerThemePureBlack => '纯黑';

  @override
  String get readerThemeParchment => '牛皮纸';

  @override
  String get readerThemeCustom => '自定义';

  @override
  String get readerPullBookmarkTitle => '下拉书签';

  @override
  String get readerPullBookmarkHint => '从屏幕顶部向下拉，松手即可添加或移除当前页书签';

  @override
  String get readerPullBookmarkAddHint => '继续下拉以添加书签';

  @override
  String get readerPullBookmarkRemoveHint => '继续下拉以移除书签';

  @override
  String get readerPullBookmarkReleaseHint => '松开完成';

  @override
  String get readerTapAnimationTitle => '点击动画';

  @override
  String get readerTapAnimationHint => '左右点击时使用当前翻页模式的动画；关闭后立即刷新页面';

  @override
  String get readerTabletTwoPageTitle => '平板双页布局';

  @override
  String get readerTabletTwoPageHint => '横屏时并排显示左右两页；关闭后始终使用单页布局';

  @override
  String get readerCustomThemeTitle => '自定义阅读主题';

  @override
  String get readerCustomThemeReset => '重置';

  @override
  String get readerCustomThemeColors => '主题颜色';

  @override
  String get readerCustomThemeTextColor => '字体颜色';

  @override
  String get readerCustomThemeTextColorHint => '正文、标题与主要图标';

  @override
  String get readerCustomThemeBackground => '阅读背景';

  @override
  String get readerCustomThemeBackgroundHint => '纸张与阅读画布的底色';

  @override
  String get readerCustomThemeControlBar => '控制栏颜色';

  @override
  String get readerCustomThemeControlBarHint => '顶部、底部控制栏与设置面板';

  @override
  String get readerCustomThemeContrastGood => '正文与背景对比清晰，适合长时间阅读';

  @override
  String get readerCustomThemeContrastLow => '正文与背景对比较低，可能容易疲劳';

  @override
  String get readerCustomThemeSave => '保存并使用';

  @override
  String get readerCustomThemePreview => '实时预览';

  @override
  String get readerCustomThemePreviewChapter => '第一章 · 风从书页间吹过';

  @override
  String get readerCustomThemePreviewBody =>
      '这是你的阅读空间。调整字体、纸张和控制栏的颜色，让每一页都更贴近自己的阅读习惯。';

  @override
  String get readerCustomThemeHexInvalid => '请输入 6 位十六进制颜色，例如 #F6F0E4';

  @override
  String get readerCustomThemeHexLabel => '十六进制颜色';

  @override
  String get readerCustomThemesTitle => '自定义阅读主题';

  @override
  String get readerCustomThemeAdd => '添加主题';

  @override
  String get readerCustomThemeReorderHint => '长按右侧拖动柄调整顺序，排序会同步到阅读设置的主题列表。';

  @override
  String get readerCustomThemeUse => '使用选中的主题';

  @override
  String get readerCustomThemeDeleteTitle => '删除阅读主题？';

  @override
  String readerCustomThemeDeleteMessage(String name) {
    return '“$name”将从主题列表中删除，已保存的背景图片也会一并清理。';
  }

  @override
  String get readerCustomThemeEmptyTitle => '还没有自定义主题';

  @override
  String get readerCustomThemeEmptyHint => '添加一套属于自己的文字、纸张与背景图片组合。';

  @override
  String get readerCustomThemeNewTitle => '新建阅读主题';

  @override
  String get readerCustomThemeEditTitle => '编辑阅读主题';

  @override
  String get readerCustomThemeName => '主题名称';

  @override
  String get readerCustomThemeNameHint => '例如：雨夜、午后纸张';

  @override
  String get readerCustomThemeBackgroundImage => '背景图片';

  @override
  String get readerCustomThemeBackgroundImageHint =>
      '支持 JPG、PNG、WebP，图片会复制到应用存储中。';

  @override
  String get readerCustomThemeChooseImage => '上传图片';

  @override
  String get readerCustomThemeReplaceImage => '更换图片';

  @override
  String get readerCustomThemeRemoveImage => '移除图片';

  @override
  String get readerCustomThemeImageStrength => '背景图片强度';

  @override
  String get readerCustomThemeImageUnsupported => '当前平台暂不支持导入背景图片';

  @override
  String get readerCustomThemeImageTooLarge => '图片不能超过 20 MB';

  @override
  String get readerCustomThemeImageFormat => '请选择 JPG、PNG 或 WebP 图片';

  @override
  String get readerCustomThemeImageFailed => '背景图片导入失败，请重试';

  @override
  String get importSourceTitle => '添加书籍';

  @override
  String get importSourceDescription => '可以一次选择多本书，确认队列后再开始导入。';

  @override
  String get importSelectFiles => '选择文件';

  @override
  String get importIosSharedDocuments => '我的 iPhone · Open Reading';

  @override
  String get importICloudDrive => 'iCloud Drive · Open Reading';

  @override
  String get importICloudUnavailable => 'iCloud Drive 当前不可用';

  @override
  String get importAndroidFolder => '授权书籍目录';

  @override
  String get importAndroidRescan => '扫描已授权目录';

  @override
  String get importFolderPermissionAvailable => '已授权 · 点击扫描';

  @override
  String get importFolderPermissionLost => '权限已失效 · 请重新授权';

  @override
  String get importRemoveFolder => '移除目录';

  @override
  String importQueueTitle(int count) {
    return '导入队列（$count）';
  }

  @override
  String get importQueueHint => '可先删除误选项，导入时将逐本处理。';

  @override
  String get importQueueEmptyTitle => '还没有选择书籍';

  @override
  String get importQueueEmptyBody => '请选择 EPUB、PDF、TXT、MOBI 或其他支持的书籍文件。';

  @override
  String importAction(int count) {
    return '导入 $count 本';
  }

  @override
  String importRetryFailed(int count) {
    return '重试失败的 $count 本';
  }

  @override
  String get importStatusQueued => '等待中';

  @override
  String get importStatusPreparing => '正在准备文件';

  @override
  String get importStatusChecking => '正在检查';

  @override
  String get importStatusCopying => '正在复制';

  @override
  String get importStatusAnalyzing => '正在解析';

  @override
  String get importStatusSaving => '正在保存';

  @override
  String get importStatusImported => '导入成功';

  @override
  String get importStatusSkipped => '已存在，已跳过';

  @override
  String get importStatusFailed => '导入失败';

  @override
  String get importRemove => '移除';

  @override
  String get importRetry => '重试';

  @override
  String get importClearCompleted => '清除已完成';

  @override
  String get importDone => '完成';

  @override
  String importSummary(int succeeded, int skipped, int failed) {
    return '成功 $succeeded 本 · 跳过 $skipped 本 · 失败 $failed 本';
  }

  @override
  String get importNoSupportedFiles => '没有发现支持的书籍文件';

  @override
  String get importScanning => '正在扫描文件…';
}

/// The translations for Chinese, as used in Taiwan (`zh_TW`).
class AppLocalizationsZhTw extends AppLocalizationsZh {
  AppLocalizationsZhTw() : super('zh_TW');

  @override
  String get appTitle => '開元閱讀';

  @override
  String get home => '首頁';

  @override
  String get library => '書架';

  @override
  String get bookSources => '書源';

  @override
  String get discover => '探索';

  @override
  String get discoverRecommended => '推薦';

  @override
  String get discoverCategories => '分類';

  @override
  String get discoverLatest => '最新';

  @override
  String get discoverLoadFailed => '探索內容載入失敗';

  @override
  String get discoverRetry => '重新載入';

  @override
  String get discoverUnsupportedTitle => '目前書源暫不支援此欄目';

  @override
  String discoverUnsupportedMessage(String capability) {
    return '需要書源提供 $capability 能力；現有書源仍可繼續用於搜尋。';
  }

  @override
  String get discoverCategoryEmpty => '這個分類暫時沒有可顯示的書籍。';

  @override
  String get bookSourceManagementTitle => '書源管理';

  @override
  String get bookSourceManagementSubtitle => '管理內容來源的新增、啟停與協定資訊。探索頁只保留找書體驗。';

  @override
  String get settingsContentSourcesTitle => '內容來源';

  @override
  String get settingsContentSourcesSubtitle => '新增、啟用或移除開放書源';

  @override
  String get bookSourcesSubtitle => '連接開放書源，跨來源搜尋可閱讀內容';

  @override
  String get bookSourcesAdd => '新增書源';

  @override
  String get bookSourcesSearchHint => '輸入書名或作者，搜尋已啟用書源';

  @override
  String get bookSourcesSearch => '搜尋';

  @override
  String get bookSourcesLoadMore => '載入更多';

  @override
  String bookSourcesFailedCount(int count) {
    return '$count 個書源請求失敗';
  }

  @override
  String get bookSourcesSearchPrompt => '新增並啟用書源後，即可在這裡統一搜尋';

  @override
  String get bookSourcesNoResults => '沒有找到符合的書籍';

  @override
  String get bookSourcesNoSourcesTitle => '還沒有書源';

  @override
  String get bookSourcesNoSourcesDescription =>
      '貼上相容 Open Reading Source Protocol 的服務位址即可接入。';

  @override
  String get bookSourcesManageTitle => '已接入書源';

  @override
  String get bookSourcesEnabled => '已啟用';

  @override
  String get bookSourcesDisabled => '已停用';

  @override
  String get bookSourcesRemove => '移除';

  @override
  String get bookSourcesRemoveTitle => '移除書源';

  @override
  String get bookSourcesRemoveMessage => '此操作只移除書源設定，不會刪除本機書籍。';

  @override
  String get bookSourcesCancel => '取消';

  @override
  String get bookSourcesConfirm => '確認';

  @override
  String get bookSourcesAddTitle => '新增開放書源';

  @override
  String get bookSourcesUrlLabel => '書源位址';

  @override
  String get bookSourcesUrlHint => 'https://example.com 或探索文件 URL';

  @override
  String get bookSourcesNoOfficialSourcesNotice =>
      '開元閱讀不預載任何書源，也不營運、推薦或背書第三方書源服務。每個書源位址都由你主動新增。';

  @override
  String get bookSourcesResponsibilityAck =>
      '我確認自己有權存取相關內容，且不會利用書源繞過登入、付費、DRM 或其他存取控制。';

  @override
  String get bookSourcesConnect => '連接並驗證';

  @override
  String get bookSourcesConnecting => '正在驗證協定…';

  @override
  String get bookSourcesAdded => '書源已新增';

  @override
  String get bookSourcesProtocolTitle => 'Open Reading Source Protocol';

  @override
  String get bookSourcesProtocolDescription =>
      '統一探索、搜尋、書籍詳情、目錄與章節內文介面。開發者可架設原生書源，也可為既有合法內容服務撰寫轉接閘道。';

  @override
  String get bookSourcesProtocolDetails => '檢視協定';

  @override
  String get bookSourcesProtocolRepository => '協定開源倉庫';

  @override
  String get bookSourcesProtocolRepositoryOpen => '在 GitHub 檢視';

  @override
  String get bookSourcesProtocolRepositoryOpenFailed => '無法開啟書源協定倉庫';

  @override
  String get bookSourcesProtocolDialogTitle => '開放書源協定 v1.2';

  @override
  String get bookSourcesProtocolDialogBody =>
      '服務在 /.well-known/open-reading-source.json 發布探索文件，並實作搜尋、書籍詳情、章節目錄與章節內文介面。v1.2 為公開、無需登入的 HTTP(S) 書源加入營運者、聯絡方式、內容授權與權利聲明中繼資料。';

  @override
  String get bookSourcesRightsDetails => '營運者與權利資訊';

  @override
  String get bookSourcesOperator => '書源營運者';

  @override
  String get bookSourcesContentLicense => '內容授權';

  @override
  String get bookSourcesRightsStatement => '權利聲明';

  @override
  String get bookSourcesRightsNotProvided => '此書源未提供';

  @override
  String get bookSourcesRightsUnverifiedNotice =>
      '上述資訊由獨立書源營運者自行聲明。開元閱讀僅為提高透明度而顯示，不負責核驗，也不構成推薦或背書。';

  @override
  String get bookSourcesContactOperator => '聯絡營運者';

  @override
  String get bookSourcesRightsReport => '權利申訴';

  @override
  String get bookSourcesRightsReportOpenFailed => '無法開啟權利申訴表單';

  @override
  String get bookSourcesClose => '關閉';

  @override
  String get settings => '設定';

  @override
  String get statistics => '統計';

  @override
  String get reading => '閱讀';

  @override
  String get importBooks => '匯入書籍';

  @override
  String get darkMode => '深色模式';

  @override
  String get lightMode => '淺色模式';

  @override
  String get systemMode => '跟隨系統';

  @override
  String get theme => '主題';

  @override
  String get accent => '強調色';

  @override
  String get bookmarks => '書籤';

  @override
  String get notes => '筆記';

  @override
  String get highlights => '螢光標記';

  @override
  String get ttsReading => '語音朗讀';

  @override
  String get share => '分享';

  @override
  String get shareContent => '分享內容';

  @override
  String get shareCurrentPage => '分享目前頁面';

  @override
  String get shareSelectedText => '分享選取文字';

  @override
  String get shareProgress => '分享閱讀進度';

  @override
  String get play => '播放';

  @override
  String get pause => '暫停';

  @override
  String get stop => '停止';

  @override
  String get speed => '語速';

  @override
  String get pitch => '音調';

  @override
  String get language => '語言';

  @override
  String get fontSize => '字體大小';

  @override
  String get readingProgress => '閱讀進度';

  @override
  String get totalPages => '總頁數';

  @override
  String get currentPage => '目前頁面';

  @override
  String get readingTime => '閱讀時長';

  @override
  String get booksRead => '已讀書籍';

  @override
  String get todayReading => '今日閱讀';

  @override
  String get cancel => '取消';

  @override
  String get confirm => '確認';

  @override
  String get delete => '刪除';

  @override
  String get edit => '編輯';

  @override
  String get save => '儲存';

  @override
  String get back => '返回';

  @override
  String get next => '下一頁';

  @override
  String get previous => '上一頁';

  @override
  String get search => '搜尋';

  @override
  String get noResults => '找不到結果';

  @override
  String get loading => '載入中...';

  @override
  String get error => '錯誤';

  @override
  String get initializationFailed => '初始化失敗';

  @override
  String get unknownError => '未知錯誤';

  @override
  String get retry => '重試';

  @override
  String get appearanceSettings => '外觀設定';

  @override
  String get readingTips => '閱讀提示';

  @override
  String get readingFontSettingsMoved => '閱讀字體設定已移至閱讀介面';

  @override
  String get readingFontSettingsHint =>
      '開啟任意書籍，點擊螢幕中央，在底部控制列中點擊「設定」按鈕，即可調整字體大小、行距、字元間距、頁面邊界與閱讀字體。';

  @override
  String get readingSettings => '閱讀設定';

  @override
  String get enableTts => '啟用朗讀功能';

  @override
  String get enableTtsHint => '開啟文字轉語音朗讀';

  @override
  String get ttsSpeedLabel => '朗讀速度';

  @override
  String get ttsSpeedHint => '調整朗讀的快慢';

  @override
  String get ttsVolumeLabel => '朗讀音量';

  @override
  String get ttsVolumeHint => '調整朗讀音量大小';

  @override
  String get ttsPitchLabel => '音調高低';

  @override
  String get ttsPitchHint => '調整朗讀音調';

  @override
  String get appSettings => '應用程式設定';

  @override
  String get appFont => 'App 字體';

  @override
  String get appFontDescription => '用於導覽、按鈕、設定等介面文字，不影響書籍正文。';

  @override
  String get readerFont => '閱讀字體';

  @override
  String get readerFontDescription => '僅用於書籍正文和章節標題，不影響 App 介面。';

  @override
  String get fontSystem => '系統預設';

  @override
  String get fontSourceHanSerif => '思源宋體';

  @override
  String get fontSourceHanSans => '思源黑體';

  @override
  String get fontJetBrainsMono => 'JetBrains Mono';

  @override
  String get fontInstrumentSans => 'Instrument Sans';

  @override
  String get fontNewsreader => 'Newsreader';

  @override
  String get fontSystemDescription => '跟隨目前裝置和作業系統的原生字體。';

  @override
  String get fontSerifDescription => '沉靜、具出版物氣質的襯線字體，適合長時間閱讀。';

  @override
  String get fontSansSerifDescription => '清晰簡潔的無襯線字體，適合緊湊介面和日常閱讀。';

  @override
  String get fontMonospaceDescription => '等寬字體，適合程式碼、技術內容和專注排版。';

  @override
  String get fontPreviewText => 'Open Reading · 自由閱讀，開卷有益';

  @override
  String get customFonts => '我的字體';

  @override
  String get customFontsEmpty => '尚未匯入字體';

  @override
  String get customFontsEmptyHint => '匯入一次 TTF 或 OTF 檔案，即可用於 App 介面或閱讀正文。';

  @override
  String customFontsCount(int count) {
    return '已匯入 $count 款字體';
  }

  @override
  String get customFontsLocalOnly => '匯入的字體只儲存在目前裝置，不會自動同步。';

  @override
  String get builtInFonts => '內建字體';

  @override
  String get importFont => '匯入字體';

  @override
  String get importingFont => '正在匯入字體…';

  @override
  String get customFontImported => '字體已匯入';

  @override
  String get customFontAlreadyImported => '該字體已經匯入，可以直接使用';

  @override
  String get customFontApplied => '字體設定已更新';

  @override
  String get customFontAppliedToApp => '已匯入並設為 App 字體';

  @override
  String get customFontAppliedToReader => '已匯入並設為閱讀字體';

  @override
  String get customFontImportUnsupported => '目前平台暫不支援持久化匯入字體。';

  @override
  String get customFontUnsupportedFormat => '請選擇 TTF 或 OTF 字體檔案。';

  @override
  String get customFontInvalid => '此檔案不是有效或支援的字體。';

  @override
  String get customFontTooLarge => '字體檔案不可超過 50 MB。';

  @override
  String get customFontReadFailed => '無法讀取字體檔案。';

  @override
  String get customFontLoadFailed => '無法載入此字體。';

  @override
  String get customFontStorageFailed => '無法將字體儲存到目前裝置。';

  @override
  String get customFontUnavailable => '字體檔案不可用，請刪除後重新匯入。';

  @override
  String get setAsAppFont => '設為 App 字體';

  @override
  String get setAsReaderFont => '設為閱讀字體';

  @override
  String get setAsBothFonts => '同時用於兩者';

  @override
  String get renameFont => '重新命名字體';

  @override
  String deleteCustomFontTitle(String name) {
    return '刪除「$name」？';
  }

  @override
  String get deleteCustomFontMessage => '字體檔案將從目前裝置刪除。';

  @override
  String get deleteCustomFontInUse => '此字體正在使用。刪除後，受影響的字體設定將恢復為預設值。';

  @override
  String get deleteAndReset => '刪除並恢復預設';

  @override
  String get settingsTelegramChannel => 'Telegram';

  @override
  String get settingsTelegramSubtitle => 'Telegram 官方頻道';

  @override
  String get settingsTelegramOpenFailed => '無法開啟 Telegram 連結';

  @override
  String get settingsQqChannel => 'QQ 頻道';

  @override
  String get settingsQqChannelSubtitle => '開元閱讀 · OpenReading6';

  @override
  String get settingsQqChannelOpenFailed => '無法開啟 QQ 頻道邀請連結';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get typographySettings => '排版設定';

  @override
  String get fontFamilyLabel => '字體';

  @override
  String get fontSizeLabel => '字體大小';

  @override
  String get lineSpacingLabel => '行距';

  @override
  String get letterSpacingLabel => '字距';

  @override
  String get firstLineIndentLabel => '首行縮排';

  @override
  String get paragraphSpacingLabel => '段落間距';

  @override
  String get pageMarginLabel => '頁面邊界';

  @override
  String get resetDefault => '恢復預設';

  @override
  String get ttsPanelTitle => '語音朗讀';

  @override
  String get ttsPreviewEffect => '預覽效果';

  @override
  String get ttsVolume => '音量';

  @override
  String get ttsPitch => '音調';

  @override
  String get ttsSpeed => '語速';

  @override
  String get ttsPreviousSentence => '上一句';

  @override
  String get ttsNextSentence => '下一句';

  @override
  String get ttsTimerStop => '定時停止';

  @override
  String get ttsTimerOff => '不限時';

  @override
  String ttsTimerMinutes(Object minutes) {
    return '$minutes 分鐘後停止';
  }

  @override
  String get ttsPlaying => '正在播放';

  @override
  String get ttsPaused => '已暫停';

  @override
  String get ttsStopped => '已停止';

  @override
  String get ttsPreviousSentenceFailed => '上一句失敗';

  @override
  String get ttsNextSentenceFailed => '下一句失敗';

  @override
  String get ttsEmptyContentError => '目前頁面內容為空';

  @override
  String get ttsPlaybackFailed => '播放失敗';

  @override
  String get ttsOperationFailed => '操作失敗';

  @override
  String get pageTurningMode => '翻頁模式';

  @override
  String get pageTurningSlide => '水平滑動';

  @override
  String get pageTurningScroll => '上下翻頁';

  @override
  String get tapZoneSettings => '點擊翻頁區域';

  @override
  String get tapZoneNextPage => '下一頁';

  @override
  String get tapZonePreviousPage => '上一頁';

  @override
  String get tapZoneMenu => '選單';

  @override
  String get tapZoneLegend => '圖例';

  @override
  String get highlightColor => '螢光筆顏色';

  @override
  String get highlightPreview => '預覽效果';

  @override
  String get highlightSampleText => '這是一段範例文字，';

  @override
  String get highlightSampleText2 => '這部分將被標記顯示，';

  @override
  String get highlightSampleText3 => '展示螢光筆效果。';

  @override
  String get colorLightBlue => '淺藍色';

  @override
  String get colorRed => '紅色';

  @override
  String get colorGreen => '綠色';

  @override
  String get colorPurple => '紫色';

  @override
  String get colorGold => '金色';

  @override
  String get colorOrange => '橙色';

  @override
  String get colorYellow => '黃色';

  @override
  String get colorDarkGreen => '深綠色';

  @override
  String get colorCustom => '自訂';

  @override
  String get noteTypeHighlight => '螢光標記';

  @override
  String get noteTypeUnderline => '底線';

  @override
  String get noteTypeNote => '筆記';

  @override
  String get noteTypeUnknown => '未知';

  @override
  String get bookFormatTXT => 'TXT';

  @override
  String get bookFormatEPUB => 'EPUB';

  @override
  String get bookFormatPDF => 'PDF';

  @override
  String get importBook => '匯入書籍';

  @override
  String get importFromFiles => '從檔案匯入';

  @override
  String get importNoBooks => '還沒有匯入任何書籍';

  @override
  String get importSuccess => '書籍匯入成功';

  @override
  String get importFailed => '匯入失敗';

  @override
  String get importProcessing => '正在處理書籍...';

  @override
  String get author => '作者';

  @override
  String get progress => '進度';

  @override
  String get continueReading => '繼續閱讀';

  @override
  String get recentBooks => '最近閱讀';

  @override
  String get allBooks => '全部書籍';

  @override
  String get emptyLibrary => '書庫是空的';

  @override
  String get deleteBook => '刪除書籍';

  @override
  String get deleteBookConfirm => '確定要刪除這本書嗎？';

  @override
  String get bookDeleted => '書籍已刪除';

  @override
  String get userAgreement => '使用者條款';

  @override
  String get acceptAgreement => '我已閱讀並同意';

  @override
  String get declineAgreement => '不同意';

  @override
  String get statsToday => '今日';

  @override
  String get statsThisWeek => '本週';

  @override
  String get statsTotal => '總計';

  @override
  String statsMinutes(Object minutes) {
    return '$minutes 分鐘';
  }

  @override
  String statsHours(Object hours) {
    return '$hours 小時';
  }

  @override
  String statsBooks(Object count) {
    return '$count 本';
  }

  @override
  String get statsConsecutiveDays => '連續閱讀';

  @override
  String get statsFocusTime => '專注時長';

  @override
  String get statsThisWeekTotal => '本週總計';

  @override
  String get statsKeepReading => '堅持每日閱讀';

  @override
  String get statsMaxSession => '最長單次';

  @override
  String get statsWeeklyTrend => '週閱讀趨勢';

  @override
  String get statsAchievements => '閱讀成就';

  @override
  String get readerToolbarMenu => '選單';

  @override
  String get readerToolbarTOC => '目錄';

  @override
  String get readerToolbarSettings => '設定';

  @override
  String get readerAddBookmark => '新增書籤';

  @override
  String get readerAddNote => '新增筆記';

  @override
  String get readerShare => '分享';

  @override
  String get bookmarkAdded => '已新增書籤';

  @override
  String get bookmarkRemoved => '已移除書籤';

  @override
  String get readerNavigationTitle => '閱讀導覽';

  @override
  String readerNavigationPosition(int current, int total) {
    return '第 $current/$total 章';
  }

  @override
  String get readerSearchChapters => '搜尋章節';

  @override
  String get readerBackToCurrentChapter => '回到目前章節';

  @override
  String get readerCurrentChapter => '目前';

  @override
  String get readerCurrentPosition => '目前位置';

  @override
  String get readerNoChapterResults => '找不到相關章節';

  @override
  String get readerNoChapterResultsHint => '請嘗試章節標題中的其他關鍵字。';

  @override
  String get readerNoBookmarks => '還沒有書籤';

  @override
  String get readerNoBookmarksHint => '閱讀時點擊右上角的書籤按鈕，即可儲存目前位置。';

  @override
  String get readerBookmarkRequiresShelf => '加入書架後才能儲存書籤';

  @override
  String get themeBlue => '海洋藍';

  @override
  String get themePurple => '神秘紫';

  @override
  String get themeGreen => '森林綠';

  @override
  String get themeOrange => '活力橙';

  @override
  String get themeRed => '熱情紅';

  @override
  String get themeCustom => '自訂';

  @override
  String get tapZoneLeftRight => '左/右';

  @override
  String get tapZoneLeftCenterRight => '左/中/右';

  @override
  String get homeTagline => '優雅閱讀';

  @override
  String get homeReadingStatsTitle => '閱讀統計';

  @override
  String get homeTodayReadingMoment => '今日閱讀時光';

  @override
  String homeReadMinutesKeepGoing(int minutes) {
    return '已閱讀 $minutes 分鐘，繼續保持';
  }

  @override
  String get homeTodayReadingJourneyStart => '開始今天的閱讀之旅吧';

  @override
  String get homeTodayReadingKeepRhythm => '已完成今日閱讀，保持節奏';

  @override
  String get homeTodayReadingPrompt => '今天也要留點時間給閱讀';

  @override
  String homeTotalReadingHours(String hours) {
    return '累計閱讀 $hours 小時';
  }

  @override
  String get homeWeeklyReading => '本週閱讀';

  @override
  String get homeTotalReading => '累計閱讀';

  @override
  String get homeLibraryCount => '書架藏書';

  @override
  String get homeCollectionCount => '藏書';

  @override
  String get homeKeyMetrics => '關鍵指標';

  @override
  String get homeReadingRhythm => '閱讀節奏';

  @override
  String get homeAchievements => '閱讀成就';

  @override
  String get homeConsecutiveReading => '連續閱讀';

  @override
  String get homeConsecutiveReadingDesc => '保持每日閱讀習慣';

  @override
  String get homeFocusDuration => '專注時長';

  @override
  String get homeFocusDurationDesc => '單次最長閱讀時間';

  @override
  String get homeWeeklyTotal => '本週總計';

  @override
  String get homeWeeklyTotalDesc => '本週閱讀時長';

  @override
  String get homeRecentReading => '最近閱讀';

  @override
  String get homeWeeklyTrend => '本週閱讀趨勢';

  @override
  String homeBarTooltipMinutes(int minutes) {
    return '$minutes 分鐘';
  }

  @override
  String get unitMinute => '分鐘';

  @override
  String get unitHour => '小時';

  @override
  String get unitBook => '本';

  @override
  String get unitDay => '天';

  @override
  String get weekdayMonShort => '一';

  @override
  String get weekdayTueShort => '二';

  @override
  String get weekdayWedShort => '三';

  @override
  String get weekdayThuShort => '四';

  @override
  String get weekdayFriShort => '五';

  @override
  String get weekdaySatShort => '六';

  @override
  String get weekdaySunShort => '日';

  @override
  String get agreementTagline => '沉浸閱讀 · AI 助手 · 本機優先';

  @override
  String get agreementCardTitle => '使用者服務條款';

  @override
  String get agreementCardSubtitle => '請仔細閱讀以下內容';

  @override
  String get agreementWelcomeTitle => '歡迎使用開元閱讀';

  @override
  String get agreementWelcomeBody => '為確保你獲得穩定、可預期的閱讀體驗，請先閱讀並同意以下條款內容。';

  @override
  String get agreementFeatureFormatsTitle => '多格式支援';

  @override
  String get agreementFeatureFormatsBody => 'EPUB、PDF、TXT、MOBI 等多種格式';

  @override
  String get agreementFeatureCustomizationTitle => '個人化閱讀';

  @override
  String get agreementFeatureCustomizationBody => '自訂字體、顏色、排版等閱讀體驗';

  @override
  String get agreementFeatureSyncTitle => '本機優先';

  @override
  String get agreementFeatureSyncBody => '書籍、進度與筆記儲存在目前裝置，由你掌控';

  @override
  String get agreementFeatureTtsTitle => 'TTS 朗讀';

  @override
  String get agreementFeatureTtsBody => '智慧語音朗讀，解放雙眼，聽書更自由';

  @override
  String get agreementTapToAgreeHint => '點擊「同意並繼續」即表示您已閱讀並同意使用本應用程式';

  @override
  String get agreementExitApp => '離開應用程式';

  @override
  String get agreementAgreeAndContinue => '同意並繼續';

  @override
  String get agreementExitDialogContent => '如果您不同意使用者條款，將無法使用本應用程式。確定要離開嗎？';

  @override
  String get agreementConfirmExit => '確定離開';

  @override
  String get readerFileMissing => '書籍檔案不存在，請重新匯入';

  @override
  String get readerUnsupportedFormat => '原生閱讀器目前僅支援 EPUB 和 TXT';

  @override
  String get bootstrapDataServiceFailed => '資料系統初始化失敗';

  @override
  String get bootstrapImageManagerFailed => '圖片管理器初始化失敗';

  @override
  String homeFocusCompleted(int minutes) {
    return '$minutes 分鐘專注已完成，做得很好。';
  }

  @override
  String get homeDailyReadingGoal => '每日閱讀目標';

  @override
  String get homeAiAdviceSection => 'AI 閱讀建議';

  @override
  String get homeTodayGlance => '今日速覽';

  @override
  String get homeTodayReadingPlan => '今日閱讀計畫';

  @override
  String get homeViewAll => '檢視全部';

  @override
  String get homeSyncingReadingPlan => '正在同步你的閱讀計畫';

  @override
  String get homeGoalDoneSuggestReview => '今日目標已完成，建議做一次閱讀回顧';

  @override
  String homeRemainingToGoal(int minutes) {
    return '還差 $minutes 分鐘即可完成今日目標';
  }

  @override
  String get homePickBookHint => '從書架選一本想繼續的書，先完成 1 個專注番茄鐘。';

  @override
  String homeContinueBookHint(String title) {
    return '優先繼續《$title》，完成後再切換其他書籍。';
  }

  @override
  String get homeTodayActionAdvice => '今日行動建議';

  @override
  String homeProgressPercent(int percent) {
    return '$percent% 進度';
  }

  @override
  String homeStreakDays(int days) {
    return '連讀 $days 天';
  }

  @override
  String homeWeekMinutes(int minutes) {
    return '本週 $minutes 分鐘';
  }

  @override
  String get homePlanLoading => '計畫載入中';

  @override
  String homeGoalMinutesPerDay(int minutes) {
    return '目標 $minutes 分鐘/天';
  }

  @override
  String get homeAiAdviceForYou => 'AI 給你的閱讀建議';

  @override
  String homeBasedOnBook(String title) {
    return '根據《$title》';
  }

  @override
  String get homeTodayReadingMinutesLabel => '今日閱讀（分鐘）';

  @override
  String get homeTotalReadingMinutesLabel => '累計閱讀（分鐘）';

  @override
  String get homeGeneratingPlan => '正在產生今日閱讀計畫...';

  @override
  String get homeCompletedLabel => '完成';

  @override
  String get homeTodayGoalAchieved => '今日目標已達成';

  @override
  String homeMinutesRemaining(int minutes) {
    return '還差 $minutes 分鐘';
  }

  @override
  String homeReadOfGoalMinutes(int read, int goal) {
    return '已讀 $read / $goal 分鐘';
  }

  @override
  String homeSessionsToFinishGoal(int sessions) {
    return '約 $sessions 次專注可完成今日目標';
  }

  @override
  String get homeStreakLabel => '連續';

  @override
  String get homeWeekAchievedLabel => '週達標';

  @override
  String get homeFocusLabel => '專注';

  @override
  String homeDaysCount(int days) {
    return '$days天';
  }

  @override
  String homeTimesCount(int times) {
    return '$times次';
  }

  @override
  String homeFocusCountdown(String time) {
    return '專注倒數 $time';
  }

  @override
  String get homeGoLibraryRead => '去書庫閱讀';

  @override
  String get homeEndFocus => '結束專注';

  @override
  String homeFocusMinutesButton(int minutes) {
    return '專注 $minutes 分鐘';
  }

  @override
  String homeAdjustGoalMinutes(int minutes) {
    return '調整目標：$minutes 分鐘';
  }

  @override
  String get homeNoRecentReading => '暫無最近閱讀紀錄，去書庫開啟一本書開始閱讀吧。';

  @override
  String homeReadingProgressPercent(String percent) {
    return '閱讀進度 $percent%';
  }

  @override
  String get librarySearchHint => '搜尋書名、作者';

  @override
  String libraryFilterAll(int count) {
    return '全部 $count';
  }

  @override
  String libraryFilterReading(int count) {
    return '在讀 $count';
  }

  @override
  String libraryFilterFinished(int count) {
    return '已讀 $count';
  }

  @override
  String get libraryFilterTooltip => '按閱讀狀態篩選';

  @override
  String get libraryNoMatchingBooks => '沒有符合的書籍';

  @override
  String get libraryNoReadingBooks => '目前沒有在讀書籍';

  @override
  String get libraryNoFinishedBooks => '目前沒有已讀書籍';

  @override
  String get libraryNoBooks => '暫無書籍';

  @override
  String libraryProgressContinue(int percent) {
    return '$percent% · 繼續閱讀';
  }

  @override
  String libraryPageNumber(int page) {
    return '第 $page 頁';
  }

  @override
  String get libraryStartFromBeginning => '從頭開始';

  @override
  String get libraryBookInfo => '書籍資訊';

  @override
  String libraryFormatAndPages(String format, int pages) {
    return '$format · $pages 頁';
  }

  @override
  String get libraryDeleteBookHint => '將永久刪除此書籍';

  @override
  String get libraryBookTitle => '書名';

  @override
  String get libraryFormat => '格式';

  @override
  String libraryPagesCount(int pages) {
    return '$pages 頁';
  }

  @override
  String get libraryClose => '關閉';

  @override
  String get libraryConfirmDeleteTitle => '確認刪除';

  @override
  String libraryDeleteBookMessage(String title) {
    return '確定要刪除《$title》嗎？檔案將從裝置中永久移除。';
  }

  @override
  String libraryDeletingBook(String title) {
    return '正在刪除《$title》...';
  }

  @override
  String libraryBookDeletedToast(String title) {
    return '《$title》已刪除';
  }

  @override
  String libraryDeleteFailed(String error) {
    return '刪除失敗：$error';
  }

  @override
  String get libraryReadingBadge => '在讀';

  @override
  String get libraryDeletingBookFile => '刪除書籍檔案...';

  @override
  String get libraryDeletingCoverImage => '刪除封面圖片...';

  @override
  String get libraryCleaningDatabase => '清理資料庫紀錄...';

  @override
  String get libraryDeleteComplete => '刪除完成';

  @override
  String get readerPrefaceTitle => '內文前';

  @override
  String get readerModeHorizontalPage => '無動畫';

  @override
  String get readerModeVerticalScrollHint => '預先分頁後上下連續滑動，左右滑動切換章節';

  @override
  String get readerModeWholeBookScrollHint => '全書預先分頁後組成可定位的縱向列表';

  @override
  String get readerScrollByChapterTitle => '按章節捲動';

  @override
  String get readerScrollByChapterOnHint => '單章內按頁上下滑動，左右滑動切換章節';

  @override
  String get readerScrollByChapterOffHint => '所有章節按頁連接為可定位的縱向列表';

  @override
  String get readerModeHorizontalPageHint => '點擊左側上一頁，點擊右側下一頁';

  @override
  String get readerModeHorizontalSlideHint => '頁面跟隨手指橫向移動並吸附翻頁';

  @override
  String get readerModePageCurl => '仿真翻頁';

  @override
  String get readerModePageCurlHint => '左右拖動捲起頁面，放開後完成翻頁或回彈';

  @override
  String readerFontSizeValue(int size) {
    return '字體大小  $size';
  }

  @override
  String readerHorizontalMarginValue(int margin) {
    return '左右頁面邊界  $margin';
  }

  @override
  String get readerHorizontalMarginLabel => '左右頁邊距';

  @override
  String get readerTopMarginLabel => '上頁邊距';

  @override
  String get readerBottomMarginLabel => '下頁邊距';

  @override
  String get readerVerticalMarginLabel => '上下頁邊距';

  @override
  String readerVerticalMarginValue(int margin) {
    return '上下頁面邊界  $margin';
  }

  @override
  String readerChapterCount(int count) {
    return '$count 章';
  }

  @override
  String readerChapterFallback(int number) {
    return '第 $number 章';
  }

  @override
  String readerOpenFailed(String error) {
    return '開啟失敗：$error';
  }

  @override
  String get readerNoContent => '書籍沒有可顯示的內文';

  @override
  String readerStatusPaged(
      int chapter, int chapterCount, int page, int pageCount) {
    return '第 $chapter/$chapterCount 章 · $page/$pageCount 頁';
  }

  @override
  String readerStatusScroll(int chapter, int chapterCount) {
    return '第 $chapter/$chapterCount 章 · 縱向捲動';
  }

  @override
  String get importPreparing => '準備匯入...';

  @override
  String importFailedWithError(String error) {
    return '匯入失敗：$error';
  }

  @override
  String get importLocalFile => '本機檔案';

  @override
  String get settingsAiTempHintMinimax => 'Temperature：MiniMax 建議 0.01 ~ 1.00';

  @override
  String get settingsAiCustomConfigTitle => '自訂 AI 設定';

  @override
  String settingsAiCurrentProvider(String provider) {
    return '目前服務商：$provider';
  }

  @override
  String get settingsAiTempErrorMinimax =>
      'MiniMax 的 Temperature 必須在 0.01 ~ 1.00 之間';

  @override
  String get settingsAiTempErrorOutOfRange => 'Temperature 超出範圍，請按提示填寫';

  @override
  String get settingsApply => '套用';

  @override
  String get settingsAiCustomApplied => '已套用自訂參數，記得儲存設定';

  @override
  String get settingsAiApiKeyRequired => 'API Key 不能為空';

  @override
  String get settingsAiModelRequired => 'Model 不能為空';

  @override
  String get settingsAiBaseUrlInvalid => 'Base URL 必須是合法的 http/https 位址';

  @override
  String get settingsAiSettingsSaved => 'AI 設定已儲存';

  @override
  String settingsSaveFailed(String error) {
    return '儲存失敗：$error';
  }

  @override
  String get settingsVolumeKeyTurnTitle => '音量鍵翻頁';

  @override
  String get settingsVolumeKeyTurnSubtitle => '在非捲動翻頁模式下使用音量鍵翻頁';

  @override
  String get settingsShowStatusBarTitle => '閱讀時顯示系統狀態列';

  @override
  String get settingsShowStatusBarOnSubtitle => '已隱藏閱讀頁電量/時間 UI';

  @override
  String get settingsShowStatusBarOffSubtitle => '使用閱讀頁電量/時間 UI';

  @override
  String get readerTopBarStyleTitle => '頂部資訊';

  @override
  String get readerTopBarStyleSystem => '系統狀態列';

  @override
  String get readerTopBarStyleSystemHint => '顯示系統時間、訊號與電量';

  @override
  String get readerTopBarStyleReader => '閱讀資訊列';

  @override
  String get readerTopBarStyleReaderHint => '顯示時間、章節標題與電量';

  @override
  String get readerTopBarStyleHidden => '完全沉浸';

  @override
  String get readerTopBarStyleHiddenHint => '頂部不顯示任何資訊';

  @override
  String get settingsAiAssistantTitle => 'AI 閱讀助手';

  @override
  String get settingsSystemSettingsTitle => '系統設定';

  @override
  String get settingsKeepScreenOnTitle => '保持螢幕恆亮';

  @override
  String get settingsKeepScreenOnSubtitle => '閱讀時防止螢幕自動關閉';

  @override
  String get settingsAutoSaveTitle => '自動儲存';

  @override
  String get settingsAutoSaveSubtitle => '自動儲存閱讀進度';

  @override
  String get settingsHelpPlaceholder => '這裡可以放說明資訊';

  @override
  String get settingsAiConfigured => 'AI 已設定';

  @override
  String get settingsAiNotConfigured => '尚未設定 API Key';

  @override
  String get settingsAiReadyToUse => '可直接使用';

  @override
  String get settingsAiPendingConfig => '待設定';

  @override
  String settingsAiCurrentPreset(String preset) {
    return '目前預設組合：$preset';
  }

  @override
  String settingsAiCurrentCustom(String model) {
    return '目前設定：自訂 · $model';
  }

  @override
  String get settingsAiPresetIntro => '已內建常用服務商和模型，通常只需要選擇預設組合並輸入 API Key。';

  @override
  String get settingsAiProviderLabel => '服務商';

  @override
  String get settingsAiPresetHint => '選擇預設模型';

  @override
  String get settingsAiPresetLabel => '預設模型';

  @override
  String get settingsAiCustomButton => '自訂';

  @override
  String get settingsAiPresetSelectedHint => '選擇預設組合後只需輸入 API Key 即可使用。';

  @override
  String get settingsAiCustomActiveHint => '目前使用自訂參數，可隨時切回預設組合。';

  @override
  String get settingsAiApiKeyHint => '輸入後即可啟用目前預設組合';

  @override
  String get settingsShow => '顯示';

  @override
  String get settingsHide => '隱藏';

  @override
  String get settingsAiSaving => '儲存中...';

  @override
  String get settingsAiSaveConfig => '儲存 AI 設定';

  @override
  String get settingsPageIntro => '只保留真正影響閱讀體驗的選項。';

  @override
  String get settingsDeveloperProductsTitle => '開發者的其他產品';

  @override
  String get settingsXiaoyuanReadingTitle => '小元读书';

  @override
  String get settingsXiaoyuanReadingSubtitle => '面向使用者的閱讀產品，目前僅提供 iOS 版本';

  @override
  String get settingsXiaoyuanCommunityTitle => '小元读书社区';

  @override
  String get settingsXiaoyuanCommunitySubtitle => '閱讀、創作與交流社群';

  @override
  String get settingsDeveloperProductOpenFailed => '無法開啟產品網站';

  @override
  String get settingsSupportDevelopmentTitle => '支持開發';

  @override
  String get firstHomeSupportNow => '立即支持';

  @override
  String get firstHomeSupportLater => '再說吧';

  @override
  String get firstHomeSupportPaperSemanticLabel => '開元閱讀開發者的自願支持說明';

  @override
  String get settingsSupportDevelopmentCardTitle => '支持持續開發';

  @override
  String get settingsSupportDevelopmentCardSubtitle =>
      '開發與維護投入了大量時間和心力。如果開元閱讀對你有幫助，歡迎自願捐贈支持。';

  @override
  String get settingsDonationAction => '微信捐贈';

  @override
  String get settingsAlipayDonationAction => '支付寶捐贈';

  @override
  String get settingsDonationDialogTitle => '微信捐贈';

  @override
  String get settingsDonationDialogHint => '請使用微信掃描二維碼。感謝你對持續開發的支持。';

  @override
  String get settingsAlipayDonationDialogTitle => '支付寶捐贈';

  @override
  String get settingsAlipayDonationDialogHint => '請使用支付寶掃描二維碼。感謝你對持續開發的支持。';

  @override
  String get settingsDonationVoluntaryNotice => '捐贈完全自願，不影響任何功能，也不構成購買或服務承諾。';

  @override
  String get settingsDonationQrCodeLabel => '微信捐贈二維碼';

  @override
  String get settingsAlipayDonationQrCodeLabel => '支付寶捐贈二維碼';

  @override
  String get settingsAiSwipeHint => '左右滑動選擇模型，點擊卡片即可切換。';

  @override
  String get settingsAiLegacyIntro => '選擇服務商和模型，填寫 API Key 即可。其餘參數保持預設。';

  @override
  String get settingsAiModelLabel => '模型';

  @override
  String get settingsAiUsingCustomParams => '正在使用自訂模型參數';

  @override
  String get settingsAiApiKeyStoredLocally => '僅儲存在目前裝置';

  @override
  String get settingsAiSaveAndEnable => '儲存並啟用';

  @override
  String get settingsAboutTagline => '開源、跨平台、專注閱讀';

  @override
  String get settingsVersionLabel => '版本';

  @override
  String get changelogHistoryTitle => '歷史更新日誌';

  @override
  String get changelogHistorySubtitle => '查看各版本更新內容';

  @override
  String get openSourceLicensesTitle => '開源授權';

  @override
  String get openSourceLicensesSubtitle => '查看應用程式、內建字型與第三方元件的授權';

  @override
  String get openSourceLicensesIntro =>
      '以下授權文字隨應用程式離線提供。Open Reading、內建字型及第三方軟體分別適用各自的授權條款。';

  @override
  String get openSourceProjectSection => '專案授權';

  @override
  String get openSourceLegacyLicenseTitle => '歷史版本';

  @override
  String get openSourceFontsSection => '內建字型';

  @override
  String get openSourceDependenciesSection => '第三方軟體';

  @override
  String get openSourceDependenciesTitle => 'Flutter 與 Dart 相依套件';

  @override
  String get openSourceDependenciesSubtitle => '查看由 Flutter 自動彙整的第三方軟體授權';

  @override
  String get openSourceLicenseLegalese => 'Open Reading 與第三方元件分別適用各自的授權條款。';

  @override
  String get openSourceLicenseLoadFailed => '無法載入授權文字。';

  @override
  String get changelogPageTitle => '版本更新記錄';

  @override
  String get changelogCurrentVersion => '目前版本';

  @override
  String get changelog220TabletSpread => '平板新增可關閉的橫向雙頁版面，左右頁頂部資訊分工顯示';

  @override
  String get changelog220PageCurl => '重做擬真翻頁跟手、跨書脊層級與回彈收尾，修正跳動、甩尾和遮擋';

  @override
  String get changelog220ReaderPerformance =>
      '最佳化 TXT 開啟轉場、書源章節預取與分頁重用，減少開啟和跨章等待';

  @override
  String get changelog220NavigationThemes => '手機懸浮導覽支援圖示文字切換，預設與自訂閱讀主題可統一排序';

  @override
  String get changelog220ReadingStats => '閱讀統計詳情頁採用統一書卷風格並重新設計各項統計內容';

  @override
  String get changelog220PageOrganization => '頁面原始碼依功能領域重新整理，統一檔案命名、模組邊界與跨領域引用';

  @override
  String get changelog220OfficialUpdates =>
      '更新檢查新增 GitHub 與官網雙來源；Android 可在應用程式內下載、校驗並請求系統安裝官網 APK';

  @override
  String get changelog220ReleaseDistribution =>
      '官網新增安裝檔鏡像與下載統計，發布流程加強資產、校驗和、APK 版本與簽章驗證';

  @override
  String get changelog220SourcePolicy => '明確第三方書源責任邊界，並新增開發者產品和自願支持入口';

  @override
  String get changelog203DeveloperProducts => '設定頁新增小元读书和小元读书社区入口';

  @override
  String get changelog203Donation => '新增自願微信和支付寶捐贈入口，並明確不影響任何功能';

  @override
  String get changelog202PaperInformation => '閱讀資訊列嵌入每張紙頁，橫向滑動與擬真翻頁時會隨頁面一起移動';

  @override
  String get changelog202PageNumberInset => '頁碼向螢幕內側保留安全距離，避免被圓角遮擋';

  @override
  String get changelog201BackwardPageTurn => '最佳化上一頁擬真翻頁，從中央起手立即跟手，垂直晃動不再帶偏裝訂邊';

  @override
  String get changelog201SnapshotPreheat => '前後相鄰頁同步預熱，減少首次反向翻頁卡頓';

  @override
  String get changelog201SourceFilters => '發現頁支援全部或單一書源篩選，最新書籍在多個書源間均衡穿插';

  @override
  String get changelog120CustomFonts => '完善自訂字型，支援匯入與管理';

  @override
  String get changelog120SystemBars => '美化狀態列與閱讀控制列';

  @override
  String get changelog120BookAnimations => '重做書籍開啟與關閉動畫';

  @override
  String get changelog120TabletLibrary => '優化平板書庫版面';

  @override
  String get changelog120Typography => '優化閱讀排版，支援零邊距與同頁更多文字';

  @override
  String get changelog120VolumeKeys => '接入音量鍵翻頁';

  @override
  String get changelog120Import => '重構書籍匯入，適配安全區更易用';

  @override
  String get changelog120Covers => '無封面書籍統一產生簡約封面';

  @override
  String get changelog120Licenses => '新增應用內開源授權檢視';

  @override
  String get changelog121ContinuousScroll => '線上書源補齊按章節捲動與整書連續捲動';

  @override
  String get changelog121Typography => '修正中文正文左右留白不對稱並統一分頁繪製';

  @override
  String get changelog124PaperLeaf => '新增紙頁化頁腳、經典摺頁動畫與閱讀排版設定';

  @override
  String get changelog122ContinuousTap => '修正線上連續捲動無法點擊中央叫出控制列';

  @override
  String get changelog200ReaderExperience => '升級頂部資訊、紙頁頁碼與擬真翻頁體驗';

  @override
  String get changelog200CustomThemes => '支援多套自訂閱讀主題、圖片背景與拖曳排序';

  @override
  String get changelog200Navigation => '最佳化 EPUB 分頁與可摺疊多層目錄';

  @override
  String get changelog200KeepScreenOn => 'Android 閱讀時保持螢幕常亮正式生效';

  @override
  String get changelog110CustomFonts => '新增自訂字型';

  @override
  String get changelog110Bookmarks => '新增加入書籤';

  @override
  String get changelog102Summary => '最佳化發現頁、獨立搜尋和閱讀設定';

  @override
  String get changelog101Summary => '新增發現功能、分頁搜尋和開源授權說明';

  @override
  String get changelog100Summary => '新增開放書源、多主題和仿真翻頁';

  @override
  String get changelog091Summary => '新增平板雙頁版面和跨平台發布支援';

  @override
  String get settingsMaintainerLabel => '維護者';

  @override
  String get settingsLicenseLabel => '授權條款';

  @override
  String get settingsViewSourceSubtitle => '檢視開源專案';

  @override
  String get settingsJoinQqGroup => '加入 QQ 群';

  @override
  String get settingsQqOpenFailed => '無法開啟 QQ，請確認已安裝 QQ';

  @override
  String get contributorsTitle => '貢獻者';

  @override
  String get contributorsSubtitle => '感謝每一位讓 Open Reading 變得更好的人';

  @override
  String get contributorsOpenProfileFailed => '無法開啟貢獻者主頁';

  @override
  String get contributorsEmpty => '暫時沒有可顯示的貢獻者';

  @override
  String get contributorsLoadFailed => '貢獻者載入失敗，請檢查網路後重試';

  @override
  String get settingsDarkModeTitle => '夜間模式';

  @override
  String settingsCurrentValue(String value) {
    return '目前：$value';
  }

  @override
  String get settingsUiStyleTitle => '玻璃效果';

  @override
  String get settingsGlassEffectSubtitle => '開啟半透明、背景模糊和懸浮層次效果';

  @override
  String get settingsHideNavigationLabelsTitle => '隱藏底部導覽文字';

  @override
  String get settingsHideNavigationLabelsSubtitle => '開啟後，手機底部導覽列僅顯示圖示';

  @override
  String get settingsAccentFollowTheme => '強調色：跟隨主題';

  @override
  String settingsAccentValue(String name) {
    return '強調色：$name';
  }

  @override
  String get settingsAppThemeTitle => '應用程式主題';

  @override
  String settingsCurrentThemeSummary(String theme, String accent) {
    return '目前：$theme · $accent';
  }

  @override
  String get settingsFollowAppTheme => '跟隨應用程式主題';

  @override
  String get settingsAccentColorTitle => '強調色';

  @override
  String get settingsThemeModeSystemHint => '跟隨系統外觀自動切換';

  @override
  String get settingsThemeModeLightHint => '一律使用淺色外觀';

  @override
  String get settingsThemeModeDarkHint => '一律使用深色外觀';

  @override
  String get settingsSelectAppTheme => '選擇應用程式主題';

  @override
  String get settingsDone => '完成';

  @override
  String get settingsAccentColorAdvice => '建議優先選擇應用程式主題，再視需要覆寫強調色。';

  @override
  String get settingsAccentFollowThemeOption => '跟隨主題';

  @override
  String get settingsAccentFollowThemeDesc => '使用目前應用程式主題的預設強調色';

  @override
  String get settingsAboutTitle => '關於應用程式';

  @override
  String get settingsAppName => '開元閱讀';

  @override
  String get settingsAuthor => '維護者：小元Niki';

  @override
  String get settingsGithubRepo => 'GitHub 倉庫';

  @override
  String get settingsNewYearGreeting => '一個專注、克制、可自由修改的跨平台閱讀器。';

  @override
  String get settingsGithubOpenFailed => '無法開啟 GitHub 連結';

  @override
  String get updateCheckNow => '檢查更新';

  @override
  String get updateCheckNowSubtitle => '從 GitHub 或官網取得最新版本';

  @override
  String get updateAvailableTitle => '發現新版本';

  @override
  String updateVersionSummary(String currentVersion, String latestVersion) {
    return '目前版本：$currentVersion\n最新版本：$latestVersion';
  }

  @override
  String get updateNotesTitle => '更新說明';

  @override
  String get updateNotesEmpty => '此版本暫未提供更新說明。';

  @override
  String get updateLater => '稍後';

  @override
  String get updateGoToDownload => '前往更新';

  @override
  String get updateFromGithub => '從 GitHub 更新';

  @override
  String get updateFromWebsite => '前往官網更新';

  @override
  String get updateFromWebsiteInstall => '從官網下載並安裝';

  @override
  String get updateWebsiteUnavailable => '官網暫未提供適用於此裝置的安裝檔';

  @override
  String get updateDownloadingTitle => '正在下載更新';

  @override
  String updateDownloadProgress(int percent) {
    return '已下載 $percent%';
  }

  @override
  String get updatePreparingInstaller => '正在驗證安裝檔並準備系統安裝程式…';

  @override
  String get updateDownloadFailed => '無法從官網下載更新，請稍後再試';

  @override
  String get updateIntegrityFailed => '安裝檔完整性驗證失敗，已刪除此下載';

  @override
  String get updateInstallFailed => '無法安裝更新，請檢查安裝未知應用程式權限後再試';

  @override
  String get updateAlreadyLatest => '目前已是最新版本';

  @override
  String get updateCheckFailed => '檢查更新失敗，請稍後再試';

  @override
  String get updateOpenFailed => '無法開啟 GitHub Release 下載頁面';

  @override
  String get settingsIosOnlyFeature => '該功能僅支援 iOS';

  @override
  String settingsIosSyncResult(String storage, int books, int files) {
    return '已同步到$storage\n書籍 $books 本，檔案複製 $files 個';
  }

  @override
  String get settingsRestartRequiredReason => '此設定變更需要重新啟動應用程式才能完全生效。';

  @override
  String get settingsRestartRequiredTitle => '需要重新啟動應用程式';

  @override
  String settingsRestartPrompt(String reason) {
    return '$reason\n\n是否現在重新啟動應用程式？';
  }

  @override
  String get settingsRestartLater => '稍後';

  @override
  String get settingsRestartNow => '重新啟動';

  @override
  String get statsDetailedTitle => '詳細統計';

  @override
  String get statsRange7Days => '7天';

  @override
  String get statsRange30Days => '30天';

  @override
  String get statsRange90Days => '90天';

  @override
  String get statsRange1Year => '1年';

  @override
  String get statsRangeAll => '全部';

  @override
  String get statsTabOverview => '總覽';

  @override
  String get statsTabCharts => '圖表';

  @override
  String get statsTabBooks => '書籍';

  @override
  String get statsTabAchievements => '成就';

  @override
  String get statsReadingOverview => '閱讀總覽';

  @override
  String statsCumulativeHours(Object hours) {
    return '累計 $hours 小時';
  }

  @override
  String statsStreakEncouragement(Object days) {
    return '保持節奏，你已經連續閱讀 $days 天';
  }

  @override
  String get statsTotalDuration => '總時長';

  @override
  String get statsAvgSession => '平均單次';

  @override
  String statsDaysCount(Object count) {
    return '$count 天';
  }

  @override
  String get statsNoData => '暫無資料';

  @override
  String get statsPeriodEarlyMorning => '清晨 05:00-08:59';

  @override
  String get statsPeriodMorning => '上午 09:00-11:59';

  @override
  String get statsPeriodAfternoon => '下午 12:00-17:59';

  @override
  String get statsPeriodEvening => '晚上 18:00-21:59';

  @override
  String get statsPeriodLateNight => '深夜 22:00-04:59';

  @override
  String get statsTotalReadingTime => '總閱讀時長';

  @override
  String get statsTotalPagesRead => '總閱讀頁數';

  @override
  String get statsBooksReadCount => '閱讀書籍數';

  @override
  String get statsUnitPage => '頁';

  @override
  String get statsTodayProgress => '今日閱讀進度';

  @override
  String statsMinutesOfTarget(Object current, Object target) {
    return '$current / $target 分鐘';
  }

  @override
  String get statsPagesRead => '閱讀頁數';

  @override
  String statsPagesOfTarget(Object current, Object target) {
    return '$current / $target 頁';
  }

  @override
  String get statsReadingHabits => '閱讀習慣分析';

  @override
  String get statsBestReadingPeriod => '最佳閱讀時段';

  @override
  String get statsAvgSessionReading => '平均單次閱讀';

  @override
  String get statsMaxStreakDays => '最高連讀天數';

  @override
  String get statsFocusScore => '閱讀專注度';

  @override
  String get statsBookCount => '書籍數量';

  @override
  String get statsTrendAnalysis => '閱讀趨勢分析';

  @override
  String statsAxisMinutes(Object value) {
    return '$value分';
  }

  @override
  String statsAxisPages(Object value) {
    return '$value頁';
  }

  @override
  String statsAxisBooks(Object value) {
    return '$value本';
  }

  @override
  String statsAxisHour(Object hour) {
    return '$hour時';
  }

  @override
  String get statsTimeDistribution => '閱讀時間分布';

  @override
  String get statsFormatDistribution => '書籍格式分布';

  @override
  String get statsCompleted => '已完成';

  @override
  String get statsInProgress => '閱讀中';

  @override
  String get statsDurationRanking => '閱讀時長排行';

  @override
  String get statsProgressRanking => '閱讀進度排行';

  @override
  String statsPagesCount(Object count) {
    return '$count頁';
  }

  @override
  String statsSessionCount(Object count) {
    return '$count 次工作階段';
  }

  @override
  String statsAchievementsSummary(Object achieved, Object remaining) {
    return '已獲得 $achieved 個成就，還有 $remaining 個等待解鎖';
  }

  @override
  String get statsAchievementFirstReadTitle => '初次閱讀';

  @override
  String get statsAchievementFirstReadDesc => '完成第一次閱讀紀錄';

  @override
  String get statsAchievementNoviceTitle => '閱讀新手';

  @override
  String get statsAchievementNoviceDesc => '累計閱讀時長達到 10 小時';

  @override
  String get statsAchievementBookwormTitle => '書蟲';

  @override
  String get statsAchievementBookwormDesc => '累計閱讀時長達到 100 小時';

  @override
  String get statsAchievementExpertTitle => '閱讀達人';

  @override
  String get statsAchievementExpertDesc => '連續閱讀 7 天';

  @override
  String get statsAchievementOceanTitle => '知識海洋';

  @override
  String get statsAchievementOceanDesc => '閱讀頁數達到 10000 頁';

  @override
  String get statsAchievementScholarTitle => '博學者';

  @override
  String get statsAchievementScholarDesc => '閱讀 10 本不同的書籍';

  @override
  String get statsAchievementMarathonTitle => '閱讀馬拉松';

  @override
  String get statsAchievementMarathonDesc => '連續閱讀 30 天';

  @override
  String get statsAchievementFocusTitle => '專注達人';

  @override
  String get statsAchievementFocusDesc => '累計閱讀時長達到 500 小時';

  @override
  String statsProgressPercent(Object percent) {
    return '進度：$percent%';
  }

  @override
  String get statsGoalProgress => '閱讀目標進度';

  @override
  String get statsMonthlyReadingTime => '本月閱讀時長';

  @override
  String get statsWeeklyReadingTime => '本週閱讀時長';

  @override
  String get statsAvgDailyPages7d => '近 7 天日均頁數';

  @override
  String statsHoursCount(Object count) {
    return '$count小時';
  }

  @override
  String get statsSpeedTrend => '閱讀速度趨勢';

  @override
  String statsAvgSpeed(Object speed) {
    return '平均：$speed頁/分鐘';
  }

  @override
  String get statsReadingContinuity => '閱讀連續性';

  @override
  String statsCurrentStreak(Object days) {
    return '目前連讀：$days天';
  }

  @override
  String get statsHeatmapLess => '少';

  @override
  String get statsHeatmapMore => '多';

  @override
  String statsWeekNumber(Object week) {
    return '第$week週';
  }

  @override
  String get bookSourceAddToShelf => '加入書架';

  @override
  String get bookSourceAddOnline => '線上加入書架';

  @override
  String get bookSourceAddOnlineHint => '不下載全書，閱讀時從書源取得並快取章節';

  @override
  String get bookSourceDownloadLocal => '下載到本機';

  @override
  String get bookSourceDownloadLocalHint => '下載全部章節並作為本機 TXT 加入書架';

  @override
  String get bookSourceAddedOnline => '已線上加入書架';

  @override
  String get bookSourceAlreadyOnShelf => '這本書已在書架中';

  @override
  String get bookSourceDownloading => '正在下載到本機';

  @override
  String get bookSourceFetchingCatalog => '正在取得章節目錄…';

  @override
  String bookSourceDownloadProgress(int completed, int total) {
    return '$completed/$total 章';
  }

  @override
  String get bookSourceDownloadComplete => '下載完成，已加入本機書架';

  @override
  String get bookSourceDownloadConverted => '下載完成，已轉為本機書籍';

  @override
  String bookSourceDownloadFailed(String error) {
    return '下載失敗：$error';
  }

  @override
  String get bookSourceExitAddTitle => '加入書架？';

  @override
  String bookSourceExitAddMessage(String title) {
    return '要把《$title》作為線上書籍加入書架嗎？閱讀進度會繼續保留。';
  }

  @override
  String get bookSourceNotNow => '暫不';

  @override
  String get bookSourceOnlineBadge => '線上';

  @override
  String bookSourceOnlineDataBroken(String error) {
    return '線上書籍資訊損壞：$error';
  }

  @override
  String get readerThemeTitle => '閱讀主題';

  @override
  String get readerThemeDescription => '僅改變閱讀頁面與閱讀控制列，不影響應用程式主題';

  @override
  String get readerThemeDay => '白天';

  @override
  String get readerThemeMist => '晨霧';

  @override
  String get readerThemeGreen => '護眼';

  @override
  String get readerThemeRose => '豆沙';

  @override
  String get readerThemeNavy => '深藍';

  @override
  String get readerThemeNight => '黑夜';

  @override
  String get readerThemePureBlack => '純黑';

  @override
  String get readerThemeParchment => '牛皮紙';

  @override
  String get readerThemeCustom => '自訂';

  @override
  String get readerPullBookmarkTitle => '下拉書籤';

  @override
  String get readerPullBookmarkHint => '從螢幕頂部向下拉，放開即可加入或移除目前頁書籤';

  @override
  String get readerPullBookmarkAddHint => '繼續下拉以加入書籤';

  @override
  String get readerPullBookmarkRemoveHint => '繼續下拉以移除書籤';

  @override
  String get readerPullBookmarkReleaseHint => '放開完成';

  @override
  String get readerTapAnimationTitle => '點擊動畫';

  @override
  String get readerTapAnimationHint => '左右點擊時使用目前翻頁模式的動畫；關閉後立即刷新頁面';

  @override
  String get readerTabletTwoPageTitle => '平板雙頁版面';

  @override
  String get readerTabletTwoPageHint => '橫向時並排顯示左右兩頁；關閉後一律使用單頁版面';

  @override
  String get readerCustomThemeTitle => '自訂閱讀主題';

  @override
  String get readerCustomThemeReset => '重設';

  @override
  String get readerCustomThemeColors => '主題顏色';

  @override
  String get readerCustomThemeTextColor => '字體顏色';

  @override
  String get readerCustomThemeTextColorHint => '正文、標題與主要圖示';

  @override
  String get readerCustomThemeBackground => '閱讀背景';

  @override
  String get readerCustomThemeBackgroundHint => '紙張與閱讀畫布的底色';

  @override
  String get readerCustomThemeControlBar => '控制列顏色';

  @override
  String get readerCustomThemeControlBarHint => '頂部、底部控制列與設定面板';

  @override
  String get readerCustomThemeContrastGood => '正文與背景對比清晰，適合長時間閱讀';

  @override
  String get readerCustomThemeContrastLow => '正文與背景對比較低，可能容易疲勞';

  @override
  String get readerCustomThemeSave => '儲存並使用';

  @override
  String get readerCustomThemePreview => '即時預覽';

  @override
  String get readerCustomThemePreviewChapter => '第一章 · 風從書頁間吹過';

  @override
  String get readerCustomThemePreviewBody =>
      '這是你的閱讀空間。調整字體、紙張和控制列的顏色，讓每一頁都更貼近自己的閱讀習慣。';

  @override
  String get readerCustomThemeHexInvalid => '請輸入 6 位十六進位顏色，例如 #F6F0E4';

  @override
  String get readerCustomThemeHexLabel => '十六進位顏色';

  @override
  String get readerCustomThemesTitle => '自訂閱讀主題';

  @override
  String get readerCustomThemeAdd => '新增主題';

  @override
  String get readerCustomThemeReorderHint => '長按右側拖曳柄調整順序，排序會同步到閱讀設定的主題列表。';

  @override
  String get readerCustomThemeUse => '使用選取的主題';

  @override
  String get readerCustomThemeDeleteTitle => '刪除閱讀主題？';

  @override
  String readerCustomThemeDeleteMessage(String name) {
    return '「$name」將從主題列表中刪除，已儲存的背景圖片也會一併清理。';
  }

  @override
  String get readerCustomThemeEmptyTitle => '還沒有自訂主題';

  @override
  String get readerCustomThemeEmptyHint => '新增一套屬於自己的文字、紙張與背景圖片組合。';

  @override
  String get readerCustomThemeNewTitle => '新增閱讀主題';

  @override
  String get readerCustomThemeEditTitle => '編輯閱讀主題';

  @override
  String get readerCustomThemeName => '主題名稱';

  @override
  String get readerCustomThemeNameHint => '例如：雨夜、午後紙張';

  @override
  String get readerCustomThemeBackgroundImage => '背景圖片';

  @override
  String get readerCustomThemeBackgroundImageHint =>
      '支援 JPG、PNG、WebP，圖片會複製到應用程式儲存空間。';

  @override
  String get readerCustomThemeChooseImage => '上傳圖片';

  @override
  String get readerCustomThemeReplaceImage => '更換圖片';

  @override
  String get readerCustomThemeRemoveImage => '移除圖片';

  @override
  String get readerCustomThemeImageStrength => '背景圖片強度';

  @override
  String get readerCustomThemeImageUnsupported => '目前平台暫不支援匯入背景圖片';

  @override
  String get readerCustomThemeImageTooLarge => '圖片不能超過 20 MB';

  @override
  String get readerCustomThemeImageFormat => '請選擇 JPG、PNG 或 WebP 圖片';

  @override
  String get readerCustomThemeImageFailed => '背景圖片匯入失敗，請再試一次';

  @override
  String get importSourceTitle => '加入書籍';

  @override
  String get importSourceDescription => '可以一次選擇多本書，確認佇列後再開始匯入。';

  @override
  String get importSelectFiles => '選擇檔案';

  @override
  String get importIosSharedDocuments => '我的 iPhone · Open Reading';

  @override
  String get importICloudDrive => 'iCloud Drive · Open Reading';

  @override
  String get importICloudUnavailable => 'iCloud Drive 目前無法使用';

  @override
  String get importAndroidFolder => '授權書籍目錄';

  @override
  String get importAndroidRescan => '掃描已授權目錄';

  @override
  String get importFolderPermissionAvailable => '已授權 · 點擊掃描';

  @override
  String get importFolderPermissionLost => '權限已失效 · 請重新授權';

  @override
  String get importRemoveFolder => '移除目錄';

  @override
  String importQueueTitle(int count) {
    return '匯入佇列（$count）';
  }

  @override
  String get importQueueHint => '可先移除誤選項，匯入時會逐本處理。';

  @override
  String get importQueueEmptyTitle => '尚未選擇書籍';

  @override
  String get importQueueEmptyBody => '請選擇 EPUB、PDF、TXT、MOBI 或其他支援的書籍檔案。';

  @override
  String importAction(int count) {
    return '匯入 $count 本';
  }

  @override
  String importRetryFailed(int count) {
    return '重試失敗的 $count 本';
  }

  @override
  String get importStatusQueued => '等待中';

  @override
  String get importStatusPreparing => '正在準備檔案';

  @override
  String get importStatusChecking => '正在檢查';

  @override
  String get importStatusCopying => '正在複製';

  @override
  String get importStatusAnalyzing => '正在解析';

  @override
  String get importStatusSaving => '正在儲存';

  @override
  String get importStatusImported => '匯入成功';

  @override
  String get importStatusSkipped => '已存在，已略過';

  @override
  String get importStatusFailed => '匯入失敗';

  @override
  String get importRemove => '移除';

  @override
  String get importRetry => '重試';

  @override
  String get importClearCompleted => '清除已完成';

  @override
  String get importDone => '完成';

  @override
  String importSummary(int succeeded, int skipped, int failed) {
    return '成功 $succeeded 本 · 略過 $skipped 本 · 失敗 $failed 本';
  }

  @override
  String get importNoSupportedFiles => '沒有找到支援的書籍檔案';

  @override
  String get importScanning => '正在掃描檔案…';
}
