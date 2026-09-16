import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

enum AiModelType { qwen, deepseek }

class AiModelConfig {
  final String name;
  final String baseUrl;
  final String model;
  final String prefsKey;
  final String apiKeyUrl;
  final String apiKeyGuide;

  const AiModelConfig({
    required this.name,
    required this.baseUrl,
    required this.model,
    required this.prefsKey,
    required this.apiKeyUrl,
    required this.apiKeyGuide,
  });
}

class AiService {
  static const Map<AiModelType, AiModelConfig> _modelConfigs = {
    AiModelType.qwen: AiModelConfig(
      name: 'Qwen',
      baseUrl: 'https://dashscope.aliyuncs.com/compatible-mode/v1',
      model: 'qwen3.6-flash',
      prefsKey: 'qwen_api_key',
      apiKeyUrl: 'https://bailian.console.aliyun.com/?tab=model#/api-key',
      apiKeyGuide: '登录阿里云百炼控制台，在 API Key 管理页面创建并复制密钥。',
    ),
    AiModelType.deepseek: AiModelConfig(
      name: 'DeepSeek',
      baseUrl: 'https://api.deepseek.com',
      model: 'deepseek-v4-flash',
      prefsKey: 'deepseek_api_key',
      apiKeyUrl: 'https://platform.deepseek.com/api_keys',
      apiKeyGuide: '登录 DeepSeek 开放平台，在 API Keys 页面创建并复制密钥。',
    ),
  };

  Future<String> _getApiKey(AiModelType modelType) async {
    final prefs = await SharedPreferences.getInstance();
    final config = _modelConfigs[modelType]!;
    return prefs.getString(config.prefsKey) ?? '';
  }

  static Future<String> getApiKey(AiModelType modelType) async {
    final prefs = await SharedPreferences.getInstance();
    final config = _modelConfigs[modelType]!;
    return prefs.getString(config.prefsKey) ?? '';
  }

  static Future<void> setApiKey(AiModelType modelType, String apiKey) async {
    final prefs = await SharedPreferences.getInstance();
    final config = _modelConfigs[modelType]!;
    await prefs.setString(config.prefsKey, apiKey);
  }

  static AiModelConfig getModelConfig(AiModelType modelType) {
    return _modelConfigs[modelType]!;
  }

  static String getDefaultApiKey(AiModelType modelType) {
    return '';
  }

  Stream<String> chatStream({
    required List<Map<String, String>> messages,
    required AiModelType modelType,
  }) async* {
    final config = _modelConfigs[modelType]!;
    final apiKey = await _getApiKey(modelType);
    if (apiKey.trim().isEmpty) {
      throw StateError('请先在设置中配置 ${config.name} API Key');
    }

    final uri = Uri.parse('${config.baseUrl}/chat/completions');

    final bodyMap = <String, dynamic>{
      'model': config.model,
      'messages': messages,
      'stream': true,
    };
    // DeepSeek 默认开启思考模式，按文档传 thinking.type = disabled 关闭
    if (modelType == AiModelType.deepseek) {
      bodyMap['thinking'] = {'type': 'disabled'};
    }

    final body = jsonEncode(bodyMap);

    final request = http.Request('POST', uri)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer $apiKey'
      ..body = body;

    final streamedResponse = await request.send();

    if (streamedResponse.statusCode != 200) {
      final errorBody = await streamedResponse.stream.bytesToString();
      throw Exception('API请求失败: ${streamedResponse.statusCode} - $errorBody');
    }

    String buffer = '';
    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      buffer += chunk;
      final lines = buffer.split('\n');
      buffer = lines.removeLast();

      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.isEmpty || trimmed == 'data: [DONE]') continue;
        if (!trimmed.startsWith('data: ')) continue;

        final jsonStr = trimmed.substring(6);
        try {
          final json = jsonDecode(jsonStr);
          final choices = json['choices'] as List<dynamic>?;
          if (choices != null && choices.isNotEmpty) {
            final delta = choices[0]['delta'] as Map<String, dynamic>?;
            if (delta != null) {
              final content = delta['content'] as String?;
              if (content != null && content.isNotEmpty) {
                yield content;
              }
            }
          }
        } catch (_) {}
      }
    }
  }
}
