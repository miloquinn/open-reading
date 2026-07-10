import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/pages/native_reader_page.dart';
import 'package:xxread/services/books/book_storage_repair_service.dart';
import 'package:xxread/widgets/side_toast.dart';

class NativeReaderService {
  NativeReaderService._();

  static const _supportedFormats = <String>{'epub', 'txt'};

  static Future<void> openBook(BuildContext context, Book book) async {
    final repaired =
        await BookStorageRepairService().repairSingleBookIfNeeded(book);
    if (!await File(repaired.filePath).exists()) {
      if (context.mounted) showSideToast(context, '书籍文件不存在，请重新导入');
      return;
    }
    if (!_supportedFormats.contains(repaired.format.toLowerCase())) {
      if (context.mounted) {
        showSideToast(context, '原生阅读器当前仅支持 EPUB 和 TXT');
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => NativeReaderPage(book: repaired),
      ),
    );
  }
}
