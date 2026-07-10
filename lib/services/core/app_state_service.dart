// 文件说明：应用状态服务，记录最近阅读、当前书籍和全局运行状态。
// 技术要点：服务层、Flutter。

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:xxread/services/core/data_cache_service.dart';

/// 应用状态管理服务
///
/// 负责管理应用的完整状态，包括用户设置、阅读状态、
/// UI状态、书签、笔记等，确保应用退出重启后能够
/// 完整恢复用户的使用状态
///
/// 核心功能：
/// - 应用状态持久化
/// - 状态自动恢复
/// - 状态变更监听
/// - 状态版本管理
class AppStateService {
  static final AppStateService _instance = AppStateService._internal();
  factory AppStateService() => _instance;
  AppStateService._internal();

  // 依赖服务
  final DataCacheService _cacheService = DataCacheService();

  // 状态变更控制器
  final StreamController<AppStateEvent> _stateEventController =
      StreamController<AppStateEvent>.broadcast();
  Stream<AppStateEvent> get stateEventStream => _stateEventController.stream;

  // 应用状态数据
  AppStateData? _currentState;
  bool _isInitialized = false;

  // 状态保存定时器
  Timer? _stateSaveTimer;
  final Set<String> _changedSections = {};

  // 配置参数
  static const Duration _stateSaveInterval = Duration(seconds: 15);
  static const String _stateKey = 'app_state_v2';
  static const int _currentStateVersion = 2;

  /// 获取当前应用状态
  AppStateData get currentState => _currentState ?? AppStateData.empty();

  /// 检查服务是否已初始化
  bool get isInitialized => _isInitialized;

  /// 初始化应用状态服务
  Future<void> initialize() async {
    debugPrint('🚀 初始化应用状态服务');

    try {
      // 恢复应用状态
      await _restoreAppState();

      // 启动状态保存定时器
      _startStateSaveTimer();

      _isInitialized = true;
      _emitStateEvent(AppStateEvent.initialized(_currentState!));

      debugPrint('✅ 应用状态服务初始化成功');
    } catch (e) {
      debugPrint('❌ 应用状态服务初始化失败: $e');

      // 创建默认状态
      _currentState = AppStateData.empty();
      _isInitialized = true;
      _emitStateEvent(AppStateEvent.initialized(_currentState!));

      rethrow;
    }
  }

  /// 销毁应用状态服务
  Future<void> dispose() async {
    debugPrint('🛑 销毁应用状态服务');

    try {
      // 停止定时器
      _stateSaveTimer?.cancel();

      // 保存当前状态
      await _saveAppState();

      // 关闭状态事件流
      await _stateEventController.close();

      // 清理数据
      _currentState = null;
      _isInitialized = false;
      _changedSections.clear();

      debugPrint('✅ 应用状态服务销毁完成');
    } catch (e) {
      debugPrint('❌ 应用状态服务销毁失败: $e');
    }
  }

  /// 更新阅读状态
  ///
  /// [readingState] 新的阅读状态
  Future<void> updateReadingState(ReadingState readingState) async {
    if (!_isInitialized) return;

    try {
      final oldState = _currentState!;
      _currentState = oldState.copyWith(readingState: readingState);
      _changedSections.add('reading');

      _emitStateEvent(AppStateEvent.readingStateChanged(readingState));
      debugPrint(
        '📖 更新阅读状态: ${readingState.currentBookId != null ? "书籍[${readingState.currentBookId}]" : "无书籍"}',
      );
    } catch (e) {
      debugPrint('❌ 更新阅读状态失败: $e');
    }
  }

  /// 更新用户设置
  ///
  /// [userSettings] 新的用户设置
  Future<void> updateUserSettings(UserSettings userSettings) async {
    if (!_isInitialized) return;

    try {
      final oldState = _currentState!;
      _currentState = oldState.copyWith(userSettings: userSettings);
      _changedSections.add('settings');

      _emitStateEvent(AppStateEvent.userSettingsChanged(userSettings));
      debugPrint('⚙️ 更新用户设置');
    } catch (e) {
      debugPrint('❌ 更新用户设置失败: $e');
    }
  }

  /// 更新UI状态
  ///
  /// [uiState] 新的UI状态
  Future<void> updateUIState(UIState uiState) async {
    if (!_isInitialized) return;

    try {
      final oldState = _currentState!;
      _currentState = oldState.copyWith(uiState: uiState);
      _changedSections.add('ui');

      _emitStateEvent(AppStateEvent.uiStateChanged(uiState));
      debugPrint('🎨 更新UI状态');
    } catch (e) {
      debugPrint('❌ 更新UI状态失败: $e');
    }
  }

  /// 更新应用运行时信息
  ///
  /// [appInfo] 新的应用信息
  Future<void> updateAppInfo(AppInfo appInfo) async {
    if (!_isInitialized) return;

    try {
      final oldState = _currentState!;
      _currentState = oldState.copyWith(appInfo: appInfo);
      _changedSections.add('app_info');

      _emitStateEvent(AppStateEvent.appInfoChanged(appInfo));
      debugPrint('ℹ️ 更新应用信息');
    } catch (e) {
      debugPrint('❌ 更新应用信息失败: $e');
    }
  }

  /// 添加最近阅读的书籍
  ///
  /// [bookId] 书籍ID
  /// [bookTitle] 书籍标题
  Future<void> addRecentBook(int bookId, String bookTitle) async {
    if (!_isInitialized) return;

    try {
      final oldReadingState = _currentState!.readingState;
      final recentBooks = List<RecentBook>.from(oldReadingState.recentBooks);

      // 移除已存在的同一本书
      recentBooks.removeWhere((book) => book.bookId == bookId);

      // 添加到列表开头
      recentBooks.insert(
        0,
        RecentBook(
          bookId: bookId,
          title: bookTitle,
          lastReadTime: DateTime.now(),
        ),
      );

      // 保持最近10本书
      if (recentBooks.length > 10) {
        recentBooks.removeRange(10, recentBooks.length);
      }

      final newReadingState = oldReadingState.copyWith(
        recentBooks: recentBooks,
      );
      await updateReadingState(newReadingState);

      debugPrint('📚 添加最近阅读: $bookTitle');
    } catch (e) {
      debugPrint('❌ 添加最近阅读失败: $e');
    }
  }

  /// 设置当前阅读的书籍
  ///
  /// [bookId] 书籍ID
  /// [bookTitle] 书籍标题
  /// [currentPage] 当前页数
  Future<void> setCurrentBook(
    int bookId,
    String bookTitle,
    int currentPage,
  ) async {
    if (!_isInitialized) return;

    try {
      final oldReadingState = _currentState!.readingState;
      final newReadingState = oldReadingState.copyWith(
        currentBookId: bookId,
        currentBookTitle: bookTitle,
        currentPage: currentPage,
        lastReadTime: DateTime.now(),
      );

      await updateReadingState(newReadingState);
      await addRecentBook(bookId, bookTitle);

      debugPrint('📖 设置当前书籍: $bookTitle (页面 $currentPage)');
    } catch (e) {
      debugPrint('❌ 设置当前书籍失败: $e');
    }
  }

  /// 清除当前阅读的书籍
  Future<void> clearCurrentBook() async {
    if (!_isInitialized) return;

    try {
      final oldReadingState = _currentState!.readingState;
      final newReadingState = oldReadingState.copyWith(
        currentBookId: null,
        currentBookTitle: null,
        currentPage: null,
      );

      await updateReadingState(newReadingState);
      debugPrint('📖 清除当前书籍');
    } catch (e) {
      debugPrint('❌ 清除当前书籍失败: $e');
    }
  }

  /// 更新阅读统计
  ///
  /// [dailyReadingMinutes] 今日阅读分钟数
  /// [totalReadingMinutes] 总阅读分钟数
  Future<void> updateReadingStats(
    int dailyReadingMinutes,
    int totalReadingMinutes,
  ) async {
    if (!_isInitialized) return;

    try {
      final oldReadingState = _currentState!.readingState;
      final newReadingState = oldReadingState.copyWith(
        dailyReadingMinutes: dailyReadingMinutes,
        totalReadingMinutes: totalReadingMinutes,
      );

      await updateReadingState(newReadingState);
      debugPrint(
        '📊 更新阅读统计: 今日$dailyReadingMinutes分钟, 总计$totalReadingMinutes分钟',
      );
    } catch (e) {
      debugPrint('❌ 更新阅读统计失败: $e');
    }
  }

  /// 强制保存当前状态
  Future<void> forceSave() async {
    debugPrint('💾 强制保存应用状态');

    try {
      await _saveAppState();
      debugPrint('✅ 强制保存完成');
    } catch (e) {
      debugPrint('❌ 强制保存失败: $e');
      rethrow;
    }
  }

  /// 获取状态摘要信息
  Map<String, dynamic> getStateSummary() {
    if (!_isInitialized || _currentState == null) {
      return {'status': 'not_initialized'};
    }

    final state = _currentState!;
    return {
      'status': 'initialized',
      'state_version': state.version,
      'last_updated': state.lastUpdated.toIso8601String(),
      'current_book_id': state.readingState.currentBookId,
      'current_book_title': state.readingState.currentBookTitle,
      'current_page': state.readingState.currentPage,
      'recent_books_count': state.readingState.recentBooks.length,
      'daily_reading_minutes': state.readingState.dailyReadingMinutes,
      'total_reading_minutes': state.readingState.totalReadingMinutes,
      'theme_mode': state.userSettings.themeMode,
      'changed_sections': _changedSections.toList(),
    };
  }

  /// 启动状态保存定时器
  void _startStateSaveTimer() {
    _stateSaveTimer?.cancel();
    _stateSaveTimer = Timer.periodic(_stateSaveInterval, (timer) async {
      if (_changedSections.isNotEmpty) {
        debugPrint('⏰ 状态保存定时器触发，变更部分: $_changedSections');
        try {
          await _saveAppState();
        } catch (e) {
          debugPrint('❌ 定时保存状态失败: $e');
        }
      }
    });
    debugPrint('⏰ 状态保存定时器已启动，间隔: ${_stateSaveInterval.inSeconds}秒');
  }

  /// 恢复应用状态
  Future<void> _restoreAppState() async {
    debugPrint('🔄 恢复应用状态');

    try {
      final cachedStateData = _cacheService.getCache<Map<String, dynamic>>(
        _stateKey,
      );

      if (cachedStateData != null) {
        final stateData = AppStateData.fromJson(cachedStateData);

        // 验证状态版本
        if (stateData.version < _currentStateVersion) {
          debugPrint(
            '⚠️ 状态版本过旧，执行迁移: ${stateData.version} -> $_currentStateVersion',
          );
          _currentState = await _migrateState(stateData);
        } else {
          _currentState = stateData;
        }

        debugPrint('✅ 应用状态恢复成功: 版本${_currentState!.version}');
      } else {
        // 创建新的默认状态
        _currentState = AppStateData.empty();
        debugPrint('✅ 创建默认应用状态');
      }
    } catch (e) {
      debugPrint('❌ 恢复应用状态失败: $e');
      _currentState = AppStateData.empty();
    }
  }

  /// 保存应用状态
  Future<void> _saveAppState() async {
    if (_currentState == null) return;

    try {
      // 更新时间戳
      _currentState = _currentState!.copyWith(lastUpdated: DateTime.now());

      // 保存到缓存
      await _cacheService.setCache(
        _stateKey,
        _currentState!.toJson(),
        persistImmediately: true,
      );

      // 清理变更标记
      _changedSections.clear();

      debugPrint('💾 应用状态已保存');
    } catch (e) {
      debugPrint('❌ 保存应用状态失败: $e');
      rethrow;
    }
  }

  /// 迁移旧版本状态
  Future<AppStateData> _migrateState(AppStateData oldState) async {
    // 在这里实现状态迁移逻辑
    // 目前只是简单地更新版本号
    return oldState.copyWith(version: _currentStateVersion);
  }

  /// 发射状态事件
  void _emitStateEvent(AppStateEvent event) {
    if (!_stateEventController.isClosed) {
      _stateEventController.add(event);
    }
  }
}

/// 应用状态数据模型
class AppStateData {
  final int version;
  final DateTime lastUpdated;
  final ReadingState readingState;
  final UserSettings userSettings;
  final UIState uiState;
  final AppInfo appInfo;

  const AppStateData({
    required this.version,
    required this.lastUpdated,
    required this.readingState,
    required this.userSettings,
    required this.uiState,
    required this.appInfo,
  });

  /// 创建空的默认状态
  factory AppStateData.empty() {
    final now = DateTime.now();
    return AppStateData(
      version: 2,
      lastUpdated: now,
      readingState: ReadingState.empty(),
      userSettings: UserSettings.defaults(),
      uiState: UIState.defaults(),
      appInfo: AppInfo.defaults(),
    );
  }

  /// 从JSON创建实例
  factory AppStateData.fromJson(Map<String, dynamic> json) {
    return AppStateData(
      version: json['version'] as int? ?? 1,
      lastUpdated: DateTime.parse(json['lastUpdated'] as String),
      readingState: ReadingState.fromJson(
        json['readingState'] as Map<String, dynamic>,
      ),
      userSettings: UserSettings.fromJson(
        json['userSettings'] as Map<String, dynamic>,
      ),
      uiState: UIState.fromJson(json['uiState'] as Map<String, dynamic>),
      appInfo: AppInfo.fromJson(json['appInfo'] as Map<String, dynamic>),
    );
  }

  /// 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'lastUpdated': lastUpdated.toIso8601String(),
      'readingState': readingState.toJson(),
      'userSettings': userSettings.toJson(),
      'uiState': uiState.toJson(),
      'appInfo': appInfo.toJson(),
    };
  }

  /// 创建副本
  AppStateData copyWith({
    int? version,
    DateTime? lastUpdated,
    ReadingState? readingState,
    UserSettings? userSettings,
    UIState? uiState,
    AppInfo? appInfo,
  }) {
    return AppStateData(
      version: version ?? this.version,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      readingState: readingState ?? this.readingState,
      userSettings: userSettings ?? this.userSettings,
      uiState: uiState ?? this.uiState,
      appInfo: appInfo ?? this.appInfo,
    );
  }
}

/// 阅读状态模型
class ReadingState {
  final int? currentBookId;
  final String? currentBookTitle;
  final int? currentPage;
  final DateTime? lastReadTime;
  final List<RecentBook> recentBooks;
  final int dailyReadingMinutes;
  final int totalReadingMinutes;

  const ReadingState({
    this.currentBookId,
    this.currentBookTitle,
    this.currentPage,
    this.lastReadTime,
    required this.recentBooks,
    required this.dailyReadingMinutes,
    required this.totalReadingMinutes,
  });

  factory ReadingState.empty() {
    return const ReadingState(
      recentBooks: [],
      dailyReadingMinutes: 0,
      totalReadingMinutes: 0,
    );
  }

  factory ReadingState.fromJson(Map<String, dynamic> json) {
    return ReadingState(
      currentBookId: json['currentBookId'] as int?,
      currentBookTitle: json['currentBookTitle'] as String?,
      currentPage: json['currentPage'] as int?,
      lastReadTime: json['lastReadTime'] != null
          ? DateTime.parse(json['lastReadTime'] as String)
          : null,
      recentBooks: (json['recentBooks'] as List<dynamic>?)
              ?.map((item) => RecentBook.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      dailyReadingMinutes: json['dailyReadingMinutes'] as int? ?? 0,
      totalReadingMinutes: json['totalReadingMinutes'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'currentBookId': currentBookId,
      'currentBookTitle': currentBookTitle,
      'currentPage': currentPage,
      'lastReadTime': lastReadTime?.toIso8601String(),
      'recentBooks': recentBooks.map((book) => book.toJson()).toList(),
      'dailyReadingMinutes': dailyReadingMinutes,
      'totalReadingMinutes': totalReadingMinutes,
    };
  }

  ReadingState copyWith({
    int? currentBookId,
    String? currentBookTitle,
    int? currentPage,
    DateTime? lastReadTime,
    List<RecentBook>? recentBooks,
    int? dailyReadingMinutes,
    int? totalReadingMinutes,
  }) {
    return ReadingState(
      currentBookId: currentBookId ?? this.currentBookId,
      currentBookTitle: currentBookTitle ?? this.currentBookTitle,
      currentPage: currentPage ?? this.currentPage,
      lastReadTime: lastReadTime ?? this.lastReadTime,
      recentBooks: recentBooks ?? this.recentBooks,
      dailyReadingMinutes: dailyReadingMinutes ?? this.dailyReadingMinutes,
      totalReadingMinutes: totalReadingMinutes ?? this.totalReadingMinutes,
    );
  }
}

/// 最近阅读书籍模型
class RecentBook {
  final int bookId;
  final String title;
  final DateTime lastReadTime;

  const RecentBook({
    required this.bookId,
    required this.title,
    required this.lastReadTime,
  });

  factory RecentBook.fromJson(Map<String, dynamic> json) {
    return RecentBook(
      bookId: json['bookId'] as int,
      title: json['title'] as String,
      lastReadTime: DateTime.parse(json['lastReadTime'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'bookId': bookId,
      'title': title,
      'lastReadTime': lastReadTime.toIso8601String(),
    };
  }
}

/// 用户设置模型
class UserSettings {
  final String themeMode;
  final String language;
  final bool enableAnimations;
  final bool keepScreenOn;
  final Map<String, dynamic> readingSettings;
  final Map<String, dynamic> ttsSettings;

  const UserSettings({
    required this.themeMode,
    required this.language,
    required this.enableAnimations,
    required this.keepScreenOn,
    required this.readingSettings,
    required this.ttsSettings,
  });

  factory UserSettings.defaults() {
    return const UserSettings(
      themeMode: 'system',
      language: 'zh-CN',
      enableAnimations: true,
      keepScreenOn: false,
      readingSettings: {},
      ttsSettings: {},
    );
  }

  factory UserSettings.fromJson(Map<String, dynamic> json) {
    return UserSettings(
      themeMode: json['themeMode'] as String? ?? 'system',
      language: json['language'] as String? ?? 'zh-CN',
      enableAnimations: json['enableAnimations'] as bool? ?? true,
      keepScreenOn: json['keepScreenOn'] as bool? ?? false,
      readingSettings: json['readingSettings'] as Map<String, dynamic>? ?? {},
      ttsSettings: json['ttsSettings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'themeMode': themeMode,
      'language': language,
      'enableAnimations': enableAnimations,
      'keepScreenOn': keepScreenOn,
      'readingSettings': readingSettings,
      'ttsSettings': ttsSettings,
    };
  }

  UserSettings copyWith({
    String? themeMode,
    String? language,
    bool? enableAnimations,
    bool? keepScreenOn,
    Map<String, dynamic>? readingSettings,
    Map<String, dynamic>? ttsSettings,
  }) {
    return UserSettings(
      themeMode: themeMode ?? this.themeMode,
      language: language ?? this.language,
      enableAnimations: enableAnimations ?? this.enableAnimations,
      keepScreenOn: keepScreenOn ?? this.keepScreenOn,
      readingSettings: readingSettings ?? this.readingSettings,
      ttsSettings: ttsSettings ?? this.ttsSettings,
    );
  }
}

/// UI状态模型
class UIState {
  final String lastVisitedPage;
  final Map<String, dynamic> pageStates;
  final List<String> openDialogs;

  const UIState({
    required this.lastVisitedPage,
    required this.pageStates,
    required this.openDialogs,
  });

  factory UIState.defaults() {
    return const UIState(
      lastVisitedPage: 'home',
      pageStates: {},
      openDialogs: [],
    );
  }

  factory UIState.fromJson(Map<String, dynamic> json) {
    return UIState(
      lastVisitedPage: json['lastVisitedPage'] as String? ?? 'home',
      pageStates: json['pageStates'] as Map<String, dynamic>? ?? {},
      openDialogs:
          (json['openDialogs'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lastVisitedPage': lastVisitedPage,
      'pageStates': pageStates,
      'openDialogs': openDialogs,
    };
  }

  UIState copyWith({
    String? lastVisitedPage,
    Map<String, dynamic>? pageStates,
    List<String>? openDialogs,
  }) {
    return UIState(
      lastVisitedPage: lastVisitedPage ?? this.lastVisitedPage,
      pageStates: pageStates ?? this.pageStates,
      openDialogs: openDialogs ?? this.openDialogs,
    );
  }
}

/// 应用信息模型
class AppInfo {
  final String version;
  final int launchCount;
  final DateTime firstLaunchTime;
  final DateTime lastLaunchTime;

  const AppInfo({
    required this.version,
    required this.launchCount,
    required this.firstLaunchTime,
    required this.lastLaunchTime,
  });

  factory AppInfo.defaults() {
    final now = DateTime.now();
    return AppInfo(
      version: '1.0.0',
      launchCount: 1,
      firstLaunchTime: now,
      lastLaunchTime: now,
    );
  }

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      version: json['version'] as String? ?? '1.0.0',
      launchCount: json['launchCount'] as int? ?? 1,
      firstLaunchTime: DateTime.parse(json['firstLaunchTime'] as String),
      lastLaunchTime: DateTime.parse(json['lastLaunchTime'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'launchCount': launchCount,
      'firstLaunchTime': firstLaunchTime.toIso8601String(),
      'lastLaunchTime': lastLaunchTime.toIso8601String(),
    };
  }

  AppInfo copyWith({
    String? version,
    int? launchCount,
    DateTime? firstLaunchTime,
    DateTime? lastLaunchTime,
  }) {
    return AppInfo(
      version: version ?? this.version,
      launchCount: launchCount ?? this.launchCount,
      firstLaunchTime: firstLaunchTime ?? this.firstLaunchTime,
      lastLaunchTime: lastLaunchTime ?? this.lastLaunchTime,
    );
  }
}

/// 应用状态事件
abstract class AppStateEvent {
  const AppStateEvent();

  factory AppStateEvent.initialized(AppStateData state) = AppStateInitialized;
  factory AppStateEvent.readingStateChanged(ReadingState state) =
      ReadingStateChanged;
  factory AppStateEvent.userSettingsChanged(UserSettings settings) =
      UserSettingsChanged;
  factory AppStateEvent.uiStateChanged(UIState state) = UIStateChanged;
  factory AppStateEvent.appInfoChanged(AppInfo info) = AppInfoChanged;
}

class AppStateInitialized extends AppStateEvent {
  final AppStateData state;
  const AppStateInitialized(this.state);
}

class ReadingStateChanged extends AppStateEvent {
  final ReadingState state;
  const ReadingStateChanged(this.state);
}

class UserSettingsChanged extends AppStateEvent {
  final UserSettings settings;
  const UserSettingsChanged(this.settings);
}

class UIStateChanged extends AppStateEvent {
  final UIState state;
  const UIStateChanged(this.state);
}

class AppInfoChanged extends AppStateEvent {
  final AppInfo info;
  const AppInfoChanged(this.info);
}
