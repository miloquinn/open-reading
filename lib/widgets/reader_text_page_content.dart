import 'package:flutter/material.dart';

import '../core/reader/native_text_paginator.dart';
import '../core/reader/reader_text_layout.dart';
import '../core/reader/reader_text_pagination.dart';
import 'reader_chapter_title_page.dart';

/// Shared final renderer for local and online flowing-text pages.
///
/// It consumes the same [ReaderTextPage] and [NativeTextFlowStyle] used during
/// pagination so measurement and painting cannot silently drift apart.
class ReaderTextPageContent extends StatelessWidget {
  const ReaderTextPageContent({
    super.key,
    required this.page,
    required this.chapterTitle,
    required this.bodyStyle,
    required this.flowStyle,
    this.sourceSpanBuilder,
  });

  final ReaderTextPage page;
  final String chapterTitle;
  final TextStyle bodyStyle;
  final NativeTextFlowStyle flowStyle;
  final ReaderSourceSpanBuilder? sourceSpanBuilder;

  @override
  Widget build(BuildContext context) {
    if (page.isChapterTitle) {
      return ReaderChapterTitlePage(
        title: chapterTitle,
        bodyStyle: bodyStyle,
      );
    }
    return RichText(
      text: page.buildSpan(
        style: bodyStyle,
        sourceSpanBuilder: sourceSpanBuilder,
      ),
      textAlign: flowStyle.textAlign,
      textDirection: flowStyle.textDirection,
      textScaler: flowStyle.textScaler,
      locale: flowStyle.locale,
      strutStyle: flowStyle.strutStyle,
      textWidthBasis: flowStyle.textWidthBasis,
      textHeightBehavior: flowStyle.textHeightBehavior,
    );
  }
}
