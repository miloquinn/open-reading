// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Xiaoyuan Reader';

  @override
  String get home => 'Home';

  @override
  String get library => 'Library';

  @override
  String get settings => 'Settings';

  @override
  String get statistics => 'Statistics';

  @override
  String get reading => 'Reading';

  @override
  String get importBooks => 'Import Books';

  @override
  String get darkMode => 'Dark Mode';

  @override
  String get lightMode => 'Light Mode';

  @override
  String get systemMode => 'System';

  @override
  String get theme => 'Theme';

  @override
  String get accent => 'Accent Color';

  @override
  String get bookmarks => 'Bookmarks';

  @override
  String get notes => 'Notes';

  @override
  String get highlights => 'Highlights';

  @override
  String get ttsReading => 'Text-to-Speech';

  @override
  String get share => 'Share';

  @override
  String get shareContent => 'Share Content';

  @override
  String get shareCurrentPage => 'Share Current Page';

  @override
  String get shareSelectedText => 'Share Selected Text';

  @override
  String get shareProgress => 'Share Reading Progress';

  @override
  String get play => 'Play';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get speed => 'Speed';

  @override
  String get pitch => 'Pitch';

  @override
  String get language => 'Language';

  @override
  String get fontSize => 'Font Size';

  @override
  String get readingProgress => 'Reading Progress';

  @override
  String get totalPages => 'Total Pages';

  @override
  String get currentPage => 'Current Page';

  @override
  String get readingTime => 'Reading Time';

  @override
  String get booksRead => 'Books Read';

  @override
  String get todayReading => 'Today\'s Reading';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get save => 'Save';

  @override
  String get back => 'Back';

  @override
  String get next => 'Next';

  @override
  String get previous => 'Previous';

  @override
  String get search => 'Search';

  @override
  String get noResults => 'No results found';

  @override
  String get loading => 'Loading...';

  @override
  String get error => 'Error';

  @override
  String get initializationFailed => 'Initialization failed';

  @override
  String get unknownError => 'Unknown error';

  @override
  String get retry => 'Retry';

  @override
  String get appearanceSettings => 'Appearance';

  @override
  String get readingTips => 'Reading Tips';

  @override
  String get readingFontSettingsMoved => 'Reading font settings moved';

  @override
  String get readingFontSettingsHint =>
      'Open any book, tap the center of the screen, then use the bottom toolbar to adjust font size, line spacing, letter spacing, margins, and reading font.';

  @override
  String get readingSettings => 'Reading Settings';

  @override
  String get enableTts => 'Enable TTS';

  @override
  String get enableTtsHint => 'Enable text-to-speech reading';

  @override
  String get ttsSpeedLabel => 'Speed';

  @override
  String get ttsSpeedHint => 'Adjust reading speed';

  @override
  String get ttsVolumeLabel => 'Volume';

  @override
  String get ttsVolumeHint => 'Adjust reading volume';

  @override
  String get ttsPitchLabel => 'Pitch';

  @override
  String get ttsPitchHint => 'Adjust reading pitch';

  @override
  String get cloudSync => 'Cloud Sync';

  @override
  String get webdavConfig => 'WebDAV';

  @override
  String webdavConfigured(Object serverUrl) {
    return 'Configured - $serverUrl';
  }

  @override
  String get webdavConfigHint => 'Tap to configure WebDAV server';

  @override
  String get appSettings => 'App Settings';

  @override
  String get appFont => 'App Font';

  @override
  String get fontSystem => 'System Default';

  @override
  String get fontSourceHanSans => 'Source Han Sans';

  @override
  String get fontJetBrainsMono => 'JetBrains Mono';

  @override
  String get languageSystem => 'Follow System';

  @override
  String get languageChinese => 'Chinese';

  @override
  String get languageEnglish => 'English';

  @override
  String get typographySettings => 'Typography';

  @override
  String get fontFamilyLabel => 'Font';

  @override
  String get fontSizeLabel => 'Font Size';

  @override
  String get lineSpacingLabel => 'Line Spacing';

  @override
  String get letterSpacingLabel => 'Letter Spacing';

  @override
  String get firstLineIndentLabel => 'First-line Indent';

  @override
  String get pageMarginLabel => 'Page Margin';

  @override
  String get resetDefault => 'Reset';

  @override
  String get ttsPanelTitle => 'Text-to-Speech';

  @override
  String get ttsPreviewEffect => 'Preview Effect';

  @override
  String get ttsVolume => 'Volume';

  @override
  String get ttsPitch => 'Pitch';

  @override
  String get ttsSpeed => 'Speed';

  @override
  String get ttsPreviousSentence => 'Previous Sentence';

  @override
  String get ttsNextSentence => 'Next Sentence';

  @override
  String get ttsTimerStop => 'Timer Stop';

  @override
  String get ttsTimerOff => 'No Limit';

  @override
  String ttsTimerMinutes(Object minutes) {
    return '$minutes minutes';
  }

  @override
  String get ttsPlaying => 'Playing';

  @override
  String get ttsPaused => 'Paused';

  @override
  String get ttsStopped => 'Stopped';

  @override
  String get ttsPreviousSentenceFailed => 'Failed to play previous sentence';

  @override
  String get ttsNextSentenceFailed => 'Failed to play next sentence';

  @override
  String get ttsEmptyContentError => 'Current page content is empty';

  @override
  String get ttsPlaybackFailed => 'Playback failed';

  @override
  String get ttsOperationFailed => 'Operation failed';

  @override
  String get pageTurningSettings => 'Page Turning';

  @override
  String get pageTurningMode => 'Page Mode';

  @override
  String get pageTurningCover => 'Cover';

  @override
  String get pageTurningSlide => 'Slide';

  @override
  String get pageTurningScroll => 'Scroll';

  @override
  String get pageTurningSimulation => 'Simulation';

  @override
  String get tapZoneSettings => 'Tap Zones';

  @override
  String get tapZoneNextPage => 'Next Page';

  @override
  String get tapZonePreviousPage => 'Previous Page';

  @override
  String get tapZoneMenu => 'Menu';

  @override
  String get tapZoneLegend => 'Legend';

  @override
  String get highlightColor => 'Highlight Color';

  @override
  String get highlightPreview => 'Preview';

  @override
  String get highlightSampleText => 'This is a sample text,';

  @override
  String get highlightSampleText2 => 'this part will be highlighted,';

  @override
  String get highlightSampleText3 => 'showing the highlight effect.';

  @override
  String get webdavTitle => 'WebDAV Configuration';

  @override
  String get webdavSetupCloudSync => 'Setup Cloud Sync Service';

  @override
  String get webdavServerUrl => 'Server URL';

  @override
  String get webdavUsername => 'Username';

  @override
  String get webdavPassword => 'Password';

  @override
  String get webdavEnterServerUrl => 'Please enter server URL';

  @override
  String get webdavInvalidUrl => 'Please enter a valid URL';

  @override
  String get webdavEnterUsername => 'Please enter username';

  @override
  String get webdavEnterPassword => 'Please enter password';

  @override
  String get webdavConnectionFailed =>
      'Connection failed, please check settings';

  @override
  String get webdavTestConnection => 'Test Connection';

  @override
  String get webdavSaveConfig => 'Save Configuration';

  @override
  String get webdavClearConfig => 'Clear Configuration';

  @override
  String get webdavTestSuccess => 'Connection test successful!';

  @override
  String get webdavTestFailed => 'Connection test failed';

  @override
  String get webdavConfigSaved => 'WebDAV configuration saved';

  @override
  String get webdavConfigSaveFailed => 'Failed to save configuration';

  @override
  String get webdavConfirmClear =>
      'Are you sure you want to clear WebDAV configuration?';

  @override
  String get webdavConfigCleared => 'WebDAV configuration cleared';

  @override
  String get colorLightBlue => 'Light Blue';

  @override
  String get colorRed => 'Red';

  @override
  String get colorGreen => 'Green';

  @override
  String get colorPurple => 'Purple';

  @override
  String get colorGold => 'Gold';

  @override
  String get colorOrange => 'Orange';

  @override
  String get colorYellow => 'Yellow';

  @override
  String get colorDarkGreen => 'Dark Green';

  @override
  String get colorCustom => 'Custom';

  @override
  String get noteTypeHighlight => 'Highlight';

  @override
  String get noteTypeUnderline => 'Underline';

  @override
  String get noteTypeNote => 'Note';

  @override
  String get noteTypeUnknown => 'Unknown';

  @override
  String get bookFormatTXT => 'TXT';

  @override
  String get bookFormatEPUB => 'EPUB';

  @override
  String get bookFormatPDF => 'PDF';

  @override
  String get importBook => 'Import Book';

  @override
  String get importFromFiles => 'Import from Files';

  @override
  String get importNoBooks => 'No books imported yet';

  @override
  String get importSuccess => 'Book imported successfully';

  @override
  String get importFailed => 'Import failed';

  @override
  String get importProcessing => 'Processing book...';

  @override
  String get author => 'Author';

  @override
  String get progress => 'Progress';

  @override
  String get continueReading => 'Continue Reading';

  @override
  String get recentBooks => 'Recent Books';

  @override
  String get allBooks => 'All Books';

  @override
  String get emptyLibrary => 'Library is empty';

  @override
  String get deleteBook => 'Delete Book';

  @override
  String get deleteBookConfirm => 'Are you sure you want to delete this book?';

  @override
  String get bookDeleted => 'Book deleted';

  @override
  String get userAgreement => 'User Agreement';

  @override
  String get acceptAgreement => 'I have read and agree';

  @override
  String get declineAgreement => 'Decline';

  @override
  String get statsToday => 'Today';

  @override
  String get statsThisWeek => 'This Week';

  @override
  String get statsTotal => 'Total';

  @override
  String statsMinutes(Object minutes) {
    return '$minutes min';
  }

  @override
  String statsHours(Object hours) {
    return '$hours h';
  }

  @override
  String statsBooks(Object count) {
    return '$count books';
  }

  @override
  String get statsConsecutiveDays => 'Consecutive Days';

  @override
  String get statsFocusTime => 'Focus Time';

  @override
  String get statsThisWeekTotal => 'This Week Total';

  @override
  String get statsKeepReading => 'Keep Reading Daily';

  @override
  String get statsMaxSession => 'Max Session';

  @override
  String get statsWeeklyTrend => 'Weekly Trend';

  @override
  String get statsAchievements => 'Achievements';

  @override
  String get readerToolbarMenu => 'Menu';

  @override
  String get readerToolbarTOC => 'Table of Contents';

  @override
  String get readerToolbarSettings => 'Settings';

  @override
  String get readerAddBookmark => 'Add Bookmark';

  @override
  String get readerAddNote => 'Add Note';

  @override
  String get readerShare => 'Share';

  @override
  String get bookmarkAdded => 'Bookmark added';

  @override
  String get bookmarkRemoved => 'Bookmark removed';

  @override
  String get themeBlue => 'Ocean Blue';

  @override
  String get themePurple => 'Mystic Purple';

  @override
  String get themeGreen => 'Forest Green';

  @override
  String get themeOrange => 'Vibrant Orange';

  @override
  String get themeRed => 'Passionate Red';

  @override
  String get themeCustom => 'Custom';

  @override
  String get tapZoneLeftRight => 'Left/Right';

  @override
  String get tapZoneLeftCenterRight => 'Left/Center/Right';

  @override
  String get homeTagline => 'Read beautifully';

  @override
  String get homeReadingStatsTitle => 'Reading Stats';

  @override
  String get homeTodayReadingMoment => 'Today\'s Reading Moment';

  @override
  String homeReadMinutesKeepGoing(int minutes) {
    return 'Read $minutes minutes, keep going';
  }

  @override
  String get homeTodayReadingJourneyStart => 'Start your reading journey today';

  @override
  String get homeTodayReadingKeepRhythm =>
      'You are on track today, keep the rhythm';

  @override
  String get homeTodayReadingPrompt => 'Save some time for reading today';

  @override
  String homeTotalReadingHours(String hours) {
    return 'Total reading $hours hours';
  }

  @override
  String get homeWeeklyReading => 'This Week';

  @override
  String get homeTotalReading => 'Total Reading';

  @override
  String get homeLibraryCount => 'Library Books';

  @override
  String get homeCollectionCount => 'Collection';

  @override
  String get homeKeyMetrics => 'Key Metrics';

  @override
  String get homeReadingRhythm => 'Reading Rhythm';

  @override
  String get homeAchievements => 'Reading Achievements';

  @override
  String get homeConsecutiveReading => 'Consecutive Reading';

  @override
  String get homeConsecutiveReadingDesc => 'Keep a daily reading habit';

  @override
  String get homeFocusDuration => 'Focus Duration';

  @override
  String get homeFocusDurationDesc => 'Longest single reading session';

  @override
  String get homeWeeklyTotal => 'Weekly Total';

  @override
  String get homeWeeklyTotalDesc => 'Reading time this week';

  @override
  String get homeRecentReading => 'Recent Reading';

  @override
  String get homeWeeklyTrend => 'Weekly Reading Trend';

  @override
  String homeBarTooltipMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String get unitMinute => 'min';

  @override
  String get unitHour => 'hour';

  @override
  String get unitBook => 'books';

  @override
  String get unitDay => 'days';

  @override
  String get weekdayMonShort => 'Mon';

  @override
  String get weekdayTueShort => 'Tue';

  @override
  String get weekdayWedShort => 'Wed';

  @override
  String get weekdayThuShort => 'Thu';

  @override
  String get weekdayFriShort => 'Fri';

  @override
  String get weekdaySatShort => 'Sat';

  @override
  String get weekdaySunShort => 'Sun';
}
