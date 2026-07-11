import 'dart:io';

import 'package:flutter/material.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/pages/native_reader_page.dart';
import 'package:xxread/services/books/book_storage_repair_service.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_transitions.dart';
import 'package:xxread/widgets/side_toast.dart';

class NativeReaderService {
  NativeReaderService._();

  static const _supportedFormats = <String>{
    'epub',
    'txt',
    'html',
    'htm',
    'xhtml',
    'md',
    'markdown',
    'fb2',
    'rtf',
    'docx',
  };

  static Future<void> openBook(BuildContext context, Book book) async {
    final repaired =
        await BookStorageRepairService().repairSingleBookIfNeeded(book);
    if (!await File(repaired.filePath).exists()) {
      if (context.mounted) {
        showSideToast(context, context.l10n.readerFileMissing);
      }
      return;
    }
    if (!_supportedFormats.contains(repaired.format.toLowerCase())) {
      if (context.mounted) {
        showSideToast(context, context.l10n.readerUnsupportedFormat);
      }
      return;
    }
    if (!context.mounted) return;
    await Navigator.of(context).push<void>(
      CustomPageTransitions.createSmoothReaderPageRoute<void>(
        NativeReaderPage(book: repaired),
      ),
    );
  }
}
