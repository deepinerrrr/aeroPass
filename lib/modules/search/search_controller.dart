import 'dart:async';
import 'package:get/get.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_model.dart';
import '../home/home_controller.dart';

class QuestionSearchController extends GetxController {
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
  final isLoading = false.obs;
  final keyword = ''.obs;
  final hasSearched = false.obs;
  Timer? _debounce;

  void onSearchChanged(String text) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      search(text);
    });
  }

  Future<void> search(String text) async {
    if (text.trim().isEmpty) {
      questions.clear();
      hasSearched.value = false;
      return;
    }
    keyword.value = text.trim();
    isLoading.value = true;
    hasSearched.value = true;
    try {
      questions.value = await _db.searchQuestions(
        keyword.value,
        bankId: _bankId,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void clearSearch() {
    _debounce?.cancel();
    keyword.value = '';
    questions.clear();
    hasSearched.value = false;
  }

  @override
  void onClose() {
    _debounce?.cancel();
    super.onClose();
  }
}
