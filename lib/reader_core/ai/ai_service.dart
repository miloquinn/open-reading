// 文件说明：阅读内核 AI 配置与请求模型，统一描述模型、提供商和请求参数。
// 技术要点：ReaderCore、Dio、SharedPreferences、JSON。

import 'dart:convert';

import 'package:dio/dio.dart';
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

enum AIProviderType {
  minimax,
  glm,
  openai,
  claude,
  gemini,
}

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
      path = path.replaceFirst(
        RegExp(r'/messages$', caseSensitive: false),
        '',
      );
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
    return 'API Key 不能为空';
  }
  if (normalized.model.isEmpty) {
    return 'Model 不能为空';
  }

  final uri = Uri.tryParse(normalized.baseUrl);
  if (normalized.baseUrl.isEmpty ||
      uri == null ||
      !(uri.isScheme('http') || uri.isScheme('https'))) {
    return 'Base URL 必须是合法的 http/https 地址';
  }

  if (!_isValidTemperature(normalized.provider, normalized.temperature)) {
    return normalized.provider == AIProviderType.minimax
        ? 'MiniMax 的 Temperature 必须在 0.01 ~ 1.00 之间'
        : 'Temperature 超出范围，请按提示填写';
  }

  final model = normalized.model.toLowerCase();
  switch (normalized.provider) {
    case AIProviderType.claude:
      if (!model.startsWith('claude')) {
        return 'Claude 服务商的模型名通常应以 claude 开头，请检查 provider 和 model 是否匹配';
      }
      break;
    case AIProviderType.gemini:
      if (!model.contains('gemini')) {
        return 'Gemini 服务商的模型名通常应包含 gemini，请检查 provider 和 model 是否匹配';
      }
      break;
    case AIProviderType.glm:
      if (!model.startsWith('glm')) {
        return 'GLM 服务商的模型名通常应以 glm 开头，请检查 provider 和 model 是否匹配';
      }
      break;
    case AIProviderType.minimax:
      if (!model.contains('minimax')) {
        return 'MiniMax 服务商的模型名通常应包含 MiniMax，请检查 provider 和 model 是否匹配';
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
    final normalizedBase =
        settings.baseUrl.trim().replaceAll(RegExp(r'/+$'), '');
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
      model:
          normalizedModel.isEmpty ? _defaultModel(provider) : normalizedModel,
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

  const AIChatMessage({
    required this.role,
    required this.content,
  });

  Map<String, dynamic> toJson() => {
        'role': role,
        'content': content,
      };
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
  final String message;
  const AIServiceException(this.message);

  @override
  String toString() => message;
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

  @override
  Future<AIProviderSettings> loadSettings([AIProviderType? provider]) async {
    final prefs = await SharedPreferences.getInstance();
    final activeProvider = provider ??
        AIProviderTypeX.fromValue(prefs.getString(_activeProviderKey));
    final defaults = AIProviderSettings.defaults(activeProvider);

    final apiKey = prefs.getString(_apiKeyKey(activeProvider)) ?? '';
    final baseUrl =
        prefs.getString(_baseUrlKey(activeProvider)) ?? defaults.baseUrl;
    final model = prefs.getString(_modelKey(activeProvider)) ?? defaults.model;
    final temperature = prefs.getDouble(_temperatureKey(activeProvider)) ??
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
      throw AIServiceException(validationError);
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_activeProviderKey, normalized.provider.value);
    await prefs.setString(_apiKeyKey(normalized.provider), normalized.apiKey);
    await prefs.setString(_baseUrlKey(normalized.provider), normalized.baseUrl);
    await prefs.setString(_modelKey(normalized.provider), normalized.model);
    await prefs.setDouble(
      _temperatureKey(normalized.provider),
      normalized.temperature,
    );
    _cachedActive = normalized;
  }

  Future<List<String>> fetchAvailableModels(
    AIProviderSettings settings,
  ) async {
    final normalized = settings.normalized();
    if (normalized.apiKey.isEmpty) {
      throw const AIServiceException('请先填写 API Key');
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
        throw const AIServiceException('模型列表返回格式无法识别');
      }

      final rawModels = body['data'] ?? body['models'];
      if (rawModels is! List) {
        throw const AIServiceException('服务端没有返回可用模型列表');
      }

      final models = rawModels
          .map((item) {
            if (item is String) return item;
            if (item is Map) {
              final value = item['id'] ?? item['name'] ?? item['model'];
              return value?.toString();
            }
            return null;
          })
          .whereType<String>()
          .map((model) => model.replaceFirst(RegExp(r'^models/'), '').trim())
          .where((model) => model.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      if (models.isEmpty) {
        throw const AIServiceException('没有获取到可用模型');
      }
      return models;
    } on DioException catch (error) {
      throw AIServiceException(_extractDioErrorMessage(error));
    } on AIServiceException {
      rethrow;
    } catch (error) {
      throw AIServiceException('获取模型失败：$error');
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
      history: [
        AIChatMessage(role: 'user', content: prompt.toString()),
      ],
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
        AIChatMessage(
          role: 'user',
          content: '请总结当前页的核心观点，并给出 3 条可执行的阅读建议。',
        ),
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
      throw AIServiceException(validationError);
    }

    final context = _compactPageContext(pageText);
    final singleSystemPrompt = _buildSingleSystemPrompt(
      context: context,
      meta: meta,
    );
    final messages = <Map<String, dynamic>>[
      {
        'role': 'system',
        'content': singleSystemPrompt,
      },
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
      throw const AIServiceException('请输入问题后再发送');
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
        throw const AIServiceException('模型返回为空，请重试');
      }
      return answer.trim();
    } on DioException catch (e) {
      final msg = _extractDioErrorMessage(e);
      throw AIServiceException(msg);
    } catch (e) {
      throw AIServiceException('请求失败：$e');
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
    final headers = <String, dynamic>{
      'Content-Type': 'application/json',
    };

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
        '服务端返回为空，通常是 Base URL 配置错误、网关没有转发到模型接口，或服务端提前断开连接。\n请求地址：$endpoint',
      );
    }

    try {
      return jsonDecode(body);
    } on FormatException {
      throw AIServiceException(
        '服务端返回的不是合法 JSON，当前接口可能与 ${settings.provider.displayName} 配置不兼容。\n请求地址：$endpoint\n返回片段：${_truncateForError(body)}',
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
        final systemPrompt = messages.isNotEmpty &&
                messages.first['role'] == 'system' &&
                messages.first['content'] is String
            ? messages.first['content'] as String
            : '';
        final chatMessages = messages
            .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
            .map((m) => <String, dynamic>{
                  'role': m['role'],
                  'content': [
                    {
                      'type': 'text',
                      'text': (m['content'] as String?) ?? '',
                    },
                  ],
                })
            .toList();
        return <String, dynamic>{
          'model': settings.model,
          'system': systemPrompt,
          'messages': chatMessages,
          'max_tokens': 1024,
          'temperature': settings.temperature.clamp(0.0, 1.0),
        };
      case AIProviderType.gemini:
        final systemPrompt = messages.isNotEmpty &&
                messages.first['role'] == 'system' &&
                messages.first['content'] is String
            ? messages.first['content'] as String
            : '';
        final chatContents = messages
            .where((m) => m['role'] == 'user' || m['role'] == 'assistant')
            .map((m) => <String, dynamic>{
                  'role': m['role'] == 'assistant' ? 'model' : 'user',
                  'parts': [
                    {
                      'text': (m['content'] as String?) ?? '',
                    },
                  ],
                })
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

  String _extractDioErrorMessage(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;
    final endpoint = e.requestOptions.uri.toString();
    if (data is Map) {
      final error = data['error'];
      if (error is Map) {
        final message = error['message'];
        if (message is String && message.trim().isNotEmpty) {
          return _enhanceProviderError(message, status, endpoint: endpoint);
        }
      }
      final message = data['message'];
      if (message is String && message.trim().isNotEmpty) {
        return _enhanceProviderError(message, status, endpoint: endpoint);
      }
      final detail = data['detail'];
      if (detail is String && detail.trim().isNotEmpty) {
        return _enhanceProviderError(detail, status, endpoint: endpoint);
      }
    }
    if (data is String && data.trim().isNotEmpty) {
      try {
        final jsonMap = jsonDecode(data);
        if (jsonMap is Map) {
          final msg = jsonMap['message'];
          if (msg is String && msg.trim().isNotEmpty) {
            return _enhanceProviderError(msg, status, endpoint: endpoint);
          }
        }
      } catch (_) {
        return _enhanceProviderError(data, status, endpoint: endpoint);
      }
    }
    final rawError = e.error?.toString() ?? e.message ?? '未知错误';
    if (_looksLikeMissingResponse(rawError)) {
      return '请求失败${status == null ? '' : '($status)'}：未能读取服务端返回的数据，通常是 Base URL 配错、接口返回空内容，或网络把响应截断了。\n请求地址：$endpoint';
    }
    return '网络请求失败${status == null ? '' : '($status)'}：$rawError\n请求地址：$endpoint';
  }

  String _enhanceProviderError(
    String message,
    int? status, {
    required String endpoint,
  }) {
    final text = message.trim();
    if (text.toLowerCase().contains('invalid chat setting')) {
      return '请求失败($status)：$text\n建议检查：1) MiniMax 温度需在 (0,1]；2) 模型名与接口是否匹配；3) 仅使用单条 system 指令。\n请求地址：$endpoint';
    }
    if (text.toLowerCase().contains('anthropic-version')) {
      return '请求失败($status)：$text\n提示：Claude 必须携带 anthropic-version 请求头。\n请求地址：$endpoint';
    }
    if (text.toLowerCase().contains('api key not valid') ||
        text.toLowerCase().contains('invalid api key')) {
      return '请求失败($status)：$text\n提示：请确认服务商与 API Key 对应，不可混用。\n请求地址：$endpoint';
    }
    if (_looksLikeMissingResponse(text)) {
      return '请求失败${status == null ? '' : '($status)'}：未能读取服务端返回的数据，通常是 Base URL 配错、接口返回空内容，或网络把响应截断了。\n请求地址：$endpoint';
    }
    return '请求失败($status)：$text\n请求地址：$endpoint';
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
  AIProviderSettings _settings =
      AIProviderSettings.defaults(AIProviderType.minimax);

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
    return 'AI(模拟): 你选择的内容是“$selectedText”。\n\n上文: ${_trim(contextBefore)}\n下文: ${_trim(contextAfter)}';
  }

  @override
  Future<String> analyzePage({
    required String pageText,
    required AIRequestMeta meta,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return 'AI(模拟): 本页共 ${pageText.length} 字，建议重点关注段落开头与结尾处的论点。';
  }

  @override
  Future<String> chat({
    required List<AIChatMessage> history,
    required String pageText,
    required AIRequestMeta meta,
  }) async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    final last = history.isNotEmpty ? history.last.content : '你好';
    return 'AI(模拟): 你问的是「${_trim(last)}」。\n\n我已读取当前页（${pageText.length} 字），你可以继续追问。';
  }

  String _trim(String text) {
    if (text.length <= 80) return text;
    return '${text.substring(0, 80)}...';
  }
}
