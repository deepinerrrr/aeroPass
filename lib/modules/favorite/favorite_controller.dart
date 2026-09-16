import 'package:get/get.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_model.dart';
import '../../data/services/question_filter_service.dart';
import '../home/home_controller.dart';

class FavoriteController extends GetxController {
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
  final favoriteCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadFavoriteQuestions();
  }

  Future<void> loadFavoriteQuestions() async {
    isLoading.value = true;
    try {
      final excludeLongest = await QuestionFilterService.isAutoFilterEnabled();
      questions.value = await _db.getFavoriteQuestions(limit: 1000, bankId: _bankId, excludeLongestAnswer: excludeLongest);
      favoriteCount.value = await _db.getFavoriteQuestionCount(bankId: _bankId, excludeLongestAnswer: excludeLongest);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> removeFavorite(String questionId) async {
    await _db.toggleFavorite(questionId);
    await loadFavoriteQuestions();
  }
}
