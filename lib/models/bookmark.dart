// 文件说明：书签数据模型，保存书签位置、标题和创建时间。
// 技术要点：Dart 数据模型。

class Bookmark {
  final int? id;
  final int bookId;
  final int pageNumber;
  final String note;
  final DateTime createDate;
  final String? cfi;
  final String? canonicalLocator;
  final String? anchorKey;
  final int? chapterIndex;
  final String? chapterTitle;
  final String? excerpt;

  Bookmark({
    this.id,
    required this.bookId,
    required this.pageNumber,
    this.note = '',
    DateTime? createDate,
    this.cfi,
    this.canonicalLocator,
    this.anchorKey,
    this.chapterIndex,
    this.chapterTitle,
    this.excerpt,
  }) : createDate = createDate ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'bookId': bookId,
      'pageNumber': pageNumber,
      'note': note,
      'createDate': createDate.millisecondsSinceEpoch,
      'cfi': cfi,
      'canonical_locator': canonicalLocator,
      'anchor_key': anchorKey,
      'chapter_index': chapterIndex,
      'chapter_title': chapterTitle,
      'excerpt': excerpt,
    };
  }

  factory Bookmark.fromMap(Map<String, dynamic> map) {
    final createDateRaw = map['createDate'];
    DateTime parsedCreateDate;
    if (createDateRaw is int) {
      parsedCreateDate = DateTime.fromMillisecondsSinceEpoch(createDateRaw);
    } else if (createDateRaw is num) {
      parsedCreateDate =
          DateTime.fromMillisecondsSinceEpoch(createDateRaw.toInt());
    } else if (createDateRaw is String) {
      final asInt = int.tryParse(createDateRaw);
      if (asInt != null) {
        parsedCreateDate = DateTime.fromMillisecondsSinceEpoch(asInt);
      } else {
        parsedCreateDate = DateTime.tryParse(createDateRaw) ?? DateTime.now();
      }
    } else {
      parsedCreateDate = DateTime.now();
    }

    int toInt(dynamic value, {int fallback = 0}) {
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? fallback;
      return fallback;
    }

    return Bookmark(
      id: map['id'],
      bookId: toInt(map['bookId']),
      pageNumber: toInt(map['pageNumber']),
      note: map['note'] ?? '',
      createDate: parsedCreateDate,
      cfi: map['cfi'],
      canonicalLocator: map['canonical_locator'],
      anchorKey: map['anchor_key'],
      chapterIndex:
          map['chapter_index'] == null ? null : toInt(map['chapter_index']),
      chapterTitle: map['chapter_title'],
      excerpt: map['excerpt'],
    );
  }

  Bookmark copyWith({
    int? id,
    int? bookId,
    int? pageNumber,
    String? note,
    DateTime? createDate,
    String? cfi,
    String? canonicalLocator,
    String? anchorKey,
    int? chapterIndex,
    String? chapterTitle,
    String? excerpt,
  }) {
    return Bookmark(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      pageNumber: pageNumber ?? this.pageNumber,
      note: note ?? this.note,
      createDate: createDate ?? this.createDate,
      cfi: cfi ?? this.cfi,
      canonicalLocator: canonicalLocator ?? this.canonicalLocator,
      anchorKey: anchorKey ?? this.anchorKey,
      chapterIndex: chapterIndex ?? this.chapterIndex,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      excerpt: excerpt ?? this.excerpt,
    );
  }
}
