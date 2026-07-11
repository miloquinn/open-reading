// 文件说明：数据缓存服务，负责轻量级缓存、脏标记和恢复加速。
// 技术要点：服务层、SharedPreferences、JSON、Flutter。

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xxread/services/core/database_service.dart';

/// 统一数据缓存管理服务
///
/// 负责管理应用程序的所有缓存数据和持久化操作，
/// 确保关键数据在应用退出重启后能够正确恢复
///
/// 核心功能：
/// - 实时数据缓存
/// - 定期数据同步
/// - 应用状态恢复
/// - 数据备份验证
class DataCacheService {
  static final DataCacheService _instance = DataCacheService._internal();
  factory DataCacheService() => _instance;
  DataCacheService._internal();

  // 数据库服务实例
  final DatabaseService _databaseService = DatabaseService();

  // 定时器用于定期保存数据
  Timer? _autoSaveTimer;
  Timer? _dataSyncTimer;

  // 缓存数据存储
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamp = {};

  // 标记数据是否已修改
  final Set<String> _dirtyKeys = {};

  // 自动保存间隔
  static const Duration _autoSaveInterval = Duration(seconds: 30);
  static const Duration _dataSyncInterval = Duration(minutes: 2);

  /// 初始化缓存服务
  ///
  /// 启动自动保存定时器和数据同步定时器
  /// 从持久化存储中恢复缓存数据
  Future<void> initialize() async {
    debugPrint('🔄 初始化数据缓存服务');

    try {
      // 恢复缓存数据
      await _restoreCacheData();

      // 启动定时器
      _startAutoSaveTimer();
      _startDataSyncTimer();

      debugPrint('✅ 数据缓存服务初始化成功');
    } catch (e) {
      debugPrint('❌ 数据缓存服务初始化失败: $e');
      rethrow;
    }
  }

  /// 销毁缓存服务
  ///
  /// 保存所有待写入数据并清理资源
  Future<void> dispose() async {
    debugPrint('🛑 销毁数据缓存服务');

    try {
      // 停止定时器
      _autoSaveTimer?.cancel();
      _dataSyncTimer?.cancel();

      // 保存所有脏数据
      await _saveAllDirtyData();

      // 清理缓存
      _cache.clear();
      _cacheTimestamp.clear();
      _dirtyKeys.clear();

      debugPrint('✅ 数据缓存服务销毁完成');
    } catch (e) {
      debugPrint('❌ 数据缓存服务销毁失败: $e');
    }
  }

  /// 设置缓存数据
  ///
  /// [key] 缓存键名
  /// [value] 缓存值
  /// [persistImmediately] 是否立即持久化，默认false
  Future<void> setCache(
    String key,
    dynamic value, {
    bool persistImmediately = false,
  }) async {
    try {
      _cache[key] = value;
      _cacheTimestamp[key] = DateTime.now();
      _dirtyKeys.add(key);

      debugPrint('📝 缓存数据: $key = ${_truncateValue(value)}');

      if (persistImmediately) {
        await _persistCacheItem(key, value);
        _dirtyKeys.remove(key);
        debugPrint('💾 立即持久化: $key');
      }
    } catch (e) {
      debugPrint('❌ 设置缓存失败: $key = $value, 错误: $e');
      rethrow;
    }
  }

  /// 获取缓存数据
  ///
  /// [key] 缓存键名
  /// [defaultValue] 默认值
  /// Returns: 缓存值或默认值
  T? getCache<T>(String key, [T? defaultValue]) {
    try {
      if (_cache.containsKey(key)) {
        final value = _cache[key];
        debugPrint('📖 读取缓存: $key = ${_truncateValue(value)}');
        return value as T?;
      } else {
        debugPrint('📖 缓存未命中: $key, 返回默认值: $defaultValue');
        return defaultValue;
      }
    } catch (e) {
      debugPrint('❌ 获取缓存失败: $key, 错误: $e');
      return defaultValue;
    }
  }

  /// 移除缓存数据
  ///
  /// [key] 缓存键名
  /// [persistImmediately] 是否立即持久化删除操作
  Future<void> removeCache(
    String key, {
    bool persistImmediately = false,
  }) async {
    try {
      _cache.remove(key);
      _cacheTimestamp.remove(key);
      _dirtyKeys.add('_remove_$key'); // 标记为待删除

      debugPrint('🗑️ 移除缓存: $key');

      if (persistImmediately) {
        await _removePersistentItem(key);
        _dirtyKeys.remove('_remove_$key');
        debugPrint('💾 立即持久化删除: $key');
      }
    } catch (e) {
      debugPrint('❌ 移除缓存失败: $key, 错误: $e');
    }
  }

  /// 检查缓存是否存在
  ///
  /// [key] 缓存键名
  /// Returns: 缓存是否存在
  bool hasCache(String key) {
    return _cache.containsKey(key);
  }

  /// 获取缓存时间戳
  ///
  /// [key] 缓存键名
  /// Returns: 缓存设置时间
  DateTime? getCacheTimestamp(String key) {
    return _cacheTimestamp[key];
  }

  /// 清空所有缓存
  ///
  /// [persistImmediately] 是否立即持久化清空操作
  Future<void> clearCache({bool persistImmediately = false}) async {
    try {
      _cache.clear();
      _cacheTimestamp.clear();
      _dirtyKeys.clear();
      _dirtyKeys.add('_clear_all'); // 标记全局清理

      debugPrint('🧹 清空所有缓存');

      if (persistImmediately) {
        await _clearAllPersistentData();
        _dirtyKeys.remove('_clear_all');
        debugPrint('💾 立即持久化清空操作');
      }
    } catch (e) {
      debugPrint('❌ 清空缓存失败: $e');
    }
  }

  /// 强制保存所有脏数据
  ///
  /// 将所有待写入的缓存数据立即持久化到存储
  Future<void> forceSync() async {
    debugPrint('🔄 强制同步所有数据');

    try {
      await _saveAllDirtyData();
      debugPrint('✅ 强制同步完成');
    } catch (e) {
      debugPrint('❌ 强制同步失败: $e');
      rethrow;
    }
  }

  /// 获取缓存统计信息
  ///
  /// Returns: 包含缓存统计信息的Map
  Map<String, dynamic> getCacheStats() {
    return {
      'total_items': _cache.length,
      'dirty_items': _dirtyKeys.length,
      'oldest_timestamp': _cacheTimestamp.values.isNotEmpty
          ? _cacheTimestamp.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
      'newest_timestamp': _cacheTimestamp.values.isNotEmpty
          ? _cacheTimestamp.values.reduce((a, b) => a.isAfter(b) ? a : b)
          : null,
      'memory_usage_estimation': _estimateMemoryUsage(),
    };
  }

  /// 启动自动保存定时器
  void _startAutoSaveTimer() {
    _autoSaveTimer?.cancel(); // 确保没有重复定时器
    _autoSaveTimer = Timer.periodic(_autoSaveInterval, (timer) async {
      if (_dirtyKeys.isNotEmpty) {
        debugPrint('⏰ 自动保存触发，脏数据项: ${_dirtyKeys.length}');
        try {
          await _saveAllDirtyData();
        } catch (e) {
          debugPrint('❌ 自动保存失败: $e');
        }
      }
    });
    debugPrint('⏰ 自动保存定时器已启动，间隔: ${_autoSaveInterval.inSeconds}秒');
  }

  /// 启动数据同步定时器
  void _startDataSyncTimer() {
    _dataSyncTimer?.cancel(); // 确保没有重复定时器
    _dataSyncTimer = Timer.periodic(_dataSyncInterval, (timer) async {
      debugPrint('🔄 定期数据同步触发');
      try {
        await _performDataSync();
      } catch (e) {
        debugPrint('❌ 定期数据同步失败: $e');
      }
    });
    debugPrint('🔄 数据同步定时器已启动，间隔: ${_dataSyncInterval.inMinutes}分钟');
  }

  /// 保存所有脏数据
  Future<void> _saveAllDirtyData() async {
    if (_dirtyKeys.isEmpty) return;

    final dirtyKeysSnapshot = Set<String>.from(_dirtyKeys);
    debugPrint('💾 保存脏数据，共 ${dirtyKeysSnapshot.length} 项');

    try {
      // 处理普通缓存项
      for (final key in dirtyKeysSnapshot) {
        if (key.startsWith('_remove_')) {
          // 处理删除操作
          final originalKey = key.substring(8);
          await _removePersistentItem(originalKey);
        } else if (key == '_clear_all') {
          // 处理全局清理操作
          await _clearAllPersistentData();
        } else if (_cache.containsKey(key)) {
          // 处理普通更新操作
          await _persistCacheItem(key, _cache[key]);
        }
      }

      // 清理已处理的脏数据标记
      _dirtyKeys.removeAll(dirtyKeysSnapshot);

      debugPrint('✅ 脏数据保存完成');
    } catch (e) {
      debugPrint('❌ 保存脏数据失败: $e');
      rethrow;
    }
  }

  /// 持久化单个缓存项
  Future<void> _persistCacheItem(String key, dynamic value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final serializedValue = json.encode({
        'value': value,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'type': value.runtimeType.toString(),
      });

      await prefs.setString('cache_$key', serializedValue);
      debugPrint('💾 持久化缓存项: $key');
    } catch (e) {
      debugPrint('❌ 持久化缓存项失败: $key, 错误: $e');
      rethrow;
    }
  }

  /// 移除持久化项
  Future<void> _removePersistentItem(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cache_$key');
      debugPrint('🗑️ 移除持久化项: $key');
    } catch (e) {
      debugPrint('❌ 移除持久化项失败: $key, 错误: $e');
    }
  }

  /// 清空所有持久化数据
  Future<void> _clearAllPersistentData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys =
          prefs.getKeys().where((key) => key.startsWith('cache_')).toList();

      for (final key in keys) {
        await prefs.remove(key);
      }

      debugPrint('🧹 清空所有持久化数据，共清理 ${keys.length} 项');
    } catch (e) {
      debugPrint('❌ 清空持久化数据失败: $e');
    }
  }

  /// 恢复缓存数据
  Future<void> _restoreCacheData() async {
    debugPrint('🔄 恢复缓存数据');

    try {
      final prefs = await SharedPreferences.getInstance();
      final cacheKeys =
          prefs.getKeys().where((key) => key.startsWith('cache_')).toList();

      int restoredCount = 0;
      for (final prefKey in cacheKeys) {
        try {
          final serializedValue = prefs.getString(prefKey);
          if (serializedValue != null) {
            final data = json.decode(serializedValue);
            final originalKey = prefKey.substring(6); // 移除 'cache_' 前缀

            _cache[originalKey] = data['value'];
            _cacheTimestamp[originalKey] = DateTime.fromMillisecondsSinceEpoch(
              data['timestamp'],
            );
            restoredCount++;
          }
        } catch (e) {
          debugPrint('⚠️ 恢复缓存项失败: $prefKey, 错误: $e');
          // 移除损坏的缓存项
          await prefs.remove(prefKey);
        }
      }

      debugPrint('✅ 缓存数据恢复完成，共恢复 $restoredCount 项');
    } catch (e) {
      debugPrint('❌ 恢复缓存数据失败: $e');
    }
  }

  /// 执行数据同步
  Future<void> _performDataSync() async {
    try {
      // 执行数据完整性检查
      await _verifyDataIntegrity();

      // 清理过期缓存
      await _cleanupExpiredCache();

      debugPrint('✅ 定期数据同步完成');
    } catch (e) {
      debugPrint('❌ 数据同步失败: $e');
    }
  }

  /// 验证数据完整性
  Future<void> _verifyDataIntegrity() async {
    try {
      final db = await _databaseService.database;

      // 简单的数据库连接测试
      await db.rawQuery('SELECT 1');

      debugPrint('✅ 数据完整性验证通过');
    } catch (e) {
      debugPrint('❌ 数据完整性验证失败: $e');
      throw Exception('数据库完整性验证失败: $e');
    }
  }

  /// 永不过期的持久化键：应用状态等长期数据不应被"7天未访问"清理策略删除，
  /// 否则用户超过一周未打开应用后会丢失阅读状态。
  static const Set<String> _persistentKeys = {'app_state_v2'};

  /// 清理过期缓存
  Future<void> _cleanupExpiredCache() async {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    // 查找7天前的缓存项
    const maxAge = Duration(days: 7);

    for (final entry in _cacheTimestamp.entries) {
      if (_persistentKeys.contains(entry.key)) continue;
      if (now.difference(entry.value) > maxAge) {
        expiredKeys.add(entry.key);
      }
    }

    // 清理过期项
    for (final key in expiredKeys) {
      await removeCache(key, persistImmediately: true);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint('🧹 清理过期缓存，共清理 ${expiredKeys.length} 项');
    }
  }

  /// 估算内存使用量
  int _estimateMemoryUsage() {
    int totalSize = 0;

    for (final value in _cache.values) {
      totalSize += _estimateValueSize(value);
    }

    return totalSize;
  }

  /// 估算单个值的内存大小
  int _estimateValueSize(dynamic value) {
    if (value == null) return 4;
    if (value is String) return value.length * 2; // UTF-16编码
    if (value is int) return 8;
    if (value is double) return 8;
    if (value is bool) return 1;
    if (value is List) return value.length * 8; // 估算
    if (value is Map) return value.length * 16; // 估算

    return 32; // 默认估算
  }

  /// 截断值用于日志显示
  String _truncateValue(dynamic value) {
    final str = value.toString();
    return str.length > 100 ? '${str.substring(0, 100)}...' : str;
  }
}
