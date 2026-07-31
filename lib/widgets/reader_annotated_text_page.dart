import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'package:xxread/core/reader/canonical_locator.dart';
import 'package:xxread/core/reader/native_text_paginator.dart';
import 'package:xxread/core/reader/reader_aloud_controller.dart';
import 'package:xxread/core/reader/reader_annotation.dart';
import 'package:xxread/core/reader/reader_text_pagination.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/reader_themes.dart';
import 'package:xxread/widgets/reader_text_page_content.dart';

typedef ReaderTextAnnotationSaveCallback =
    Future<void> Function(
      ReaderSelectionSnapshot selection,
      ReaderAnnotationEditorResult annotation,
    );

/// Shared selectable, annotated text leaf used by local and book-source readers.
///
/// Selection offsets are captured with [SelectionListener] and translated back
/// through [ReaderTextPage.sourceOffsetForTextOffset], keeping stored anchors
/// independent from generated indentation, paragraph spacing and pagination.
class ReaderAnnotatedTextPage extends StatefulWidget {
  const ReaderAnnotatedTextPage({
    super.key,
    required this.page,
    required this.sourceText,
    required this.chapterId,
    required this.chapterTitle,
    required this.chapterIndex,
    required this.pageIndex,
    required this.bookId,
    required this.format,
    required this.renderer,
    required this.palette,
    required this.bodyStyle,
    required this.flowStyle,
    required this.annotations,
    required this.onSaveTextAnnotation,
    this.spokenHighlight,
    this.baseSourceSpanBuilder,
    this.onAnnotationUnavailable,
    this.onInteractionChanged,
    this.onAskAiSelection,
    this.fillAvailableSpace = true,
  });

  final ReaderTextPage page;
  final String sourceText;
  final String chapterId;
  final String chapterTitle;
  final int chapterIndex;
  final int pageIndex;
  final int? bookId;
  final BookFormat format;
  final ReaderRendererType renderer;
  final ReaderThemePalette palette;
  final TextStyle bodyStyle;
  final NativeTextFlowStyle flowStyle;
  final List<BookNote> annotations;
  final ReaderAloudHighlight? spokenHighlight;
  final TextSpan Function(int start, int end)? baseSourceSpanBuilder;
  final VoidCallback? onAnnotationUnavailable;
  final ReaderTextAnnotationSaveCallback onSaveTextAnnotation;
  final ValueChanged<bool>? onInteractionChanged;
  final Future<void> Function(ReaderSelectionSnapshot selection)?
  onAskAiSelection;
  final bool fillAvailableSpace;

  @override
  State<ReaderAnnotatedTextPage> createState() =>
      _ReaderAnnotatedTextPageState();
}

class _ReaderAnnotatedTextPageState extends State<ReaderAnnotatedTextPage> {
  final SelectionListenerNotifier _selectionNotifier =
      SelectionListenerNotifier();
  final Map<String, TapGestureRecognizer> _noteRecognizers = {};

  @override
  void dispose() {
    for (final recognizer in _noteRecognizers.values) {
      recognizer.dispose();
    }
    _selectionNotifier.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant ReaderAnnotatedTextPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final activeIds = widget.annotations
        .where((annotation) => annotation.type == readerAnnotationTypeNote)
        .map((annotation) => annotation.annotationId)
        .toSet();
    final removedIds = _noteRecognizers.keys
        .where((annotationId) => !activeIds.contains(annotationId))
        .toList(growable: false);
    for (final annotationId in removedIds) {
      _noteRecognizers.remove(annotationId)?.dispose();
    }
  }

  ReaderSelectionSnapshot? get _selectionSnapshot {
    if (!_selectionNotifier.registered || widget.page.isChapterTitle) {
      return null;
    }
    final range = _selectionNotifier.selection.range;
    if (range == null || range.startOffset == range.endOffset) return null;
    final localStart = math.min(range.startOffset, range.endOffset);
    final localEnd = math.max(range.startOffset, range.endOffset);
    final sourceStart = widget.page.sourceOffsetForTextOffset(
      localStart,
      preferVisibleStart: true,
    );
    final sourceEnd = widget.page.sourceOffsetForTextOffset(localEnd);
    if (sourceStart >= sourceEnd) return null;
    return ReaderSelectionSnapshot(
      bookId: widget.bookId,
      format: widget.format,
      renderer: widget.renderer,
      chapterId: widget.chapterId,
      chapterTitle: widget.chapterTitle,
      chapterIndex: widget.chapterIndex,
      pageIndex: widget.pageIndex,
      sourceText: widget.sourceText,
      startOffset: sourceStart,
      endOffset: sourceEnd,
    );
  }

  TextSpan _annotatedSpan(int start, int end) => buildReaderAnnotatedSpan(
    sourceText: widget.sourceText,
    start: start,
    end: end,
    baseStyle: widget.bodyStyle,
    palette: widget.palette,
    annotations: readerTextAnnotationsForChapter(
      widget.annotations,
      widget.chapterId,
    ),
    spokenHighlight:
        widget.spokenHighlight?.matches(
              chapterIndex: widget.chapterIndex,
              chapterId: widget.chapterId,
            ) ==
            true
        ? widget.spokenHighlight
        : null,
    baseSpanBuilder: widget.baseSourceSpanBuilder,
    recognizerBuilder: _recognizerForNote,
  );

  GestureRecognizer _recognizerForNote(BookNote annotation) {
    final recognizer = _noteRecognizers.putIfAbsent(
      annotation.annotationId,
      TapGestureRecognizer.new,
    );
    recognizer.onTap = () => unawaited(_showNote(annotation));
    return recognizer;
  }

  Future<void> _showNote(BookNote annotation) async {
    widget.onInteractionChanged?.call(true);
    try {
      await showReaderAnnotationDetails(
        context,
        palette: widget.palette,
        annotation: annotation,
      );
    } finally {
      widget.onInteractionChanged?.call(false);
    }
  }

  void _clearSelection(SelectableRegionState regionState) {
    regionState.hideToolbar();
    regionState.clearSelection();
  }

  bool _ensureCanAnnotate(SelectableRegionState regionState) {
    if (widget.bookId != null) return true;
    _clearSelection(regionState);
    widget.onAnnotationUnavailable?.call();
    return false;
  }

  Future<void> _createHighlight(SelectableRegionState regionState) async {
    final selection = _selectionSnapshot;
    if (selection == null) return;
    if (!_ensureCanAnnotate(regionState)) return;
    _clearSelection(regionState);
    final result = await showReaderAnnotationEditor(
      context,
      palette: widget.palette,
      selection: selection,
      withNote: false,
    );
    if (result != null) {
      await widget.onSaveTextAnnotation(selection, result);
    }
  }

  Future<void> _createNote(SelectableRegionState regionState) async {
    final selection = _selectionSnapshot;
    if (selection == null) return;
    if (!_ensureCanAnnotate(regionState)) return;
    _clearSelection(regionState);
    final result = await showReaderAnnotationEditor(
      context,
      palette: widget.palette,
      selection: selection,
      withNote: true,
    );
    if (result != null) {
      await widget.onSaveTextAnnotation(selection, result);
    }
  }

  Future<void> _askAi(SelectableRegionState regionState) async {
    final selection = _selectionSnapshot;
    final handler = widget.onAskAiSelection;
    if (selection == null || handler == null) return;
    _clearSelection(regionState);
    widget.onInteractionChanged?.call(true);
    try {
      await handler(selection);
    } finally {
      widget.onInteractionChanged?.call(false);
    }
  }

  Widget _buildSelectionToolbar(
    BuildContext context,
    SelectableRegionState regionState,
  ) {
    final copyItem = regionState.contextMenuButtonItems
        .where((item) => item.type == ContextMenuButtonType.copy)
        .firstOrNull;
    return ReaderSelectionToolbar(
      palette: widget.palette,
      anchors: regionState.contextMenuAnchors,
      onHighlight: () => unawaited(_createHighlight(regionState)),
      onNote: () => unawaited(_createNote(regionState)),
      onCopy: copyItem?.onPressed,
      onAskAi: widget.onAskAiSelection == null
          ? null
          : () => unawaited(_askAi(regionState)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = SelectionArea(
      contextMenuBuilder: _buildSelectionToolbar,
      child: SelectionListener(
        selectionNotifier: _selectionNotifier,
        child: ReaderTextPageContent(
          page: widget.page,
          chapterTitle: widget.chapterTitle,
          bodyStyle: widget.bodyStyle,
          flowStyle: widget.flowStyle,
          sourceSpanBuilder: _annotatedSpan,
        ),
      ),
    );
    return widget.fillAvailableSpace
        ? Stack(fit: StackFit.expand, children: [text])
        : text;
  }
}

class ReaderSelectionToolbar extends StatelessWidget {
  const ReaderSelectionToolbar({
    super.key,
    required this.palette,
    required this.anchors,
    required this.onHighlight,
    required this.onNote,
    required this.onCopy,
    this.onAskAi,
  });

  final ReaderThemePalette palette;
  final TextSelectionToolbarAnchors anchors;
  final VoidCallback onHighlight;
  final VoidCallback onNote;
  final VoidCallback? onCopy;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    return TextSelectionToolbar(
      anchorAbove: anchors.primaryAnchor,
      anchorBelow: anchors.secondaryAnchor ?? anchors.primaryAnchor,
      toolbarBuilder: (context, child) => Material(
        key: const ValueKey('reader-selection-toolbar'),
        color: palette.controlBar,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border.withValues(alpha: 0.72)),
            boxShadow: [
              BoxShadow(
                color: palette.shadow.withValues(
                  alpha: palette.brightness == Brightness.dark ? 0.42 : 0.16,
                ),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        ),
      ),
      children: [
        _ReaderSelectionAction(
          icon: Icons.auto_awesome_rounded,
          label: context.l10n.highlights,
          color: palette.accent,
          onPressed: onHighlight,
        ),
        _ReaderSelectionAction(
          icon: Icons.mode_comment_outlined,
          label: context.l10n.notes,
          color: palette.text,
          onPressed: onNote,
        ),
        if (onAskAi != null)
          _ReaderSelectionAction(
            icon: Icons.auto_awesome_outlined,
            label: context.l10n.readerAskAi,
            color: palette.text,
            onPressed: onAskAi,
          ),
        _ReaderSelectionAction(
          icon: Icons.content_copy_rounded,
          label: material.copyButtonLabel,
          color: palette.text,
          onPressed: onCopy,
        ),
      ],
    );
  }
}

class _ReaderSelectionAction extends StatelessWidget {
  const _ReaderSelectionAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 72, minHeight: 44),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: onPressed == null
                    ? color.withValues(alpha: 0.38)
                    : color,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: onPressed == null
                      ? color.withValues(alpha: 0.38)
                      : color,
                  fontSize: 12,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> showReaderAnnotationDetails(
  BuildContext context, {
  required ReaderThemePalette palette,
  required BookNote annotation,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: Colors.transparent,
  barrierColor: palette.shadow.withValues(
    alpha: palette.brightness == Brightness.dark ? 0.72 : 0.36,
  ),
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 620),
  builder: (context) {
    final note = annotation.readerNote?.trim() ?? '';
    final quote = annotation.content.replaceAll(RegExp(r'\s+'), ' ').trim();
    final theme = palette.toThemeData(typography: Theme.of(context).textTheme);
    return Theme(
      data: theme,
      child: Material(
        key: const ValueKey('reader-annotation-detail-sheet'),
        color: palette.surface,
        surfaceTintColor: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: palette.secondaryText.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.mode_comment_outlined, color: palette.accent),
                      const SizedBox(width: 9),
                      Text(
                        context.l10n.notes,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (quote.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: palette.controlBar,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: palette.border.withValues(alpha: 0.66),
                        ),
                      ),
                      child: Text(
                        quote,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          height: 1.55,
                          color: palette.secondaryText,
                        ),
                      ),
                    ),
                  ],
                  if (note.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    SelectableText(
                      note,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyLarge?.copyWith(height: 1.65),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                      ),
                      child: Text(context.l10n.confirm),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  },
);

Future<ReaderAnnotationEditorResult?> showReaderAnnotationEditor(
  BuildContext context, {
  required ReaderThemePalette palette,
  required ReaderSelectionSnapshot selection,
  required bool withNote,
}) => showModalBottomSheet<ReaderAnnotationEditorResult>(
  context: context,
  backgroundColor: Colors.transparent,
  barrierColor: palette.shadow.withValues(
    alpha: palette.brightness == Brightness.dark ? 0.72 : 0.36,
  ),
  isScrollControlled: true,
  constraints: const BoxConstraints(maxWidth: 620),
  builder: (context) => _ReaderAnnotationEditorSheet(
    palette: palette,
    selection: selection,
    withNote: withNote,
  ),
);

class _ReaderAnnotationEditorSheet extends StatefulWidget {
  const _ReaderAnnotationEditorSheet({
    required this.palette,
    required this.selection,
    required this.withNote,
  });

  final ReaderThemePalette palette;
  final ReaderSelectionSnapshot selection;
  final bool withNote;

  @override
  State<_ReaderAnnotationEditorSheet> createState() =>
      _ReaderAnnotationEditorSheetState();
}

class _ReaderAnnotationEditorSheetState
    extends State<_ReaderAnnotationEditorSheet> {
  late final TextEditingController _noteController = TextEditingController();
  String _type = readerAnnotationTypeHighlight;
  String _colorHex = 'FFD54F';

  List<Color> get _colors => <Color>[
    const Color(0xFFFFD54F),
    const Color(0xFF7DD3FC),
    const Color(0xFF86EFAC),
    const Color(0xFFF0ABFC),
    const Color(0xFFFF9A76),
    widget.palette.accent,
  ];

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  void _submit() {
    final note = _noteController.text.trim();
    if (widget.withNote && note.isEmpty) return;
    Navigator.of(context).pop(
      ReaderAnnotationEditorResult(
        type: widget.withNote ? readerAnnotationTypeNote : _type,
        colorHex: _colorHex,
        note: widget.withNote ? note : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final theme = widget.palette.toThemeData(
      typography: Theme.of(context).textTheme,
    );
    return Theme(
      data: theme,
      child: Material(
        color: widget.palette.surface,
        surfaceTintColor: Colors.transparent,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: widget.palette.secondaryText.withValues(
                        alpha: 0.32,
                      ),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.withNote
                      ? context.l10n.readerAddAnnotation
                      : context.l10n.highlights,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: widget.palette.controlBar,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: widget.palette.border.withValues(alpha: 0.66),
                    ),
                  ),
                  child: Text(
                    widget.selection.selectedText
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim(),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      height: 1.55,
                      color: widget.palette.secondaryText,
                    ),
                  ),
                ),
                if (!widget.withNote) ...[
                  const SizedBox(height: 16),
                  SegmentedButton<String>(
                    segments: [
                      ButtonSegment(
                        value: readerAnnotationTypeHighlight,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: Text(context.l10n.noteTypeHighlight),
                      ),
                      ButtonSegment(
                        value: readerAnnotationTypeUnderline,
                        icon: const Icon(Icons.format_underlined_rounded),
                        label: Text(context.l10n.noteTypeUnderline),
                      ),
                    ],
                    selected: <String>{_type},
                    onSelectionChanged: (value) =>
                        setState(() => _type = value.first),
                  ),
                ],
                const SizedBox(height: 16),
                Text(
                  context.l10n.highlightColor,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final color in _colors)
                      _ReaderColorChoice(
                        color: color,
                        selected: _colorHex == readerColorHex(color),
                        onTap: () =>
                            setState(() => _colorHex = readerColorHex(color)),
                      ),
                  ],
                ),
                if (widget.withNote) ...[
                  const SizedBox(height: 18),
                  TextField(
                    key: const ValueKey('reader-annotation-note-field'),
                    controller: _noteController,
                    autofocus: true,
                    minLines: 3,
                    maxLines: 7,
                    textInputAction: TextInputAction.newline,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      hintText: context.l10n.readerAnnotationHint,
                      filled: true,
                      fillColor: widget.palette.controlBar,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        child: Text(context.l10n.cancel),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed:
                            widget.withNote &&
                                _noteController.text.trim().isEmpty
                            ? null
                            : _submit,
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(50),
                        ),
                        icon: const Icon(Icons.check_rounded),
                        label: Text(context.l10n.save),
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
}

class _ReaderColorChoice extends StatelessWidget {
  const _ReaderColorChoice({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkResponse(
        onTap: onTap,
        radius: 26,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 42,
          height: 42,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.onSurface
                  : Colors.transparent,
              width: 2,
            ),
          ),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.28), blurRadius: 8),
              ],
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 18,
                    color:
                        ThemeData.estimateBrightnessForColor(color) ==
                            Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    return iterator.moveNext() ? iterator.current : null;
  }
}
