// 文件说明：AI 服务错误码翻译器，将 service 层返回的码解析为用户可见文案。
// 技术要点：i18n、AppLocalizations、AIServiceException、mock 响应令牌。

import 'dart:convert';

import 'package:flutter/widgets.dart';

import '../../utils/localization_extension.dart';
import 'ai_service.dart';

/// Translate an AI validation error code to user-visible text.
///
/// Codes returned by [validateAIProviderSettings]:
/// - `api_key_required`, `model_required`, `base_url_invalid`
/// - `temp_error_minimax`, `temp_error_out_of_range`
/// - `model_mismatch_claude`, `model_mismatch_gemini`,
///   `model_mismatch_glm`, `model_mismatch_minimax`
String translateAiValidationError(BuildContext context, String code) {
  final l10n = context.l10n;
  switch (code) {
    case 'api_key_required':
      return l10n.settingsAiApiKeyRequired;
    case 'model_required':
      return l10n.settingsAiModelRequired;
    case 'base_url_invalid':
      return l10n.settingsAiBaseUrlInvalid;
    case 'temp_error_minimax':
      return l10n.settingsAiTempErrorMinimax;
    case 'temp_error_out_of_range':
      return l10n.settingsAiTempErrorOutOfRange;
    case 'model_mismatch_claude':
      return l10n.settingsAiModelMismatchClaude;
    case 'model_mismatch_gemini':
      return l10n.settingsAiModelMismatchGemini;
    case 'model_mismatch_glm':
      return l10n.settingsAiModelMismatchGlm;
    case 'model_mismatch_minimax':
      return l10n.settingsAiModelMismatchMinimax;
    default:
      return code;
  }
}

/// Format a raw HTTP status code string for the `{status}` placeholder
/// that expects either an empty string or `'(code)'`.
String _formatStatusParen(String? status) {
  if (status == null || status.isEmpty) return '';
  return '($status)';
}

/// Translate an [AIServiceException] to user-visible text.
///
/// The exception carries a `code` plus optional structured fields
/// (`status`, `text`, `endpoint`, `error`, `provider`, `snippet`)
/// that the UI layer uses to fill ARB placeholders.
String translateAIServiceException(
  BuildContext context,
  AIServiceException exception,
) {
  final l10n = context.l10n;
  switch (exception.code) {
    // Validation codes (reuse settings ARB keys).
    case 'api_key_required':
      return l10n.settingsAiApiKeyRequired;
    case 'model_required':
      return l10n.settingsAiModelRequired;
    case 'base_url_invalid':
      return l10n.settingsAiBaseUrlInvalid;
    case 'temp_error_minimax':
      return l10n.settingsAiTempErrorMinimax;
    case 'temp_error_out_of_range':
      return l10n.settingsAiTempErrorOutOfRange;
    case 'model_mismatch_claude':
      return l10n.settingsAiModelMismatchClaude;
    case 'model_mismatch_gemini':
      return l10n.settingsAiModelMismatchGemini;
    case 'model_mismatch_glm':
      return l10n.settingsAiModelMismatchGlm;
    case 'model_mismatch_minimax':
      return l10n.settingsAiModelMismatchMinimax;

    // fetchAvailableModels error codes.
    case 'model_list_format_unrecognized':
      return l10n.settingsAiModelListFormatUnrecognized;
    case 'no_models_returned':
      return l10n.settingsAiNoModelsReturned;
    case 'no_models_available':
      return l10n.settingsAiNoModelsAvailable;
    case 'fetch_models_failed':
      return l10n.settingsAiFetchModelsFailed(exception.error ?? '');

    // chat error codes.
    case 'enter_question_first':
      return l10n.readerAiEnterQuestionFirst;
    case 'empty_response':
      return l10n.readerAiEmptyResponse;
    case 'request_failed':
      return l10n.readerAiRequestFailed(exception.error ?? '');

    // HTTP / response decoding error codes.
    case 'empty_response_error':
      return l10n.readerAiEmptyResponseError(exception.endpoint ?? '');
    case 'invalid_json_error':
      return l10n.readerAiInvalidJsonError(
        exception.provider ?? '',
        exception.endpoint ?? '',
        exception.snippet ?? '',
      );
    case 'failed_read_body':
      return l10n.readerAiFailedReadBody(
        _formatStatusParen(exception.status),
        exception.endpoint ?? '',
      );
    case 'network_request_failed':
      return l10n.readerAiNetworkRequestFailed(
        _formatStatusParen(exception.status),
        exception.error ?? '',
        exception.endpoint ?? '',
      );
    case 'request_failed_minimax_hint':
      return l10n.readerAiRequestFailedMinimaxHint(
        exception.status ?? '',
        exception.text ?? '',
        exception.endpoint ?? '',
      );
    case 'request_failed_claude_hint':
      return l10n.readerAiRequestFailedClaudeHint(
        exception.status ?? '',
        exception.text ?? '',
        exception.endpoint ?? '',
      );
    case 'request_failed_provider_mismatch_hint':
      return l10n.readerAiRequestFailedProviderMismatchHint(
        exception.status ?? '',
        exception.text ?? '',
        exception.endpoint ?? '',
      );
    case 'request_failed_generic':
      return l10n.readerAiRequestFailedGeneric(
        exception.status ?? '',
        exception.text ?? '',
        exception.endpoint ?? '',
      );
    default:
      return l10n.readerAiUnknownError;
  }
}

/// Regular expression that matches mock-response tokens embedded by
/// [MockAIService].
///
/// Token format: `[[mock:CODE|JSON_PARAMS]]`
/// where JSON_PARAMS is a JSON object string (may be empty for codes
/// without parameters, e.g. `[[mock:greeting|{}]]`).
final RegExp _mockTokenRegex = RegExp(
  r'\[\[mock:([a-z_]+)\|(\{.*?\})\]\]',
  dotAll: true,
);

/// Translate a mock AI response token to user-visible text.
///
/// [text] is the raw string returned by [MockAIService] methods (e.g.
/// `askSelection`, `analyzePage`, `chat`). If the string is a mock
/// token, it is replaced with the localized text; otherwise it is
/// returned unchanged (so real AI responses pass through verbatim).
String translateMockAiResponse(BuildContext context, String text) {
  final l10n = context.l10n;
  return text.replaceAllMapped(_mockTokenRegex, (match) {
    final code = match.group(1)!;
    final jsonStr = match.group(2)!;
    Map<String, dynamic> params;
    try {
      params = jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (_) {
      params = const <String, dynamic>{};
    }
    switch (code) {
      case 'mock_greeting':
        return l10n.readerAiMockGreeting;
      case 'mock_selection_response':
        return l10n.readerAiMockSelectionResponse(
          params['selectedText'] as String? ?? '',
          params['before'] as String? ?? '',
          params['after'] as String? ?? '',
        );
      case 'mock_page_analysis':
        return l10n.readerAiMockPageAnalysis(params['chars'] as int? ?? 0);
      case 'mock_chat_response':
        return l10n.readerAiMockChatResponse(
          params['question'] as String? ?? '',
          params['chars'] as int? ?? 0,
        );
      default:
        return match.group(0)!;
    }
  });
}
