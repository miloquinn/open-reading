import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class BookSourceReadingProgress {
  final String chapterId;
  final int chapterIndex;
  final double chapterProgress;
  final DateTime updatedAt;

  const BookSourceReadingProgress({
    required this.chapterId,
    required this.chapterIndex,
    required this.chapterProgress,
    required this.updatedAt,
  });

  factory BookSourceReadingProgress.fromJson(Map<String, dynamic> json) {
    return BookSourceReadingProgress(
      chapterId: (json['chapterId'] as String?)?.trim() ?? '',
      chapterIndex: (json['chapterIndex'] as num?)?.toInt() ?? 0,
      chapterProgress:
          ((json['chapterProgress'] as num?)?.toDouble() ?? 0).clamp(0, 1),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
    );
  }

  Map<String, dynamic> toJson() => {
        'chapterId': chapterId,
        'chapterIndex': chapterIndex,
        'chapterProgress': chapterProgress.clamp(0, 1),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };
}

class BookSourceReadingProgressStore {
  static const _prefix = 'book_source_reading_progress_v1';

  const BookSourceReadingProgressStore();

  Future<BookSourceReadingProgress?> load({
    required String sourceId,
    required String bookId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(sourceId, bookId));
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      return BookSourceReadingProgress.fromJson(decoded);
    } catch (_) {
      return null;
    }
  }

  Future<void> save({
    required String sourceId,
    required String bookId,
    required BookSourceReadingProgress progress,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key(sourceId, bookId),
      jsonEncode(progress.toJson()),
    );
  }

  String _key(String sourceId, String bookId) =>
      '$_prefix:${Uri.encodeComponent(sourceId)}:${Uri.encodeComponent(bookId)}';
}
