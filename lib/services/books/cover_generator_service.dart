// 文件说明：封面生成服务，基于标题与颜色方案生成默认封面图片。
// 技术要点：服务层、Path、Path Provider、文件系统、渲染层、Flutter。

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';

/// 封面生成器
///
/// 为没有封面的书籍生成美观的默认封面
class CoverGenerator {
  /// 生成文本封面
  ///
  /// [title] 书名
  /// [author] 作者
  /// [format] 文件格式（TXT, MOBI等）
  /// [width] 封面宽度
  /// [height] 封面高度
  /// Returns: 封面图片的字节数据
  static Future<Uint8List> generateTextCover({
    required String title,
    String author = 'Unknown',
    String format = 'TXT',
    int width = 400,
    int height = 600,
  }) async {
    final normalizedTitle = _normalizeTitle(title);
    final normalizedAuthor = _normalizeAuthor(author);
    final normalizedFormat = _normalizeFormat(format);

    // 创建画布
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final size = Size(width.toDouble(), height.toDouble());
    final bounds = Offset.zero & size;

    final colorScheme = _getColorScheme(
      format: normalizedFormat,
      seedText: '$normalizedTitle|$normalizedAuthor|$normalizedFormat',
    );

    // 背景渐变
    final backgroundPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: colorScheme.gradientColors,
        stops: const [0.0, 0.58, 1.0],
      ).createShader(bounds);
    canvas.drawRect(bounds, backgroundPaint);

    // 背景氛围光
    final glowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.7, -0.85),
        radius: 1.1,
        colors: [
          colorScheme.glowColor.withValues(alpha: 0.42),
          Colors.transparent,
        ],
      ).createShader(bounds);
    canvas.drawRect(bounds, glowPaint);

    // 左侧书脊
    final spineRect = Rect.fromLTWH(0, 0, size.width * 0.1, size.height);
    canvas.drawRect(spineRect, Paint()..color = colorScheme.spineColor);
    canvas.drawRect(
      spineRect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.white.withValues(alpha: 0.2),
            Colors.transparent,
          ],
        ).createShader(spineRect),
    );

    // 外框
    final frameRect = Rect.fromLTWH(
      size.width * 0.05,
      size.width * 0.05,
      size.width * 0.9,
      size.height - size.width * 0.1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(frameRect, const Radius.circular(14)),
      Paint()
        ..color = colorScheme.frameColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    // 大号首字母水印
    _drawMonogram(
      canvas,
      _extractMonogram(normalizedTitle, normalizedFormat),
      size,
      colorScheme.monogramColor,
    );

    // 标题区
    final titlePanelRect = Rect.fromLTWH(
      size.width * 0.14,
      size.height * 0.25,
      size.width * 0.74,
      size.height * 0.42,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(titlePanelRect, const Radius.circular(16)),
      Paint()..color = colorScheme.panelColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(titlePanelRect, const Radius.circular(16)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    _drawTextInRect(
      canvas: canvas,
      rect: titlePanelRect.deflate(size.width * 0.055),
      text: normalizedTitle,
      fontSize: _calculateTitleFontSize(normalizedTitle),
      maxLines: 4,
      color: colorScheme.titleColor,
      fontWeight: FontWeight.w700,
      textAlign: TextAlign.left,
      letterSpacing: 0.3,
      lineHeight: 1.26,
    );

    // 作者信息与底部分割线
    final dividerY = size.height * 0.79;
    canvas.drawLine(
      Offset(size.width * 0.14, dividerY),
      Offset(size.width * 0.88, dividerY),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.24)
        ..strokeWidth = 1.2,
    );
    final authorText = normalizedAuthor == '本地文本'
        ? normalizedAuthor
        : '作者 · $normalizedAuthor';
    _drawTextInRect(
      canvas: canvas,
      rect: Rect.fromLTWH(
        size.width * 0.14,
        dividerY + 14,
        size.width * 0.74,
        size.height * 0.1,
      ),
      text: authorText,
      fontSize: 20,
      maxLines: 1,
      color: colorScheme.secondaryTextColor,
      fontWeight: FontWeight.w500,
      textAlign: TextAlign.left,
      letterSpacing: 0.25,
      lineHeight: 1.2,
    );

    // 顶部格式标签
    _drawFormatTag(
      canvas: canvas,
      size: size,
      format: normalizedFormat,
      backgroundColor: colorScheme.tagBackgroundColor,
      textColor: colorScheme.tagTextColor,
    );

    // 轻微纹理
    _drawTextureLines(canvas, size);

    // 转换为图片
    final picture = recorder.endRecording();
    final image = await picture.toImage(width, height);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  static String _normalizeTitle(String title) {
    var normalized = title.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (normalized.isEmpty) {
      return '未命名文本';
    }
    if (normalized.length > 72) {
      normalized = '${normalized.substring(0, 72)}…';
    }
    return normalized;
  }

  static String _normalizeAuthor(String author) {
    final normalized = author.trim();
    if (normalized.isEmpty) {
      return '本地文本';
    }
    final lower = normalized.toLowerCase();
    if (lower == 'unknown' || lower == 'null' || lower == 'none') {
      return '本地文本';
    }
    if (normalized.length > 18) {
      return '${normalized.substring(0, 18)}…';
    }
    return normalized;
  }

  static String _normalizeFormat(String format) {
    final normalized = format.trim().toUpperCase();
    return normalized.isEmpty ? 'TXT' : normalized;
  }

  static void _drawMonogram(
    Canvas canvas,
    String monogram,
    Size size,
    Color color,
  ) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: monogram,
        style: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: size.width * 0.62,
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final offset = Offset(
      size.width * 0.56 - textPainter.width / 2,
      size.height * 0.14,
    );
    textPainter.paint(canvas, offset);
  }

  static void _drawTextInRect({
    required Canvas canvas,
    required Rect rect,
    required String text,
    required double fontSize,
    required int maxLines,
    required Color color,
    required FontWeight fontWeight,
    required TextAlign textAlign,
    required double lineHeight,
    double? letterSpacing,
  }) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: color,
          height: lineHeight,
          letterSpacing: letterSpacing,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: textAlign,
      maxLines: maxLines,
      ellipsis: '…',
    )..layout(maxWidth: rect.width);

    final y = rect.top + (rect.height - textPainter.height) / 2;
    final maxY = rect.bottom - textPainter.height;
    final dy =
        (maxY >= rect.top ? y.clamp(rect.top, maxY) : rect.top).toDouble();
    textPainter.paint(canvas, Offset(rect.left, dy));
  }

  static void _drawTextureLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < 7; i++) {
      final y = size.height * (0.13 + i * 0.12);
      canvas.drawLine(
        Offset(size.width * 0.12, y),
        Offset(size.width * 0.9, y + (i.isEven ? 3 : -3)),
        paint,
      );
    }
  }

  static String _extractMonogram(String title, String format) {
    for (final rune in title.runes) {
      if (_isVisibleCharacter(rune)) {
        return String.fromCharCode(rune).toUpperCase();
      }
    }
    return format.isEmpty ? 'B' : format[0];
  }

  static bool _isVisibleCharacter(int rune) {
    final isAsciiAlphaNum = (rune >= 0x30 && rune <= 0x39) ||
        (rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A);
    final isCjk = (rune >= 0x4E00 && rune <= 0x9FFF) ||
        (rune >= 0x3400 && rune <= 0x4DBF);
    return isAsciiAlphaNum || isCjk;
  }

  /// 保存封面到磁盘
  ///
  /// [imageBytes] 图片字节数据
  /// [bookFileName] 书籍文件名（用于生成封面文件名）
  /// Returns: 保存的封面路径
  static Future<String> saveCover(
    Uint8List imageBytes,
    String bookFileName,
  ) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      final coversDir = Directory(join(documentsDir.path, 'covers'));
      if (!await coversDir.exists()) {
        await coversDir.create(recursive: true);
      }

      // 生成唯一的封面文件名
      final coverFileName =
          '${basenameWithoutExtension(bookFileName)}_${DateTime.now().millisecondsSinceEpoch}.png';
      final coverPath = join(coversDir.path, coverFileName);

      // 保存文件
      final file = File(coverPath);
      await file.writeAsBytes(imageBytes);

      return coverPath;
    } catch (e) {
      debugPrint('保存封面失败: $e');
      rethrow;
    }
  }

  /// 计算标题字体大小
  static double _calculateTitleFontSize(String title) {
    final length = title.runes.length;
    if (length <= 8) {
      return 50;
    } else if (length <= 14) {
      return 44;
    } else if (length <= 24) {
      return 36;
    } else if (length <= 36) {
      return 31;
    } else if (length <= 50) {
      return 27;
    } else {
      return 24;
    }
  }

  /// 绘制格式标签
  static void _drawFormatTag({
    required Canvas canvas,
    required Size size,
    required String format,
    required Color backgroundColor,
    required Color textColor,
  }) {
    final tagRect = Rect.fromLTWH(size.width - 112, 24, 88, 40);

    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(12)),
      Paint()..color = backgroundColor,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(tagRect, const Radius.circular(12)),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: format,
        style: TextStyle(
          fontFamily: 'SourceHanSansCN',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: textColor,
          letterSpacing: 0.8,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();

    final xCenter = tagRect.center.dx - textPainter.width / 2;
    final yCenter = tagRect.center.dy - textPainter.height / 2;
    textPainter.paint(canvas, Offset(xCenter, yCenter));
  }

  /// 获取配色方案
  static _ColorScheme _getColorScheme({
    required String format,
    required String seedText,
  }) {
    final palettes = switch (format) {
      'TXT' => const [
          [Color(0xFF17365C), Color(0xFF2A6F97), Color(0xFF61A5C2)],
          [Color(0xFF4A1E30), Color(0xFF7A2846), Color(0xFFB94B72)],
          [Color(0xFF1F3A2B), Color(0xFF2D6A4F), Color(0xFF52B788)],
          [Color(0xFF3A2A68), Color(0xFF5E4FA2), Color(0xFF7E77D2)],
          [Color(0xFF462D21), Color(0xFF8A4F2A), Color(0xFFD47A3C)],
        ],
      'MOBI' || 'AZW' || 'AZW3' => const [
          [Color(0xFF42275A), Color(0xFF734B6D), Color(0xFFA77FA8)],
          [Color(0xFF3B2F2F), Color(0xFF7D5A50), Color(0xFFD6A77A)],
          [Color(0xFF1B3B5F), Color(0xFF365D8D), Color(0xFF5D8FC2)],
        ],
      'FB2' => const [
          [Color(0xFF0B3C5D), Color(0xFF328CC1), Color(0xFF7DB9DE)],
          [Color(0xFF1D3557), Color(0xFF457B9D), Color(0xFF7FAFD1)],
          [Color(0xFF264653), Color(0xFF2A9D8F), Color(0xFF73C9BC)],
        ],
      'RTF' => const [
          [Color(0xFF49243E), Color(0xFF704264), Color(0xFFBB8493)],
          [Color(0xFF3E2723), Color(0xFF6D4C41), Color(0xFFBCAAA4)],
          [Color(0xFF303F60), Color(0xFF536B9B), Color(0xFF8CA6DB)],
        ],
      _ => const [
          [Color(0xFF243B55), Color(0xFF3C5F8A), Color(0xFF6B8FB2)],
          [Color(0xFF35477D), Color(0xFF6C5B7B), Color(0xFFC06C84)],
          [Color(0xFF2A2D43), Color(0xFF4E5679), Color(0xFF8F9BB3)],
        ],
    };

    final index = seedText.hashCode.abs() % palettes.length;
    final selected = palettes[index];
    return _ColorScheme(
      gradientColors: selected,
      glowColor: selected[2],
      spineColor: Colors.black.withValues(alpha: 0.18),
      frameColor: Colors.white.withValues(alpha: 0.24),
      panelColor: Colors.black.withValues(alpha: 0.22),
      monogramColor: Colors.white.withValues(alpha: 0.1),
      titleColor: Colors.white,
      secondaryTextColor: Colors.white.withValues(alpha: 0.9),
      tagBackgroundColor: Colors.black.withValues(alpha: 0.26),
      tagTextColor: Colors.white.withValues(alpha: 0.96),
    );
  }
}

/// 配色方案
class _ColorScheme {
  final List<Color> gradientColors;
  final Color glowColor;
  final Color spineColor;
  final Color frameColor;
  final Color panelColor;
  final Color monogramColor;
  final Color titleColor;
  final Color secondaryTextColor;
  final Color tagBackgroundColor;
  final Color tagTextColor;

  _ColorScheme({
    required this.gradientColors,
    required this.glowColor,
    required this.spineColor,
    required this.frameColor,
    required this.panelColor,
    required this.monogramColor,
    required this.titleColor,
    required this.secondaryTextColor,
    required this.tagBackgroundColor,
    required this.tagTextColor,
  });
}
