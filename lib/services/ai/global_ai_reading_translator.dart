// 文件说明：全局 AI 阅读服务响应缓冲区翻译器。
// 技术要点：i18n、AppLocalizations、正则替换。
//
// [GlobalAIReadingService] 会向 StringBuffer 写入占位令牌
// （如 `[[readerAiMemorySummaryHeading]]`），UI 层在显示前调用
// [localizeAiResponseBuffer] 将所有令牌替换为实际翻译文案。
//
// 对于带参数的令牌 `readerAiSnippetLocation`，服务写入的格式为
// `[[snippetLocation:{chapterId}:{startOffset}:{endOffset}]]`，
// 翻译器通过正则提取三个参数后调用 l10n 方法。

import 'package:flutter/widgets.dart';

import '../../utils/localization_extension.dart';

/// Replace all placeholder tokens in [bufferText] with actual
/// translations from the current locale.
///
/// Supported tokens:
/// - `[[readerAiMemorySummaryHeading]]`
/// - `[[readerAiReadingAdviceHeading]]`
/// - `[[readerAiIndexedSnippetsHeading]]`
/// - `[[readerAiLocalFallbackIntro]]`
/// - `[[readerAiRelatedContentHeading]]`
/// - `[[readerAiNoRelatedContent]]`
/// - `[[readerAiRelatedContentLocationHeading]]`
/// - `[[readerAiReadingSuggestionHeading]]`
/// - `[[readerAiNextStepHeading]]`
/// - `[[readerAiNextStepReadSnippet]]`
/// - `[[readerAiNextStepAskFollowUp]]`
/// - `[[snippetLocation:{chapterId}:{startOffset}:{endOffset}]]`
String localizeAiResponseBuffer(BuildContext context, String bufferText) {
  final l10n = context.l10n;
  // Replace snippet location tokens first (they have inline parameters).
  final snippetRegex = RegExp(
    r'\[\[snippetLocation:([^:]*):(\d+):(\d+)\]\]',
  );
  var result = bufferText.replaceAllMapped(snippetRegex, (match) {
    return l10n.readerAiSnippetLocation(
      match.group(1)!,
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  });

  // Replace simple heading tokens.
  result = result
      .replaceAll(
        '[[readerAiMemorySummaryHeading]]',
        l10n.readerAiMemorySummaryHeading,
      )
      .replaceAll(
        '[[readerAiReadingAdviceHeading]]',
        l10n.readerAiReadingAdviceHeading,
      )
      .replaceAll(
        '[[readerAiIndexedSnippetsHeading]]',
        l10n.readerAiIndexedSnippetsHeading,
      )
      .replaceAll(
        '[[readerAiLocalFallbackIntro]]',
        l10n.readerAiLocalFallbackIntro,
      )
      .replaceAll(
        '[[readerAiRelatedContentHeading]]',
        l10n.readerAiRelatedContentHeading,
      )
      .replaceAll(
        '[[readerAiNoRelatedContent]]',
        l10n.readerAiNoRelatedContent,
      )
      .replaceAll(
        '[[readerAiRelatedContentLocationHeading]]',
        l10n.readerAiRelatedContentLocationHeading,
      )
      .replaceAll(
        '[[readerAiReadingSuggestionHeading]]',
        l10n.readerAiReadingSuggestionHeading,
      )
      .replaceAll(
        '[[readerAiNextStepHeading]]',
        l10n.readerAiNextStepHeading,
      )
      .replaceAll(
        '[[readerAiNextStepReadSnippet]]',
        l10n.readerAiNextStepReadSnippet,
      )
      .replaceAll(
        '[[readerAiNextStepAskFollowUp]]',
        l10n.readerAiNextStepAskFollowUp,
      );

  return result;
}
