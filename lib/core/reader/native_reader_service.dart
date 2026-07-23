import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader/native_reader_page.dart';
import 'package:xxread/services/books/book_storage_repair_service.dart';
import 'package:xxread/services/books/web_book_file_store.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/reader_themes.dart';
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

  static Future<void> openBook(
    BuildContext context,
    Book book, {
    BookOpenAnimation? animation,
    bool waitForReaderClose = true,
  }) async {
    final repaired = kIsWeb
        ? book
        : await BookStorageRepairService().repairSingleBookIfNeeded(book);
    final fileExists = kIsWeb
        ? WebBookFileStore.isWebBookPath(repaired.filePath) &&
              await WebBookFileStore().exists(repaired.filePath)
        : await File(repaired.filePath).exists();
    if (!fileExists) {
      if (context.mounted) {
        showSideToast(
          context,
          context.l10n.readerFileMissing,
          kind: SideToastKind.error,
        );
      }
      return;
    }
    if (!_supportedFormats.contains(repaired.format.toLowerCase())) {
      if (context.mounted) {
        showSideToast(
          context,
          context.l10n.readerUnsupportedFormat,
          kind: SideToastKind.warning,
        );
      }
      return;
    }
    if (!context.mounted) return;
    final initialTheme = animation == null
        ? null
        : await ReaderThemes.loadSavedPalette();
    if (!context.mounted) return;
    final navigation = Navigator.of(context).push<void>(
      BookOpenTransition.createRoute<void>(
        NativeReaderPage(book: repaired, initialTheme: initialTheme),
        animation: animation,
        readerBackgroundColor: initialTheme?.background,
      ),
    );
    if (waitForReaderClose) {
      await navigation;
    } else {
      unawaited(navigation);
    }
  }
}
