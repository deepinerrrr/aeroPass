import 'dart:async';
import 'dart:convert';
import 'package:get/get.dart';
import '../../data/services/ai_service.dart';
import '../../data/models/question_model.dart';
import '../../data/database/database_helper.dart';
import '../home/home_controller.dart';

class ChatMessage {
  final String role;
  final String content;
  final bool isStreaming;

  ChatMessage({
    required this.role,
    required this.content,
    this.isStreaming = false,
  });

  ChatMessage copyWith({String? content, bool? isStreaming}) {
    return ChatMessage(
      role: role,
      content: content ?? this.content,
      isStreaming: isStreaming ?? this.isStreaming,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
      'isStreaming': isStreaming,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      role: json['role'] as String,
      content: json['content'] as String,
      isStreaming: json['isStreaming'] as bool? ?? false,
    );
  }
}

class AiChatController extends GetxController {
  final AiService _aiService = AiService();
  final DatabaseHelper _db = DatabaseHelper();

  final messages = <ChatMessage>[].obs;
  final isGenerating = false.obs;
  final inputText = ''.obs;
  final currentModel = 'qwen'.obs;
  StreamSubscription? _currentSubscription;

  late Question _question;
  bool _hasHistory = false;

  AiModelType get currentModelType =>
      currentModel.value == 'deepseek' ? AiModelType.deepseek : AiModelType.qwen;

  String get currentModelName {
    final config = AiService.getModelConfig(currentModelType);
    return config.name;
  }

  @override
  void onInit() {
    super.onInit();
    _loadCurrentModel();
  }

  Future<void> _loadCurrentModel() async {
    try {
      final settingsController = Get.find<SettingsController>();
      currentModel.value = settingsController.currentAiModel.value;
    } catch (_) {
      currentModel.value = 'qwen';
    }
  }

  void switchModel(String model) {
    if (isGenerating.value) return;
    currentModel.value = model;
  }

  Future<void> initQuestion(Question question) async {
    _question = question;
    inputText.value = '';

    await _loadCurrentModel();

    final historyJson = await _db.loadAiChatHistory(question.questionId);
    if (historyJson != null && historyJson.isNotEmpty) {
      try {
        final historyList = jsonDecode(historyJson) as List<dynamic>;
        messages.value = historyList
            .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
            .toList();
        _hasHistory = true;
      } catch (_) {
        _hasHistory = false;
      }
    }

    if (!_hasHistory || messages.isEmpty) {
      messages.clear();
      _addSystemMessage();
      _sendInitialAnalysis();
    }
  }

  void _addSystemMessage() {
    final optionsBuffer = StringBuffer();
    final labels = _question.optionLabels;
    final options = _question.options;
    for (int i = 0; i < options.length; i++) {
      optionsBuffer.writeln('${labels[i]}. ${options[i]}');
    }

    final referenceAnswerText = _question.referenceAnswer != null && _question.referenceAnswer!.isNotEmpty
        ? '\n参考答案解析：${_question.referenceAnswer}'
        : '';

    final systemPrompt = '''你是执照考试的专业辅导老师。请对以下题目进行详细解析。

题目信息：
- 题号：${_question.questionId}
- 题型：${_question.isJudge ? '判断题' : '单选题'}
- 题目：${_question.content}
${_question.isJudge ? '' : '- 选项：\n$optionsBuffer'}
- 参考答案：${_question.answer}$referenceAnswerText

请按以下结构进行解析，必须包含三大部分，每部分都要有实质内容：

## 一、题目解析
- 详细解释正确答案
- 逐个分析各选项对错原因
- 指出题目中的关键词和陷阱

## 二、知识拓展
- 相关知识点的延伸讲解
- 考试中常见的相似题型
- 记忆口诀或理解技巧

## 三、通俗解释
- 用生活中的例子或比喻来解释
- 用简单的类比帮助理解抽象概念
- 避免使用专业术语，用通俗语言阐述

格式要求：
- 使用 Markdown 格式
- 适当使用列表、加粗等格式增强可读性
- 不要输出思考过程，直接给出答案
- 参考答案即为正确答案''';

    messages.add(ChatMessage(role: 'system', content: systemPrompt));
  }

  void _sendInitialAnalysis() {
    messages.add(ChatMessage(role: 'user', content: '请帮我解析这道题目。'));
    _generateResponse();
  }

  void sendMessage() {
    final text = inputText.value.trim();
    if (text.isEmpty || isGenerating.value) return;

    messages.add(ChatMessage(role: 'user', content: text));
    inputText.value = '';
    _generateResponse();
  }

  List<Map<String, String>> _buildApiMessages() {
    final apiMessages = <Map<String, String>>[];
    for (final msg in messages) {
      apiMessages.add({'role': msg.role, 'content': msg.content});
    }
    return apiMessages;
  }

  void _generateResponse() {
    isGenerating.value = true;

    final assistantMessage = ChatMessage(role: 'assistant', content: '', isStreaming: true);
    messages.add(assistantMessage);

    final apiMessages = _buildApiMessages();

    final stream = _aiService.chatStream(
      messages: apiMessages,
      modelType: currentModelType,
    );

    _currentSubscription = stream.listen(
      (chunk) {
        final lastIndex = messages.length - 1;
        if (lastIndex >= 0 && messages[lastIndex].role == 'assistant') {
          final updated = messages[lastIndex].copyWith(
            content: messages[lastIndex].content + chunk,
          );
          messages[lastIndex] = updated;
        }
      },
      onDone: () {
        final lastIndex = messages.length - 1;
        if (lastIndex >= 0 && messages[lastIndex].role == 'assistant') {
          messages[lastIndex] = messages[lastIndex].copyWith(isStreaming: false);
        }
        isGenerating.value = false;
        _saveHistory();
      },
      onError: (error) {
        final lastIndex = messages.length - 1;
        if (lastIndex >= 0 && messages[lastIndex].role == 'assistant') {
          messages[lastIndex] = ChatMessage(
            role: 'assistant',
            content: '抱歉，生成回答时出现错误：${error.toString()}',
            isStreaming: false,
          );
        }
        isGenerating.value = false;
        _saveHistory();
      },
    );
  }

  void stopGeneration() {
    _currentSubscription?.cancel();
    final lastIndex = messages.length - 1;
    if (lastIndex >= 0 && messages[lastIndex].role == 'assistant') {
      messages[lastIndex] = messages[lastIndex].copyWith(isStreaming: false);
    }
    isGenerating.value = false;
    _saveHistory();
  }

  Future<void> clearHistory() async {
    stopGeneration();
    await _db.deleteAiChatHistory(_question.questionId);
    messages.clear();
    _hasHistory = false;
    _addSystemMessage();
    _sendInitialAnalysis();
  }

  Future<void> _saveHistory() async {
    try {
      final displayMessages = messages.where((m) => m.role != 'system').toList();
      final jsonList = displayMessages.map((m) => m.toJson()).toList();
      await _db.saveAiChatHistory(_question.questionId, jsonEncode(jsonList));
    } catch (_) {}
  }

  @override
  void onClose() {
    _currentSubscription?.cancel();
    _saveHistory();
    super.onClose();
  }
}
