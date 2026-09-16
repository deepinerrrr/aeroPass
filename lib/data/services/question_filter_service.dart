import 'package:shared_preferences/shared_preferences.dart';

/// 题库高级筛选服务：管理“隐藏正确答案为最长选项的题目”开关。
class QuestionFilterService {
  static const String _autoFilterKey = 'auto_filter_longest_answer';

  /// 当前是否开启了“自动隐藏答案最长题”。
  static Future<bool> isAutoFilterEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoFilterKey) ?? false;
  }

  /// 设置开关状态。
  static Future<void> setAutoFilterEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoFilterKey, enabled);
  }
}
