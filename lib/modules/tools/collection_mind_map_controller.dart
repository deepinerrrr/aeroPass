import 'dart:convert';

import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/question_model.dart';
import '../../data/services/ai_service.dart';

class MindMapBranch {
  final String title;
  final List<String> children;

  const MindMapBranch({required this.title, required this.children});

  Map<String, dynamic> toJson() => {'title': title, 'children': children};

  factory MindMapBranch.fromJson(Map<String, dynamic> json) {
    return MindMapBranch(
      title: json['title'] is String ? json['title'] as String : '',
      children: (json['children'] as List? ?? const [])
          .whereType<String>()
          .toList(),
    );
  }
}

class CollectionMindMap {
  final String title;
  final List<MindMapBranch> branches;

  const CollectionMindMap({required this.title, required this.branches});

  Map<String, dynamic> toJson() => {
        'title': title,
        'branches': branches.map((branch) => branch.toJson()).toList(),
      };

  static CollectionMindMap? fromJson(dynamic decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final title = decoded['title'];
    final rawBranches = decoded['branches'];
    if (title is! String || rawBranches is! List) return null;
    final branches = rawBranches
        .whereType<Map>()
        .map((branch) => MindMapBranch.fromJson(Map<String, dynamic>.from(branch)))
        .where((branch) => branch.title.isNotEmpty)
        .toList();
    if (branches.isEmpty) return null;
    return CollectionMindMap(title: title, branches: branches);
  }
}

/// Turns a collection into a compact, display-safe mind map using the app's
/// selected AI model. The map intentionally uses a small fixed depth so it
/// remains readable on a phone while still being useful when zoomed out.
class CollectionMindMapController extends GetxController {
  CollectionMindMapController({required this.keyword, required this.questions});

  /// 每个合集持久化一份导图，key 以合集名称区分。
  static const _storagePrefix = 'collectionMindMap:';

  final String keyword;
  final List<Question> questions;
  final AiService _aiService = AiService();

  final mindMap = Rxn<CollectionMindMap>();
  final isGenerating = false.obs;
  final errorMessage = ''.obs;
  final rawResponse = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _restoreOrGenerate();
  }

  /// 优先加载上次生成的持久化导图；没有缓存或缓存损坏时才自动生成。
  /// 用户手动点击“重新生成”会覆盖缓存。
  Future<void> _restoreOrGenerate() async {
    final restored = await loadSavedMindMap(keyword);
    if (restored != null) {
      mindMap.value = restored;
      return;
    }
    await generate();
  }

  static String storageKeyFor(String keyword) => '$_storagePrefix$keyword';

  /// 读取某个合集的持久化导图，不存在或解析失败时返回 null。
  static Future<CollectionMindMap?> loadSavedMindMap(String keyword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(storageKeyFor(keyword));
      if (saved == null || saved.isEmpty) return null;
      return CollectionMindMap.fromJson(jsonDecode(saved));
    } catch (_) {
      return null;
    }
  }

  /// 删除合集时同步清理其持久化导图。
  static Future<void> clearSavedMindMap(String keyword) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(storageKeyFor(keyword));
    } catch (_) {
      // 清理失败不影响主流程。
    }
  }

  Future<void> _persistMindMap(CollectionMindMap map) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(storageKeyFor(keyword), jsonEncode(map.toJson()));
    } catch (_) {
      // 持久化失败不阻断当前展示。
    }
  }

  Future<void> generate() async {
    if (isGenerating.value) return;
    isGenerating.value = true;
    errorMessage.value = '';
    rawResponse.value = '';
    mindMap.value = null;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedModel = prefs.getString('currentAiModel') ?? 'qwen';
      final modelType = savedModel == 'deepseek'
          ? AiModelType.deepseek
          : AiModelType.qwen;

      await for (final chunk in _aiService.chatStream(
        modelType: modelType,
        messages: [
          {
            'role': 'system',
            'content': '''你是执照考试题库的知识架构师。请把同一合集的题目归纳为简洁的知识思维导图，只梳理题目涉及的核心知识点。
只能输出一个合法 JSON 对象，不要 Markdown、解释或代码块。JSON 格式必须严格为：
{"title":"合集核心知识","nodes":[{"title":"一级知识点","children":["核心规则","必要条件或结论"]}]}
要求：title 不超过 16 字；提炼 2 到 5 个一级知识点；每个一级知识点最多 2 个简短 children；相同知识合并，能用短语就不用长句；只保留定义、规则、条件、数值和结论；不要整理易错点、误区、陷阱、答题技巧或题目复述；不要引用或推断任何题目编号；不得杜撰题目中没有的信息。''',
          },
          {'role': 'user', 'content': buildQuestionContext(keyword, questions)},
        ],
      )) {
        rawResponse.value += chunk;
      }

      final map = parseMindMap(rawResponse.value, fallbackTitle: keyword);
      if (map == null) {
        throw const FormatException('AI 返回的导图格式无法识别');
      }
      mindMap.value = map;
      await _persistMindMap(map);
    } catch (error) {
      errorMessage.value = _friendlyError(error);
    } finally {
      isGenerating.value = false;
    }
  }

  /// Builds the AI input without including the database/display question ID.
  /// Numeric facts inside the stem and answers remain intact because they are
  /// part of the knowledge that the mind map must analyze.
  static String buildQuestionContext(String keyword, List<Question> questions) {
    final buffer = StringBuffer('合集名称：$keyword\n题目数量：${questions.length}\n\n');
    for (final question in questions) {
      buffer
        ..writeln('题型：${question.isJudge ? '判断题' : '单选题'}')
        ..writeln('题干：${_shorten(question.content, 460)}')
        ..writeln(
          '正确答案：${question.answer}${question.correctOptionText.isEmpty ? '' : '（${_shorten(question.correctOptionText, 160)}）'}',
        );
      if (question.referenceAnswer?.trim().isNotEmpty ?? false) {
        buffer.writeln('解析：${_shorten(question.referenceAnswer!.trim(), 280)}');
      }
      buffer.writeln('---');
    }
    return buffer.toString();
  }

  static CollectionMindMap? parseMindMap(
    String response, {
    required String fallbackTitle,
  }) {
    final jsonText = _extractJsonObject(response);
    if (jsonText == null) return null;

    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is! Map<String, dynamic>) return null;
      final rawNodes = decoded['nodes'];
      if (rawNodes is! List) return null;

      final branches = rawNodes
          .whereType<Map>()
          .map((node) {
            final title = _cleanLabel(node['title']);
            final children =
                (node['children'] is List ? node['children'] as List : const [])
                    .map(_cleanLabel)
                    .where(
                      (label) =>
                          label.isNotEmpty && !_isNonKnowledgeLabel(label),
                    )
                    .take(2)
                    .toList();
            return title.isEmpty || _isNonKnowledgeLabel(title)
                ? null
                : MindMapBranch(title: title, children: children);
          })
          .whereType<MindMapBranch>()
          .take(5)
          .toList();

      if (branches.isEmpty) return null;
      final title = _cleanLabel(decoded['title']);
      return CollectionMindMap(
        title: title.isEmpty ? fallbackTitle : title,
        branches: branches,
      );
    } catch (_) {
      return null;
    }
  }

  static String? _extractJsonObject(String response) {
    final fenced = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(response);
    final candidate = (fenced?.group(1) ?? response).trim();
    final start = candidate.indexOf('{');
    final end = candidate.lastIndexOf('}');
    if (start < 0 || end <= start) return null;
    return candidate.substring(start, end + 1);
  }

  static String _cleanLabel(Object? value) {
    if (value is! String) return '';
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= 42
        ? normalized
        : '${normalized.substring(0, 42)}…';
  }

  static bool _isNonKnowledgeLabel(String label) {
    return RegExp(r'易错|误区|陷阱|答题技巧|解题技巧|常见错误|容易混淆|易混淆').hasMatch(label);
  }

  String _friendlyError(Object error) {
    final message = error.toString();
    if (message.contains('401') || message.contains('403')) {
      return 'AI 服务鉴权失败，请前往设置检查当前模型的 API Key。';
    }
    if (message.contains('FormatException')) {
      return 'AI 返回的导图格式无法识别，请重新生成。';
    }
    return '导图生成失败，请检查网络或 AI 配置后重试。';
  }

  static String _shorten(String text, int maxLength) {
    final normalized = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    return normalized.length <= maxLength
        ? normalized
        : '${normalized.substring(0, maxLength)}…';
  }
}
