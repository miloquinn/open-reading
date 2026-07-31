// 文件说明：阅读器"问AI"底部面板，承载与 AI 阅读助手的对话与追问。
// 技术要点：showModalBottomSheet、ReaderHttpAIService.chat、ai_error_translator、l10n。

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/reader/reader_annotation.dart';
import '../reader_core/ai/ai_error_translator.dart';
import '../reader_core/ai/ai_service.dart';
import '../services/ai/ai_chat_history_store.dart';
import '../services/ai/ai_request_coordinator.dart';
import '../utils/glass_config.dart';
import '../utils/localization_extension.dart';
import '../utils/reader_themes.dart';
import 'release_notes_markdown.dart';
import 'side_toast.dart';

/// Selection context that seeds the conversation when the panel is opened
/// from the text-selection toolbar.
class ReaderAiSelectionContext {
  const ReaderAiSelectionContext({
    required this.selectedText,
    required this.contextBefore,
    required this.contextAfter,
  });

  final String selectedText;
  final String contextBefore;
  final String contextAfter;
}

/// Page context handed to the AI service is capped well above the service's
/// own 2800-char compaction so the window stays centered on the selection.
String readerAiPageContextFromSelection(ReaderSelectionSnapshot selection) {
  const window = 1400;
  final source = selection.sourceText;
  final start = (selection.startOffset - window).clamp(0, source.length);
  final end = (selection.endOffset + window).clamp(start, source.length);
  return source.substring(start, end);
}

Future<void> showReaderAiPanelSheet({
  required BuildContext context,
  required ReaderThemePalette palette,
  required ThemeData themeData,
  required AIRequestMeta meta,
  required String pageText,
  String bookTitle = '',
  ReaderAiSelectionContext? selection,
  ConfigurableAIService? aiService,
}) => showModalBottomSheet<void>(
  context: context,
  useSafeArea: true,
  isScrollControlled: true,
  enableDrag: true,
  showDragHandle: true,
  backgroundColor: palette.controlBar,
  constraints: const BoxConstraints(maxWidth: 720),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (sheetContext) {
    final media = MediaQuery.of(sheetContext);
    final height = math.min(
      media.size.height * 0.72,
      math.max(280.0, media.size.height - media.viewInsets.bottom - 96),
    );
    return Theme(
      data: themeData,
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: height,
          child: ReaderAiPanel(
            palette: palette,
            meta: meta,
            pageText: pageText,
            bookTitle: bookTitle,
            selection: selection,
            aiService: aiService ?? ReaderHttpAIService(),
          ),
        ),
      ),
    );
  },
);

class ReaderAiPanel extends StatefulWidget {
  const ReaderAiPanel({
    super.key,
    required this.palette,
    required this.meta,
    required this.pageText,
    required this.aiService,
    this.bookTitle = '',
    this.selection,
  });

  final ReaderThemePalette palette;
  final AIRequestMeta meta;
  final String pageText;
  final String bookTitle;
  final ConfigurableAIService aiService;
  final ReaderAiSelectionContext? selection;

  @override
  State<ReaderAiPanel> createState() => _ReaderAiPanelState();
}

class _ReaderAiChatEntry {
  _ReaderAiChatEntry({
    required this.role,
    required this.display,
    required this.content,
  }) : at = DateTime.now();

  /// `user` or `assistant`; mirrors [AIChatMessage.role].
  final String role;

  /// Text shown in the bubble (mock tokens already resolved).
  final String display;

  /// Raw text sent back to the service as conversation history.
  final String content;

  final DateTime at;
}

class _ReaderAiPanelState extends State<ReaderAiPanel> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ReaderAiChatEntry> _entries = [];

  final AiChatHistoryStore _historyStore = AiChatHistoryStore();
  bool _configured = false;
  bool _configChecked = false;
  bool _sending = false;
  bool _selectionSent = false;
  String? _error;
  String? _sessionId;
  DateTime? _sessionCreatedAt;

  @override
  void initState() {
    super.initState();
    unawaited(_initialize());
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initialize() async {
    var configured = false;
    try {
      final settings = await widget.aiService.loadSettings();
      configured = settings.isConfigured;
    } catch (_) {
      configured = false;
    }
    if (!mounted) return;
    setState(() {
      _configured = configured;
      _configChecked = true;
    });
    final selection = widget.selection;
    if (configured && selection != null && !_selectionSent) {
      _selectionSent = true;
      await _sendSelectionQuestion(selection);
    }
  }

  Future<void> _sendSelectionQuestion(
    ReaderAiSelectionContext selection,
  ) async {
    final l10n = context.l10n;
    final selected = selection.selectedText.trim();
    final quote = selected.replaceAll(RegExp(r'\s+'), ' ');
    final shortQuote = quote.length > 160
        ? '${quote.substring(0, 160)}…'
        : quote;
    await _sendMessage(
      display: '${l10n.readerAiSelectionQuestionLabel}\n"$shortQuote"',
      content: l10n.readerAiSelectionPrompt(
        selected,
        selection.contextBefore.trim(),
        selection.contextAfter.trim(),
      ),
    );
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _sending || !_configured) return;
    _inputController.clear();
    await _sendMessage(display: text, content: text);
  }

  Future<void> _sendMessage({
    required String display,
    required String content,
  }) async {
    setState(() {
      _entries.add(
        _ReaderAiChatEntry(role: 'user', display: display, content: content),
      );
      _sending = true;
      _error = null;
    });
    _scrollToBottomSoon();
    try {
      final history = _entries
          .map(
            (entry) => AIChatMessage(role: entry.role, content: entry.content),
          )
          .toList(growable: false);
      // 交互式请求登记到协调器：后台预处理会让行，对话不排队。
      final answer = await AiRequestCoordinator().runInteractive(
        () => widget.aiService.chat(
          history: history,
          pageText: widget.pageText,
          meta: widget.meta,
        ),
      );
      if (!mounted) return;
      setState(() {
        _entries.add(
          _ReaderAiChatEntry(
            role: 'assistant',
            display: translateMockAiResponse(context, answer),
            content: answer,
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

  /// 每轮完整问答后整体覆盖保存当前会话，供 AI 页面回看与删除。
  Future<void> _persistHistory() async {
    if (_entries.isEmpty) return;
    final now = DateTime.now();
    _sessionId ??= now.microsecondsSinceEpoch.toString();
    _sessionCreatedAt ??= _entries.first.at;
    await _historyStore.upsertSession(
      AiChatHistorySession(
        id: _sessionId!,
        bookTitle: widget.bookTitle,
        createdAt: _sessionCreatedAt!,
        updatedAt: now,
        messages: [
          for (final entry in _entries)
            AiChatHistoryMessage(
              role: entry.role,
              text: entry.display,
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

  /// 键盘收起时为系统手势区高度，弹出时键盘已顶起面板、无需再让位。
  double get _gestureInset {
    final media = MediaQuery.of(context);
    return media.viewInsets.bottom > 0 ? 0.0 : media.viewPadding.bottom;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final palette = widget.palette;
    // 不用 SafeArea 包内容：对话一直铺到面板底边（手势区照常显示消息），
    // 只有悬浮胶囊自己抬高避开手势提示线。
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.auto_awesome_outlined, color: palette.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  l10n.settingsAiAssistantTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_configChecked && !_configured)
            _ReaderAiNotice(
              palette: palette,
              icon: Icons.key_off_outlined,
              text: l10n.readerAiNotConfiguredHint,
            ),
          // 输入胶囊悬浮在对话上方：只有胶囊本体有背景，
          // 四周透出消息内容；列表底部预留胶囊高度。
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(child: _buildConversation(context)),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 12 + _gestureInset,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null) ...[
                        // 悬浮态下垫一层实色，避免下方文字透进半透明错误条。
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: palette.surface,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: _ReaderAiNotice(
                            palette: palette,
                            icon: Icons.error_outline_rounded,
                            text: _error!,
                            isError: true,
                          ),
                        ),
                        const SizedBox(height: 6),
                      ],
                      _buildInputRow(context),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversation(BuildContext context) {
    final l10n = context.l10n;
    final palette = widget.palette;
    if (_entries.isEmpty && !_sending) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            l10n.readerAiEmptyHint,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: palette.secondaryText,
              height: 1.5,
            ),
          ),
        ),
      );
    }
    return ListView(
      controller: _scrollController,
      // 底部预留悬浮胶囊（约 52px + 抬高量）与错误条的高度。
      padding: EdgeInsets.fromLTRB(
        0,
        6,
        0,
        72 + _gestureInset + (_error != null ? 64 : 0),
      ),
      children: [
        for (final entry in _entries)
          _ReaderAiBubble(palette: palette, entry: entry),
        if (_sending)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: palette.accent,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.readerAiThinking,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: palette.secondaryText),
                ),
              ],
            ),
          ),
      ],
    );
  }

  /// 悬浮胶囊输入条：与 AI 页同款——圆角胶囊、无边框输入、
  /// 输入文字与发送键垂直居中在同一水平线。
  Widget _buildInputRow(BuildContext context) {
    final l10n = context.l10n;
    final palette = widget.palette;
    final canSend = _configured && !_sending;
    final blurEnabled = !GlassEffectConfig.shouldDisableBlur;
    final bar = Container(
      decoration: BoxDecoration(
        color: palette.surface.withValues(alpha: blurEnabled ? 0.72 : 1.0),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: palette.border, width: 0.8),
      ),
      padding: const EdgeInsets.fromLTRB(16, 5, 5, 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              key: const ValueKey('reader-ai-input'),
              controller: _inputController,
              enabled: _configured,
              minLines: 1,
              maxLines: 4,
              textAlignVertical: TextAlignVertical.center,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => unawaited(_handleSend()),
              style: TextStyle(color: palette.text, fontSize: 14, height: 1.4),
              cursorColor: palette.accent,
              decoration: InputDecoration(
                hintText: l10n.readerAiInputHint,
                hintStyle: TextStyle(
                  color: palette.secondaryText.withValues(alpha: 0.8),
                ),
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            key: const ValueKey('reader-ai-send'),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            onPressed: canSend ? () => unawaited(_handleSend()) : null,
            tooltip: l10n.readerAiSendButton,
            icon: const Icon(Icons.arrow_upward_rounded, size: 20),
            style: IconButton.styleFrom(
              backgroundColor: palette.accent,
              foregroundColor: palette.onAccent,
              disabledBackgroundColor: palette.accent.withValues(alpha: 0.32),
              disabledForegroundColor: palette.onAccent.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(
              alpha: palette.brightness == Brightness.dark ? 0.4 : 0.18,
            ),
            blurRadius: 18,
            offset: const Offset(0, 6),
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

class _ReaderAiBubble extends StatelessWidget {
  const _ReaderAiBubble({required this.palette, required this.entry});

  final ReaderThemePalette palette;
  final _ReaderAiChatEntry entry;

  Future<void> _openLink(BuildContext context, Uri uri) async {
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && context.mounted) {
      showSideToast(
        context,
        context.l10n.updateOpenFailed,
        kind: SideToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = entry.role == 'user';
    final background = isUser
        ? palette.accent.withValues(alpha: 0.15)
        : palette.surface.withValues(alpha: 0.85);
    final borderColor = isUser
        ? palette.accent.withValues(alpha: 0.4)
        : palette.border;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: EdgeInsets.fromLTRB(13, 10, 13, isUser ? 10 : 0),
        constraints: const BoxConstraints(maxWidth: 520),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          border: Border.all(color: borderColor, width: 0.8),
        ),
        // 用户消息保持原样纯文本；AI 回答按 Markdown 渲染（复用更新日志的
        // 零依赖渲染器，末块自带 10-12px 底距，故 AI 气泡底 padding 归零）。
        child: isUser
            ? SelectableText(
                entry.display,
                style: TextStyle(
                  color: palette.text,
                  fontSize: 14,
                  height: 1.55,
                ),
              )
            : ReleaseNotesMarkdown(
                data: entry.display,
                onTapLink: (uri) => _openLink(context, uri),
              ),
      ),
    );
  }
}

class _ReaderAiNotice extends StatelessWidget {
  const _ReaderAiNotice({
    required this.palette,
    required this.icon,
    required this.text,
    this.isError = false,
  });

  final ReaderThemePalette palette;
  final IconData icon;
  final String text;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? Theme.of(context).colorScheme.error
        : palette.secondaryText;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.32)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: color, fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
