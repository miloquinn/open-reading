// 文件说明：统一的无封面书籍封面绘制与持久化服务。
// 技术要点：同一绘制器同时服务于 PNG 生成和 UI 实时兜底，样式仅由书名与作者决定。
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// 为没有真实封面的书籍生成简约封面。
class CoverGenerator {
  /// 生成 PNG 封面。
  ///
  /// [format] 为兼容旧调用保留，但不再影响视觉结果。这样同一本书无论来自
  /// 本地文件还是在线书源，只要书名和作者一致，就会得到相同封面。
  ///
  /// [fallbackTitle] 在 [title] 为空时作为兜底标题绘制，由 UI 调用方通过
  /// `context.l10n.bookUntitled` 传入；服务层调用方可不传（默认空串）。
  static Future<Uint8List> generateTextCover({
    required String title,
    String author = '',
    String format = '',
    String fallbackTitle = '',
    int width = 400,
    int height = 600,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final painter = GeneratedBookCoverPainter(
      title: title,
      author: author,
      fallbackTitle: fallbackTitle,
    );
    painter.paint(canvas, Size(width.toDouble(), height.toDouble()));

    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    if (byteData == null) {
      throw StateError('无法编码生成的书籍封面');
    }
    return byteData.buffer.asUint8List();
  }

  /// 将封面保存到应用文档目录下的 `covers/`。
  static Future<String> saveCover(
    Uint8List imageBytes,
    String bookFileName, {
    Directory? documentsDirectory,
    String fileTag = 'generated',
    String fileExtension = 'png',
  }) async {
    final documentsDir =
        documentsDirectory ?? await getApplicationDocumentsDirectory();
    final coversDir = Directory(join(documentsDir.path, 'covers'));
    await coversDir.create(recursive: true);

    final safeBaseName = _safeFileName(basenameWithoutExtension(bookFileName));
    final fingerprint = _stableHash(bookFileName).toRadixString(16);
    final safeTag = _safeFileName(fileTag);
    final safeExtension = fileExtension.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    final coverPath = join(
      coversDir.path,
      '${safeBaseName}_${fingerprint}_$safeTag.${safeExtension.isEmpty ? 'img' : safeExtension}',
    );
    await File(coverPath).writeAsBytes(imageBytes, flush: true);
    return coverPath;
  }

  static String _safeFileName(String value) {
    final safe = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    return safe.isEmpty ? 'book' : safe.substring(0, safe.length.clamp(0, 80));
  }
}

/// 可供图片生成器与 Flutter UI 共同复用的封面绘制器。
class GeneratedBookCoverPainter extends CustomPainter {
  GeneratedBookCoverPainter({
    required String title,
    required String author,
    this.fallbackTitle = '',
  }) : title = _normalizeTitle(title, fallbackTitle),
       author = _normalizeAuthor(author),
       palette = GeneratedBookCoverPalette.resolve(title, author);

  final String title;
  final String author;
  final String fallbackTitle;
  final GeneratedBookCoverPalette palette;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..color = palette.background);

    // 克制的装饰元素：只保留细书脊与短横线。
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width * 0.045, size.height),
      Paint()..color = palette.accent,
    );
    canvas.drawRect(
      Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.115,
        size.width * 0.18,
        size.height * 0.012,
      ),
      Paint()..color = palette.accent,
    );
    _paintText(
      canvas: canvas,
      rect: Rect.fromLTWH(
        size.width * 0.14,
        size.height * 0.235,
        size.width * 0.72,
        size.height * 0.47,
      ),
      text: title,
      fontSize: _titleFontSize(title, size.width),
      maxLines: 4,
      color: palette.foreground,
      fontWeight: FontWeight.w700,
      textAlign: TextAlign.left,
      height: 1.2,
      verticallyCenter: true,
    );

    if (author.isNotEmpty) {
      canvas.drawLine(
        Offset(size.width * 0.14, size.height * 0.79),
        Offset(size.width * 0.45, size.height * 0.79),
        Paint()
          ..color = palette.accent
          ..strokeWidth = (size.width * 0.006).clamp(1, 3),
      );
      _paintText(
        canvas: canvas,
        rect: Rect.fromLTWH(
          size.width * 0.14,
          size.height * 0.82,
          size.width * 0.72,
          size.height * 0.1,
        ),
        text: author,
        fontSize: size.width * 0.052,
        maxLines: 1,
        color: palette.secondaryForeground,
        fontWeight: FontWeight.w500,
        textAlign: TextAlign.left,
        height: 1.1,
        verticallyCenter: true,
      );
    }

    canvas.drawRect(
      bounds.deflate((size.width * 0.018).clamp(1, 5)),
      Paint()
        ..color = palette.border
        ..style = PaintingStyle.stroke
        ..strokeWidth = (size.width * 0.004).clamp(0.8, 2),
    );
  }

  @override
  bool shouldRepaint(covariant GeneratedBookCoverPainter oldDelegate) {
    return oldDelegate.title != title || oldDelegate.author != author;
  }
}

@immutable
class GeneratedBookCoverPalette {
  const GeneratedBookCoverPalette({
    required this.background,
    required this.foreground,
    required this.secondaryForeground,
    required this.accent,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color secondaryForeground;
  final Color accent;
  final Color border;

  static const values = <GeneratedBookCoverPalette>[
    GeneratedBookCoverPalette(
      background: Color(0xFFF2EBDD),
      foreground: Color(0xFF25231F),
      secondaryForeground: Color(0xFF625C52),
      accent: Color(0xFFB5523C),
      border: Color(0x3325231F),
    ),
    GeneratedBookCoverPalette(
      background: Color(0xFFE8EEF0),
      foreground: Color(0xFF1E2A30),
      secondaryForeground: Color(0xFF56666D),
      accent: Color(0xFF3F7180),
      border: Color(0x331E2A30),
    ),
    GeneratedBookCoverPalette(
      background: Color(0xFFEAE9E1),
      foreground: Color(0xFF24271F),
      secondaryForeground: Color(0xFF5E6354),
      accent: Color(0xFF63724B),
      border: Color(0x3324271F),
    ),
    GeneratedBookCoverPalette(
      background: Color(0xFFF0E8EC),
      foreground: Color(0xFF2C2228),
      secondaryForeground: Color(0xFF695760),
      accent: Color(0xFF8A526B),
      border: Color(0x332C2228),
    ),
    GeneratedBookCoverPalette(
      background: Color(0xFFE9E7F0),
      foreground: Color(0xFF262331),
      secondaryForeground: Color(0xFF5D586D),
      accent: Color(0xFF66588E),
      border: Color(0x33262331),
    ),
    GeneratedBookCoverPalette(
      background: Color(0xFFF1E9DF),
      foreground: Color(0xFF2B241E),
      secondaryForeground: Color(0xFF6A5D51),
      accent: Color(0xFF9A673D),
      border: Color(0x332B241E),
    ),
  ];

  static GeneratedBookCoverPalette resolve(String title, String author) {
    final seed = '${_normalizeTitle(title)}|${_normalizeAuthor(author)}';
    return values[_stableHash(seed) % values.length];
  }
}

void _paintText({
  required Canvas canvas,
  required Rect rect,
  required String text,
  required double fontSize,
  required int maxLines,
  required Color color,
  required FontWeight fontWeight,
  required TextAlign textAlign,
  double height = 1.0,
  bool verticallyCenter = false,
}) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        // 字体不内置后改用系统字体；之前硬编码 'SourceHanSansCN' 在字体未下载
        // 时也会回退到系统字体，行为等价但 null 让意图更清晰，避免对在线字体
        // 下载状态的隐式依赖。
        fontFamily: null,
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height,
      ),
    ),
    textDirection: TextDirection.ltr,
    textAlign: textAlign,
    maxLines: maxLines,
    ellipsis: '…',
  )..layout(maxWidth: rect.width);

  final dy = verticallyCenter
      ? rect.top + ((rect.height - painter.height) / 2).clamp(0, rect.height)
      : rect.top;
  painter.paint(canvas, Offset(rect.left, dy));
}

String _normalizeTitle(String title, [String fallbackTitle = '']) {
  final normalized = title.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return fallbackTitle;
  return normalized.runes.length <= 72
      ? normalized
      : '${String.fromCharCodes(normalized.runes.take(72))}…';
}

String _normalizeAuthor(String author) {
  final normalized = author.trim().replaceAll(RegExp(r'\s+'), ' ');
  final lower = normalized.toLowerCase();
  if (normalized.isEmpty ||
      lower == 'unknown' ||
      lower == 'unknown author' ||
      lower == 'null' ||
      lower == 'none' ||
      normalized == '未知' ||
      normalized == '未知作者') {
    return '';
  }
  return normalized.runes.length <= 28
      ? normalized
      : '${String.fromCharCodes(normalized.runes.take(28))}…';
}

double _titleFontSize(String title, double width) {
  final length = title.runes.length;
  final scale = switch (length) {
    <= 8 => 0.14,
    <= 16 => 0.115,
    <= 28 => 0.09,
    <= 44 => 0.075,
    _ => 0.065,
  };
  return width * scale;
}

int _stableHash(String value) {
  var hash = 0x811C9DC5;
  for (final byte in value.codeUnits) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0x7FFFFFFF;
  }
  return hash;
}
