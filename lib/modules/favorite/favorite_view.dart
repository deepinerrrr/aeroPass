import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'favorite_controller.dart';
import '../../core/routes/routes.dart';

class FavoriteView extends StatelessWidget {
  const FavoriteView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(FavoriteController());

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text('收藏题库 (${controller.favoriteCount.value})')),
        actions: [
          IconButton(
            onPressed: () => Get.toNamed(Routes.practice, arguments: {'subMode': 'favorite', 'sheetName': ''}),
            icon: const Icon(Icons.play_arrow_rounded),
            tooltip: '练习收藏题目',
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
                Icon(Icons.favorite_border_rounded, size: 64, color: Colors.orange.shade300),
                const SizedBox(height: 16),
                const Text('暂无收藏题目', style: TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 8),
                const Text('刷题时点击❤️即可收藏', style: TextStyle(fontSize: 13, color: Colors.grey)),
              ],
            ),
          );
        }
        return _buildQuestionList(controller);
      }),
    );
  }

  Widget _buildQuestionList(FavoriteController controller) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: controller.questions.length,
      itemBuilder: (context, index) {
        final question = controller.questions[index];
        return Dismissible(
          key: Key(question.questionId),
          direction: DismissDirection.endToStart,
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            color: Colors.red.shade400,
            child: const Icon(Icons.delete_rounded, color: Colors.white),
          ),
          onDismissed: (_) => controller.removeFavorite(question.questionId),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                Get.toNamed(Routes.practice, arguments: {'subMode': 'favorite', 'sheetName': ''});
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
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      question.content,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
