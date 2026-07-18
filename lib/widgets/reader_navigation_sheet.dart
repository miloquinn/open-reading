import 'package:flutter/material.dart';

import '../models/bookmark.dart';
import '../utils/localization_extension.dart';
import '../utils/reader_themes.dart';
import 'open_reading_icons.dart';

class ReaderNavigationChapter {
  const ReaderNavigationChapter({
    required this.title,
    required this.index,
    this.depth = 0,
  });

  final String title;
  final int index;
  final int depth;
}

class ReaderNavigationSheet extends StatefulWidget {
  const ReaderNavigationSheet({
    super.key,
    required this.palette,
    required this.chapters,
    required this.currentChapterIndex,
    required this.bookmarks,
    required this.onChapterSelected,
    required this.onBookmarkSelected,
    required this.onBookmarkDeleted,
    this.currentAnchorKey,
  });

  final ReaderThemePalette palette;
  final List<ReaderNavigationChapter> chapters;
  final int currentChapterIndex;
  final List<Bookmark> bookmarks;
  final String? currentAnchorKey;
  final ValueChanged<int> onChapterSelected;
  final ValueChanged<Bookmark> onBookmarkSelected;
  final ValueChanged<Bookmark> onBookmarkDeleted;

  @override
  State<ReaderNavigationSheet> createState() => _ReaderNavigationSheetState();
}

class _ReaderNavigationSheetState extends State<ReaderNavigationSheet>
    with SingleTickerProviderStateMixin {
  static const _chapterExtent = 64.0;
  static const _treeIndent = 16.0;

  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _chapterScrollController = ScrollController();
  final Set<int> _collapsedChapterPositions = <int>{};
  String _query = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_handleTabChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_handleTabChanged)
      ..dispose();
    _searchController.dispose();
    _chapterScrollController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!_tabController.indexIsChanging) setState(() {});
  }

  @override
  void didUpdateWidget(covariant ReaderNavigationSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameChapterTree(oldWidget.chapters, widget.chapters)) {
      _collapsedChapterPositions.clear();
    }
    if (oldWidget.currentChapterIndex != widget.currentChapterIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }
  }

  bool _sameChapterTree(
    List<ReaderNavigationChapter> previous,
    List<ReaderNavigationChapter> next,
  ) {
    if (identical(previous, next)) return true;
    if (previous.length != next.length) return false;
    for (var index = 0; index < previous.length; index++) {
      final before = previous[index];
      final after = next[index];
      if (before.index != after.index ||
          before.depth != after.depth ||
          before.title != after.title) {
        return false;
      }
    }
    return true;
  }

  List<_ReaderNavigationTreeEntry> _buildTreeEntries() {
    final entries = <_ReaderNavigationTreeEntry>[];
    final ancestorPositions = <int>[];
    for (var position = 0; position < widget.chapters.length; position++) {
      final chapter = widget.chapters[position];
      final depth = chapter.depth < 0 ? 0 : chapter.depth;
      while (ancestorPositions.isNotEmpty &&
          entries[ancestorPositions.last].depth >= depth) {
        ancestorPositions.removeLast();
      }
      final parentPosition =
          ancestorPositions.isEmpty ? null : ancestorPositions.last;
      final hasChildren = position + 1 < widget.chapters.length &&
          widget.chapters[position + 1].depth > depth;
      entries.add(
        _ReaderNavigationTreeEntry(
          chapter: chapter,
          position: position,
          depth: depth,
          parentPosition: parentPosition,
          hasChildren: hasChildren,
        ),
      );
      ancestorPositions.add(position);
    }
    return entries;
  }

  List<_ReaderNavigationTreeEntry> get _visibleChapters {
    final entries = _buildTreeEntries();
    final normalized = _query.trim().toLowerCase();
    if (normalized.isNotEmpty) {
      final includedPositions = <int>{};
      for (final entry in entries) {
        if (!entry.chapter.title.toLowerCase().contains(normalized)) continue;
        int? position = entry.position;
        while (position != null && includedPositions.add(position)) {
          position = entries[position].parentPosition;
        }
      }
      return entries
          .where((entry) => includedPositions.contains(entry.position))
          .toList(growable: false);
    }
    return entries
        .where((entry) => !_hasCollapsedAncestor(entry, entries))
        .toList(growable: false);
  }

  bool _hasCollapsedAncestor(
    _ReaderNavigationTreeEntry entry,
    List<_ReaderNavigationTreeEntry> entries,
  ) {
    var position = entry.parentPosition;
    while (position != null) {
      if (_collapsedChapterPositions.contains(position)) return true;
      position = entries[position].parentPosition;
    }
    return false;
  }

  void _toggleChapter(_ReaderNavigationTreeEntry entry) {
    setState(() {
      if (!_collapsedChapterPositions.remove(entry.position)) {
        _collapsedChapterPositions.add(entry.position);
      }
    });
  }

  void _scrollToCurrent() {
    if (!_chapterScrollController.hasClients || widget.chapters.isEmpty) {
      return;
    }
    if (_query.isNotEmpty) {
      _searchController.clear();
      setState(() => _query = '');
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
      return;
    }
    final entries = _buildTreeEntries();
    final currentPosition = entries.indexWhere(
      (entry) => entry.chapter.index == widget.currentChapterIndex,
    );
    if (currentPosition < 0) return;
    var expandedAncestor = false;
    var ancestorPosition = entries[currentPosition].parentPosition;
    while (ancestorPosition != null) {
      expandedAncestor =
          _collapsedChapterPositions.remove(ancestorPosition) ||
              expandedAncestor;
      ancestorPosition = entries[ancestorPosition].parentPosition;
    }
    if (expandedAncestor) {
      setState(() {});
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
      return;
    }
    final visiblePosition = _visibleChapters.indexWhere(
      (entry) => entry.position == currentPosition,
    );
    if (visiblePosition < 0) return;
    final position = _chapterScrollController.position;
    final currentTop = visiblePosition * _chapterExtent;
    final currentBottom = currentTop + _chapterExtent;
    final visibleTop = position.pixels;
    final visibleBottom = visibleTop + position.viewportDimension;
    if (currentTop >= visibleTop && currentBottom <= visibleBottom) return;
    final rawTarget = currentTop - position.viewportDimension * 0.32;
    final alignedTarget = (rawTarget / _chapterExtent).floor() * _chapterExtent;
    final target = alignedTarget.clamp(0.0, position.maxScrollExtent);
    _chapterScrollController.animateTo(
      target,
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.palette.toThemeData(
      typography: Theme.of(context).textTheme,
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (themedContext) => Material(
          color: widget.palette.surface,
          surfaceTintColor: Colors.transparent,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                _buildDragHandle(),
                _buildHeader(themedContext),
                _buildTabs(themedContext),
                Divider(height: 1, color: widget.palette.border),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildCatalog(themedContext),
                      _buildBookmarks(themedContext),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDragHandle() {
    return Container(
      key: const ValueKey('reader-navigation-drag-handle'),
      width: 36,
      height: 4,
      margin: const EdgeInsets.only(top: 8),
      decoration: BoxDecoration(
        color: widget.palette.secondaryText.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(99),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.readerNavigationTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  context.l10n.readerNavigationPosition(
                    widget.currentChapterIndex + 1,
                    widget.chapters.length,
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: widget.palette.secondaryText,
                      ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              MaterialLocalizations.of(context).closeButtonTooltip,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: widget.palette.controlBar,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: widget.palette.border.withValues(alpha: 0.72),
          ),
        ),
        child: TabBar(
          controller: _tabController,
          dividerColor: Colors.transparent,
          indicatorSize: TabBarIndicatorSize.tab,
          indicator: BoxDecoration(
            color: widget.palette.controlFill,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: widget.palette.shadow.withValues(alpha: 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          tabs: [
            Tab(
              height: 42,
              child: _tabLabel(
                label: context.l10n.readerToolbarTOC,
              ),
            ),
            Tab(
              height: 42,
              child: _tabLabel(
                label: context.l10n.bookmarks,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabLabel({
    required String label,
  }) {
    return Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
    );
  }

  Widget _buildCatalog(BuildContext context) {
    final chapters = _visibleChapters;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  onChanged: (value) => setState(() => _query = value),
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: context.l10n.readerSearchChapters,
                    filled: true,
                    fillColor: widget.palette.controlBar,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Tooltip(
                message: context.l10n.readerBackToCurrentChapter,
                child: TextButton(
                  key: const ValueKey(
                    'reader-navigation-current-chapter-button',
                  ),
                  onPressed: _scrollToCurrent,
                  style: TextButton.styleFrom(
                    minimumSize: const Size(60, 48),
                    backgroundColor: widget.palette.controlFill,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Text(context.l10n.readerCurrentChapter),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: chapters.isEmpty
              ? _emptyState(
                  context,
                  title: context.l10n.readerNoChapterResults,
                  message: context.l10n.readerNoChapterResultsHint,
                )
              : ListView.builder(
                  controller: _chapterScrollController,
                  padding: const EdgeInsets.fromLTRB(12, 2, 12, 20),
                  itemExtent: _chapterExtent,
                  itemCount: chapters.length,
                  itemBuilder: (context, visibleIndex) {
                    final entry = chapters[visibleIndex];
                    final selected =
                        entry.chapter.index == widget.currentChapterIndex;
                    return _buildChapterTile(context, entry, selected);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildChapterTile(
    BuildContext context,
    _ReaderNavigationTreeEntry entry,
    bool selected,
  ) {
    final chapter = entry.chapter;
    final title = chapter.title.isEmpty
        ? context.l10n.readerChapterFallback(chapter.index + 1)
        : chapter.title;
    final displayDepth = entry.depth.clamp(0, 8);
    final isSearching = _query.trim().isNotEmpty;
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: title,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: InkWell(
          onTap: () => widget.onChapterSelected(chapter.index),
          borderRadius: BorderRadius.circular(16),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.only(
              left: 8,
              right: 12,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? widget.palette.accent.withValues(alpha: 0.08)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(13),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 3,
                  height: selected ? 30 : 0,
                  decoration: BoxDecoration(
                    color: widget.palette.accent,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(width: 6),
                _buildDepthGuides(displayDepth),
                _buildTreeControl(
                  context,
                  entry: entry,
                  selected: selected,
                  enabled: !isSearching,
                ),
                SizedBox(
                  width: 24,
                  child: selected
                      ? OpenReadingCurrentIcon(
                          size: 20,
                          color: widget.palette.accent,
                        )
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight:
                              selected ? FontWeight.w700 : FontWeight.w500,
                          color: selected
                              ? widget.palette.accent
                              : widget.palette.text,
                        ),
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.readerCurrentChapter,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: widget.palette.accent,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepthGuides(int depth) {
    if (depth <= 0) return const SizedBox.shrink();
    return SizedBox(
      width: depth * _treeIndent,
      child: Row(
        children: [
          for (var level = 0; level < depth; level++)
            SizedBox(
              width: _treeIndent,
              child: Center(
                child: Container(
                  width: 1,
                  height: _chapterExtent,
                  color: widget.palette.border.withValues(alpha: 0.62),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTreeControl(
    BuildContext context, {
    required _ReaderNavigationTreeEntry entry,
    required bool selected,
    required bool enabled,
  }) {
    final color = selected
        ? widget.palette.accent
        : widget.palette.secondaryText.withValues(alpha: 0.88);
    if (!entry.hasChildren) {
      return SizedBox(
        width: 34,
        child: Center(
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: selected
                  ? widget.palette.accent
                  : widget.palette.border.withValues(alpha: 0.92),
              shape: BoxShape.circle,
            ),
          ),
        ),
      );
    }
    final expanded = !_collapsedChapterPositions.contains(entry.position);
    final localizations = MaterialLocalizations.of(context);
    return SizedBox(
      width: 34,
      height: 42,
      child: Tooltip(
        message: expanded
            ? localizations.expandedIconTapHint
            : localizations.collapsedIconTapHint,
        child: IconButton(
          key: ValueKey('reader-navigation-toggle-${entry.chapter.index}'),
          onPressed: enabled ? () => _toggleChapter(entry) : null,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 34, height: 42),
          visualDensity: VisualDensity.compact,
          icon: AnimatedRotation(
            turns: expanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            child: Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: enabled ? color : color.withValues(alpha: 0.48),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBookmarks(BuildContext context) {
    if (widget.bookmarks.isEmpty) {
      return _emptyState(
        context,
        title: context.l10n.readerNoBookmarks,
        message: context.l10n.readerNoBookmarksHint,
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
      itemCount: widget.bookmarks.length,
      separatorBuilder: (_, __) => const SizedBox(height: 9),
      itemBuilder: (context, index) {
        final bookmark = widget.bookmarks[index];
        final current = bookmark.anchorKey != null &&
            bookmark.anchorKey == widget.currentAnchorKey;
        return _buildBookmarkTile(context, bookmark, current);
      },
    );
  }

  Widget _buildBookmarkTile(
    BuildContext context,
    Bookmark bookmark,
    bool current,
  ) {
    final chapterNumber =
        (bookmark.chapterIndex ?? bookmark.pageNumber).clamp(0, 1000000) + 1;
    final chapterTitle = bookmark.chapterTitle?.trim().isNotEmpty == true
        ? bookmark.chapterTitle!.trim()
        : context.l10n.readerChapterFallback(chapterNumber);
    final excerpt = bookmark.excerpt?.trim() ?? '';
    final date = bookmark.createDate;
    final dateText = '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    return Semantics(
      button: true,
      selected: current,
      label: chapterTitle,
      child: Material(
        color: current
            ? widget.palette.accent.withValues(alpha: 0.10)
            : widget.palette.controlBar.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: () => widget.onBookmarkSelected(bookmark),
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 13, 8, 13),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              chapterTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                          ),
                          if (current)
                            Container(
                              margin: const EdgeInsets.only(left: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: widget.palette.accent,
                                borderRadius: BorderRadius.circular(99),
                              ),
                              child: Text(
                                context.l10n.readerCurrentPosition,
                                style: TextStyle(
                                  color: widget.palette.onAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                        ],
                      ),
                      if (excerpt.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          excerpt,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: widget.palette.secondaryText,
                                    height: 1.45,
                                  ),
                        ),
                      ],
                      const SizedBox(height: 7),
                      Text(
                        dateText,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: widget.palette.secondaryText,
                            ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: MaterialLocalizations.of(context).showMenuTooltip,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    child: Text(
                      MaterialLocalizations.of(context).showMenuTooltip,
                      style: TextStyle(
                        color: widget.palette.secondaryText,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  onSelected: (value) {
                    if (value == 'delete') widget.onBookmarkDeleted(bookmark);
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        MaterialLocalizations.of(context).deleteButtonTooltip,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyState(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320),
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: widget.palette.secondaryText,
                      height: 1.5,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReaderNavigationTreeEntry {
  const _ReaderNavigationTreeEntry({
    required this.chapter,
    required this.position,
    required this.depth,
    required this.parentPosition,
    required this.hasChildren,
  });

  final ReaderNavigationChapter chapter;
  final int position;
  final int depth;
  final int? parentPosition;
  final bool hasChildren;
}
