// 文件说明：离线数据服务，维护离线操作队列和网络恢复后的同步策略。
// 技术要点：服务层、Connectivity Plus、Flutter。

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:xxread/services/core/data_cache_service.dart';
import 'package:xxread/services/core/enhanced_database_service.dart';

/// 离线数据管理服务
///
/// 负责管理离线数据缓存，确保在网络问题或
/// 应用离线状态下用户数据仍能正常保存和访问
///
/// 核心功能：
/// - 离线数据队列管理
/// - 网络状态监控
/// - 数据同步策略
/// - 冲突解决机制
class OfflineDataService {
  static final OfflineDataService _instance = OfflineDataService._internal();
  factory OfflineDataService() => _instance;
  OfflineDataService._internal();

  // 依赖服务
  final DataCacheService _cacheService = DataCacheService();
  final EnhancedDatabaseService _databaseService = EnhancedDatabaseService();
  final Connectivity _connectivity = Connectivity();

  // 网络状态
  bool _isOnline = false;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  // 离线数据队列
  final List<OfflineOperation> _pendingOperations = [];
  final Map<String, OfflineDataEntry> _offlineCache = {};

  // 同步状态
  bool _isSyncing = false;
  DateTime? _lastSyncTime;
  Timer? _syncTimer;
  Timer? _cleanupTimer;

  // 配置参数
  static const Duration _syncInterval = Duration(minutes: 5);
  static const Duration _cleanupInterval = Duration(hours: 1);
  static const Duration _offlineDataRetention = Duration(days: 7);
  static const int _maxPendingOperations = 1000;

  /// 获取网络状态
  bool get isOnline => _isOnline;

  /// 获取待同步操作数量
  int get pendingOperationsCount => _pendingOperations.length;

  /// 获取最后同步时间
  DateTime? get lastSyncTime => _lastSyncTime;

  /// 检查是否正在同步
  bool get isSyncing => _isSyncing;

  /// 初始化离线数据服务
  Future<void> initialize() async {
    debugPrint('🌐 初始化离线数据服务');

    try {
      // 检查网络状态
      await _checkConnectivity();

      // 监听网络状态变化
      _startConnectivityMonitoring();

      // 加载离线数据
      await _loadOfflineData();

      // 启动定时器
      _startSyncTimer();
      _startCleanupTimer();

      // 如果在线，尝试同步
      if (_isOnline) {
        _scheduleSync();
      }

      debugPrint('✅ 离线数据服务初始化成功');
    } catch (e) {
      debugPrint('❌ 离线数据服务初始化失败: $e');
      rethrow;
    }
  }

  /// 销毁离线数据服务
  Future<void> dispose() async {
    debugPrint('🛑 销毁离线数据服务');

    try {
      // 停止监听
      await _connectivitySubscription?.cancel();

      // 停止定时器
      _syncTimer?.cancel();
      _cleanupTimer?.cancel();

      // 保存离线数据
      await _saveOfflineData();

      // 清理数据
      _pendingOperations.clear();
      _offlineCache.clear();

      debugPrint('✅ 离线数据服务销毁完成');
    } catch (e) {
      debugPrint('❌ 离线数据服务销毁失败: $e');
    }
  }

  /// 添加离线操作
  ///
  /// [operation] 离线操作
  Future<void> addOfflineOperation(OfflineOperation operation) async {
    try {
      // 检查队列大小
      if (_pendingOperations.length >= _maxPendingOperations) {
        // 移除最旧的操作
        _pendingOperations.removeAt(0);
        debugPrint('⚠️ 离线队列已满，移除最旧操作');
      }

      _pendingOperations.add(operation);

      // 立即保存到本地
      await _saveOfflineData();

      debugPrint(
        '📝 添加离线操作: ${operation.type} (队列: ${_pendingOperations.length})',
      );

      // 如果在线，尝试立即同步
      if (_isOnline && !_isSyncing) {
        _scheduleSync();
      }
    } catch (e) {
      debugPrint('❌ 添加离线操作失败: $e');
    }
  }

  /// 缓存离线数据
  ///
  /// [key] 数据键
  /// [data] 数据内容
  /// [priority] 优先级
  Future<void> cacheOfflineData(
    String key,
    Map<String, dynamic> data, {
    OfflineDataPriority priority = OfflineDataPriority.normal,
  }) async {
    try {
      final entry = OfflineDataEntry(
        key: key,
        data: data,
        timestamp: DateTime.now(),
        priority: priority,
      );

      _offlineCache[key] = entry;

      // 保存到持久存储
      await _cacheService.setCache(
        'offline_data_$key',
        entry.toJson(),
        persistImmediately: true,
      );

      debugPrint('💾 缓存离线数据: $key (优先级: ${priority.name})');
    } catch (e) {
      debugPrint('❌ 缓存离线数据失败: $key, 错误: $e');
    }
  }

  /// 获取离线数据
  ///
  /// [key] 数据键
  /// Returns: 离线数据，如果不存在则返回null
  Future<Map<String, dynamic>?> getOfflineData(String key) async {
    try {
      // 首先检查内存缓存
      if (_offlineCache.containsKey(key)) {
        final entry = _offlineCache[key]!;
        debugPrint('📖 从内存获取离线数据: $key');
        return entry.data;
      }

      // 从持久存储获取
      final cachedData = _cacheService.getCache<Map<String, dynamic>>(
        'offline_data_$key',
      );
      if (cachedData != null) {
        final entry = OfflineDataEntry.fromJson(cachedData);
        _offlineCache[key] = entry; // 加载到内存
        debugPrint('📖 从存储获取离线数据: $key');
        return entry.data;
      }

      debugPrint('📖 未找到离线数据: $key');
      return null;
    } catch (e) {
      debugPrint('❌ 获取离线数据失败: $key, 错误: $e');
      return null;
    }
  }

  /// 移除离线数据
  ///
  /// [key] 数据键
  Future<void> removeOfflineData(String key) async {
    try {
      _offlineCache.remove(key);
      await _cacheService.removeCache(
        'offline_data_$key',
        persistImmediately: true,
      );
      debugPrint('🗑️ 移除离线数据: $key');
    } catch (e) {
      debugPrint('❌ 移除离线数据失败: $key, 错误: $e');
    }
  }

  /// 强制同步离线数据
  ///
  /// Returns: 同步是否成功
  Future<bool> forceSync() async {
    if (!_isOnline) {
      debugPrint('⚠️ 设备离线，无法同步数据');
      return false;
    }

    if (_isSyncing) {
      debugPrint('⚠️ 同步正在进行中');
      return false;
    }

    return await _performSync();
  }

  /// 获取离线数据统计
  Map<String, dynamic> getOfflineStats() {
    final highPriorityCount = _offlineCache.values
        .where((entry) => entry.priority == OfflineDataPriority.high)
        .length;

    final normalPriorityCount = _offlineCache.values
        .where((entry) => entry.priority == OfflineDataPriority.normal)
        .length;

    final lowPriorityCount = _offlineCache.values
        .where((entry) => entry.priority == OfflineDataPriority.low)
        .length;

    return {
      'is_online': _isOnline,
      'is_syncing': _isSyncing,
      'pending_operations': _pendingOperations.length,
      'cached_entries': _offlineCache.length,
      'high_priority_entries': highPriorityCount,
      'normal_priority_entries': normalPriorityCount,
      'low_priority_entries': lowPriorityCount,
      'last_sync_time': _lastSyncTime?.toIso8601String(),
    };
  }

  /// 检查网络连接
  Future<void> _checkConnectivity() async {
    try {
      final connectivityResults = await _connectivity.checkConnectivity();
      _isOnline = connectivityResults.isNotEmpty &&
          connectivityResults.any(
            (result) => result != ConnectivityResult.none,
          );

      debugPrint('🌐 网络状态: ${_isOnline ? "在线" : "离线"}');
    } catch (e) {
      debugPrint('❌ 检查网络连接失败: $e');
      _isOnline = false;
    }
  }

  /// 开始监听网络状态
  void _startConnectivityMonitoring() {
    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> connectivityResults) {
        final wasOnline = _isOnline;
        _isOnline = connectivityResults.isNotEmpty &&
            connectivityResults.any(
              (result) => result != ConnectivityResult.none,
            );

        debugPrint('🌐 网络状态变化: ${_isOnline ? "在线" : "离线"}');

        // 如果从离线变为在线，立即尝试同步
        if (!wasOnline && _isOnline && !_isSyncing) {
          _scheduleSync();
        }
      },
      onError: (error) {
        debugPrint('❌ 网络状态监听错误: $error');
      },
    );
  }

  /// 启动同步定时器
  void _startSyncTimer() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(_syncInterval, (timer) async {
      if (_isOnline && !_isSyncing && _pendingOperations.isNotEmpty) {
        debugPrint('⏰ 定时同步触发');
        await _performSync();
      }
    });
    debugPrint('⏰ 同步定时器已启动，间隔: ${_syncInterval.inMinutes}分钟');
  }

  /// 启动清理定时器
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (timer) async {
      debugPrint('🧹 定时清理触发');
      await _cleanupExpiredData();
    });
    debugPrint('🧹 清理定时器已启动，间隔: ${_cleanupInterval.inHours}小时');
  }

  /// 调度同步
  void _scheduleSync() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (_isOnline && !_isSyncing) {
        await _performSync();
      }
    });
  }

  /// 执行同步
  Future<bool> _performSync() async {
    if (_isSyncing) return false;

    _isSyncing = true;
    debugPrint('🔄 开始同步离线数据');

    try {
      int syncedCount = 0;
      final failedOperations = <OfflineOperation>[];

      // 复制操作列表以避免并发修改
      final operationsToSync = List<OfflineOperation>.from(_pendingOperations);

      for (final operation in operationsToSync) {
        try {
          final success = await _executeOperation(operation);
          if (success) {
            syncedCount++;
            _pendingOperations.remove(operation);
          } else {
            failedOperations.add(operation);
          }
        } catch (e) {
          debugPrint('❌ 执行离线操作失败: ${operation.type}, 错误: $e');
          failedOperations.add(operation);
        }
      }

      // 更新同步时间
      _lastSyncTime = DateTime.now();

      // 保存更新后的队列
      await _saveOfflineData();

      debugPrint('✅ 同步完成: 成功$syncedCount个, 失败${failedOperations.length}个');
      return failedOperations.isEmpty;
    } catch (e) {
      debugPrint('❌ 同步失败: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// 执行单个操作
  Future<bool> _executeOperation(OfflineOperation operation) async {
    try {
      switch (operation.type) {
        case OfflineOperationType.insert:
          return await _executeInsertOperation(operation);
        case OfflineOperationType.update:
          return await _executeUpdateOperation(operation);
        case OfflineOperationType.delete:
          return await _executeDeleteOperation(operation);
      }
    } catch (e) {
      debugPrint('❌ 执行操作失败: ${operation.type}, 错误: $e');
      return false;
    }
  }

  /// 执行插入操作
  Future<bool> _executeInsertOperation(OfflineOperation operation) async {
    try {
      await _databaseService.safeInsert(
        operation.table,
        operation.data,
        operationName: 'offline_insert_${operation.table}',
      );
      return true;
    } catch (e) {
      debugPrint('❌ 离线插入操作失败: $e');
      return false;
    }
  }

  /// 执行更新操作
  Future<bool> _executeUpdateOperation(OfflineOperation operation) async {
    try {
      final where = operation.where;
      final whereArgs = operation.whereArgs;

      if (where != null) {
        // 使用WHERE条件更新
        final sql =
            'UPDATE ${operation.table} SET ${_buildSetClause(operation.data)} WHERE $where';
        final args = [
          ...operation.data.values,
          if (whereArgs != null) ...whereArgs,
        ];

        await _databaseService.safeUpdate(
          sql,
          arguments: args,
          operationName: 'offline_update_${operation.table}',
        );
      } else {
        debugPrint('⚠️ 更新操作缺少WHERE条件');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('❌ 离线更新操作失败: $e');
      return false;
    }
  }

  /// 执行删除操作
  Future<bool> _executeDeleteOperation(OfflineOperation operation) async {
    try {
      await _databaseService.safeDelete(
        operation.table,
        where: operation.where,
        whereArgs: operation.whereArgs,
        operationName: 'offline_delete_${operation.table}',
      );
      return true;
    } catch (e) {
      debugPrint('❌ 离线删除操作失败: $e');
      return false;
    }
  }

  /// 构建SET子句
  String _buildSetClause(Map<String, dynamic> data) {
    return data.keys.map((key) => '$key = ?').join(', ');
  }

  /// 加载离线数据
  Future<void> _loadOfflineData() async {
    try {
      // 加载离线操作队列
      final operationsData = _cacheService.getCache<List<dynamic>>(
        'offline_operations',
        <dynamic>[],
      );
      _pendingOperations.clear();
      _pendingOperations.addAll(
        (operationsData ?? <dynamic>[]).map(
          (data) => OfflineOperation.fromJson(data as Map<String, dynamic>),
        ),
      );

      debugPrint('🔄 加载离线操作队列: ${_pendingOperations.length}个操作');
    } catch (e) {
      debugPrint('❌ 加载离线数据失败: $e');
    }
  }

  /// 保存离线数据
  Future<void> _saveOfflineData() async {
    try {
      // 保存离线操作队列
      final operationsData =
          _pendingOperations.map((op) => op.toJson()).toList();
      await _cacheService.setCache(
        'offline_operations',
        operationsData,
        persistImmediately: true,
      );

      debugPrint('💾 保存离线操作队列: ${_pendingOperations.length}个操作');
    } catch (e) {
      debugPrint('❌ 保存离线数据失败: $e');
    }
  }

  /// 清理过期数据
  Future<void> _cleanupExpiredData() async {
    try {
      final now = DateTime.now();
      final expiredKeys = <String>[];

      // 查找过期的离线数据
      for (final entry in _offlineCache.entries) {
        if (now.difference(entry.value.timestamp) > _offlineDataRetention) {
          expiredKeys.add(entry.key);
        }
      }

      // 清理过期数据
      for (final key in expiredKeys) {
        await removeOfflineData(key);
      }

      // 清理过期的操作（保留高优先级操作更长时间）
      final cutoffTime = now.subtract(_offlineDataRetention);
      _pendingOperations.removeWhere(
        (operation) =>
            operation.timestamp.isBefore(cutoffTime) &&
            operation.priority != OfflineDataPriority.high,
      );

      if (expiredKeys.isNotEmpty || _pendingOperations.isNotEmpty) {
        await _saveOfflineData();
        debugPrint('🧹 清理过期数据: ${expiredKeys.length}个缓存项');
      }
    } catch (e) {
      debugPrint('❌ 清理过期数据失败: $e');
    }
  }
}

/// 离线操作类型
enum OfflineOperationType { insert, update, delete }

/// 离线数据优先级
enum OfflineDataPriority { low, normal, high }

/// 离线操作模型
class OfflineOperation {
  final String id;
  final OfflineOperationType type;
  final String table;
  final Map<String, dynamic> data;
  final String? where;
  final List<dynamic>? whereArgs;
  final DateTime timestamp;
  final OfflineDataPriority priority;

  const OfflineOperation({
    required this.id,
    required this.type,
    required this.table,
    required this.data,
    this.where,
    this.whereArgs,
    required this.timestamp,
    this.priority = OfflineDataPriority.normal,
  });

  factory OfflineOperation.fromJson(Map<String, dynamic> json) {
    return OfflineOperation(
      id: json['id'] as String,
      type: OfflineOperationType.values[json['type'] as int],
      table: json['table'] as String,
      data: json['data'] as Map<String, dynamic>,
      where: json['where'] as String?,
      whereArgs: json['whereArgs'] as List<dynamic>?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      priority: OfflineDataPriority.values[json['priority'] as int? ?? 1],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.index,
      'table': table,
      'data': data,
      'where': where,
      'whereArgs': whereArgs,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.index,
    };
  }
}

/// 离线数据条目
class OfflineDataEntry {
  final String key;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final OfflineDataPriority priority;

  const OfflineDataEntry({
    required this.key,
    required this.data,
    required this.timestamp,
    this.priority = OfflineDataPriority.normal,
  });

  factory OfflineDataEntry.fromJson(Map<String, dynamic> json) {
    return OfflineDataEntry(
      key: json['key'] as String,
      data: json['data'] as Map<String, dynamic>,
      timestamp: DateTime.parse(json['timestamp'] as String),
      priority: OfflineDataPriority.values[json['priority'] as int? ?? 1],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'key': key,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'priority': priority.index,
    };
  }
}
