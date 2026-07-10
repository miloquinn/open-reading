// 文件说明：同步辅助工具，负责设备标识、序列化和同步通用函数。
// 技术要点：服务层、SharedPreferences、UUID、JSON、文件系统、Flutter。

import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// WebDAV 同步工具类
///
/// 提供设备识别、时间戳比较、数据合并等同步辅助功能
class SyncUtils {
  static const String _deviceIdKey = 'webdav_device_id';
  static const Uuid _uuid = Uuid();

  /// 获取或生成设备唯一标识
  ///
  /// 每个设备在首次使用同步功能时会生成一个唯一 ID，
  /// 用于识别数据来源设备和解决冲突
  static Future<String> getDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);

      if (deviceId == null || deviceId.isEmpty) {
        // 生成新的设备 ID
        deviceId = _generateDeviceId();
        await prefs.setString(_deviceIdKey, deviceId);
        debugPrint('生成新设备 ID: $deviceId');
      }

      return deviceId;
    } catch (e) {
      debugPrint('获取设备 ID 失败: $e');
      // 降级方案：生成临时 ID
      return _uuid.v4();
    }
  }

  /// 生成设备唯一标识
  ///
  /// 优先使用平台信息，配合 UUID 生成
  static String _generateDeviceId() {
    final buffer = StringBuffer();
    buffer.write('xxread-');

    // 添加平台标识
    if (kIsWeb) {
      buffer.write('web-');
    } else if (Platform.isAndroid) {
      buffer.write('android-');
    } else if (Platform.isIOS) {
      buffer.write('ios-');
    } else if (Platform.isMacOS) {
      buffer.write('macos-');
    } else if (Platform.isWindows) {
      buffer.write('windows-');
    } else if (Platform.isLinux) {
      buffer.write('linux-');
    } else {
      buffer.write('unknown-');
    }

    // 添加 UUID
    buffer.write(_uuid.v4().substring(0, 8));
    return buffer.toString();
  }

  /// 比较两个时间戳字符串
  ///
  /// 返回值：
  /// - 负数：localTime 较新
  /// - 0：时间相同
  /// - 正数：remoteTime 较新
  ///
  /// 如果任一时间为 null，则认为另一个优先
  static int compareTimestamps(String? localTime, String? remoteTime) {
    if (localTime == null && remoteTime == null) return 0;
    if (localTime == null) return 1; // 远程优先
    if (remoteTime == null) return -1; // 本地优先

    try {
      final local = DateTime.parse(localTime);
      final remote = DateTime.parse(remoteTime);
      return remote.compareTo(local);
    } catch (e) {
      debugPrint('解析时间戳失败: $e');
      return 0;
    }
  }

  /// 判断远程时间戳是否较新
  static bool isRemoteNewer(String? localTime, String? remoteTime) {
    return compareTimestamps(localTime, remoteTime) > 0;
  }

  /// 判断本地时间戳是否较新
  static bool isLocalNewer(String? localTime, String? remoteTime) {
    return compareTimestamps(localTime, remoteTime) < 0;
  }

  /// 按时间戳合并两个字符串值
  ///
  /// 根据 updateTime 选择较新的值
  static String? mergeStringByTimestamp(
    String? localValue,
    String? remoteValue,
    String? localUpdateTime,
    String? remoteUpdateTime,
  ) {
    // 如果值相同，直接返回
    if (localValue == remoteValue) return localValue;

    // 如果有一个为空，返回非空的
    if (localValue == null || localValue.isEmpty) return remoteValue;
    if (remoteValue == null || remoteValue.isEmpty) return localValue;

    // 根据更新时间选择
    return isRemoteNewer(localUpdateTime, remoteUpdateTime)
        ? remoteValue
        : localValue;
  }

  /// 按时间戳合并两个整数值
  ///
  /// 用于合并页码等数值，选择较大的值
  static int? mergeIntByTimestamp(
    int? localValue,
    int? remoteValue,
    String? localUpdateTime,
    String? remoteUpdateTime,
  ) {
    // 如果有一个为空，返回非空的
    if (localValue == null) return remoteValue;
    if (remoteValue == null) return localValue;

    // 对于阅读进度等数值，通常取较大值（用户倾向于向前阅读）
    // 但如果远程更新时间较新，使用远程值
    return isRemoteNewer(localUpdateTime, remoteUpdateTime)
        ? remoteValue
        : (localValue > remoteValue ? localValue : remoteValue);
  }

  /// 生成内容哈希键（用于去重）
  ///
  /// 根据指定字段生成唯一键，用于识别重复记录
  static String generateHashKey(
      Map<String, dynamic> data, List<String> fields) {
    final buffer = StringBuffer();
    for (final field in fields) {
      final value = data[field];
      if (value != null) {
        if (buffer.isNotEmpty) buffer.write(':');
        buffer.write(value.toString());
      }
    }
    return buffer.toString();
  }

  /// 书签去重键：bookId + pageNumber
  static String generateBookmarkKey(int bookId, int pageNumber) {
    return 'bookmark:$bookId:$pageNumber';
  }

  /// 笔记去重键：bookId + cfi + startOffset + endOffset
  static String generateNoteKey(
    int bookId,
    String cfi,
    int? startOffset,
    int? endOffset,
  ) {
    return 'note:$bookId:$cfi:$startOffset:$endOffset';
  }

  /// 进度去重键：bookId
  static String generateProgressKey(int bookId) {
    return 'progress:$bookId';
  }

  /// 统计去重键：date
  static String generateStatsKey(String date) {
    return 'stats:$date';
  }

  /// 格式化同步时间戳
  static String formatSyncTimestamp(DateTime timestamp) {
    return timestamp.toIso8601String();
  }

  /// 解析同步时间戳
  static DateTime? parseSyncTimestamp(String? timestamp) {
    if (timestamp == null || timestamp.isEmpty) return null;
    try {
      return DateTime.parse(timestamp);
    } catch (e) {
      debugPrint('解析同步时间戳失败: $e');
      return null;
    }
  }

  /// 计算同步耗时描述
  static String formatSyncDuration(Duration duration) {
    if (duration.inSeconds < 60) {
      return '${duration.inSeconds}秒';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes}分${duration.inSeconds % 60}秒';
    } else {
      return '${duration.inHours}小时${duration.inMinutes % 60}分';
    }
  }

  /// 格式化文件大小
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
    }
  }

  /// 检查是否为有效的同步数据版本
  static bool isValidSyncVersion(int version) {
    return version >= 1 && version <= 10; // 支持版本 1-10
  }

  /// 获取同步数据的默认版本号
  static int getDefaultSyncVersion() {
    return 1;
  }

  /// 合并两个列表，按指定键去重
  ///
  /// [localList] 本地数据列表
  /// [remoteList] 远程数据列表
  /// [keyGenerator] 生成去重键的函数
  /// [comparator] 比较函数，返回 true 表示保留远程数据
  /// [merger] 合并函数，当需要合并时调用
  static List<Map<String, dynamic>> mergeListsWithDeduplication<T>({
    required List<Map<String, dynamic>> localList,
    required List<Map<String, dynamic>> remoteList,
    required String Function(Map<String, dynamic>) keyGenerator,
    required bool Function(
            Map<String, dynamic> local, Map<String, dynamic> remote)
        comparator,
    Map<String, dynamic> Function(
            Map<String, dynamic> local, Map<String, dynamic> remote)?
        merger,
  }) {
    final mergedMap = <String, Map<String, dynamic>>{};

    // 添加本地数据
    for (final item in localList) {
      final key = keyGenerator(item);
      mergedMap[key] = item;
    }

    // 合并远程数据
    for (final remoteItem in remoteList) {
      final key = keyGenerator(remoteItem);

      if (mergedMap.containsKey(key)) {
        final localItem = mergedMap[key]!;

        // 需要合并时
        if (merger != null && comparator(localItem, remoteItem)) {
          mergedMap[key] = merger(localItem, remoteItem);
        } else if (comparator(localItem, remoteItem)) {
          // 使用远程数据
          mergedMap[key] = remoteItem;
        }
        // 否则保留本地数据
      } else {
        // 新增远程数据
        mergedMap[key] = remoteItem;
      }
    }

    return mergedMap.values.toList();
  }
}
