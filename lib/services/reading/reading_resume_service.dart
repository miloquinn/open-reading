// 文件说明：阅读恢复服务，记录进行中的阅读会话，供启动时自动回到上次阅读页面。
// 技术要点：服务层、SharedPreferences；正常关闭阅读器时清除会话，阅读中杀进程则保留，
// 下次启动由 main.dart 消费记录并重新打开书籍（阅读位置由各阅读器自身持久化恢复）。

import 'package:shared_preferences/shared_preferences.dart';

/// 「启动时回到上次阅读」的会话记录。
///
/// 语义：阅读器打开时记下书库书籍 ID，正常关闭（返回书架）时清除；
/// 应用在阅读中退出/被杀时记录保留，下次启动据此自动回到阅读页。
/// 记录一经启动消费即清除，避免陈旧会话在开关稍后打开时误触发。
class ReadingResumeService {
  ReadingResumeService._();

  /// 设置开关（默认关闭），设置页「阅读设置」读写。
  static const String enabledPreferenceKey = 'autoResumeReadingOnLaunch';

  /// 进行中阅读会话的书库书籍 ID。
  static const String _sessionBookIdKey = 'activeReadingSessionBookId';

  /// 阅读器进入时调用；[bookId] 为空（书不在书库，例如书源试读）时不记录。
  static Future<void> markReading(int? bookId) async {
    if (bookId == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sessionBookIdKey, bookId);
  }

  /// 阅读器正常关闭时调用；只清除自己的记录，避免误清其他阅读器刚写入的会话。
  static Future<void> markClosed(int? bookId) async {
    if (bookId == null) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_sessionBookIdKey) != bookId) return;
    await prefs.remove(_sessionBookIdKey);
  }

  /// 启动时消费待恢复的会话：无论开关状态都清除记录（一次性语义），
  /// 仅在开关开启且存在记录时返回书籍 ID。
  static Future<int?> takePendingResumeBookId() async {
    final prefs = await SharedPreferences.getInstance();
    final bookId = prefs.getInt(_sessionBookIdKey);
    if (bookId != null) {
      await prefs.remove(_sessionBookIdKey);
    }
    final enabled = prefs.getBool(enabledPreferenceKey) ?? false;
    return enabled ? bookId : null;
  }
}
