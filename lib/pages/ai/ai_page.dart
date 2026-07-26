// 文件说明：AI 导航页，进入即为对话界面；左上角入口打开历史记录。
// 技术要点：壳层内嵌聊天、选书注入知识库与笔记上下文、AiChatHistoryStore 落盘。

import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:xxread/models/book.dart';
import 'package:xxread/models/book_note.dart';
import 'package:xxread/pages/ai/ai_history_page.dart';
import 'package:xxread/pages/home/home_mobile_chrome.dart';
import 'package:xxread/pages/home/home_shell_page.dart';
import 'package:xxread/reader_core/ai/ai_error_translator.dart';
import 'package:xxread/reader_core/ai/ai_service.dart';
import 'package:xxread/services/ai/ai_chat_history_store.dart';
import 'package:xxread/services/ai/ai_request_coordinator.dart';
import 'package:xxread/services/ai/global_ai_reading_service.dart';
import 'package:xxread/services/books/book_dao.dart';
import 'package:xxread/services/books/book_note_dao.dart';
import 'package:xxread/utils/glass_config.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';
import 'package:xxread/utils/ui_style.dart';
import 'package:xxread/widgets/release_notes_markdown.dart';

class _AiChatEntry {
  _AiChatEntry({required this.role, required this.text}) : at = DateTime.now();

  _AiChatEntry.restored({
    required this.role,
    required this.text,
    required this.at,
  });

  final String role;
  final String text;
  final DateTime at;
}

/// 壳层顶栏与 AI 页之间的轻量桥：顶栏右侧工具按钮驱动页面行为。
class AiPageController {
  _AiPageState? _state;

  void openHistory() {
    final state = _state;
    if (state != null) unawaited(state._openHistory());
  }

  void startNewChat() => _state?._startNewChat();
}

/// AI 页：悬浮导航直达的对话界面。
class AiPage extends StatefulWidget {
  const AiPage({super.key, this.controller, this.aiService});

  final AiPageController? controller;
  final ConfigurableAIService? aiService;

  @override
  State<AiPage> createState() => _AiPageState();
}

class _AiPageState extends State<AiPage> {
  late final ConfigurableAIService _ai =
      widget.aiService ?? ReaderHttpAIService();
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AiChatHistoryStore _historyStore = AiChatHistoryStore();
  final List<_AiChatEntry> _entries = [];

  bool _configured = false;
  bool _configChecked = false;
  bool _sending = false;
  String? _error;
  String? _sessionId;
  DateTime? _sessionCreatedAt;

  Book? _selectedBook;
  String _bookContext = '';
  bool _bookContextLoading = false;
  bool _lastKeyboardVisible = false;

  @override
  void initState() {
    super.initState();
    widget.controller?._state = this;
    unawaited(_checkConfigured());
  }

  @override
  void dispose() {
    if (widget.controller?._state == this) {
      widget.controller?._state = null;
    }
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _checkConfigured() async {
    var configured = false;
    try {
      configured = (await _ai.loadSettings()).isConfigured;
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _configured = configured;
      _configChecked = true;
    });
  }

  Future<void> _openHistory() async {
    final session = await Navigator.of(context).push<AiChatHistorySession>(
      MaterialPageRoute<AiChatHistorySession>(
        builder: (_) => const AiHistoryPage(),
      ),
    );
    if (session == null || !mounted || _sending) return;
    await _restoreSession(session);
  }

  /// 载入历史会话继续对话：沿用原会话 ID，后续问答仍更新同一条记录。
  Future<void> _restoreSession(AiChatHistorySession session) async {
    setState(() {
      _entries
        ..clear()
        ..addAll(
          session.messages.map(
            (message) => _AiChatEntry.restored(
              role: message.role,
              text: message.text,
              at: message.at,
            ),
          ),
        );
      _error = null;
      _sessionId = session.id;
      _sessionCreatedAt = session.createdAt;
      _selectedBook = null;
      _bookContext = '';
    });
    _scrollToBottomSoon();

    // 恢复关联书籍：优先按存储的书籍 ID，老记录退回书名匹配。
    Book? book;
    try {
      final numericId = int.tryParse(session.bookId ?? '');
      if (numericId != null) {
        book = await BookDao().getBookById(numericId);
      }
      if (book == null && session.bookTitle.trim().isNotEmpty) {
        final books = await BookDao().getAllBooks();
        book = books
            .where((candidate) => candidate.title == session.bookTitle.trim())
            .firstOrNull;
      }
    } catch (_) {}
    if (!mounted || book == null) return;
    final restoredBook = book;
    setState(() {
      _selectedBook = restoredBook;
      _bookContextLoading = true;
    });
    final loaded = await _buildBookContext(restoredBook);
    if (!mounted) return;
    setState(() {
      _bookContext = loaded;
      _bookContextLoading = false;
    });
  }

  /// 开启新对话：当前会话已持久化，直接清空重来。
  void _startNewChat() {
    if (_entries.isEmpty && _error == null) return;
    setState(() {
      _entries.clear();
      _error = null;
      _sessionId = null;
      _sessionCreatedAt = null;
    });
  }

  /// 输入框左侧加号菜单：书籍关联入口。
  Future<void> _showPlusMenu() async {
    final selectedTitle = _selectedBook?.title;
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.menu_book_outlined),
              title: Text(sheetContext.l10n.aiChatSelectBook),
              subtitle: selectedTitle == null
                  ? null
                  : Text(
                      selectedTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
              onTap: () => Navigator.of(sheetContext).pop('pick'),
            ),
            if (selectedTitle != null)
              ListTile(
                leading: const Icon(Icons.link_off_rounded),
                title: Text(sheetContext.l10n.aiChatNoBook),
                onTap: () => Navigator.of(sheetContext).pop('clear'),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'pick':
        await _pickBook();
      case 'clear':
        setState(() {
          _selectedBook = null;
          _bookContext = '';
        });
    }
  }

  Future<void> _pickBook() async {
    List<Book> books = const [];
    try {
      books = await BookDao().getAllBooks();
    } catch (_) {}
    if (!mounted) return;
    final selection = await showModalBottomSheet<Object>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: 720,
        maxHeight: MediaQuery.sizeOf(context).height * 0.7,
      ),
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.block_outlined),
              title: Text(l10n.aiChatNoBook),
              onTap: () => Navigator.of(sheetContext).pop('none'),
            ),
            for (final book in books)
              ListTile(
                leading: const Icon(Icons.menu_book_outlined),
                title: Text(
                  book.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: book.author.trim().isEmpty
                    ? null
                    : Text(
                        book.author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                onTap: () => Navigator.of(sheetContext).pop(book),
              ),
          ],
        );
      },
    );
    if (!mounted || selection == null) return;
    if (selection == 'none') {
      setState(() {
        _selectedBook = null;
        _bookContext = '';
      });
      return;
    }
    final book = selection as Book;
    setState(() {
      _selectedBook = book;
      _bookContext = '';
      _bookContextLoading = true;
    });
    final loaded = await _buildBookContext(book);
    if (!mounted) return;
    setState(() {
      _bookContext = loaded;
      _bookContextLoading = false;
    });
  }

  /// 注入内容 = 预处理摘要（若有）+ 用户笔记/高亮；总长受服务端 2800 字符
  /// 压缩约束，这里主动裁剪并保证两部分都有配额。
  Future<String> _buildBookContext(Book book) async {
    final buffer = StringBuffer();
    final bookId = book.id?.toString() ?? '';
    try {
      final summary = bookId.isEmpty
          ? null
          : await GlobalAIReadingService().loadBookSummary(bookId);
      if (summary != null) {
        final trimmed = summary.length > 1800
            ? '${summary.substring(0, 1800)}…'
            : summary;
        buffer
          ..writeln('【《${book.title}》本地知识库摘要】')
          ..writeln(trimmed)
          ..writeln();
      }
    } catch (_) {}
    try {
      final notes = book.id == null
          ? const <BookNote>[]
          : await BookNoteDao().selectBookNotesByBookId(book.id!);
      if (notes.isNotEmpty) {
        buffer.writeln('【用户在《${book.title}》中的笔记与高亮】');
        var used = 0;
        for (final note in notes) {
          final label = switch (note.type) {
            'note' => '笔记',
            'underline' => '下划线',
            _ => '高亮',
          };
          final quote = note.content.replaceAll(RegExp(r'\s+'), ' ').trim();
          final own = note.readerNote?.trim() ?? '';
          final line = '- [$label] $quote${own.isEmpty ? '' : '（批注：$own）'}';
          if (used + line.length > 900) break;
          used += line.length;
          buffer.writeln(line);
        }
      }
    } catch (_) {}
    return buffer.toString().trim();
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending || !_configured) return;
    _inputController.clear();
    setState(() {
      _entries.add(_AiChatEntry(role: 'user', text: text));
      _sending = true;
      _error = null;
    });
    _scrollToBottomSoon();
    try {
      final history = _entries
          .map((entry) => AIChatMessage(role: entry.role, content: entry.text))
          .toList(growable: false);
      // 交互式请求登记到协调器：后台预处理会让行，对话不排队。
      final answer = await AiRequestCoordinator().runInteractive(
        () => _ai.chat(
          history: history,
          pageText: _bookContext,
          meta: AIRequestMeta(
            bookId: _selectedBook?.id?.toString() ?? '',
            chapterId: 'ai-page-chat',
          ),
        ),
      );
      if (!mounted) return;
      setState(() {
        _entries.add(
          _AiChatEntry(
            role: 'assistant',
            text: translateMockAiResponse(context, answer),
          ),
        );
        _sending = false;
      });
      unawaited(_persistHistory());
    } on AIServiceException catch (exception) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = translateAIServiceException(context, exception);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = context.l10n.readerAiUnknownError;
      });
    }
    _scrollToBottomSoon();
  }

  Future<void> _persistHistory() async {
    if (_entries.isEmpty) return;
    final now = DateTime.now();
    _sessionId ??= now.microsecondsSinceEpoch.toString();
    _sessionCreatedAt ??= _entries.first.at;
    await _historyStore.upsertSession(
      AiChatHistorySession(
        id: _sessionId!,
        bookTitle: _selectedBook?.title ?? '',
        bookId: _selectedBook?.id?.toString(),
        createdAt: _sessionCreatedAt!,
        updatedAt: now,
        messages: [
          for (final entry in _entries)
            AiChatHistoryMessage(
              role: entry.role,
              text: entry.text,
              at: entry.at,
            ),
        ],
      ),
    );
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final useRailNavigation =
        NavigationContext.of(context)?.useRailNavigation ?? false;
    final mobileChrome = HomeMobileChromeScope.of(context);
    final topPadding = useRailNavigation ? 16.0 : mobileChrome.pageTopPadding;
    // 键盘弹出时悬浮导航栏滑出隐藏，输入条收起为导航栏预留的底部留白，
    // 直接贴近键盘。键盘可见性来自壳层 Scaffold 外侧的原始 viewInsets。
    final bottomPadding = useRailNavigation
        ? 20.0
        : mobileChrome.keyboardVisible
        ? 10.0
        : mobileChrome.pageBottomPadding;
    // 键盘弹出的瞬间把对话滚到底，避免最后几条消息被压缩后的视口截断。
    if (mobileChrome.keyboardVisible != _lastKeyboardVisible) {
      _lastKeyboardVisible = mobileChrome.keyboardVisible;
      if (mobileChrome.keyboardVisible) _scrollToBottomSoon();
    }
    // 列表顶部留白：手机端内容需越过顶栏（顶栏高度并入滚动区内边距）。
    final bannerVisible = _configChecked && !_configured;
    final listTopPadding = useRailNavigation || bannerVisible
        ? 10.0
        : topPadding + 10.0;

    return Container(
      decoration: BoxDecoration(
        gradient: PageStyleHelper.backgroundGradient(context),
      ),
      child: SafeArea(
        top: useRailNavigation,
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              children: [
                // 手机端标题与工具在壳层顶栏（工具在右）；宽屏保留页内大标题行。
                if (useRailNavigation)
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, topPadding, 12, 0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l10n.navAi,
                            style: const TextStyle(
                              fontSize: 36,
                              height: 1.05,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          key: const ValueKey('ai-page-history'),
                          tooltip: l10n.aiHistoryTitle,
                          onPressed: _sending
                              ? null
                              : () => unawaited(_openHistory()),
                          icon: const Icon(Icons.history_rounded),
                        ),
                        IconButton(
                          key: const ValueKey('ai-page-new-chat'),
                          tooltip: l10n.aiChatNewChat,
                          onPressed: _sending ? null : _startNewChat,
                          icon: const Icon(Icons.add_comment_outlined),
                        ),
                      ],
                    ),
                  ),
                // 手机端不加实体占位：内容从半透明顶栏下方穿过（与其他页一致），
                // 顶部留白放进滚动区内部，避免顶栏区域出现双色图层。
                if (_configChecked && !_configured)
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      useRailNavigation ? 8 : topPadding + 8,
                      16,
                      0,
                    ),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.errorContainer.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Text(
                        l10n.readerAiNotConfiguredHint,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                  ),
                // 输入条真悬浮：只有胶囊本体有背景，四周完全透出消息；
                // 列表底部预留胶囊高度，滚到底时最后一条消息停在胶囊上方。
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _entries.isEmpty && !_sending
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_outlined,
                                        size: 44,
                                        color: scheme.onSurfaceVariant
                                            .withValues(alpha: 0.5),
                                      ),
                                      const SizedBox(height: 14),
                                      Text(
                                        l10n.readerAiEmptyHint,
                                        textAlign: TextAlign.center,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyMedium
                                            ?.copyWith(
                                              color: scheme.onSurfaceVariant,
                                              height: 1.5,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView(
                                controller: _scrollController,
                                padding: EdgeInsets.fromLTRB(
                                  16,
                                  listTopPadding,
                                  16,
                                  _overlayReserve(bottomPadding),
                                ),
                                children: [
                                  for (final entry in _entries)
                                    _AiChatBubble(entry: entry),
                                  if (_sending)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Row(
                                        children: [
                                          const SizedBox(
                                            width: 15,
                                            height: 15,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            l10n.readerAiThinking,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodySmall
                                                ?.copyWith(
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      // 悬浮层：错误条/书籍胶囊/输入条，周边区域不拦截点击。
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  0,
                                  16,
                                  8,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: scheme.errorContainer.withValues(
                                      alpha: 0.92,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Text(
                                    _error!,
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: scheme.onErrorContainer,
                                        ),
                                  ),
                                ),
                              ),
                            // 已关联书籍时在输入条上方展示可移除的胶囊。
                            if (_selectedBook != null)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  0,
                                  20,
                                  6,
                                ),
                                child: Row(
                                  children: [
                                    Flexible(
                                      child: InputChip(
                                        key: const ValueKey(
                                          'ai-page-linked-book',
                                        ),
                                        avatar: Icon(
                                          Icons.menu_book,
                                          size: 16,
                                          color: scheme.primary,
                                        ),
                                        label: Text(
                                          _selectedBook!.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onDeleted: _sending
                                            ? null
                                            : () => setState(() {
                                                _selectedBook = null;
                                                _bookContext = '';
                                              }),
                                      ),
                                    ),
                                    if (_bookContextLoading)
                                      const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: SizedBox(
                                          width: 14,
                                          height: 14,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            // 悬浮输入条：与悬浮导航栏同风格的玻璃胶囊。
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                16,
                                0,
                                16,
                                bottomPadding,
                              ),
                              child: _buildFloatingInputBar(context),
                            ),
                          ],
                        ),
                      ),
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

  /// 悬浮层为列表预留的底部空间：输入条（约 54）+ 间距 + 悬浮边距，
  /// 以及可见时的书籍胶囊与错误条高度估算。
  double _overlayReserve(double bottomPadding) {
    var reserve = 62.0 + bottomPadding;
    if (_selectedBook != null) reserve += 44;
    if (_error != null) reserve += 58;
    return reserve;
  }

  /// 悬浮输入条：玻璃胶囊（与悬浮导航栏同参数），加号、输入框与
  /// 发送键垂直居中在同一水平线上。
  Widget _buildFloatingInputBar(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final isMaterial3Style =
        Theme.of(
          context,
        ).extension<UiStyleThemeExtension>()?.isMaterial3Style ??
        false;
    final blurEnabled =
        !isMaterial3Style && !GlassEffectConfig.shouldDisableBlur;
    final bar = Container(
      decoration: BoxDecoration(
        color: isMaterial3Style
            ? scheme.surfaceContainerHigh
            : GlassEffectConfig.chromeSurfaceColor(context),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: scheme.outline.withValues(
            alpha: isMaterial3Style ? 0.18 : 0.12,
          ),
          width: 0.6,
        ),
      ),
      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
      // 全部元素垂直居中：加号、输入文字与发送键保持同一水平线；
      // 多行输入时整条同步增高，仍居中。
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          IconButton(
            key: const ValueKey('ai-page-plus'),
            tooltip: l10n.aiChatSelectBook,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            onPressed: _sending ? null : () => unawaited(_showPlusMenu()),
            icon: const Icon(Icons.add_circle_outline, size: 22),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              key: const ValueKey('ai-page-input'),
              controller: _inputController,
              enabled: _configured,
              minLines: 1,
              maxLines: 4,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_handleSend()),
              style: const TextStyle(fontSize: 15, height: 1.4),
              decoration: InputDecoration(
                hintText: l10n.readerAiInputHint,
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 10,
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton.filled(
            key: const ValueKey('ai-page-send'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            onPressed: _configured && !_sending
                ? () => unawaited(_handleSend())
                : null,
            tooltip: l10n.readerAiSendButton,
            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
          ),
        ],
      ),
    );

    // 与悬浮导航栏同参数的玻璃模糊；阴影放在裁剪层外侧避免被裁掉。
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.16),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: blurEnabled
            ? BackdropFilter(
                filter: ui.ImageFilter.blur(
                  sigmaX: GlassEffectConfig.navigationBarBlur,
                  sigmaY: GlassEffectConfig.navigationBarBlur,
                ),
                child: bar,
              )
            : bar,
      ),
    );
  }
}

class _AiChatBubble extends StatelessWidget {
  const _AiChatBubble({required this.entry});

  final _AiChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isUser = entry.role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.fromLTRB(13, 10, 13, isUser ? 10 : 0),
        constraints: const BoxConstraints(maxWidth: 560),
        decoration: BoxDecoration(
          color: isUser
              ? scheme.primary.withValues(alpha: 0.12)
              : scheme.surfaceContainerLow,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(
            color: isUser
                ? scheme.primary.withValues(alpha: 0.32)
                : scheme.outlineVariant,
          ),
        ),
        child: isUser
            ? SelectableText(
                entry.text,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(height: 1.55),
              )
            : ReleaseNotesMarkdown(data: entry.text),
      ),
    );
  }
}
