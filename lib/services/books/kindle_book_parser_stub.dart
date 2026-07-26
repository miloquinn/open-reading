// 文件说明：Kindle 解析在非 IO 平台（Web）的安全桩。
// 技术要点：kindle_unpack 依赖 dart:io（字体 zlib）且 HUFF 解码含 64 位
// 位运算，Web 端不可用；所有入口统一抛 UnsupportedError，调用方回退
// 基础元数据或提示格式不支持。
// 详见 docs/book-format-support.md

import 'dart:typed_data';

import 'package:xxread/services/books/kindle_book_parser_types.dart';

Never _unsupported() =>
    throw UnsupportedError('Kindle parsing is not supported on this platform');

KindleBookMetadata parseKindleMetadata(Uint8List bytes) => _unsupported();

bool kindleBookHasDrm(Uint8List bytes) => _unsupported();

KindleBookContent parseKindleContent(Uint8List bytes) => _unsupported();
