import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Xiaoyuan Reader'**
  String get appTitle;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Library tab label
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get library;

  /// Settings tab label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// Statistics tab label
  ///
  /// In en, this message translates to:
  /// **'Statistics'**
  String get statistics;

  /// Reading page title
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get reading;

  /// Import books button label
  ///
  /// In en, this message translates to:
  /// **'Import Books'**
  String get importBooks;

  /// Dark mode setting label
  ///
  /// In en, this message translates to:
  /// **'Dark Mode'**
  String get darkMode;

  /// Light mode setting label
  ///
  /// In en, this message translates to:
  /// **'Light Mode'**
  String get lightMode;

  /// System theme mode setting label
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemMode;

  /// Theme setting section
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get theme;

  /// Accent color setting label
  ///
  /// In en, this message translates to:
  /// **'Accent Color'**
  String get accent;

  /// Bookmarks feature label
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get bookmarks;

  /// Notes feature label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notes;

  /// Highlights feature label
  ///
  /// In en, this message translates to:
  /// **'Highlights'**
  String get highlights;

  /// TTS reading feature label
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get ttsReading;

  /// Share button label
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// Share content dialog title
  ///
  /// In en, this message translates to:
  /// **'Share Content'**
  String get shareContent;

  /// Share current page option
  ///
  /// In en, this message translates to:
  /// **'Share Current Page'**
  String get shareCurrentPage;

  /// Share selected text option
  ///
  /// In en, this message translates to:
  /// **'Share Selected Text'**
  String get shareSelectedText;

  /// Share reading progress option
  ///
  /// In en, this message translates to:
  /// **'Share Reading Progress'**
  String get shareProgress;

  /// Play TTS button
  ///
  /// In en, this message translates to:
  /// **'Play'**
  String get play;

  /// Pause TTS button
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// Stop TTS button
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// TTS speed setting
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// TTS pitch setting
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get pitch;

  /// Language setting
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// Font size setting
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSize;

  /// Reading progress indicator
  ///
  /// In en, this message translates to:
  /// **'Reading Progress'**
  String get readingProgress;

  /// Total pages label
  ///
  /// In en, this message translates to:
  /// **'Total Pages'**
  String get totalPages;

  /// Current page label
  ///
  /// In en, this message translates to:
  /// **'Current Page'**
  String get currentPage;

  /// Reading time statistics
  ///
  /// In en, this message translates to:
  /// **'Reading Time'**
  String get readingTime;

  /// Books read statistics
  ///
  /// In en, this message translates to:
  /// **'Books Read'**
  String get booksRead;

  /// Today's reading time
  ///
  /// In en, this message translates to:
  /// **'Today\'s Reading'**
  String get todayReading;

  /// Cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// Confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// Delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// Edit button
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// Save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// Back button
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// Next button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// Previous button
  ///
  /// In en, this message translates to:
  /// **'Previous'**
  String get previous;

  /// Search function
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No search results message
  ///
  /// In en, this message translates to:
  /// **'No results found'**
  String get noResults;

  /// Loading indicator text
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// Error message
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// Initialization failed message
  ///
  /// In en, this message translates to:
  /// **'Initialization failed'**
  String get initializationFailed;

  /// Unknown error message
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get unknownError;

  /// Retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// Appearance settings section
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearanceSettings;

  /// Reading tips section
  ///
  /// In en, this message translates to:
  /// **'Reading Tips'**
  String get readingTips;

  /// Message about moved font settings
  ///
  /// In en, this message translates to:
  /// **'Reading font settings moved'**
  String get readingFontSettingsMoved;

  /// Hint about font settings location
  ///
  /// In en, this message translates to:
  /// **'Open any book, tap the center of the screen, then use the bottom toolbar to adjust font size, line spacing, letter spacing, margins, and reading font.'**
  String get readingFontSettingsHint;

  /// Reading settings section
  ///
  /// In en, this message translates to:
  /// **'Reading Settings'**
  String get readingSettings;

  /// Enable text-to-speech option
  ///
  /// In en, this message translates to:
  /// **'Enable TTS'**
  String get enableTts;

  /// Hint about enabling TTS
  ///
  /// In en, this message translates to:
  /// **'Enable text-to-speech reading'**
  String get enableTtsHint;

  /// TTS speed label
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ttsSpeedLabel;

  /// Hint for TTS speed
  ///
  /// In en, this message translates to:
  /// **'Adjust reading speed'**
  String get ttsSpeedHint;

  /// TTS volume label
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get ttsVolumeLabel;

  /// Hint for TTS volume
  ///
  /// In en, this message translates to:
  /// **'Adjust reading volume'**
  String get ttsVolumeHint;

  /// TTS pitch label
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get ttsPitchLabel;

  /// Hint for TTS pitch
  ///
  /// In en, this message translates to:
  /// **'Adjust reading pitch'**
  String get ttsPitchHint;

  /// Cloud sync section
  ///
  /// In en, this message translates to:
  /// **'Cloud Sync'**
  String get cloudSync;

  /// WebDAV configuration
  ///
  /// In en, this message translates to:
  /// **'WebDAV'**
  String get webdavConfig;

  /// WebDAV configured status
  ///
  /// In en, this message translates to:
  /// **'Configured - {serverUrl}'**
  String webdavConfigured(Object serverUrl);

  /// Hint for WebDAV config
  ///
  /// In en, this message translates to:
  /// **'Tap to configure WebDAV server'**
  String get webdavConfigHint;

  /// App settings section
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// App font setting
  ///
  /// In en, this message translates to:
  /// **'App Font'**
  String get appFont;

  /// System default font
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get fontSystem;

  /// Source Han Sans font
  ///
  /// In en, this message translates to:
  /// **'Source Han Sans'**
  String get fontSourceHanSans;

  /// JetBrains Mono font
  ///
  /// In en, this message translates to:
  /// **'JetBrains Mono'**
  String get fontJetBrainsMono;

  /// Follow system language
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get languageSystem;

  /// Chinese language
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get languageChinese;

  /// English language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Typography settings section
  ///
  /// In en, this message translates to:
  /// **'Typography'**
  String get typographySettings;

  /// Font family label
  ///
  /// In en, this message translates to:
  /// **'Font'**
  String get fontFamilyLabel;

  /// Font size label
  ///
  /// In en, this message translates to:
  /// **'Font Size'**
  String get fontSizeLabel;

  /// Line spacing label
  ///
  /// In en, this message translates to:
  /// **'Line Spacing'**
  String get lineSpacingLabel;

  /// Letter spacing label
  ///
  /// In en, this message translates to:
  /// **'Letter Spacing'**
  String get letterSpacingLabel;

  /// First line indent label
  ///
  /// In en, this message translates to:
  /// **'First-line Indent'**
  String get firstLineIndentLabel;

  /// Page margin label
  ///
  /// In en, this message translates to:
  /// **'Page Margin'**
  String get pageMarginLabel;

  /// Reset to default button
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetDefault;

  /// TTS panel title
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get ttsPanelTitle;

  /// Preview effect label
  ///
  /// In en, this message translates to:
  /// **'Preview Effect'**
  String get ttsPreviewEffect;

  /// TTS volume
  ///
  /// In en, this message translates to:
  /// **'Volume'**
  String get ttsVolume;

  /// TTS pitch
  ///
  /// In en, this message translates to:
  /// **'Pitch'**
  String get ttsPitch;

  /// TTS speed
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get ttsSpeed;

  /// Previous sentence button
  ///
  /// In en, this message translates to:
  /// **'Previous Sentence'**
  String get ttsPreviousSentence;

  /// Next sentence button
  ///
  /// In en, this message translates to:
  /// **'Next Sentence'**
  String get ttsNextSentence;

  /// Timer stop label
  ///
  /// In en, this message translates to:
  /// **'Timer Stop'**
  String get ttsTimerStop;

  /// No time limit option
  ///
  /// In en, this message translates to:
  /// **'No Limit'**
  String get ttsTimerOff;

  /// Timer minutes option
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes'**
  String ttsTimerMinutes(Object minutes);

  /// TTS playing status
  ///
  /// In en, this message translates to:
  /// **'Playing'**
  String get ttsPlaying;

  /// TTS paused status
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get ttsPaused;

  /// TTS stopped status
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get ttsStopped;

  /// Previous sentence failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to play previous sentence'**
  String get ttsPreviousSentenceFailed;

  /// Next sentence failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to play next sentence'**
  String get ttsNextSentenceFailed;

  /// Empty content error
  ///
  /// In en, this message translates to:
  /// **'Current page content is empty'**
  String get ttsEmptyContentError;

  /// Playback failed message
  ///
  /// In en, this message translates to:
  /// **'Playback failed'**
  String get ttsPlaybackFailed;

  /// Operation failed message
  ///
  /// In en, this message translates to:
  /// **'Operation failed'**
  String get ttsOperationFailed;

  /// Page turning settings
  ///
  /// In en, this message translates to:
  /// **'Page Turning'**
  String get pageTurningSettings;

  /// Page turning mode
  ///
  /// In en, this message translates to:
  /// **'Page Mode'**
  String get pageTurningMode;

  /// Cover page turning
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get pageTurningCover;

  /// Slide page turning
  ///
  /// In en, this message translates to:
  /// **'Slide'**
  String get pageTurningSlide;

  /// Scroll page turning
  ///
  /// In en, this message translates to:
  /// **'Scroll'**
  String get pageTurningScroll;

  /// Simulation page turning
  ///
  /// In en, this message translates to:
  /// **'Simulation'**
  String get pageTurningSimulation;

  /// Tap zone settings
  ///
  /// In en, this message translates to:
  /// **'Tap Zones'**
  String get tapZoneSettings;

  /// Next page tap zone
  ///
  /// In en, this message translates to:
  /// **'Next Page'**
  String get tapZoneNextPage;

  /// Previous page tap zone
  ///
  /// In en, this message translates to:
  /// **'Previous Page'**
  String get tapZonePreviousPage;

  /// Menu tap zone
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get tapZoneMenu;

  /// Tap zone legend
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get tapZoneLegend;

  /// Highlight color label
  ///
  /// In en, this message translates to:
  /// **'Highlight Color'**
  String get highlightColor;

  /// Highlight preview
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get highlightPreview;

  /// Sample text for highlight preview
  ///
  /// In en, this message translates to:
  /// **'This is a sample text,'**
  String get highlightSampleText;

  /// Sample text part 2
  ///
  /// In en, this message translates to:
  /// **'this part will be highlighted,'**
  String get highlightSampleText2;

  /// Sample text part 3
  ///
  /// In en, this message translates to:
  /// **'showing the highlight effect.'**
  String get highlightSampleText3;

  /// WebDAV configuration title
  ///
  /// In en, this message translates to:
  /// **'WebDAV Configuration'**
  String get webdavTitle;

  /// Setup cloud sync hint
  ///
  /// In en, this message translates to:
  /// **'Setup Cloud Sync Service'**
  String get webdavSetupCloudSync;

  /// WebDAV server URL label
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get webdavServerUrl;

  /// WebDAV username label
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get webdavUsername;

  /// WebDAV password label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get webdavPassword;

  /// Enter server URL error
  ///
  /// In en, this message translates to:
  /// **'Please enter server URL'**
  String get webdavEnterServerUrl;

  /// Invalid URL error
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid URL'**
  String get webdavInvalidUrl;

  /// Enter username error
  ///
  /// In en, this message translates to:
  /// **'Please enter username'**
  String get webdavEnterUsername;

  /// Enter password error
  ///
  /// In en, this message translates to:
  /// **'Please enter password'**
  String get webdavEnterPassword;

  /// Connection failed message
  ///
  /// In en, this message translates to:
  /// **'Connection failed, please check settings'**
  String get webdavConnectionFailed;

  /// Test connection button
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get webdavTestConnection;

  /// Save configuration button
  ///
  /// In en, this message translates to:
  /// **'Save Configuration'**
  String get webdavSaveConfig;

  /// Clear configuration button
  ///
  /// In en, this message translates to:
  /// **'Clear Configuration'**
  String get webdavClearConfig;

  /// Test success message
  ///
  /// In en, this message translates to:
  /// **'Connection test successful!'**
  String get webdavTestSuccess;

  /// Test failed message
  ///
  /// In en, this message translates to:
  /// **'Connection test failed'**
  String get webdavTestFailed;

  /// Config saved message
  ///
  /// In en, this message translates to:
  /// **'WebDAV configuration saved'**
  String get webdavConfigSaved;

  /// Save config failed message
  ///
  /// In en, this message translates to:
  /// **'Failed to save configuration'**
  String get webdavConfigSaveFailed;

  /// Confirm clear message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to clear WebDAV configuration?'**
  String get webdavConfirmClear;

  /// Config cleared message
  ///
  /// In en, this message translates to:
  /// **'WebDAV configuration cleared'**
  String get webdavConfigCleared;

  /// Light blue color name
  ///
  /// In en, this message translates to:
  /// **'Light Blue'**
  String get colorLightBlue;

  /// Red color name
  ///
  /// In en, this message translates to:
  /// **'Red'**
  String get colorRed;

  /// Green color name
  ///
  /// In en, this message translates to:
  /// **'Green'**
  String get colorGreen;

  /// Purple color name
  ///
  /// In en, this message translates to:
  /// **'Purple'**
  String get colorPurple;

  /// Gold color name
  ///
  /// In en, this message translates to:
  /// **'Gold'**
  String get colorGold;

  /// Orange color name
  ///
  /// In en, this message translates to:
  /// **'Orange'**
  String get colorOrange;

  /// Yellow color name
  ///
  /// In en, this message translates to:
  /// **'Yellow'**
  String get colorYellow;

  /// Dark green color name
  ///
  /// In en, this message translates to:
  /// **'Dark Green'**
  String get colorDarkGreen;

  /// Custom color name
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get colorCustom;

  /// Highlight note type
  ///
  /// In en, this message translates to:
  /// **'Highlight'**
  String get noteTypeHighlight;

  /// Underline note type
  ///
  /// In en, this message translates to:
  /// **'Underline'**
  String get noteTypeUnderline;

  /// Note type
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get noteTypeNote;

  /// Unknown note type
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get noteTypeUnknown;

  /// TXT book format
  ///
  /// In en, this message translates to:
  /// **'TXT'**
  String get bookFormatTXT;

  /// EPUB book format
  ///
  /// In en, this message translates to:
  /// **'EPUB'**
  String get bookFormatEPUB;

  /// PDF book format
  ///
  /// In en, this message translates to:
  /// **'PDF'**
  String get bookFormatPDF;

  /// Import book action
  ///
  /// In en, this message translates to:
  /// **'Import Book'**
  String get importBook;

  /// Import from files
  ///
  /// In en, this message translates to:
  /// **'Import from Files'**
  String get importFromFiles;

  /// No books message
  ///
  /// In en, this message translates to:
  /// **'No books imported yet'**
  String get importNoBooks;

  /// Import success message
  ///
  /// In en, this message translates to:
  /// **'Book imported successfully'**
  String get importSuccess;

  /// Import failed message
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importFailed;

  /// Import processing message
  ///
  /// In en, this message translates to:
  /// **'Processing book...'**
  String get importProcessing;

  /// Author label
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get author;

  /// Progress label
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// Continue reading button
  ///
  /// In en, this message translates to:
  /// **'Continue Reading'**
  String get continueReading;

  /// Recent books section
  ///
  /// In en, this message translates to:
  /// **'Recent Books'**
  String get recentBooks;

  /// All books section
  ///
  /// In en, this message translates to:
  /// **'All Books'**
  String get allBooks;

  /// Empty library message
  ///
  /// In en, this message translates to:
  /// **'Library is empty'**
  String get emptyLibrary;

  /// Delete book action
  ///
  /// In en, this message translates to:
  /// **'Delete Book'**
  String get deleteBook;

  /// Delete book confirmation
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this book?'**
  String get deleteBookConfirm;

  /// Book deleted message
  ///
  /// In en, this message translates to:
  /// **'Book deleted'**
  String get bookDeleted;

  /// User agreement title
  ///
  /// In en, this message translates to:
  /// **'User Agreement'**
  String get userAgreement;

  /// Accept agreement checkbox
  ///
  /// In en, this message translates to:
  /// **'I have read and agree'**
  String get acceptAgreement;

  /// Decline agreement button
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get declineAgreement;

  /// Today's statistics
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get statsToday;

  /// This week's statistics
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get statsThisWeek;

  /// Total statistics
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get statsTotal;

  /// Reading minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String statsMinutes(Object minutes);

  /// Reading hours
  ///
  /// In en, this message translates to:
  /// **'{hours} h'**
  String statsHours(Object hours);

  /// Book count
  ///
  /// In en, this message translates to:
  /// **'{count} books'**
  String statsBooks(Object count);

  /// Consecutive reading days
  ///
  /// In en, this message translates to:
  /// **'Consecutive Days'**
  String get statsConsecutiveDays;

  /// Focus time
  ///
  /// In en, this message translates to:
  /// **'Focus Time'**
  String get statsFocusTime;

  /// This week total
  ///
  /// In en, this message translates to:
  /// **'This Week Total'**
  String get statsThisWeekTotal;

  /// Keep reading daily tip
  ///
  /// In en, this message translates to:
  /// **'Keep Reading Daily'**
  String get statsKeepReading;

  /// Maximum session
  ///
  /// In en, this message translates to:
  /// **'Max Session'**
  String get statsMaxSession;

  /// Weekly reading trend
  ///
  /// In en, this message translates to:
  /// **'Weekly Trend'**
  String get statsWeeklyTrend;

  /// Reading achievements
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get statsAchievements;

  /// Reader toolbar menu
  ///
  /// In en, this message translates to:
  /// **'Menu'**
  String get readerToolbarMenu;

  /// Table of contents
  ///
  /// In en, this message translates to:
  /// **'Table of Contents'**
  String get readerToolbarTOC;

  /// Reader settings
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get readerToolbarSettings;

  /// Add bookmark
  ///
  /// In en, this message translates to:
  /// **'Add Bookmark'**
  String get readerAddBookmark;

  /// Add note
  ///
  /// In en, this message translates to:
  /// **'Add Note'**
  String get readerAddNote;

  /// Share content
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get readerShare;

  /// Bookmark added message
  ///
  /// In en, this message translates to:
  /// **'Bookmark added'**
  String get bookmarkAdded;

  /// Bookmark removed message
  ///
  /// In en, this message translates to:
  /// **'Bookmark removed'**
  String get bookmarkRemoved;

  /// Blue theme name
  ///
  /// In en, this message translates to:
  /// **'Ocean Blue'**
  String get themeBlue;

  /// Purple theme name
  ///
  /// In en, this message translates to:
  /// **'Mystic Purple'**
  String get themePurple;

  /// Green theme name
  ///
  /// In en, this message translates to:
  /// **'Forest Green'**
  String get themeGreen;

  /// Orange theme name
  ///
  /// In en, this message translates to:
  /// **'Vibrant Orange'**
  String get themeOrange;

  /// Red theme name
  ///
  /// In en, this message translates to:
  /// **'Passionate Red'**
  String get themeRed;

  /// Custom theme name
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get themeCustom;

  /// Left/Right tap zone
  ///
  /// In en, this message translates to:
  /// **'Left/Right'**
  String get tapZoneLeftRight;

  /// Left/Center/Right tap zone
  ///
  /// In en, this message translates to:
  /// **'Left/Center/Right'**
  String get tapZoneLeftCenterRight;

  /// Homepage app tagline under title
  ///
  /// In en, this message translates to:
  /// **'Read beautifully'**
  String get homeTagline;

  /// Home dashboard page title
  ///
  /// In en, this message translates to:
  /// **'Reading Stats'**
  String get homeReadingStatsTitle;

  /// Hero card title for today reading
  ///
  /// In en, this message translates to:
  /// **'Today\'s Reading Moment'**
  String get homeTodayReadingMoment;

  /// Encouragement text with today minutes
  ///
  /// In en, this message translates to:
  /// **'Read {minutes} minutes, keep going'**
  String homeReadMinutesKeepGoing(int minutes);

  /// Prompt when there is no reading today
  ///
  /// In en, this message translates to:
  /// **'Start your reading journey today'**
  String get homeTodayReadingJourneyStart;

  /// Prompt when today reading is positive
  ///
  /// In en, this message translates to:
  /// **'You are on track today, keep the rhythm'**
  String get homeTodayReadingKeepRhythm;

  /// Generic reading prompt text
  ///
  /// In en, this message translates to:
  /// **'Save some time for reading today'**
  String get homeTodayReadingPrompt;

  /// Total reading hours text with value
  ///
  /// In en, this message translates to:
  /// **'Total reading {hours} hours'**
  String homeTotalReadingHours(String hours);

  /// Weekly reading label
  ///
  /// In en, this message translates to:
  /// **'This Week'**
  String get homeWeeklyReading;

  /// Total reading label
  ///
  /// In en, this message translates to:
  /// **'Total Reading'**
  String get homeTotalReading;

  /// Library books count label
  ///
  /// In en, this message translates to:
  /// **'Library Books'**
  String get homeLibraryCount;

  /// Short label for collection count
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get homeCollectionCount;

  /// Section title for key metrics
  ///
  /// In en, this message translates to:
  /// **'Key Metrics'**
  String get homeKeyMetrics;

  /// Section title for reading rhythm
  ///
  /// In en, this message translates to:
  /// **'Reading Rhythm'**
  String get homeReadingRhythm;

  /// Section title for achievements
  ///
  /// In en, this message translates to:
  /// **'Reading Achievements'**
  String get homeAchievements;

  /// Achievement title consecutive reading
  ///
  /// In en, this message translates to:
  /// **'Consecutive Reading'**
  String get homeConsecutiveReading;

  /// Achievement description for consecutive reading
  ///
  /// In en, this message translates to:
  /// **'Keep a daily reading habit'**
  String get homeConsecutiveReadingDesc;

  /// Achievement title for focus duration
  ///
  /// In en, this message translates to:
  /// **'Focus Duration'**
  String get homeFocusDuration;

  /// Achievement description for focus duration
  ///
  /// In en, this message translates to:
  /// **'Longest single reading session'**
  String get homeFocusDurationDesc;

  /// Achievement title for weekly total
  ///
  /// In en, this message translates to:
  /// **'Weekly Total'**
  String get homeWeeklyTotal;

  /// Achievement description for weekly total
  ///
  /// In en, this message translates to:
  /// **'Reading time this week'**
  String get homeWeeklyTotalDesc;

  /// Section title for recent reading books
  ///
  /// In en, this message translates to:
  /// **'Recent Reading'**
  String get homeRecentReading;

  /// Chart title for weekly trend
  ///
  /// In en, this message translates to:
  /// **'Weekly Reading Trend'**
  String get homeWeeklyTrend;

  /// Bar chart tooltip text for minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String homeBarTooltipMinutes(int minutes);

  /// Minute unit label
  ///
  /// In en, this message translates to:
  /// **'min'**
  String get unitMinute;

  /// Hour unit label
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get unitHour;

  /// Book unit label
  ///
  /// In en, this message translates to:
  /// **'books'**
  String get unitBook;

  /// Day unit label
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get unitDay;

  /// Short label for Monday
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get weekdayMonShort;

  /// Short label for Tuesday
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get weekdayTueShort;

  /// Short label for Wednesday
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get weekdayWedShort;

  /// Short label for Thursday
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get weekdayThuShort;

  /// Short label for Friday
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get weekdayFriShort;

  /// Short label for Saturday
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get weekdaySatShort;

  /// Short label for Sunday
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get weekdaySunShort;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
