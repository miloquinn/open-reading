// 文件说明：BookNote 显示文案的 i18n 翻译器，把模型层的 code 转成用户可见文案。
// 技术要点：Flutter 本地化、扩展方法。

import 'package:flutter/widgets.dart';
import '../utils/localization_extension.dart';
import 'book_note.dart';

/// 翻译笔记类型 code 为用户可见名称。
/// 例如 'highlight' -> 'Highlight' / '高亮' / 'ハイライト' / '螢光標記'
String bookNoteTypeName(BuildContext context, String type) {
  final l10n = context.l10n;
  switch (type) {
    case 'highlight':
      return l10n.noteTypeHighlight;
    case 'underline':
      return l10n.noteTypeUnderline;
    case 'note':
      return l10n.noteTypeNote;
    default:
      return l10n.noteTypeUnknown;
  }
}

/// 翻译笔记颜色 hex 为用户可见名称。
String bookNoteColorName(BuildContext context, String colorHex) {
  final l10n = context.l10n;
  switch (colorHex.toUpperCase()) {
    case '66CCFF':
      return l10n.noteColorLightBlue;
    case 'FF0000':
      return l10n.noteColorRed;
    case '00FF00':
      return l10n.noteColorGreen;
    case 'EB3BFF':
      return l10n.noteColorPurple;
    case 'FFD700':
      return l10n.noteColorGold;
    case 'FF9800':
      return l10n.noteColorOrange;
    case 'FFEB3B':
      return l10n.noteColorYellow;
    case '4CAF50':
      return l10n.noteColorDarkGreen;
    default:
      return l10n.noteColorCustom;
  }
}

/// 格式化笔记分享文本，使用当前 locale 翻译。
String formatBookNoteShareText(
  BuildContext context,
  BookNote note,
  String bookTitle,
  String author,
) {
  final l10n = context.l10n;
  final buffer = StringBuffer();
  buffer.writeln(l10n.noteShareBookHeader(bookTitle, author));
  buffer.writeln();

  if (note.content.isNotEmpty) {
    buffer.writeln('"${note.content}"');
    buffer.writeln();
  }

  if (note.hasNote && note.readerNote != null) {
    buffer.writeln(l10n.noteShareNoteLabel(note.readerNote!));
    buffer.writeln();
  }

  buffer.writeln(l10n.noteShareChapterLabel(note.chapter));
  if (note.pageNumber != null) {
    buffer.writeln(l10n.noteSharePageLabel(note.pageNumber!));
  }
  buffer.writeln();
  buffer.writeln(l10n.noteShareHashtags(bookNoteTypeName(context, note.type)));

  return buffer.toString();
}
