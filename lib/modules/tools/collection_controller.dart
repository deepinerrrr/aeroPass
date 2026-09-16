import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_model.dart';
import 'collection_mind_map_controller.dart';

class CollectionController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper();

  final collections = <CollectionInfo>[].obs;
  final searchQuery = ''.obs;
  final isLoading = false.obs;
  final correctJudgeCount = 0.obs;
  final wrongJudgeCount = 0.obs;
  final syncingJudgeAnswer = RxnBool();
  final deletingKeyword = RxnString();

  @override
  void onInit() {
    super.onInit();
    loadCollections();
  }

  Future<void> loadCollections() async {
    isLoading.value = true;
    try {
      final results = await Future.wait([
        _db.getCollectionKeywords(),
        _db.getDefaultJudgeAnswerCounts(),
      ]);
      collections.value = results[0] as List<CollectionInfo>;
      final counts = results[1] as Map<bool, int>;
      correctJudgeCount.value = counts[true] ?? 0;
      wrongJudgeCount.value = counts[false] ?? 0;
    } finally {
      isLoading.value = false;
    }
  }

  /// 按合集名称模糊过滤（忽略大小写），搜索词为空时返回全部合集。
  List<CollectionInfo> get filteredCollections {
    final query = searchQuery.value.trim().toLowerCase();
    if (query.isEmpty) return collections;
    return collections
        .where((collection) => collection.keyword.toLowerCase().contains(query))
        .toList();
  }

  int collectionCountFor(bool answerIsCorrect) {
    final keyword = answerIsCorrect
        ? DatabaseHelper.defaultJudgeCorrectCollection
        : DatabaseHelper.defaultJudgeWrongCollection;
    return collections
            .where((collection) => collection.keyword == keyword)
            .firstOrNull
            ?.questionCount ??
        0;
  }

  Future<void> createJudgeCollection(bool answerIsCorrect) async {
    if (syncingJudgeAnswer.value != null) return;
    final available = answerIsCorrect
        ? correctJudgeCount.value
        : wrongJudgeCount.value;
    if (available == 0) {
      Get.snackbar(
        '暂无可收录题目',
        answerIsCorrect ? '默认题库中没有答案为正确的判断题' : '默认题库中没有答案为错误的判断题',
        snackPosition: SnackPosition.BOTTOM,
      );
      return;
    }

    syncingJudgeAnswer.value = answerIsCorrect;
    try {
      final count = await _db.syncDefaultJudgeCollection(
        answerIsCorrect: answerIsCorrect,
      );
      await loadCollections();
      final label = answerIsCorrect ? '答案正确' : '答案错误';
      Get.snackbar(
        '合集已创建',
        '已将默认题库中 $count 道$label的判断题收录到合集',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } catch (error) {
      Get.snackbar(
        '创建失败',
        '未能创建判断题合集，请稍后重试',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      syncingJudgeAnswer.value = null;
    }
  }

  Future<bool> deleteCollection(String keyword) async {
    if (deletingKeyword.value != null) return false;
    deletingKeyword.value = keyword;
    try {
      await _db.deleteCollectionByKeyword(keyword);
      await CollectionMindMapController.clearSavedMindMap(keyword);
      await loadCollections();
      Get.snackbar(
        '合集已删除',
        '“$keyword”已从合集列表移除，题库原题和学习记录均已保留',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
      return true;
    } catch (_) {
      Get.snackbar(
        '删除失败',
        '未能删除该合集，请稍后重试',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      return false;
    } finally {
      deletingKeyword.value = null;
    }
  }
}

class CollectionDetailController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper();

  final questions = <Question>[].obs;
  final isLoading = true.obs;
  final keyword = ''.obs;
  final currentIndex = 0.obs;
  final swipeMode = 'horizontal'.obs;

  late PageController pageController;

  @override
  void onInit() {
    super.onInit();
    pageController = PageController();
    final arg = Get.arguments;
    if (arg is String) {
      keyword.value = arg;
      _loadSwipeMode();
      loadQuestions();
    } else {
      isLoading.value = false;
    }
  }

  Future<void> _loadSwipeMode() async {
    final prefs = await SharedPreferences.getInstance();
    swipeMode.value = prefs.getString('swipeMode') ?? 'horizontal';
  }

  Future<void> loadQuestions() async {
    if (keyword.value.isEmpty) return;
    isLoading.value = true;
    try {
      questions.value = await _db.getQuestionsByCollectionKeyword(
        keyword.value,
      );
    } finally {
      isLoading.value = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (pageController.hasClients) {
          pageController.jumpToPage(currentIndex.value);
        }
      });
    }
  }

  Question? get currentQuestion {
    if (questions.isEmpty || currentIndex.value >= questions.length) {
      return null;
    }
    return questions[currentIndex.value];
  }

  void nextQuestion() {
    if (currentIndex.value < questions.length - 1) {
      currentIndex.value++;
      _animateToCurrentPage();
    }
  }

  void prevQuestion() {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      _animateToCurrentPage();
    }
  }

  void jumpToIndex(int index) {
    if (index < 0 || index >= questions.length) return;
    currentIndex.value = index;
  }

  void jumpToIndexWithAnimation(int index) {
    if (index < 0 || index >= questions.length) return;
    currentIndex.value = index;
    _animateToCurrentPage();
  }

  void _animateToCurrentPage() {
    if (pageController.hasClients) {
      pageController.animateToPage(
        currentIndex.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  void onClose() {
    pageController.dispose();
    super.onClose();
  }
}
