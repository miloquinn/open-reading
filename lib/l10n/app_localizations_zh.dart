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
  String get library => '书库';

  @override
  String get bookSources => '书源';

  @override
  String get bookSourcesSubtitle => '连接开放书源，跨来源搜索可阅读内容';

  @override
  String get bookSourcesAdd => '添加书源';

  @override
  String get bookSourcesSearchHint => '输入书名或作者，搜索已启用书源';

  @override
  String get bookSourcesSearch => '搜索';

  @override
  String get bookSourcesSearching => '正在搜索书源…';

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
  String get bookSourcesProtocolDialogTitle => '开放书源协议 v1';

  @override
  String get bookSourcesProtocolDialogBody =>
      '服务在 /.well-known/open-reading-source.json 发布发现文档，并实现 /v1/search、书籍详情、章节目录与章节正文接口。首版仅支持公开、无需登录的 HTTP(S) 书源。';

  @override
  String get bookSourcesClose => '关闭';

  @override
  String bookSourcesIdentity(String sourceId, String bookId) {
    return '书源 ID：$sourceId\n书籍 ID：$bookId';
  }

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
  String get appFont => '全局字体';

  @override
  String get fontSystem => '系统默认';

  @override
  String get fontSourceHanSans => '思源黑体';

  @override
  String get fontJetBrainsMono => 'JetBrains Mono';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

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
  String readerFontSizeValue(int size) {
    return '字体大小  $size';
  }

  @override
  String readerHorizontalMarginValue(int margin) {
    return '左右页边距  $margin';
  }

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
  String get settingsDarkModeTitle => '夜间模式';

  @override
  String settingsCurrentValue(String value) {
    return '当前：$value';
  }

  @override
  String get settingsUiStyleTitle => '界面风格';

  @override
  String settingsUiStyleSwitchedRestart(String style) {
    return '界面风格已切换为 $style，重启后会完整应用到所有页面。';
  }

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
}
