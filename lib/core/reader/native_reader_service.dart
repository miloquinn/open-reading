import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/pages/reader/comic_reader_page.dart';
import 'package:xxread/pages/reader/native_reader_page.dart';
import 'package:xxread/pages/reader/pdf_reader_page.dart';
import 'package:xxread/services/books/book_storage_repair_service.dart';
import 'package:xxread/services/books/web_book_file_store.dart';
import 'package:xxread/utils/book_open_transition.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_transitions.dart';
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

  /// kindle_unpack 依赖 dart:io，Web 端只有安全桩，不放行。
  static const _kindleFormats = <String>{'mobi', 'azw', 'azw3'};

  static bool _canOpenFormat(String format) {
    if (_supportedFormats.contains(format)) return true;
    if (!kIsWeb && _kindleFormats.contains(format)) return true;
    return false;
  }

  static Future<void> openBook(
    BuildContext context,
    Book book, {
    BookOpenAnimation? animation,
    ReaderPageTransitionOrigin origin = ReaderPageTransitionOrigin.standard,
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
    final format = repaired.format.toLowerCase();
    if (format == 'cbz') {
      if (!context.mounted) return;
      await ComicReaderPage.open(
        context,
        repaired,
        animation: animation,
        waitForReaderClose: waitForReaderClose,
      );
      return;
    }
    if (format == 'pdf') {
      if (!context.mounted) return;
      // pdfx 没有 Linux 实现（Android/iOS/macOS/Windows/Web 可用）。
      if (!kIsWeb && Platform.isLinux) {
        showSideToast(
          context,
          context.l10n.readerPdfLinuxUnsupported,
          kind: SideToastKind.warning,
        );
        return;
      }
      await PdfReaderPage.open(
        context,
        repaired,
        animation: animation,
        waitForReaderClose: waitForReaderClose,
      );
      return;
    }
    if (!_canOpenFormat(format)) {
      if (context.mounted) {
        showSideToast(
          context,
          format == 'cbr'
              ? context.l10n.readerComicCbrUnsupported
              : context.l10n.readerUnsupportedFormat,
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
    final route = BookOpenTransition.createRoute<void>(
      NativeReaderPage(book: repaired, initialTheme: initialTheme),
      animation: animation,
      readerBackgroundColor: initialTheme?.background,
      origin: origin,
      waitForReaderReady: true,
    );
    final navigation = BookOpenTransition.push<void>(context, route);
    if (waitForReaderClose) {
      await navigation;
    } else {
      unawaited(navigation);
    }
  }
}
