// 文件说明：问AI 对话历史存储，供 AI 页面查看与删除历史会话。
// 技术要点：SharedPreferences JSON、ChangeNotifier 单例、容量上限裁剪。

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiChatHistoryMessage {
  const AiChatHistoryMessage({
    required this.role,
    required this.text,
    required this.at,
  });

  /// `user` 或 `assistant`。
  final String role;

  /// 界面上展示的文本（助手消息为原始 Markdown）。
  final String text;

  final DateTime at;

  Map<String, dynamic> toJson() => {
    'role': role,
    'text': text,
    'at': at.toUtc().toIso8601String(),
  };

  static AiChatHistoryMessage? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final role = json['role'];
    final text = json['text'];
    if (role is! String || text is! String) return null;
    final at = DateTime.tryParse(json['at'] as String? ?? '');
    return AiChatHistoryMessage(
      role: role,
      text: text,
      at: (at ?? DateTime.now()).toLocal(),
    );
  }
}

class AiChatHistorySession {
  const AiChatHistorySession({
    required this.id,
    required this.bookTitle,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
    this.bookId,
  });

  final String id;
  final String bookTitle;

  /// 关联书籍的稳定 ID（`Book.id` 的字符串形式），用于继续对话时恢复上下文。
  final String? bookId;

  final DateTime createdAt;
  final DateTime updatedAt;
  final List<AiChatHistoryMessage> messages;

  /// 列表标题：第一条用户提问。
  String get firstQuestion {
    for (final message in messages) {
      if (message.role == 'user') return message.text;
    }
    return '';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'bookTitle': bookTitle,
    if (bookId != null) 'bookId': bookId,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'updatedAt': updatedAt.toUtc().toIso8601String(),
    'messages': messages
        .map((message) => message.toJson())
        .toList(growable: false),
  };

  static AiChatHistorySession? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final id = json['id'];
    if (id is! String || id.isEmpty) return null;
    final createdAt = DateTime.tryParse(json['createdAt'] as String? ?? '');
    final updatedAt = DateTime.tryParse(json['updatedAt'] as String? ?? '');
    final messages = <AiChatHistoryMessage>[];
    final rawMessages = json['messages'];
    if (rawMessages is List) {
      for (final raw in rawMessages) {
        final message = AiChatHistoryMessage.fromJson(raw);
        if (message != null) messages.add(message);
      }
    }
    if (messages.isEmpty) return null;
    final bookId = json['bookId'];
    return AiChatHistorySession(
      id: id,
      bookTitle: json['bookTitle'] as String? ?? '',
      bookId: bookId is String && bookId.isNotEmpty ? bookId : null,
      createdAt: (createdAt ?? DateTime.now()).toLocal(),
      updatedAt: (updatedAt ?? createdAt ?? DateTime.now()).toLocal(),
      messages: List<AiChatHistoryMessage>.unmodifiable(messages),
    );
  }
}

/// 全局问AI 历史存储：会话按最近更新排序，超出上限时裁掉最旧的会话。
class AiChatHistoryStore extends ChangeNotifier {
  AiChatHistoryStore._();

  static final AiChatHistoryStore _instance = AiChatHistoryStore._();

  factory AiChatHistoryStore() => _instance;

  static const String _prefsKey = 'reader_ai_chat_history_v1';
  static const int maxSessions = 100;

  List<AiChatHistorySession> _sessions = const [];
  bool _loaded = false;
  Future<void>? _loading;

  /// 仅供测试：清空内存态，让下一次 ensureLoaded 重新从持久层读取。
  @visibleForTesting
  void debugResetForTest() {
    _sessions = const [];
    _loaded = false;
    _loading = null;
  }

  bool get isLoaded => _loaded;

  /// 最近更新在前的会话列表。
  List<AiChatHistorySession> get sessions => _sessions;

  Future<void> ensureLoaded() {
    if (_loaded) return Future.value();
    return _loading ??= _load();
  }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      final sessions = <AiChatHistorySession>[];
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final item in decoded) {
            final session = AiChatHistorySession.fromJson(item);
            if (session != null) sessions.add(session);
          }
        }
      }
      sessions.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _sessions = List<AiChatHistorySession>.unmodifiable(sessions);
    } catch (error) {
      debugPrint('load ai chat history failed: $error');
      _sessions = const [];
    } finally {
      _loaded = true;
      _loading = null;
      notifyListeners();
    }
  }

  Future<void> upsertSession(AiChatHistorySession session) async {
    await ensureLoaded();
    final next = _sessions
        .where((existing) => existing.id != session.id)
        .toList();
    next.insert(0, session);
    if (next.length > maxSessions) {
      next.removeRange(maxSessions, next.length);
    }
    _sessions = List<AiChatHistorySession>.unmodifiable(next);
    notifyListeners();
    await _persist();
  }

  Future<void> deleteSession(String id) async {
    await ensureLoaded();
    final next = _sessions.where((session) => session.id != id).toList();
    if (next.length == _sessions.length) return;
    _sessions = List<AiChatHistorySession>.unmodifiable(next);
    notifyListeners();
    await _persist();
  }

  Future<void> clearAll() async {
    await ensureLoaded();
    if (_sessions.isEmpty) return;
    _sessions = const [];
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _prefsKey,
        jsonEncode(
          _sessions.map((session) => session.toJson()).toList(growable: false),
        ),
      );
    } catch (error) {
      debugPrint('persist ai chat history failed: $error');
    }
  }
}
