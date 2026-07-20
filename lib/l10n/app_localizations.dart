import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('ja'),
    Locale('zh'),
    Locale('zh', 'TW')
  ];

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'OpenReading'**
  String get appTitle;

  /// Home tab label
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// Library tab label
  ///
  /// In en, this message translates to:
  /// **'Bookshelf'**
  String get library;

  /// Book sources tab label
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get bookSources;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @discoverRecommended.
  ///
  /// In en, this message translates to:
  /// **'For you'**
  String get discoverRecommended;

  /// No description provided for @discoverCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get discoverCategories;

  /// No description provided for @discoverLatest.
  ///
  /// In en, this message translates to:
  /// **'Latest'**
  String get discoverLatest;

  /// No description provided for @discoverLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load discovery content'**
  String get discoverLoadFailed;

  /// No description provided for @discoverRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get discoverRetry;

  /// No description provided for @discoverUnsupportedTitle.
  ///
  /// In en, this message translates to:
  /// **'Current sources do not support this section'**
  String get discoverUnsupportedTitle;

  /// No description provided for @discoverUnsupportedMessage.
  ///
  /// In en, this message translates to:
  /// **'A source with the {capability} capability is required. Existing sources can still be searched.'**
  String discoverUnsupportedMessage(String capability);

  /// No description provided for @discoverCategoryEmpty.
  ///
  /// In en, this message translates to:
  /// **'There are no books to show in this category yet.'**
  String get discoverCategoryEmpty;

  /// No description provided for @bookSourceManagementTitle.
  ///
  /// In en, this message translates to:
  /// **'Manage sources'**
  String get bookSourceManagementTitle;

  /// No description provided for @bookSourceManagementSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, enable, remove, and inspect content providers. Discovery stays focused on finding books.'**
  String get bookSourceManagementSubtitle;

  /// No description provided for @settingsContentSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Content sources'**
  String get settingsContentSourcesTitle;

  /// No description provided for @settingsContentSourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add, enable, or remove open book sources'**
  String get settingsContentSourcesSubtitle;

  /// No description provided for @bookSourcesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect open sources and search readable content across providers'**
  String get bookSourcesSubtitle;

  /// No description provided for @bookSourcesAdd.
  ///
  /// In en, this message translates to:
  /// **'Add source'**
  String get bookSourcesAdd;

  /// No description provided for @bookSourcesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search enabled sources by title or author'**
  String get bookSourcesSearchHint;

  /// No description provided for @bookSourcesSearch.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get bookSourcesSearch;

  /// No description provided for @bookSourcesLoadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get bookSourcesLoadMore;

  /// No description provided for @bookSourcesFailedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} source request(s) failed'**
  String bookSourcesFailedCount(int count);

  /// No description provided for @bookSourcesSearchPrompt.
  ///
  /// In en, this message translates to:
  /// **'Add and enable a source to search it here'**
  String get bookSourcesSearchPrompt;

  /// No description provided for @bookSourcesNoResults.
  ///
  /// In en, this message translates to:
  /// **'No matching books found'**
  String get bookSourcesNoResults;

  /// No description provided for @bookSourcesNoSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'No sources yet'**
  String get bookSourcesNoSourcesTitle;

  /// No description provided for @bookSourcesNoSourcesDescription.
  ///
  /// In en, this message translates to:
  /// **'Paste the address of a service compatible with the Open Reading Source Protocol.'**
  String get bookSourcesNoSourcesDescription;

  /// No description provided for @bookSourcesManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Connected sources'**
  String get bookSourcesManageTitle;

  /// No description provided for @bookSourcesEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get bookSourcesEnabled;

  /// No description provided for @bookSourcesDisabled.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get bookSourcesDisabled;

  /// No description provided for @bookSourcesRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get bookSourcesRemove;

  /// No description provided for @bookSourcesRemoveTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove source'**
  String get bookSourcesRemoveTitle;

  /// No description provided for @bookSourcesRemoveMessage.
  ///
  /// In en, this message translates to:
  /// **'This only removes the source configuration. Local books are not affected.'**
  String get bookSourcesRemoveMessage;

  /// No description provided for @bookSourcesCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get bookSourcesCancel;

  /// No description provided for @bookSourcesConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get bookSourcesConfirm;

  /// No description provided for @bookSourcesAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add open source'**
  String get bookSourcesAddTitle;

  /// No description provided for @bookSourcesUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Source address'**
  String get bookSourcesUrlLabel;

  /// No description provided for @bookSourcesUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com or a discovery document URL'**
  String get bookSourcesUrlHint;

  /// No description provided for @bookSourcesNoOfficialSourcesNotice.
  ///
  /// In en, this message translates to:
  /// **'OpenReading includes no sources and does not operate, recommend, or endorse third-party source services. Every source address is added by you.'**
  String get bookSourcesNoOfficialSourcesNotice;

  /// No description provided for @bookSourcesResponsibilityAck.
  ///
  /// In en, this message translates to:
  /// **'I confirm that I am authorized to access this content and will not use the source to bypass sign-in, payment, DRM, or other access controls.'**
  String get bookSourcesResponsibilityAck;

  /// No description provided for @bookSourcesConnect.
  ///
  /// In en, this message translates to:
  /// **'Connect and validate'**
  String get bookSourcesConnect;

  /// No description provided for @bookSourcesConnecting.
  ///
  /// In en, this message translates to:
  /// **'Validating protocol…'**
  String get bookSourcesConnecting;

  /// No description provided for @bookSourcesAdded.
  ///
  /// In en, this message translates to:
  /// **'Source added'**
  String get bookSourcesAdded;

  /// No description provided for @bookSourcesProtocolTitle.
  ///
  /// In en, this message translates to:
  /// **'Open Reading Source Protocol'**
  String get bookSourcesProtocolTitle;

  /// No description provided for @bookSourcesProtocolDescription.
  ///
  /// In en, this message translates to:
  /// **'A common contract for discovery, search, book details, catalogs, and chapter content. Developers can host native sources or build adapters for content they are authorized to serve.'**
  String get bookSourcesProtocolDescription;

  /// No description provided for @bookSourcesProtocolDetails.
  ///
  /// In en, this message translates to:
  /// **'View protocol'**
  String get bookSourcesProtocolDetails;

  /// No description provided for @bookSourcesProtocolRepository.
  ///
  /// In en, this message translates to:
  /// **'Protocol repository'**
  String get bookSourcesProtocolRepository;

  /// No description provided for @bookSourcesProtocolRepositoryOpen.
  ///
  /// In en, this message translates to:
  /// **'View on GitHub'**
  String get bookSourcesProtocolRepositoryOpen;

  /// No description provided for @bookSourcesProtocolRepositoryOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the protocol repository'**
  String get bookSourcesProtocolRepositoryOpenFailed;

  /// No description provided for @bookSourcesProtocolDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Open source protocol v1.3'**
  String get bookSourcesProtocolDialogTitle;

  /// No description provided for @bookSourcesProtocolDialogBody.
  ///
  /// In en, this message translates to:
  /// **'A source publishes /.well-known/open-reading-source.json and implements search, book details, paginated chapter catalogs, and chapter content. Version 1.3 adds complete catalog pagination while retaining operator, contact, license, and rights-statement metadata for public HTTP(S) sources that do not require sign-in.'**
  String get bookSourcesProtocolDialogBody;

  /// No description provided for @bookSourcesRightsDetails.
  ///
  /// In en, this message translates to:
  /// **'Operator and rights'**
  String get bookSourcesRightsDetails;

  /// No description provided for @bookSourcesOperator.
  ///
  /// In en, this message translates to:
  /// **'Source operator'**
  String get bookSourcesOperator;

  /// No description provided for @bookSourcesContentLicense.
  ///
  /// In en, this message translates to:
  /// **'Content license'**
  String get bookSourcesContentLicense;

  /// No description provided for @bookSourcesRightsStatement.
  ///
  /// In en, this message translates to:
  /// **'Rights statement'**
  String get bookSourcesRightsStatement;

  /// No description provided for @bookSourcesRightsNotProvided.
  ///
  /// In en, this message translates to:
  /// **'Not provided by this source'**
  String get bookSourcesRightsNotProvided;

  /// No description provided for @bookSourcesRightsUnverifiedNotice.
  ///
  /// In en, this message translates to:
  /// **'These statements are supplied by the independent source operator. OpenReading displays them for transparency but does not verify or endorse them.'**
  String get bookSourcesRightsUnverifiedNotice;

  /// No description provided for @bookSourcesContactOperator.
  ///
  /// In en, this message translates to:
  /// **'Contact operator'**
  String get bookSourcesContactOperator;

  /// No description provided for @bookSourcesRightsReport.
  ///
  /// In en, this message translates to:
  /// **'Rights report'**
  String get bookSourcesRightsReport;

  /// No description provided for @bookSourcesRightsReportOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the rights-report form'**
  String get bookSourcesRightsReportOpenFailed;

  /// No description provided for @bookSourcesClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get bookSourcesClose;

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

  /// App settings section
  ///
  /// In en, this message translates to:
  /// **'App Settings'**
  String get appSettings;

  /// App font setting
  ///
  /// In en, this message translates to:
  /// **'App font'**
  String get appFont;

  /// Explains the scope of the app font
  ///
  /// In en, this message translates to:
  /// **'Used by navigation, buttons, settings, and other interface text. It does not change book content.'**
  String get appFontDescription;

  /// Reader content font setting
  ///
  /// In en, this message translates to:
  /// **'Reading font'**
  String get readerFont;

  /// Explains the scope of the reading font
  ///
  /// In en, this message translates to:
  /// **'Used only for book text and chapter headings. It does not change the app interface.'**
  String get readerFontDescription;

  /// System default font
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get fontSystem;

  /// Source Han Serif font
  ///
  /// In en, this message translates to:
  /// **'Source Han Serif'**
  String get fontSourceHanSerif;

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

  /// Instrument Sans font
  ///
  /// In en, this message translates to:
  /// **'Instrument Sans'**
  String get fontInstrumentSans;

  /// Newsreader font
  ///
  /// In en, this message translates to:
  /// **'Newsreader'**
  String get fontNewsreader;

  /// System font option description
  ///
  /// In en, this message translates to:
  /// **'Follows the native font of the current device and operating system.'**
  String get fontSystemDescription;

  /// Serif font option description
  ///
  /// In en, this message translates to:
  /// **'Serif type with a calm, editorial character for sustained reading.'**
  String get fontSerifDescription;

  /// Sans serif font option description
  ///
  /// In en, this message translates to:
  /// **'Clear sans serif type suited to compact interfaces and everyday reading.'**
  String get fontSansSerifDescription;

  /// Monospace font option description
  ///
  /// In en, this message translates to:
  /// **'Fixed-width type suited to code, technical material, and focused layouts.'**
  String get fontMonospaceDescription;

  /// Bilingual font preview sample
  ///
  /// In en, this message translates to:
  /// **'Open Reading · Read freely 开卷有益'**
  String get fontPreviewText;

  /// No description provided for @customFonts.
  ///
  /// In en, this message translates to:
  /// **'My fonts'**
  String get customFonts;

  /// No description provided for @customFontsEmpty.
  ///
  /// In en, this message translates to:
  /// **'No custom fonts yet'**
  String get customFontsEmpty;

  /// No description provided for @customFontsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Import a TTF or OTF file once, then use it for the app interface or reading.'**
  String get customFontsEmptyHint;

  /// No description provided for @customFontsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} imported fonts'**
  String customFontsCount(int count);

  /// No description provided for @customFontsLocalOnly.
  ///
  /// In en, this message translates to:
  /// **'Imported fonts are stored only on this device and are not synced automatically.'**
  String get customFontsLocalOnly;

  /// No description provided for @builtInFonts.
  ///
  /// In en, this message translates to:
  /// **'Built-in fonts'**
  String get builtInFonts;

  /// No description provided for @importFont.
  ///
  /// In en, this message translates to:
  /// **'Import font'**
  String get importFont;

  /// No description provided for @importingFont.
  ///
  /// In en, this message translates to:
  /// **'Importing font…'**
  String get importingFont;

  /// No description provided for @customFontImported.
  ///
  /// In en, this message translates to:
  /// **'Font imported'**
  String get customFontImported;

  /// No description provided for @customFontAlreadyImported.
  ///
  /// In en, this message translates to:
  /// **'This font was already imported and is ready to use'**
  String get customFontAlreadyImported;

  /// No description provided for @customFontApplied.
  ///
  /// In en, this message translates to:
  /// **'Font selection updated'**
  String get customFontApplied;

  /// No description provided for @customFontAppliedToApp.
  ///
  /// In en, this message translates to:
  /// **'Imported and set as the app font'**
  String get customFontAppliedToApp;

  /// No description provided for @customFontAppliedToReader.
  ///
  /// In en, this message translates to:
  /// **'Imported and set as the reading font'**
  String get customFontAppliedToReader;

  /// No description provided for @customFontImportUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Persistent font import is not supported on this platform yet.'**
  String get customFontImportUnsupported;

  /// No description provided for @customFontUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose a TTF or OTF font file.'**
  String get customFontUnsupportedFormat;

  /// No description provided for @customFontInvalid.
  ///
  /// In en, this message translates to:
  /// **'This file is not a valid or supported font.'**
  String get customFontInvalid;

  /// No description provided for @customFontTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The font file is larger than 50 MB.'**
  String get customFontTooLarge;

  /// No description provided for @customFontReadFailed.
  ///
  /// In en, this message translates to:
  /// **'The font file could not be read.'**
  String get customFontReadFailed;

  /// No description provided for @customFontLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The font could not be loaded.'**
  String get customFontLoadFailed;

  /// No description provided for @customFontStorageFailed.
  ///
  /// In en, this message translates to:
  /// **'The font could not be saved on this device.'**
  String get customFontStorageFailed;

  /// No description provided for @customFontUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Font file is unavailable. Delete it and import it again.'**
  String get customFontUnavailable;

  /// No description provided for @setAsAppFont.
  ///
  /// In en, this message translates to:
  /// **'Use as app font'**
  String get setAsAppFont;

  /// No description provided for @setAsReaderFont.
  ///
  /// In en, this message translates to:
  /// **'Use as reading font'**
  String get setAsReaderFont;

  /// No description provided for @setAsBothFonts.
  ///
  /// In en, this message translates to:
  /// **'Use for both'**
  String get setAsBothFonts;

  /// No description provided for @renameFont.
  ///
  /// In en, this message translates to:
  /// **'Rename font'**
  String get renameFont;

  /// No description provided for @deleteCustomFontTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete “{name}”?'**
  String deleteCustomFontTitle(String name);

  /// No description provided for @deleteCustomFontMessage.
  ///
  /// In en, this message translates to:
  /// **'The font file will be removed from this device.'**
  String get deleteCustomFontMessage;

  /// No description provided for @deleteCustomFontInUse.
  ///
  /// In en, this message translates to:
  /// **'This font is currently in use. Deleting it will restore the affected font settings to their defaults.'**
  String get deleteCustomFontInUse;

  /// No description provided for @deleteAndReset.
  ///
  /// In en, this message translates to:
  /// **'Delete and reset'**
  String get deleteAndReset;

  /// No description provided for @settingsTelegramChannel.
  ///
  /// In en, this message translates to:
  /// **'Telegram'**
  String get settingsTelegramChannel;

  /// No description provided for @settingsTelegramSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Official Telegram channel'**
  String get settingsTelegramSubtitle;

  /// No description provided for @settingsTelegramOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the Telegram link'**
  String get settingsTelegramOpenFailed;

  /// No description provided for @settingsQqChannel.
  ///
  /// In en, this message translates to:
  /// **'QQ Channel'**
  String get settingsQqChannel;

  /// No description provided for @settingsQqChannelSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Open Reading · OpenReading6'**
  String get settingsQqChannelSubtitle;

  /// No description provided for @settingsQqChannelOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the QQ Channel invitation link'**
  String get settingsQqChannelOpenFailed;

  /// Follow system language
  ///
  /// In en, this message translates to:
  /// **'Follow System'**
  String get languageSystem;

  /// Simplified Chinese language shown in its native name
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChinese;

  /// English language
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// Japanese language shown in its native name
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// Traditional Chinese language shown in its native name
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageTraditionalChinese;

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

  /// Additional spacing between reader paragraphs
  ///
  /// In en, this message translates to:
  /// **'Paragraph Spacing'**
  String get paragraphSpacingLabel;

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

  /// Page turning mode
  ///
  /// In en, this message translates to:
  /// **'Page Mode'**
  String get pageTurningMode;

  /// Slide page turning
  ///
  /// In en, this message translates to:
  /// **'Horizontal Slide'**
  String get pageTurningSlide;

  /// Scroll page turning
  ///
  /// In en, this message translates to:
  /// **'Vertical paging'**
  String get pageTurningScroll;

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

  /// No description provided for @readerNavigationTitle.
  ///
  /// In en, this message translates to:
  /// **'Reading navigation'**
  String get readerNavigationTitle;

  /// No description provided for @readerNavigationPosition.
  ///
  /// In en, this message translates to:
  /// **'Chapter {current} of {total}'**
  String readerNavigationPosition(int current, int total);

  /// No description provided for @readerSearchChapters.
  ///
  /// In en, this message translates to:
  /// **'Search chapters'**
  String get readerSearchChapters;

  /// No description provided for @readerBackToCurrentChapter.
  ///
  /// In en, this message translates to:
  /// **'Back to current chapter'**
  String get readerBackToCurrentChapter;

  /// No description provided for @readerCurrentChapter.
  ///
  /// In en, this message translates to:
  /// **'Current'**
  String get readerCurrentChapter;

  /// No description provided for @readerCurrentPosition.
  ///
  /// In en, this message translates to:
  /// **'Current position'**
  String get readerCurrentPosition;

  /// No description provided for @readerNoChapterResults.
  ///
  /// In en, this message translates to:
  /// **'No matching chapters'**
  String get readerNoChapterResults;

  /// No description provided for @readerNoChapterResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Try another word from the chapter title.'**
  String get readerNoChapterResultsHint;

  /// No description provided for @readerNoBookmarks.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks yet'**
  String get readerNoBookmarks;

  /// No description provided for @readerNoBookmarksHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the bookmark button in the top-right corner to save your place.'**
  String get readerNoBookmarksHint;

  /// No description provided for @readerBookmarkRequiresShelf.
  ///
  /// In en, this message translates to:
  /// **'Add this book to the shelf before saving bookmarks'**
  String get readerBookmarkRequiresShelf;

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

  /// Tagline badge under the app title on the user agreement page
  ///
  /// In en, this message translates to:
  /// **'Immersive Reading · AI Assistant · Local First'**
  String get agreementTagline;

  /// Title of the agreement content card
  ///
  /// In en, this message translates to:
  /// **'User Service Agreement'**
  String get agreementCardTitle;

  /// Subtitle under the agreement card title
  ///
  /// In en, this message translates to:
  /// **'Please read the following carefully'**
  String get agreementCardSubtitle;

  /// Welcome heading inside the agreement content
  ///
  /// In en, this message translates to:
  /// **'Welcome to OpenReading'**
  String get agreementWelcomeTitle;

  /// Welcome paragraph asking the user to read and agree to the agreement
  ///
  /// In en, this message translates to:
  /// **'To ensure a stable and predictable reading experience, please read and agree to the following agreement first.'**
  String get agreementWelcomeBody;

  /// Feature item title: supported book formats
  ///
  /// In en, this message translates to:
  /// **'Multi-Format Support'**
  String get agreementFeatureFormatsTitle;

  /// Feature item description: supported book formats
  ///
  /// In en, this message translates to:
  /// **'EPUB, PDF, TXT, MOBI and more'**
  String get agreementFeatureFormatsBody;

  /// Feature item title: reading customization
  ///
  /// In en, this message translates to:
  /// **'Personalized Reading'**
  String get agreementFeatureCustomizationTitle;

  /// Feature item description: reading customization
  ///
  /// In en, this message translates to:
  /// **'Customize fonts, colors, typography and more'**
  String get agreementFeatureCustomizationBody;

  /// Feature item title: local-first storage
  ///
  /// In en, this message translates to:
  /// **'Local First'**
  String get agreementFeatureSyncTitle;

  /// Feature item description: local-first storage
  ///
  /// In en, this message translates to:
  /// **'Books, progress, and notes stay on the device you control'**
  String get agreementFeatureSyncBody;

  /// Feature item title: TTS read-aloud
  ///
  /// In en, this message translates to:
  /// **'Text-to-Speech'**
  String get agreementFeatureTtsTitle;

  /// Feature item description: TTS read-aloud
  ///
  /// In en, this message translates to:
  /// **'Smart voice narration frees your eyes so you can listen anywhere'**
  String get agreementFeatureTtsBody;

  /// Hint explaining what tapping the agree button means
  ///
  /// In en, this message translates to:
  /// **'By tapping \"Agree and Continue\", you confirm that you have read and agree to use this app'**
  String get agreementTapToAgreeHint;

  /// Decline button label and exit confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Exit App'**
  String get agreementExitApp;

  /// Primary button to accept the agreement and continue
  ///
  /// In en, this message translates to:
  /// **'Agree and Continue'**
  String get agreementAgreeAndContinue;

  /// Body of the exit confirmation dialog shown when declining the agreement
  ///
  /// In en, this message translates to:
  /// **'If you do not agree to the user agreement, you will not be able to use this app. Are you sure you want to exit?'**
  String get agreementExitDialogContent;

  /// Confirm button in the exit dialog
  ///
  /// In en, this message translates to:
  /// **'Exit'**
  String get agreementConfirmExit;

  /// Toast shown when opening a book whose file is missing
  ///
  /// In en, this message translates to:
  /// **'Book file not found. Please re-import it.'**
  String get readerFileMissing;

  /// Toast shown when opening an unsupported book format
  ///
  /// In en, this message translates to:
  /// **'The native reader currently only supports EPUB and TXT.'**
  String get readerUnsupportedFormat;

  /// Startup error when the data/cache services fail to initialize
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize the data system'**
  String get bootstrapDataServiceFailed;

  /// Startup error when the book image manager fails to initialize
  ///
  /// In en, this message translates to:
  /// **'Failed to initialize the image manager'**
  String get bootstrapImageManagerFailed;

  /// Toast shown when a focus timer finishes
  ///
  /// In en, this message translates to:
  /// **'{minutes}-minute focus session complete. Well done!'**
  String homeFocusCompleted(int minutes);

  /// Title of the daily reading goal picker bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Daily Reading Goal'**
  String get homeDailyReadingGoal;

  /// Section label for the AI reading advice card
  ///
  /// In en, this message translates to:
  /// **'AI Reading Advice'**
  String get homeAiAdviceSection;

  /// Section label for the today summary row
  ///
  /// In en, this message translates to:
  /// **'Today at a Glance'**
  String get homeTodayGlance;

  /// Header of the daily reading plan section
  ///
  /// In en, this message translates to:
  /// **'Today\'s Reading Plan'**
  String get homeTodayReadingPlan;

  /// Action to open the full detailed stats page
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get homeViewAll;

  /// Hero card title while the reading plan is loading
  ///
  /// In en, this message translates to:
  /// **'Syncing your reading plan'**
  String get homeSyncingReadingPlan;

  /// Hero card title when today's reading goal is done
  ///
  /// In en, this message translates to:
  /// **'Today\'s goal is complete — consider a reading review'**
  String get homeGoalDoneSuggestReview;

  /// Hero card title showing minutes left to today's goal
  ///
  /// In en, this message translates to:
  /// **'Just {minutes} more minutes to reach today\'s goal'**
  String homeRemainingToGoal(int minutes);

  /// Recommendation shown when no book is suggested
  ///
  /// In en, this message translates to:
  /// **'Pick a book from your shelf to continue and complete 1 focus session first.'**
  String get homePickBookHint;

  /// Recommendation to continue a specific book
  ///
  /// In en, this message translates to:
  /// **'Continue \"{title}\" first, then switch to other books.'**
  String homeContinueBookHint(String title);

  /// Title of the hero card with today's suggested actions
  ///
  /// In en, this message translates to:
  /// **'Today\'s Action Plan'**
  String get homeTodayActionAdvice;

  /// Plan completion percentage badge on the hero card
  ///
  /// In en, this message translates to:
  /// **'{percent}% progress'**
  String homeProgressPercent(int percent);

  /// Hero chip showing consecutive reading days
  ///
  /// In en, this message translates to:
  /// **'{days}-day streak'**
  String homeStreakDays(int days);

  /// Hero chip showing minutes read this week
  ///
  /// In en, this message translates to:
  /// **'{minutes} min this week'**
  String homeWeekMinutes(int minutes);

  /// Hero chip placeholder while the plan is loading
  ///
  /// In en, this message translates to:
  /// **'Plan loading'**
  String get homePlanLoading;

  /// Hero chip showing the daily goal in minutes
  ///
  /// In en, this message translates to:
  /// **'Goal: {minutes} min/day'**
  String homeGoalMinutesPerDay(int minutes);

  /// Title of the AI advice card on the mobile dashboard
  ///
  /// In en, this message translates to:
  /// **'AI Reading Advice for You'**
  String get homeAiAdviceForYou;

  /// Subtitle indicating which book the AI advice is based on
  ///
  /// In en, this message translates to:
  /// **'Based on \"{title}\"'**
  String homeBasedOnBook(String title);

  /// Caption under today's reading minutes summary number
  ///
  /// In en, this message translates to:
  /// **'Today\'s Reading (min)'**
  String get homeTodayReadingMinutesLabel;

  /// Caption under total reading minutes summary number
  ///
  /// In en, this message translates to:
  /// **'Total Reading (min)'**
  String get homeTotalReadingMinutesLabel;

  /// Loading text while the daily plan is being generated
  ///
  /// In en, this message translates to:
  /// **'Generating today\'s reading plan...'**
  String get homeGeneratingPlan;

  /// Small label under the plan completion percentage ring
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get homeCompletedLabel;

  /// Plan card title when today's goal is reached
  ///
  /// In en, this message translates to:
  /// **'Today\'s goal achieved'**
  String get homeTodayGoalAchieved;

  /// Plan card title showing minutes left to today's goal
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes to go'**
  String homeMinutesRemaining(int minutes);

  /// Minutes read out of the daily goal
  ///
  /// In en, this message translates to:
  /// **'Read {read} / {goal} min'**
  String homeReadOfGoalMinutes(int read, int goal);

  /// Estimated focus sessions needed to complete the daily goal
  ///
  /// In en, this message translates to:
  /// **'About {sessions} focus sessions to finish today\'s goal'**
  String homeSessionsToFinishGoal(int sessions);

  /// Plan metric badge label for the reading streak
  ///
  /// In en, this message translates to:
  /// **'Streak'**
  String get homeStreakLabel;

  /// Plan metric badge label for days the goal was met this week
  ///
  /// In en, this message translates to:
  /// **'Weekly goal'**
  String get homeWeekAchievedLabel;

  /// Plan metric badge label for focus sessions today
  ///
  /// In en, this message translates to:
  /// **'Focus'**
  String get homeFocusLabel;

  /// Day count value in plan metric badges
  ///
  /// In en, this message translates to:
  /// **'{days} days'**
  String homeDaysCount(int days);

  /// Times count value in plan metric badges
  ///
  /// In en, this message translates to:
  /// **'{times} times'**
  String homeTimesCount(int times);

  /// Label above the focus timer progress bar; time is mm:ss
  ///
  /// In en, this message translates to:
  /// **'Focus countdown {time}'**
  String homeFocusCountdown(String time);

  /// Button when no recommended book is available
  ///
  /// In en, this message translates to:
  /// **'Read from Library'**
  String get homeGoLibraryRead;

  /// Button to cancel the running focus timer
  ///
  /// In en, this message translates to:
  /// **'End Focus'**
  String get homeEndFocus;

  /// Button to start a focus session of the given minutes
  ///
  /// In en, this message translates to:
  /// **'Focus {minutes} min'**
  String homeFocusMinutesButton(int minutes);

  /// Button to open the daily goal picker showing the current goal
  ///
  /// In en, this message translates to:
  /// **'Adjust goal: {minutes} min'**
  String homeAdjustGoalMinutes(int minutes);

  /// Empty state for the recent reading list
  ///
  /// In en, this message translates to:
  /// **'No recent reading yet. Open a book from your library to get started.'**
  String get homeNoRecentReading;

  /// Reading progress percentage of a book in the recent list
  ///
  /// In en, this message translates to:
  /// **'Progress {percent}%'**
  String homeReadingProgressPercent(String percent);

  /// Hint text for the library search field
  ///
  /// In en, this message translates to:
  /// **'Search titles or authors'**
  String get librarySearchHint;

  /// Filter chip showing total book count
  ///
  /// In en, this message translates to:
  /// **'All {count}'**
  String libraryFilterAll(int count);

  /// Filter chip showing count of books in progress
  ///
  /// In en, this message translates to:
  /// **'Reading {count}'**
  String libraryFilterReading(int count);

  /// Filter chip showing count of finished books
  ///
  /// In en, this message translates to:
  /// **'Finished {count}'**
  String libraryFilterFinished(int count);

  /// No description provided for @libraryFilterTooltip.
  ///
  /// In en, this message translates to:
  /// **'Filter by reading status'**
  String get libraryFilterTooltip;

  /// Shown when a library search returns no books
  ///
  /// In en, this message translates to:
  /// **'No matching books'**
  String get libraryNoMatchingBooks;

  /// Shown when the reading filter has no books
  ///
  /// In en, this message translates to:
  /// **'No books in progress'**
  String get libraryNoReadingBooks;

  /// Shown when the finished filter has no books
  ///
  /// In en, this message translates to:
  /// **'No finished books'**
  String get libraryNoFinishedBooks;

  /// Shown when the library has no books for the current filter
  ///
  /// In en, this message translates to:
  /// **'No books yet'**
  String get libraryNoBooks;

  /// List item subtitle showing reading progress percentage
  ///
  /// In en, this message translates to:
  /// **'{percent}% · Continue reading'**
  String libraryProgressContinue(int percent);

  /// Current page indicator in book options sheet
  ///
  /// In en, this message translates to:
  /// **'Page {page}'**
  String libraryPageNumber(int page);

  /// Subtitle when a book has not been started yet
  ///
  /// In en, this message translates to:
  /// **'Start from the beginning'**
  String get libraryStartFromBeginning;

  /// Book information option and dialog title
  ///
  /// In en, this message translates to:
  /// **'Book Info'**
  String get libraryBookInfo;

  /// Book format and total page count subtitle
  ///
  /// In en, this message translates to:
  /// **'{format} · {pages} pages'**
  String libraryFormatAndPages(String format, int pages);

  /// Subtitle of the delete book option
  ///
  /// In en, this message translates to:
  /// **'This book will be permanently deleted'**
  String get libraryDeleteBookHint;

  /// Book title label in the book info dialog
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get libraryBookTitle;

  /// Book format label in the book info dialog
  ///
  /// In en, this message translates to:
  /// **'Format'**
  String get libraryFormat;

  /// Page count value in the book info dialog
  ///
  /// In en, this message translates to:
  /// **'{pages} pages'**
  String libraryPagesCount(int pages);

  /// Close button in the book info dialog
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get libraryClose;

  /// Title of the delete book confirmation dialog
  ///
  /// In en, this message translates to:
  /// **'Confirm Deletion'**
  String get libraryConfirmDeleteTitle;

  /// Delete book confirmation message with book title
  ///
  /// In en, this message translates to:
  /// **'Delete \"{title}\"? The file will be permanently removed from your device.'**
  String libraryDeleteBookMessage(String title);

  /// Progress dialog message while deleting a book
  ///
  /// In en, this message translates to:
  /// **'Deleting \"{title}\"...'**
  String libraryDeletingBook(String title);

  /// Toast shown after a book is deleted
  ///
  /// In en, this message translates to:
  /// **'\"{title}\" deleted'**
  String libraryBookDeletedToast(String title);

  /// Toast shown when deleting a book fails
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String libraryDeleteFailed(String error);

  /// Badge on a book cover indicating the book is in progress
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get libraryReadingBadge;

  /// Deletion progress step: removing the book file
  ///
  /// In en, this message translates to:
  /// **'Deleting book file...'**
  String get libraryDeletingBookFile;

  /// Deletion progress step: removing the cover image
  ///
  /// In en, this message translates to:
  /// **'Deleting cover image...'**
  String get libraryDeletingCoverImage;

  /// Deletion progress step: removing database records
  ///
  /// In en, this message translates to:
  /// **'Cleaning up database records...'**
  String get libraryCleaningDatabase;

  /// Deletion progress step: finished
  ///
  /// In en, this message translates to:
  /// **'Deletion complete'**
  String get libraryDeleteComplete;

  /// Chapter title for TXT content that appears before the first detected chapter heading
  ///
  /// In en, this message translates to:
  /// **'Front Matter'**
  String get readerPrefaceTitle;

  /// Page mode option: content split into pages turned instantly by tapping
  ///
  /// In en, this message translates to:
  /// **'No Animation'**
  String get readerModeHorizontalPage;

  /// Subtitle explaining the vertical scroll page mode
  ///
  /// In en, this message translates to:
  /// **'Slide through pre-paginated pages vertically; swipe sideways to change chapters'**
  String get readerModeVerticalScrollHint;

  /// Subtitle explaining whole-book continuous vertical scrolling
  ///
  /// In en, this message translates to:
  /// **'Pre-paginated chapters form one positionable vertical list'**
  String get readerModeWholeBookScrollHint;

  /// Switch controlling whether vertical scrolling is limited to one chapter
  ///
  /// In en, this message translates to:
  /// **'Scroll by chapter'**
  String get readerScrollByChapterTitle;

  /// Subtitle when chapter-scoped vertical scrolling is enabled
  ///
  /// In en, this message translates to:
  /// **'Slide through one chapter page by page, then swipe sideways to change chapters'**
  String get readerScrollByChapterOnHint;

  /// Subtitle when whole-book vertical scrolling is enabled
  ///
  /// In en, this message translates to:
  /// **'All chapters connect page by page in one positionable vertical list'**
  String get readerScrollByChapterOffHint;

  /// Subtitle explaining the horizontal paging mode
  ///
  /// In en, this message translates to:
  /// **'Tap the left side for the previous page, the right side for the next page'**
  String get readerModeHorizontalPageHint;

  /// Subtitle explaining the horizontal slide page mode
  ///
  /// In en, this message translates to:
  /// **'Pages follow your finger horizontally and snap into place'**
  String get readerModeHorizontalSlideHint;

  /// Page mode option with an interactive simulated paper curl
  ///
  /// In en, this message translates to:
  /// **'Page Curl'**
  String get readerModePageCurl;

  /// Subtitle explaining the simulated page curl mode
  ///
  /// In en, this message translates to:
  /// **'Drag sideways to curl the page, then release to turn or rebound'**
  String get readerModePageCurlHint;

  /// Slider label showing the current reader font size
  ///
  /// In en, this message translates to:
  /// **'Font size  {size}'**
  String readerFontSizeValue(int size);

  /// Slider label showing the current left/right page margin
  ///
  /// In en, this message translates to:
  /// **'Horizontal margin  {margin}'**
  String readerHorizontalMarginValue(int margin);

  /// No description provided for @readerHorizontalMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Horizontal margin'**
  String get readerHorizontalMarginLabel;

  /// No description provided for @readerTopMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Top margin'**
  String get readerTopMarginLabel;

  /// No description provided for @readerBottomMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Bottom margin'**
  String get readerBottomMarginLabel;

  /// No description provided for @readerVerticalMarginLabel.
  ///
  /// In en, this message translates to:
  /// **'Vertical margin'**
  String get readerVerticalMarginLabel;

  /// Slider label showing the current top/bottom page margin
  ///
  /// In en, this message translates to:
  /// **'Vertical margin  {margin}'**
  String readerVerticalMarginValue(int margin);

  /// Total chapter count shown in the table of contents header
  ///
  /// In en, this message translates to:
  /// **'{count} chapters'**
  String readerChapterCount(int count);

  /// Fallback title for a chapter without a title, 1-based index
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String readerChapterFallback(int number);

  /// Error message when a book fails to load in the native reader
  ///
  /// In en, this message translates to:
  /// **'Failed to open: {error}'**
  String readerOpenFailed(String error);

  /// Shown when a book parses successfully but contains no displayable text
  ///
  /// In en, this message translates to:
  /// **'This book has no readable content'**
  String get readerNoContent;

  /// Bottom status bar in paged modes: current chapter and page position
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter}/{chapterCount} · Page {page}/{pageCount}'**
  String readerStatusPaged(
      int chapter, int chapterCount, int page, int pageCount);

  /// Bottom status bar in vertical scroll mode: current chapter position
  ///
  /// In en, this message translates to:
  /// **'Chapter {chapter}/{chapterCount} · Vertical scroll'**
  String readerStatusScroll(int chapter, int chapterCount);

  /// Progress message shown when a local file import starts
  ///
  /// In en, this message translates to:
  /// **'Preparing import...'**
  String get importPreparing;

  /// Toast shown when importing a book throws an exception
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailedWithError(String error);

  /// Button label to import a book from local device storage
  ///
  /// In en, this message translates to:
  /// **'Local Files'**
  String get importLocalFile;

  /// Temperature range hint for the MiniMax AI provider
  ///
  /// In en, this message translates to:
  /// **'Temperature: MiniMax recommends 0.01 ~ 1.00'**
  String get settingsAiTempHintMinimax;

  /// Title of the custom AI config dialog
  ///
  /// In en, this message translates to:
  /// **'Custom AI Configuration'**
  String get settingsAiCustomConfigTitle;

  /// Shows the currently selected AI provider in the custom config dialog
  ///
  /// In en, this message translates to:
  /// **'Current provider: {provider}'**
  String settingsAiCurrentProvider(String provider);

  /// Validation error for MiniMax temperature range
  ///
  /// In en, this message translates to:
  /// **'MiniMax Temperature must be between 0.01 and 1.00'**
  String get settingsAiTempErrorMinimax;

  /// Validation error for temperature out of allowed range
  ///
  /// In en, this message translates to:
  /// **'Temperature is out of range, please follow the hint'**
  String get settingsAiTempErrorOutOfRange;

  /// Apply button in the custom AI config dialog
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get settingsApply;

  /// Toast after applying custom AI parameters
  ///
  /// In en, this message translates to:
  /// **'Custom parameters applied, remember to save the configuration'**
  String get settingsAiCustomApplied;

  /// Validation error when API key is empty
  ///
  /// In en, this message translates to:
  /// **'API Key cannot be empty'**
  String get settingsAiApiKeyRequired;

  /// Validation error when model is empty
  ///
  /// In en, this message translates to:
  /// **'Model cannot be empty'**
  String get settingsAiModelRequired;

  /// Validation error for invalid base URL
  ///
  /// In en, this message translates to:
  /// **'Base URL must be a valid http/https address'**
  String get settingsAiBaseUrlInvalid;

  /// Toast after saving AI settings
  ///
  /// In en, this message translates to:
  /// **'AI settings saved'**
  String get settingsAiSettingsSaved;

  /// Error message when saving settings fails
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String settingsSaveFailed(String error);

  /// Switch title for volume-key page turning
  ///
  /// In en, this message translates to:
  /// **'Volume key page turning'**
  String get settingsVolumeKeyTurnTitle;

  /// Switch subtitle for volume-key page turning
  ///
  /// In en, this message translates to:
  /// **'Use volume keys in paged reading modes'**
  String get settingsVolumeKeyTurnSubtitle;

  /// Switch title for showing system status bar in reader
  ///
  /// In en, this message translates to:
  /// **'Show system status bar while reading'**
  String get settingsShowStatusBarTitle;

  /// Subtitle when system status bar is shown in reader
  ///
  /// In en, this message translates to:
  /// **'Reader battery/time UI hidden'**
  String get settingsShowStatusBarOnSubtitle;

  /// Subtitle when system status bar is hidden in reader
  ///
  /// In en, this message translates to:
  /// **'Using reader battery/time UI'**
  String get settingsShowStatusBarOffSubtitle;

  /// Title for selecting the reader top information style
  ///
  /// In en, this message translates to:
  /// **'Top information'**
  String get readerTopBarStyleTitle;

  /// No description provided for @readerTopBarStyleSystem.
  ///
  /// In en, this message translates to:
  /// **'System status bar'**
  String get readerTopBarStyleSystem;

  /// No description provided for @readerTopBarStyleSystemHint.
  ///
  /// In en, this message translates to:
  /// **'Show the system time, signal, and battery'**
  String get readerTopBarStyleSystemHint;

  /// No description provided for @readerTopBarStyleReader.
  ///
  /// In en, this message translates to:
  /// **'Reader information bar'**
  String get readerTopBarStyleReader;

  /// No description provided for @readerTopBarStyleReaderHint.
  ///
  /// In en, this message translates to:
  /// **'Show time, chapter title, and battery'**
  String get readerTopBarStyleReaderHint;

  /// No description provided for @readerTopBarStyleHidden.
  ///
  /// In en, this message translates to:
  /// **'Fully immersive'**
  String get readerTopBarStyleHidden;

  /// No description provided for @readerTopBarStyleHiddenHint.
  ///
  /// In en, this message translates to:
  /// **'Show no information at the top'**
  String get readerTopBarStyleHiddenHint;

  /// Section title for AI assistant settings
  ///
  /// In en, this message translates to:
  /// **'AI Reading Assistant'**
  String get settingsAiAssistantTitle;

  /// Section title for system settings
  ///
  /// In en, this message translates to:
  /// **'System Settings'**
  String get settingsSystemSettingsTitle;

  /// Switch title for keeping screen on
  ///
  /// In en, this message translates to:
  /// **'Keep screen on'**
  String get settingsKeepScreenOnTitle;

  /// Switch subtitle for keeping screen on
  ///
  /// In en, this message translates to:
  /// **'Prevent the screen from turning off while reading'**
  String get settingsKeepScreenOnSubtitle;

  /// Switch title for auto save
  ///
  /// In en, this message translates to:
  /// **'Auto save'**
  String get settingsAutoSaveTitle;

  /// Switch subtitle for auto save
  ///
  /// In en, this message translates to:
  /// **'Automatically save reading progress'**
  String get settingsAutoSaveSubtitle;

  /// Placeholder toast for the help button
  ///
  /// In en, this message translates to:
  /// **'Help information can go here'**
  String get settingsHelpPlaceholder;

  /// Status text when AI is configured
  ///
  /// In en, this message translates to:
  /// **'AI configured'**
  String get settingsAiConfigured;

  /// Status text when AI API key is missing
  ///
  /// In en, this message translates to:
  /// **'API Key not configured yet'**
  String get settingsAiNotConfigured;

  /// Badge when AI settings are complete
  ///
  /// In en, this message translates to:
  /// **'Ready to use'**
  String get settingsAiReadyToUse;

  /// Badge when AI settings are incomplete
  ///
  /// In en, this message translates to:
  /// **'Pending setup'**
  String get settingsAiPendingConfig;

  /// Shows the matched AI model preset
  ///
  /// In en, this message translates to:
  /// **'Current preset: {preset}'**
  String settingsAiCurrentPreset(String preset);

  /// Shows the custom AI model in use
  ///
  /// In en, this message translates to:
  /// **'Current configuration: custom · {model}'**
  String settingsAiCurrentCustom(String model);

  /// Intro text explaining AI presets
  ///
  /// In en, this message translates to:
  /// **'Common providers and models are built in; usually you only need to pick a preset and enter an API Key.'**
  String get settingsAiPresetIntro;

  /// Label of the AI provider dropdown
  ///
  /// In en, this message translates to:
  /// **'Provider'**
  String get settingsAiProviderLabel;

  /// Hint of the AI preset dropdown
  ///
  /// In en, this message translates to:
  /// **'Select a preset model'**
  String get settingsAiPresetHint;

  /// Label of the AI preset dropdown
  ///
  /// In en, this message translates to:
  /// **'Preset model'**
  String get settingsAiPresetLabel;

  /// Button opening the custom AI config dialog
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get settingsAiCustomButton;

  /// Hint shown when a preset is selected
  ///
  /// In en, this message translates to:
  /// **'After selecting a preset, just enter an API Key to start using it.'**
  String get settingsAiPresetSelectedHint;

  /// Hint shown when custom AI parameters are active
  ///
  /// In en, this message translates to:
  /// **'Custom parameters are in use; you can switch back to a preset at any time.'**
  String get settingsAiCustomActiveHint;

  /// Hint text of the API key input
  ///
  /// In en, this message translates to:
  /// **'Enter to enable the current preset'**
  String get settingsAiApiKeyHint;

  /// Tooltip to reveal the API key
  ///
  /// In en, this message translates to:
  /// **'Show'**
  String get settingsShow;

  /// Tooltip to hide the API key
  ///
  /// In en, this message translates to:
  /// **'Hide'**
  String get settingsHide;

  /// Button label while AI settings are being saved
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get settingsAiSaving;

  /// Button label to save AI settings
  ///
  /// In en, this message translates to:
  /// **'Save AI configuration'**
  String get settingsAiSaveConfig;

  /// Subtitle under the settings page title
  ///
  /// In en, this message translates to:
  /// **'Only the options that shape your reading experience.'**
  String get settingsPageIntro;

  /// Section title for the developer's other products
  ///
  /// In en, this message translates to:
  /// **'More from the developer'**
  String get settingsDeveloperProductsTitle;

  /// Brand name of the developer's iOS reading product
  ///
  /// In en, this message translates to:
  /// **'小元读书'**
  String get settingsXiaoyuanReadingTitle;

  /// Description of the developer's iOS reading product
  ///
  /// In en, this message translates to:
  /// **'A reader-focused product for end users, currently available on iOS only'**
  String get settingsXiaoyuanReadingSubtitle;

  /// Brand name of the developer's reading community
  ///
  /// In en, this message translates to:
  /// **'小元读书社区'**
  String get settingsXiaoyuanCommunityTitle;

  /// Description of the developer's reading community
  ///
  /// In en, this message translates to:
  /// **'A community for reading, writing, and conversation'**
  String get settingsXiaoyuanCommunitySubtitle;

  /// Toast shown when a promoted product website cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open the product website'**
  String get settingsDeveloperProductOpenFailed;

  /// Settings section title for voluntary donations
  ///
  /// In en, this message translates to:
  /// **'Support development'**
  String get settingsSupportDevelopmentTitle;

  /// Primary action on the first-home developer support introduction
  ///
  /// In en, this message translates to:
  /// **'Support now'**
  String get firstHomeSupportNow;

  /// Dismiss action on the first-home developer support introduction
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get firstHomeSupportLater;

  /// Accessibility label for the paper shown in the first-home support introduction
  ///
  /// In en, this message translates to:
  /// **'A letter from the Open Reading developer asking for voluntary support'**
  String get firstHomeSupportPaperSemanticLabel;

  /// Title of the voluntary developer support card
  ///
  /// In en, this message translates to:
  /// **'Support continued development'**
  String get settingsSupportDevelopmentCardTitle;

  /// Explanation shown on the voluntary developer support card
  ///
  /// In en, this message translates to:
  /// **'Building and maintaining Open Reading takes substantial time and effort. If it helps you, voluntary donations are welcome.'**
  String get settingsSupportDevelopmentCardSubtitle;

  /// Action label that opens the WeChat donation QR code
  ///
  /// In en, this message translates to:
  /// **'Donate with WeChat'**
  String get settingsDonationAction;

  /// Action label that opens the Alipay donation QR code
  ///
  /// In en, this message translates to:
  /// **'Donate with Alipay'**
  String get settingsAlipayDonationAction;

  /// Title of the WeChat donation QR code dialog
  ///
  /// In en, this message translates to:
  /// **'WeChat donation'**
  String get settingsDonationDialogTitle;

  /// Instructions shown above the WeChat donation QR code
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code with WeChat to support continued development. Thank you.'**
  String get settingsDonationDialogHint;

  /// Title of the Alipay donation QR code dialog
  ///
  /// In en, this message translates to:
  /// **'Alipay donation'**
  String get settingsAlipayDonationDialogTitle;

  /// Instructions shown above the Alipay donation QR code
  ///
  /// In en, this message translates to:
  /// **'Scan the QR code with Alipay to support continued development. Thank you.'**
  String get settingsAlipayDonationDialogHint;

  /// Notice clarifying that donations are voluntary and do not unlock features
  ///
  /// In en, this message translates to:
  /// **'Donations are entirely optional. They do not unlock features or constitute a purchase or service agreement.'**
  String get settingsDonationVoluntaryNotice;

  /// Accessibility label for the WeChat donation QR code image
  ///
  /// In en, this message translates to:
  /// **'WeChat donation QR code'**
  String get settingsDonationQrCodeLabel;

  /// Accessibility label for the Alipay donation QR code image
  ///
  /// In en, this message translates to:
  /// **'Alipay donation QR code'**
  String get settingsAlipayDonationQrCodeLabel;

  /// Hint above the horizontal AI model card list
  ///
  /// In en, this message translates to:
  /// **'Swipe through models and tap a card to switch.'**
  String get settingsAiSwipeHint;

  /// Intro text on the legacy AI settings page
  ///
  /// In en, this message translates to:
  /// **'Choose a provider and model, then enter your API key.'**
  String get settingsAiLegacyIntro;

  /// Label of the AI model dropdown
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get settingsAiModelLabel;

  /// Helper text when no preset matches the current AI settings
  ///
  /// In en, this message translates to:
  /// **'Using custom model settings'**
  String get settingsAiUsingCustomParams;

  /// Hint of the API key field about local-only storage
  ///
  /// In en, this message translates to:
  /// **'Stored on this device only'**
  String get settingsAiApiKeyStoredLocally;

  /// Button label to save and enable AI settings
  ///
  /// In en, this message translates to:
  /// **'Save and enable'**
  String get settingsAiSaveAndEnable;

  /// Tagline under the app name in the about card
  ///
  /// In en, this message translates to:
  /// **'Open source, cross-platform, focused on reading'**
  String get settingsAboutTagline;

  /// Version label in the about card
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersionLabel;

  /// No description provided for @changelogHistoryTitle.
  ///
  /// In en, this message translates to:
  /// **'Version history'**
  String get changelogHistoryTitle;

  /// No description provided for @changelogHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'View changes from every release'**
  String get changelogHistorySubtitle;

  /// No description provided for @openSourceLicensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get openSourceLicensesTitle;

  /// No description provided for @openSourceLicensesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View licenses for the app, bundled fonts, and third-party software'**
  String get openSourceLicensesSubtitle;

  /// No description provided for @openSourceLicensesIntro.
  ///
  /// In en, this message translates to:
  /// **'These license texts are available offline in the app. Open Reading, bundled fonts, and third-party software remain subject to their respective licenses.'**
  String get openSourceLicensesIntro;

  /// No description provided for @openSourceProjectSection.
  ///
  /// In en, this message translates to:
  /// **'Project licenses'**
  String get openSourceProjectSection;

  /// No description provided for @openSourceLegacyLicenseTitle.
  ///
  /// In en, this message translates to:
  /// **'Earlier releases'**
  String get openSourceLegacyLicenseTitle;

  /// No description provided for @openSourceFontsSection.
  ///
  /// In en, this message translates to:
  /// **'Bundled fonts'**
  String get openSourceFontsSection;

  /// No description provided for @openSourceDependenciesSection.
  ///
  /// In en, this message translates to:
  /// **'Third-party software'**
  String get openSourceDependenciesSection;

  /// No description provided for @openSourceDependenciesTitle.
  ///
  /// In en, this message translates to:
  /// **'Flutter and Dart dependencies'**
  String get openSourceDependenciesTitle;

  /// No description provided for @openSourceDependenciesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'View third-party licenses collected automatically by Flutter'**
  String get openSourceDependenciesSubtitle;

  /// No description provided for @openSourceLicenseLegalese.
  ///
  /// In en, this message translates to:
  /// **'Open Reading and third-party components remain subject to their respective licenses.'**
  String get openSourceLicenseLegalese;

  /// No description provided for @openSourceLicenseLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not load the license text.'**
  String get openSourceLicenseLoadFailed;

  /// No description provided for @changelogPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Release history'**
  String get changelogPageTitle;

  /// No description provided for @changelogCurrentVersion.
  ///
  /// In en, this message translates to:
  /// **'Current version'**
  String get changelogCurrentVersion;

  /// No description provided for @changelog225UnifiedTextReader.
  ///
  /// In en, this message translates to:
  /// **'Unified local files and online sources on the same text pagination and rendering engine'**
  String get changelog225UnifiedTextReader;

  /// No description provided for @changelog225SourceChapterTurn.
  ///
  /// In en, this message translates to:
  /// **'Fixed horizontal cross-chapter turns rebuilding the page before the animation finished'**
  String get changelog225SourceChapterTurn;

  /// No description provided for @changelog225AppIcons.
  ///
  /// In en, this message translates to:
  /// **'Updated app icons consistently across mobile, desktop, web, and OpenHarmony'**
  String get changelog225AppIcons;

  /// No description provided for @changelog224SourceCatalogPaging.
  ///
  /// In en, this message translates to:
  /// **'Updated source support to ORSP 1.3 and fetch complete chapter catalogs using each source\'s declared page-size limit'**
  String get changelog224SourceCatalogPaging;

  /// No description provided for @changelog224SourceHtmlParagraphs.
  ///
  /// In en, this message translates to:
  /// **'Fixed paragraph boundaries being lost when source HTML separates paragraphs with <br> elements'**
  String get changelog224SourceHtmlParagraphs;

  /// No description provided for @changelog224MobileNavigation.
  ///
  /// In en, this message translates to:
  /// **'Reduced the mobile home floating navigation height to leave more room for content'**
  String get changelog224MobileNavigation;

  /// No description provided for @changelog221TabletBackPage.
  ///
  /// In en, this message translates to:
  /// **'Fixed tablet spread page-curl backs so turning the right page shows the next left page in normal reading orientation'**
  String get changelog221TabletBackPage;

  /// No description provided for @changelog220TabletSpread.
  ///
  /// In en, this message translates to:
  /// **'Added an optional landscape tablet spread with top information split across the left and right pages'**
  String get changelog220TabletSpread;

  /// No description provided for @changelog220PageCurl.
  ///
  /// In en, this message translates to:
  /// **'Rebuilt page-curl tracking, cross-spine layering, and settling to fix jumps, tails, and incorrect overlap'**
  String get changelog220PageCurl;

  /// No description provided for @changelog220ReaderPerformance.
  ///
  /// In en, this message translates to:
  /// **'Improved TXT opening transitions, source chapter prefetching, and pagination reuse to reduce waiting'**
  String get changelog220ReaderPerformance;

  /// No description provided for @changelog220NavigationThemes.
  ///
  /// In en, this message translates to:
  /// **'Added icon-only or labeled floating navigation and unified sorting for built-in and custom reader themes'**
  String get changelog220NavigationThemes;

  /// No description provided for @changelog220ReadingStats.
  ///
  /// In en, this message translates to:
  /// **'Redesigned detailed reading statistics with a consistent paper-inspired layout'**
  String get changelog220ReadingStats;

  /// No description provided for @changelog220PageOrganization.
  ///
  /// In en, this message translates to:
  /// **'Reorganized page source by feature area with consistent naming and module boundaries'**
  String get changelog220PageOrganization;

  /// No description provided for @changelog220OfficialUpdates.
  ///
  /// In en, this message translates to:
  /// **'Added GitHub and official-site update choices; Android can download, verify, and hand official APKs to the system installer'**
  String get changelog220OfficialUpdates;

  /// No description provided for @changelog220ReleaseDistribution.
  ///
  /// In en, this message translates to:
  /// **'Added official-site mirrors and download statistics with stricter asset, checksum, APK version, and signing verification'**
  String get changelog220ReleaseDistribution;

  /// No description provided for @changelog220SourcePolicy.
  ///
  /// In en, this message translates to:
  /// **'Clarified third-party source responsibilities and added developer product and optional support entries'**
  String get changelog220SourcePolicy;

  /// No description provided for @changelog203DeveloperProducts.
  ///
  /// In en, this message translates to:
  /// **'Added settings links for 小元读书 and 小元读书社区'**
  String get changelog203DeveloperProducts;

  /// No description provided for @changelog203Donation.
  ///
  /// In en, this message translates to:
  /// **'Added optional WeChat and Alipay donation entries with no effect on app features'**
  String get changelog203Donation;

  /// No description provided for @changelog202PaperInformation.
  ///
  /// In en, this message translates to:
  /// **'Embedded reader information in each paper page so it moves with slide and page-curl turns'**
  String get changelog202PaperInformation;

  /// No description provided for @changelog202PageNumberInset.
  ///
  /// In en, this message translates to:
  /// **'Inset page numbers from screen edges to avoid rounded-corner clipping'**
  String get changelog202PageNumberInset;

  /// No description provided for @changelog201BackwardPageTurn.
  ///
  /// In en, this message translates to:
  /// **'Improved backward simulated turns with immediate mid-screen tracking and a stable binding edge during vertical hand movement'**
  String get changelog201BackwardPageTurn;

  /// No description provided for @changelog201SnapshotPreheat.
  ///
  /// In en, this message translates to:
  /// **'Preheated both adjacent pages together to reduce first backward-turn latency'**
  String get changelog201SnapshotPreheat;

  /// No description provided for @changelog201SourceFilters.
  ///
  /// In en, this message translates to:
  /// **'Added all-source and per-source discovery filters with balanced latest-book interleaving'**
  String get changelog201SourceFilters;

  /// No description provided for @changelog120CustomFonts.
  ///
  /// In en, this message translates to:
  /// **'Improved custom fonts with import and management'**
  String get changelog120CustomFonts;

  /// No description provided for @changelog120SystemBars.
  ///
  /// In en, this message translates to:
  /// **'Polished the status bar and reading controls'**
  String get changelog120SystemBars;

  /// No description provided for @changelog120BookAnimations.
  ///
  /// In en, this message translates to:
  /// **'Redesigned book open and close animations'**
  String get changelog120BookAnimations;

  /// No description provided for @changelog120TabletLibrary.
  ///
  /// In en, this message translates to:
  /// **'Improved the tablet library layout'**
  String get changelog120TabletLibrary;

  /// No description provided for @changelog120Typography.
  ///
  /// In en, this message translates to:
  /// **'Improved reader layout with zero margins and more text per page'**
  String get changelog120Typography;

  /// No description provided for @changelog120VolumeKeys.
  ///
  /// In en, this message translates to:
  /// **'Added volume-key page turning on Android'**
  String get changelog120VolumeKeys;

  /// No description provided for @changelog120Import.
  ///
  /// In en, this message translates to:
  /// **'Redesigned book import with safer bottom controls'**
  String get changelog120Import;

  /// No description provided for @changelog120Covers.
  ///
  /// In en, this message translates to:
  /// **'Generated simple covers for books without artwork'**
  String get changelog120Covers;

  /// No description provided for @changelog120Licenses.
  ///
  /// In en, this message translates to:
  /// **'Added offline open-source license viewing'**
  String get changelog120Licenses;

  /// No description provided for @changelog121ContinuousScroll.
  ///
  /// In en, this message translates to:
  /// **'Added shared chapter-by-chapter and continuous whole-book scrolling for online sources'**
  String get changelog121ContinuousScroll;

  /// No description provided for @changelog121Typography.
  ///
  /// In en, this message translates to:
  /// **'Fixed asymmetric Chinese text margins and aligned pagination with rendering'**
  String get changelog121Typography;

  /// No description provided for @changelog124PaperLeaf.
  ///
  /// In en, this message translates to:
  /// **'Added paper-bound page chrome, classic fold animation, and reader typography controls'**
  String get changelog124PaperLeaf;

  /// No description provided for @changelog122ContinuousTap.
  ///
  /// In en, this message translates to:
  /// **'Restored center-tap reader controls during continuous online scrolling'**
  String get changelog122ContinuousTap;

  /// No description provided for @changelog200ReaderExperience.
  ///
  /// In en, this message translates to:
  /// **'Upgraded top information, page numbering, and simulated page turns'**
  String get changelog200ReaderExperience;

  /// No description provided for @changelog200CustomThemes.
  ///
  /// In en, this message translates to:
  /// **'Added multiple custom reading themes, image backgrounds, and drag sorting'**
  String get changelog200CustomThemes;

  /// No description provided for @changelog200Navigation.
  ///
  /// In en, this message translates to:
  /// **'Improved EPUB pagination and collapsible nested contents'**
  String get changelog200Navigation;

  /// No description provided for @changelog200KeepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled real keep-screen-on behavior while reading on Android'**
  String get changelog200KeepScreenOn;

  /// No description provided for @changelog110CustomFonts.
  ///
  /// In en, this message translates to:
  /// **'Added custom fonts'**
  String get changelog110CustomFonts;

  /// No description provided for @changelog110Bookmarks.
  ///
  /// In en, this message translates to:
  /// **'Added bookmark support'**
  String get changelog110Bookmarks;

  /// No description provided for @changelog102Summary.
  ///
  /// In en, this message translates to:
  /// **'Improved discovery, standalone search, and reading settings'**
  String get changelog102Summary;

  /// No description provided for @changelog101Summary.
  ///
  /// In en, this message translates to:
  /// **'Added discovery, paginated search, and open-source licensing notes'**
  String get changelog101Summary;

  /// No description provided for @changelog100Summary.
  ///
  /// In en, this message translates to:
  /// **'Added open book sources, reading themes, and page-turn animation'**
  String get changelog100Summary;

  /// No description provided for @changelog091Summary.
  ///
  /// In en, this message translates to:
  /// **'Added tablet spreads and cross-platform release support'**
  String get changelog091Summary;

  /// Maintainer label in the about card
  ///
  /// In en, this message translates to:
  /// **'Maintainer'**
  String get settingsMaintainerLabel;

  /// License label in the about card
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get settingsLicenseLabel;

  /// Subtitle of the GitHub repository row
  ///
  /// In en, this message translates to:
  /// **'View open-source project'**
  String get settingsViewSourceSubtitle;

  /// Row title to join the QQ group
  ///
  /// In en, this message translates to:
  /// **'Join QQ group'**
  String get settingsJoinQqGroup;

  /// Toast when the QQ link fails to open
  ///
  /// In en, this message translates to:
  /// **'Could not open QQ. Please make sure QQ is installed.'**
  String get settingsQqOpenFailed;

  /// Title of the contributors card
  ///
  /// In en, this message translates to:
  /// **'Contributors'**
  String get contributorsTitle;

  /// Subtitle of the contributors card
  ///
  /// In en, this message translates to:
  /// **'Thanks to everyone making Open Reading better'**
  String get contributorsSubtitle;

  /// Toast when a contributor profile link fails to open
  ///
  /// In en, this message translates to:
  /// **'Could not open contributor profile'**
  String get contributorsOpenProfileFailed;

  /// Empty state of the contributors card
  ///
  /// In en, this message translates to:
  /// **'No contributors to show yet'**
  String get contributorsEmpty;

  /// Error state of the contributors card
  ///
  /// In en, this message translates to:
  /// **'Could not load contributors'**
  String get contributorsLoadFailed;

  /// Title of the theme mode setting and modal
  ///
  /// In en, this message translates to:
  /// **'Night mode'**
  String get settingsDarkModeTitle;

  /// Generic subtitle showing the current value of a setting
  ///
  /// In en, this message translates to:
  /// **'Current: {value}'**
  String settingsCurrentValue(String value);

  /// Title of the glass effect toggle
  ///
  /// In en, this message translates to:
  /// **'Glass effect'**
  String get settingsUiStyleTitle;

  /// Description of the glass effect toggle
  ///
  /// In en, this message translates to:
  /// **'Use translucent surfaces, background blur, and floating depth'**
  String get settingsGlassEffectSubtitle;

  /// Title of the mobile bottom navigation label visibility toggle
  ///
  /// In en, this message translates to:
  /// **'Hide bottom navigation labels'**
  String get settingsHideNavigationLabelsTitle;

  /// Description of the mobile bottom navigation label visibility toggle
  ///
  /// In en, this message translates to:
  /// **'Show icons only in the mobile bottom navigation'**
  String get settingsHideNavigationLabelsSubtitle;

  /// Accent summary when following the app theme
  ///
  /// In en, this message translates to:
  /// **'Accent color: follow theme'**
  String get settingsAccentFollowTheme;

  /// Accent summary showing the chosen color name
  ///
  /// In en, this message translates to:
  /// **'Accent color: {name}'**
  String settingsAccentValue(String name);

  /// Title of the app theme setting
  ///
  /// In en, this message translates to:
  /// **'App theme'**
  String get settingsAppThemeTitle;

  /// Subtitle combining the current theme name and accent summary
  ///
  /// In en, this message translates to:
  /// **'Current: {theme} · {accent}'**
  String settingsCurrentThemeSummary(String theme, String accent);

  /// Accent color subtitle when no custom accent is set
  ///
  /// In en, this message translates to:
  /// **'Follow app theme'**
  String get settingsFollowAppTheme;

  /// Title of the accent color setting and modal
  ///
  /// In en, this message translates to:
  /// **'Accent color'**
  String get settingsAccentColorTitle;

  /// Hint for system theme mode
  ///
  /// In en, this message translates to:
  /// **'Switch automatically with the system appearance'**
  String get settingsThemeModeSystemHint;

  /// Hint for light theme mode
  ///
  /// In en, this message translates to:
  /// **'Always use the light appearance'**
  String get settingsThemeModeLightHint;

  /// Hint for dark theme mode
  ///
  /// In en, this message translates to:
  /// **'Always use the dark appearance'**
  String get settingsThemeModeDarkHint;

  /// Title of the app theme picker modal
  ///
  /// In en, this message translates to:
  /// **'Choose app theme'**
  String get settingsSelectAppTheme;

  /// Done button in theme/accent modals
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get settingsDone;

  /// Advice text in the accent color modal
  ///
  /// In en, this message translates to:
  /// **'Prefer choosing an app theme first, then override the accent color as needed.'**
  String get settingsAccentColorAdvice;

  /// Option title to follow the theme accent
  ///
  /// In en, this message translates to:
  /// **'Follow theme'**
  String get settingsAccentFollowThemeOption;

  /// Description for the follow-theme accent option
  ///
  /// In en, this message translates to:
  /// **'Use the current app theme\'s default accent color'**
  String get settingsAccentFollowThemeDesc;

  /// Title of the about card
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAboutTitle;

  /// Display name of the app in the about card
  ///
  /// In en, this message translates to:
  /// **'Open Reading'**
  String get settingsAppName;

  /// Author line in the about card
  ///
  /// In en, this message translates to:
  /// **'Maintainer: 小元Niki'**
  String get settingsAuthor;

  /// Link label to the GitHub repository
  ///
  /// In en, this message translates to:
  /// **'GitHub repository'**
  String get settingsGithubRepo;

  /// New Year greeting in the about card
  ///
  /// In en, this message translates to:
  /// **'A focused, restrained, and freely modifiable cross-platform reader.'**
  String get settingsNewYearGreeting;

  /// Toast when the GitHub link fails to open
  ///
  /// In en, this message translates to:
  /// **'Could not open the GitHub link'**
  String get settingsGithubOpenFailed;

  /// No description provided for @updateCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check for updates'**
  String get updateCheckNow;

  /// No description provided for @updateCheckNowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Get the latest version from GitHub or the official website'**
  String get updateCheckNowSubtitle;

  /// No description provided for @updateAvailableTitle.
  ///
  /// In en, this message translates to:
  /// **'A new version is available'**
  String get updateAvailableTitle;

  /// No description provided for @updateVersionSummary.
  ///
  /// In en, this message translates to:
  /// **'Current version: {currentVersion}\nLatest version: {latestVersion}'**
  String updateVersionSummary(String currentVersion, String latestVersion);

  /// No description provided for @updateNotesTitle.
  ///
  /// In en, this message translates to:
  /// **'What\'s new'**
  String get updateNotesTitle;

  /// No description provided for @updateNotesEmpty.
  ///
  /// In en, this message translates to:
  /// **'No release notes were provided for this version.'**
  String get updateNotesEmpty;

  /// No description provided for @updateLater.
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get updateLater;

  /// No description provided for @updateGoToDownload.
  ///
  /// In en, this message translates to:
  /// **'Go to update'**
  String get updateGoToDownload;

  /// No description provided for @updateFromGithub.
  ///
  /// In en, this message translates to:
  /// **'Update from GitHub'**
  String get updateFromGithub;

  /// No description provided for @updateFromWebsite.
  ///
  /// In en, this message translates to:
  /// **'Open official website'**
  String get updateFromWebsite;

  /// No description provided for @updateFromWebsiteInstall.
  ///
  /// In en, this message translates to:
  /// **'Download from website'**
  String get updateFromWebsiteInstall;

  /// No description provided for @updateWebsiteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'The official website package is not available for this device yet'**
  String get updateWebsiteUnavailable;

  /// No description provided for @updateDownloadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Downloading update'**
  String get updateDownloadingTitle;

  /// No description provided for @updateDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'Downloaded {percent}%'**
  String updateDownloadProgress(int percent);

  /// No description provided for @updatePreparingInstaller.
  ///
  /// In en, this message translates to:
  /// **'Verifying the package and preparing the system installer…'**
  String get updatePreparingInstaller;

  /// No description provided for @updateDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not download the update from the official website'**
  String get updateDownloadFailed;

  /// No description provided for @updateIntegrityFailed.
  ///
  /// In en, this message translates to:
  /// **'The downloaded update failed its integrity check and was deleted'**
  String get updateIntegrityFailed;

  /// No description provided for @updateInstallFailed.
  ///
  /// In en, this message translates to:
  /// **'The update package could not be installed. Check installation permissions and try again.'**
  String get updateInstallFailed;

  /// No description provided for @updateAlreadyLatest.
  ///
  /// In en, this message translates to:
  /// **'You\'re already using the latest version'**
  String get updateAlreadyLatest;

  /// No description provided for @updateCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not check for updates. Please try again later.'**
  String get updateCheckFailed;

  /// No description provided for @updateOpenFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not open the GitHub Release download page'**
  String get updateOpenFailed;

  /// Toast when using an iOS-only feature on another platform
  ///
  /// In en, this message translates to:
  /// **'This feature is only available on iOS'**
  String get settingsIosOnlyFeature;

  /// Toast summarizing the iOS sync result
  ///
  /// In en, this message translates to:
  /// **'Synced to {storage}\n{books} books, {files} files copied'**
  String settingsIosSyncResult(String storage, int books, int files);

  /// Default reason in the restart dialog
  ///
  /// In en, this message translates to:
  /// **'This settings change requires an app restart to take full effect.'**
  String get settingsRestartRequiredReason;

  /// Title of the restart dialog
  ///
  /// In en, this message translates to:
  /// **'Restart required'**
  String get settingsRestartRequiredTitle;

  /// Body of the restart dialog combining the reason and the question
  ///
  /// In en, this message translates to:
  /// **'{reason}\n\nRestart the app now?'**
  String settingsRestartPrompt(String reason);

  /// Button to postpone the restart
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get settingsRestartLater;

  /// Button to restart the app immediately
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get settingsRestartNow;

  /// Detailed stats page title
  ///
  /// In en, this message translates to:
  /// **'Detailed Statistics'**
  String get statsDetailedTitle;

  /// Time range option: last 7 days
  ///
  /// In en, this message translates to:
  /// **'7 days'**
  String get statsRange7Days;

  /// Time range option: last 30 days
  ///
  /// In en, this message translates to:
  /// **'30 days'**
  String get statsRange30Days;

  /// Time range option: last 90 days
  ///
  /// In en, this message translates to:
  /// **'90 days'**
  String get statsRange90Days;

  /// Time range option: last year
  ///
  /// In en, this message translates to:
  /// **'1 year'**
  String get statsRange1Year;

  /// Time range option: all time
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get statsRangeAll;

  /// Stats tab title: overview
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get statsTabOverview;

  /// Stats tab title: charts
  ///
  /// In en, this message translates to:
  /// **'Charts'**
  String get statsTabCharts;

  /// Stats tab title: books
  ///
  /// In en, this message translates to:
  /// **'Books'**
  String get statsTabBooks;

  /// Stats tab title: achievements
  ///
  /// In en, this message translates to:
  /// **'Achievements'**
  String get statsTabAchievements;

  /// Hero panel title on the overview tab
  ///
  /// In en, this message translates to:
  /// **'Reading Overview'**
  String get statsReadingOverview;

  /// Hero headline: cumulative reading hours (hours is a preformatted decimal string)
  ///
  /// In en, this message translates to:
  /// **'Total {hours} hours'**
  String statsCumulativeHours(Object hours);

  /// Hero subtitle encouraging the current reading streak
  ///
  /// In en, this message translates to:
  /// **'Keep the rhythm — you have read {days} days in a row'**
  String statsStreakEncouragement(Object days);

  /// Overview chip label: total reading time
  ///
  /// In en, this message translates to:
  /// **'Total Time'**
  String get statsTotalDuration;

  /// Overview chip label: average single-session duration
  ///
  /// In en, this message translates to:
  /// **'Avg Session'**
  String get statsAvgSession;

  /// A number of days with unit
  ///
  /// In en, this message translates to:
  /// **'{count} days'**
  String statsDaysCount(Object count);

  /// Shown when there is no statistics data
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get statsNoData;

  /// Best reading period label: early morning
  ///
  /// In en, this message translates to:
  /// **'Early morning 05:00-08:59'**
  String get statsPeriodEarlyMorning;

  /// Best reading period label: morning
  ///
  /// In en, this message translates to:
  /// **'Morning 09:00-11:59'**
  String get statsPeriodMorning;

  /// Best reading period label: afternoon
  ///
  /// In en, this message translates to:
  /// **'Afternoon 12:00-17:59'**
  String get statsPeriodAfternoon;

  /// Best reading period label: evening
  ///
  /// In en, this message translates to:
  /// **'Evening 18:00-21:59'**
  String get statsPeriodEvening;

  /// Best reading period label: late night
  ///
  /// In en, this message translates to:
  /// **'Late night 22:00-04:59'**
  String get statsPeriodLateNight;

  /// Stats grid card title: total reading time
  ///
  /// In en, this message translates to:
  /// **'Total Reading Time'**
  String get statsTotalReadingTime;

  /// Stats grid card title: total pages read
  ///
  /// In en, this message translates to:
  /// **'Total Pages Read'**
  String get statsTotalPagesRead;

  /// Stats grid card title: number of books read
  ///
  /// In en, this message translates to:
  /// **'Books Read'**
  String get statsBooksReadCount;

  /// Unit suffix for pages
  ///
  /// In en, this message translates to:
  /// **'pages'**
  String get statsUnitPage;

  /// Card title: today's reading progress
  ///
  /// In en, this message translates to:
  /// **'Today\'s Reading Progress'**
  String get statsTodayProgress;

  /// Progress vs target in minutes
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} min'**
  String statsMinutesOfTarget(Object current, Object target);

  /// Label for pages read (progress row and chart type selector)
  ///
  /// In en, this message translates to:
  /// **'Pages Read'**
  String get statsPagesRead;

  /// Progress vs target in pages
  ///
  /// In en, this message translates to:
  /// **'{current} / {target} pages'**
  String statsPagesOfTarget(Object current, Object target);

  /// Card title: reading habits analysis
  ///
  /// In en, this message translates to:
  /// **'Reading Habits'**
  String get statsReadingHabits;

  /// Habit item label: best reading period of the day
  ///
  /// In en, this message translates to:
  /// **'Best Reading Time'**
  String get statsBestReadingPeriod;

  /// Habit item label: average single reading session
  ///
  /// In en, this message translates to:
  /// **'Avg Session Reading'**
  String get statsAvgSessionReading;

  /// Habit item label: longest consecutive reading days
  ///
  /// In en, this message translates to:
  /// **'Longest Streak'**
  String get statsMaxStreakDays;

  /// Habit item label: reading focus score
  ///
  /// In en, this message translates to:
  /// **'Reading Focus'**
  String get statsFocusScore;

  /// Chart type selector: number of books
  ///
  /// In en, this message translates to:
  /// **'Book Count'**
  String get statsBookCount;

  /// Chart title: reading trend analysis
  ///
  /// In en, this message translates to:
  /// **'Reading Trend Analysis'**
  String get statsTrendAnalysis;

  /// Chart axis label: minutes (compact)
  ///
  /// In en, this message translates to:
  /// **'{value} min'**
  String statsAxisMinutes(Object value);

  /// Chart axis label: pages (compact)
  ///
  /// In en, this message translates to:
  /// **'{value} pg'**
  String statsAxisPages(Object value);

  /// Chart axis label: books (compact)
  ///
  /// In en, this message translates to:
  /// **'{value} bk'**
  String statsAxisBooks(Object value);

  /// Chart axis label: hour of day (compact)
  ///
  /// In en, this message translates to:
  /// **'{hour}h'**
  String statsAxisHour(Object hour);

  /// Chart title: hourly reading time distribution
  ///
  /// In en, this message translates to:
  /// **'Reading Time Distribution'**
  String get statsTimeDistribution;

  /// Chart title: book format distribution pie chart
  ///
  /// In en, this message translates to:
  /// **'Book Format Distribution'**
  String get statsFormatDistribution;

  /// Books summary: completed books
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get statsCompleted;

  /// Books summary: books currently being read
  ///
  /// In en, this message translates to:
  /// **'In Progress'**
  String get statsInProgress;

  /// Books ranking title when real durations exist
  ///
  /// In en, this message translates to:
  /// **'Reading Time Ranking'**
  String get statsDurationRanking;

  /// Books ranking title when only progress data exists
  ///
  /// In en, this message translates to:
  /// **'Reading Progress Ranking'**
  String get statsProgressRanking;

  /// A number of pages with unit
  ///
  /// In en, this message translates to:
  /// **'{count} pages'**
  String statsPagesCount(Object count);

  /// Number of reading sessions
  ///
  /// In en, this message translates to:
  /// **'{count} sessions'**
  String statsSessionCount(Object count);

  /// Achievements overview subtitle
  ///
  /// In en, this message translates to:
  /// **'Earned {achieved} achievements, {remaining} more to unlock'**
  String statsAchievementsSummary(Object achieved, Object remaining);

  /// Achievement title: first reading session
  ///
  /// In en, this message translates to:
  /// **'First Read'**
  String get statsAchievementFirstReadTitle;

  /// Achievement description: first reading session
  ///
  /// In en, this message translates to:
  /// **'Complete your first reading session'**
  String get statsAchievementFirstReadDesc;

  /// Achievement title: 10 hours total
  ///
  /// In en, this message translates to:
  /// **'Reading Novice'**
  String get statsAchievementNoviceTitle;

  /// Achievement description: 10 hours total
  ///
  /// In en, this message translates to:
  /// **'Read for a total of 10 hours'**
  String get statsAchievementNoviceDesc;

  /// Achievement title: 100 hours total
  ///
  /// In en, this message translates to:
  /// **'Bookworm'**
  String get statsAchievementBookwormTitle;

  /// Achievement description: 100 hours total
  ///
  /// In en, this message translates to:
  /// **'Read for a total of 100 hours'**
  String get statsAchievementBookwormDesc;

  /// Achievement title: 7-day streak
  ///
  /// In en, this message translates to:
  /// **'Reading Expert'**
  String get statsAchievementExpertTitle;

  /// Achievement description: 7-day streak
  ///
  /// In en, this message translates to:
  /// **'Read 7 days in a row'**
  String get statsAchievementExpertDesc;

  /// Achievement title: 10000 pages
  ///
  /// In en, this message translates to:
  /// **'Ocean of Knowledge'**
  String get statsAchievementOceanTitle;

  /// Achievement description: 10000 pages
  ///
  /// In en, this message translates to:
  /// **'Read 10,000 pages'**
  String get statsAchievementOceanDesc;

  /// Achievement title: 10 different books
  ///
  /// In en, this message translates to:
  /// **'Polymath'**
  String get statsAchievementScholarTitle;

  /// Achievement description: 10 different books
  ///
  /// In en, this message translates to:
  /// **'Read 10 different books'**
  String get statsAchievementScholarDesc;

  /// Achievement title: 30-day streak
  ///
  /// In en, this message translates to:
  /// **'Reading Marathon'**
  String get statsAchievementMarathonTitle;

  /// Achievement description: 30-day streak
  ///
  /// In en, this message translates to:
  /// **'Read 30 days in a row'**
  String get statsAchievementMarathonDesc;

  /// Achievement title: 500 hours total
  ///
  /// In en, this message translates to:
  /// **'Focus Master'**
  String get statsAchievementFocusTitle;

  /// Achievement description: 500 hours total
  ///
  /// In en, this message translates to:
  /// **'Read for a total of 500 hours'**
  String get statsAchievementFocusDesc;

  /// Achievement progress percentage
  ///
  /// In en, this message translates to:
  /// **'Progress: {percent}%'**
  String statsProgressPercent(Object percent);

  /// Chart title: reading goal progress
  ///
  /// In en, this message translates to:
  /// **'Reading Goal Progress'**
  String get statsGoalProgress;

  /// Goal row label: this month's reading time
  ///
  /// In en, this message translates to:
  /// **'This Month\'s Reading Time'**
  String get statsMonthlyReadingTime;

  /// Goal row label: this week's reading time
  ///
  /// In en, this message translates to:
  /// **'This Week\'s Reading Time'**
  String get statsWeeklyReadingTime;

  /// Goal row label: average daily pages over the last 7 days
  ///
  /// In en, this message translates to:
  /// **'Daily Avg Pages (Last 7 Days)'**
  String get statsAvgDailyPages7d;

  /// A number of hours with unit
  ///
  /// In en, this message translates to:
  /// **'{count} hours'**
  String statsHoursCount(Object count);

  /// Chart title: reading speed trend
  ///
  /// In en, this message translates to:
  /// **'Reading Speed Trend'**
  String get statsSpeedTrend;

  /// Average reading speed badge (speed is a preformatted decimal string)
  ///
  /// In en, this message translates to:
  /// **'Avg: {speed} pages/min'**
  String statsAvgSpeed(Object speed);

  /// Heatmap card title: reading continuity
  ///
  /// In en, this message translates to:
  /// **'Reading Continuity'**
  String get statsReadingContinuity;

  /// Current consecutive reading days badge
  ///
  /// In en, this message translates to:
  /// **'Current streak: {days} days'**
  String statsCurrentStreak(Object days);

  /// Heatmap legend: low intensity
  ///
  /// In en, this message translates to:
  /// **'Less'**
  String get statsHeatmapLess;

  /// Heatmap legend: high intensity
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get statsHeatmapMore;

  /// Heatmap column header: week number
  ///
  /// In en, this message translates to:
  /// **'Week {week}'**
  String statsWeekNumber(Object week);

  /// No description provided for @bookSourceAddToShelf.
  ///
  /// In en, this message translates to:
  /// **'Add to shelf'**
  String get bookSourceAddToShelf;

  /// No description provided for @bookSourceAddOnline.
  ///
  /// In en, this message translates to:
  /// **'Add online'**
  String get bookSourceAddOnline;

  /// No description provided for @bookSourceAddOnlineHint.
  ///
  /// In en, this message translates to:
  /// **'Read from the source and cache chapters as you go'**
  String get bookSourceAddOnlineHint;

  /// No description provided for @bookSourceDownloadLocal.
  ///
  /// In en, this message translates to:
  /// **'Download locally'**
  String get bookSourceDownloadLocal;

  /// No description provided for @bookSourceDownloadLocalHint.
  ///
  /// In en, this message translates to:
  /// **'Download every chapter and add a local TXT copy'**
  String get bookSourceDownloadLocalHint;

  /// No description provided for @bookSourceAddedOnline.
  ///
  /// In en, this message translates to:
  /// **'Added to shelf as an online book'**
  String get bookSourceAddedOnline;

  /// No description provided for @bookSourceAlreadyOnShelf.
  ///
  /// In en, this message translates to:
  /// **'This book is already on your shelf'**
  String get bookSourceAlreadyOnShelf;

  /// No description provided for @bookSourceDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading locally'**
  String get bookSourceDownloading;

  /// No description provided for @bookSourceFetchingCatalog.
  ///
  /// In en, this message translates to:
  /// **'Fetching chapter catalog…'**
  String get bookSourceFetchingCatalog;

  /// No description provided for @bookSourceDownloadProgress.
  ///
  /// In en, this message translates to:
  /// **'{completed}/{total} chapters'**
  String bookSourceDownloadProgress(int completed, int total);

  /// No description provided for @bookSourceDownloadComplete.
  ///
  /// In en, this message translates to:
  /// **'Download complete and added to the local shelf'**
  String get bookSourceDownloadComplete;

  /// No description provided for @bookSourceDownloadConverted.
  ///
  /// In en, this message translates to:
  /// **'Download complete. This is now a local book'**
  String get bookSourceDownloadConverted;

  /// No description provided for @bookSourceDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed: {error}'**
  String bookSourceDownloadFailed(String error);

  /// No description provided for @bookSourceExitAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add to shelf?'**
  String get bookSourceExitAddTitle;

  /// No description provided for @bookSourceExitAddMessage.
  ///
  /// In en, this message translates to:
  /// **'Add “{title}” to your shelf as an online book? Your reading progress will be kept.'**
  String bookSourceExitAddMessage(String title);

  /// No description provided for @bookSourceNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get bookSourceNotNow;

  /// No description provided for @bookSourceOnlineBadge.
  ///
  /// In en, this message translates to:
  /// **'Online'**
  String get bookSourceOnlineBadge;

  /// No description provided for @bookSourceOnlineDataBroken.
  ///
  /// In en, this message translates to:
  /// **'Online book data is invalid: {error}'**
  String bookSourceOnlineDataBroken(String error);

  /// Title of the reader-only theme selector
  ///
  /// In en, this message translates to:
  /// **'Reading theme'**
  String get readerThemeTitle;

  /// Explains that reading themes are independent from the app theme
  ///
  /// In en, this message translates to:
  /// **'Only changes the reading page and its controls'**
  String get readerThemeDescription;

  /// Day reading theme name
  ///
  /// In en, this message translates to:
  /// **'Day'**
  String get readerThemeDay;

  /// No description provided for @readerThemeMist.
  ///
  /// In en, this message translates to:
  /// **'Mist'**
  String get readerThemeMist;

  /// No description provided for @readerThemeGreen.
  ///
  /// In en, this message translates to:
  /// **'Eye care'**
  String get readerThemeGreen;

  /// No description provided for @readerThemeRose.
  ///
  /// In en, this message translates to:
  /// **'Rose'**
  String get readerThemeRose;

  /// No description provided for @readerThemeNavy.
  ///
  /// In en, this message translates to:
  /// **'Deep blue'**
  String get readerThemeNavy;

  /// Night reading theme name
  ///
  /// In en, this message translates to:
  /// **'Night'**
  String get readerThemeNight;

  /// Pure black reading theme name
  ///
  /// In en, this message translates to:
  /// **'Pure black'**
  String get readerThemePureBlack;

  /// Parchment reading theme name
  ///
  /// In en, this message translates to:
  /// **'Parchment'**
  String get readerThemeParchment;

  /// No description provided for @readerThemeCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get readerThemeCustom;

  /// No description provided for @readerPullBookmarkTitle.
  ///
  /// In en, this message translates to:
  /// **'Pull-down bookmark'**
  String get readerPullBookmarkTitle;

  /// No description provided for @readerPullBookmarkHint.
  ///
  /// In en, this message translates to:
  /// **'Pull down from the top edge and release to add or remove a bookmark for this page'**
  String get readerPullBookmarkHint;

  /// No description provided for @readerPullBookmarkAddHint.
  ///
  /// In en, this message translates to:
  /// **'Pull farther to add bookmark'**
  String get readerPullBookmarkAddHint;

  /// No description provided for @readerPullBookmarkRemoveHint.
  ///
  /// In en, this message translates to:
  /// **'Pull farther to remove bookmark'**
  String get readerPullBookmarkRemoveHint;

  /// No description provided for @readerPullBookmarkReleaseHint.
  ///
  /// In en, this message translates to:
  /// **'Release to finish'**
  String get readerPullBookmarkReleaseHint;

  /// No description provided for @readerTapAnimationTitle.
  ///
  /// In en, this message translates to:
  /// **'Tap animation'**
  String get readerTapAnimationTitle;

  /// No description provided for @readerTapAnimationHint.
  ///
  /// In en, this message translates to:
  /// **'Use the current page-turn animation for side taps; turn off to refresh instantly'**
  String get readerTapAnimationHint;

  /// No description provided for @readerTabletTwoPageTitle.
  ///
  /// In en, this message translates to:
  /// **'Tablet two-page layout'**
  String get readerTabletTwoPageTitle;

  /// No description provided for @readerTabletTwoPageHint.
  ///
  /// In en, this message translates to:
  /// **'Show left and right pages side by side in landscape; turn off to always use a single page'**
  String get readerTabletTwoPageHint;

  /// No description provided for @readerCustomThemeTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom reading theme'**
  String get readerCustomThemeTitle;

  /// No description provided for @readerCustomThemeReset.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get readerCustomThemeReset;

  /// No description provided for @readerCustomThemeColors.
  ///
  /// In en, this message translates to:
  /// **'Theme colors'**
  String get readerCustomThemeColors;

  /// No description provided for @readerCustomThemeTextColor.
  ///
  /// In en, this message translates to:
  /// **'Text color'**
  String get readerCustomThemeTextColor;

  /// No description provided for @readerCustomThemeTextColorHint.
  ///
  /// In en, this message translates to:
  /// **'Body text, headings, and primary icons'**
  String get readerCustomThemeTextColorHint;

  /// No description provided for @readerCustomThemeBackground.
  ///
  /// In en, this message translates to:
  /// **'Reading background'**
  String get readerCustomThemeBackground;

  /// No description provided for @readerCustomThemeBackgroundHint.
  ///
  /// In en, this message translates to:
  /// **'The paper and reading canvas color'**
  String get readerCustomThemeBackgroundHint;

  /// No description provided for @readerCustomThemeControlBar.
  ///
  /// In en, this message translates to:
  /// **'Control bar color'**
  String get readerCustomThemeControlBar;

  /// No description provided for @readerCustomThemeControlBarHint.
  ///
  /// In en, this message translates to:
  /// **'Top and bottom controls and settings surfaces'**
  String get readerCustomThemeControlBarHint;

  /// No description provided for @readerCustomThemeContrastGood.
  ///
  /// In en, this message translates to:
  /// **'Text has clear contrast for comfortable long reading'**
  String get readerCustomThemeContrastGood;

  /// No description provided for @readerCustomThemeContrastLow.
  ///
  /// In en, this message translates to:
  /// **'Text contrast is low and may cause reading fatigue'**
  String get readerCustomThemeContrastLow;

  /// No description provided for @readerCustomThemeSave.
  ///
  /// In en, this message translates to:
  /// **'Save and use'**
  String get readerCustomThemeSave;

  /// No description provided for @readerCustomThemePreview.
  ///
  /// In en, this message translates to:
  /// **'Live preview'**
  String get readerCustomThemePreview;

  /// No description provided for @readerCustomThemePreviewChapter.
  ///
  /// In en, this message translates to:
  /// **'Chapter One · Wind Between the Pages'**
  String get readerCustomThemePreviewChapter;

  /// No description provided for @readerCustomThemePreviewBody.
  ///
  /// In en, this message translates to:
  /// **'This is your reading space. Tune the text, paper, and control colors until every page feels distinctly yours.'**
  String get readerCustomThemePreviewBody;

  /// No description provided for @readerCustomThemeHexInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a 6-digit hex color, such as #F6F0E4'**
  String get readerCustomThemeHexInvalid;

  /// No description provided for @readerCustomThemeHexLabel.
  ///
  /// In en, this message translates to:
  /// **'Hex color'**
  String get readerCustomThemeHexLabel;

  /// No description provided for @readerCustomThemesTitle.
  ///
  /// In en, this message translates to:
  /// **'Custom reading themes'**
  String get readerCustomThemesTitle;

  /// No description provided for @readerCustomThemeAdd.
  ///
  /// In en, this message translates to:
  /// **'Add theme'**
  String get readerCustomThemeAdd;

  /// No description provided for @readerCustomThemeReorderHint.
  ///
  /// In en, this message translates to:
  /// **'Hold the handle on the right to reorder themes. The same order appears in reading settings.'**
  String get readerCustomThemeReorderHint;

  /// No description provided for @readerCustomThemeUse.
  ///
  /// In en, this message translates to:
  /// **'Use selected theme'**
  String get readerCustomThemeUse;

  /// No description provided for @readerCustomThemeDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete reading theme?'**
  String get readerCustomThemeDeleteTitle;

  /// No description provided for @readerCustomThemeDeleteMessage.
  ///
  /// In en, this message translates to:
  /// **'“{name}” will be removed from your themes, along with its saved background image.'**
  String readerCustomThemeDeleteMessage(String name);

  /// No description provided for @readerCustomThemeEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No custom themes yet'**
  String get readerCustomThemeEmptyTitle;

  /// No description provided for @readerCustomThemeEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Create your own combination of type, paper color, and background image.'**
  String get readerCustomThemeEmptyHint;

  /// No description provided for @readerCustomThemeNewTitle.
  ///
  /// In en, this message translates to:
  /// **'New reading theme'**
  String get readerCustomThemeNewTitle;

  /// No description provided for @readerCustomThemeEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit reading theme'**
  String get readerCustomThemeEditTitle;

  /// No description provided for @readerCustomThemeName.
  ///
  /// In en, this message translates to:
  /// **'Theme name'**
  String get readerCustomThemeName;

  /// No description provided for @readerCustomThemeNameHint.
  ///
  /// In en, this message translates to:
  /// **'For example, Rainy night or Afternoon paper'**
  String get readerCustomThemeNameHint;

  /// No description provided for @readerCustomThemeBackgroundImage.
  ///
  /// In en, this message translates to:
  /// **'Background image'**
  String get readerCustomThemeBackgroundImage;

  /// No description provided for @readerCustomThemeBackgroundImageHint.
  ///
  /// In en, this message translates to:
  /// **'Supports JPG, PNG, and WebP. The image is copied into app storage.'**
  String get readerCustomThemeBackgroundImageHint;

  /// No description provided for @readerCustomThemeChooseImage.
  ///
  /// In en, this message translates to:
  /// **'Upload image'**
  String get readerCustomThemeChooseImage;

  /// No description provided for @readerCustomThemeReplaceImage.
  ///
  /// In en, this message translates to:
  /// **'Replace image'**
  String get readerCustomThemeReplaceImage;

  /// No description provided for @readerCustomThemeRemoveImage.
  ///
  /// In en, this message translates to:
  /// **'Remove image'**
  String get readerCustomThemeRemoveImage;

  /// No description provided for @readerCustomThemeImageStrength.
  ///
  /// In en, this message translates to:
  /// **'Background image strength'**
  String get readerCustomThemeImageStrength;

  /// No description provided for @readerCustomThemeImageUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Background image import is not supported on this platform'**
  String get readerCustomThemeImageUnsupported;

  /// No description provided for @readerCustomThemeImageTooLarge.
  ///
  /// In en, this message translates to:
  /// **'The image must be no larger than 20 MB'**
  String get readerCustomThemeImageTooLarge;

  /// No description provided for @readerCustomThemeImageFormat.
  ///
  /// In en, this message translates to:
  /// **'Choose a JPG, PNG, or WebP image'**
  String get readerCustomThemeImageFormat;

  /// No description provided for @readerCustomThemeImageFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not import the background image. Try again.'**
  String get readerCustomThemeImageFailed;

  /// No description provided for @importSourceTitle.
  ///
  /// In en, this message translates to:
  /// **'Add books'**
  String get importSourceTitle;

  /// No description provided for @importSourceDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose several files first. Review the queue before starting the import.'**
  String get importSourceDescription;

  /// No description provided for @importSelectFiles.
  ///
  /// In en, this message translates to:
  /// **'Choose files'**
  String get importSelectFiles;

  /// No description provided for @importIosSharedDocuments.
  ///
  /// In en, this message translates to:
  /// **'On My iPhone · Open Reading'**
  String get importIosSharedDocuments;

  /// No description provided for @importICloudDrive.
  ///
  /// In en, this message translates to:
  /// **'iCloud Drive · Open Reading'**
  String get importICloudDrive;

  /// No description provided for @importICloudUnavailable.
  ///
  /// In en, this message translates to:
  /// **'iCloud Drive is unavailable'**
  String get importICloudUnavailable;

  /// No description provided for @importAndroidFolder.
  ///
  /// In en, this message translates to:
  /// **'Authorize a book folder'**
  String get importAndroidFolder;

  /// No description provided for @importAndroidRescan.
  ///
  /// In en, this message translates to:
  /// **'Scan authorized folders'**
  String get importAndroidRescan;

  /// No description provided for @importFolderPermissionAvailable.
  ///
  /// In en, this message translates to:
  /// **'Authorized · tap to scan'**
  String get importFolderPermissionAvailable;

  /// No description provided for @importFolderPermissionLost.
  ///
  /// In en, this message translates to:
  /// **'Permission lost · authorize again to restore access'**
  String get importFolderPermissionLost;

  /// No description provided for @importRemoveFolder.
  ///
  /// In en, this message translates to:
  /// **'Remove folder'**
  String get importRemoveFolder;

  /// No description provided for @importQueueTitle.
  ///
  /// In en, this message translates to:
  /// **'Import queue ({count})'**
  String importQueueTitle(int count);

  /// No description provided for @importQueueHint.
  ///
  /// In en, this message translates to:
  /// **'Remove files selected by mistake, then import them one at a time.'**
  String get importQueueHint;

  /// No description provided for @importQueueEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No books selected'**
  String get importQueueEmptyTitle;

  /// No description provided for @importQueueEmptyBody.
  ///
  /// In en, this message translates to:
  /// **'Choose EPUB, PDF, TXT, MOBI or another supported book file.'**
  String get importQueueEmptyBody;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import {count} books'**
  String importAction(int count);

  /// No description provided for @importRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Retry {count} failed'**
  String importRetryFailed(int count);

  /// No description provided for @importStatusQueued.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get importStatusQueued;

  /// No description provided for @importStatusPreparing.
  ///
  /// In en, this message translates to:
  /// **'Preparing file'**
  String get importStatusPreparing;

  /// No description provided for @importStatusChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking'**
  String get importStatusChecking;

  /// No description provided for @importStatusCopying.
  ///
  /// In en, this message translates to:
  /// **'Copying'**
  String get importStatusCopying;

  /// No description provided for @importStatusAnalyzing.
  ///
  /// In en, this message translates to:
  /// **'Analyzing'**
  String get importStatusAnalyzing;

  /// No description provided for @importStatusSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving'**
  String get importStatusSaving;

  /// No description provided for @importStatusImported.
  ///
  /// In en, this message translates to:
  /// **'Imported'**
  String get importStatusImported;

  /// No description provided for @importStatusSkipped.
  ///
  /// In en, this message translates to:
  /// **'Already exists, skipped'**
  String get importStatusSkipped;

  /// No description provided for @importStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed'**
  String get importStatusFailed;

  /// No description provided for @importRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get importRemove;

  /// No description provided for @importRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get importRetry;

  /// No description provided for @importClearCompleted.
  ///
  /// In en, this message translates to:
  /// **'Clear completed'**
  String get importClearCompleted;

  /// No description provided for @importDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get importDone;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'{succeeded} imported · {skipped} skipped · {failed} failed'**
  String importSummary(int succeeded, int skipped, int failed);

  /// No description provided for @importNoSupportedFiles.
  ///
  /// In en, this message translates to:
  /// **'No supported book files were found'**
  String get importNoSupportedFiles;

  /// No description provided for @importScanning.
  ///
  /// In en, this message translates to:
  /// **'Scanning files…'**
  String get importScanning;
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
      <String>['en', 'ja', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+country codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.countryCode) {
          case 'TW':
            return AppLocalizationsZhTw();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
