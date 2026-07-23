import 'package:flutter/material.dart';
import 'package:xxread/models/book.dart';

class LibraryGridBookDetails extends StatelessWidget {
  const LibraryGridBookDetails({super.key, required this.book});

  static const double height = 40;

  final Book book;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final progress = book.totalPages > 0
        ? (book.currentPage / book.totalPages).clamp(0.0, 1.0)
        : 0.0;
    final percent = (progress * 100).round();

    return SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              book.title,
              key: const ValueKey('library-grid-title'),
              softWrap: false,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 13,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      key: const ValueKey('library-grid-progress'),
                      value: progress,
                      minHeight: 3,
                      backgroundColor: scheme.primary.withValues(alpha: 0.12),
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '$percent%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontSize: 10,
                    height: 1,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
