import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xxread/reader_core/ai/ai_service.dart';

void main() {
  group('ReaderHttpAIService.fetchAvailableModels', () {
    test('parses OpenAI-compatible model data', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'data': [
                      {'id': 'model-b'},
                      {'id': 'model-a'},
                    ],
                  },
                ),
              );
            },
          ),
        );
      final service = ReaderHttpAIService(dio: dio);

      final models = await service.fetchAvailableModels(
        const AIProviderSettings(
          provider: AIProviderType.openai,
          apiKey: 'test-key',
          baseUrl: 'https://example.com/v1',
          model: 'model-a',
          temperature: 0.7,
        ),
      );

      expect(models, ['model-a', 'model-b']);
    });

    test('parses and normalizes Gemini model names', () async {
      final dio = Dio()
        ..interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              handler.resolve(
                Response<dynamic>(
                  requestOptions: options,
                  statusCode: 200,
                  data: {
                    'models': [
                      {'name': 'models/gemini-2.5-flash'},
                      {'name': 'models/gemini-2.5-pro'},
                    ],
                  },
                ),
              );
            },
          ),
        );
      final service = ReaderHttpAIService(dio: dio);

      final models = await service.fetchAvailableModels(
        const AIProviderSettings(
          provider: AIProviderType.gemini,
          apiKey: 'test-key',
          baseUrl: 'https://generativelanguage.googleapis.com/v1beta',
          model: 'gemini-2.5-flash',
          temperature: 0.7,
        ),
      );

      expect(models, ['gemini-2.5-flash', 'gemini-2.5-pro']);
    });
  });
}
