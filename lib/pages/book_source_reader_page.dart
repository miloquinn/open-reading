import 'dart:async';

import 'package:flutter/material.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import '../book_sources/models/registered_book_source.dart';
import '../book_sources/protocol/book_source_protocol.dart';
import '../book_sources/services/book_source_client.dart';
import '../utils/localization_extension.dart';

/// Reads chapters streamed from an Open Reading book source.
///
/// Remote chapters stay separate from the local-file reader and are fetched on
/// demand, so opening a source book does not create a fake local import.
class BookSourceReaderPage extends StatefulWidget {
  final RegisteredBookSource source;
  final BookSourceBook book;
  final BookSourceClient? client;

  const BookSourceReaderPage({
    super.key,
    required this.source,
    required this.book,
    this.client,
  });

  @override
  State<BookSourceReaderPage> createState() => _BookSourceReaderPageState();
}

class _BookSourceReaderPageState extends State<BookSourceReaderPage> {
  late final BookSourceClient _client = widget.client ?? BookSourceClient();
  final ScrollController _scrollController = ScrollController();

  List<BookSourceChapter> _chapters = const [];
  BookSourceChapterContent? _content;
  int _chapterIndex = 0;
  bool _loadingCatalog = true;
  bool _loadingContent = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalog());
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCatalog() async {
    setState(() {
      _loadingCatalog = true;
      _error = null;
    });
    try {
      final chapters = [
        ...await _client.getChapters(widget.source, widget.book.id),
      ]..sort((a, b) => a.order.compareTo(b.order));
      if (!mounted) return;
      setState(() {
        _chapters = chapters;
        _loadingCatalog = false;
      });
      if (chapters.isNotEmpty) await _loadChapter(0);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingCatalog = false;
        _error = error;
      });
    }
  }

  Future<void> _loadChapter(int index) async {
    if (index < 0 || index >= _chapters.length || _loadingContent) return;
    setState(() {
      _chapterIndex = index;
      _loadingContent = true;
      _content = null;
      _error = null;
    });
    if (_scrollController.hasClients) _scrollController.jumpTo(0);
    try {
      final chapter = _chapters[index];
      final content = await _client.getChapterContent(
        widget.source,
        bookId: widget.book.id,
        chapterId: chapter.id,
      );
      if (!mounted || index != _chapterIndex) return;
      setState(() {
        _content = content;
        _loadingContent = false;
      });
    } catch (error) {
      if (!mounted || index != _chapterIndex) return;
      setState(() {
        _loadingContent = false;
        _error = error;
      });
    }
  }

  Future<void> _showCatalog() async {
    if (_chapters.isEmpty) return;
    final selected = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.72,
          child: ListView.builder(
            itemCount: _chapters.length,
            itemBuilder: (context, index) {
              final isSelected = index == _chapterIndex;
              return ListTile(
                selected: isSelected,
                leading: isSelected
                    ? Icon(
                        Icons.play_arrow_rounded,
                        color: Theme.of(context).colorScheme.primary,
                      )
                    : Text('${index + 1}'),
                title: Text(_chapters[index].title),
                onTap: () => Navigator.pop(context, index),
              );
            },
          ),
        ),
      ),
    );
    if (selected != null && selected != _chapterIndex) {
      await _loadChapter(selected);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(widget.book.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: context.l10n.readerToolbarTOC,
            onPressed: _chapters.isEmpty ? null : _showCatalog,
            icon: const Icon(Icons.format_list_bulleted_rounded),
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _chapters.isEmpty ? null : _buildChapterNavigation(),
    );
  }

  Widget _buildBody() {
    if (_loadingCatalog || _loadingContent) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44),
              const SizedBox(height: 12),
              Text(
                _error.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _chapters.isEmpty
                    ? _loadCatalog
                    : () => _loadChapter(_chapterIndex),
                child: Text(context.l10n.retry),
              ),
            ],
          ),
        ),
      );
    }
    if (_chapters.isEmpty || _content == null) {
      return Center(child: Text(context.l10n.readerNoContent));
    }

    final content = _content!;
    final chapterTitle =
        content.title.isEmpty ? _chapters[_chapterIndex].title : content.title;
    return SelectionArea(
      child: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapterTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        height: 1.35,
                      ),
                ),
                const SizedBox(height: 24),
                Text(
                  _readableChapterText(content),
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        fontFamily: 'SourceHanSansCN',
                        fontSize: 18,
                        height: 1.85,
                        letterSpacing: 0.25,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChapterNavigation() {
    final canGoPrevious = !_loadingContent && _chapterIndex > 0;
    final canGoNext = !_loadingContent && _chapterIndex < _chapters.length - 1;
    return SafeArea(
      top: false,
      child: Material(
        elevation: 8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: canGoPrevious
                      ? () => _loadChapter(_chapterIndex - 1)
                      : null,
                  icon: const Icon(Icons.chevron_left_rounded),
                  label: Text(context.l10n.previous),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text('${_chapterIndex + 1}/${_chapters.length}'),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed:
                      canGoNext ? () => _loadChapter(_chapterIndex + 1) : null,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.chevron_right_rounded),
                  label: Text(context.l10n.next),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _readableChapterText(BookSourceChapterContent content) {
  if (content.contentType != 'text/html') return content.content.trim();
  final fragment = html_parser.parseFragment(content.content);
  final buffer = StringBuffer();

  void appendNode(dom.Node node) {
    if (node is dom.Text) {
      buffer.write(node.data);
      return;
    }
    if (node is! dom.Element) return;
    if (node.localName == 'br') buffer.writeln();
    for (final child in node.nodes) {
      appendNode(child);
    }
    if (const {
      'p',
      'div',
      'li',
      'blockquote',
      'h1',
      'h2',
      'h3',
      'h4',
      'h5',
      'h6',
    }.contains(node.localName)) {
      buffer.writeln();
      buffer.writeln();
    }
  }

  for (final node in fragment.nodes) {
    appendNode(node);
  }
  return buffer
      .toString()
      .replaceAll(RegExp(r'[ \t]+\n'), '\n')
      .replaceAll(RegExp(r'\n{3,}'), '\n\n')
      .trim();
}
