import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'collection_controller.dart';
import 'collection_mind_map_selection_view.dart';
import '../../data/models/question_model.dart';
import '../question_detail/question_detail_view.dart';
import '../question_related/related_questions_panel.dart';

class CollectionDetailView extends StatefulWidget {
  const CollectionDetailView({super.key});

  @override
  State<CollectionDetailView> createState() => _CollectionDetailViewState();
}

class _CollectionDetailViewState extends State<CollectionDetailView> {
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(CollectionDetailController());

    return Scaffold(
      appBar: AppBar(
        title: Obx(
          () => Text(
            controller.keyword.value.isEmpty
                ? '合集详情'
                : controller.keyword.value,
          ),
        ),
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
                Icon(
                  Icons.collections_bookmark_outlined,
                  size: 64,
                  color: Colors.teal.shade300,
                ),
                const SizedBox(height: 16),
                const Text(
                  '该合集暂无题目',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            _buildMindMapAction(controller),
            _buildProgressBar(controller),
            Expanded(child: _buildSwipeView(controller)),
            _buildBottomBar(controller),
          ],
        );
      }),
    );
  }

  Widget _buildMindMapAction(CollectionDetailController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => Get.to(
            () => CollectionMindMapSelectionView(
              keyword: controller.keyword.value,
              questions: controller.questions.toList(growable: false),
            ),
          ),
          icon: const Icon(Icons.account_tree_rounded),
          label: const Text('AI 创建思维导图'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(CollectionDetailController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${controller.currentIndex.value + 1} / ${controller.questions.length}',
                style: TextStyle(
                  fontSize: 13,
                  color: Get.theme.textTheme.bodySmall!.color,
                ),
              ),
              Text(
                controller.keyword.value,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF0D9488),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Stack(
            children: [
              SliderTheme(
                data: SliderThemeData(
                  trackHeight: 6,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 16,
                  ),
                  trackShape: const RoundedRectSliderTrackShape(),
                  activeTrackColor: Get.theme.colorScheme.primary,
                  inactiveTrackColor: Get.theme.dividerColor,
                  thumbColor: Get.theme.colorScheme.primary,
                ),
                child: Slider(
                  value: _isDragging
                      ? _dragValue
                      : (controller.currentIndex.value + 1).toDouble(),
                  min: 1,
                  max: controller.questions.length.toDouble(),
                  onChanged: (value) {
                    setState(() {
                      _isDragging = true;
                      _dragValue = value;
                    });
                    final index = (value - 1).round();
                    controller.jumpToIndex(index);
                  },
                  onChangeEnd: (value) {
                    setState(() => _isDragging = false);
                    final index = (value - 1).round();
                    controller.jumpToIndexWithAnimation(index);
                  },
                ),
              ),
              if (_isDragging)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Get.theme.colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '第 ${_dragValue.round()} 题',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeView(CollectionDetailController controller) {
    final isVertical = controller.swipeMode.value == 'vertical';
    return PageView.builder(
      scrollDirection: isVertical ? Axis.vertical : Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      controller: controller.pageController,
      itemCount: controller.questions.length,
      onPageChanged: (index) => controller.jumpToIndex(index),
      itemBuilder: (context, index) {
        final question = controller.questions[index];
        return RelatedQuestionsPager(
          currentQuestion: question,
          primarySwipeDirection: isVertical ? Axis.vertical : Axis.horizontal,
          itemBuilder: (context, item, isPrimary, search, parents) =>
              _buildQuestionContent(item, search, parents),
        );
      },
    );
  }

  Widget _buildQuestionContent(
    Question item,
    ValueChanged<String> search,
    List<ParentQuestionInfo> parents,
  ) {
    final hasParents = parents.isNotEmpty;

    Widget body = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionCard(item, search),
        const SizedBox(height: 20),
        _buildAnswerSection(item),
      ],
    );
    if (hasParents) body = buildGrayedContent(body);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildQuestionHeader(item, search),
              if (hasParents) ...[
                const SizedBox(height: 12),
                CollectionBadgeBar(
                  parents: parents,
                  onTap: (parent) =>
                      Get.to(() => QuestionDetailView(question: parent)),
                ),
              ],
              const SizedBox(height: 20),
              body,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionHeader(Question question, ValueChanged<String> search) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: question.isJudge
                ? Colors.purple.shade50
                : Colors.blue.shade50,
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
        if (question.isLongestAnswerQuestion) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              '答案最长',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8B5CF6),
              ),
            ),
          ),
        ],
        const Spacer(),
        QuestionSearchField(onSearch: search),
      ],
    );
  }

  Widget _buildQuestionCard(Question question, ValueChanged<String> search) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Get.theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: SelectableText(
        question.content,
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
          fontSize: 17,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildAnswerSection(Question question) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.green),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '正确答案: ${question.answer.toUpperCase()}. ${question.correctOptionText}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ..._buildAnswerOptions(question),
        if (question.referenceAnswer?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Get.theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              question.referenceAnswer!,
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
                color: Get.theme.textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildAnswerOptions(Question question) {
    final options = question.options;
    final labels = question.optionLabels;
    final correctAnswer = question.answer.toUpperCase();
    final List<Widget> widgets = [];

    for (int i = 0; i < options.length; i++) {
      final isCorrect = labels[i] == correctAnswer;
      widgets.add(
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isCorrect
                ? Colors.green.shade50.withValues(alpha: 0.5)
                : Get.theme.cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isCorrect ? Colors.green.shade100 : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isCorrect
                      ? Colors.green.shade50
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  labels[i],
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isCorrect
                        ? Colors.green.shade400
                        : Colors.grey.shade600,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  options[i],
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: isCorrect
                        ? Colors.green.shade500
                        : Get.theme.textTheme.bodyLarge!.color,
                  ),
                ),
              ),
              if (isCorrect)
                Icon(
                  Icons.check_circle_outline_rounded,
                  color: Colors.green.shade300,
                  size: 20,
                ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  Widget _buildBottomBar(CollectionDetailController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
          IconButton(
            onPressed: controller.currentIndex.value > 0
                ? controller.prevQuestion
                : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            tooltip: '上一题',
            color: controller.currentIndex.value > 0
                ? Get.theme.colorScheme.primary
                : Get.theme.textTheme.bodySmall!.color,
          ),
          IconButton(
            onPressed: () {
              final question = controller.currentQuestion;
              if (question != null) {
                Get.to(() => QuestionDetailView(question: question));
              }
            },
            icon: const Icon(Icons.fullscreen_rounded, size: 20),
            tooltip: '详情',
            color: Get.theme.colorScheme.primary,
          ),
          IconButton(
            onPressed:
                controller.currentIndex.value < controller.questions.length - 1
                ? controller.nextQuestion
                : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 20),
            tooltip: '下一题',
            color:
                controller.currentIndex.value < controller.questions.length - 1
                ? Get.theme.colorScheme.primary
                : Get.theme.textTheme.bodySmall!.color,
          ),
        ],
      ),
    );
  }
}
