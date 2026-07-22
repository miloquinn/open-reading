// 文件说明：阅读内核 AI 配置与请求模型，统一描述模型、提供商和请求参数。
// 技术要点：ReaderCore、Dio、SharedPreferences、Secure Storage、JSON。

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AIRequestMeta {
  final String bookId;
  final String chapterId;
  final int? pageIndex;

  const AIRequestMeta({
    required this.bookId,
    required this.chapterId,
    this.pageIndex,
  });
}

enum AIProviderType { minimax, glm, openai, claude, gemini }

extension AIProviderTypeX on AIProviderType {
  String get value {
    switch (this) {
      case AIProviderType.minimax:
        return 'minimax';
      case AIProviderType.glm:
        return 'glm';
      case AIProviderType.openai:
        return 'openai';
      case AIProviderType.claude:
        return 'claude';
      case AIProviderType.gemini:
        return 'gemini';
    }
  }

  String get displayName {
    switch (this) {
      case AIProviderType.minimax:
        return 'MiniMax';
      case AIProviderType.glm:
        return 'GLM';
      case AIProviderType.openai:
        return 'OpenAI';
      case AIProviderType.claude:
        return 'Claude';
      case AIProviderType.gemini:
        return 'Gemini';
    }
  }

  static AIProviderType fromValue(String? value) {
    switch (value) {
      case 'glm':
        return AIProviderType.glm;
      case 'openai':
        return AIProviderType.openai;
      case 'claude':
        return AIProviderType.claude;
      case 'gemini':
        return AIProviderType.gemini;
      default:
        return AIProviderType.minimax;
    }
  }
}

String normalizeAIBaseUrl(AIProviderType provider, String baseUrl) {
  final trimmed = baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
  if (trimmed.isEmpty) {
    return '';
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    return trimmed;
  }

  var path = uri.path.replaceAll(RegExp(r'/+$'), '');
  switch (provider) {
    case AIProviderType.minimax:
    case AIProviderType.glm:
    case AIProviderType.openai:
      path = path.replaceFirst(
        RegExp(r'/chat/completions$', caseSensitive: false),
        '',
      );
      break;
    case AIProviderType.claude:
      path = path.replaceFirst(
        RegExp(r'/v1/messages$', caseSensitive: false),
        '/v1',
      );
      path = path.replaceFirst(RegExp(r'/messages$', caseSensitive: false), '');
      break;
    case AIProviderType.gemini:
      path = path.replaceFirst(
        RegExp(r'/models/[^/]+:generateContent$', caseSensitive: false),
        '',
      );
      break;
  }

  return uri.replace(path: path).toString().replaceAll(RegExp(r'/+$'), '');
}

String? validateAIProviderSettings(
  AIProviderSettings settings, {
  bool requireApiKey = true,
}) {
  final normalized = settings.normalized();
  if (requireApiKey && normalized.apiKey.isEmpty) {
    return 'api_key_required';
  }
  if (normalized.model.isEmpty) {
    return 'model_required';
  }

  final uri = Uri.tryParse(normalized.baseUrl);
  if (normalized.baseUrl.isEmpty ||
      uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https'))) {
    return 'base_url_invalid';
  }

  if (!_isValidTemperature(normalized.provider, normalized.temperature)) {
    return normalized.provider == AIProviderType.minimax
        ? 'temp_error_minimax'
        : 'temp_error_out_of_range';
  }

  final model = normalized.model.toLowerCase();
  switch (normalized.provider) {
    case AIProviderType.claude:
      if (!model.startsWith('claude')) {
        return 'model_mismatch_claude';
      }
      break;
    case AIProviderType.gemini:
      if (!model.contains('gemini')) {
        return 'model_mismatch_gemini';
      }
      break;
    case AIProviderType.glm:
      if (!model.startsWith('glm')) {
        return 'model_mismatch_glm';
      }
      break;
    case AIProviderType.minimax:
      if (!model.contains('minimax')) {
        return 'model_mismatch_minimax';
      }
      break;
    case AIProviderType.openai:
      break;
  }

  return null;
}

bool _isValidTemperature(AIProviderType provider, double value) {
  if (!value.isFinite || value < 0 || value > 2) {
    return false;
  }
  if (provider == AIProviderType.minimax) {
    return value > 0 && value <= 1;
  }
  if ((provider == AIProviderType.claude ||
          provider == AIProviderType.gemini) &&
      value > 1) {
    return false;
  }
  return true;
}

class AIModelPreset {
  final String id;
  final String label;
  final String vendor;
  final AIProviderType provider;
  final String baseUrl;
  final String model;
  final double temperature;

  const AIModelPreset({
    required this.id,
    required this.label,
    required this.vendor,
    required this.provider,
    required this.baseUrl,
    required this.model,
    required this.temperature,
  });

  AIProviderSettings toSettings({String apiKey = ''}) {
    return AIProviderSettings(
      provider: provider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      temperature: temperature,
    ).normalized();
  }
}

class AIModelPresets {
  static const List<AIModelPreset> all = <AIModelPreset>[
    AIModelPreset(
      id: 'openai_gpt_4o_mini',
      label: 'GPT-4o mini',
      vendor: 'OpenAI',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o-mini',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'openai_gpt_4o',
      label: 'GPT-4o',
      vendor: 'OpenAI',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4o',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'openai_gpt_4_1_mini',
      label: 'GPT-4.1 mini',
      vendor: 'OpenAI',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4.1-mini',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'openai_gpt_4_1',
      label: 'GPT-4.1',
      vendor: 'OpenAI',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.openai.com/v1',
      model: 'gpt-4.1',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'glm_4_flash',
      label: 'GLM-4-Flash',
      vendor: '智谱 GLM',
      provider: AIProviderType.glm,
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-4-flash',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'glm_4_plus',
      label: 'GLM-4-Plus',
      vendor: '智谱 GLM',
      provider: AIProviderType.glm,
      baseUrl: 'https://open.bigmodel.cn/api/paas/v4',
      model: 'glm-4-plus',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'minimax_m2_5',
      label: 'MiniMax-M2.5',
      vendor: 'MiniMax',
      provider: AIProviderType.minimax,
      baseUrl: 'https://api.minimax.io/v1',
      model: 'MiniMax-M2.5',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'claude_sonnet',
      label: 'Claude Sonnet',
      vendor: 'Anthropic',
      provider: AIProviderType.claude,
      baseUrl: 'https://api.anthropic.com',
      model: 'claude-3-5-sonnet-latest',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'claude_haiku',
      label: 'Claude Haiku',
      vendor: 'Anthropic',
      provider: AIProviderType.claude,
      baseUrl: 'https://api.anthropic.com',
      model: 'claude-3-5-haiku-latest',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'gemini_2_flash',
      label: 'Gemini 2.0 Flash',
      vendor: 'Google',
      provider: AIProviderType.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      model: 'gemini-2.0-flash',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'gemini_2_5_pro',
      label: 'Gemini 2.5 Pro',
      vendor: 'Google',
      provider: AIProviderType.gemini,
      baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
      model: 'gemini-2.5-pro',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'deepseek_chat',
      label: 'DeepSeek Chat',
      vendor: 'DeepSeek(OpenAI兼容)',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.deepseek.com/v1',
      model: 'deepseek-chat',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'deepseek_reasoner',
      label: 'DeepSeek Reasoner',
      vendor: 'DeepSeek(OpenAI兼容)',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.deepseek.com/v1',
      model: 'deepseek-reasoner',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'qwen_plus',
      label: 'Qwen Plus',
      vendor: '阿里云百炼(OpenAI兼容)',
      provider: AIProviderType.openai,
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      model: 'qwen-plus',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'qwen_max',
      label: 'Qwen Max',
      vendor: '阿里云百炼(OpenAI兼容)',
      provider: AIProviderType.openai,
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      model: 'qwen-max',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'kimi_8k',
      label: 'Moonshot 8k',
      vendor: 'Moonshot(OpenAI兼容)',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.moonshot.cn/v1',
      model: 'moonshot-v1-8k',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'kimi_32k',
      label: 'Moonshot 32k',
      vendor: 'Moonshot(OpenAI兼容)',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.moonshot.cn/v1',
      model: 'moonshot-v1-32k',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'groq_llama_70b',
      label: 'Llama 3.3 70B',
      vendor: 'Groq(OpenAI兼容)',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.groq.com/openai/v1',
      model: 'llama-3.3-70b-versatile',
      temperature: 0.7,
    ),
    AIModelPreset(
      id: 'siliconflow_qwen_72b',
      label: 'Qwen2.5 72B',
      vendor: 'SiliconFlow(OpenAI兼容)',
      provider: AIProviderType.openai,
      baseUrl: 'https://api.siliconflow.cn/v1',
      model: 'Qwen/Qwen2.5-72B-Instruct',
      temperature: 0.7,
    ),
  ];

  static AIModelPreset defaultForProvider(AIProviderType provider) {
    return all.firstWhere(
      (p) => p.provider == provider,
      orElse: () => all.first,
    );
  }

  static AIModelPreset? match(AIProviderSettings settings) {
    final normalizedBase = settings.baseUrl.trim().replaceAll(
      RegExp(r'/+$'),
      '',
    );
    final normalizedModel = settings.model.trim();
    for (final preset in all) {
      final presetBase = preset.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
      if (preset.provider == settings.provider &&
          presetBase == normalizedBase &&
          preset.model == normalizedModel) {
        return preset;
      }
    }
    return null;
  }

  static List<AIModelPreset> byProvider(AIProviderType provider) {
    return all.where((preset) => preset.provider == provider).toList();
  }
}

class AIProviderSettings {
  final AIProviderType provider;
  final String apiKey;
  final String baseUrl;
  final String model;
  final double temperature;

  const AIProviderSettings({
    required this.provider,
    required this.apiKey,
    required this.baseUrl,
    required this.model,
    required this.temperature,
  });

  factory AIProviderSettings.defaults(AIProviderType provider) {
    return AIModelPresets.defaultForProvider(provider).toSettings();
  }

  AIProviderSettings copyWith({
    AIProviderType? provider,
    String? apiKey,
    String? baseUrl,
    String? model,
    double? temperature,
  }) {
    return AIProviderSettings(
      provider: provider ?? this.provider,
      apiKey: apiKey ?? this.apiKey,
      baseUrl: baseUrl ?? this.baseUrl,
      model: model ?? this.model,
      temperature: temperature ?? this.temperature,
    );
  }

  AIProviderSettings normalized() {
    final normalizedBaseUrl = normalizeAIBaseUrl(provider, baseUrl);
    final normalizedModel = model.trim();
    final normalizedTemperature = temperature.isFinite ? temperature : 0.7;
    return copyWith(
      apiKey: apiKey.trim(),
      baseUrl: normalizedBaseUrl.isEmpty
          ? _defaultBaseUrl(provider)
          : normalizedBaseUrl,
      model: normalizedModel.isEmpty
          ? _defaultModel(provider)
          : normalizedModel,
      temperature: normalizedTemperature.clamp(0.0, 2.0),
    );
  }

  bool get isConfigured => apiKey.trim().isNotEmpty;

  static String _defaultBaseUrl(AIProviderType provider) =>
      AIProviderSettings.defaults(provider).baseUrl;
  static String _defaultModel(AIProviderType provider) =>
      AIProviderSettings.defaults(provider).model;
}

class AIChatMessage {
  final String role;
  final String content;

  const AIChatMessage({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};
}

abstract class AIService {
  Future<String> askSelection({
    required String selectedText,
    required String contextBefore,
    required String contextAfter,
    required AIRequestMeta meta,
  });

  Future<String> analyzePage({
    required String pageText,
    required AIRequestMeta meta,
  });

  Future<String> chat({
    required List<AIChatMessage> history,
    required String pageText,
    required AIRequestMeta meta,
  });
}

abstract class ConfigurableAIService implements AIService {
  Future<AIProviderSettings> loadSettings([AIProviderType? provider]);
  Future<void> saveSettings(AIProviderSettings settings);
}

class AIServiceException implements Exception {
  final String code;
  final String? status;
  final String? text;
  final String? endpoint;
  final String? error;
  final String? provider;
  final String? snippet;

  const AIServiceException({
    required this.code,
    this.status,
    this.text,
    this.endpoint,
    this.error,
    this.provider,
    this.snippet,
  });

  @override
  String toString() => code;
}

class ReaderHttpAIService implements ConfigurableAIService {
  ReaderHttpAIService({Dio? dio}) : _dio = dio ?? Dio();

  static const _activeProviderKey = 'reader_ai_provider_v1';
  static const _minimaxApiKeyKey = 'reader_ai_minimax_api_key_v1';
  static const _glmApiKeyKey = 'reader_ai_glm_api_key_v1';
  static const _openaiApiKeyKey = 'reader_ai_openai_api_key_v1';
  static const _claudeApiKeyKey = 'reader_ai_claude_api_key_v1';
  static const _geminiApiKeyKey = 'reader_ai_gemini_api_key_v1';
  static const _minimaxBaseUrlKey = 'reader_ai_minimax_base_url_v1';
  static const _glmBaseUrlKey = 'reader_ai_glm_base_url_v1';
  static const _openaiBaseUrlKey = 'reader_ai_openai_base_url_v1';
  static const _claudeBaseUrlKey = 'reader_ai_claude_base_url_v1';
  static const _geminiBaseUrlKey = 'reader_ai_gemini_base_url_v1';
  static const _minimaxModelKey = 'reader_ai_minimax_model_v1';
  static const _glmModelKey = 'reader_ai_glm_model_v1';
  static const _openaiModelKey = 'reader_ai_openai_model_v1';
  static const _claudeModelKey = 'reader_ai_claude_model_v1';
  static const _geminiModelKey = 'reader_ai_gemini_model_v1';
  static const _minimaxTemperatureKey = 'reader_ai_minimax_temp_v1';
  static const _glmTemperatureKey = 'reader_ai_glm_temp_v1';
  static const _openaiTemperatureKey = 'reader_ai_openai_temp_v1';
  static const _claudeTemperatureKey = 'reader_ai_claude_temp_v1';
  static const _geminiTemperatureKey = 'reader_ai_gemini_temp_v1';

  final Dio _dio;
  AIProviderSettings? _cachedActive;

  static const _secureStorage = FlutterSecureStorage();

  /// 读取 API Key：优先安全存储；发现 SharedPreferences 中的历史明文
  /// key 时迁移到安全存储并删除明文副本。
  Future<String> _readApiKey(
    SharedPreferences prefs,
    AIProviderType provider,
  ) async {
    final storageKey = _apiKeyKey(provider);
    try {
      final secureValue = await _secureStorage.read(key: storageKey);
      if (secureValue != null) {
        // 清理可能残留的明文副本
        if (prefs.containsKey(storageKey)) {
          await prefs.remove(storageKey);
        }
        return secureValue;
      }
      final legacyValue = prefs.getString(storageKey);
      if (legacyValue != null) {
        await _secureStorage.write(key: storageKey, value: legacyValue);
        await prefs.remove(storageKey);
        return legacyValue;
      }
      return '';
    } on Exception {
      // 安全存储不可用（如 Linux 无 keyring）时回退明文存储，
      // 保证功能可用优先于存储强度。
      return prefs.getString(storageKey) ?? '';
    }
  }

  Future<void> _writeApiKey(
    SharedPreferences prefs,
    AIProviderType provider,
    String apiKey,
  ) async {
    final storageKey = _apiKeyKey(provider);
    try {
      await _secureStorage.write(key: storageKey, value: apiKey);
      if (prefs.containsKey(storageKey)) {
        await prefs.remove(storageKey);
      }
    } on Exception {
      await prefs.setString(storageKey, apiKey);
    }
  }

  @override
  Future<AIProviderSettings> loadSettings([AIProviderType? provider]) async {
    final prefs = await SharedPreferences.getInstance();
    final activeProvider =
        provider ??
        AIProviderTypeX.fromValue(prefs.getString(_activeProviderKey));
    final defaults = AIProviderSettings.defaults(activeProvider);

    final apiKey = await _readApiKey(prefs, activeProvider);
    final baseUrl =
        prefs.getString(_baseUrlKey(activeProvider)) ?? defaults.baseUrl;
    final model = prefs.getString(_modelKey(activeProvider)) ?? defaults.model;
    final temperature =
        prefs.getDouble(_temperatureKey(activeProvider)) ??
        defaults.temperature;

    final settings = AIProviderSettings(
      provider: activeProvider,
      apiKey: apiKey,
      baseUrl: baseUrl,
      model: model,
      temperature: temperature,
    ).normalized();

    if (provider == null || provider == settings.provider) {
      _cachedActive = settings;
    }
    return settings;
  }

  @override
  Future<void> saveSettings(AIProviderSettings settings) async {
    final normalized = settings.normalized();
    final validationError = validateAIProviderSettings(normalized);
    if (validationError != null) {
      throw AIServiceException(code: validationError);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProviderKey, normalized.provider.value);
    await _writeApiKey(prefs, normalized.provider, normalized.apiKey);
    await prefs.setString(_baseUrlKey(normalized.provider), normalized.baseUrl);
    await prefs.setString(_modelKey(normalized.provider), normalized.model);
    await prefs.setDouble(
      _temperatureKey(normalized.provider),
      normalized.temperature,
    );
    _cachedActive = normalized;
  }

  Future<List<String>> fetchAvailableModels(AIProviderSettings settings) async {
    final normalized = settings.normalized();
    if (normalized.apiKey.isEmpty) {
      throw const AIServiceException(code: 'api_key_required');
    }

    final base = normalized.baseUrl.replaceAll(RegExp(r'/+$'), '');
    final endpoint = switch (normalized.provider) {
      AIProviderType.claude =>
        base.endsWith('/v1') ? '$base/models' : '$base/v1/models',
      _ => '$base/models',
    };
    final options = _buildRequestOptions(normalized).copyWith(
      responseType: ResponseType.json,
      receiveTimeout: const Duration(seconds: 30),
    );

    try {
      final response = await _dio.get<dynamic>(endpoint, options: options);
      dynamic body = response.data;
      if (body is String) {
        body = jsonDecode(body);
      }
      if (body is! Map) {
        throw const AIServiceException(code: 'model_list_format_unrecognized');
      }

      final rawModels = body['data'] ?? body['models'];
      if (rawModels is! List) {
        throw const AIServiceException(code: 'no_models_returned');
      }

      final models =
          rawModels
              .map((item) {
                if (item is String) return item;
                if (item is Map) {
                  final value = item['id'] ?? item['name'] ?? item['model'];
                  return value?.toString();
                }
                return null;
              })
              .whereType<String>()
              .map(
                (model) => model.replaceFirst(RegExp(r'^models/'), '').trim(),
              )
              .where((model) => model.isNotEmpty)
              .toSet()
              .toList()
            ..sort();

      if (models.isEmpty) {
        throw const AIServiceException(code: 'no_models_available');
      }
      return models;
    } on DioException catch (error) {
      throw _extractDioException(error);
    } on AIServiceException {
      rethrow;
    } catch (error) {
      throw AIServiceException(
        code: 'fetch_models_failed',
        error: error.toString(),
      );
    }
  }

  @override
  Future<String> askSelection({
    required String selectedText,
    required String contextBefore,
    required String contextAfter,
    required AIRequestMeta meta,
  }) {
    final prompt = StringBuffer()
      ..writeln('请解释下面这段选中文本，并给出 3 条要点。')
      ..writeln()
      ..writeln('【选中文本】')
      ..writeln(selectedText.trim())
      ..writeln()
      ..writeln('【上文】')
      ..writeln(contextBefore.trim().isEmpty ? '(无)' : contextBefore.trim())
      ..writeln()
      ..writeln('【下文】')
      ..writeln(contextAfter.trim().isEmpty ? '(无)' : contextAfter.trim());

    return chat(
      history: [AIChatMessage(role: 'user', content: prompt.toString())],
      pageText: '$contextBefore\n$selectedText\n$contextAfter',
      meta: meta,
    );
  }

  @override
  Future<String> analyzePage({
    required String pageText,
    required AIRequestMeta meta,
  }) {
    return chat(
      history: const [
        AIChatMessage(role: 'user', content: '请总结当前页的核心观点，并给出 3 条可执行的阅读建议。'),
      ],
      pageText: pageText,
      meta: meta,
    );
  }

  @override
  Future<String> chat({
    required List<AIChatMessage> history,
    required String pageText,
    required AIRequestMeta meta,
  }) async {
    final settings = await _resolveActiveSettings();
    final validationError = validateAIProviderSettings(settings);
    if (validationError != null) {
      throw AIServiceException(code: validationError);
    }

    final context = _compactPageContext(pageText);
    final singleSystemPrompt = _buildSingleSystemPrompt(
      context: context,
      meta: meta,
    );
    final messages = <Map<String, dynamic>>[
      {'role': 'system', 'content': singleSystemPrompt},
      ...history
          .where(
            (m) =>
                (m.role == 'user' ||
                    m.role == 'assistant' ||
                    m.role == 'system') &&
                m.content.trim().isNotEmpty,
          )
          .map((m) => m.toJson()),
    ];

    if (!messages.any((m) => m['role'] == 'user')) {
      throw const AIServiceException(code: 'enter_question_first');
    }

    final endpoint = _buildEndpoint(settings);
    final payload = _buildPayload(settings: settings, messages: messages);

    try {
      final response = await _dio.post<String>(
        endpoint,
        data: payload,
        options: _buildRequestOptions(settings),
      );
      final responseData = _decodeResponseBody(
        rawBody: response.data,
        endpoint: endpoint,
        settings: settings,
      );
      final answer = _extractAssistantContent(
        settings: settings,
        responseData: responseData,
      );
      if (answer.trim().isEmpty) {
        throw const AIServiceException(code: 'empty_response');
      }
      return answer.trim();
    } on DioException catch (e) {
      throw _extractDioException(e);
    } catch (e) {
      throw AIServiceException(code: 'request_failed', error: e.toString());
    }
  }

  Future<AIProviderSettings> _resolveActiveSettings() async {
    if (_cachedActive != null) {
      return _cachedActive!;
    }
    return loadSettings();
  }

  String _compactPageContext(String pageText) {
    final text = pageText
        .replaceAll('\r\n', '\n')
        .replaceAll(RegExp(r'\n{3,}'), '\n\n')
        .trim();
    if (text.length <= 2800) {
      return text;
    }
    return '${text.substring(0, 2800)}...';
  }

  String _buildSingleSystemPrompt({
    required String context,
    required AIRequestMeta meta,
  }) {
    final buffer = StringBuffer()
      ..writeln('你是一个中文阅读助手。')
      ..writeln('回答要求：简洁、准确、结构清晰，优先结合用户当前阅读页内容。')
      ..writeln(
        '元信息：bookId=${meta.bookId}, chapterId=${meta.chapterId}, pageIndex=${meta.pageIndex ?? -1}',
      );
    if (context.isNotEmpty) {
      buffer
        ..writeln('当前阅读页正文（仅供参考）：')
        ..writeln(context);
    }
    return buffer.toString().trim();
  }

  String _buildEndpoint(AIProviderSettings settings) {
    final base = settings.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
    switch (settings.provider) {
      case AIProviderType.minimax:
      case AIProviderType.glm:
      case AIProviderType.openai:
        return '$base/chat/completions';
      case AIProviderType.claude:
        if (base.endsWith('/v1')) {
          return '$base/messages';
        }
        return '$base/v1/messages';
      case AIProviderType.gemini:
        final modelPath = settings.model.startsWith('models/')
            ? settings.model
            : 'models/${settings.model}';
        return '$base/$modelPath:generateContent';
    }
  }

  Options _buildRequestOptions(AIProviderSettings settings) {
    final headers = <String, dynamic>{'Content-Type': 'application/json'};

    switch (settings.provider) {
      case AIProviderType.minimax:
      case AIProviderType.glm:
      case AIProviderType.openai:
        headers['Authorization'] = 'Bearer ${settings.apiKey}';
        break;
      case AIProviderType.claude:
        headers['x-api-key'] = settings.apiKey;
        headers['anthropic-version'] = '2023-06-01';
        break;
      case AIProviderType.gemini:
        headers['x-goog-api-key'] = settings.apiKey;
        break;
    }

    return Options(
      headers: headers,
      responseType: ResponseType.plain,
      receiveDataWhenStatusError: true,
      sendTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 90),
    );
  }

  dynamic _decodeResponseBody({
    required String? rawBody,
    required String endpoint,
    required AIProviderSettings settings,
  }) {
    final body = rawBody?.trim() ?? '';
    if (body.isEmpty) {
      throw AIServiceException(
        code: 'empty_response_error',
        endpoint: endpoint,
      );
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      throw AIServiceException(
        code: 'invalid_json_error',
        provider: settings.provider.displayName,
        endpoint: endpoint,
        snippet: _truncateForError(body),
      );
    }
  }

  Map<String, dynamic> _buildPayload({
    required AIProviderSettings settings,
    required List<Map<String, dynamic>> messages,
  }) {
    switch (settings.provider) {
      case AIProviderType.minimax:
        final minimaxTemp = settings.temperature.clamp(0.01, 1.0);
        return <String, dynamic>{
          'model': settings.model,
          'messages': messages,
          'temperature': minimaxTemp,
          'stream': false,
        };
      case AIProviderType.glm:
      case AIProviderType.openai:
        return <String, dynamic>{
          'model': settings.model,
          'messages': messages,
          'temperature': settings.temperature,
          'stream': false,
        };
      case AIProviderType.claude:
        final systemPrompt =
            messages.isNotEmpty &&
                messages.first['role'] == 'system' &&
                messages.first['content'] is String
            ? messages.first['content'] as String
            : '';
        final chatMessages = messages
            .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
            .map(
              (m) => <String, dynamic>{
                'role': m['role'],
                'content': [
                  {'type': 'text', 'text': (m['content'] as String?) ?? ''},
                ],
              },
            )
            .toList();
        return <String, dynamic>{
          'model': settings.model,
          'system': systemPrompt,
          'messages': chatMessages,
          'max_tokens': 1024,
          'temperature': settings.temperature.clamp(0.0, 1.0),
        };
      case AIProviderType.gemini:
        final systemPrompt =
            messages.isNotEmpty &&
                messages.first['role'] == 'system' &&
                messages.first['content'] is String
            ? messages.first['content'] as String
            : '';
        final chatContents = messages
            .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
            .map(
              (m) => <String, dynamic>{
                'role': m['role'] == 'assistant' ? 'model' : 'user',
                'parts': [
                  {'text': (m['content'] as String?) ?? ''},
                ],
              },
            )
            .toList();
        return <String, dynamic>{
          if (systemPrompt.isNotEmpty)
            'systemInstruction': {
              'parts': [
                {'text': systemPrompt},
              ],
            },
          'contents': chatContents,
          'generationConfig': {
            'temperature': settings.temperature.clamp(0.0, 1.0),
          },
        };
    }
  }

  String _extractAssistantContent({
    required AIProviderSettings settings,
    required dynamic responseData,
  }) {
    switch (settings.provider) {
      case AIProviderType.minimax:
      case AIProviderType.glm:
      case AIProviderType.openai:
        return _extractOpenAIContent(responseData);
      case AIProviderType.claude:
        return _extractClaudeContent(responseData);
      case AIProviderType.gemini:
        return _extractGeminiContent(responseData);
    }
  }

  String _extractOpenAIContent(dynamic responseData) {
    if (responseData is! Map) {
      return '';
    }
    final choices = responseData['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final first = choices.first;
    if (first is! Map) {
      return '';
    }
    final message = first['message'];
    if (message is! Map) {
      return '';
    }
    final content = message['content'];
    if (content is String) {
      return content;
    }
    if (content is List) {
      final buffer = StringBuffer();
      for (final part in content) {
        if (part is Map && part['text'] is String) {
          buffer.write(part['text'] as String);
        } else if (part is String) {
          buffer.write(part);
        }
      }
      return buffer.toString();
    }
    return '';
  }

  String _extractClaudeContent(dynamic responseData) {
    if (responseData is! Map) {
      return '';
    }
    final content = responseData['content'];
    if (content is! List || content.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final part in content) {
      if (part is Map && part['type'] == 'text' && part['text'] is String) {
        buffer.write(part['text'] as String);
      }
    }
    return buffer.toString();
  }

  String _extractGeminiContent(dynamic responseData) {
    if (responseData is! Map) {
      return '';
    }
    final candidates = responseData['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }
    final first = candidates.first;
    if (first is! Map) {
      return '';
    }
    final content = first['content'];
    if (content is! Map) {
      return '';
    }
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) {
      return '';
    }
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] is String) {
        buffer.write(part['text'] as String);
      }
    }
    return buffer.toString();
  }

  AIServiceException _extractDioException(DioException e) {
    final status = e.response?.statusCode;
    final statusStr = status?.toString() ?? '';
    final data = e.response?.data;
    final endpoint = e.requestOptions.uri.toString();
    if (data is Map) {
      final message = _extractMapErrorMessage(data);
      if (message != null) {
        return _enhanceProviderException(message, statusStr, endpoint);
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        final jsonMap = jsonDecode(data);
        if (jsonMap is Map) {
          final msg = _extractMapErrorMessage(jsonMap);
          if (msg != null) {
            return _enhanceProviderException(msg, statusStr, endpoint);
          }
        }
      } catch (_) {
        return _enhanceProviderException(data, statusStr, endpoint);
      }
    }
    final rawError = e.error?.toString() ?? e.message ?? '';
    if (_looksLikeMissingResponse(rawError)) {
      return AIServiceException(
        code: 'failed_read_body',
        status: statusStr,
        endpoint: endpoint,
      );
    }
    return AIServiceException(
      code: 'network_request_failed',
      status: statusStr,
      error: rawError,
      endpoint: endpoint,
    );
  }

  /// Extract the first non-empty error message from a response Map.
  String? _extractMapErrorMessage(Map data) {
    final error = data['error'];
    if (error is Map) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }
    }
    final message = data['message'];
    if (message is String && message.trim().isNotEmpty) {
      return message;
    }
    final detail = data['detail'];
    if (detail is String && detail.trim().isNotEmpty) {
      return detail;
    }
    return null;
  }

  AIServiceException _enhanceProviderException(
    String message,
    String status,
    String endpoint,
  ) {
    final text = message.trim();
    if (text.toLowerCase().contains('invalid chat setting')) {
      return AIServiceException(
        code: 'request_failed_minimax_hint',
        status: status,
        text: text,
        endpoint: endpoint,
      );
    }
    if (text.toLowerCase().contains('anthropic-version')) {
      return AIServiceException(
        code: 'request_failed_claude_hint',
        status: status,
        text: text,
        endpoint: endpoint,
      );
    }
    if (text.toLowerCase().contains('api key not valid') ||
        text.toLowerCase().contains('invalid api key')) {
      return AIServiceException(
        code: 'request_failed_provider_mismatch_hint',
        status: status,
        text: text,
        endpoint: endpoint,
      );
    }
    if (_looksLikeMissingResponse(text)) {
      return AIServiceException(
        code: 'failed_read_body',
        status: status,
        endpoint: endpoint,
      );
    }
    return AIServiceException(
      code: 'request_failed_generic',
      status: status,
      text: text,
      endpoint: endpoint,
    );
  }

  bool _looksLikeMissingResponse(String text) {
    final lower = text.toLowerCase();
    return lower.contains('data couldn') && lower.contains('missing') ||
        lower.contains('data is missing') ||
        lower.contains('because it is missing') ||
        lower.contains('unexpected end of input');
  }

  String _truncateForError(String text, {int maxLength = 220}) {
    final compact = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (compact.length <= maxLength) {
      return compact;
    }
    return '${compact.substring(0, maxLength)}...';
  }

  String _apiKeyKey(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.minimax:
        return _minimaxApiKeyKey;
      case AIProviderType.glm:
        return _glmApiKeyKey;
      case AIProviderType.openai:
        return _openaiApiKeyKey;
      case AIProviderType.claude:
        return _claudeApiKeyKey;
      case AIProviderType.gemini:
        return _geminiApiKeyKey;
    }
  }

  String _baseUrlKey(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.minimax:
        return _minimaxBaseUrlKey;
      case AIProviderType.glm:
        return _glmBaseUrlKey;
      case AIProviderType.openai:
        return _openaiBaseUrlKey;
      case AIProviderType.claude:
        return _claudeBaseUrlKey;
      case AIProviderType.gemini:
        return _geminiBaseUrlKey;
    }
  }

  String _modelKey(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.minimax:
        return _minimaxModelKey;
      case AIProviderType.glm:
        return _glmModelKey;
      case AIProviderType.openai:
        return _openaiModelKey;
      case AIProviderType.claude:
        return _claudeModelKey;
      case AIProviderType.gemini:
        return _geminiModelKey;
    }
  }

  String _temperatureKey(AIProviderType provider) {
    switch (provider) {
      case AIProviderType.minimax:
        return _minimaxTemperatureKey;
      case AIProviderType.glm:
        return _glmTemperatureKey;
      case AIProviderType.openai:
        return _openaiTemperatureKey;
      case AIProviderType.claude:
        return _claudeTemperatureKey;
      case AIProviderType.gemini:
        return _geminiTemperatureKey;
    }
  }
}

class MockAIService implements ConfigurableAIService {
  AIProviderSettings _settings = AIProviderSettings.defaults(
    AIProviderType.minimax,
  );

  @override
  Future<AIProviderSettings> loadSettings([AIProviderType? provider]) async {
    if (provider == null || provider == _settings.provider) {
      return _settings;
    }
    return AIProviderSettings.defaults(provider);
  }

  @override
  Future<void> saveSettings(AIProviderSettings settings) async {
    _settings = settings.normalized();
  }

  @override
  Future<String> askSelection({
    required String selectedText,
    required String contextBefore,
    required String contextAfter,
    required AIRequestMeta meta,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return _mockToken('mock_selection_response', {
      'selectedText': selectedText,
      'before': _trim(contextBefore),
      'after': _trim(contextAfter),
    });
  }

  @override
  Future<String> analyzePage({
    required String pageText,
    required AIRequestMeta meta,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return _mockToken('mock_page_analysis', {'chars': pageText.length});
  }

  @override
  Future<String> chat({
    required List<AIChatMessage> history,
    required String pageText,
    required AIRequestMeta meta,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final last = history.isNotEmpty ? history.last.content : '';
    if (last.trim().isEmpty) {
      return _mockToken('mock_greeting', {});
    }
    return _mockToken('mock_chat_response', {
      'question': _trim(last),
      'chars': pageText.length,
    });
  }

  String _trim(String text) {
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }

  /// Encode a mock response as a token that the UI layer translates
  /// via [translateMockAiResponse].
  static String _mockToken(String code, Map<String, dynamic> params) {
    return '[[mock:$code|${jsonEncode(params)}]]';
  }
}
