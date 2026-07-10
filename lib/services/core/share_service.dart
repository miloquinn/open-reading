// 文件说明：分享服务，统一生成分享文本并调用系统分享能力。
// 技术要点：服务层、Share Plus、Intl、Flutter。

import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

/// 增强分享服务
/// 提供丰富的内容分享功能，支持多种分享格式和模板
class ShareService extends ChangeNotifier {
  /// 分享当前页面内容
  Future<void> shareCurrentPage({
    required String bookTitle,
    required String content,
    required int currentPage,
    required int totalPages,
  }) async {
    try {
      final formattedContent = _formatPageContent(
        bookTitle: bookTitle,
        content: content,
        currentPage: currentPage,
        totalPages: totalPages,
      );

      await SharePlus.instance.share(ShareParams(text: formattedContent));

      debugPrint('分享页面内容成功');
    } catch (e) {
      debugPrint('分享页面内容失败: $e');
    }
  }

  /// 分享选中的文本
  Future<void> shareSelectedText({
    required String bookTitle,
    required String selectedText,
    required String author,
  }) async {
    try {
      final formattedContent = _formatSelectedText(
        bookTitle: bookTitle,
        selectedText: selectedText,
        author: author,
      );

      await SharePlus.instance.share(ShareParams(text: formattedContent));

      debugPrint('分享选中文本成功');
    } catch (e) {
      debugPrint('分享选中文本失败: $e');
    }
  }

  /// 分享阅读进度
  Future<void> shareReadingProgress({
    required String bookTitle,
    required String author,
    required double progressPercentage,
    required int currentPage,
    required int totalPages,
    required Duration readingTime,
  }) async {
    try {
      final formattedContent = _formatReadingProgress(
        bookTitle: bookTitle,
        author: author,
        progressPercentage: progressPercentage,
        currentPage: currentPage,
        totalPages: totalPages,
        readingTime: readingTime,
      );

      await SharePlus.instance.share(ShareParams(text: formattedContent));

      debugPrint('分享阅读进度成功');
    } catch (e) {
      debugPrint('分享阅读进度失败: $e');
    }
  }

  /// 分享书籍推荐
  Future<void> shareBookRecommendation({
    required String bookTitle,
    required String author,
    required String description,
    required double rating,
  }) async {
    try {
      final formattedContent = _formatBookRecommendation(
        bookTitle: bookTitle,
        author: author,
        description: description,
        rating: rating,
      );

      await SharePlus.instance.share(ShareParams(text: formattedContent));

      debugPrint('分享书籍推荐成功');
    } catch (e) {
      debugPrint('分享书籍推荐失败: $e');
    }
  }

  /// 分享笔记内容
  Future<void> shareNote({
    required String bookTitle,
    required String noteContent,
    required String context,
    required DateTime createTime,
  }) async {
    try {
      final formattedContent = _formatNote(
        bookTitle: bookTitle,
        noteContent: noteContent,
        context: context,
        createTime: createTime,
      );

      await SharePlus.instance.share(ShareParams(text: formattedContent));

      debugPrint('分享笔记成功');
    } catch (e) {
      debugPrint('分享笔记失败: $e');
    }
  }

  /// 分享阅读统计
  Future<void> shareReadingStatistics({
    required int totalBooksRead,
    required Duration totalReadingTime,
    required int totalPages,
    required String favoriteGenre,
  }) async {
    try {
      final formattedContent = _formatReadingStatistics(
        totalBooksRead: totalBooksRead,
        totalReadingTime: totalReadingTime,
        totalPages: totalPages,
        favoriteGenre: favoriteGenre,
      );

      await SharePlus.instance.share(ShareParams(text: formattedContent));

      debugPrint('分享阅读统计成功');
    } catch (e) {
      debugPrint('分享阅读统计失败: $e');
    }
  }

  /// 格式化页面内容
  String _formatPageContent({
    required String bookTitle,
    required String content,
    required int currentPage,
    required int totalPages,
  }) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy年MM月dd日').format(now);

    return '''📖 《$bookTitle》

${_cleanContent(content)}

📍 第 $currentPage 页 / 共 $totalPages 页
📅 分享于 $formattedDate
📱 来自小元阅读器

────────────────
愿你在书中找到属于自己的世界 ✨''';
  }

  /// 格式化选中文本
  String _formatSelectedText({
    required String bookTitle,
    required String selectedText,
    required String author,
  }) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy年MM月dd日').format(now);

    return '''📝 摘录自《$bookTitle》

"${_cleanContent(selectedText)}"

✍️ 作者：$author
📅 摘录于 $formattedDate
📱 来自小元阅读器

────────────────
每一段文字都可能改变一个人的人生 📚''';
  }

  /// 格式化阅读进度
  String _formatReadingProgress({
    required String bookTitle,
    required String author,
    required double progressPercentage,
    required int currentPage,
    required int totalPages,
    required Duration readingTime,
  }) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy年MM月dd日').format(now);
    final readingHours = readingTime.inMinutes / 60;

    return '''📊 阅读进度更新

📖 《$bookTitle》
✍️ 作者：$author

📈 进度：${progressPercentage.toStringAsFixed(1)}%
📍 第 $currentPage 页 / 共 $totalPages 页
⏰ 已阅读：${readingHours.toStringAsFixed(1)} 小时

📅 更新于 $formattedDate
📱 来自小元阅读器

────────────────
坚持阅读，收获智慧 🌱''';
  }

  /// 格式化书籍推荐
  String _formatBookRecommendation({
    required String bookTitle,
    required String author,
    required String description,
    required double rating,
  }) {
    final stars = '⭐' * rating.round();
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy年MM月dd日').format(now);

    return '''📚 好书推荐

📖 《$bookTitle》
✍️ 作者：$author
⭐ 评分：$stars (${rating.toStringAsFixed(1)}/5.0)

📝 推荐理由：
${_cleanContent(description)}

📅 推荐于 $formattedDate
📱 来自小元阅读器

────────────────
好书如朋友，值得分享 ✨''';
  }

  /// 格式化笔记内容
  String _formatNote({
    required String bookTitle,
    required String noteContent,
    required String context,
    required DateTime createTime,
  }) {
    final formattedDate = DateFormat('yyyy年MM月dd日').format(createTime);

    return '''📝 读书笔记

📖 《$bookTitle》

📄 原文：
"${_cleanContent(context)}"

💭 我的思考：
${_cleanContent(noteContent)}

📅 记录于 $formattedDate
📱 来自小元阅读器

────────────────
思考让阅读更有意义 🤔''';
  }

  /// 格式化阅读统计
  String _formatReadingStatistics({
    required int totalBooksRead,
    required Duration totalReadingTime,
    required int totalPages,
    required String favoriteGenre,
  }) {
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy年MM月dd日').format(now);
    final totalHours = totalReadingTime.inMinutes / 60;

    return '''📈 我的阅读统计

📚 已读书籍：$totalBooksRead 本
📖 总页数：$totalPages 页
⏰ 阅读时长：${totalHours.toStringAsFixed(1)} 小时
❤️ 偏爱类型：$favoriteGenre

📅 统计于 $formattedDate
📱 来自小元阅读器

────────────────
阅读是心灵的旅行 🌟''';
  }

  /// 清理内容文本
  String _cleanContent(String content) {
    return content
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ') // 合并多个空白字符
        .replaceAll(RegExp(r'\n\s*\n'), '\n\n'); // 规范化换行
  }

  /// 获取分享选项
  List<ShareOption> getShareOptions() {
    return const [
      ShareOption(
        icon: '📄',
        title: '当前页面',
        description: '分享正在阅读的页面内容',
        type: ShareType.currentPage,
      ),
      ShareOption(
        icon: '📝',
        title: '选中文本',
        description: '分享选中的精彩片段',
        type: ShareType.selectedText,
      ),
      ShareOption(
        icon: '📊',
        title: '阅读进度',
        description: '分享当前的阅读进度',
        type: ShareType.progress,
      ),
      ShareOption(
        icon: '📚',
        title: '书籍推荐',
        description: '推荐这本好书给朋友',
        type: ShareType.recommendation,
      ),
      ShareOption(
        icon: '💭',
        title: '读书笔记',
        description: '分享你的思考和感悟',
        type: ShareType.note,
      ),
    ];
  }
}

/// 分享选项
class ShareOption {
  final String icon;
  final String title;
  final String description;
  final ShareType type;

  const ShareOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.type,
  });
}

/// 分享类型枚举
enum ShareType {
  currentPage,
  selectedText,
  progress,
  recommendation,
  note,
  statistics,
}
