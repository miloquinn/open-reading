// 文件说明：文本预处理工具，负责清洗段落、空白和章节前的文本规范化。
// 技术要点：服务层、Flutter。

import 'package:flutter/foundation.dart';

/// 文本预处理器
///
/// 功能：
/// 1. 统一换行符（\r\n → \n）
/// 2. 压缩多余空行（多个\n → 1个\n）
/// 3. 添加段首缩进（可配置0-4个字符）
/// 4. 处理特殊字符
///
/// 用于Legado风格分页前的文本规范化
class TextPreprocessor {
  /// 预处理文本
  ///
  /// [rawText] 原始文本
  /// [indentSize] 段首缩进字符数（0-4）
  /// [indentDialogue] 对话是否也缩进
  /// [compressEmptyLines] 是否压缩多余空行
  ///
  /// Returns: 处理后的文本
  String process(
    String rawText, {
    int indentSize = 2,
    bool indentDialogue = true,
    bool compressEmptyLines = true,
    int paragraphSpacing = 0, // 段落间距（0-2行空行）
  }) {
    if (rawText.isEmpty) return rawText;

    final startTime = DateTime.now();
    debugPrint('📝 开始文本预处理...');
    debugPrint('   - 原始长度: ${rawText.length} 字符');
    debugPrint('   - 缩进大小: $indentSize 字符');
    debugPrint('   - 对话缩进: $indentDialogue');
    debugPrint('   - 压缩空行: $compressEmptyLines');
    debugPrint('   - 段落间距: $paragraphSpacing 行');

    String processed = rawText;

    // 步骤1: 统一换行符
    processed = _normalizeLineBreaks(processed);

    // 步骤2: 处理特殊字符
    processed = _cleanSpecialCharacters(processed);

    // 步骤3: 压缩多余空行
    if (compressEmptyLines) {
      processed = _compressEmptyLines(processed);
    }

    // 步骤4: 添加段首缩进
    if (indentSize > 0) {
      processed = _addParagraphIndent(
        processed,
        indentSize: indentSize,
        indentDialogue: indentDialogue,
      );
    }

    // 步骤5: 添加段落间距
    if (paragraphSpacing > 0) {
      processed = _addParagraphSpacing(processed, paragraphSpacing);
    }

    final endTime = DateTime.now();
    final duration = endTime.difference(startTime);

    debugPrint('✅ 文本预处理完成');
    debugPrint('   - 处理后长度: ${processed.length} 字符');
    debugPrint('   - 耗时: ${duration.inMilliseconds}ms');

    return processed;
  }

  /// 统一换行符
  ///
  /// 将 \r\n 和 \r 统一转换为 \n
  String _normalizeLineBreaks(String text) {
    // 替换 \r\n 为 \n
    text = text.replaceAll('\r\n', '\n');
    // 替换单独的 \r 为 \n
    text = text.replaceAll('\r', '\n');
    return text;
  }

  /// 清理特殊字符
  ///
  /// 处理：
  /// - 全角空格 → 两个半角空格
  /// - 零宽字符 → 删除
  /// - 制表符 → 两个空格
  String _cleanSpecialCharacters(String text) {
    // 全角空格（U+3000）替换为两个半角空格
    text = text.replaceAll('　', '  ');

    // 零宽字符删除
    text = text.replaceAll('\u200B', ''); // 零宽空格
    text = text.replaceAll('\uFEFF', ''); // 零宽不换行空格（BOM）

    // 制表符替换为两个空格
    text = text.replaceAll('\t', '  ');

    return text;
  }

  /// 压缩多余空行
  ///
  /// 将多个连续换行符压缩为单个换行符
  /// 同时移除段落之间的空行，让段落紧密排列（通过缩进区分段落）
  ///
  /// 例如:
  /// "段落1\n\n\n\n段落2" → "段落1\n段落2"
  /// "  行1  \n  \n行2" → "行1\n行2" (移除空白行)
  String _compressEmptyLines(String text) {
    // 步骤1: 移除每行首尾的空白字符
    final lines = text.split('\n');
    final trimmedLines = lines.map((line) => line.trim()).toList();

    // 步骤2: 移除空行并合并
    final nonEmptyLines =
        trimmedLines.where((line) => line.isNotEmpty).toList();

    // 步骤3: 用单个换行符连接所有非空行（彻底去除段落间空行）
    return nonEmptyLines.join('\n');
  }

  /// 添加段首缩进
  ///
  /// 为每个段落开头添加指定数量的空格
  ///
  /// 段落识别规则：
  /// 1. 文本开头
  /// 2. \n\n 后的内容（新段落）
  /// 3. 单个\n 后的内容（也被视为新段落）
  ///
  /// [text] 输入文本
  /// [indentSize] 缩进字符数
  /// [indentDialogue] 对话（引号开头）是否也缩进
  String _addParagraphIndent(
    String text, {
    required int indentSize,
    required bool indentDialogue,
  }) {
    if (indentSize <= 0 || indentSize > 4) return text;

    // 生成缩进字符串
    final indent = '  ' * indentSize; // 每个缩进单位 = 2个空格

    // 分割成行
    final lines = text.split('\n');
    final result = StringBuffer();

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.trim().isEmpty) {
        // 空行，保持原样
        result.write(line);
      } else {
        // 非空行，检查是否需要缩进
        final shouldIndent = _shouldIndentLine(
          line,
          isFirstLine: i == 0,
          indentDialogue: indentDialogue,
        );

        if (shouldIndent) {
          result.write(indent);
          result.write(line);
        } else {
          result.write(line);
        }
      }

      // 添加换行符（除了最后一行）
      if (i < lines.length - 1) {
        result.write('\n');
      }
    }

    return result.toString();
  }

  /// 判断某行是否应该缩进
  ///
  /// [line] 当前行内容
  /// [isFirstLine] 是否是第一行
  /// [indentDialogue] 对话是否缩进
  bool _shouldIndentLine(
    String line, {
    required bool isFirstLine,
    required bool indentDialogue,
  }) {
    final trimmed = line.trim();

    if (trimmed.isEmpty) {
      return false; // 空行不缩进
    }

    // 检查是否已经有缩进（避免重复缩进）
    if (line.startsWith('  ')) {
      return false;
    }

    // 检查是否是对话
    if (!indentDialogue && _isDialogue(trimmed)) {
      return false; // 对话不缩进
    }

    // 其他情况都缩进
    return true;
  }

  /// 判断是否是对话
  ///
  /// 规则：以引号开头
  /// 支持中英文引号：" " ' ' 「 」 『 』
  bool _isDialogue(String text) {
    if (text.isEmpty) return false;

    final firstChar = text[0];
    const dialogueMarkers = [
      '"',
      '"',
      '"',
      "'",
      ''',
      ''',
      '「',
      '」',
      '『',
      '』',
    ];

    return dialogueMarkers.contains(firstChar);
  }

  /// 添加段落间距
  ///
  /// 在每个段落（换行符）之间添加指定数量的空行
  ///
  /// [text] 输入文本（已经过段首缩进处理）
  /// [spacing] 段落间距（0-2行）
  ///
  /// 例如：
  /// spacing=1: "段落1\n段落2" → "段落1\n\n段落2"
  /// spacing=2: "段落1\n段落2" → "段落1\n\n\n段落2"
  String _addParagraphSpacing(String text, int spacing) {
    if (spacing <= 0 || spacing > 2) return text;

    // 将每个 \n 替换为 spacing+1 个 \n
    final replacement = '\n' * (spacing + 1);
    return text.replaceAll('\n', replacement);
  }

  /// 快速预处理（用于性能敏感场景）
  ///
  /// 只做最基础的处理：
  /// 1. 统一换行符
  /// 2. 压缩空行
  ///
  /// 不做缩进和特殊字符处理
  String quickProcess(String rawText) {
    if (rawText.isEmpty) return rawText;

    String processed = rawText;

    // 统一换行符
    processed = _normalizeLineBreaks(processed);

    // 压缩空行
    processed = _compressEmptyLines(processed);

    return processed;
  }
}

class TextPreprocessRequest {
  final String text;
  final int indentSize;
  final bool indentDialogue;
  final bool compressEmptyLines;
  final int paragraphSpacing;

  const TextPreprocessRequest({
    required this.text,
    this.indentSize = 2,
    this.indentDialogue = true,
    this.compressEmptyLines = true,
    this.paragraphSpacing = 0,
  });
}

String preprocessTextInIsolate(TextPreprocessRequest request) {
  return TextPreprocessor().process(
    request.text,
    indentSize: request.indentSize,
    indentDialogue: request.indentDialogue,
    compressEmptyLines: request.compressEmptyLines,
    paragraphSpacing: request.paragraphSpacing,
  );
}
