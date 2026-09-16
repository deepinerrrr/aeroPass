import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'mock_exam_controller.dart';
import '../ai_chat/ai_chat_dialog.dart';

class MockExamView extends StatelessWidget {
  const MockExamView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MockExamController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('模拟考试'),
        actions: [
          Obx(() => IconButton(
            onPressed: controller.toggleFavorite,
            icon: Icon(
              controller.isFavorite.value ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: controller.isFavorite.value ? Colors.red : null,
            ),
          )),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.isExamFinished.value) {
          return _buildExamResult(controller);
        }
        if (controller.questions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox_rounded, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                const Text('题库题目不足，无法开始考试', style: TextStyle(fontSize: 16, color: Colors.grey)),
              ],
            ),
          );
        }
        return _buildQuestionContent(controller);
      }),
    );
  }

  Widget _buildExamResult(MockExamController controller) {
    final score = controller.score;
    final isPassed = score >= 60;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed ? Colors.green.shade50 : Colors.red.shade50,
                border: Border.all(
                  color: isPassed ? Colors.green.shade300 : Colors.red.shade300,
                  width: 3,
                ),
              ),
              child: Center(
                child: Text(
                  score.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isPassed ? Colors.green.shade600 : Colors.red.shade600,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isPassed ? '恭喜通过！' : '未通过',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: isPassed ? Colors.green.shade600 : Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildResultRow('总题数', controller.questions.length.toString()),
                    _buildResultRow('答对数', controller.correctCount.value.toString()),
                    _buildResultRow('答错数', (controller.questions.length - controller.correctCount.value).toString()),
                    _buildResultRow('正确率', '${score.toStringAsFixed(1)}%'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Get.back(),
                    icon: const Icon(Icons.home_rounded),
                    label: const Text('返回首页'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: controller.restartExam,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('再考一次'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildQuestionContent(MockExamController controller) {
    final question = controller.currentQuestion;
    if (question == null) return const SizedBox();

    return Column(
      children: [
        _buildProgressBar(controller),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuestionHeader(controller, question),
                const SizedBox(height: 20),
                _buildQuestionText(question),
                const SizedBox(height: 24),
                ..._buildOptions(controller, question),
              ],
            ),
          ),
        ),
        _buildBottomBar(controller),
      ],
    );
  }

  Widget _buildProgressBar(MockExamController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${controller.currentIndex.value + 1} / ${controller.questions.length}',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
              Text(
                '正确: ${controller.correctCount.value}',
                style: const TextStyle(fontSize: 13, color: Colors.green),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: controller.progress,
              backgroundColor: Colors.grey.shade200,
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.teal),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionHeader(MockExamController controller, dynamic question) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: question.isJudge ? Colors.purple.shade50 : Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            question.isJudge ? '判断题' : '单选题',
            style: TextStyle(
              fontSize: 12,
              color: question.isJudge ? Colors.purple : Colors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'No.${question.questionId}',
          style: const TextStyle(fontSize: 12, color: Colors.grey),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.teal.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '模拟考试',
            style: TextStyle(fontSize: 11, color: Colors.teal.shade700, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionText(dynamic question) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        question.content,
        style: const TextStyle(fontSize: 17, height: 1.6, fontWeight: FontWeight.w500),
      ),
    );
  }

  List<Widget> _buildOptions(MockExamController controller, dynamic question) {
    final options = question.options;
    final labels = question.optionLabels;
    final List<Widget> widgets = [];

    for (int i = 0; i < options.length; i++) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(_buildOptionButton(
        controller: controller,
        label: labels[i],
        text: options[i],
        index: i,
        question: question,
      ));
    }
    return widgets;
  }

  Widget _buildOptionButton({
    required MockExamController controller,
    required String label,
    required String text,
    required int index,
    required dynamic question,
  }) {
    return Obx(() {
      final isSelected = controller.selectedIndex.value == index;
      final isAnswered = controller.isAnswered.value;
      final isCorrectOpt = label == question.answer.toUpperCase();
      final isWrongSelection = isSelected && !controller.isCorrectAnswer.value;

      Color bgColor = Get.theme.cardColor;
      Color borderColor = Colors.grey.shade200;
      Color textColor = Get.theme.textTheme.bodyLarge!.color!;
      Color labelColor = Colors.grey.shade600;
      IconData? trailingIcon;

      if (isAnswered) {
        if (isCorrectOpt) {
          bgColor = Colors.green.shade50;
          borderColor = Colors.green.shade300;
          textColor = Colors.green.shade800;
          labelColor = Colors.green.shade700;
          trailingIcon = Icons.check_circle_rounded;
        } else if (isWrongSelection) {
          bgColor = Colors.red.shade50;
          borderColor = Colors.red.shade300;
          textColor = Colors.red.shade800;
          labelColor = Colors.red.shade700;
          trailingIcon = Icons.cancel_rounded;
        }
      } else if (isSelected) {
        bgColor = Colors.teal.shade50;
        borderColor = Colors.teal.shade300;
      }

      return GestureDetector(
        onTap: () => controller.selectOption(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: labelColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: labelColor,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(fontSize: 15, height: 1.4, color: textColor),
                ),
              ),
              if (trailingIcon != null)
                Icon(trailingIcon, color: isCorrectOpt ? Colors.green : Colors.red, size: 22),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomBar(MockExamController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: controller.currentIndex.value > 0 ? () {} : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
            label: const Text('上一题', style: TextStyle(fontSize: 14)),
          ),
          Obx(() => _buildAnswerResult(controller)),
          _buildAiButton(controller),
          TextButton.icon(
            onPressed: controller.nextQuestion,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text(
              controller.currentIndex.value < controller.questions.length - 1 ? '下一题' : '交卷',
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiButton(MockExamController controller) {
    return TextButton.icon(
      onPressed: () {
        final question = controller.currentQuestion;
        if (question != null) {
          AiChatDialog.show(question);
        }
      },
      icon: const Icon(Icons.smart_toy_rounded, size: 18),
      label: const Text('答疑', style: TextStyle(fontSize: 14)),
      style: TextButton.styleFrom(
        foregroundColor: Get.theme.colorScheme.primary,
      ),
    );
  }

  Widget _buildAnswerResult(MockExamController controller) {
    if (!controller.isAnswered.value) {
      return const Text('请选择答案', style: TextStyle(fontSize: 14, color: Colors.grey));
    }
    if (controller.isCorrectAnswer.value) {
      return const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
          SizedBox(width: 4),
          Text('回答正确', style: TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w600)),
        ],
      );
    }
    final question = controller.currentQuestion;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.cancel_rounded, color: Colors.red, size: 20),
        const SizedBox(width: 4),
        Text(
          '正确答案: ${question?.answer ?? ""}',
          style: const TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
