// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'OpenReading';

  @override
  String get home => 'ホーム';

  @override
  String get library => '本棚';

  @override
  String get bookSources => 'ソース';

  @override
  String get bookSourcesSubtitle => 'オープンソースに接続し、提供元をまたいで読める本を検索';

  @override
  String get bookSourcesAdd => 'ソースを追加';

  @override
  String get bookSourcesSearchHint => '書名や著者で有効なソースを検索';

  @override
  String get bookSourcesSearch => '検索';

  @override
  String get bookSourcesSearching => 'ソースを検索中…';

  @override
  String bookSourcesFailedCount(int count) {
    return '$count 件のソースリクエストが失敗しました';
  }

  @override
  String get bookSourcesSearchPrompt => 'ソースを追加して有効化すると、ここでまとめて検索できます';

  @override
  String get bookSourcesNoResults => '該当する書籍が見つかりません';

  @override
  String get bookSourcesNoSourcesTitle => 'ソースがまだありません';

  @override
  String get bookSourcesNoSourcesDescription =>
      'Open Reading Source Protocol に対応したサービスのアドレスを貼り付けて接続します。';

  @override
  String get bookSourcesManageTitle => '接続済みのソース';

  @override
  String get bookSourcesEnabled => '有効';

  @override
  String get bookSourcesDisabled => '無効';

  @override
  String get bookSourcesRemove => '削除';

  @override
  String get bookSourcesRemoveTitle => 'ソースを削除';

  @override
  String get bookSourcesRemoveMessage => 'ソースの設定のみを削除します。ローカルの書籍には影響しません。';

  @override
  String get bookSourcesCancel => 'キャンセル';

  @override
  String get bookSourcesConfirm => '確認';

  @override
  String get bookSourcesAddTitle => 'オープンソースを追加';

  @override
  String get bookSourcesUrlLabel => 'ソースのアドレス';

  @override
  String get bookSourcesUrlHint => 'https://example.com またはディスカバリードキュメントの URL';

  @override
  String get bookSourcesConnect => '接続して検証';

  @override
  String get bookSourcesConnecting => 'プロトコルを検証中…';

  @override
  String get bookSourcesAdded => 'ソースを追加しました';

  @override
  String get bookSourcesProtocolTitle => 'Open Reading Source Protocol';

  @override
  String get bookSourcesProtocolDescription =>
      '発見・検索・書籍詳細・目次・本文取得を統一したインターフェース。開発者はネイティブソースを構築したり、正規のコンテンツサービス向けにアダプターを作成したりできます。';

  @override
  String get bookSourcesProtocolDetails => 'プロトコルを見る';

  @override
  String get bookSourcesProtocolRepository => 'プロトコルのリポジトリ';

  @override
  String get bookSourcesProtocolRepositoryOpen => 'GitHub で見る';

  @override
  String get bookSourcesProtocolRepositoryOpenFailed => 'プロトコルのリポジトリを開けませんでした';

  @override
  String get bookSourcesProtocolDialogTitle => 'オープンソースプロトコル v1';

  @override
  String get bookSourcesProtocolDialogBody =>
      'サービスは /.well-known/open-reading-source.json でディスカバリードキュメントを公開し、/v1/search、書籍詳細、章の目次、章の本文の各エンドポイントを実装します。バージョン 1 はログイン不要の公開 HTTP(S) ソースのみをサポートします。';

  @override
  String get bookSourcesClose => '閉じる';

  @override
  String bookSourcesIdentity(String sourceId, String bookId) {
    return 'ソース ID：$sourceId\n書籍 ID：$bookId';
  }

  @override
  String get settings => '設定';

  @override
  String get statistics => '統計';

  @override
  String get reading => '読書';

  @override
  String get importBooks => '書籍を追加';

  @override
  String get darkMode => 'ダークモード';

  @override
  String get lightMode => 'ライトモード';

  @override
  String get systemMode => 'システムに従う';

  @override
  String get theme => 'テーマ';

  @override
  String get accent => 'アクセントカラー';

  @override
  String get bookmarks => 'ブックマーク';

  @override
  String get notes => 'メモ';

  @override
  String get highlights => 'ハイライト';

  @override
  String get ttsReading => '読み上げ';

  @override
  String get share => '共有';

  @override
  String get shareContent => 'コンテンツを共有';

  @override
  String get shareCurrentPage => '現在のページを共有';

  @override
  String get shareSelectedText => '選択したテキストを共有';

  @override
  String get shareProgress => '読書の進捗を共有';

  @override
  String get play => '再生';

  @override
  String get pause => '一時停止';

  @override
  String get stop => '停止';

  @override
  String get speed => '速度';

  @override
  String get pitch => 'ピッチ';

  @override
  String get language => '言語';

  @override
  String get fontSize => '文字サイズ';

  @override
  String get readingProgress => '読書の進捗';

  @override
  String get totalPages => '総ページ数';

  @override
  String get currentPage => '現在のページ';

  @override
  String get readingTime => '読書時間';

  @override
  String get booksRead => '読了した本';

  @override
  String get todayReading => '今日の読書';

  @override
  String get cancel => 'キャンセル';

  @override
  String get confirm => '確認';

  @override
  String get delete => '削除';

  @override
  String get edit => '編集';

  @override
  String get save => '保存';

  @override
  String get back => '戻る';

  @override
  String get next => '次のページ';

  @override
  String get previous => '前のページ';

  @override
  String get search => '検索';

  @override
  String get noResults => '結果が見つかりません';

  @override
  String get loading => '読み込み中...';

  @override
  String get error => 'エラー';

  @override
  String get initializationFailed => '初期化に失敗しました';

  @override
  String get unknownError => '不明なエラー';

  @override
  String get retry => '再試行';

  @override
  String get appearanceSettings => '外観設定';

  @override
  String get readingTips => '読書のヒント';

  @override
  String get readingFontSettingsMoved => '読書フォント設定は読書画面に移動しました';

  @override
  String get readingFontSettingsHint =>
      '本を開いて画面中央をタップし、下部のツールバーの「設定」から文字サイズ・行間・字間・余白・読書フォントを調整できます。';

  @override
  String get readingSettings => '読書設定';

  @override
  String get enableTts => '読み上げを有効にする';

  @override
  String get enableTtsHint => 'テキスト読み上げをオンにします';

  @override
  String get ttsSpeedLabel => '読み上げ速度';

  @override
  String get ttsSpeedHint => '読み上げの速さを調整';

  @override
  String get ttsVolumeLabel => '読み上げ音量';

  @override
  String get ttsVolumeHint => '読み上げの音量を調整';

  @override
  String get ttsPitchLabel => 'ピッチ';

  @override
  String get ttsPitchHint => '読み上げのピッチを調整';

  @override
  String get appSettings => 'アプリ設定';

  @override
  String get appFont => 'アプリのフォント';

  @override
  String get fontSystem => 'システム標準';

  @override
  String get fontSourceHanSans => '源ノ角ゴシック';

  @override
  String get fontJetBrainsMono => 'JetBrains Mono';

  @override
  String get languageSystem => 'システムに従う';

  @override
  String get languageChinese => '简体中文';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageTraditionalChinese => '繁體中文';

  @override
  String get typographySettings => '組版設定';

  @override
  String get fontFamilyLabel => 'フォント';

  @override
  String get fontSizeLabel => '文字サイズ';

  @override
  String get lineSpacingLabel => '行間';

  @override
  String get letterSpacingLabel => '字間';

  @override
  String get firstLineIndentLabel => '字下げ';

  @override
  String get pageMarginLabel => 'ページ余白';

  @override
  String get resetDefault => '初期値に戻す';

  @override
  String get ttsPanelTitle => '読み上げ';

  @override
  String get ttsPreviewEffect => 'プレビュー';

  @override
  String get ttsVolume => '音量';

  @override
  String get ttsPitch => 'ピッチ';

  @override
  String get ttsSpeed => '速度';

  @override
  String get ttsPreviousSentence => '前の文';

  @override
  String get ttsNextSentence => '次の文';

  @override
  String get ttsTimerStop => 'タイマー停止';

  @override
  String get ttsTimerOff => '制限なし';

  @override
  String ttsTimerMinutes(Object minutes) {
    return '$minutes 分後に停止';
  }

  @override
  String get ttsPlaying => '再生中';

  @override
  String get ttsPaused => '一時停止中';

  @override
  String get ttsStopped => '停止しました';

  @override
  String get ttsPreviousSentenceFailed => '前の文の再生に失敗しました';

  @override
  String get ttsNextSentenceFailed => '次の文の再生に失敗しました';

  @override
  String get ttsEmptyContentError => '現在のページに内容がありません';

  @override
  String get ttsPlaybackFailed => '再生に失敗しました';

  @override
  String get ttsOperationFailed => '操作に失敗しました';

  @override
  String get pageTurningMode => 'ページめくり';

  @override
  String get pageTurningSlide => '左右スワイプ';

  @override
  String get pageTurningScroll => '縦スクロール';

  @override
  String get tapZoneSettings => 'タップ領域';

  @override
  String get tapZoneNextPage => '次のページ';

  @override
  String get tapZonePreviousPage => '前のページ';

  @override
  String get tapZoneMenu => 'メニュー';

  @override
  String get tapZoneLegend => '凡例';

  @override
  String get highlightColor => 'マーカーの色';

  @override
  String get highlightPreview => 'プレビュー';

  @override
  String get highlightSampleText => 'これはサンプルテキストです。';

  @override
  String get highlightSampleText2 => 'この部分がハイライトされ、';

  @override
  String get highlightSampleText3 => 'マーカーの効果を確認できます。';

  @override
  String get colorLightBlue => 'ライトブルー';

  @override
  String get colorRed => 'レッド';

  @override
  String get colorGreen => 'グリーン';

  @override
  String get colorPurple => 'パープル';

  @override
  String get colorGold => 'ゴールド';

  @override
  String get colorOrange => 'オレンジ';

  @override
  String get colorYellow => 'イエロー';

  @override
  String get colorDarkGreen => 'ダークグリーン';

  @override
  String get colorCustom => 'カスタム';

  @override
  String get noteTypeHighlight => 'ハイライト';

  @override
  String get noteTypeUnderline => '下線';

  @override
  String get noteTypeNote => 'メモ';

  @override
  String get noteTypeUnknown => '不明';

  @override
  String get bookFormatTXT => 'TXT';

  @override
  String get bookFormatEPUB => 'EPUB';

  @override
  String get bookFormatPDF => 'PDF';

  @override
  String get importBook => '書籍を追加';

  @override
  String get importFromFiles => 'ファイルから追加';

  @override
  String get importNoBooks => 'まだ書籍が追加されていません';

  @override
  String get importSuccess => '書籍を追加しました';

  @override
  String get importFailed => '追加に失敗しました';

  @override
  String get importProcessing => '書籍を処理中...';

  @override
  String get author => '著者';

  @override
  String get progress => '進捗';

  @override
  String get continueReading => '続きを読む';

  @override
  String get recentBooks => '最近の読書';

  @override
  String get allBooks => 'すべての本';

  @override
  String get emptyLibrary => '本棚は空です';

  @override
  String get deleteBook => '書籍を削除';

  @override
  String get deleteBookConfirm => 'この本を削除してもよろしいですか？';

  @override
  String get bookDeleted => '書籍を削除しました';

  @override
  String get userAgreement => '利用規約';

  @override
  String get acceptAgreement => '読んだうえで同意します';

  @override
  String get declineAgreement => '同意しない';

  @override
  String get statsToday => '今日';

  @override
  String get statsThisWeek => '今週';

  @override
  String get statsTotal => '合計';

  @override
  String statsMinutes(Object minutes) {
    return '$minutes 分';
  }

  @override
  String statsHours(Object hours) {
    return '$hours 時間';
  }

  @override
  String statsBooks(Object count) {
    return '$count 冊';
  }

  @override
  String get statsConsecutiveDays => '連続読書';

  @override
  String get statsFocusTime => '集中時間';

  @override
  String get statsThisWeekTotal => '今週の合計';

  @override
  String get statsKeepReading => '毎日の読書を続けよう';

  @override
  String get statsMaxSession => '最長セッション';

  @override
  String get statsWeeklyTrend => '週間の読書傾向';

  @override
  String get statsAchievements => '読書の実績';

  @override
  String get readerToolbarMenu => 'メニュー';

  @override
  String get readerToolbarTOC => '目次';

  @override
  String get readerToolbarSettings => '設定';

  @override
  String get readerAddBookmark => 'ブックマークを追加';

  @override
  String get readerAddNote => 'メモを追加';

  @override
  String get readerShare => '共有';

  @override
  String get bookmarkAdded => 'ブックマークを追加しました';

  @override
  String get bookmarkRemoved => 'ブックマークを削除しました';

  @override
  String get themeBlue => 'オーシャンブルー';

  @override
  String get themePurple => 'ミスティックパープル';

  @override
  String get themeGreen => 'フォレストグリーン';

  @override
  String get themeOrange => 'ビビッドオレンジ';

  @override
  String get themeRed => 'パッションレッド';

  @override
  String get themeCustom => 'カスタム';

  @override
  String get tapZoneLeftRight => '左／右';

  @override
  String get tapZoneLeftCenterRight => '左／中央／右';

  @override
  String get homeTagline => '美しく読む';

  @override
  String get homeReadingStatsTitle => '読書統計';

  @override
  String get homeTodayReadingMoment => '今日の読書時間';

  @override
  String homeReadMinutesKeepGoing(int minutes) {
    return '$minutes 分読みました。この調子で続けましょう';
  }

  @override
  String get homeTodayReadingJourneyStart => '今日の読書を始めましょう';

  @override
  String get homeTodayReadingKeepRhythm => '今日の読書は順調です。リズムを保ちましょう';

  @override
  String get homeTodayReadingPrompt => '今日も読書の時間をつくりましょう';

  @override
  String homeTotalReadingHours(String hours) {
    return '累計 $hours 時間読書';
  }

  @override
  String get homeWeeklyReading => '今週の読書';

  @override
  String get homeTotalReading => '累計読書';

  @override
  String get homeLibraryCount => '本棚の蔵書';

  @override
  String get homeCollectionCount => '蔵書';

  @override
  String get homeKeyMetrics => '主要な指標';

  @override
  String get homeReadingRhythm => '読書のリズム';

  @override
  String get homeAchievements => '読書の実績';

  @override
  String get homeConsecutiveReading => '連続読書';

  @override
  String get homeConsecutiveReadingDesc => '毎日の読書習慣を保つ';

  @override
  String get homeFocusDuration => '集中時間';

  @override
  String get homeFocusDurationDesc => '1 回の最長読書時間';

  @override
  String get homeWeeklyTotal => '今週の合計';

  @override
  String get homeWeeklyTotalDesc => '今週の読書時間';

  @override
  String get homeRecentReading => '最近の読書';

  @override
  String get homeWeeklyTrend => '今週の読書傾向';

  @override
  String homeBarTooltipMinutes(int minutes) {
    return '$minutes 分';
  }

  @override
  String get unitMinute => '分';

  @override
  String get unitHour => '時間';

  @override
  String get unitBook => '冊';

  @override
  String get unitDay => '日';

  @override
  String get weekdayMonShort => '月';

  @override
  String get weekdayTueShort => '火';

  @override
  String get weekdayWedShort => '水';

  @override
  String get weekdayThuShort => '木';

  @override
  String get weekdayFriShort => '金';

  @override
  String get weekdaySatShort => '土';

  @override
  String get weekdaySunShort => '日';

  @override
  String get agreementTagline => '没入型読書 · AI アシスタント · ローカルファースト';

  @override
  String get agreementCardTitle => '利用規約';

  @override
  String get agreementCardSubtitle => '以下の内容をよくお読みください';

  @override
  String get agreementWelcomeTitle => 'OpenReading へようこそ';

  @override
  String get agreementWelcomeBody => '安定した読書体験を提供するため、まず以下の規約をお読みのうえ同意してください。';

  @override
  String get agreementFeatureFormatsTitle => '多形式対応';

  @override
  String get agreementFeatureFormatsBody => 'EPUB、PDF、TXT、MOBI などに対応';

  @override
  String get agreementFeatureCustomizationTitle => 'パーソナライズ';

  @override
  String get agreementFeatureCustomizationBody => 'フォント・色・組版など読書体験を自由にカスタマイズ';

  @override
  String get agreementFeatureSyncTitle => 'ローカルファースト';

  @override
  String get agreementFeatureSyncBody => '書籍・進捗・メモはお使いの端末に保存され、あなたが管理します';

  @override
  String get agreementFeatureTtsTitle => '読み上げ（TTS）';

  @override
  String get agreementFeatureTtsBody => 'スマートな音声読み上げで目を休めながら本を楽しめます';

  @override
  String get agreementTapToAgreeHint =>
      '「同意して続ける」をタップすると、規約を読み、本アプリの利用に同意したものとみなされます';

  @override
  String get agreementExitApp => 'アプリを終了';

  @override
  String get agreementAgreeAndContinue => '同意して続ける';

  @override
  String get agreementExitDialogContent =>
      '利用規約に同意しない場合、本アプリはご利用いただけません。終了してもよろしいですか？';

  @override
  String get agreementConfirmExit => '終了する';

  @override
  String get readerFileMissing => '書籍ファイルが見つかりません。再度追加してください。';

  @override
  String get readerUnsupportedFormat => 'ネイティブリーダーは現在 EPUB と TXT のみ対応しています';

  @override
  String get bootstrapDataServiceFailed => 'データシステムの初期化に失敗しました';

  @override
  String get bootstrapImageManagerFailed => '画像マネージャーの初期化に失敗しました';

  @override
  String homeFocusCompleted(int minutes) {
    return '$minutes 分の集中セッションが完了しました。おつかれさまです！';
  }

  @override
  String get homeDailyReadingGoal => '1 日の読書目標';

  @override
  String get homeAiAdviceSection => 'AI 読書アドバイス';

  @override
  String get homeTodayGlance => '今日のまとめ';

  @override
  String get homeTodayReadingPlan => '今日の読書プラン';

  @override
  String get homeViewAll => 'すべて見る';

  @override
  String get homeSyncingReadingPlan => '読書プランを同期しています';

  @override
  String get homeGoalDoneSuggestReview => '今日の目標を達成しました。読書のふり返りはいかがですか';

  @override
  String homeRemainingToGoal(int minutes) {
    return '今日の目標まであと $minutes 分';
  }

  @override
  String get homePickBookHint => '本棚から続きを読みたい本を選び、まず 1 回の集中セッションを完了しましょう。';

  @override
  String homeContinueBookHint(String title) {
    return 'まず『$title』を読み進めてから、ほかの本に切り替えましょう。';
  }

  @override
  String get homeTodayActionAdvice => '今日のアクション';

  @override
  String homeProgressPercent(int percent) {
    return '進捗 $percent%';
  }

  @override
  String homeStreakDays(int days) {
    return '$days 日連続';
  }

  @override
  String homeWeekMinutes(int minutes) {
    return '今週 $minutes 分';
  }

  @override
  String get homePlanLoading => 'プランを読み込み中';

  @override
  String homeGoalMinutesPerDay(int minutes) {
    return '目標 $minutes 分／日';
  }

  @override
  String get homeAiAdviceForYou => 'あなたへの AI 読書アドバイス';

  @override
  String homeBasedOnBook(String title) {
    return '『$title』に基づく';
  }

  @override
  String get homeTodayReadingMinutesLabel => '今日の読書（分）';

  @override
  String get homeTotalReadingMinutesLabel => '累計読書（分）';

  @override
  String get homeGeneratingPlan => '今日の読書プランを作成中...';

  @override
  String get homeCompletedLabel => '達成';

  @override
  String get homeTodayGoalAchieved => '今日の目標を達成しました';

  @override
  String homeMinutesRemaining(int minutes) {
    return 'あと $minutes 分';
  }

  @override
  String homeReadOfGoalMinutes(int read, int goal) {
    return '$read / $goal 分読了';
  }

  @override
  String homeSessionsToFinishGoal(int sessions) {
    return 'あと約 $sessions 回の集中で今日の目標を達成できます';
  }

  @override
  String get homeStreakLabel => '連続';

  @override
  String get homeWeekAchievedLabel => '週間達成';

  @override
  String get homeFocusLabel => '集中';

  @override
  String homeDaysCount(int days) {
    return '$days日';
  }

  @override
  String homeTimesCount(int times) {
    return '$times回';
  }

  @override
  String homeFocusCountdown(String time) {
    return '集中カウントダウン $time';
  }

  @override
  String get homeGoLibraryRead => '本棚から読む';

  @override
  String get homeEndFocus => '集中を終了';

  @override
  String homeFocusMinutesButton(int minutes) {
    return '$minutes 分集中する';
  }

  @override
  String homeAdjustGoalMinutes(int minutes) {
    return '目標を調整：$minutes 分';
  }

  @override
  String get homeNoRecentReading => '最近の読書記録はありません。本棚から本を開いて読書を始めましょう。';

  @override
  String homeReadingProgressPercent(String percent) {
    return '読書進捗 $percent%';
  }

  @override
  String get librarySearchHint => '書名・著者を検索';

  @override
  String libraryFilterAll(int count) {
    return 'すべて $count';
  }

  @override
  String libraryFilterReading(int count) {
    return '読書中 $count';
  }

  @override
  String libraryFilterFinished(int count) {
    return '読了 $count';
  }

  @override
  String get libraryNoMatchingBooks => '該当する本がありません';

  @override
  String get libraryNoReadingBooks => '読書中の本はありません';

  @override
  String get libraryNoFinishedBooks => '読了した本はありません';

  @override
  String get libraryNoBooks => '本がまだありません';

  @override
  String libraryProgressContinue(int percent) {
    return '$percent% · 続きを読む';
  }

  @override
  String libraryPageNumber(int page) {
    return '$page ページ';
  }

  @override
  String get libraryStartFromBeginning => '最初から読む';

  @override
  String get libraryBookInfo => '書籍情報';

  @override
  String libraryFormatAndPages(String format, int pages) {
    return '$format · $pages ページ';
  }

  @override
  String get libraryDeleteBookHint => 'この本は完全に削除されます';

  @override
  String get libraryBookTitle => '書名';

  @override
  String get libraryFormat => '形式';

  @override
  String libraryPagesCount(int pages) {
    return '$pages ページ';
  }

  @override
  String get libraryClose => '閉じる';

  @override
  String get libraryConfirmDeleteTitle => '削除の確認';

  @override
  String libraryDeleteBookMessage(String title) {
    return '『$title』を削除しますか？ファイルは端末から完全に削除されます。';
  }

  @override
  String libraryDeletingBook(String title) {
    return '『$title』を削除中...';
  }

  @override
  String libraryBookDeletedToast(String title) {
    return '『$title』を削除しました';
  }

  @override
  String libraryDeleteFailed(String error) {
    return '削除に失敗しました：$error';
  }

  @override
  String get libraryReadingBadge => '読書中';

  @override
  String get libraryDeletingBookFile => '書籍ファイルを削除中...';

  @override
  String get libraryDeletingCoverImage => 'カバー画像を削除中...';

  @override
  String get libraryCleaningDatabase => 'データベースの記録を整理中...';

  @override
  String get libraryDeleteComplete => '削除が完了しました';

  @override
  String get readerPrefaceTitle => '前付';

  @override
  String get readerModeHorizontalPage => '横めくり';

  @override
  String get readerModeVerticalScrollHint => '本文は縦スクロール、左右スワイプで章を切り替え';

  @override
  String get readerModeWholeBookScrollHint => '本全体を最初から最後まで連続して縦にスクロール';

  @override
  String get readerScrollByChapterTitle => '章ごとにスクロール';

  @override
  String get readerScrollByChapterOnHint => '章内は縦スクロール、左右スワイプで章を切り替え';

  @override
  String get readerScrollByChapterOffHint => '全章をひとつの連続した縦の流れとして表示';

  @override
  String get readerModeHorizontalPageHint => '左側タップで前のページ、右側タップで次のページ';

  @override
  String get readerModeHorizontalSlideHint => 'ページが指に追従して横に動き、離すと吸着します';

  @override
  String readerFontSizeValue(int size) {
    return '文字サイズ  $size';
  }

  @override
  String readerHorizontalMarginValue(int margin) {
    return '左右余白  $margin';
  }

  @override
  String readerVerticalMarginValue(int margin) {
    return '上下余白  $margin';
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
    return '開けませんでした：$error';
  }

  @override
  String get readerNoContent => 'この本には表示できる本文がありません';

  @override
  String readerStatusPaged(
      int chapter, int chapterCount, int page, int pageCount) {
    return '第 $chapter/$chapterCount 章 · $page/$pageCount ページ';
  }

  @override
  String readerStatusScroll(int chapter, int chapterCount) {
    return '第 $chapter/$chapterCount 章 · 縦スクロール';
  }

  @override
  String get importPreparing => 'インポートを準備中...';

  @override
  String importFailedWithError(String error) {
    return '追加に失敗しました：$error';
  }

  @override
  String get importLocalFile => 'ローカルファイル';

  @override
  String get settingsAiTempHintMinimax =>
      'Temperature：MiniMax の推奨は 0.01 ~ 1.00';

  @override
  String get settingsAiCustomConfigTitle => 'カスタム AI 設定';

  @override
  String settingsAiCurrentProvider(String provider) {
    return '現在のプロバイダー：$provider';
  }

  @override
  String get settingsAiTempErrorMinimax =>
      'MiniMax の Temperature は 0.01 ~ 1.00 の範囲で指定してください';

  @override
  String get settingsAiTempErrorOutOfRange =>
      'Temperature が範囲外です。ヒントに従って入力してください';

  @override
  String get settingsApply => '適用';

  @override
  String get settingsAiCustomApplied => 'カスタムパラメーターを適用しました。設定の保存を忘れずに';

  @override
  String get settingsAiApiKeyRequired => 'API Key を入力してください';

  @override
  String get settingsAiModelRequired => 'Model を入力してください';

  @override
  String get settingsAiBaseUrlInvalid =>
      'Base URL は有効な http/https アドレスである必要があります';

  @override
  String get settingsAiSettingsSaved => 'AI 設定を保存しました';

  @override
  String settingsSaveFailed(String error) {
    return '保存に失敗しました：$error';
  }

  @override
  String get settingsVolumeKeyTurnTitle => '音量キーでページめくり';

  @override
  String get settingsVolumeKeyTurnSubtitle => '音量キーでページをめくります';

  @override
  String get settingsShowStatusBarTitle => '読書中にステータスバーを表示';

  @override
  String get settingsShowStatusBarOnSubtitle => 'リーダーの電池／時刻表示は非表示です';

  @override
  String get settingsShowStatusBarOffSubtitle => 'リーダーの電池／時刻表示を使用します';

  @override
  String get settingsAiAssistantTitle => 'AI 読書アシスタント';

  @override
  String get settingsSystemSettingsTitle => 'システム設定';

  @override
  String get settingsKeepScreenOnTitle => '画面を常にオン';

  @override
  String get settingsKeepScreenOnSubtitle => '読書中に画面が自動で消えないようにします';

  @override
  String get settingsAutoSaveTitle => '自動保存';

  @override
  String get settingsAutoSaveSubtitle => '読書の進捗を自動的に保存します';

  @override
  String get settingsHelpPlaceholder => 'ここにヘルプ情報を表示できます';

  @override
  String get settingsAiConfigured => 'AI 設定済み';

  @override
  String get settingsAiNotConfigured => 'API Key が未設定です';

  @override
  String get settingsAiReadyToUse => 'すぐに使えます';

  @override
  String get settingsAiPendingConfig => '設定待ち';

  @override
  String settingsAiCurrentPreset(String preset) {
    return '現在のプリセット：$preset';
  }

  @override
  String settingsAiCurrentCustom(String model) {
    return '現在の設定：カスタム · $model';
  }

  @override
  String get settingsAiPresetIntro =>
      '主要なプロバイダーとモデルを内蔵しています。通常はプリセットを選んで API Key を入力するだけです。';

  @override
  String get settingsAiProviderLabel => 'プロバイダー';

  @override
  String get settingsAiPresetHint => 'プリセットモデルを選択';

  @override
  String get settingsAiPresetLabel => 'プリセットモデル';

  @override
  String get settingsAiCustomButton => 'カスタム';

  @override
  String get settingsAiPresetSelectedHint => 'プリセットを選んだら API Key を入力するだけで使えます。';

  @override
  String get settingsAiCustomActiveHint => '現在カスタムパラメーターを使用中です。いつでもプリセットに戻せます。';

  @override
  String get settingsAiApiKeyHint => '入力すると現在のプリセットが有効になります';

  @override
  String get settingsShow => '表示';

  @override
  String get settingsHide => '非表示';

  @override
  String get settingsAiSaving => '保存中...';

  @override
  String get settingsAiSaveConfig => 'AI 設定を保存';

  @override
  String get settingsPageIntro => '読書体験に本当に影響する項目だけを残しています。';

  @override
  String get settingsAiSwipeHint => '左右にスワイプしてモデルを選び、カードをタップで切り替え。';

  @override
  String get settingsAiLegacyIntro =>
      'プロバイダーとモデルを選び、API Key を入力してください。ほかのパラメーターは既定のままで構いません。';

  @override
  String get settingsAiModelLabel => 'モデル';

  @override
  String get settingsAiUsingCustomParams => 'カスタムモデルパラメーターを使用中';

  @override
  String get settingsAiApiKeyStoredLocally => 'この端末のみに保存されます';

  @override
  String get settingsAiSaveAndEnable => '保存して有効化';

  @override
  String get settingsAboutTagline => 'オープンソース・クロスプラットフォーム・読書に集中';

  @override
  String get settingsVersionLabel => 'バージョン';

  @override
  String get settingsMaintainerLabel => 'メンテナー';

  @override
  String get settingsLicenseLabel => 'ライセンス';

  @override
  String get settingsViewSourceSubtitle => 'オープンソースプロジェクトを見る';

  @override
  String get settingsJoinQqGroup => 'QQ グループに参加';

  @override
  String get settingsQqOpenFailed => 'QQ を開けませんでした。QQ がインストールされているか確認してください。';

  @override
  String get contributorsTitle => 'コントリビューター';

  @override
  String get contributorsSubtitle => 'Open Reading をより良くしてくれるすべての人に感謝します';

  @override
  String get contributorsOpenProfileFailed => 'コントリビューターのプロフィールを開けませんでした';

  @override
  String get contributorsEmpty => '表示できるコントリビューターはまだいません';

  @override
  String get contributorsLoadFailed =>
      'コントリビューターを読み込めませんでした。ネットワークを確認して再試行してください';

  @override
  String get settingsDarkModeTitle => 'ナイトモード';

  @override
  String settingsCurrentValue(String value) {
    return '現在：$value';
  }

  @override
  String get settingsUiStyleTitle => 'ガラスエフェクト';

  @override
  String get settingsGlassEffectSubtitle => '半透明・背景ぼかし・浮遊感のあるレイヤー効果を有効にします';

  @override
  String get settingsAccentFollowTheme => 'アクセントカラー：テーマに従う';

  @override
  String settingsAccentValue(String name) {
    return 'アクセントカラー：$name';
  }

  @override
  String get settingsAppThemeTitle => 'アプリテーマ';

  @override
  String settingsCurrentThemeSummary(String theme, String accent) {
    return '現在：$theme · $accent';
  }

  @override
  String get settingsFollowAppTheme => 'アプリテーマに従う';

  @override
  String get settingsAccentColorTitle => 'アクセントカラー';

  @override
  String get settingsThemeModeSystemHint => 'システムの外観に合わせて自動で切り替え';

  @override
  String get settingsThemeModeLightHint => '常にライトモードを使用';

  @override
  String get settingsThemeModeDarkHint => '常にダークモードを使用';

  @override
  String get settingsSelectAppTheme => 'アプリテーマを選択';

  @override
  String get settingsDone => '完了';

  @override
  String get settingsAccentColorAdvice =>
      'まずアプリテーマを選び、必要に応じてアクセントカラーを上書きするのがおすすめです。';

  @override
  String get settingsAccentFollowThemeOption => 'テーマに従う';

  @override
  String get settingsAccentFollowThemeDesc => '現在のアプリテーマの既定アクセントカラーを使用';

  @override
  String get settingsAboutTitle => 'アプリについて';

  @override
  String get settingsAppName => 'Open Reading';

  @override
  String get settingsAuthor => 'メンテナー：小元Niki';

  @override
  String get settingsGithubRepo => 'GitHub リポジトリ';

  @override
  String get settingsNewYearGreeting => '集中と節度を大切にした、自由に改変できるクロスプラットフォームリーダー。';

  @override
  String get settingsGithubOpenFailed => 'GitHub のリンクを開けませんでした';

  @override
  String get settingsIosOnlyFeature => 'この機能は iOS のみ対応しています';

  @override
  String settingsIosSyncResult(String storage, int books, int files) {
    return '$storage に同期しました\n書籍 $books 冊、ファイル $files 件をコピー';
  }

  @override
  String get settingsRestartRequiredReason => 'この設定変更を完全に反映するには、アプリの再起動が必要です。';

  @override
  String get settingsRestartRequiredTitle => '再起動が必要です';

  @override
  String settingsRestartPrompt(String reason) {
    return '$reason\n\n今すぐ再起動しますか？';
  }

  @override
  String get settingsRestartLater => '後で';

  @override
  String get settingsRestartNow => '再起動';

  @override
  String get statsDetailedTitle => '詳細統計';

  @override
  String get statsRange7Days => '7日';

  @override
  String get statsRange30Days => '30日';

  @override
  String get statsRange90Days => '90日';

  @override
  String get statsRange1Year => '1年';

  @override
  String get statsRangeAll => 'すべて';

  @override
  String get statsTabOverview => '概要';

  @override
  String get statsTabCharts => 'グラフ';

  @override
  String get statsTabBooks => '書籍';

  @override
  String get statsTabAchievements => '実績';

  @override
  String get statsReadingOverview => '読書の概要';

  @override
  String statsCumulativeHours(Object hours) {
    return '累計 $hours 時間';
  }

  @override
  String statsStreakEncouragement(Object days) {
    return 'この調子で。$days 日連続で読書しています';
  }

  @override
  String get statsTotalDuration => '総時間';

  @override
  String get statsAvgSession => '平均セッション';

  @override
  String statsDaysCount(Object count) {
    return '$count 日';
  }

  @override
  String get statsNoData => 'データがありません';

  @override
  String get statsPeriodEarlyMorning => '早朝 05:00-08:59';

  @override
  String get statsPeriodMorning => '午前 09:00-11:59';

  @override
  String get statsPeriodAfternoon => '午後 12:00-17:59';

  @override
  String get statsPeriodEvening => '夜 18:00-21:59';

  @override
  String get statsPeriodLateNight => '深夜 22:00-04:59';

  @override
  String get statsTotalReadingTime => '総読書時間';

  @override
  String get statsTotalPagesRead => '総読書ページ数';

  @override
  String get statsBooksReadCount => '読んだ本の数';

  @override
  String get statsUnitPage => 'ページ';

  @override
  String get statsTodayProgress => '今日の読書進捗';

  @override
  String statsMinutesOfTarget(Object current, Object target) {
    return '$current / $target 分';
  }

  @override
  String get statsPagesRead => '読書ページ数';

  @override
  String statsPagesOfTarget(Object current, Object target) {
    return '$current / $target ページ';
  }

  @override
  String get statsReadingHabits => '読書習慣の分析';

  @override
  String get statsBestReadingPeriod => '最も読む時間帯';

  @override
  String get statsAvgSessionReading => '平均セッション時間';

  @override
  String get statsMaxStreakDays => '最長連続日数';

  @override
  String get statsFocusScore => '読書の集中度';

  @override
  String get statsBookCount => '書籍数';

  @override
  String get statsTrendAnalysis => '読書トレンド分析';

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
    return '$value冊';
  }

  @override
  String statsAxisHour(Object hour) {
    return '$hour時';
  }

  @override
  String get statsTimeDistribution => '読書時間の分布';

  @override
  String get statsFormatDistribution => '書籍形式の分布';

  @override
  String get statsCompleted => '読了';

  @override
  String get statsInProgress => '読書中';

  @override
  String get statsDurationRanking => '読書時間ランキング';

  @override
  String get statsProgressRanking => '読書進捗ランキング';

  @override
  String statsPagesCount(Object count) {
    return '$countページ';
  }

  @override
  String statsSessionCount(Object count) {
    return '$count セッション';
  }

  @override
  String statsAchievementsSummary(Object achieved, Object remaining) {
    return '$achieved 個の実績を獲得、残り $remaining 個';
  }

  @override
  String get statsAchievementFirstReadTitle => 'はじめての読書';

  @override
  String get statsAchievementFirstReadDesc => '初めての読書記録を達成';

  @override
  String get statsAchievementNoviceTitle => '読書ビギナー';

  @override
  String get statsAchievementNoviceDesc => '累計読書時間 10 時間を達成';

  @override
  String get statsAchievementBookwormTitle => '本の虫';

  @override
  String get statsAchievementBookwormDesc => '累計読書時間 100 時間を達成';

  @override
  String get statsAchievementExpertTitle => '読書の達人';

  @override
  String get statsAchievementExpertDesc => '7 日連続で読書';

  @override
  String get statsAchievementOceanTitle => '知識の海';

  @override
  String get statsAchievementOceanDesc => '読書ページ数 10,000 ページを達成';

  @override
  String get statsAchievementScholarTitle => '博識家';

  @override
  String get statsAchievementScholarDesc => '10 冊の異なる本を読む';

  @override
  String get statsAchievementMarathonTitle => '読書マラソン';

  @override
  String get statsAchievementMarathonDesc => '30 日連続で読書';

  @override
  String get statsAchievementFocusTitle => '集中の達人';

  @override
  String get statsAchievementFocusDesc => '累計読書時間 500 時間を達成';

  @override
  String statsProgressPercent(Object percent) {
    return '進捗：$percent%';
  }

  @override
  String get statsGoalProgress => '読書目標の進捗';

  @override
  String get statsMonthlyReadingTime => '今月の読書時間';

  @override
  String get statsWeeklyReadingTime => '今週の読書時間';

  @override
  String get statsAvgDailyPages7d => '直近 7 日の 1 日平均ページ数';

  @override
  String statsHoursCount(Object count) {
    return '$count時間';
  }

  @override
  String get statsSpeedTrend => '読書速度の推移';

  @override
  String statsAvgSpeed(Object speed) {
    return '平均：$speedページ/分';
  }

  @override
  String get statsReadingContinuity => '読書の継続性';

  @override
  String statsCurrentStreak(Object days) {
    return '現在の連続日数：$days日';
  }

  @override
  String get statsHeatmapLess => '少';

  @override
  String get statsHeatmapMore => '多';

  @override
  String statsWeekNumber(Object week) {
    return '第$week週';
  }
}
