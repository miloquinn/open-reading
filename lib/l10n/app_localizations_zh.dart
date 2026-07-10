// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '小元阅读器';

  @override
  String get home => '首页';

  @override
  String get library => '书库';

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
  String get cloudSync => '云端同步';

  @override
  String get webdavConfig => 'WebDAV配置';

  @override
  String webdavConfigured(Object serverUrl) {
    return '已配置 - $serverUrl';
  }

  @override
  String get webdavConfigHint => '点击配置WebDAV服务器';

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
  String get pageTurningSettings => '翻页方式';

  @override
  String get pageTurningMode => '翻页模式';

  @override
  String get pageTurningCover => '覆盖翻页';

  @override
  String get pageTurningSlide => '左右滑动';

  @override
  String get pageTurningScroll => '上下滚动';

  @override
  String get pageTurningSimulation => '仿真翻页';

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
  String get webdavTitle => 'WebDAV配置';

  @override
  String get webdavSetupCloudSync => '设置云端同步服务';

  @override
  String get webdavServerUrl => '服务器地址';

  @override
  String get webdavUsername => '用户名';

  @override
  String get webdavPassword => '密码';

  @override
  String get webdavEnterServerUrl => '请输入服务器地址';

  @override
  String get webdavInvalidUrl => '请输入有效的URL';

  @override
  String get webdavEnterUsername => '请输入用户名';

  @override
  String get webdavEnterPassword => '请输入密码';

  @override
  String get webdavConnectionFailed => '连接失败，请检查设置';

  @override
  String get webdavTestConnection => '测试连接';

  @override
  String get webdavSaveConfig => '保存配置';

  @override
  String get webdavClearConfig => '清除配置';

  @override
  String get webdavTestSuccess => '连接测试成功！';

  @override
  String get webdavTestFailed => '连接测试失败';

  @override
  String get webdavConfigSaved => 'WebDAV配置已保存';

  @override
  String get webdavConfigSaveFailed => '保存配置失败';

  @override
  String get webdavConfirmClear => '确定要清除WebDAV配置吗？这将删除所有同步设置。';

  @override
  String get webdavConfigCleared => 'WebDAV配置已清除';

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
}
