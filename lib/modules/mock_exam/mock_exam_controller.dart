import 'dart:math';
import 'package:get/get.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_model.dart';
import '../../data/models/study_record_model.dart';
import '../../data/services/question_filter_service.dart';
import '../home/home_controller.dart';

class MockExamController extends GetxController {
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
  final isExamFinished = false.obs;
  final isFavorite = false.obs;

  static const int examQuestionCount = 300;

  @override
  void onInit() {
    super.onInit();
    loadQuestions();
  }

  Future<void> loadQuestions() async {
    isLoading.value = true;
    try {
      final excludeLongest = await QuestionFilterService.isAutoFilterEnabled();
      final totalCount = await _db.getQuestionCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
      final limit = min(totalCount, examQuestionCount);
      questions.value = await _db.getRandomQuestions(limit: limit, bankId: _bankId, excludeLongestAnswer: excludeLongest);
    } finally {
      isLoading.value = false;
      _updateFavoriteStatus();
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

  double get score {
    if (questions.isEmpty) return 0;
    return correctCount.value / questions.length * 100;
  }

  void selectOption(int index) {
    if (isAnswered.value || isExamFinished.value) return;
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
    } else {
      finishExam();
    }
  }

  void finishExam() {
    isExamFinished.value = true;
    _saveExamResult();
  }

  Future<void> _saveExamResult() async {
    try {
      final homeController = Get.find<HomeController>();
      await homeController.saveExamResult(score, correctCount.value, questions.length);
      await _db.saveMockExamRecord(correctCount.value, questions.length, score);
    } catch (_) {}
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

  void restartExam() {
    currentIndex.value = 0;
    correctCount.value = 0;
    selectedIndex.value = -1;
    isAnswered.value = false;
    isCorrectAnswer.value = false;
    isExamFinished.value = false;
    loadQuestions();
  }
}
