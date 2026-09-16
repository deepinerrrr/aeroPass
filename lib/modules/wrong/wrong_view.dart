import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'wrong_controller.dart';
import '../../core/routes/routes.dart';

class WrongView extends StatelessWidget {
  const WrongView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(WrongController());

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text('错题本 (${controller.wrongCount.value})')),
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear') {
                _showClearConfirm(controller);
              } else if (value == 'practice') {
                Get.toNamed(Routes.practice, arguments: {'subMode': 'wrong', 'sheetName': ''});
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'practice', child: Text('重刷错题')),
              const PopupMenuItem(value: 'clear', child: Text('清空错题本')),
            ],
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.questions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline_rounded, size: 64, color: Colors.green.shade300),
                const SizedBox(height: 16),
                const Text('暂无错题，继续加油！', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return _buildQuestionList(controller);
      }),
    );
  }

  Widget _buildQuestionList(WrongController controller) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.questions.length,
      itemBuilder: (context, index) {
        final question = controller.questions[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              Get.toNamed(
                Routes.practice,
                arguments: {'subMode': 'wrong', 'sheetName': ''},
              );
            },
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: question.isJudge ? Colors.purple.shade50 : Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          question.isJudge ? '判断' : '单选',
                          style: TextStyle(
                            fontSize: 11,
                            color: question.isJudge ? Colors.purple : Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'No.${question.questionId}',
                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => controller.removeWrongMark(question.questionId),
                        icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                        tooltip: '取消标记',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    question.content,
                    style: const TextStyle(fontSize: 15, height: 1.5),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '正确答案: ${question.answer}. ${question.correctOptionText}',
                    style: TextStyle(fontSize: 13, color: Colors.green.shade700),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showClearConfirm(WrongController controller) {
    Get.dialog(
      AlertDialog(
        title: const Text('清空错题本'),
        content: const Text('确定要清空所有错题记录吗？此操作不可撤销。'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          TextButton(
            onPressed: () {
              Get.back();
              controller.clearWrongRecords();
            },
            child: const Text('确定', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
