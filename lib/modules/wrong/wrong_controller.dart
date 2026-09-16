import 'package:get/get.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_model.dart';
import '../../data/services/question_filter_service.dart';
import '../home/home_controller.dart';

class WrongController extends GetxController {
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
  final isLoading = true.obs;
  final wrongCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadWrongQuestions();
  }

  Future<void> loadWrongQuestions() async {
    isLoading.value = true;
    try {
      final excludeLongest = await QuestionFilterService.isAutoFilterEnabled();
      questions.value = await _db.getWrongQuestions(limit: 1000, bankId: _bankId, excludeLongestAnswer: excludeLongest);
      wrongCount.value = await _db.getWrongQuestionCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> clearWrongRecords() async {
    await _db.clearWrongRecords();
    await loadWrongQuestions();
  }

  Future<void> removeWrongMark(String questionId) async {
    final record = await _db.getStudyRecord(questionId);
    if (record != null) {
      record.isWrong = 0;
      await _db.upsertStudyRecord(record);
      await loadWrongQuestions();
    }
  }
}
