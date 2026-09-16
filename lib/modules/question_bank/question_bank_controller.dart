import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_bank_model.dart';
import '../../data/services/import_service.dart';
import '../../data/services/question_filter_service.dart';
import '../home/home_controller.dart';

class QuestionBankController extends GetxController {
  final DatabaseHelper _db = DatabaseHelper();
  final ImportService _importService = ImportService();

  final banks = <QuestionBank>[].obs;
  final activeBankId = 0.obs;
  final activeBankName = ''.obs;
  final isImporting = false.obs;
  final importProgress = ''.obs;

  // 高级筛选：自动隐藏“正确答案为最长选项”的题目
  final isAutoFilterEnabled = false.obs;
  final activeBankTotal = 0.obs;
  final longestAnswerCount = 0.obs;

  @override
  void onInit() {
    super.onInit();
    loadBanks();
    loadFilterState();
  }

  Future<void> loadFilterState() async {
    isAutoFilterEnabled.value =
        await QuestionFilterService.isAutoFilterEnabled();
  }

  Future<void> _loadFilterStats() async {
    final bankId = activeBankId.value > 0 ? activeBankId.value : null;
    activeBankTotal.value = await _db.getQuestionCount(bankId: bankId);
    longestAnswerCount.value = await _db.getLongestAnswerCount(bankId: bankId);
  }

  int get effectiveCount => isAutoFilterEnabled.value
      ? (activeBankTotal.value - longestAnswerCount.value).clamp(
          0,
          activeBankTotal.value,
        )
      : activeBankTotal.value;

  Future<void> toggleAutoFilter(bool enabled) async {
    await QuestionFilterService.setAutoFilterEnabled(enabled);
    isAutoFilterEnabled.value = enabled;
    await _loadFilterStats();
    // 立即刷新首页统计，使题量与筛选状态保持一致
    try {
      final homeController = Get.find<HomeController>();
      await homeController.loadStats();
    } catch (_) {}
    Get.snackbar(
      enabled ? '已开启高级筛选' : '已关闭高级筛选',
      enabled ? '答案最长题将在刷题/背题/模考中隐藏，可在搜索中查看标注' : '已恢复显示全部题目',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Get.theme.colorScheme.primary,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> loadBanks() async {
    final bankList = await _db.getAllBanks();
    banks.value = bankList;
    final active = bankList.where((b) => b.isActiveBank).firstOrNull;
    if (active != null) {
      activeBankId.value = active.id!;
      activeBankName.value = active.name;
    }
    await _loadFilterStats();
  }

  Future<void> switchBank(int bankId) async {
    await _db.setActiveBank(bankId);
    await loadBanks();
    final homeController = Get.find<HomeController>();
    await homeController.switchBank(bankId);
    final bank = banks.where((b) => b.id == bankId).firstOrNull;
    if (bank != null) {
      Get.snackbar(
        '切换成功',
        '已切换到「${bank.name}」',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> deleteBank(int bankId) async {
    final wasActive = bankId == activeBankId.value;
    await _db.deleteQuestionBank(bankId);
    await loadBanks();
    if (wasActive) {
      final homeController = Get.find<HomeController>();
      await homeController.switchBank(
        activeBankId.value > 0 ? activeBankId.value : 0,
      );
    }
    Get.snackbar(
      '删除成功',
      '题库已删除',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> importFromExcel() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['xlsx'],
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return;
    final filePath = result.files.single.path;
    if (filePath == null) return;

    // 弹出输入题库名称的对话框
    final bankName = await _showBankNameDialog();
    if (bankName == null || bankName.isEmpty) return;

    isImporting.value = true;
    importProgress.value = '正在解析Excel文件...';

    try {
      final importResult = await _importService.importFromExcel(
        filePath,
        bankName,
      );

      if (importResult.success) {
        importProgress.value = importResult.message;
        await loadBanks();
        final homeController = Get.find<HomeController>();
        await homeController.switchBank(
          importResult.bankId ?? activeBankId.value,
        );
        Get.snackbar(
          '导入成功',
          importResult.message,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.green,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        importProgress.value = importResult.message;
        Get.dialog(
          AlertDialog(
            backgroundColor: Get.theme.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text('导入失败'),
            content: SingleChildScrollView(
              child: SelectableText(importResult.message),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Get.back(),
                child: const Text('我知道了'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      importProgress.value = '导入失败: $e';
      Get.snackbar(
        '导入异常',
        '$e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 3),
      );
    } finally {
      isImporting.value = false;
    }
  }

  Future<String?> _showBankNameDialog() {
    final textController = TextEditingController();
    return Get.dialog<String>(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '输入题库名称',
          style: TextStyle(color: Get.theme.textTheme.headlineSmall!.color),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 30,
          decoration: InputDecoration(
            hintText: '例如：新版执照题库',
            hintStyle: TextStyle(color: Get.theme.textTheme.bodySmall!.color),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Get.theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Get.theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Get.theme.colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: null),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Get.back(result: textController.text.trim()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void showDeleteConfirmDialog(int bankId, String bankName) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '删除题库',
          style: TextStyle(color: Get.theme.textTheme.headlineSmall!.color),
        ),
        content: Text(
          '确定要删除「$bankName」吗？该题库下的所有题目和学习记录将被清除，且不可恢复。',
          style: TextStyle(color: Get.theme.textTheme.bodyLarge!.color),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              deleteBank(bankId);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('确定删除'),
          ),
        ],
      ),
    );
  }
}
