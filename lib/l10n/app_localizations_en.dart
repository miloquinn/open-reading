// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'OpenReading';

  @override
  String get home => 'Home';

  @override
  String get library => 'Library';

  @override
  String get bookSources => 'Sources';

  @override
  String get bookSourcesSubtitle =>
      'Connect open sources and search readable content across providers';

  @override
  String get bookSourcesAdd => 'Add source';

  @override
  String get bookSourcesSearchHint =>
      'Search enabled sources by title or author';

  @override
  String get bookSourcesSearch => 'Search';

  @override
  String get bookSourcesSearching => 'Searching sources…';

  @override
  String bookSourcesFailedCount(int count) {
    return '$count source request(s) failed';
  }

  @override
  String get bookSourcesSearchPrompt =>
      'Add and enable a source to search it here';

  @override
  String get bookSourcesNoResults => 'No matching books found';

  @override
  String get bookSourcesNoSourcesTitle => 'No sources yet';

  @override
  String get bookSourcesNoSourcesDescription =>
      'Paste the address of a service compatible with the Open Reading Source Protocol.';

  @override
  String get bookSourcesManageTitle => 'Connected sources';

  @override
  String get bookSourcesEnabled => 'Enabled';

  @override
  String get bookSourcesDisabled => 'Disabled';

  @override
  String get bookSourcesRemove => 'Remove';

  @override
  String get bookSourcesRemoveTitle => 'Remove source';

  @override
  String get bookSourcesRemoveMessage =>
      'This only removes the source configuration. Local books are not affected.';

  @override
  String get bookSourcesCancel => 'Cancel';

  @override
  String get bookSourcesConfirm => 'Confirm';

  @override
  String get bookSourcesAddTitle => 'Add open source';

  @override
  String get bookSourcesUrlLabel => 'Source address';

  @override
  String get bookSourcesUrlHint =>
      'https://example.com or a discovery document URL';

  @override
  String get bookSourcesConnect => 'Connect and validate';

  @override
  String get bookSourcesConnecting => 'Validating protocol…';

  @override
  String get bookSourcesAdded => 'Source added';

  @override
  String get bookSourcesProtocolTitle => 'Open Reading Source Protocol';

  @override
  String get bookSourcesProtocolDescription =>
      'A common contract for discovery, search, book details, catalogs, and chapter content. Developers can host native sources or build adapters for content they are authorized to serve.';

  @override
  String get bookSourcesProtocolDetails => 'View protocol';

  @override
  String get bookSourcesProtocolRepository => 'Protocol repository';

  @override
  String get bookSourcesProtocolRepositoryOpen => 'View on GitHub';

  @override
  String get bookSourcesProtocolRepositoryOpenFailed =>
      'Could not open the protocol repository';

  @override
  String get bookSourcesProtocolDialogTitle => 'Open source protocol v1';

  @override
  String get bookSourcesProtocolDialogBody =>
      'A source publishes /.well-known/open-reading-source.json and implements /v1/search plus book details, chapter catalogs, and chapter content endpoints. Version 1 supports public HTTP(S) sources that do not require sign-in.';

  @override
  String get bookSourcesClose => 'Close';

  @override
  String bookSourcesIdentity(String sourceId, String bookId) {
    return 'Source ID: $sourceId\nBook ID: $bookId';
  }

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
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageTraditionalChinese => '繁體中文';

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
  String get pageTurningMode => 'Page Mode';

  @override
  String get pageTurningSlide => 'Slide';

  @override
  String get pageTurningScroll => 'Scroll';

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

  @override
  String get agreementTagline =>
      'Immersive Reading · AI Assistant · Local First';

  @override
  String get agreementCardTitle => 'User Service Agreement';

  @override
  String get agreementCardSubtitle => 'Please read the following carefully';

  @override
  String get agreementWelcomeTitle => 'Welcome to OpenReading';

  @override
  String get agreementWelcomeBody =>
      'To ensure a stable and predictable reading experience, please read and agree to the following agreement first.';

  @override
  String get agreementFeatureFormatsTitle => 'Multi-Format Support';

  @override
  String get agreementFeatureFormatsBody => 'EPUB, PDF, TXT, MOBI and more';

  @override
  String get agreementFeatureCustomizationTitle => 'Personalized Reading';

  @override
  String get agreementFeatureCustomizationBody =>
      'Customize fonts, colors, typography and more';

  @override
  String get agreementFeatureSyncTitle => 'Local First';

  @override
  String get agreementFeatureSyncBody =>
      'Books, progress, and notes stay on the device you control';

  @override
  String get agreementFeatureTtsTitle => 'Text-to-Speech';

  @override
  String get agreementFeatureTtsBody =>
      'Smart voice narration frees your eyes so you can listen anywhere';

  @override
  String get agreementTapToAgreeHint =>
      'By tapping \"Agree and Continue\", you confirm that you have read and agree to use this app';

  @override
  String get agreementExitApp => 'Exit App';

  @override
  String get agreementAgreeAndContinue => 'Agree and Continue';

  @override
  String get agreementExitDialogContent =>
      'If you do not agree to the user agreement, you will not be able to use this app. Are you sure you want to exit?';

  @override
  String get agreementConfirmExit => 'Exit';

  @override
  String get readerFileMissing => 'Book file not found. Please re-import it.';

  @override
  String get readerUnsupportedFormat =>
      'The native reader currently only supports EPUB and TXT.';

  @override
  String get bootstrapDataServiceFailed =>
      'Failed to initialize the data system';

  @override
  String get bootstrapImageManagerFailed =>
      'Failed to initialize the image manager';

  @override
  String homeFocusCompleted(int minutes) {
    return '$minutes-minute focus session complete. Well done!';
  }

  @override
  String get homeDailyReadingGoal => 'Daily Reading Goal';

  @override
  String get homeAiAdviceSection => 'AI Reading Advice';

  @override
  String get homeTodayGlance => 'Today at a Glance';

  @override
  String get homeTodayReadingPlan => 'Today\'s Reading Plan';

  @override
  String get homeViewAll => 'View All';

  @override
  String get homeSyncingReadingPlan => 'Syncing your reading plan';

  @override
  String get homeGoalDoneSuggestReview =>
      'Today\'s goal is complete — consider a reading review';

  @override
  String homeRemainingToGoal(int minutes) {
    return 'Just $minutes more minutes to reach today\'s goal';
  }

  @override
  String get homePickBookHint =>
      'Pick a book from your shelf to continue and complete 1 focus session first.';

  @override
  String homeContinueBookHint(String title) {
    return 'Continue \"$title\" first, then switch to other books.';
  }

  @override
  String get homeTodayActionAdvice => 'Today\'s Action Plan';

  @override
  String homeProgressPercent(int percent) {
    return '$percent% progress';
  }

  @override
  String homeStreakDays(int days) {
    return '$days-day streak';
  }

  @override
  String homeWeekMinutes(int minutes) {
    return '$minutes min this week';
  }

  @override
  String get homePlanLoading => 'Plan loading';

  @override
  String homeGoalMinutesPerDay(int minutes) {
    return 'Goal: $minutes min/day';
  }

  @override
  String get homeAiAdviceForYou => 'AI Reading Advice for You';

  @override
  String homeBasedOnBook(String title) {
    return 'Based on \"$title\"';
  }

  @override
  String get homeTodayReadingMinutesLabel => 'Today\'s Reading (min)';

  @override
  String get homeTotalReadingMinutesLabel => 'Total Reading (min)';

  @override
  String get homeGeneratingPlan => 'Generating today\'s reading plan...';

  @override
  String get homeCompletedLabel => 'Done';

  @override
  String get homeTodayGoalAchieved => 'Today\'s goal achieved';

  @override
  String homeMinutesRemaining(int minutes) {
    return '$minutes minutes to go';
  }

  @override
  String homeReadOfGoalMinutes(int read, int goal) {
    return 'Read $read / $goal min';
  }

  @override
  String homeSessionsToFinishGoal(int sessions) {
    return 'About $sessions focus sessions to finish today\'s goal';
  }

  @override
  String get homeStreakLabel => 'Streak';

  @override
  String get homeWeekAchievedLabel => 'Weekly goal';

  @override
  String get homeFocusLabel => 'Focus';

  @override
  String homeDaysCount(int days) {
    return '$days days';
  }

  @override
  String homeTimesCount(int times) {
    return '$times times';
  }

  @override
  String homeFocusCountdown(String time) {
    return 'Focus countdown $time';
  }

  @override
  String get homeGoLibraryRead => 'Read from Library';

  @override
  String get homeEndFocus => 'End Focus';

  @override
  String homeFocusMinutesButton(int minutes) {
    return 'Focus $minutes min';
  }

  @override
  String homeAdjustGoalMinutes(int minutes) {
    return 'Adjust goal: $minutes min';
  }

  @override
  String get homeNoRecentReading =>
      'No recent reading yet. Open a book from your library to get started.';

  @override
  String homeReadingProgressPercent(String percent) {
    return 'Progress $percent%';
  }

  @override
  String get librarySearchHint => 'Search titles or authors';

  @override
  String libraryFilterAll(int count) {
    return 'All $count';
  }

  @override
  String libraryFilterReading(int count) {
    return 'Reading $count';
  }

  @override
  String libraryFilterFinished(int count) {
    return 'Finished $count';
  }

  @override
  String get libraryNoMatchingBooks => 'No matching books';

  @override
  String get libraryNoReadingBooks => 'No books in progress';

  @override
  String get libraryNoFinishedBooks => 'No finished books';

  @override
  String get libraryNoBooks => 'No books yet';

  @override
  String libraryProgressContinue(int percent) {
    return '$percent% · Continue reading';
  }

  @override
  String libraryPageNumber(int page) {
    return 'Page $page';
  }

  @override
  String get libraryStartFromBeginning => 'Start from the beginning';

  @override
  String get libraryBookInfo => 'Book Info';

  @override
  String libraryFormatAndPages(String format, int pages) {
    return '$format · $pages pages';
  }

  @override
  String get libraryDeleteBookHint => 'This book will be permanently deleted';

  @override
  String get libraryBookTitle => 'Title';

  @override
  String get libraryFormat => 'Format';

  @override
  String libraryPagesCount(int pages) {
    return '$pages pages';
  }

  @override
  String get libraryClose => 'Close';

  @override
  String get libraryConfirmDeleteTitle => 'Confirm Deletion';

  @override
  String libraryDeleteBookMessage(String title) {
    return 'Delete \"$title\"? The file will be permanently removed from your device.';
  }

  @override
  String libraryDeletingBook(String title) {
    return 'Deleting \"$title\"...';
  }

  @override
  String libraryBookDeletedToast(String title) {
    return '\"$title\" deleted';
  }

  @override
  String libraryDeleteFailed(String error) {
    return 'Failed to delete: $error';
  }

  @override
  String get libraryReadingBadge => 'Reading';

  @override
  String get libraryDeletingBookFile => 'Deleting book file...';

  @override
  String get libraryDeletingCoverImage => 'Deleting cover image...';

  @override
  String get libraryCleaningDatabase => 'Cleaning up database records...';

  @override
  String get libraryDeleteComplete => 'Deletion complete';

  @override
  String get readerPrefaceTitle => 'Front Matter';

  @override
  String get readerModeHorizontalPage => 'Horizontal Paging';

  @override
  String get readerModeVerticalScrollHint =>
      'Scroll vertically to read, swipe horizontally to switch chapters';

  @override
  String get readerModeWholeBookScrollHint =>
      'Scroll continuously from the beginning to the end of the book';

  @override
  String get readerScrollByChapterTitle => 'Scroll by chapter';

  @override
  String get readerScrollByChapterOnHint =>
      'Scroll within one chapter, then swipe left or right to switch chapters';

  @override
  String get readerScrollByChapterOffHint =>
      'All chapters form one continuous vertical list';

  @override
  String get readerModeHorizontalPageHint =>
      'Tap the left side for the previous page, the right side for the next page';

  @override
  String get readerModeHorizontalSlideHint =>
      'Pages follow your finger horizontally and snap into place';

  @override
  String readerFontSizeValue(int size) {
    return 'Font size  $size';
  }

  @override
  String readerHorizontalMarginValue(int margin) {
    return 'Horizontal margin  $margin';
  }

  @override
  String readerVerticalMarginValue(int margin) {
    return 'Vertical margin  $margin';
  }

  @override
  String readerChapterCount(int count) {
    return '$count chapters';
  }

  @override
  String readerChapterFallback(int number) {
    return 'Chapter $number';
  }

  @override
  String readerOpenFailed(String error) {
    return 'Failed to open: $error';
  }

  @override
  String get readerNoContent => 'This book has no readable content';

  @override
  String readerStatusPaged(
      int chapter, int chapterCount, int page, int pageCount) {
    return 'Chapter $chapter/$chapterCount · Page $page/$pageCount';
  }

  @override
  String readerStatusScroll(int chapter, int chapterCount) {
    return 'Chapter $chapter/$chapterCount · Vertical scroll';
  }

  @override
  String get importPreparing => 'Preparing import...';

  @override
  String importFailedWithError(String error) {
    return 'Import failed: $error';
  }

  @override
  String get importLocalFile => 'Local Files';

  @override
  String get settingsAiTempHintMinimax =>
      'Temperature: MiniMax recommends 0.01 ~ 1.00';

  @override
  String get settingsAiCustomConfigTitle => 'Custom AI Configuration';

  @override
  String settingsAiCurrentProvider(String provider) {
    return 'Current provider: $provider';
  }

  @override
  String get settingsAiTempErrorMinimax =>
      'MiniMax Temperature must be between 0.01 and 1.00';

  @override
  String get settingsAiTempErrorOutOfRange =>
      'Temperature is out of range, please follow the hint';

  @override
  String get settingsApply => 'Apply';

  @override
  String get settingsAiCustomApplied =>
      'Custom parameters applied, remember to save the configuration';

  @override
  String get settingsAiApiKeyRequired => 'API Key cannot be empty';

  @override
  String get settingsAiModelRequired => 'Model cannot be empty';

  @override
  String get settingsAiBaseUrlInvalid =>
      'Base URL must be a valid http/https address';

  @override
  String get settingsAiSettingsSaved => 'AI settings saved';

  @override
  String settingsSaveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String get settingsVolumeKeyTurnTitle => 'Volume key page turning';

  @override
  String get settingsVolumeKeyTurnSubtitle => 'Use volume keys to turn pages';

  @override
  String get settingsShowStatusBarTitle =>
      'Show system status bar while reading';

  @override
  String get settingsShowStatusBarOnSubtitle => 'Reader battery/time UI hidden';

  @override
  String get settingsShowStatusBarOffSubtitle => 'Using reader battery/time UI';

  @override
  String get settingsAiAssistantTitle => 'AI Reading Assistant';

  @override
  String get settingsSystemSettingsTitle => 'System Settings';

  @override
  String get settingsKeepScreenOnTitle => 'Keep screen on';

  @override
  String get settingsKeepScreenOnSubtitle =>
      'Prevent the screen from turning off while reading';

  @override
  String get settingsAutoSaveTitle => 'Auto save';

  @override
  String get settingsAutoSaveSubtitle => 'Automatically save reading progress';

  @override
  String get settingsHelpPlaceholder => 'Help information can go here';

  @override
  String get settingsAiConfigured => 'AI configured';

  @override
  String get settingsAiNotConfigured => 'API Key not configured yet';

  @override
  String get settingsAiReadyToUse => 'Ready to use';

  @override
  String get settingsAiPendingConfig => 'Pending setup';

  @override
  String settingsAiCurrentPreset(String preset) {
    return 'Current preset: $preset';
  }

  @override
  String settingsAiCurrentCustom(String model) {
    return 'Current configuration: custom · $model';
  }

  @override
  String get settingsAiPresetIntro =>
      'Common providers and models are built in; usually you only need to pick a preset and enter an API Key.';

  @override
  String get settingsAiProviderLabel => 'Provider';

  @override
  String get settingsAiPresetHint => 'Select a preset model';

  @override
  String get settingsAiPresetLabel => 'Preset model';

  @override
  String get settingsAiCustomButton => 'Custom';

  @override
  String get settingsAiPresetSelectedHint =>
      'After selecting a preset, just enter an API Key to start using it.';

  @override
  String get settingsAiCustomActiveHint =>
      'Custom parameters are in use; you can switch back to a preset at any time.';

  @override
  String get settingsAiApiKeyHint => 'Enter to enable the current preset';

  @override
  String get settingsShow => 'Show';

  @override
  String get settingsHide => 'Hide';

  @override
  String get settingsAiSaving => 'Saving...';

  @override
  String get settingsAiSaveConfig => 'Save AI configuration';

  @override
  String get settingsPageIntro =>
      'Only the options that shape your reading experience.';

  @override
  String get settingsAiSwipeHint =>
      'Swipe through models and tap a card to switch.';

  @override
  String get settingsAiLegacyIntro =>
      'Choose a provider and model, then enter your API key.';

  @override
  String get settingsAiModelLabel => 'Model';

  @override
  String get settingsAiUsingCustomParams => 'Using custom model settings';

  @override
  String get settingsAiApiKeyStoredLocally => 'Stored on this device only';

  @override
  String get settingsAiSaveAndEnable => 'Save and enable';

  @override
  String get settingsAboutTagline =>
      'Open source, cross-platform, focused on reading';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsMaintainerLabel => 'Maintainer';

  @override
  String get settingsLicenseLabel => 'License';

  @override
  String get settingsViewSourceSubtitle => 'View open-source project';

  @override
  String get settingsJoinQqGroup => 'Join QQ group';

  @override
  String get settingsQqOpenFailed =>
      'Could not open QQ. Please make sure QQ is installed.';

  @override
  String get contributorsTitle => 'Contributors';

  @override
  String get contributorsSubtitle =>
      'Thanks to everyone making Open Reading better';

  @override
  String get contributorsOpenProfileFailed =>
      'Could not open contributor profile';

  @override
  String get contributorsEmpty => 'No contributors to show yet';

  @override
  String get contributorsLoadFailed => 'Could not load contributors';

  @override
  String get settingsDarkModeTitle => 'Night mode';

  @override
  String settingsCurrentValue(String value) {
    return 'Current: $value';
  }

  @override
  String get settingsUiStyleTitle => 'Glass effect';

  @override
  String get settingsGlassEffectSubtitle =>
      'Use translucent surfaces, background blur, and floating depth';

  @override
  String get settingsAccentFollowTheme => 'Accent color: follow theme';

  @override
  String settingsAccentValue(String name) {
    return 'Accent color: $name';
  }

  @override
  String get settingsAppThemeTitle => 'App theme';

  @override
  String settingsCurrentThemeSummary(String theme, String accent) {
    return 'Current: $theme · $accent';
  }

  @override
  String get settingsFollowAppTheme => 'Follow app theme';

  @override
  String get settingsAccentColorTitle => 'Accent color';

  @override
  String get settingsThemeModeSystemHint =>
      'Switch automatically with the system appearance';

  @override
  String get settingsThemeModeLightHint => 'Always use the light appearance';

  @override
  String get settingsThemeModeDarkHint => 'Always use the dark appearance';

  @override
  String get settingsSelectAppTheme => 'Choose app theme';

  @override
  String get settingsDone => 'Done';

  @override
  String get settingsAccentColorAdvice =>
      'Prefer choosing an app theme first, then override the accent color as needed.';

  @override
  String get settingsAccentFollowThemeOption => 'Follow theme';

  @override
  String get settingsAccentFollowThemeDesc =>
      'Use the current app theme\'s default accent color';

  @override
  String get settingsAboutTitle => 'About';

  @override
  String get settingsAppName => 'Open Reading';

  @override
  String get settingsAuthor => 'Maintainer: 小元Niki';

  @override
  String get settingsGithubRepo => 'GitHub repository';

  @override
  String get settingsNewYearGreeting =>
      'A focused, restrained, and freely modifiable cross-platform reader.';

  @override
  String get settingsGithubOpenFailed => 'Could not open the GitHub link';

  @override
  String get settingsIosOnlyFeature => 'This feature is only available on iOS';

  @override
  String settingsIosSyncResult(String storage, int books, int files) {
    return 'Synced to $storage\n$books books, $files files copied';
  }

  @override
  String get settingsRestartRequiredReason =>
      'This settings change requires an app restart to take full effect.';

  @override
  String get settingsRestartRequiredTitle => 'Restart required';

  @override
  String settingsRestartPrompt(String reason) {
    return '$reason\n\nRestart the app now?';
  }

  @override
  String get settingsRestartLater => 'Later';

  @override
  String get settingsRestartNow => 'Restart';

  @override
  String get statsDetailedTitle => 'Detailed Statistics';

  @override
  String get statsRange7Days => '7 days';

  @override
  String get statsRange30Days => '30 days';

  @override
  String get statsRange90Days => '90 days';

  @override
  String get statsRange1Year => '1 year';

  @override
  String get statsRangeAll => 'All';

  @override
  String get statsTabOverview => 'Overview';

  @override
  String get statsTabCharts => 'Charts';

  @override
  String get statsTabBooks => 'Books';

  @override
  String get statsTabAchievements => 'Achievements';

  @override
  String get statsReadingOverview => 'Reading Overview';

  @override
  String statsCumulativeHours(Object hours) {
    return 'Total $hours hours';
  }

  @override
  String statsStreakEncouragement(Object days) {
    return 'Keep the rhythm — you have read $days days in a row';
  }

  @override
  String get statsTotalDuration => 'Total Time';

  @override
  String get statsAvgSession => 'Avg Session';

  @override
  String statsDaysCount(Object count) {
    return '$count days';
  }

  @override
  String get statsNoData => 'No data';

  @override
  String get statsPeriodEarlyMorning => 'Early morning 05:00-08:59';

  @override
  String get statsPeriodMorning => 'Morning 09:00-11:59';

  @override
  String get statsPeriodAfternoon => 'Afternoon 12:00-17:59';

  @override
  String get statsPeriodEvening => 'Evening 18:00-21:59';

  @override
  String get statsPeriodLateNight => 'Late night 22:00-04:59';

  @override
  String get statsTotalReadingTime => 'Total Reading Time';

  @override
  String get statsTotalPagesRead => 'Total Pages Read';

  @override
  String get statsBooksReadCount => 'Books Read';

  @override
  String get statsUnitPage => 'pages';

  @override
  String get statsTodayProgress => 'Today\'s Reading Progress';

  @override
  String statsMinutesOfTarget(Object current, Object target) {
    return '$current / $target min';
  }

  @override
  String get statsPagesRead => 'Pages Read';

  @override
  String statsPagesOfTarget(Object current, Object target) {
    return '$current / $target pages';
  }

  @override
  String get statsReadingHabits => 'Reading Habits';

  @override
  String get statsBestReadingPeriod => 'Best Reading Time';

  @override
  String get statsAvgSessionReading => 'Avg Session Reading';

  @override
  String get statsMaxStreakDays => 'Longest Streak';

  @override
  String get statsFocusScore => 'Reading Focus';

  @override
  String get statsBookCount => 'Book Count';

  @override
  String get statsTrendAnalysis => 'Reading Trend Analysis';

  @override
  String statsAxisMinutes(Object value) {
    return '$value min';
  }

  @override
  String statsAxisPages(Object value) {
    return '$value pg';
  }

  @override
  String statsAxisBooks(Object value) {
    return '$value bk';
  }

  @override
  String statsAxisHour(Object hour) {
    return '${hour}h';
  }

  @override
  String get statsTimeDistribution => 'Reading Time Distribution';

  @override
  String get statsFormatDistribution => 'Book Format Distribution';

  @override
  String get statsCompleted => 'Completed';

  @override
  String get statsInProgress => 'In Progress';

  @override
  String get statsDurationRanking => 'Reading Time Ranking';

  @override
  String get statsProgressRanking => 'Reading Progress Ranking';

  @override
  String statsPagesCount(Object count) {
    return '$count pages';
  }

  @override
  String statsSessionCount(Object count) {
    return '$count sessions';
  }

  @override
  String statsAchievementsSummary(Object achieved, Object remaining) {
    return 'Earned $achieved achievements, $remaining more to unlock';
  }

  @override
  String get statsAchievementFirstReadTitle => 'First Read';

  @override
  String get statsAchievementFirstReadDesc =>
      'Complete your first reading session';

  @override
  String get statsAchievementNoviceTitle => 'Reading Novice';

  @override
  String get statsAchievementNoviceDesc => 'Read for a total of 10 hours';

  @override
  String get statsAchievementBookwormTitle => 'Bookworm';

  @override
  String get statsAchievementBookwormDesc => 'Read for a total of 100 hours';

  @override
  String get statsAchievementExpertTitle => 'Reading Expert';

  @override
  String get statsAchievementExpertDesc => 'Read 7 days in a row';

  @override
  String get statsAchievementOceanTitle => 'Ocean of Knowledge';

  @override
  String get statsAchievementOceanDesc => 'Read 10,000 pages';

  @override
  String get statsAchievementScholarTitle => 'Polymath';

  @override
  String get statsAchievementScholarDesc => 'Read 10 different books';

  @override
  String get statsAchievementMarathonTitle => 'Reading Marathon';

  @override
  String get statsAchievementMarathonDesc => 'Read 30 days in a row';

  @override
  String get statsAchievementFocusTitle => 'Focus Master';

  @override
  String get statsAchievementFocusDesc => 'Read for a total of 500 hours';

  @override
  String statsProgressPercent(Object percent) {
    return 'Progress: $percent%';
  }

  @override
  String get statsGoalProgress => 'Reading Goal Progress';

  @override
  String get statsMonthlyReadingTime => 'This Month\'s Reading Time';

  @override
  String get statsWeeklyReadingTime => 'This Week\'s Reading Time';

  @override
  String get statsAvgDailyPages7d => 'Daily Avg Pages (Last 7 Days)';

  @override
  String statsHoursCount(Object count) {
    return '$count hours';
  }

  @override
  String get statsSpeedTrend => 'Reading Speed Trend';

  @override
  String statsAvgSpeed(Object speed) {
    return 'Avg: $speed pages/min';
  }

  @override
  String get statsReadingContinuity => 'Reading Continuity';

  @override
  String statsCurrentStreak(Object days) {
    return 'Current streak: $days days';
  }

  @override
  String get statsHeatmapLess => 'Less';

  @override
  String get statsHeatmapMore => 'More';

  @override
  String statsWeekNumber(Object week) {
    return 'Week $week';
  }

  @override
  String get readerThemeTitle => 'Reading theme';

  @override
  String get readerThemeDescription =>
      'Only changes the reading page and its controls';

  @override
  String get readerThemeDay => 'Day';

  @override
  String get readerThemeNight => 'Night';

  @override
  String get readerThemeParchment => 'Parchment';
}
