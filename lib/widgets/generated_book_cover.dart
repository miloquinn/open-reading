// 文件说明：无真实封面时使用的统一简约封面组件。
import 'package:flutter/material.dart';

import '../services/books/cover_generator_service.dart';
import '../utils/localization_extension.dart';

class GeneratedBookCover extends StatelessWidget {
  const GeneratedBookCover({
    super.key,
    required this.title,
    required this.author,
  });

  final String title;
  final String author;

  @override
  Widget build(BuildContext context) {
    final fallbackTitle = context.l10n.bookUntitled;
    final semanticsLabel = [
      title.trim(),
      author.trim(),
    ].where((value) => value.isNotEmpty).join('，');
    return Semantics(
      image: true,
      label: semanticsLabel,
      child: CustomPaint(
        painter: GeneratedBookCoverPainter(
          title: title,
          author: author,
          fallbackTitle: fallbackTitle,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}
