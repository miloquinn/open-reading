// 文件说明：AI 对话历史页，从 AI 页左上角进入；点选会话返回并继续对话。
// 技术要点：AiChatHistoryStore 监听、Dismissible 删除、Navigator 结果回传。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xxread/services/ai/ai_chat_history_store.dart';
import 'package:xxread/utils/localization_extension.dart';
import 'package:xxread/utils/page_style_helper.dart';

String _formatSessionTime(BuildContext context, DateTime time) {
  final locale = Localizations.localeOf(context).toString();
  return DateFormat.yMd(locale).add_Hm().format(time);
}

/// 历史会话列表：按最近更新排列，左滑删除，右上角清空；
/// 点击会话以 Navigator 结果返回，由 AI 页载入并继续对话。
class AiHistoryPage extends StatefulWidget {
  const AiHistoryPage({super.key});

  @override
  State<AiHistoryPage> createState() => _AiHistoryPageState();
}

class _AiHistoryPageState extends State<AiHistoryPage> {
  final AiChatHistoryStore _store = AiChatHistoryStore();

  @override
  void initState() {
    super.initState();
    unawaited(_store.ensureLoaded());
  }

  Future<void> _confirmClearAll() async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.aiHistoryClearAll),
        content: Text(l10n.aiHistoryClearAllConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) await _store.clearAll();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.aiHistoryTitle),
        actions: [
          IconButton(
            key: const ValueKey('ai-history-clear-all'),
            tooltip: l10n.aiHistoryClearAll,
            onPressed: () => unawaited(_confirmClearAll()),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: PageStyleHelper.backgroundGradient(context),
        ),
        child: ListenableBuilder(
          listenable: _store,
          builder: (context, _) {
            final sessions = _store.sessions;
            if (sessions.isEmpty) {
              return _buildEmptyState(context);
            }
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 860),
                child: ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
                  itemCount: sessions.length,
                  itemBuilder: (context, index) =>
                      _buildSessionTile(context, sessions[index]),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_outlined,
              size: 52,
              color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 18),
            Text(
              l10n.aiHistoryEmpty,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSessionTile(BuildContext context, AiChatHistorySession session) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final question = session.firstQuestion.replaceAll(RegExp(r'\s+'), ' ');
    final subtitleParts = [
      if (session.bookTitle.trim().isNotEmpty) session.bookTitle.trim(),
      _formatSessionTime(context, session.updatedAt),
      l10n.aiHistoryMessageCount(session.messages.length),
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Dismissible(
        key: ValueKey('ai-history-session-${session.id}'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => unawaited(_store.deleteSession(session.id)),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 22),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
        ),
        child: Material(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          child: InkWell(
            borderRadius: BorderRadius.circular(18),
            onTap: () => Navigator.of(context).pop(session),
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.auto_awesome_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          question.isEmpty ? l10n.aiHistoryTitle : question,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          subtitleParts.join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
