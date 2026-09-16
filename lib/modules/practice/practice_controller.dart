import 'dart:math';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_model.dart';
import '../../data/models/study_record_model.dart';
import '../../data/services/question_filter_service.dart';
import '../home/home_controller.dart';

class PracticeController extends GetxController {
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
  final currentIndex = 0.obs;
  final correctCount = 0.obs;
  final selectedIndex = (-1).obs;
  final isAnswered = false.obs;
  final isCorrectAnswer = false.obs;
  final isLoading = true.obs;
  final subMode = 'sequential'.obs;
  final sheetName = ''.obs;
  final isFavorite = false.obs;
  final swipeMode = 'horizontal'.obs;

  late PageController verticalPageController;
  late PageController horizontalPageController;

  @override
  void onInit() {
    super.onInit();
    verticalPageController = PageController();
    horizontalPageController = PageController();
    final args = Get.arguments as Map<String, dynamic>?;
    if (args != null) {
      subMode.value = args['subMode'] ?? 'sequential';
      sheetName.value = args['sheetName'] ?? '';
    }
    _loadSwipeMode();
    loadQuestions();
  }

  Future<void> _loadSwipeMode() async {
    final prefs = await SharedPreferences.getInstance();
    swipeMode.value = prefs.getString('swipeMode') ?? 'horizontal';
  }

  Future<void> loadQuestions() async {
    isLoading.value = true;
    try {
      final excludeLongest = await QuestionFilterService.isAutoFilterEnabled();
      switch (subMode.value) {
        case 'random':
          final count = await _db.getQuestionCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
          final limit = min(count, 100);
          questions.value = await _db.getRandomQuestions(limit: limit, bankId: _bankId, excludeLongestAnswer: excludeLongest);
          break;
        case 'wrong':
          questions.value = await _db.getWrongQuestions(limit: 1000, bankId: _bankId, excludeLongestAnswer: excludeLongest);
          await _loadProgress();
          break;
        case 'favorite':
          questions.value = await _db.getFavoriteQuestions(limit: 1000, bankId: _bankId, excludeLongestAnswer: excludeLongest);
          await _loadProgress();
          break;
        case 'sequential':
        default:
          if (sheetName.value.isNotEmpty) {
            questions.value = await _db.getQuestionsBySheet(sheetName.value, limit: 10000, bankId: _bankId, excludeLongestAnswer: excludeLongest);
          } else {
            questions.value = await _db.getAllQuestions(limit: 10000, bankId: _bankId, excludeLongestAnswer: excludeLongest);
          }
          await _loadProgress();
          break;
      }
    } finally {
      isLoading.value = false;
      _updateFavoriteStatus();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (swipeMode.value == 'vertical' && verticalPageController.hasClients) {
          verticalPageController.jumpToPage(currentIndex.value);
        }
        if (swipeMode.value == 'horizontal' && horizontalPageController.hasClients) {
          horizontalPageController.jumpToPage(currentIndex.value);
        }
      });
    }
  }

  Future<void> _loadProgress() async {
    final progress = await _db.getProgress('practice', subMode.value, sheetName: sheetName.value.isEmpty ? null : sheetName.value, bankId: _bankId);
    if (progress != null) {
      currentIndex.value = progress['current_index'] as int? ?? 0;
      correctCount.value = progress['correct_count'] as int? ?? 0;
      if (currentIndex.value >= questions.length) {
        currentIndex.value = 0;
      }
    }
  }

  Question? get currentQuestion {
    if (questions.isEmpty || currentIndex.value >= questions.length) return null;
    return questions[currentIndex.value];
  }

  double get progress {
    if (questions.isEmpty) return 0;
    return (currentIndex.value + 1) / questions.length;
  }

  void selectOption(int index) {
    if (isAnswered.value) return;
    selectedIndex.value = index;
    isAnswered.value = true;

    final question = currentQuestion;
    if (question == null) return;

    final selectedLabel = question.optionLabels[index];
    isCorrectAnswer.value = selectedLabel == question.answer.toUpperCase();

    if (isCorrectAnswer.value) {
      correctCount.value++;
    }

    _saveAnswer(question, isCorrectAnswer.value);

    if (isCorrectAnswer.value) {
      Future.delayed(const Duration(milliseconds: 800), () {
        nextQuestion();
      });
    }
  }

  Future<void> _saveAnswer(Question question, bool correct) async {
    final record = await _db.getStudyRecord(question.questionId);
    final now = DateTime.now().toIso8601String();
    if (record != null) {
      record.practiceCount++;
      record.lastPracticeAt = now;
      record.isCorrect = correct ? 1 : 0;
      if (!correct) {
        record.isWrong = 1;
      } else {
        record.isWrong = 0;
      }
      await _db.upsertStudyRecord(record);
    } else {
      await _db.upsertStudyRecord(StudyRecord(
        questionId: question.questionId,
        isCorrect: correct ? 1 : 0,
        isWrong: correct ? 0 : 1,
        practiceCount: 1,
        lastPracticeAt: now,
      ));
    }
  }

  void nextQuestion() {
    if (currentIndex.value < questions.length - 1) {
      currentIndex.value++;
      selectedIndex.value = -1;
      isAnswered.value = false;
      isCorrectAnswer.value = false;
      _updateFavoriteStatus();
      _saveProgress();
      _animateToCurrentPage();
    }
  }

  void prevQuestion() {
    if (currentIndex.value > 0) {
      currentIndex.value--;
      selectedIndex.value = -1;
      isAnswered.value = false;
      isCorrectAnswer.value = false;
      _updateFavoriteStatus();
      _saveProgress();
      _animateToCurrentPage();
    }
  }

  void jumpToIndex(int index) {
    currentIndex.value = index;
    _updateFavoriteStatus();
    _saveProgress();
  }

  void jumpToIndexWithAnimation(int index) {
    currentIndex.value = index;
    _updateFavoriteStatus();
    _saveProgress();
    _animateToCurrentPage();
  }

  void onPageChanged(int index) {
    if (index != currentIndex.value) {
      currentIndex.value = index;
      selectedIndex.value = -1;
      isAnswered.value = false;
      isCorrectAnswer.value = false;
      _updateFavoriteStatus();
      _saveProgress();
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
    if (swipeMode.value == 'horizontal' && horizontalPageController.hasClients) {
      horizontalPageController.animateToPage(
        currentIndex.value,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> toggleFavorite() async {
    final question = currentQuestion;
    if (question == null) return;
    await _db.toggleFavorite(question.questionId);
    isFavorite.value = !isFavorite.value;
  }

  void _updateFavoriteStatus() async {
    final question = currentQuestion;
    if (question == null) return;
    final record = await _db.getStudyRecord(question.questionId);
    isFavorite.value = record?.isFavorited ?? false;
  }

  Future<void> _saveProgress() async {
    await _db.saveProgress(
      'practice',
      subMode.value,
      sheetName.value.isEmpty ? null : sheetName.value,
      currentIndex.value,
      questions.length,
      correctCount.value,
      bankId: _bankId,
    );
  }

  int getCorrectOptionIndex() {
    final question = currentQuestion;
    if (question == null) return -1;
    return question.optionLabels.indexOf(question.answer.toUpperCase());
  }

  @override
  void onClose() {
    verticalPageController.dispose();
    horizontalPageController.dispose();
    super.onClose();
  }
}
