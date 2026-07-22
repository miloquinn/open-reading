// 文件说明：TTS 服务错误码翻译器，将 TtsService 返回的码解析为用户可见文案。
// 技术要点：i18n、AppLocalizations。

import 'package:flutter/widgets.dart';

import '../utils/localization_extension.dart';

/// Translate a TTS error code to user-visible text.
///
/// [errorCode] is the code stored in `TtsService.lastError`.
/// [language] is the optional language string stored in
/// `TtsService.lastErrorLanguage` (used by the
/// `tts_unsupported_language` code).
String translateTtsError(
  BuildContext context,
  String? errorCode, [
  String? language,
]) {
  if (errorCode == null) return '';
  final l10n = context.l10n;
  switch (errorCode) {
    case 'tts_unavailable':
      return l10n.ttsUnavailable;
    case 'tts_call_failed':
      return l10n.ttsCallFailed;
    case 'tts_unsupported_language':
      return l10n.ttsUnsupportedLanguage(language ?? '');
    default:
      return errorCode;
  }
}

/// Translate the TTS voice label, falling back to "System default"
/// when no voice title is available.
String ttsVoiceLabel(BuildContext context, String? voiceTitle) {
  return voiceTitle ?? context.l10n.ttsSystemDefault;
}
