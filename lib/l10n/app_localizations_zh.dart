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
  String get legadoCompatibilityTitle => 'Legado 兼容（Beta）';

  @override
  String get legadoCompatibilitySubtitle => '导入后先扫描规则能力，再决定是否允许兼容运行';

  @override
  String get legadoImport => '导入 Legado';

  @override
  String get legadoImportTitle => '导入 Legado 书源';

  @override
  String get legadoImportNotice =>
      'Legado JSON 可能包含可执行脚本、Cookie、登录流程或浏览器自动化。导入只会保存并扫描规则，App 不会直接执行高风险能力。';

  @override
  String get legadoChooseFile => '选择 JSON 文件';

  @override
  String get legadoJsonLabel => 'Legado 书源 JSON';

  @override
  String get legadoImportHint => '粘贴单个书源、导出的书源列表，或选择 JSON 文件';

  @override
  String get legadoFileTooLarge => '书源文件超过 2 MB 导入限制。';

  @override
  String get legadoFileReadFailed => '无法读取所选文件。';

  @override
  String legadoImportedCount(int count) {
    return '已导入 $count 个 Legado 书源';
  }

  @override
  String get legadoNoSources => '尚未导入 Legado 书源。这里的导入不会启用脚本，也不会内置第三方内容。';

  @override
  String get legadoLite => 'Lite 可兼容';

  @override
  String get legadoAdapterRequired => '需要兼容引擎';

  @override
  String get legadoUnsupported => '暂不支持';

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
  String get bookSourcesProtocolDialogTitle => '开放书源协议 v1.1';

  @override
  String get bookSourcesProtocolDialogBody =>
      '服务在 /.well-known/open-reading-source.json 发布发现文档，并实现搜索、书籍详情、章节目录与章节正文接口。v1.1 可选支持推荐、分类与浏览，仍仅面向公开、无需登录的 HTTP(S) 书源。';

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
  String get pageTurningSlide => '左右滑动';

  @override
  String get pageTurningScroll => '上下滚动';

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
  String get readerModeHorizontalPage => '水平分页';

  @override
  String get readerModeVerticalScrollHint => '上下滚动正文，左右滑动切换章节';

  @override
  String get readerModeWholeBookScrollHint => '整本书从头到尾连续向下滚动';

  @override
  String get readerScrollByChapterTitle => '按章节滚动';

  @override
  String get readerScrollByChapterOnHint => '单章内上下滚动，左右滑动切换章节';

  @override
  String get readerScrollByChapterOffHint => '所有章节合并为一条连续的纵向内容流';

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
  String get settingsVolumeKeyTurnSubtitle => '使用音量键控制翻页';

  @override
  String get settingsShowStatusBarTitle => '阅读时显示系统状态栏';

  @override
  String get settingsShowStatusBarOnSubtitle => '已隐藏阅读页电量/时间 UI';

  @override
  String get settingsShowStatusBarOffSubtitle => '使用阅读页电量/时间 UI';

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
  String get updateCheckNowSubtitle => '从 GitHub Releases 获取最新版本';

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
  String get legadoCompatibilityTitle => 'Legado 相容（Beta）';

  @override
  String get legadoCompatibilitySubtitle => '匯入後先掃描規則能力，再決定是否允許相容執行';

  @override
  String get legadoImport => '匯入 Legado';

  @override
  String get legadoImportTitle => '匯入 Legado 書源';

  @override
  String get legadoImportNotice =>
      'Legado JSON 可能包含可執行腳本、Cookie、登入流程或瀏覽器自動化。匯入只會儲存並掃描規則，App 不會直接執行高風險能力。';

  @override
  String get legadoChooseFile => '選擇 JSON 檔案';

  @override
  String get legadoJsonLabel => 'Legado 書源 JSON';

  @override
  String get legadoImportHint => '貼上單一書源、匯出的書源清單，或選擇 JSON 檔案';

  @override
  String get legadoFileTooLarge => '書源檔案超過 2 MB 匯入限制。';

  @override
  String get legadoFileReadFailed => '無法讀取所選檔案。';

  @override
  String legadoImportedCount(int count) {
    return '已匯入 $count 個 Legado 書源';
  }

  @override
  String get legadoNoSources => '尚未匯入 Legado 書源。這裡的匯入不會啟用腳本，也不會內建第三方內容。';

  @override
  String get legadoLite => 'Lite 可相容';

  @override
  String get legadoAdapterRequired => '需要相容引擎';

  @override
  String get legadoUnsupported => '暫不支援';

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
  String get bookSourcesProtocolDialogTitle => '開放書源協定 v1.1';

  @override
  String get bookSourcesProtocolDialogBody =>
      '服務在 /.well-known/open-reading-source.json 發布探索文件，並實作搜尋、書籍詳情、章節目錄與章節內文介面。v1.1 可選支援推薦、分類與瀏覽，仍僅面向公開、無需登入的 HTTP(S) 書源。';

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
  String get pageTurningSlide => '左右滑動';

  @override
  String get pageTurningScroll => '上下捲動';

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
  String get readerModeHorizontalPage => '水平分頁';

  @override
  String get readerModeVerticalScrollHint => '上下捲動內文，左右滑動切換章節';

  @override
  String get readerModeWholeBookScrollHint => '整本書從頭到尾連續向下捲動';

  @override
  String get readerScrollByChapterTitle => '按章節捲動';

  @override
  String get readerScrollByChapterOnHint => '單章內上下捲動，左右滑動切換章節';

  @override
  String get readerScrollByChapterOffHint => '所有章節合併為一條連續的縱向內容流';

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
  String get settingsVolumeKeyTurnSubtitle => '使用音量鍵控制翻頁';

  @override
  String get settingsShowStatusBarTitle => '閱讀時顯示系統狀態列';

  @override
  String get settingsShowStatusBarOnSubtitle => '已隱藏閱讀頁電量/時間 UI';

  @override
  String get settingsShowStatusBarOffSubtitle => '使用閱讀頁電量/時間 UI';

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
  String get updateCheckNowSubtitle => '從 GitHub Releases 取得最新版本';

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
