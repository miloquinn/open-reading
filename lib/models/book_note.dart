// 文件说明：书摘与笔记模型，统一描述高亮、笔记内容和颜色信息。
// 技术要点：Dart 数据模型、Flutter。

import 'package:flutter/material.dart';

/// 统一的书籍注释模型
/// 整合高亮和笔记功能
///
/// 支持功能：
/// - 高亮文本标记（多种颜色和类型）
/// - 文字笔记附加到高亮
/// - CFI定位（EPUB精确定位）
/// - 章节信息关联
/// - 导出和分享功能
class BookNote {
  /// 唯一标识符
  final int? id;

  /// 关联的书籍ID
  final int bookId;

  /// 选中的文本内容
  final String content;

  /// CFI定位信息（用于EPUB精确定位）
  final String cfi;

  /// 章节标题或标识符
  final String chapter;

  /// 注释类型：'highlight'（高亮）、'underline'（下划线）、'note'（纯笔记）
  final String type;

  /// 高亮颜色（十六进制字符串，不含#前缀）
  final String color;

  /// 用户添加的笔记内容
  final String? readerNote;

  /// 页码（用于快速定位）
  final int? pageNumber;

  /// 文本开始偏移量
  final int? startOffset;

  /// 文本结束偏移量
  final int? endOffset;

  /// 创建时间
  final DateTime? createTime;

  /// 更新时间
  final DateTime updateTime;

  BookNote({
    this.id,
    required this.bookId,
    required this.content,
    required this.cfi,
    required this.chapter,
    required this.type,
    required this.color,
    this.readerNote,
    this.pageNumber,
    this.startOffset,
    this.endOffset,
    this.createTime,
    DateTime? updateTime,
  }) : updateTime = updateTime ?? DateTime.now();

  /// 设置ID（用于数据库插入后）
  void setId(int newId) {
    // Note: 由于Dart的不可变性，这里通过copyWith实现
  }

  /// 转换为数据库Map
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'content': content,
      'cfi': cfi,
      'chapter': chapter,
      'type': type,
      'color': color,
      'reader_note': readerNote,
      'page_number': pageNumber,
      'start_offset': startOffset,
      'end_offset': endOffset,
      'create_time': createTime?.toIso8601String(),
      'update_time': updateTime.toIso8601String(),
    };
  }

  /// 从数据库Map创建实例
  factory BookNote.fromMap(Map<String, dynamic> map) {
    return BookNote(
      id: map['id'],
      bookId: map['book_id'],
      content: map['content'],
      cfi: map['cfi'],
      chapter: map['chapter'],
      type: map['type'],
      color: map['color'],
      readerNote: map['reader_note'],
      pageNumber: map['page_number'],
      startOffset: map['start_offset'],
      endOffset: map['end_offset'],
      createTime: map['create_time'] != null
          ? DateTime.parse(map['create_time'])
          : null,
      updateTime: DateTime.parse(map['update_time']),
    );
  }

  /// 转换为JSON格式（用于导出）
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'note': content,
      'value': cfi,
      'type': type,
      'color': '#$color',
      'readerNote': readerNote,
      'chapter': chapter,
      'pageNumber': pageNumber,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime.toIso8601String(),
    };
  }

  /// 创建副本
  BookNote copyWith({
    int? id,
    int? bookId,
    String? content,
    String? cfi,
    String? chapter,
    String? type,
    String? color,
    String? readerNote,
    int? pageNumber,
    int? startOffset,
    int? endOffset,
    DateTime? createTime,
    DateTime? updateTime,
  }) {
    return BookNote(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      content: content ?? this.content,
      cfi: cfi ?? this.cfi,
      chapter: chapter ?? this.chapter,
      type: type ?? this.type,
      color: color ?? this.color,
      readerNote: readerNote ?? this.readerNote,
      pageNumber: pageNumber ?? this.pageNumber,
      startOffset: startOffset ?? this.startOffset,
      endOffset: endOffset ?? this.endOffset,
      createTime: createTime ?? this.createTime,
      updateTime: updateTime ?? this.updateTime,
    );
  }

  /// 获取颜色对象
  Color get colorValue => Color(int.parse('0xFF$color'));

  /// 预定义的注释颜色
  static const List<String> noteColors = [
    '66CCFF', // 浅蓝色
    'FF0000', // 红色
    '00FF00', // 绿色
    'EB3BFF', // 紫色
    'FFD700', // 金色
    'FF9800', // 橙色
    'FFEB3B', // 黄色
    '4CAF50', // 深绿色
  ];

  /// 注释类型定义
  static const List<Map<String, dynamic>> noteTypes = [
    {
      'type': 'highlight',
      'icon': Icons.highlight_alt,
    },
    {
      'type': 'underline',
      'icon': Icons.format_underlined,
    },
    {
      'type': 'note',
      'icon': Icons.note_alt,
    },
  ];

  /// 获取颜色 code（稳定标识，UI 层通过 `bookNoteColorName` 翻译为显示文案）
  static String getColorName(String colorHex) {
    switch (colorHex.toUpperCase()) {
      case '66CCFF':
        return 'lightBlue';
      case 'FF0000':
        return 'red';
      case '00FF00':
        return 'green';
      case 'EB3BFF':
        return 'purple';
      case 'FFD700':
        return 'gold';
      case 'FF9800':
        return 'orange';
      case 'FFEB3B':
        return 'yellow';
      case '4CAF50':
        return 'darkGreen';
      default:
        return 'custom';
    }
  }

  /// 获取类型 code（稳定标识，UI 层通过 `bookNoteTypeName` 翻译为显示文案）
  static String getTypeName(String type) {
    switch (type) {
      case 'highlight':
        return 'highlight';
      case 'underline':
        return 'underline';
      case 'note':
        return 'note';
      default:
        return 'unknown';
    }
  }

  /// 获取类型图标
  static IconData getTypeIcon(String type) {
    switch (type) {
      case 'highlight':
        return Icons.highlight_alt;
      case 'underline':
        return Icons.format_underlined;
      case 'note':
        return Icons.note_alt;
      default:
        return Icons.bookmark;
    }
  }

  /// 是否有笔记内容
  bool get hasNote => readerNote != null && readerNote!.isNotEmpty;

  /// 是否为纯笔记（无选中文本）
  bool get isPureNote => type == 'note' && content.isEmpty;

  /// 转换为导出格式
  ///
  /// `type`/`color` 均为稳定 code（type code 与颜色 hex），不含本地化显示文案；
  /// 如需展示给用户，UI 层应通过 `bookNoteTypeName` / `bookNoteColorName` 翻译。
  Map<String, dynamic> toExportMap() {
    return {
      'content': content,
      'note': readerNote,
      'type': type,
      'color': color,
      'chapter': chapter,
      'page': pageNumber,
      'createTime': createTime?.toIso8601String(),
      'updateTime': updateTime.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'BookNote{id: $id, bookId: $bookId, type: $type, color: $color, content: ${content.length > 50 ? '${content.substring(0, 50)}...' : content}, hasNote: $hasNote}';
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookNote && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
