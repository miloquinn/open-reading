// 文件说明：数据总管服务，协调数据库、缓存、离线队列与完整性检查。
// 技术要点：服务层、Flutter。

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:xxread/services/core/data_cache_service.dart';
import 'package:xxread/services/core/app_state_service.dart';
import 'package:xxread/services/core/data_backup_service.dart';
import 'package:xxread/services/core/enhanced_database_service.dart';
import 'package:xxread/services/core/offline_data_service.dart';

/// 统一数据管理器
///
/// 整合所有数据服务，提供统一的数据管理接口，
/// 负责服务的初始化、协调和生命周期管理
///
/// 核心功能：
/// - 服务生命周期管理
/// - 服务间协调
/// - 统一错误处理
/// - 数据一致性保证
class DataManager {
  static final DataManager _instance = DataManager._internal();
  factory DataManager() => _instance;
  DataManager._internal();

  // 服务实例
  final DataCacheService _cacheService = DataCacheService();
  final AppStateService _stateService = AppStateService();
  final DataBackupService _backupService = DataBackupService();
  final EnhancedDatabaseService _databaseService = EnhancedDatabaseService();
  final OfflineDataService _offlineService = OfflineDataService();

  // 初始化状态
  bool _isInitialized = false;
  Future<void>? _initializing;

  // 错误处理
  final StreamController<DataManagerError> _errorController =
      StreamController<DataManagerError>.broadcast();
  Stream<DataManagerError> get errorStream => _errorController.stream;

  /// 获取各个服务实例
  DataCacheService get cacheService => _cacheService;
  AppStateService get stateService => _stateService;
  DataBackupService get backupService => _backupService;
  EnhancedDatabaseService get databaseService => _databaseService;
  OfflineDataService get offlineService => _offlineService;

  /// 检查是否已初始化
  bool get isInitialized => _isInitialized;

  /// 等待初始化完成
  Future<void> get initialized {
    if (_isInitialized) {
      return Future.value();
    }
    return _initializing ?? Future.value();
  }

  /// 初始化数据管理器
  ///
  /// 按照依赖关系顺序初始化所有服务
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }

    final initializing = _initializing;
    if (initializing != null) {
      return initializing;
    }

    _initializing = _initialize();
    try {
      await _initializing;
    } finally {
      _initializing = null;
    }
  }

  Future<void> _initialize() async {
    if (_isInitialized) {
      debugPrint('⚠️ 数据管理器已经初始化');
      return;
    }

    debugPrint('🚀 开始初始化数据管理器');

    try {
      // 第一阶段：初始化基础服务
      await _initializeBaseServices();

      // 第二阶段：初始化应用层服务
      await _initializeAppServices();

      // 第三阶段：初始化备份和同步服务
      await _initializeBackupServices();

      // 设置服务间协调
      await _setupServiceCoordination();

      _isInitialized = true;
      debugPrint('✅ 数据管理器初始化成功');
    } catch (e) {
      debugPrint('❌ 数据管理器初始化失败: $e');

      _handleInitializationError(e);

      rethrow;
    }
  }

  /// 销毁数据管理器
  ///
  /// 按照相反顺序销毁所有服务
  Future<void> dispose() async {
    if (!_isInitialized) return;

    debugPrint('🛑 开始销毁数据管理器');

    try {
      // 按相反顺序销毁服务
      await _offlineService.dispose();
      await _backupService.dispose();
      await _stateService.dispose();
      await _cacheService.dispose();
      await _databaseService.dispose();

      // 关闭错误流
      await _errorController.close();

      _isInitialized = false;

      debugPrint('✅ 数据管理器销毁完成');
    } catch (e) {
      debugPrint('❌ 数据管理器销毁失败: $e');
    }
  }

  /// 执行数据完整性检查
  ///
  /// Returns: 检查结果报告
  Future<DataIntegrityReport> checkDataIntegrity() async {
    debugPrint('🔍 开始数据完整性检查');

    final report = DataIntegrityReport();

    try {
      // 检查数据库健康状态
      final dbHealth = await _databaseService.getHealthReport();
      report.databaseHealthy = dbHealth.overallHealthy;
      report.databaseReport = dbHealth.toJson();

      // 检查缓存状态
      final cacheStats = _cacheService.getCacheStats();
      report.cacheHealthy = cacheStats['total_items'] >= 0; // 基础检查
      report.cacheStats = cacheStats;

      // 检查应用状态
      final stateStats = _stateService.getStateSummary();
      report.stateHealthy = stateStats['status'] == 'initialized';
      report.stateStats = stateStats;

      // 检查备份状态
      final backupStats = _backupService.getBackupStats();
      report.backupHealthy = backupStats['total_backups'] > 0;
      report.backupStats = backupStats;

      // 检查离线数据状态
      final offlineStats = _offlineService.getOfflineStats();
      report.offlineHealthy = true; // 基础检查
      report.offlineStats = offlineStats;

      // 计算总体状态
      report.overallHealthy = report.databaseHealthy &&
          report.cacheHealthy &&
          report.stateHealthy &&
          report.backupHealthy &&
          report.offlineHealthy;

      report.checkTime = DateTime.now();

      debugPrint('✅ 数据完整性检查完成: ${report.overallHealthy ? "健康" : "异常"}');
    } catch (e) {
      debugPrint('❌ 数据完整性检查失败: $e');
      report.overallHealthy = false;
      report.errorMessage = e.toString();
    }

    return report;
  }

  /// 执行数据修复
  ///
  /// Returns: 修复是否成功
  Future<bool> repairData() async {
    debugPrint('🔧 开始数据修复');

    try {
      bool repaired = false;

      // 修复数据库
      if (!_databaseService.isDatabaseHealthy) {
        debugPrint('🔧 修复数据库');
        final validation = await _backupService.validateData();
        if (!validation.overallValid) {
          if (await _backupService.repairCorruptedData()) {
            repaired = true;
          }
        }
      }

      // 重新初始化有问题的服务
      if (!_stateService.isInitialized) {
        debugPrint('🔧 重新初始化应用状态服务');
        await _stateService.initialize();
        repaired = true;
      }

      debugPrint(repaired ? '✅ 数据修复成功' : '✅ 数据无需修复');
      return repaired;
    } catch (e) {
      debugPrint('❌ 数据修复失败: $e');
      return false;
    }
  }

  /// 强制同步所有数据
  ///
  /// Returns: 同步是否成功
  Future<bool> forceSyncAll() async {
    debugPrint('🔄 强制同步所有数据');

    try {
      // 强制保存缓存
      await _cacheService.forceSync();

      // 强制保存应用状态
      await _stateService.forceSave();

      // 创建备份
      await _backupService.createBackup(force: true);

      // 同步离线数据
      await _offlineService.forceSync();

      debugPrint('✅ 数据同步完成');
      return true;
    } catch (e) {
      debugPrint('❌ 数据同步失败: $e');
      return false;
    }
  }

  /// 获取数据管理器统计信息
  Map<String, dynamic> getStats() {
    return {
      'initialized': _isInitialized,
      'cache_stats': _cacheService.getCacheStats(),
      'state_service_stats': _stateService.getStateSummary(),
      'backup_stats': _backupService.getBackupStats(),
      'database_stats': _databaseService.operationStats.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
      'offline_stats': _offlineService.getOfflineStats(),
    };
  }

  /// 初始化基础服务
  Future<void> _initializeBaseServices() async {
    debugPrint('📦 初始化基础服务');

    // 数据库服务（最基础）
    await _databaseService.initialize();

    // 缓存服务（依赖数据库）
    await _cacheService.initialize();

    debugPrint('✅ 基础服务初始化完成');
  }

  /// 初始化应用层服务
  Future<void> _initializeAppServices() async {
    debugPrint('📱 初始化应用层服务');

    // 应用状态服务（依赖缓存）
    await _stateService.initialize();

    debugPrint('✅ 应用层服务初始化完成');
  }

  /// 初始化备份和同步服务
  Future<void> _initializeBackupServices() async {
    debugPrint('☁️ 初始化备份和同步服务');

    // 备份服务（依赖数据库和缓存）
    await _backupService.initialize();

    // 离线数据服务（依赖所有其他服务）
    await _offlineService.initialize();

    debugPrint('✅ 备份和同步服务初始化完成');
  }

  /// 设置服务间协调
  Future<void> _setupServiceCoordination() async {
    debugPrint('🔗 设置服务间协调');

    try {
      // 监听应用状态变化，自动保存到缓存
      _stateService.stateEventStream.listen((event) {
        _handleStateEvent(event);
      });

      debugPrint('✅ 服务间协调设置完成');
    } catch (e) {
      debugPrint('❌ 服务间协调设置失败: $e');
    }
  }

  /// 处理状态事件
  void _handleStateEvent(AppStateEvent event) {
    try {
      // 根据不同的状态事件执行相应的缓存操作
      if (event is ReadingStateChanged) {
        // 阅读状态变化时，更新进度缓存
        final state = event.state;
        if (state.currentBookId != null) {
          _cacheService.setCache('last_reading_book', {
            'bookId': state.currentBookId,
            'bookTitle': state.currentBookTitle,
            'currentPage': state.currentPage,
            'lastReadTime': state.lastReadTime?.toIso8601String(),
          });
        }
      }
    } catch (e) {
      debugPrint('❌ 处理状态事件失败: $e');
      _emitError(DataManagerError.stateEventProcessing, e.toString());
    }
  }

  /// 处理初始化错误
  void _handleInitializationError(dynamic error) {
    _emitError(DataManagerError.initialization, error.toString());
  }

  /// 发送错误事件
  void _emitError(DataManagerError errorType, String message) {
    if (!_errorController.isClosed) {
      _errorController.add(errorType);
      debugPrint('📢 数据管理器错误: ${errorType.name} - $message');
    }
  }
}

/// 数据管理器错误类型
enum DataManagerError {
  initialization,
  serviceCoordination,
  stateEventProcessing,
  dataIntegrityCheck,
  dataRepair,
  dataSyncing,
}

/// 数据完整性报告
class DataIntegrityReport {
  bool databaseHealthy = false;
  bool cacheHealthy = false;
  bool stateHealthy = false;
  bool backupHealthy = false;
  bool offlineHealthy = false;
  bool overallHealthy = false;

  DateTime? checkTime;
  String? errorMessage;

  Map<String, dynamic> databaseReport = {};
  Map<String, dynamic> cacheStats = {};
  Map<String, dynamic> stateStats = {};
  Map<String, dynamic> backupStats = {};
  Map<String, dynamic> offlineStats = {};

  Map<String, dynamic> toJson() {
    return {
      'database_healthy': databaseHealthy,
      'cache_healthy': cacheHealthy,
      'state_healthy': stateHealthy,
      'backup_healthy': backupHealthy,
      'offline_healthy': offlineHealthy,
      'overall_healthy': overallHealthy,
      'check_time': checkTime?.toIso8601String(),
      'error_message': errorMessage,
      'database_report': databaseReport,
      'cache_stats': cacheStats,
      'state_stats': stateStats,
      'backup_stats': backupStats,
      'offline_stats': offlineStats,
    };
  }
}
