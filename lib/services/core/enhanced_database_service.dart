// 文件说明：增强数据库服务，补充事务、统计和健康检查能力。
// 技术要点：服务层、SQLite、Flutter。

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xxread/services/core/database_service.dart';

/// 增强数据库管理服务
///
/// 扩展基础DatabaseService，提供事务管理、
/// 错误恢复、连接池管理等高级功能
///
/// 核心功能：
/// - 事务管理
/// - 错误恢复机制
/// - 连接池管理
/// - 数据库健康监控
class EnhancedDatabaseService {
  static final EnhancedDatabaseService _instance =
      EnhancedDatabaseService._internal();
  factory EnhancedDatabaseService() => _instance;
  EnhancedDatabaseService._internal();

  // 基础数据库服务
  final DatabaseService _baseService = DatabaseService();

  // 连接管理
  Database? _database;
  Future<void>? _initializing;
  bool _isInitialized = false;

  // 事务管理
  final Map<String, Completer<void>> _transactionLocks = {};
  final Map<String, int> _transactionCounters = {};

  // 错误恢复
  int _connectionRetryCount = 0;
  static const int _maxRetryAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 2);

  // 健康监控
  Timer? _healthCheckTimer;
  bool _isDatabaseHealthy = true;

  // 性能统计
  final Map<String, DatabaseOperationStats> _operationStats = {};

  /// 获取数据库实例
  Future<Database> get database async {
    if (_isInitialized && _database != null) {
      return _database!;
    }

    await initialize();
    return _database!;
  }

  /// 检查数据库是否健康
  bool get isDatabaseHealthy => _isDatabaseHealthy;

  /// 获取操作统计
  Map<String, DatabaseOperationStats> get operationStats =>
      Map.unmodifiable(_operationStats);

  /// 初始化增强数据库服务
  Future<void> initialize() async {
    if (_isInitialized && _database != null) {
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
    debugPrint('🚀 初始化增强数据库服务');

    try {
      // 获取基础数据库
      _database = await _baseService.database;
      _isInitialized = true;

      // 启动健康检查
      _startHealthCheck();

      // 执行初始健康检查
      await _performHealthCheck();

      debugPrint('✅ 增强数据库服务初始化成功');
    } catch (e) {
      debugPrint('❌ 增强数据库服务初始化失败: $e');

      rethrow;
    }
  }

  /// 销毁增强数据库服务
  Future<void> dispose() async {
    debugPrint('🛑 销毁增强数据库服务');

    try {
      // 停止健康检查
      _healthCheckTimer?.cancel();

      // 等待所有事务完成
      await _waitForAllTransactions();

      // 清理资源
      _operationStats.clear();
      _transactionLocks.clear();
      _transactionCounters.clear();

      _isInitialized = false;

      debugPrint('✅ 增强数据库服务销毁完成');
    } catch (e) {
      debugPrint('❌ 增强数据库服务销毁失败: $e');
    }
  }

  /// 执行安全查询
  ///
  /// [sql] SQL查询语句
  /// [arguments] 查询参数
  /// [operationName] 操作名称，用于统计
  /// Returns: 查询结果
  Future<List<Map<String, dynamic>>> safeQuery(
    String sql, {
    List<Object?>? arguments,
    String? operationName,
  }) async {
    final operation = operationName ?? 'query';
    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;
      final result = await db.rawQuery(sql, arguments);

      stopwatch.stop();
      _recordOperation(operation, stopwatch.elapsedMilliseconds, true);

      debugPrint('📊 查询成功: $operation (${stopwatch.elapsedMilliseconds}ms)');
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordOperation(operation, stopwatch.elapsedMilliseconds, false);

      debugPrint('❌ 查询失败: $operation, 错误: $e');

      // 尝试错误恢复
      if (await _attemptErrorRecovery(e)) {
        return await safeQuery(
          sql,
          arguments: arguments,
          operationName: operationName,
        );
      }

      rethrow;
    }
  }

  /// 执行安全更新
  ///
  /// [sql] SQL更新语句
  /// [arguments] 更新参数
  /// [operationName] 操作名称，用于统计
  /// Returns: 受影响的行数
  Future<int> safeUpdate(
    String sql, {
    List<Object?>? arguments,
    String? operationName,
  }) async {
    final operation = operationName ?? 'update';
    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;
      final result = await db.rawUpdate(sql, arguments);

      stopwatch.stop();
      _recordOperation(operation, stopwatch.elapsedMilliseconds, true);

      debugPrint(
        '📊 更新成功: $operation (${stopwatch.elapsedMilliseconds}ms, $result行)',
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordOperation(operation, stopwatch.elapsedMilliseconds, false);

      debugPrint('❌ 更新失败: $operation, 错误: $e');

      // 尝试错误恢复
      if (await _attemptErrorRecovery(e)) {
        return await safeUpdate(
          sql,
          arguments: arguments,
          operationName: operationName,
        );
      }

      rethrow;
    }
  }

  /// 执行安全插入
  ///
  /// [table] 表名
  /// [values] 插入的值
  /// [operationName] 操作名称，用于统计
  /// Returns: 插入记录的ID
  Future<int> safeInsert(
    String table,
    Map<String, Object?> values, {
    String? operationName,
  }) async {
    final operation = operationName ?? 'insert_$table';
    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;
      final result = await db.insert(table, values);

      stopwatch.stop();
      _recordOperation(operation, stopwatch.elapsedMilliseconds, true);

      debugPrint(
        '📊 插入成功: $operation (${stopwatch.elapsedMilliseconds}ms, ID:$result)',
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordOperation(operation, stopwatch.elapsedMilliseconds, false);

      debugPrint('❌ 插入失败: $operation, 错误: $e');

      // 尝试错误恢复
      if (await _attemptErrorRecovery(e)) {
        return await safeInsert(table, values, operationName: operationName);
      }

      rethrow;
    }
  }

  /// 执行安全删除
  ///
  /// [table] 表名
  /// [where] WHERE条件
  /// [whereArgs] WHERE参数
  /// [operationName] 操作名称，用于统计
  /// Returns: 删除的行数
  Future<int> safeDelete(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? operationName,
  }) async {
    final operation = operationName ?? 'delete_$table';
    final stopwatch = Stopwatch()..start();

    try {
      final db = await database;
      final result = await db.delete(table, where: where, whereArgs: whereArgs);

      stopwatch.stop();
      _recordOperation(operation, stopwatch.elapsedMilliseconds, true);

      debugPrint(
        '📊 删除成功: $operation (${stopwatch.elapsedMilliseconds}ms, $result行)',
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      _recordOperation(operation, stopwatch.elapsedMilliseconds, false);

      debugPrint('❌ 删除失败: $operation, 错误: $e');

      // 尝试错误恢复
      if (await _attemptErrorRecovery(e)) {
        return await safeDelete(
          table,
          where: where,
          whereArgs: whereArgs,
          operationName: operationName,
        );
      }

      rethrow;
    }
  }

  /// 执行事务
  ///
  /// [transactionName] 事务名称
  /// [action] 事务内执行的操作
  /// [timeout] 事务超时时间
  /// Returns: 事务结果
  Future<T> executeTransaction<T>(
    String transactionName,
    Future<T> Function(Transaction txn) action, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    debugPrint('🔄 开始事务: $transactionName');

    // 获取事务锁
    await _acquireTransactionLock(transactionName);

    try {
      final db = await database;
      final stopwatch = Stopwatch()..start();

      T result = await db.transaction<T>((txn) async {
        try {
          return await action(txn);
        } catch (e) {
          debugPrint('❌ 事务内操作失败: $transactionName, 错误: $e');
          rethrow;
        }
      });

      stopwatch.stop();
      _recordOperation(
        'transaction_$transactionName',
        stopwatch.elapsedMilliseconds,
        true,
      );

      debugPrint(
        '✅ 事务完成: $transactionName (${stopwatch.elapsedMilliseconds}ms)',
      );
      return result;
    } catch (e) {
      _recordOperation('transaction_$transactionName', 0, false);
      debugPrint('❌ 事务失败: $transactionName, 错误: $e');

      // 尝试错误恢复
      if (await _attemptErrorRecovery(e)) {
        return await executeTransaction(
          transactionName,
          action,
          timeout: timeout,
        );
      }

      rethrow;
    } finally {
      _releaseTransactionLock(transactionName);
    }
  }

  /// 批量操作
  ///
  /// [operationName] 操作名称
  /// [operations] 操作列表
  /// [batchSize] 批次大小
  /// Returns: 操作结果列表
  Future<List<T>> batchOperation<T>(
    String operationName,
    List<Future<T> Function()> operations, {
    int batchSize = 50,
  }) async {
    debugPrint('📦 开始批量操作: $operationName (${operations.length}个操作)');

    final results = <T>[];
    final stopwatch = Stopwatch()..start();

    try {
      for (int i = 0; i < operations.length; i += batchSize) {
        final batch = operations.skip(i).take(batchSize);
        final batchResults = await Future.wait(batch.map((op) => op()));
        results.addAll(batchResults);

        debugPrint('📦 批次完成: ${i + batchResults.length}/${operations.length}');
      }

      stopwatch.stop();
      _recordOperation(
        'batch_$operationName',
        stopwatch.elapsedMilliseconds,
        true,
      );

      debugPrint(
        '✅ 批量操作完成: $operationName (${stopwatch.elapsedMilliseconds}ms)',
      );
      return results;
    } catch (e) {
      stopwatch.stop();
      _recordOperation(
        'batch_$operationName',
        stopwatch.elapsedMilliseconds,
        false,
      );

      debugPrint('❌ 批量操作失败: $operationName, 错误: $e');
      rethrow;
    }
  }

  /// 获取数据库健康状态
  Future<DatabaseHealthReport> getHealthReport() async {
    final report = DatabaseHealthReport();

    try {
      // 检查数据库连接
      report.connectionHealthy = await _checkDatabaseConnection();

      // 检查表完整性
      report.tablesHealthy = await _checkTablesIntegrity();

      // 获取数据库统计信息
      report.statistics = await _getDatabaseStatistics();

      // 检查性能指标
      report.performanceMetrics = _getPerformanceMetrics();

      report.overallHealthy = report.connectionHealthy && report.tablesHealthy;
      report.lastCheckTime = DateTime.now();

      debugPrint('📊 数据库健康检查完成: ${report.overallHealthy ? "健康" : "异常"}');
    } catch (e) {
      debugPrint('❌ 数据库健康检查失败: $e');
      report.overallHealthy = false;
      report.errorMessage = e.toString();
    }

    return report;
  }

  /// 优化数据库
  Future<void> optimizeDatabase() async {
    debugPrint('🔧 开始数据库优化');

    try {
      await executeTransaction('optimize_database', (txn) async {
        // 重建索引
        await txn.rawUpdate('REINDEX');

        // 清理数据库
        await txn.rawUpdate('VACUUM');

        // 分析统计信息
        await txn.rawUpdate('ANALYZE');
      });

      debugPrint('✅ 数据库优化完成');
    } catch (e) {
      debugPrint('❌ 数据库优化失败: $e');
      rethrow;
    }
  }

  /// 启动健康检查定时器
  void _startHealthCheck() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(const Duration(minutes: 30), (
      timer,
    ) async {
      try {
        await _performHealthCheck();
      } catch (e) {
        debugPrint('❌ 定期健康检查失败: $e');
      }
    });
    debugPrint('⏰ 数据库健康检查定时器已启动');
  }

  /// 执行健康检查
  Future<void> _performHealthCheck() async {
    try {
      _isDatabaseHealthy = await _checkDatabaseConnection();

      if (!_isDatabaseHealthy) {
        debugPrint('⚠️ 数据库健康检查失败，尝试恢复');
        await _attemptErrorRecovery(Exception('Database health check failed'));
      }
    } catch (e) {
      debugPrint('❌ 健康检查失败: $e');
      _isDatabaseHealthy = false;
    }
  }

  /// 检查数据库连接
  Future<bool> _checkDatabaseConnection() async {
    try {
      final db = await database;
      await db.rawQuery('SELECT 1');
      return true;
    } catch (e) {
      debugPrint('❌ 数据库连接检查失败: $e');
      return false;
    }
  }

  /// 检查表完整性
  Future<bool> _checkTablesIntegrity() async {
    try {
      final db = await database;

      // 检查表是否存在
      final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table'",
      );

      final tableNames = tables.map((table) => table['name'] as String).toSet();
      final requiredTables = {
        'books',
        'bookmarks',
        'reading_stats',
        'book_notes',
      };

      return requiredTables.every((table) => tableNames.contains(table));
    } catch (e) {
      debugPrint('❌ 表完整性检查失败: $e');
      return false;
    }
  }

  /// 获取数据库统计信息
  Future<Map<String, dynamic>> _getDatabaseStatistics() async {
    try {
      final db = await database;
      final stats = <String, dynamic>{};

      // 获取各表记录数
      for (final table in [
        'books',
        'bookmarks',
        'reading_stats',
        'book_notes',
      ]) {
        final result = await db.rawQuery(
          'SELECT COUNT(*) as count FROM $table',
        );
        stats['${table}_count'] = result.first['count'];
      }

      // 获取数据库大小
      final sizeResult = await db.rawQuery('PRAGMA page_count');
      final pageCount = sizeResult.first['page_count'] as int;
      stats['database_size_pages'] = pageCount;

      return stats;
    } catch (e) {
      debugPrint('❌ 获取数据库统计失败: $e');
      return {};
    }
  }

  /// 获取性能指标
  Map<String, dynamic> _getPerformanceMetrics() {
    final metrics = <String, dynamic>{};

    for (final entry in _operationStats.entries) {
      final stats = entry.value;
      metrics[entry.key] = {
        'total_operations': stats.totalOperations,
        'successful_operations': stats.successfulOperations,
        'failed_operations': stats.failedOperations,
        'average_duration_ms': stats.averageDurationMs,
        'success_rate': stats.successRate,
      };
    }

    return metrics;
  }

  /// 尝试错误恢复
  Future<bool> _attemptErrorRecovery(dynamic error) async {
    if (_connectionRetryCount >= _maxRetryAttempts) {
      debugPrint('❌ 达到最大重试次数，错误恢复失败');
      _connectionRetryCount = 0;
      return false;
    }

    _connectionRetryCount++;
    debugPrint('🔄 尝试错误恢复 (第$_connectionRetryCount次)');

    try {
      // 等待一段时间后重试
      await Future.delayed(_retryDelay);

      // 重新初始化数据库连接
      _database = await _baseService.database;

      // 验证连接
      if (await _checkDatabaseConnection()) {
        _connectionRetryCount = 0;
        _isDatabaseHealthy = true;
        debugPrint('✅ 错误恢复成功');
        return true;
      }
    } catch (e) {
      debugPrint('❌ 错误恢复失败: $e');
    }

    return false;
  }

  /// 获取事务锁
  Future<void> _acquireTransactionLock(String transactionName) async {
    if (_transactionLocks.containsKey(transactionName)) {
      // 等待现有事务完成
      await _transactionLocks[transactionName]!.future;
    }

    _transactionLocks[transactionName] = Completer<void>();
    _transactionCounters[transactionName] =
        (_transactionCounters[transactionName] ?? 0) + 1;
  }

  /// 释放事务锁
  void _releaseTransactionLock(String transactionName) {
    final completer = _transactionLocks.remove(transactionName);
    completer?.complete();
  }

  /// 等待所有事务完成
  Future<void> _waitForAllTransactions() async {
    final futures = _transactionLocks.values.map(
      (completer) => completer.future,
    );
    await Future.wait(futures);
  }

  /// 记录操作统计
  void _recordOperation(String operation, int durationMs, bool success) {
    final stats = _operationStats.putIfAbsent(
      operation,
      () => DatabaseOperationStats(),
    );
    stats.recordOperation(durationMs, success);
  }
}

/// 数据库操作统计
class DatabaseOperationStats {
  int totalOperations = 0;
  int successfulOperations = 0;
  int failedOperations = 0;
  int totalDurationMs = 0;

  double get averageDurationMs {
    return totalOperations > 0 ? totalDurationMs / totalOperations : 0.0;
  }

  double get successRate {
    return totalOperations > 0 ? successfulOperations / totalOperations : 0.0;
  }

  void recordOperation(int durationMs, bool success) {
    totalOperations++;
    totalDurationMs += durationMs;

    if (success) {
      successfulOperations++;
    } else {
      failedOperations++;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'total_operations': totalOperations,
      'successful_operations': successfulOperations,
      'failed_operations': failedOperations,
      'total_duration_ms': totalDurationMs,
      'average_duration_ms': averageDurationMs,
      'success_rate': successRate,
    };
  }
}

/// 数据库健康报告
class DatabaseHealthReport {
  bool connectionHealthy = false;
  bool tablesHealthy = false;
  bool overallHealthy = false;
  DateTime? lastCheckTime;
  Map<String, dynamic> statistics = {};
  Map<String, dynamic> performanceMetrics = {};
  String? errorMessage;

  Map<String, dynamic> toJson() {
    return {
      'connection_healthy': connectionHealthy,
      'tables_healthy': tablesHealthy,
      'overall_healthy': overallHealthy,
      'last_check_time': lastCheckTime?.toIso8601String(),
      'statistics': statistics,
      'performance_metrics': performanceMetrics,
      'error_message': errorMessage,
    };
  }
}
