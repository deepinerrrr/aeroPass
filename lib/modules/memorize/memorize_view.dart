import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'memorize_controller.dart';
import '../ai_chat/ai_chat_dialog.dart';
import '../note/note_view.dart';
import '../question_detail/question_detail_view.dart';
import '../../core/routes/routes.dart';
import '../question_related/related_questions_panel.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/annotation_model.dart';
import '../../data/models/note_model.dart';
import '../../data/models/question_model.dart';
import '../common/current_question_grid.dart';

class MemorizeView extends StatefulWidget {
  const MemorizeView({super.key});

  @override
  State<MemorizeView> createState() => _MemorizeViewState();
}

class _MemorizeViewState extends State<MemorizeView> {
  bool _isDragging = false;
  double _dragValue = 0;
  final List<StrokePoint> _currentStrokePoints = [];
  int? _activeAnnotationPointer;

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(MemorizeController());

    return Scaffold(
      appBar: AppBar(
        title: const Text('背题模式'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.style_rounded),
            tooltip: '显示样式',
            onSelected: controller.setCardStyle,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'classic', child: Text('标准样式（显示答案横幅）')),
              PopupMenuItem(value: 'clean', child: Text('简洁样式（隐藏答案横幅）')),
            ],
          ),
          Obx(
            () => IconButton(
              onPressed: controller.toggleAnnotating,
              icon: Icon(
                controller.isAnnotating.value
                    ? Icons.draw_rounded
                    : Icons.draw_outlined,
                color: controller.isAnnotating.value
                    ? Get.theme.colorScheme.primary
                    : null,
              ),
              tooltip: controller.isAnnotating.value ? '退出圈画' : '圈画标注',
            ),
          ),
          Obx(
            () => IconButton(
              onPressed: controller.toggleFavorite,
              icon: Icon(
                controller.isFavorite.value
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: controller.isFavorite.value ? Colors.red : null,
              ),
              tooltip: controller.isFavorite.value ? '取消收藏' : '收藏',
            ),
          ),
          Obx(
            () => IconButton(
              onPressed: controller.isUpdatingMastered.value
                  ? null
                  : controller.toggleMastered,
              icon: Icon(
                controller.isMastered.value
                    ? Icons.task_alt_rounded
                    : Icons.check_circle_outline_rounded,
                color: controller.isMastered.value ? Colors.green : null,
              ),
              tooltip: controller.isMastered.value ? '已掌握' : '标记掌握',
            ),
          ),
          IconButton(
            onPressed: () {
              final question = controller.currentQuestion;
              if (question != null) {
                Get.toNamed(
                  Routes.questionCard,
                  arguments: {'question': question},
                );
              }
            },
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
                  color: Colors.grey.shade400,
                ),
                const SizedBox(height: 16),
                const Text(
                  '当前题库已全部掌握',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                if (controller.masteredQuestions.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAnswerCard(
                      controller,
                      showMasteredInitially: true,
                    ),
                    icon: const Icon(Icons.task_alt_rounded),
                    label: const Text('查看已掌握'),
                  ),
                ],
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

  Widget _buildVerticalSwipeView(MemorizeController controller) {
    return Column(
      children: [
        _buildProgressBar(controller),
        Expanded(
          child: PageView.builder(
            scrollDirection: Axis.vertical,
            physics: const BouncingScrollPhysics(),
            controller: controller.verticalPageController,
            itemCount: controller.questions.length,
            onPageChanged: (index) {
              controller.jumpToIndex(index);
            },
            itemBuilder: (context, index) {
              final question = controller.questions[index];
              return _buildVerticalCard(question, controller, index);
            },
          ),
        ),
        Obx(
          () => controller.isAnnotating.value
              ? _buildAnnotationToolbar(controller)
              : const SizedBox.shrink(),
        ),
        _buildBottomBar(controller),
      ],
    );
  }

  Widget _buildVerticalCard(
    dynamic question,
    MemorizeController controller,
    int index,
  ) {
    return RelatedQuestionsPager(
      currentQuestion: question,
      primarySwipeDirection: controller.swipeMode.value == 'vertical'
          ? Axis.vertical
          : Axis.horizontal,
      itemBuilder: (context, item, isPrimary, search, parents) =>
          _buildVerticalContent(controller, item, search, parents),
    );
  }

  Widget _buildVerticalContent(
    MemorizeController controller,
    dynamic question,
    ValueChanged<String> search,
    List<ParentQuestionInfo> parents,
  ) {
    controller.ensureAnnotationLoaded(question.questionId);
    final hasParents = parents.isNotEmpty;
    Widget body = Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionCard(question, search),
          const SizedBox(height: 20),
          _buildAnswerSection(controller, question),
        ],
      ),
    );
    if (hasParents) body = buildGrayedContent(body);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        child: Obx(
          () => SingleChildScrollView(
            physics: controller.isAnnotating.value
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestionHeader(question, search),
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
                _buildAnnotationLayer(controller, question),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontalSwipeView(MemorizeController controller) {
    return Column(
      children: [
        _buildProgressBar(controller),
        Expanded(
          child: PageView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            controller: controller.horizontalPageController,
            itemCount: controller.questions.length,
            onPageChanged: (index) {
              controller.jumpToIndex(index);
            },
            itemBuilder: (context, index) {
              final question = controller.questions[index];
              return _buildHorizontalCard(question, controller, index);
            },
          ),
        ),
        Obx(
          () => controller.isAnnotating.value
              ? _buildAnnotationToolbar(controller)
              : const SizedBox.shrink(),
        ),
        _buildBottomBar(controller),
      ],
    );
  }

  Widget _buildHorizontalCard(
    dynamic question,
    MemorizeController controller,
    int index,
  ) {
    return RelatedQuestionsPager(
      currentQuestion: question,
      primarySwipeDirection: controller.swipeMode.value == 'vertical'
          ? Axis.vertical
          : Axis.horizontal,
      itemBuilder: (context, item, isPrimary, search, parents) =>
          _buildMemorizeContent(controller, item, search, parents),
    );
  }

  Widget _buildMemorizeContent(
    MemorizeController controller,
    dynamic question,
    ValueChanged<String> search,
    List<ParentQuestionInfo> parents,
  ) {
    controller.ensureAnnotationLoaded(question.questionId);
    final hasParents = parents.isNotEmpty;
    Widget body = Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildQuestionCard(question, search),
          const SizedBox(height: 20),
          _buildAnswerSection(controller, question),
        ],
      ),
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
          BoxShadow(
            color: Get.theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(-3, 0),
          ),
          BoxShadow(
            color: Get.theme.colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(3, 0),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Obx(
          () => SingleChildScrollView(
            physics: controller.isAnnotating.value
                ? const NeverScrollableScrollPhysics()
                : null,
            padding: const EdgeInsets.all(24),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildQuestionHeader(question, search),
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
                _buildAnnotationLayer(controller, question),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar(MemorizeController controller) {
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
                '已掌握: ${controller.masteredCount.value}',
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

  Widget _buildQuestionHeader(dynamic question, ValueChanged<String> search) {
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

  Widget _buildAnswerSection(MemorizeController controller, dynamic question) {
    final isClean = controller.cardStyle.value == 'clean';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!isClean) ...[
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
        ],
        ..._buildAnswerOptions(controller, question),
      ],
    );
  }

  List<Widget> _buildAnswerOptions(
    MemorizeController controller,
    dynamic question,
  ) {
    final options = question.options;
    final labels = question.optionLabels;
    final correctAnswer = question.answer.toUpperCase();
    final isClean = controller.cardStyle.value == 'clean';
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
                child: isClean && isCorrect
                    ? _buildSelectableCorrectOption(
                        controller,
                        question.questionId,
                        options[i],
                      )
                    : Text(
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

  /// 简洁样式下正确选项文本：支持选取并添加底色标注。
  Widget _buildSelectableCorrectOption(
    MemorizeController controller,
    String questionId,
    String text,
  ) {
    final baseStyle = TextStyle(
      fontSize: 14,
      height: 1.4,
      color: Colors.green.shade500,
    );
    return Obx(() {
      final highlights = controller.highlightsFor(questionId);
      return SelectableText.rich(
        _buildHighlightedSpan(text, highlights),
        style: baseStyle,
        contextMenuBuilder: (context, editableTextState) {
          final items = editableTextState.contextMenuButtonItems;
          final selection = editableTextState.textEditingValue.selection;
          if (!selection.isCollapsed) {
            final start = selection.start;
            final end = selection.end;
            final hasOverlap = highlights.any((h) => h.overlaps(start, end));
            items.add(
              ContextMenuButtonItem(
                label: '标注',
                onPressed: () {
                  editableTextState.hideToolbar();
                  controller.addHighlight(questionId, start, end);
                  _collapseSelection(editableTextState);
                },
              ),
            );
            if (hasOverlap) {
              items.add(
                ContextMenuButtonItem(
                  label: '取消标注',
                  onPressed: () {
                    editableTextState.hideToolbar();
                    controller.removeHighlights(questionId, start, end);
                    _collapseSelection(editableTextState);
                  },
                ),
              );
            }
          }
          return AdaptiveTextSelectionToolbar.buttonItems(
            anchors: editableTextState.contextMenuAnchors,
            buttonItems: items,
          );
        },
      );
    });
  }

  void _collapseSelection(EditableTextState state) {
    final value = state.textEditingValue;
    state.userUpdateTextEditingValue(
      value.copyWith(
        selection: TextSelection.collapsed(offset: value.selection.end),
      ),
      SelectionChangedCause.toolbar,
    );
  }

  TextSpan _buildHighlightedSpan(String text, List<TextHighlight> highlights) {
    final sorted = [...highlights]..sort((a, b) => a.start.compareTo(b.start));
    final children = <TextSpan>[];
    int pos = 0;
    for (final h in sorted) {
      final s = h.start.clamp(0, text.length);
      final e = h.end.clamp(s, text.length);
      if (s > pos) {
        children.add(TextSpan(text: text.substring(pos, s)));
      }
      if (e > s) {
        children.add(
          TextSpan(
            text: text.substring(s, e),
            style: TextStyle(
              color: Colors.black87,
              backgroundColor: _parseHighlightColor(h.color),
            ),
          ),
        );
      }
      if (e > pos) pos = e;
    }
    if (pos < text.length) {
      children.add(TextSpan(text: text.substring(pos)));
    }
    return TextSpan(children: children);
  }

  Color _parseHighlightColor(String colorStr) {
    try {
      if (colorStr.startsWith('#')) {
        return Color(int.parse('FF${colorStr.substring(1)}', radix: 16));
      }
    } catch (_) {}
    return const Color(0xFFFFF176);
  }

  /// 覆盖整个题目卡片的自由圈画图层。
  Widget _buildAnnotationLayer(
    MemorizeController controller,
    dynamic question,
  ) {
    return Positioned.fill(
      child: Obx(() {
        final annotating = controller.isAnnotating.value;
        return IgnorePointer(
          ignoring: !annotating,
          child: RawGestureDetector(
            behavior: HitTestBehavior.opaque,
            gestures: <Type, GestureRecognizerFactory>{
              EagerGestureRecognizer:
                  GestureRecognizerFactoryWithHandlers<EagerGestureRecognizer>(
                    EagerGestureRecognizer.new,
                    (_) {},
                  ),
            },
            child: Listener(
              behavior: HitTestBehavior.opaque,
              onPointerDown: (event) {
                if (_activeAnnotationPointer != null) return;
                _activeAnnotationPointer = event.pointer;
                setState(() {
                  _currentStrokePoints
                    ..clear()
                    ..add(
                      StrokePoint(
                        x: event.localPosition.dx,
                        y: event.localPosition.dy,
                      ),
                    );
                });
              },
              onPointerMove: (event) {
                if (_activeAnnotationPointer != event.pointer) return;
                setState(() {
                  _currentStrokePoints.add(
                    StrokePoint(
                      x: event.localPosition.dx,
                      y: event.localPosition.dy,
                    ),
                  );
                });
              },
              onPointerUp: (event) {
                if (_activeAnnotationPointer != event.pointer) return;
                controller.addAnnotationStroke(
                  question.questionId,
                  List.from(_currentStrokePoints),
                );
                setState(() {
                  _activeAnnotationPointer = null;
                  _currentStrokePoints.clear();
                });
              },
              onPointerCancel: (event) {
                if (_activeAnnotationPointer != event.pointer) return;
                setState(() {
                  _activeAnnotationPointer = null;
                  _currentStrokePoints.clear();
                });
              },
              child: CustomPaint(
                painter: HandwritingPainter(
                  strokes: controller.strokesFor(question.questionId),
                  currentStrokePoints: _currentStrokePoints,
                  currentColor: controller.currentAnnotationColor.value,
                  currentStrokeWidth:
                      controller.currentAnnotationStrokeWidth.value,
                ),
                size: Size.infinite,
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildAnnotationToolbar(MemorizeController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ...controller.annotationColors.map(
                    (color) => _buildAnnotationColorButton(controller, color),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 1,
                    height: 24,
                    color: Get.theme.dividerColor,
                  ),
                  const SizedBox(width: 12),
                  ...controller.annotationStrokeWidths.map(
                    (width) => _buildAnnotationWidthButton(controller, width),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          _buildAnnotationToolButton(
            icon: Icons.undo_rounded,
            tooltip: '撤销',
            onTap: () => controller.undoAnnotationStroke(
              controller.undoTargetQuestionId,
            ),
          ),
          const SizedBox(width: 8),
          _buildAnnotationToolButton(
            icon: Icons.delete_outline_rounded,
            tooltip: '清空圈画',
            onTap: () => controller.clearAnnotationStrokes(
              controller.undoTargetQuestionId,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnnotationColorButton(
    MemorizeController controller,
    Color color,
  ) {
    return Obx(() {
      final isSelected =
          controller.currentAnnotationColor.value.toARGB32() ==
          color.toARGB32();
      return GestureDetector(
        onTap: () => controller.setAnnotationColor(color),
        child: Container(
          width: 28,
          height: 28,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: isSelected
                  ? Get.theme.colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 3 : 1,
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAnnotationWidthButton(
    MemorizeController controller,
    double width,
  ) {
    return Obx(() {
      final isSelected = controller.currentAnnotationStrokeWidth.value == width;
      return GestureDetector(
        onTap: () => controller.setAnnotationStrokeWidth(width),
        child: Container(
          width: 32,
          height: 32,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? Get.theme.colorScheme.primary.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? Get.theme.colorScheme.primary
                  : Colors.grey.shade300,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Center(
            child: Container(
              width: width * 2,
              height: width * 2,
              decoration: BoxDecoration(
                color: isSelected ? Get.theme.colorScheme.primary : Colors.grey,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildAnnotationToolButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Get.theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Get.theme.dividerColor),
        ),
        child: Icon(
          icon,
          size: 20,
          color: Get.theme.textTheme.bodyMedium?.color,
        ),
      ),
    );
  }

  Widget _buildBottomBar(MemorizeController controller) {
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

  Future<void> _showAnswerCard(
    MemorizeController controller, {
    bool showMasteredInitially = false,
  }) async {
    final db = DatabaseHelper();
    final scopedQuestions = controller.allScopedQuestions;
    final questionIds = scopedQuestions.map((q) => q.questionId).toList();
    final bankId = scopedQuestions.isNotEmpty
        ? scopedQuestions.first.bankId
        : null;
    final withRelated = await db.getQuestionIdsWithRelated(
      questionIds,
      bankId: bankId,
    );
    final withNotes = await db.getQuestionIdsWithNotes(questionIds);
    if (!mounted) return;
    final showMastered = showMasteredInitially.obs;

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
                        '共 ${scopedQuestions.length} 题',
                        style: TextStyle(
                          fontSize: 14,
                          color: Get.theme.textTheme.bodySmall!.color,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment<bool>(
                            value: false,
                            icon: Icon(Icons.grid_view_rounded),
                            label: Text('待背题目'),
                          ),
                          ButtonSegment<bool>(
                            value: true,
                            icon: Icon(Icons.task_alt_rounded),
                            label: Text('已掌握'),
                          ),
                        ],
                        selected: {showMastered.value},
                        onSelectionChanged: (selection) {
                          showMastered.value = selection.first;
                        },
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Obx(
                  () => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: showMastered.value
                        ? const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '取消掌握后，题目会重新回到背题队列',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        : Wrap(
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              _buildLegend(
                                Get.theme.colorScheme.primary.withValues(
                                  alpha: 0.15,
                                ),
                                Get.theme.colorScheme.primary,
                                '当前题',
                              ),
                              _buildLegend(
                                Colors.grey.shade100,
                                Colors.grey.shade600,
                                '待背',
                              ),
                              _buildDotLegend(Colors.teal, '合集'),
                              _buildDotLegend(Colors.amber.shade700, '笔记'),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
                Expanded(
                  child: Obx(() {
                    if (showMastered.value) {
                      return _buildMasteredQuestionList(
                        controller,
                        scrollController,
                      );
                    }
                    return CurrentQuestionGrid(
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
                        Color bgColor;
                        Color textColor;
                        Color borderColor;

                        if (isCurrent) {
                          bgColor = Get.theme.colorScheme.primary.withValues(
                            alpha: 0.15,
                          );
                          textColor = Get.theme.colorScheme.primary;
                          borderColor = Get.theme.colorScheme.primary;
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
                                width: isCurrent ? 2 : 1,
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
                    );
                  }),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildMasteredQuestionList(
    MemorizeController controller,
    ScrollController scrollController,
  ) {
    if (controller.masteredQuestions.isEmpty) {
      return const Center(child: Text('暂无已掌握题目'));
    }
    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      itemCount: controller.masteredQuestions.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final question = controller.masteredQuestions[index];
        final originalIndex = controller.allScopedQuestions.indexWhere(
          (item) => item.questionId == question.questionId,
        );
        return Card(
          margin: EdgeInsets.zero,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.green.shade100,
              foregroundColor: Colors.green.shade800,
              child: Text('${originalIndex + 1}'),
            ),
            title: Text(
              question.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle: const Text('已从背题队列暂时隐藏'),
            trailing: OutlinedButton.icon(
              onPressed: controller.isUpdatingMastered.value
                  ? null
                  : () => controller.restoreMasteredQuestion(question),
              icon: const Icon(Icons.undo_rounded, size: 18),
              label: const Text('取消掌握'),
            ),
          ),
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
}
