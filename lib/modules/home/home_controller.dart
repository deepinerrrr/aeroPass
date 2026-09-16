import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/database_helper.dart';
import '../../data/services/import_service.dart';
import '../../data/services/ai_service.dart';
import '../../data/services/question_filter_service.dart';
import '../../core/theme/app_theme.dart';

class HomeController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper();
  final ImportService _importService = ImportService();

  final totalQuestions = 0.obs;
  final practicedCount = 0.obs;
  final correctCount = 0.obs;
  final wrongCount = 0.obs;
  final favoriteCount = 0.obs;
  final isImporting = false.obs;
  final importMessage = ''.obs;
  final isImported = false.obs;
  final sheetNames = <String>[].obs;
  final lastExamScore = (-1.0).obs;
  final lastExamCorrect = 0.obs;
  final lastExamTotal = 0.obs;
  final nickname = ''.obs;
  final avatarPath = ''.obs;

  final activeBankId = 0.obs;
  final activeBankName = ''.obs;

  @override
  void onInit() {
    super.onInit();
    _initialize();
  }

  Future<void> _initialize() async {
    await _loadUserProfile();
    await _loadActiveBank();
    await _deduplicateIfNeeded();
    await loadStats();
    if (totalQuestions.value == 0) {
      await importFromAsset();
    }
  }

  /// 静默执行题库去重，防止用户重复刷到一样的题目。
  Future<void> _deduplicateIfNeeded() async {
    try {
      final bankId = activeBankId.value > 0 ? activeBankId.value : null;
      final removed = await _db.deduplicateQuestions(bankId: bankId);
      if (removed > 0) {
        print('题库去重：移除 $removed 道重复题目');
      }
    } catch (e) {
      print('题库去重失败: $e');
    }
  }

  Future<void> _loadUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    nickname.value = prefs.getString('nickname') ?? '';
    avatarPath.value = prefs.getString('avatarPath') ?? '';
  }

  Future<void> _loadActiveBank() async {
    final bank = await _db.getActiveBank();
    if (bank != null) {
      activeBankId.value = bank.id!;
      activeBankName.value = bank.name;
    } else {
      activeBankId.value = 0;
      activeBankName.value = '';
    }
  }

  Future<void> setNickname(String name) async {
    nickname.value = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', name);
  }

  Future<void> setAvatarPath(String path) async {
    avatarPath.value = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatarPath', path);
  }

  Future<void> loadStats() async {
    final bankId = activeBankId.value > 0 ? activeBankId.value : null;
    final excludeLongest = await QuestionFilterService.isAutoFilterEnabled();
    totalQuestions.value = await _db.getQuestionCount(bankId: bankId, excludeLongestAnswer: excludeLongest);
    practicedCount.value = await _db.getPracticedCount(bankId: bankId, excludeLongestAnswer: excludeLongest);
    correctCount.value = await _db.getCorrectCount(bankId: bankId, excludeLongestAnswer: excludeLongest);
    wrongCount.value = await _db.getWrongQuestionCount(bankId: bankId, excludeLongestAnswer: excludeLongest);
    favoriteCount.value = await _db.getFavoriteQuestionCount(bankId: bankId, excludeLongestAnswer: excludeLongest);
    isImported.value = totalQuestions.value > 0;
    if (isImported.value) {
      sheetNames.value = await _db.getSheetNames(bankId: bankId);
    }
    await _loadLastExamResult();
  }



  Future<void> _loadLastExamResult() async {
    final prefs = await SharedPreferences.getInstance();
    lastExamScore.value = prefs.getDouble('lastExamScore') ?? -1.0;
    lastExamCorrect.value = prefs.getInt('lastExamCorrect') ?? 0;
    lastExamTotal.value = prefs.getInt('lastExamTotal') ?? 0;
  }

  Future<void> saveExamResult(double score, int correct, int total) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lastExamScore', score);
    await prefs.setInt('lastExamCorrect', correct);
    await prefs.setInt('lastExamTotal', total);
    lastExamScore.value = score;
    lastExamCorrect.value = correct;
    lastExamTotal.value = total;
  }

  double get correctRate {
    if (practicedCount.value == 0) return 0;
    return correctCount.value / practicedCount.value * 100;
  }

  Future<void> importFromAsset() async {
    isImporting.value = true;
    importMessage.value = '正在导入题库...';
    try {
      final result = await _importService.importFromAsset();
      importMessage.value = result.message;
      if (result.success) {
        isImported.value = true;
        await _loadActiveBank();
        await _deduplicateIfNeeded();
        await loadStats();
        Get.snackbar('导入成功', result.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
            duration: const Duration(seconds: 2));
      } else {
        isImported.value = false;
        Get.snackbar('导入失败', result.message,
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.red,
            colorText: Colors.white,
            duration: const Duration(seconds: 3));
      }
    } catch (e) {
      importMessage.value = '导入失败: $e';
      isImported.value = false;
      Get.snackbar('导入异常', '$e',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3));
    } finally {
      isImporting.value = false;
    }
  }

  Future<void> switchBank(int bankId) async {
    if (bankId > 0) {
      await _db.setActiveBank(bankId);
    }
    await _loadActiveBank();
    await loadStats();
  }
}

class ThemeColorOption {
  final String name;
  final Color color;
  final String key;
  final List<Color> complementaryColors;

  const ThemeColorOption({
    required this.name,
    required this.color,
    required this.key,
    this.complementaryColors = const [],
  });
}

class SettingsController extends GetxController {
  final isDarkMode = false.obs;
  final swipeMode = 'horizontal'.obs;
  final themeColorKey = 'bu_jiao_lv'.obs;
  final nickname = ''.obs;
  final avatarPath = ''.obs;
  final currentAiModel = 'qwen'.obs;
  final qwenApiKey = ''.obs;
  final deepseekApiKey = ''.obs;
  final isThemeExpanded = false.obs;

  static const List<ThemeColorOption> themeColors = [
    ThemeColorOption(
      name: '不焦绿',
      color: Color(0xFF566C44),
      key: 'bu_jiao_lv',
      complementaryColors: [Color(0xFF7E9966), Color(0xFF969571), Color(0xFFC8C7A7), Color(0xFFDAE2BC)],
    ),
    ThemeColorOption(
      name: '绝绝紫',
      color: Color(0xFF6C4D7E),
      key: 'jue_jue_zi',
      complementaryColors: [Color(0xFFB384BC), Color(0xFFECD9CB), Color(0xFFA9D1D9), Color(0xFFD4C8A8)],
    ),
    ThemeColorOption(
      name: '不摆烂',
      color: Color(0xFF325969),
      key: 'bu_bai_lan',
      complementaryColors: [Color(0xFF6B8FA7), Color(0xFF9BB89A), Color(0xFFF2CDB4), Color(0xFFDDC7DC)],
    ),
    ThemeColorOption(
      name: '糖太棕',
      color: Color(0xFF856441),
      key: 'tang_tai_zong',
      complementaryColors: [Color(0xFFF1C883), Color(0xFF9ACAE0), Color(0xFFECDBD6), Color(0xFFEDB7A0)],
    ),
    ThemeColorOption(
      name: '放青松',
      color: Color(0xFF518463),
      key: 'fang_qing_song',
      complementaryColors: [Color(0xFFA7B3B2), Color(0xFFCEE2E0), Color(0xFFD2C8AC), Color(0xFFCEEB83)],
    ),
    ThemeColorOption(
      name: '发财红',
      color: Color(0xFFCC4968),
      key: 'fa_cai_hong',
      complementaryColors: [Color(0xFFEAB1B6), Color(0xFFF4796A), Color(0xFFD2C86C), Color(0xFFE2B2D2)],
    ),
  ];

  @override
  void onInit() {
    super.onInit();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    isDarkMode.value = prefs.getBool('isDarkMode') ?? false;
    swipeMode.value = prefs.getString('swipeMode') ?? 'horizontal';
    themeColorKey.value = prefs.getString('themeColorKey') ?? 'bu_jiao_lv';
    nickname.value = prefs.getString('nickname') ?? '';
    avatarPath.value = prefs.getString('avatarPath') ?? '';
    currentAiModel.value = prefs.getString('currentAiModel') ?? 'qwen';
    qwenApiKey.value = prefs.getString('qwen_api_key') ?? AiService.getDefaultApiKey(AiModelType.qwen);
    deepseekApiKey.value = prefs.getString('deepseek_api_key') ?? AiService.getDefaultApiKey(AiModelType.deepseek);
    _applyTheme();
  }

  Future<void> toggleDarkMode() async {
    isDarkMode.value = !isDarkMode.value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkMode', isDarkMode.value);
    _applyTheme();
  }

  Future<void> setSwipeMode(String mode) async {
    swipeMode.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('swipeMode', mode);
  }

  Future<void> setThemeColor(String key) async {
    themeColorKey.value = key;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeColorKey', key);
    _applyTheme();
  }

  void toggleThemeExpanded() {
    isThemeExpanded.value = !isThemeExpanded.value;
  }

  Future<void> setNickname(String name) async {
    nickname.value = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('nickname', name);
    final homeController = Get.find<HomeController>();
    homeController.nickname.value = name;
  }

  Future<void> setAvatarPath(String path) async {
    avatarPath.value = path;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('avatarPath', path);
    final homeController = Get.find<HomeController>();
    homeController.avatarPath.value = path;
  }

  void _applyTheme() {
    final option = themeColors.firstWhere(
      (e) => e.key == themeColorKey.value,
      orElse: () => themeColors.first,
    );
    final brightness = isDarkMode.value ? Brightness.dark : Brightness.light;
    final theme = AppTheme.createTheme(option.color, brightness);
    Get.changeTheme(theme);
    Get.changeThemeMode(isDarkMode.value ? ThemeMode.dark : ThemeMode.light);
  }

  ThemeColorOption get currentThemeColor => themeColors.firstWhere(
    (e) => e.key == themeColorKey.value,
    orElse: () => themeColors.first,
  );

  AiModelType get currentAiModelType =>
      currentAiModel.value == 'deepseek' ? AiModelType.deepseek : AiModelType.qwen;

  Future<void> setCurrentAiModel(String model) async {
    currentAiModel.value = model;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('currentAiModel', model);
  }

  Future<void> setQwenApiKey(String key) async {
    qwenApiKey.value = key;
    await AiService.setApiKey(AiModelType.qwen, key);
  }

  Future<void> setDeepseekApiKey(String key) async {
    deepseekApiKey.value = key;
    await AiService.setApiKey(AiModelType.deepseek, key);
  }
}
