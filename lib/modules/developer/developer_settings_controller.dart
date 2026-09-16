import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/database_helper.dart';

class DeveloperSettingsController extends GetxController {
  static const String _prefsKey = 'is_developer_mode';

  final isDeveloperMode = false.obs;
  final customSystemPrompt = ''.obs;
  final temperature = 0.7.obs;
  final maxTokens = 2000.obs;

  static const String defaultSystemPrompt = '''你是执照考试的专业辅导老师。请对以下题目进行详细解析。

题目信息：
- 题号：\${question_id}
- 题型：\${question_type}
- 题目：\${content}
- 选项：\${options}
- 参考答案：\${answer}

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

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    isDeveloperMode.value = prefs.getBool(_prefsKey) ?? false;

    if (isDeveloperMode.value) {
      final db = DatabaseHelper();
      final savedPrompt = await db.getDeveloperConfig('custom_system_prompt');
      customSystemPrompt.value = savedPrompt ?? defaultSystemPrompt;

      final savedTemp = await db.getDeveloperConfig('temperature');
      temperature.value = double.tryParse(savedTemp ?? '0.7') ?? 0.7;

      final savedTokens = await db.getDeveloperConfig('max_tokens');
      maxTokens.value = int.tryParse(savedTokens ?? '2000') ?? 2000;
    } else {
      customSystemPrompt.value = defaultSystemPrompt;
    }
  }

  Future<void> activateDeveloperMode() async {
    isDeveloperMode.value = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, true);
    await _loadSettings();
  }

  Future<void> deactivateDeveloperMode() async {
    isDeveloperMode.value = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, false);
  }

  Future<void> saveCustomSystemPrompt(String prompt) async {
    await DatabaseHelper().setDeveloperConfig('custom_system_prompt', prompt);
    customSystemPrompt.value = prompt;
  }

  Future<void> saveTemperature(double temp) async {
    await DatabaseHelper().setDeveloperConfig('temperature', temp.toString());
    temperature.value = temp;
  }

  Future<void> saveMaxTokens(int tokens) async {
    await DatabaseHelper().setDeveloperConfig('max_tokens', tokens.toString());
    maxTokens.value = tokens;
  }

  void resetToDefault() {
    customSystemPrompt.value = defaultSystemPrompt;
    temperature.value = 0.7;
    maxTokens.value = 2000;
    DatabaseHelper().setDeveloperConfig('custom_system_prompt', defaultSystemPrompt);
    DatabaseHelper().setDeveloperConfig('temperature', '0.7');
    DatabaseHelper().setDeveloperConfig('max_tokens', '2000');
  }
}
