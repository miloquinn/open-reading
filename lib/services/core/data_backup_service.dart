// 文件说明：数据备份服务，负责数据库与缓存数据的备份、校验和恢复。
// 技术要点：服务层、Path Provider、SharedPreferences、Crypto 哈希、JSON、文件系统。

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import 'package:xxread/services/core/database_service.dart';
import 'package:xxread/services/core/data_cache_service.dart';

/// 数据备份和验证服务
///
/// 负责应用数据的备份、恢复和完整性验证，
/// 防止数据损坏和丢失，确保用户数据安全
///
/// 核心功能：
/// - 自动数据备份
/// - 数据完整性验证
/// - 数据恢复机制
/// - 备份文件管理
class DataBackupService {
  static final DataBackupService _instance = DataBackupService._internal();
  factory DataBackupService() => _instance;
  DataBackupService._internal();

  // 依赖服务
  final DatabaseService _databaseService = DatabaseService();
  final DataCacheService _cacheService = DataCacheService();

  // 备份定时器
  Timer? _backupTimer;
  Timer? _validationTimer;

  // 备份配置
  static const Duration _backupInterval = Duration(hours: 6);
  static const Duration _validationInterval = Duration(hours: 12);
  static const int _maxBackupFiles = 7; // 保留最近7个备份
  static const String _backupDir = 'backups';
  static const String _backupPrefix = 'xxread_backup_';

  // 备份状态
  bool _isBackupRunning = false;
  DateTime? _lastBackupTime;
  DateTime? _lastValidationTime;
  final List<BackupInfo> _backupHistory = [];

  /// 获取最后备份时间
  DateTime? get lastBackupTime => _lastBackupTime;

  /// 获取最后验证时间
  DateTime? get lastValidationTime => _lastValidationTime;

  /// 获取备份历史
  List<BackupInfo> get backupHistory => List.unmodifiable(_backupHistory);

  /// 检查是否正在备份
  bool get isBackupRunning => _isBackupRunning;

  /// 初始化数据备份服务
  Future<void> initialize() async {
    debugPrint('🛡️ 初始化数据备份服务');

    try {
      // 创建备份目录
      await _createBackupDirectory();

      // 加载备份历史
      await _loadBackupHistory();

      // 启动定时器
      _startBackupTimer();
      _startValidationTimer();

      // 执行初始验证
      await _performDataValidation();

      debugPrint('✅ 数据备份服务初始化成功');
    } catch (e) {
      debugPrint('❌ 数据备份服务初始化失败: $e');
      rethrow;
    }
  }

  /// 销毁数据备份服务
  Future<void> dispose() async {
    debugPrint('🛑 销毁数据备份服务');

    try {
      // 停止定时器
      _backupTimer?.cancel();
      _validationTimer?.cancel();

      // 如果正在备份，等待完成
      while (_isBackupRunning) {
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // 清理数据
      _backupHistory.clear();

      debugPrint('✅ 数据备份服务销毁完成');
    } catch (e) {
      debugPrint('❌ 数据备份服务销毁失败: $e');
    }
  }

  /// 创建数据备份
  ///
  /// [force] 是否强制创建备份，即使距离上次备份时间很短
  /// Returns: 备份是否成功
  Future<bool> createBackup({bool force = false}) async {
    if (_isBackupRunning) {
      debugPrint('⚠️ 备份正在进行中，跳过本次备份');
      return false;
    }

    if (!force && _lastBackupTime != null) {
      final timeSinceLastBackup = DateTime.now().difference(_lastBackupTime!);
      if (timeSinceLastBackup < const Duration(hours: 1)) {
        debugPrint('⚠️ 距离上次备份时间过短，跳过本次备份');
        return false;
      }
    }

    _isBackupRunning = true;
    debugPrint('📦 开始创建数据备份');

    try {
      final timestamp = DateTime.now();
      final backupFileName =
          '$_backupPrefix${timestamp.millisecondsSinceEpoch}.json';
      final backupFile = await _getBackupFile(backupFileName);

      // 收集所有需要备份的数据
      final backupData = await _collectBackupData();

      // 计算数据校验和
      final checksum = _calculateChecksum(backupData);

      // 创建备份结构
      final backup = {
        'version': '1.0',
        'timestamp': timestamp.toIso8601String(),
        'checksum': checksum,
        'data': backupData,
      };

      // 写入备份文件
      await backupFile.writeAsString(json.encode(backup), encoding: utf8);

      // 记录备份信息
      final backupInfo = BackupInfo(
        fileName: backupFileName,
        timestamp: timestamp,
        fileSize: await backupFile.length(),
        checksum: checksum,
      );

      _backupHistory.add(backupInfo);
      _lastBackupTime = timestamp;

      // 保存备份历史
      await _saveBackupHistory();

      // 清理旧备份
      await _cleanupOldBackups();

      debugPrint('✅ 数据备份创建成功: $backupFileName');
      return true;
    } catch (e) {
      debugPrint('❌ 创建数据备份失败: $e');
      return false;
    } finally {
      _isBackupRunning = false;
    }
  }

  /// 恢复数据备份
  ///
  /// [backupFileName] 备份文件名，如果为null则使用最新备份
  /// Returns: 恢复是否成功
  Future<bool> restoreBackup({String? backupFileName}) async {
    debugPrint('🔄 开始恢复数据备份');

    try {
      // 确定要恢复的备份文件
      final fileName = backupFileName ?? _getLatestBackupFileName();
      if (fileName == null) {
        debugPrint('❌ 没有可用的备份文件');
        return false;
      }

      final backupFile = await _getBackupFile(fileName);
      if (!await backupFile.exists()) {
        debugPrint('❌ 备份文件不存在: $fileName');
        return false;
      }

      // 读取备份文件
      final backupContent = await backupFile.readAsString(encoding: utf8);
      final backup = json.decode(backupContent) as Map<String, dynamic>;

      // 验证备份完整性
      final isValid = await _validateBackup(backup);
      if (!isValid) {
        debugPrint('❌ 备份文件验证失败: $fileName');
        return false;
      }

      // 恢复数据
      final backupData = backup['data'] as Map<String, dynamic>;
      await _restoreBackupData(backupData);

      debugPrint('✅ 数据备份恢复成功: $fileName');
      return true;
    } catch (e) {
      debugPrint('❌ 恢复数据备份失败: $e');
      return false;
    }
  }

  /// 验证数据完整性
  ///
  /// Returns: 验证结果
  Future<DataValidationResult> validateData() async {
    debugPrint('🔍 开始数据完整性验证');

    try {
      final result = DataValidationResult();
      _lastValidationTime = DateTime.now();

      // 验证数据库
      result.databaseValid = await _validateDatabase();

      // 验证缓存
      result.cacheValid = await _validateCache();

      // 验证设置
      result.settingsValid = await _validateSettings();

      // 验证备份文件
      result.backupsValid = await _validateBackupFiles();

      // 计算总体状态
      result.overallValid = result.databaseValid &&
          result.cacheValid &&
          result.settingsValid &&
          result.backupsValid;

      debugPrint('✅ 数据完整性验证完成: ${result.overallValid ? "通过" : "失败"}');
      return result;
    } catch (e) {
      debugPrint('❌ 数据完整性验证失败: $e');
      return DataValidationResult()..overallValid = false;
    }
  }

  /// 修复损坏的数据
  ///
  /// Returns: 修复是否成功
  Future<bool> repairCorruptedData() async {
    debugPrint('🔧 开始修复损坏的数据');

    try {
      bool repaired = false;

      // 验证并修复数据库
      if (!await _validateDatabase()) {
        debugPrint('🔧 修复数据库');
        if (await _repairDatabase()) {
          repaired = true;
        }
      }

      // 验证并修复缓存
      if (!await _validateCache()) {
        debugPrint('🔧 修复缓存');
        if (await _repairCache()) {
          repaired = true;
        }
      }

      // 如果无法修复，尝试从备份恢复
      if (!repaired) {
        debugPrint('🔧 尝试从备份恢复');
        repaired = await restoreBackup();
      }

      debugPrint(repaired ? '✅ 数据修复成功' : '❌ 数据修复失败');
      return repaired;
    } catch (e) {
      debugPrint('❌ 修复数据失败: $e');
      return false;
    }
  }

  /// 获取备份统计信息
  Map<String, dynamic> getBackupStats() {
    return {
      'total_backups': _backupHistory.length,
      'last_backup_time': _lastBackupTime?.toIso8601String(),
      'last_validation_time': _lastValidationTime?.toIso8601String(),
      'is_backup_running': _isBackupRunning,
      'oldest_backup': _backupHistory.isNotEmpty
          ? _backupHistory.first.timestamp.toIso8601String()
          : null,
      'newest_backup': _backupHistory.isNotEmpty
          ? _backupHistory.last.timestamp.toIso8601String()
          : null,
      'total_backup_size': _backupHistory.fold<int>(
        0,
        (sum, backup) => sum + backup.fileSize,
      ),
    };
  }

  /// 启动备份定时器
  void _startBackupTimer() {
    _backupTimer?.cancel();
    _backupTimer = Timer.periodic(_backupInterval, (timer) async {
      debugPrint('⏰ 自动备份定时器触发');
      try {
        await createBackup();
      } catch (e) {
        debugPrint('❌ 自动备份失败: $e');
      }
    });
    debugPrint('⏰ 自动备份定时器已启动，间隔: ${_backupInterval.inHours}小时');
  }

  /// 启动验证定时器
  void _startValidationTimer() {
    _validationTimer?.cancel();
    _validationTimer = Timer.periodic(_validationInterval, (timer) async {
      debugPrint('⏰ 数据验证定时器触发');
      try {
        await _performDataValidation();
      } catch (e) {
        debugPrint('❌ 自动验证失败: $e');
      }
    });
    debugPrint('⏰ 数据验证定时器已启动，间隔: ${_validationInterval.inHours}小时');
  }

  /// 执行数据验证
  Future<void> _performDataValidation() async {
    final result = await validateData();
    if (!result.overallValid) {
      debugPrint('⚠️ 发现数据问题，尝试自动修复');
      await repairCorruptedData();
    }
  }

  /// 创建备份目录
  Future<void> _createBackupDirectory() async {
    final backupDir = await _getBackupDirectory();
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
      debugPrint('📁 创建备份目录: ${backupDir.path}');
    }
  }

  /// 获取备份目录
  Future<Directory> _getBackupDirectory() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    return Directory('${appDocDir.path}/$_backupDir');
  }

  /// 获取备份文件
  Future<File> _getBackupFile(String fileName) async {
    final backupDir = await _getBackupDirectory();
    return File('${backupDir.path}/$fileName');
  }

  /// 收集备份数据
  Future<Map<String, dynamic>> _collectBackupData() async {
    final data = <String, dynamic>{};

    try {
      // 备份数据库数据
      final db = await _databaseService.database;

      // 备份books表
      final books = await db.query('books');
      data['books'] = books;

      // 备份bookmarks表
      final bookmarks = await db.query('bookmarks');
      data['bookmarks'] = bookmarks;

      // 备份reading_stats表
      final readingStats = await db.query('reading_stats');
      data['reading_stats'] = readingStats;

      // 备份book_notes表
      final bookNotes = await db.query('book_notes');
      data['book_notes'] = bookNotes;

      // 备份SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final prefsData = <String, dynamic>{};
      for (final key in prefs.getKeys()) {
        final value = prefs.get(key);
        if (value != null) {
          prefsData[key] = value;
        }
      }
      data['preferences'] = prefsData;

      debugPrint('📦 数据收集完成: ${data.keys.join(", ")}');
    } catch (e) {
      debugPrint('❌ 收集备份数据失败: $e');
      rethrow;
    }

    return data;
  }

  /// 恢复备份数据
  Future<void> _restoreBackupData(Map<String, dynamic> backupData) async {
    try {
      final db = await _databaseService.database;

      // 开始事务
      await db.transaction((txn) async {
        // 清空现有数据
        await txn.delete('books');
        await txn.delete('bookmarks');
        await txn.delete('reading_stats');
        await txn.delete('book_notes');

        // 恢复books表
        if (backupData['books'] != null) {
          for (final book in backupData['books'] as List) {
            await txn.insert('books', book as Map<String, dynamic>);
          }
        }

        // 恢复bookmarks表
        if (backupData['bookmarks'] != null) {
          for (final bookmark in backupData['bookmarks'] as List) {
            await txn.insert('bookmarks', bookmark as Map<String, dynamic>);
          }
        }

        // 恢复reading_stats表
        if (backupData['reading_stats'] != null) {
          for (final stat in backupData['reading_stats'] as List) {
            await txn.insert('reading_stats', stat as Map<String, dynamic>);
          }
        }

        // 恢复book_notes表
        if (backupData['book_notes'] != null) {
          for (final note in backupData['book_notes'] as List) {
            await txn.insert('book_notes', note as Map<String, dynamic>);
          }
        }
      });

      // 恢复SharedPreferences
      if (backupData['preferences'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        final prefsData = backupData['preferences'] as Map<String, dynamic>;
        for (final entry in prefsData.entries) {
          final value = entry.value;
          if (value is String) {
            await prefs.setString(entry.key, value);
          } else if (value is int) {
            await prefs.setInt(entry.key, value);
          } else if (value is double) {
            await prefs.setDouble(entry.key, value);
          } else if (value is bool) {
            await prefs.setBool(entry.key, value);
          } else if (value is List<String>) {
            await prefs.setStringList(entry.key, value);
          }
        }
      }

      debugPrint('🔄 备份数据恢复完成');
    } catch (e) {
      debugPrint('❌ 恢复备份数据失败: $e');
      rethrow;
    }
  }

  /// 计算数据校验和
  String _calculateChecksum(Map<String, dynamic> data) {
    final jsonString = json.encode(data);
    final bytes = utf8.encode(jsonString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// 验证备份
  Future<bool> _validateBackup(Map<String, dynamic> backup) async {
    try {
      // 检查必要字段
      if (!backup.containsKey('data') || !backup.containsKey('checksum')) {
        return false;
      }

      // 验证校验和
      final data = backup['data'] as Map<String, dynamic>;
      final expectedChecksum = backup['checksum'] as String;
      final actualChecksum = _calculateChecksum(data);

      return expectedChecksum == actualChecksum;
    } catch (e) {
      debugPrint('❌ 验证备份失败: $e');
      return false;
    }
  }

  /// 验证数据库
  Future<bool> _validateDatabase() async {
    try {
      final db = await _databaseService.database;

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
      debugPrint('❌ 验证数据库失败: $e');
      return false;
    }
  }

  /// 验证缓存
  Future<bool> _validateCache() async {
    try {
      // 这里可以添加更复杂的缓存验证逻辑
      return true;
    } catch (e) {
      debugPrint('❌ 验证缓存失败: $e');
      return false;
    }
  }

  /// 验证设置
  Future<bool> _validateSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // 简单验证SharedPreferences是否可访问
      prefs.getKeys();
      return true;
    } catch (e) {
      debugPrint('❌ 验证设置失败: $e');
      return false;
    }
  }

  /// 验证备份文件
  Future<bool> _validateBackupFiles() async {
    try {
      if (_backupHistory.isEmpty) return true;

      // 验证最新备份文件
      final latestBackup = _backupHistory.last;
      final backupFile = await _getBackupFile(latestBackup.fileName);

      if (!await backupFile.exists()) {
        return false;
      }

      // 验证文件大小
      final actualSize = await backupFile.length();
      return actualSize == latestBackup.fileSize;
    } catch (e) {
      debugPrint('❌ 验证备份文件失败: $e');
      return false;
    }
  }

  /// 修复数据库
  Future<bool> _repairDatabase() async {
    try {
      // 这里可以添加数据库修复逻辑
      return true;
    } catch (e) {
      debugPrint('❌ 修复数据库失败: $e');
      return false;
    }
  }

  /// 修复缓存
  Future<bool> _repairCache() async {
    try {
      // 清理损坏的缓存
      await _cacheService.clearCache(persistImmediately: true);
      return true;
    } catch (e) {
      debugPrint('❌ 修复缓存失败: $e');
      return false;
    }
  }

  /// 获取最新备份文件名
  String? _getLatestBackupFileName() {
    if (_backupHistory.isEmpty) return null;
    return _backupHistory.last.fileName;
  }

  /// 加载备份历史
  Future<void> _loadBackupHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('backup_history');

      if (historyJson != null) {
        final historyData = json.decode(historyJson) as List;
        _backupHistory.clear();
        _backupHistory.addAll(
          historyData.map(
            (item) => BackupInfo.fromJson(item as Map<String, dynamic>),
          ),
        );

        // 更新最后备份时间
        if (_backupHistory.isNotEmpty) {
          _lastBackupTime = _backupHistory.last.timestamp;
        }
      }

      debugPrint('📜 加载备份历史: ${_backupHistory.length}个备份');
    } catch (e) {
      debugPrint('❌ 加载备份历史失败: $e');
    }
  }

  /// 保存备份历史
  Future<void> _saveBackupHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final historyData =
          _backupHistory.map((backup) => backup.toJson()).toList();
      await prefs.setString('backup_history', json.encode(historyData));

      debugPrint('💾 保存备份历史: ${_backupHistory.length}个备份');
    } catch (e) {
      debugPrint('❌ 保存备份历史失败: $e');
    }
  }

  /// 清理旧备份
  Future<void> _cleanupOldBackups() async {
    try {
      if (_backupHistory.length <= _maxBackupFiles) return;

      // 按时间排序
      _backupHistory.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      // 删除多余的备份文件
      while (_backupHistory.length > _maxBackupFiles) {
        final oldestBackup = _backupHistory.removeAt(0);
        final backupFile = await _getBackupFile(oldestBackup.fileName);

        if (await backupFile.exists()) {
          await backupFile.delete();
          debugPrint('🗑️ 删除旧备份: ${oldestBackup.fileName}');
        }
      }

      // 保存更新后的历史
      await _saveBackupHistory();
    } catch (e) {
      debugPrint('❌ 清理旧备份失败: $e');
    }
  }
}

/// 备份信息模型
class BackupInfo {
  final String fileName;
  final DateTime timestamp;
  final int fileSize;
  final String checksum;

  const BackupInfo({
    required this.fileName,
    required this.timestamp,
    required this.fileSize,
    required this.checksum,
  });

  factory BackupInfo.fromJson(Map<String, dynamic> json) {
    return BackupInfo(
      fileName: json['fileName'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      fileSize: json['fileSize'] as int,
      checksum: json['checksum'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'fileName': fileName,
      'timestamp': timestamp.toIso8601String(),
      'fileSize': fileSize,
      'checksum': checksum,
    };
  }
}

/// 数据验证结果
class DataValidationResult {
  bool databaseValid = true;
  bool cacheValid = true;
  bool settingsValid = true;
  bool backupsValid = true;
  bool overallValid = true;

  Map<String, bool> toMap() {
    return {
      'database': databaseValid,
      'cache': cacheValid,
      'settings': settingsValid,
      'backups': backupsValid,
      'overall': overallValid,
    };
  }
}
