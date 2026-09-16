import 'package:get/get.dart';
import '../../data/database/database_helper.dart';
import '../../data/services/question_filter_service.dart';
import '../home/home_controller.dart';

class StatsController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper();

  int? get _bankId {
    try {
      final id = Get.find<HomeController>().activeBankId.value;
      return id > 0 ? id : null;
    } catch (_) {
      return null;
    }
  }

  final totalQuestions = 0.obs;
  final practicedCount = 0.obs;
  final correctCount = 0.obs;
  final wrongCount = 0.obs;
  final favoriteCount = 0.obs;
  final masteredCount = 0.obs;
  final isLoading = true.obs;
  final mockExamCount = 0.obs;
  final mockExamAvgScore = 0.0.obs;
  final mockExamMaxScore = 0.0.obs;
  final mockExamRecords = <Map<String, dynamic>>[].obs;

  @override
  void onInit() {
    super.onInit();
    loadStats();
  }

  Future<void> loadStats() async {
    isLoading.value = true;
    try {
      final excludeLongest = await QuestionFilterService.isAutoFilterEnabled();
      totalQuestions.value = await _db.getQuestionCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
      practicedCount.value = await _db.getPracticedCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
      correctCount.value = await _db.getCorrectCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
      wrongCount.value = await _db.getWrongQuestionCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
      favoriteCount.value = await _db.getFavoriteQuestionCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
      masteredCount.value = await _db.getMasteredCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
      mockExamCount.value = await _db.getMockExamCount();
      mockExamAvgScore.value = await _db.getMockExamAvgScore();
      mockExamMaxScore.value = await _db.getMockExamMaxScore();
      mockExamRecords.value = await _db.getMockExamRecords(limit: 20);
    } finally {
      isLoading.value = false;
    }
  }

  double get correctRate {
    if (practicedCount.value == 0) return 0;
    return correctCount.value / practicedCount.value * 100;
  }

  double get progressRate {
    if (totalQuestions.value == 0) return 0;
    return practicedCount.value / totalQuestions.value * 100;
  }

  double get masteredRate {
    if (totalQuestions.value == 0) return 0;
    return masteredCount.value / totalQuestions.value * 100;
  }

  int get unpracticedCount => totalQuestions.value - practicedCount.value;
}
