import 'package:flutter/material.dart';

import '../core/reader/reader_leaf_status.dart';
import '../core/reader/reader_safe_area.dart';
import '../utils/reader_themes.dart';
import 'reader_theme_background.dart';
import 'reader_top_information_bar.dart';

enum ReaderPageNumberPlacement {
  bottomLeft,
  bottomRight,
}

@immutable
class ReaderPageSnapshotKey {
  const ReaderPageSnapshotKey({
    required this.pageIdentity,
    required this.layoutFingerprint,
    required this.themeId,
  });

  final String pageIdentity;
  final String layoutFingerprint;
  final String themeId;

  @override
  bool operator ==(Object other) =>
      other is ReaderPageSnapshotKey &&
      other.pageIdentity == pageIdentity &&
      other.layoutFingerprint == layoutFingerprint &&
      other.themeId == themeId;

  @override
  int get hashCode => Object.hash(pageIdentity, layoutFingerprint, themeId);

  @override
  String toString() => '$pageIdentity@$layoutFingerprint#$themeId';
}

@immutable
class ReaderPaperPageMetadata {
  const ReaderPaperPageMetadata({
    required this.pageIdentity,
    required this.layoutFingerprint,
    required this.themeId,
    required this.chapterTitle,
    required this.pageNumber,
    required this.pageCount,
  });

  final String pageIdentity;
  final String layoutFingerprint;
  final String themeId;
  final String chapterTitle;
  final int pageNumber;
  final int pageCount;

  ReaderPageSnapshotKey get snapshotKey => ReaderPageSnapshotKey(
        pageIdentity: pageIdentity,
        layoutFingerprint: layoutFingerprint,
        themeId: themeId,
      );

  String get pageLabel => '$pageNumber / $pageCount';
}

/// A complete sheet of reader paper: body and quiet editorial footer.
///
/// The footer is deliberately inside the leaf so PageView and classic fold
/// move the same pixels. Floating reader controls remain a
/// separate HUD.
class ReaderPaperPageLeaf extends StatelessWidget {
  const ReaderPaperPageLeaf({
    super.key,
    required this.palette,
    required this.safeArea,
    required this.metadata,
    required this.child,
    this.pageNumberPlacement = ReaderPageNumberPlacement.bottomRight,
    this.horizontalPadding = 14,
    this.pageNumberHorizontalPadding = 24,
    this.showTopInformation = false,
    this.status,
  });

  final ReaderThemePalette palette;
  final ReaderSafeAreaMetrics safeArea;
  final ReaderPaperPageMetadata metadata;
  final Widget child;
  final ReaderPageNumberPlacement pageNumberPlacement;
  final double horizontalPadding;
  final double pageNumberHorizontalPadding;
  final bool showTopInformation;
  final ReaderLeafStatusData? status;

  @override
  Widget build(BuildContext context) {
    final footerStyle = Theme.of(context).textTheme.labelSmall?.copyWith(
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontSize: 10,
          height: 1,
          letterSpacing: 0.08,
          fontFeatures: const [FontFeature.tabularFigures()],
        ) ??
        TextStyle(
          color: palette.secondaryText.withValues(alpha: 0.66),
          fontSize: 10,
          height: 1,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    final semanticsLabel = metadata.chapterTitle.isEmpty
        ? metadata.pageLabel
        : '${metadata.chapterTitle}, ${metadata.pageLabel}';

    return Semantics(
      label: semanticsLabel,
      container: true,
      child: ReaderThemeBackground(
        palette: palette,
        child: Stack(
          fit: StackFit.expand,
          children: [
            child,
            if (showTopInformation)
              Positioned(
                left: horizontalPadding,
                right: horizontalPadding,
                top: safeArea.readerTopBarTop,
                height: ReaderSafeAreaMetrics.readerTopBarHeight,
                child: ReaderTopInformationBar(
                  key: ValueKey(
                    'reader-leaf-top-information:${metadata.pageIdentity}',
                  ),
                  palette: palette,
                  title: metadata.chapterTitle,
                  status: status,
                ),
              ),
            Positioned(
              left: pageNumberHorizontalPadding,
              right: pageNumberHorizontalPadding,
              bottom: safeArea.pageNumberBottom,
              height: ReaderSafeAreaMetrics.pageNumberReserve,
              child: Align(
                key: ValueKey(
                  'reader-leaf-footer:${metadata.pageIdentity}',
                ),
                alignment:
                    pageNumberPlacement == ReaderPageNumberPlacement.bottomLeft
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                child: Text(
                  metadata.pageLabel,
                  key: ValueKey(
                    'reader-leaf-page:${metadata.pageIdentity}',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: footerStyle,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
