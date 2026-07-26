// 文件说明：Kindle（MOBI/AZW/AZW3）解析入口外观。
// 技术要点：IO 平台使用 kindle_unpack 实现，Web 使用安全桩；
// 结果模型与异常见 kindle_book_parser_types.dart。
// 详见 docs/book-format-support.md

export 'package:xxread/services/books/kindle_book_parser_stub.dart'
    if (dart.library.io) 'package:xxread/services/books/kindle_book_parser_io.dart';
export 'package:xxread/services/books/kindle_book_parser_types.dart';
