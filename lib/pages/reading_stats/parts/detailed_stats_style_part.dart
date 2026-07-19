part of '../detailed_stats_page.dart';

class _StatsPalette {
  final Color pageStart;
  final Color pageMiddle;
  final Color pageEnd;
  final Color card;
  final Color cardStrong;
  final Color hero;
  final Color ink;
  final Color mutedInk;
  final Color accent;
  final Color softAccent;
  final Color border;
  final Color shadow;

  const _StatsPalette({
    required this.pageStart,
    required this.pageMiddle,
    required this.pageEnd,
    required this.card,
    required this.cardStrong,
    required this.hero,
    required this.ink,
    required this.mutedInk,
    required this.accent,
    required this.softAccent,
    required this.border,
    required this.shadow,
  });

  factory _StatsPalette.fromTheme(ThemeData theme) {
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    return _StatsPalette(
      pageStart: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.18 : 0.07),
        scheme.surface,
      ),
      pageMiddle: Color.alphaBlend(
        scheme.primaryContainer.withValues(alpha: isDark ? 0.16 : 0.05),
        scheme.surface,
      ),
      pageEnd: scheme.surface,
      card: isDark
          ? scheme.surfaceContainerLow.withValues(alpha: 0.96)
          : Color.alphaBlend(
              Colors.white.withValues(alpha: 0.90),
              scheme.surface,
            ),
      cardStrong: isDark
          ? scheme.surfaceContainerHigh
          : Color.alphaBlend(
              Colors.white.withValues(alpha: 0.98),
              scheme.surface,
            ),
      hero: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.34 : 0.24),
        isDark ? scheme.surfaceContainerHigh : const Color(0xFFD7E9FF),
      ),
      ink: scheme.onSurface,
      mutedInk: scheme.onSurfaceVariant.withValues(alpha: isDark ? 0.88 : 0.76),
      accent: scheme.primary,
      softAccent: Color.alphaBlend(
        scheme.primary.withValues(alpha: isDark ? 0.22 : 0.12),
        scheme.surface,
      ),
      border: scheme.outline.withValues(alpha: isDark ? 0.24 : 0.12),
      shadow: Colors.black.withValues(alpha: isDark ? 0.18 : 0.055),
    );
  }
}

extension _DetailedStatsSharedView on _DetailedStatsPageState {
  Widget _buildPaperSection({
    required String title,
    required IconData icon,
    required Widget child,
    Widget? trailing,
  }) {
    final palette = _palette;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: palette.cardStrong,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 20,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: palette.softAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: palette.accent, size: 19),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: palette.ink,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildProgressLine(
    String label,
    String value,
    double progress,
    Color color,
  ) {
    final palette = _palette;
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: palette.mutedInk,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: palette.ink,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 7,
            color: color,
            backgroundColor: color.withValues(alpha: 0.12),
          ),
        ),
      ],
    );
  }

  Widget _buildBookCover(Book book, double width, double height) {
    final path = book.coverImagePath;
    if (path != null && path.isNotEmpty && path != 'null') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: Image.file(
          File(path),
          width: width,
          height: height,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildGeneratedBookCover(book, width, height),
        ),
      );
    }
    return _buildGeneratedBookCover(book, width, height);
  }

  Widget _buildGeneratedBookCover(Book book, double width, double height) {
    return SizedBox(
      width: width,
      height: height,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9),
        child: GeneratedBookCover(title: book.title, author: book.author),
      ),
    );
  }
}
