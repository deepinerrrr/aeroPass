import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/annotation_model.dart';
import '../../data/models/note_model.dart';
import '../../data/models/question_model.dart';
import '../../data/services/question_filter_service.dart';
import '../home/home_controller.dart';

class MemorizeController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper();

  int? get _bankId {
    try {
      final id = Get.find<HomeController>().activeBankId.value;
      return id > 0 ? id : null;
    } catch (_) {
      return null;
    }
  }

  final questions = <Question>[].obs;
  final masteredQuestions = <Question>[].obs;
  final currentIndex = 0.obs;
  final isLoading = true.obs;
  final sheetName = ''.obs;
  final isMastered = false.obs;
  final isUpdatingMastered = false.obs;
  final masteredCount = 0.obs;
  final isFavorite = false.obs;
  final swipeMode = 'horizontal'.obs;

  /// 卡片显示样式：classic（标准，带答案横幅）/ clean（简洁，无答案横幅）
  final cardStyle = 'classic'.obs;

  /// 是否处于自由圈画标注模式
  final isAnnotating = false.obs;

  /// 每道题的标注（文字底色 + 圈画笔迹），按 questionId 缓存
  final annotations = <String, MemorizeAnnotation>{}.obs;

  final currentAnnotationColor = Rx<Color>(Colors.red);
  final currentAnnotationStrokeWidth = 3.0.obs;
  final List<Color> annotationColors = [
    Colors.red,
    Colors.orange,
    Colors.black87,
    Colors.blue,
    Colors.green,
    Colors.purple,
  ];
  final List<double> annotationStrokeWidths = [2.0, 4.0, 6.0];

  String? lastAnnotatedQuestionId;
  final Map<String, Timer> _annotationSaveTimers = {};
  List<Question> _allQuestions = const [];
  Map<String, int> _questionOrder = const {};

  List<Question> get allScopedQuestions => List.unmodifiable(_allQuestions);

  late PageController verticalPageController;
  late PageController horizontalPageController;

  @override
  void onInit() {
    super.onInit();
    verticalPageController = PageController();
    horizontalPageController = PageController();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      sheetName.value = args['sheetName'] ?? '';
    }
    _loadSwipeMode();
    _loadCardStyle();
    loadQuestions();
  }

  Future<void> _loadSwipeMode() async {
    final prefs = await SharedPreferences.getInstance();
    swipeMode.value = prefs.getString('swipeMode') ?? 'horizontal';
  }

  Future<void> _loadCardStyle() async {
    final prefs = await SharedPreferences.getInstance();
    cardStyle.value = prefs.getString('memorizeCardStyle') ?? 'classic';
  }

  Future<void> setCardStyle(String style) async {
    cardStyle.value = style;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('memorizeCardStyle', style);
  }

  void toggleAnnotating() => isAnnotating.toggle();

  Future<void> loadQuestions() async {
    isLoading.value = true;
    try {
      final excludeLongest = await QuestionFilterService.isAutoFilterEnabled();
      final List<Question> loadedQuestions;
      if (sheetName.value.isNotEmpty) {
        loadedQuestions = await _db.getQuestionsBySheet(
          sheetName.value,
          limit: 10000,
          bankId: _bankId,
          excludeLongestAnswer: excludeLongest,
        );
      } else {
        loadedQuestions = await _db.getAllQuestions(
          limit: 10000,
          bankId: _bankId,
          excludeLongestAnswer: excludeLongest,
        );
      }

      _allQuestions = loadedQuestions;
      _questionOrder = {
        for (var index = 0; index < loadedQuestions.length; index++)
          loadedQuestions[index].questionId: index,
      };
      final masteredIds = await _db.getMasteredQuestionIds(
        loadedQuestions.map((question) => question.questionId).toList(),
      );
      questions.assignAll(
        loadedQuestions.where(
          (question) => !masteredIds.contains(question.questionId),
        ),
      );
      masteredQuestions.assignAll(
        loadedQuestions.where(
          (question) => masteredIds.contains(question.questionId),
        ),
      );
      masteredCount.value = masteredQuestions.length;
      await _loadProgress();
    } finally {
      isLoading.value = false;
      _updateMasteredStatus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (swipeMode.value == 'vertical' &&
            verticalPageController.hasClients) {
          verticalPageController.jumpToPage(currentIndex.value);
        }
        if (swipeMode.value == 'horizontal' &&
            horizontalPageController.hasClients) {
          horizontalPageController.jumpToPage(currentIndex.value);
        }
      });
    }
  }

  Future<void> _loadProgress() async {
    final progress = await _db.getProgress(
      'memorize',
      'sequential',
      sheetName: sheetName.value.isEmpty ? null : sheetName.value,
      bankId: _bankId,
    );
    if (progress != null) {
      currentIndex.value = progress['current_index'] as int? ?? 0;
      if (currentIndex.value >= questions.length) {
        currentIndex.value = 0;
      }
    }
  }

  Question? get currentQuestion {
    if (questions.isEmpty || currentIndex.value >= questions.length) {
      return null;
    }
    return questions[currentIndex.value];
  }

  double get progress {
    if (questions.isEmpty) return 0;
    return (currentIndex.value + 1) / questions.length;
  }

  void nextQuestion() {
    if (currentIndex.value < questions.length - 1) {
      currentIndex.value++;
      _updateMasteredStatus();
      _saveProgress();
      _animateToCurrentPage();
    }
  }

  void prevQuestion() {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      _updateMasteredStatus();
      _saveProgress();
      _animateToCurrentPage();
    }
  }

  void _animateToCurrentPage() {
    if (swipeMode.value == 'vertical' && verticalPageController.hasClients) {
      verticalPageController.animateToPage(
        currentIndex.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    if (swipeMode.value == 'horizontal' &&
        horizontalPageController.hasClients) {
      horizontalPageController.animateToPage(
        currentIndex.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void jumpToIndex(int index) {
    if (index < 0 || index >= questions.length) return;
    currentIndex.value = index;
    _updateMasteredStatus();
    _saveProgress();
  }

  void jumpToIndexWithAnimation(int index) {
    if (index < 0 || index >= questions.length) return;
    currentIndex.value = index;
    _updateMasteredStatus();
    _saveProgress();
    _animateToCurrentPage();
  }

  Future<void> toggleMastered() async {
    if (isUpdatingMastered.value) return;
    final question = currentQuestion;
    if (question == null) return;
    isUpdatingMastered.value = true;
    try {
      await _db.setMastered(question.questionId, true);
      final removedIndex = questions.indexWhere(
        (item) => item.questionId == question.questionId,
      );
      if (removedIndex < 0) return;
      questions.removeAt(removedIndex);
      masteredQuestions.add(question);
      _sortByOriginalOrder(masteredQuestions);
      masteredCount.value = masteredQuestions.length;

      if (questions.isEmpty) {
        currentIndex.value = 0;
        isMastered.value = false;
        isFavorite.value = false;
      } else {
        currentIndex.value = removedIndex.clamp(0, questions.length - 1);
        await _updateMasteredStatus();
        _syncPageController();
      }
      await _saveProgress();
    } finally {
      isUpdatingMastered.value = false;
    }
  }

  Future<void> restoreMasteredQuestion(Question question) async {
    if (isUpdatingMastered.value) return;
    isUpdatingMastered.value = true;
    try {
      await _db.setMastered(question.questionId, false);
      masteredQuestions.removeWhere(
        (item) => item.questionId == question.questionId,
      );

      final currentQuestionId = currentQuestion?.questionId;
      if (!questions.any((item) => item.questionId == question.questionId)) {
        questions.add(question);
        _sortByOriginalOrder(questions);
      }
      if (currentQuestionId != null) {
        final preservedIndex = questions.indexWhere(
          (item) => item.questionId == currentQuestionId,
        );
        currentIndex.value = preservedIndex < 0 ? 0 : preservedIndex;
      } else {
        currentIndex.value = questions.indexWhere(
          (item) => item.questionId == question.questionId,
        );
      }
      masteredCount.value = masteredQuestions.length;
      await _updateMasteredStatus();
      _syncPageController();
      await _saveProgress();
    } finally {
      isUpdatingMastered.value = false;
    }
  }

  Future<void> toggleFavorite() async {
    final question = currentQuestion;
    if (question == null) return;
    await _db.toggleFavorite(question.questionId);
    isFavorite.value = !isFavorite.value;
  }

  Future<void> _updateMasteredStatus() async {
    final question = currentQuestion;
    if (question == null) {
      isMastered.value = false;
      isFavorite.value = false;
      return;
    }
    final record = await _db.getStudyRecord(question.questionId);
    if (currentQuestion?.questionId != question.questionId) return;
    isMastered.value = record?.isMasteredFlag ?? false;
    isFavorite.value = record?.isFavorited ?? false;
  }

  void _sortByOriginalOrder(RxList<Question> list) {
    list.sort(
      (a, b) => (_questionOrder[a.questionId] ?? 0).compareTo(
        _questionOrder[b.questionId] ?? 0,
      ),
    );
  }

  void _syncPageController() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (questions.isEmpty) return;
      if (swipeMode.value == 'vertical' && verticalPageController.hasClients) {
        verticalPageController.jumpToPage(currentIndex.value);
      }
      if (swipeMode.value == 'horizontal' &&
          horizontalPageController.hasClients) {
        horizontalPageController.jumpToPage(currentIndex.value);
      }
    });
  }

  Future<void> _saveProgress() async {
    await _db.saveProgress(
      'memorize',
      'sequential',
      sheetName.value.isEmpty ? null : sheetName.value,
      currentIndex.value,
      questions.length,
      0,
      bankId: _bankId,
    );
  }

  void onSwipeNext() {
    nextQuestion();
  }

  void onSwipePrev() {
    prevQuestion();
  }

  // ============ 背题标注 ============

  MemorizeAnnotation _annotationOf(String questionId) {
    return annotations.putIfAbsent(
      questionId,
      () => MemorizeAnnotation(questionId: questionId),
    );
  }

  List<HandwritingStroke> strokesFor(String questionId) =>
      annotations[questionId]?.strokes ?? const [];

  List<TextHighlight> highlightsFor(String questionId) =>
      annotations[questionId]?.highlights ?? const [];

  /// 懒加载某道题的标注，加载完成后自动刷新界面。
  Future<void> ensureAnnotationLoaded(String questionId) async {
    if (annotations.containsKey(questionId)) return;
    try {
      final ann = await _db.getMemorizeAnnotation(questionId);
      if (!annotations.containsKey(questionId)) {
        annotations[questionId] =
            ann ?? MemorizeAnnotation(questionId: questionId);
      }
    } catch (_) {}
  }

  void addAnnotationStroke(String questionId, List<StrokePoint> points) {
    if (points.isEmpty) return;
    lastAnnotatedQuestionId = questionId;
    final ann = _annotationOf(questionId);
    ann.strokes.add(
      HandwritingStroke(
        points: points,
        color: _colorToHex(currentAnnotationColor.value),
        strokeWidth: currentAnnotationStrokeWidth.value,
      ),
    );
    annotations.refresh();
    _scheduleAnnotationSave(questionId);
  }

  void undoAnnotationStroke(String questionId) {
    final ann = annotations[questionId];
    if (ann == null || ann.strokes.isEmpty) return;
    ann.strokes.removeLast();
    annotations.refresh();
    _scheduleAnnotationSave(questionId);
  }

  void clearAnnotationStrokes(String questionId) {
    final ann = annotations[questionId];
    if (ann == null || ann.strokes.isEmpty) return;
    ann.strokes.clear();
    annotations.refresh();
    _scheduleAnnotationSave(questionId);
  }

  void addHighlight(String questionId, int start, int end) {
    if (end <= start) return;
    lastAnnotatedQuestionId = questionId;
    final ann = _annotationOf(questionId);
    ann.highlights.removeWhere((h) => h.overlaps(start, end));
    ann.highlights.add(TextHighlight(start: start, end: end));
    annotations.refresh();
    _scheduleAnnotationSave(questionId);
  }

  void removeHighlights(String questionId, int start, int end) {
    final ann = annotations[questionId];
    if (ann == null) return;
    ann.highlights.removeWhere((h) => h.overlaps(start, end));
    annotations.refresh();
    _scheduleAnnotationSave(questionId);
  }

  String get undoTargetQuestionId =>
      lastAnnotatedQuestionId ?? currentQuestion?.questionId ?? '';

  void setAnnotationColor(Color color) => currentAnnotationColor.value = color;

  void setAnnotationStrokeWidth(double width) =>
      currentAnnotationStrokeWidth.value = width;

  void _scheduleAnnotationSave(String questionId) {
    _annotationSaveTimers[questionId]?.cancel();
    _annotationSaveTimers[questionId] = Timer(
      const Duration(milliseconds: 600),
      () {
        _annotationSaveTimers.remove(questionId);
        final ann = annotations[questionId];
        if (ann != null) _db.saveMemorizeAnnotation(ann);
      },
    );
  }

  String _colorToHex(Color color) =>
      '#${color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2)}';

  @override
  void onClose() {
    // 立即保存尚未落库的标注
    for (final timer in _annotationSaveTimers.values) {
      timer.cancel();
    }
    _annotationSaveTimers.clear();
    for (final ann in annotations.values) {
      _db.saveMemorizeAnnotation(ann);
    }
    verticalPageController.dispose();
    horizontalPageController.dispose();
    super.onClose();
  }
}
