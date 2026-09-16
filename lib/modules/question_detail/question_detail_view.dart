import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/models/question_model.dart';
import '../question_related/related_questions_panel.dart';

class QuestionDetailView extends StatelessWidget {
  final Question question;

  const QuestionDetailView({super.key, required this.question});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('题目详情')),
      body: RelatedQuestionsPager(
        currentQuestion: question,
        primarySwipeDirection: Axis.horizontal,
        itemBuilder: (context, item, isPrimary, search, parents) =>
            _buildQuestionContent(item, search, parents),
      ),
    );
  }

  Widget _buildQuestionContent(
    Question item,
    ValueChanged<String> search,
    List<ParentQuestionInfo> parents,
  ) {
    final hasParents = parents.isNotEmpty;

    // 题目正文（题干+选项+答案+解析）：已被收录到合集则置灰
    Widget questionBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SelectableText(
          item.content,
          contextMenuBuilder: (context, editableTextState) {
            final items = editableTextState.contextMenuButtonItems;
            final selection = editableTextState.textEditingValue.selection;
            if (!selection.isCollapsed) {
              items.add(
                ContextMenuButtonItem(
                  label: '搜索题库',
                  onPressed: () {
                    final selectedText = selection
                        .textInside(editableTextState.textEditingValue.text)
                        .trim();
                    editableTextState.hideToolbar();
                    if (selectedText.isNotEmpty) search(selectedText);
                  },
                ),
              );
            }
            return AdaptiveTextSelectionToolbar.buttonItems(
              anchors: editableTextState.contextMenuAnchors,
              buttonItems: items,
            );
          },
          style: const TextStyle(
            fontSize: 18,
            height: 1.6,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 20),
        ...List.generate(item.options.length, (index) {
          final label = item.optionLabels[index];
          final correct = label == item.answer.toUpperCase();
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: correct ? Colors.green.shade50 : Get.theme.cardColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: correct
                    ? Colors.green.shade300
                    : Get.theme.dividerColor,
              ),
            ),
            child: SelectableText(
              '$label. ${item.options[index]}',
              style: TextStyle(
                fontSize: 15,
                height: 1.4,
                color: correct ? Colors.green.shade800 : null,
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        Text(
          '正确答案: ${item.answer.toUpperCase()}. ${item.correctOptionText}',
          style: TextStyle(
            color: Colors.green.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
        if (item.referenceAnswer?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          SelectableText(
            item.referenceAnswer!,
            style: TextStyle(
              color: Get.theme.textTheme.bodySmall?.color,
              height: 1.5,
            ),
          ),
        ],
      ],
    );
    if (hasParents) {
      questionBody = buildGrayedContent(questionBody);
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'No.${item.questionId}',
                style: TextStyle(
                  color: Get.theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (item.isLongestAnswerQuestion) ...[
                const SizedBox(width: 8),
                _buildLongestAnswerBadge(),
              ],
              const Spacer(),
              QuestionSearchField(onSearch: search),
            ],
          ),
          if (hasParents) ...[
            const SizedBox(height: 12),
            CollectionBadgeBar(
              parents: parents,
              onTap: (parent) => Get.to(
                () => QuestionDetailView(question: parent),
              ),
            ),
          ],
          const SizedBox(height: 16),
          questionBody,
        ],
      ),
    );
  }

  Widget _buildLongestAnswerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.straighten_rounded, size: 12, color: Color(0xFF8B5CF6)),
          SizedBox(width: 4),
          Text(
            '答案最长',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF8B5CF6),
            ),
          ),
        ],
      ),
    );
  }
}
