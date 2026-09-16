import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'practice_controller.dart';
import '../ai_chat/ai_chat_dialog.dart';
import '../note/note_view.dart';
import '../question_detail/question_detail_view.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_model.dart';
import '../../core/routes/routes.dart';
import '../question_related/related_questions_panel.dart';
import '../common/current_question_grid.dart';

class PracticeView extends StatefulWidget {
  const PracticeView({super.key});

  @override
  State<PracticeView> createState() => _PracticeViewState();
}

class _PracticeViewState extends State<PracticeView> {
  bool _isDragging = false;
  double _dragValue = 0;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(PracticeController());

    return Scaffold(
      appBar: AppBar(
        title: Obx(() => Text(_getSubModeTitle(controller.subMode.value))),
        actions: [
          Obx(
            () => IconButton(
              onPressed: controller.toggleFavorite,
              icon: Icon(
                controller.isFavorite.value
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: controller.isFavorite.value ? Colors.red : null,
              ),
            ),
          ),
          IconButton(
            onPressed: () => _showExportCardDialog(controller),
            icon: const Icon(Icons.share_rounded),
            tooltip: '导出卡片',
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
                Icon(
                  Icons.inbox_rounded,
                  size: 64,
                  color: Get.theme.textTheme.bodySmall!.color,
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无题目',
                  style: TextStyle(
                    fontSize: 16,
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                ),
              ],
            ),
          );
        }
        if (controller.swipeMode.value == 'vertical') {
          return _buildVerticalSwipeView(controller);
        }
        return _buildHorizontalSwipeView(controller);
      }),
    );
  }

  Widget _buildVerticalSwipeView(PracticeController controller) {
    return Column(
      children: [
        _buildProgressBar(controller),
        Expanded(
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            controller: controller.verticalPageController,
            itemCount: controller.questions.length,
            onPageChanged: (index) {
              controller.onPageChanged(index);
            },
            itemBuilder: (context, index) {
              final question = controller.questions[index];
              return _buildQuestionCard(question, controller, index);
            },
          ),
        ),
        _buildBottomBar(controller),
      ],
    );
  }

  Widget _buildHorizontalSwipeView(PracticeController controller) {
    return Column(
      children: [
        _buildProgressBar(controller),
        Expanded(
          child: PageView.builder(
            scrollDirection: Axis.horizontal,
            controller: controller.horizontalPageController,
            itemCount: controller.questions.length,
            onPageChanged: (index) {
              controller.onPageChanged(index);
            },
            itemBuilder: (context, index) {
              final question = controller.questions[index];
              return _buildQuestionCard(question, controller, index);
            },
          ),
        ),
        _buildBottomBar(controller),
      ],
    );
  }

  Widget _buildQuestionCard(
    Question question,
    PracticeController controller,
    int index,
  ) {
    return RelatedQuestionsPager(
      currentQuestion: question,
      primarySwipeDirection: controller.swipeMode.value == 'vertical'
          ? Axis.vertical
          : Axis.horizontal,
      itemBuilder: (context, item, isPrimary, search, parents) =>
          _buildQuestionContent(controller, item, isPrimary, search, parents),
    );
  }

  Widget _buildQuestionContent(
    PracticeController controller,
    Question question,
    bool isPrimary,
    ValueChanged<String> search,
    List<ParentQuestionInfo> parentQuestions,
  ) {
    final hasParents = parentQuestions.isNotEmpty;
    // 题目正文（题干+选项）：如果已被收录到合集则置灰
    Widget questionBody = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildQuestionText(question, search),
        const SizedBox(height: 24),
        if (isPrimary)
          ..._buildOptions(controller, question)
        else
          ..._buildReadOnlyOptions(question),
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
          _buildQuestionHeader(controller, question, search),
          if (hasParents) ...[
            const SizedBox(height: 12),
            CollectionBadgeBar(
              parents: parentQuestions,
              onTap: (parent) =>
                  Get.to(() => QuestionDetailView(question: parent)),
            ),
          ],
          const SizedBox(height: 20),
          questionBody,
        ],
      ),
    );
  }

  String _getSubModeTitle(String mode) {
    switch (mode) {
      case 'random':
        return '随机刷题';
      case 'wrong':
        return '错题刷题';
      case 'favorite':
        return '收藏刷题';
      default:
        return '顺序刷题';
    }
  }

  Widget _buildProgressBar(PracticeController controller) {
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
                '正确: ${controller.correctCount.value}',
                style: const TextStyle(fontSize: 13, color: Colors.green),
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
                        '第 ${(_dragValue).round()} 题',
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

  Widget _buildQuestionHeader(
    PracticeController controller,
    dynamic question,
    ValueChanged<String> search,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: question.isJudge
                ? Colors.purple.withValues(alpha: 0.08)
                : Get.theme.colorScheme.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            question.isJudge ? '判断题' : '单选题',
            style: TextStyle(
              fontSize: 12,
              color: question.isJudge
                  ? Colors.purple
                  : Get.theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          'No.${question.questionId}',
          style: TextStyle(
            fontSize: 12,
            color: Get.theme.textTheme.bodySmall!.color,
          ),
        ),
        if (question.isLongestAnswerQuestion == true) ...[
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

  Widget _buildQuestionText(Question question, ValueChanged<String> search) {
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
        style: TextStyle(
          fontSize: 17,
          height: 1.6,
          fontWeight: FontWeight.w500,
          color: Get.theme.textTheme.bodyLarge!.color,
        ),
      ),
    );
  }

  List<Widget> _buildOptions(PracticeController controller, dynamic question) {
    final options = question.options;
    final labels = question.optionLabels;
    final List<Widget> widgets = [];

    for (int i = 0; i < options.length; i++) {
      widgets.add(const SizedBox(height: 12));
      widgets.add(
        _buildOptionButton(
          controller: controller,
          label: labels[i],
          text: options[i],
          index: i,
          question: question,
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildReadOnlyOptions(Question question) {
    return List.generate(question.options.length, (index) {
      final label = question.optionLabels[index];
      final correct = label == question.answer.toUpperCase();
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: correct ? Colors.green.shade50 : Get.theme.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: correct ? Colors.green.shade300 : Get.theme.dividerColor,
          ),
        ),
        child: SelectableText(
          '$label. ${question.options[index]}',
          style: TextStyle(
            fontSize: 15,
            height: 1.4,
            color: correct ? Colors.green.shade800 : null,
          ),
        ),
      );
    });
  }

  Widget _buildOptionButton({
    required PracticeController controller,
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
      Color borderColor = Get.theme.dividerColor;
      Color textColor = Get.theme.textTheme.bodyLarge!.color!;
      Color labelColor = Get.theme.textTheme.bodyMedium!.color!;
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
        bgColor = Get.theme.colorScheme.primary.withValues(alpha: 0.08);
        borderColor = Get.theme.colorScheme.primary.withValues(alpha: 0.3);
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
                Icon(
                  trailingIcon,
                  color: isCorrectOpt ? Colors.green : Colors.red,
                  size: 22,
                ),
            ],
          ),
        ),
      );
    });
  }

  Widget _buildBottomBar(PracticeController controller) {
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
          _buildIconButton(
            Icons.arrow_back_rounded,
            '上一题',
            controller.currentIndex.value > 0 ? controller.prevQuestion : null,
          ),
          Obx(() => _buildAnswerResult(controller)),
          _buildIconButton(Icons.smart_toy_rounded, '答疑', () {
            final question = controller.currentQuestion;
            if (question != null) {
              AiChatDialog.show(question);
            }
          }, Get.theme.colorScheme.primary),
          _buildIconButton(Icons.edit_note_rounded, '笔记', () {
            final question = controller.currentQuestion;
            if (question != null) {
              Get.to(() => NoteView(questionId: question.questionId));
            }
          }, Get.theme.colorScheme.primary),
          _buildIconButton(
            Icons.grid_view_rounded,
            '答题卡',
            () => _showAnswerCard(controller),
            Get.theme.colorScheme.primary,
          ),
          _buildIconButton(
            Icons.arrow_forward_rounded,
            '下一题',
            controller.currentIndex.value < controller.questions.length - 1
                ? controller.nextQuestion
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildIconButton(
    IconData icon,
    String tooltip,
    VoidCallback? onPressed, [
    Color? color,
  ]) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      tooltip: tooltip,
      color: onPressed != null
          ? color ?? Get.theme.colorScheme.primary
          : Get.theme.textTheme.bodySmall!.color,
      style: IconButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _buildAnswerResult(PracticeController controller) {
    if (!controller.isAnswered.value) {
      return Icon(
        Icons.circle_outlined,
        size: 20,
        color: Get.theme.textTheme.bodySmall!.color,
      );
    }
    if (controller.isCorrectAnswer.value) {
      return Icon(Icons.check_circle_rounded, color: Colors.green, size: 20);
    }
    return Icon(Icons.cancel_rounded, color: Colors.red, size: 20);
  }

  Future<void> _showAnswerCard(PracticeController controller) async {
    final db = DatabaseHelper();
    final questionIds = controller.questions.map((q) => q.questionId).toList();
    final bankId = controller.questions.isNotEmpty
        ? controller.questions.first.bankId
        : null;
    final withRelated = await db.getQuestionIdsWithRelated(
      questionIds,
      bankId: bankId,
    );
    final withNotes = await db.getQuestionIdsWithNotes(questionIds);
    final inCollection = await db.getQuestionIdsInRelated(
      questionIds,
      bankId: bankId,
    );
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          expand: false,
          builder: (context, scrollController) {
            return Column(
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '答题卡',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Get.theme.textTheme.headlineSmall!.color,
                        ),
                      ),
                      Text(
                        '共 ${controller.questions.length} 题',
                        style: TextStyle(
                          fontSize: 14,
                          color: Get.theme.textTheme.bodySmall!.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 6,
                    children: [
                      _buildLegend(
                        Colors.green.shade100,
                        Colors.green.shade700,
                        '已答对',
                      ),
                      _buildLegend(
                        Colors.red.shade100,
                        Colors.red.shade700,
                        '已答错',
                      ),
                      _buildLegend(
                        Get.theme.colorScheme.primary.withValues(alpha: 0.15),
                        Get.theme.colorScheme.primary,
                        '当前题',
                      ),
                      _buildLegend(
                        Colors.grey.shade100,
                        Colors.grey.shade600,
                        '未作答',
                      ),
                      _buildLegend(
                        Colors.blueGrey.shade100,
                        Colors.blueGrey.shade600,
                        '在合集中',
                      ),
                      _buildDotLegend(Colors.teal, '有合集'),
                      _buildDotLegend(Colors.amber.shade700, '笔记'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                Expanded(
                  child: Obx(
                    () => CurrentQuestionGrid(
                      controller: scrollController,
                      currentIndex: controller.currentIndex.value,
                      itemCount: controller.questions.length,
                      itemBuilder: (context, index) {
                        final isCurrent =
                            index == controller.currentIndex.value;
                        final question = controller.questions[index];
                        final hasRelated = withRelated.contains(
                          question.questionId,
                        );
                        final hasNote = withNotes.contains(question.questionId);
                        final isInCollection = inCollection.contains(
                          question.questionId,
                        );
                        Color bgColor;
                        Color textColor;
                        Color borderColor;

                        if (isCurrent) {
                          bgColor = Get.theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          );
                          textColor = Get.theme.colorScheme.primary;
                          borderColor = Get.theme.colorScheme.primary;
                        } else if (isInCollection) {
                          // 被添加到合集：明显的深灰底 + 深色文字 + 边框 + 斜线标记
                          bgColor = Colors.blueGrey.shade200;
                          textColor = Colors.blueGrey.shade800.withValues(
                            alpha: 0.7,
                          );
                          borderColor = Colors.blueGrey.shade500;
                        } else {
                          bgColor = Colors.grey.shade100;
                          textColor = Colors.grey.shade600;
                          borderColor = Colors.grey.shade200;
                        }

                        return GestureDetector(
                          onTap: () {
                            controller.jumpToIndexWithAnimation(index);
                            Navigator.pop(context);
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: bgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: borderColor,
                                width: isCurrent
                                    ? 2
                                    : isInCollection
                                    ? 1.5
                                    : 1,
                              ),
                            ),
                            child: Stack(
                              children: [
                                Center(
                                  child: Text(
                                    '${index + 1}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isCurrent
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: textColor,
                                      decoration: isInCollection
                                          ? TextDecoration.lineThrough
                                          : null,
                                      decorationColor: isInCollection
                                          ? Colors.blueGrey.shade400
                                          : null,
                                    ),
                                  ),
                                ),
                                // 已收录合集：左上角书签角标
                                if (isInCollection)
                                  Positioned(
                                    top: 0,
                                    left: 0,
                                    child: Container(
                                      width: 14,
                                      height: 14,
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.shade600,
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(7),
                                          bottomRight: Radius.circular(7),
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.bookmark_rounded,
                                        size: 8,
                                        color: Colors.white.withValues(
                                          alpha: 0.9,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (hasRelated || hasNote)
                                  Positioned(
                                    top: 3,
                                    right: 3,
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (hasRelated)
                                          _buildCellDot(Colors.teal),
                                        if (hasNote)
                                          _buildCellDot(Colors.amber.shade700),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildCellDot(Color color) {
    return Container(
      width: 6,
      height: 6,
      margin: const EdgeInsets.only(left: 2),
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  Widget _buildDotLegend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color)),
      ],
    );
  }

  Widget _buildLegend(Color bgColor, Color textColor, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(3),
            border: Border.all(color: textColor.withValues(alpha: 0.3)),
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: textColor)),
      ],
    );
  }

  void _showExportCardDialog(PracticeController controller) {
    final question = controller.currentQuestion;
    if (question == null) return;
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '导出题目卡片',
          style: TextStyle(color: Get.theme.textTheme.headlineSmall!.color),
        ),
        content: Text(
          '将当前题目导出为精美卡片图片并保存到相册？',
          style: TextStyle(color: Get.theme.textTheme.bodyLarge!.color),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _exportQuestionCard(question);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('导出'),
          ),
        ],
      ),
    );
  }

  void _exportQuestionCard(Question question) {
    Get.toNamed(Routes.questionCard, arguments: {'question': question});
  }
}
