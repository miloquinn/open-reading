import 'dart:convert';
import 'dart:io';

import 'package:epubx/epubx.dart' hide Image;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:html/dom.dart' as html_dom;
import 'package:path/path.dart' as path;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:xxread/models/book.dart';
import 'package:xxread/services/books/book_dao.dart';

enum NativePageMode { verticalScroll, instantPage, horizontalSlide }

class NativeReaderPage extends StatefulWidget {
  const NativeReaderPage({super.key, required this.book});

  final Book book;

  @override
  State<NativeReaderPage> createState() => _NativeReaderPageState();
}

class _NativeReaderPageState extends State<NativeReaderPage> {
  static const _pageModeKey = 'native_reader_page_mode';
  static const _textStyle = TextStyle(
    fontSize: 19,
    height: 1.75,
    letterSpacing: 0.2,
  );

  late final Future<List<_NativeChapter>> _chaptersFuture;
  final PageController _pageController = PageController();
  final Map<String, List<String>> _pageCache = {};
  int _chapterIndex = 0;
  int _pageIndex = 0;
  bool _openPreviousChapterAtLastPage = false;
  bool _controlsVisible = false;
  NativePageMode _pageMode = NativePageMode.verticalScroll;
  Offset? _pointerDownPosition;
  DateTime? _pointerDownTime;
  bool _pointerMoved = false;

  @override
  void initState() {
    super.initState();
    _chapterIndex = widget.book.currentPage;
    _chaptersFuture = _loadBook();
    _loadPageMode();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  Future<void> _loadPageMode() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_pageModeKey);
    if (!mounted || name == null) return;
    setState(() {
      _pageMode = NativePageMode.values.firstWhere(
        (mode) => mode.name == name,
        orElse: () => name == 'horizontalPage'
            ? NativePageMode.instantPage
            : NativePageMode.verticalScroll,
      );
    });
  }

  Future<void> _setPageMode(NativePageMode mode) async {
    if (_pageMode == mode) return;
    setState(() {
      _pageMode = mode;
      _pageIndex = 0;
      _controlsVisible = false;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pageModeKey, mode.name);
  }

  Future<List<_NativeChapter>> _loadBook() async {
    final bytes = await File(widget.book.filePath).readAsBytes();
    switch (widget.book.format.toLowerCase()) {
      case 'epub':
        final parsed = await compute(_parseEpubChapters, bytes);
        return parsed
            .map(
              (chapter) => _NativeChapter(
                title: chapter['title'] as String? ?? '',
                blocks: (chapter['blocks'] as List<dynamic>)
                    .map(
                      (block) => _NativeBlock.fromMap(
                        Map<String, String>.from(block as Map),
                      ),
                    )
                    .toList(growable: false),
              ),
            )
            .toList(growable: false);
      case 'txt':
        return <_NativeChapter>[
          _NativeChapter(
            title: widget.book.title,
            blocks: <_NativeBlock>[
              _NativeBlock.text(String.fromCharCodes(bytes)),
            ],
          ),
        ];
      default:
        throw UnsupportedError('当前原生阅读器仅支持 EPUB 和 TXT');
    }
  }

  Future<void> _setChapter(int index, int chapterCount) async {
    final next = index.clamp(0, chapterCount - 1);
    if (next == _chapterIndex) return;
    setState(() {
      _chapterIndex = next;
      _pageIndex = 0;
    });
    final bookId = widget.book.id;
    if (bookId != null) {
      await BookDao().updateBookProgress(bookId, next);
    }
  }

  void _nextPage(List<String> pages, int chapterCount) {
    if (_pageMode == NativePageMode.horizontalSlide &&
        _pageController.hasClients) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_pageIndex < pages.length - 1) {
      setState(() => _pageIndex++);
    } else if (_chapterIndex < chapterCount - 1) {
      _setChapter(_chapterIndex + 1, chapterCount);
    }
  }

  void _previousPage(List<String> pages, int chapterCount) {
    if (_pageMode == NativePageMode.horizontalSlide &&
        _pageController.hasClients) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    if (_pageIndex > 0) {
      setState(() => _pageIndex--);
    } else if (_chapterIndex > 0) {
      _openPreviousChapterAtLastPage = true;
      _setChapter(_chapterIndex - 1, chapterCount);
    }
  }

  void _handleHorizontalSwipe(
    DragEndDetails details,
    List<String> pages,
    int chapterCount,
  ) {
    final velocity = details.primaryVelocity ?? 0;
    if (_pageMode == NativePageMode.horizontalSlide) return;
    if (_pageMode == NativePageMode.instantPage) {
      if (velocity < -350) {
        _nextPage(pages, chapterCount);
      } else if (velocity > 350) {
        _previousPage(pages, chapterCount);
      }
      return;
    }
    if (velocity < -350) {
      _setChapter(_chapterIndex + 1, chapterCount);
    } else if (velocity > 350) {
      _setChapter(_chapterIndex - 1, chapterCount);
    }
  }

  void _handleTap(
    Offset localPosition,
    double width,
    List<String> pages,
    int chapterCount,
  ) {
    final fraction = localPosition.dx / width;
    if (fraction >= 1 / 3 && fraction <= 2 / 3) {
      setState(() => _controlsVisible = !_controlsVisible);
      return;
    }
    if (_pageMode == NativePageMode.verticalScroll) return;
    if (fraction < 1 / 3) {
      _previousPage(pages, chapterCount);
    } else {
      _nextPage(pages, chapterCount);
    }
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerDownPosition = event.localPosition;
    _pointerDownTime = DateTime.now();
    _pointerMoved = false;
  }

  void _onPointerMove(PointerMoveEvent event) {
    final start = _pointerDownPosition;
    if (start != null && (event.localPosition - start).distance > 14) {
      _pointerMoved = true;
    }
  }

  void _onPointerCancel(PointerCancelEvent event) {
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _pointerMoved = false;
  }

  void _onPointerUp(
    PointerUpEvent event,
    double width,
    List<String> pages,
    int chapterCount,
  ) {
    final startedAt = _pointerDownTime;
    final isQuickTap = startedAt != null &&
        DateTime.now().difference(startedAt) <
            const Duration(milliseconds: 500);
    if (!_pointerMoved && isQuickTap) {
      _handleTap(
        event.localPosition,
        width,
        pages,
        chapterCount,
      );
    }
    _pointerDownPosition = null;
    _pointerDownTime = null;
    _pointerMoved = false;
  }

  void _showReadingSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('阅读设置', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text('翻页方式', style: Theme.of(context).textTheme.titleMedium),
              RadioGroup<NativePageMode>(
                groupValue: _pageMode,
                onChanged: (mode) {
                  if (mode == null) return;
                  Navigator.of(sheetContext).pop();
                  _setPageMode(mode);
                },
                child: const Column(
                  children: [
                    RadioListTile<NativePageMode>(
                      value: NativePageMode.verticalScroll,
                      title: Text('纵向滚动'),
                      subtitle: Text('上下滚动正文，左右滑动切换章节'),
                    ),
                    RadioListTile<NativePageMode>(
                      value: NativePageMode.instantPage,
                      title: Text('水平分页'),
                      subtitle: Text('点击左侧上一页，点击右侧下一页'),
                    ),
                    RadioListTile<NativePageMode>(
                      value: NativePageMode.horizontalSlide,
                      title: Text('水平滑动'),
                      subtitle: Text('页面跟随手指横向移动并吸附翻页'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<String> _pagesFor(
    _NativeChapter chapter,
    int chapterIndex,
    Size size,
    TextDirection direction,
  ) {
    final key = '$chapterIndex:${size.width.round()}:${size.height.round()}';
    return _pageCache.putIfAbsent(
      key,
      () {
        final pages = _paginateText(
          chapter.plainText,
          maxWidth: size.width - 44,
          maxHeight: size.height - 88,
          direction: direction,
        );
        for (var i = 0; i < chapter.blocks.length; i++) {
          if (chapter.blocks[i].imageBase64 != null) {
            pages.add('\uFFFC$i');
          }
        }
        return pages;
      },
    );
  }

  Widget _buildPage(_NativeChapter chapter, String page) {
    if (page.startsWith('\uFFFC')) {
      final blockIndex = int.tryParse(page.substring(1));
      final bytes =
          blockIndex == null ? null : chapter.blocks[blockIndex].imageBytes;
      if (bytes != null) {
        return Center(child: Image.memory(bytes, fit: BoxFit.contain));
      }
    }
    return Text(page, style: _textStyle);
  }

  List<_BookPageRef> _bookPagesFor(
    List<_NativeChapter> chapters,
    Size size,
    TextDirection direction,
  ) {
    final result = <_BookPageRef>[];
    for (var chapterIndex = 0; chapterIndex < chapters.length; chapterIndex++) {
      final chapterPages = _pagesFor(
        chapters[chapterIndex],
        chapterIndex,
        size,
        direction,
      );
      for (var pageIndex = 0; pageIndex < chapterPages.length; pageIndex++) {
        result.add(
          _BookPageRef(
            chapterIndex: chapterIndex,
            pageIndex: pageIndex,
            content: chapterPages[pageIndex],
          ),
        );
      }
    }
    return result;
  }

  void _onBookPageChanged(int index, List<_BookPageRef> bookPages) {
    final page = bookPages[index];
    final chapterChanged = page.chapterIndex != _chapterIndex;
    setState(() {
      _chapterIndex = page.chapterIndex;
      _pageIndex = page.pageIndex;
    });
    if (chapterChanged && widget.book.id != null) {
      BookDao().updateBookProgress(widget.book.id!, page.chapterIndex);
    }
  }

  Widget _buildReaderContent(
    List<_NativeChapter> chapters,
    _NativeChapter chapter,
    List<String> pages,
    List<_BookPageRef> bookPages,
  ) {
    if (_pageMode == NativePageMode.verticalScroll) {
      return SelectionArea(
        child: SingleChildScrollView(
          key: ValueKey(_chapterIndex),
          padding: const EdgeInsets.fromLTRB(22, 42, 22, 56),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: chapter.blocks.map((block) {
              final imageBytes = block.imageBytes;
              if (imageBytes != null) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      imageBytes,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(block.text ?? '', style: _textStyle),
              );
            }).toList(growable: false),
          ),
        ),
      );
    }
    if (_pageMode == NativePageMode.horizontalSlide) {
      return PageView.builder(
        controller: _pageController,
        itemCount: bookPages.length,
        onPageChanged: (index) => _onBookPageChanged(index, bookPages),
        itemBuilder: (context, index) {
          final page = bookPages[index];
          return Padding(
            padding: const EdgeInsets.fromLTRB(22, 42, 22, 46),
            child: SizedBox.expand(
              child: _buildPage(
                chapters[page.chapterIndex],
                page.content,
              ),
            ),
          );
        },
      );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 42, 22, 46),
      child: SizedBox.expand(
        child: KeyedSubtree(
          key: ValueKey('$_chapterIndex:$_pageIndex'),
          child: _buildPage(chapter, pages[_pageIndex]),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<_NativeChapter>>(
      future: _chaptersFuture,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.book.title)),
            body: Center(child: Text('打开失败：${snapshot.error}')),
          );
        }
        final chapters = snapshot.data;
        if (chapters == null) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (chapters.isEmpty) {
          return const Scaffold(body: Center(child: Text('书籍没有可显示的正文')));
        }

        _chapterIndex = _chapterIndex.clamp(0, chapters.length - 1);
        final chapter = chapters[_chapterIndex];
        final colors = Theme.of(context).colorScheme;

        return Scaffold(
          body: LayoutBuilder(
            builder: (context, constraints) {
              final size = constraints.biggest;
              final pages = _pagesFor(
                chapter,
                _chapterIndex,
                size,
                Directionality.of(context),
              );
              final bookPages = _pageMode == NativePageMode.horizontalSlide
                  ? _bookPagesFor(
                      chapters,
                      size,
                      Directionality.of(context),
                    )
                  : const <_BookPageRef>[];
              if (_openPreviousChapterAtLastPage) {
                _pageIndex = pages.length - 1;
                _openPreviousChapterAtLastPage = false;
              }
              _pageIndex = _pageIndex.clamp(0, pages.length - 1);
              if (_pageMode == NativePageMode.horizontalSlide) {
                final targetPage = bookPages.indexWhere(
                  (page) =>
                      page.chapterIndex == _chapterIndex &&
                      page.pageIndex == _pageIndex,
                );
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!_pageController.hasClients) return;
                  final current = _pageController.page?.round();
                  if (targetPage >= 0 && current != targetPage) {
                    _pageController.jumpToPage(targetPage);
                  }
                });
              }

              return Stack(
                children: [
                  Positioned.fill(
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: _onPointerDown,
                      onPointerMove: _onPointerMove,
                      onPointerCancel: _onPointerCancel,
                      onPointerUp: (event) => _onPointerUp(
                        event,
                        size.width,
                        pages,
                        chapters.length,
                      ),
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onHorizontalDragEnd:
                            _pageMode == NativePageMode.horizontalSlide
                                ? null
                                : (details) => _handleHorizontalSwipe(
                                      details,
                                      pages,
                                      chapters.length,
                                    ),
                        child: _buildReaderContent(
                          chapters,
                          chapter,
                          pages,
                          bookPages,
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    left: 12,
                    right: 12,
                    top: _controlsVisible ? 8 : -130,
                    child: SafeArea(
                      bottom: false,
                      child: Material(
                        color: colors.surface.withValues(alpha: 0.94),
                        elevation: 12,
                        shadowColor: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(24),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          height: 64,
                          child: Row(
                            children: [
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back),
                              ),
                              Expanded(
                                child: Text(
                                  chapter.title.isEmpty
                                      ? widget.book.title
                                      : chapter.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                onPressed: _showReadingSettings,
                                tooltip: '阅读设置',
                                icon: const Icon(Icons.tune),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                    left: 20,
                    right: 20,
                    bottom: _controlsVisible ? 12 : -110,
                    child: SafeArea(
                      top: false,
                      child: Material(
                        color: colors.surface.withValues(alpha: 0.94),
                        elevation: 12,
                        shadowColor: Colors.black.withValues(alpha: 0.28),
                        borderRadius: BorderRadius.circular(22),
                        clipBehavior: Clip.antiAlias,
                        child: SizedBox(
                          height: 58,
                          child: Center(
                            child: Text(
                              _pageMode != NativePageMode.verticalScroll
                                  ? '第 ${_chapterIndex + 1}/${chapters.length} 章 · ${_pageIndex + 1}/${pages.length} 页'
                                  : '第 ${_chapterIndex + 1}/${chapters.length} 章 · 纵向滚动',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

List<String> _paginateText(
  String text, {
  required double maxWidth,
  required double maxHeight,
  required TextDirection direction,
}) {
  if (text.isEmpty || maxWidth <= 0 || maxHeight <= 0) return <String>[''];
  final pages = <String>[];
  var start = 0;
  while (start < text.length) {
    final remaining = text.substring(start);
    final painter = TextPainter(
      text: TextSpan(
        text: remaining,
        style: _NativeReaderPageState._textStyle,
      ),
      textDirection: direction,
    )..layout(maxWidth: maxWidth);
    if (painter.height <= maxHeight) {
      pages.add(remaining);
      break;
    }
    var end = painter.getPositionForOffset(Offset(maxWidth, maxHeight)).offset;
    end = end.clamp(1, remaining.length);
    final breakAt = remaining.lastIndexOf(RegExp(r'[\s，。！？；：,.!?;:]'), end);
    if (breakAt > end * 0.7) end = breakAt + 1;
    pages.add(remaining.substring(0, end).trim());
    start += end;
    while (start < text.length && text.codeUnitAt(start) <= 32) {
      start++;
    }
  }
  return pages.isEmpty ? <String>[''] : pages;
}

class _NativeChapter {
  const _NativeChapter({required this.title, required this.blocks});

  final String title;
  final List<_NativeBlock> blocks;

  String get plainText => blocks
      .where((block) => block.text != null)
      .map((block) => block.text!)
      .join('\n\n');
}

class _BookPageRef {
  const _BookPageRef({
    required this.chapterIndex,
    required this.pageIndex,
    required this.content,
  });

  final int chapterIndex;
  final int pageIndex;
  final String content;
}

class _NativeBlock {
  const _NativeBlock._({this.text, this.imageBase64});

  factory _NativeBlock.text(String text) => _NativeBlock._(text: text);

  factory _NativeBlock.fromMap(Map<String, String> map) => _NativeBlock._(
        text: map['type'] == 'text' ? map['content'] : null,
        imageBase64: map['type'] == 'image' ? map['content'] : null,
      );

  final String? text;
  final String? imageBase64;

  Uint8List? get imageBytes =>
      imageBase64 == null ? null : base64Decode(imageBase64!);
}

Future<List<Map<String, dynamic>>> _parseEpubChapters(Uint8List bytes) async {
  final epub = await EpubReader.readBook(bytes);
  final result = <Map<String, dynamic>>[];
  final imagesByName = <String, String>{};

  final imageEntries = epub.Content?.Images?.entries;
  if (imageEntries != null) {
    for (final entry in imageEntries) {
      final content = entry.value.Content;
      if (content == null || content.isEmpty) continue;
      final name = path.basename(Uri.decodeFull(entry.key)).toLowerCase();
      imagesByName[name] = base64Encode(content);
    }
  }

  void append(List<EpubChapter>? chapters) {
    if (chapters == null) return;
    for (final chapter in chapters) {
      final document = html_parser.parse(chapter.HtmlContent ?? '');
      final blocks = <Map<String, String>>[];
      final elements = document.body?.querySelectorAll(
            'h1,h2,h3,h4,h5,h6,p,li,blockquote,pre,img,svg image',
          ) ??
          const <html_dom.Element>[];
      for (final element in elements) {
        final isImage = element.localName == 'img' ||
            (element.localName == 'image' && element.namespaceUri != null);
        if (isImage) {
          final src = element.attributes['src'] ??
              element.attributes['href'] ??
              element.attributes['xlink:href'];
          if (src == null || src.startsWith('data:')) continue;
          final name = path
              .basename(Uri.decodeFull(src.split('?').first.split('#').first))
              .toLowerCase();
          final encoded = imagesByName[name];
          if (encoded != null) {
            blocks.add(<String, String>{'type': 'image', 'content': encoded});
          }
          continue;
        }
        final text = element.text
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .replaceAll(RegExp(r'\n\s*\n+'), '\n\n')
            .trim();
        if (text.isNotEmpty) {
          blocks.add(<String, String>{'type': 'text', 'content': text});
        }
      }
      if (blocks.isEmpty) {
        final fallback = document.body?.text.trim() ?? '';
        if (fallback.isNotEmpty) {
          blocks.add(<String, String>{'type': 'text', 'content': fallback});
        }
      }
      if (blocks.isNotEmpty) {
        result.add(<String, dynamic>{
          'title': chapter.Title ?? '',
          'blocks': blocks,
        });
      }
      append(chapter.SubChapters);
    }
  }

  append(epub.Chapters);
  return result;
}
