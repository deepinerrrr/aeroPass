import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'search_controller.dart';
import '../../data/models/question_model.dart';
import '../question_detail/question_detail_view.dart';

class SearchView extends StatelessWidget {
  const SearchView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(QuestionSearchController());

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          autofocus: true,
          decoration: const InputDecoration(
            hintText: '搜索题目关键字...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey),
          ),
          style: const TextStyle(fontSize: 16),
          textInputAction: TextInputAction.search,
          onChanged: controller.onSearchChanged,
          onSubmitted: (value) => controller.search(value),
        ),
        actions: [
          IconButton(
            onPressed: controller.clearSearch,
            icon: const Icon(Icons.clear_rounded),
          ),
        ],
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!controller.hasSearched.value) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  '输入关键词搜索题目',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 8),
                const Text(
                  '支持部分关键字实时搜索',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        if (controller.questions.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.search_off_rounded,
                  size: 64,
                  color: Colors.grey.shade300,
                ),
                const SizedBox(height: 16),
                Text(
                  '未找到与"${controller.keyword.value}"相关的题目',
                  style: const TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(
                '找到 ${controller.questions.length} 道相关题目',
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
            Expanded(child: _buildSearchResults(controller)),
          ],
        );
      }),
    );
  }

  Widget _buildSearchResults(QuestionSearchController controller) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: controller.questions.length,
      itemBuilder: (context, index) {
        final question = controller.questions[index];
        return _buildSearchResultCard(question, controller.keyword.value);
      },
    );
  }

  Widget _buildSearchResultCard(Question question, String keyword) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () {
          Get.to(() => QuestionDetailView(question: question));
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: question.isJudge
                          ? Colors.purple.shade50
                          : Colors.blue.shade50,
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
                  if (question.isLongestAnswerQuestion) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        '答案最长',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Color(0xFF8B5CF6)),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '答案: ${question.answer}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildHighlightedText(question.content, keyword),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHighlightedText(String text, String keyword) {
    if (keyword.isEmpty) {
      return Text(
        text,
        style: const TextStyle(fontSize: 14, height: 1.5),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      );
    }

    final lowerText = text.toLowerCase();
    final lowerKeyword = keyword.toLowerCase();
    final List<TextSpan> spans = [];
    int start = 0;

    while (start < text.length) {
      final index = lowerText.indexOf(lowerKeyword, start);
      if (index == -1) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (index > start) {
        spans.add(TextSpan(text: text.substring(start, index)));
      }
      spans.add(
        TextSpan(
          text: text.substring(index, index + keyword.length),
          style: TextStyle(
            backgroundColor: Colors.yellow.shade200,
            fontWeight: FontWeight.bold,
            color: Get.theme.textTheme.bodyLarge!.color,
          ),
        ),
      );
      start = index + keyword.length;
    }

    return RichText(
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: TextStyle(
          fontSize: 14,
          height: 1.5,
          color: Get.theme.textTheme.bodyLarge!.color,
        ),
        children: spans,
      ),
    );
  }
}
