import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/question_model.dart';
import 'collection_mind_map_view.dart';

/// Lets the user decide exactly which questions are sent to AI.
class CollectionMindMapSelectionView extends StatefulWidget {
  const CollectionMindMapSelectionView({
    super.key,
    required this.keyword,
    required this.questions,
  });

  final String keyword;
  final List<Question> questions;

  @override
  State<CollectionMindMapSelectionView> createState() =>
      _CollectionMindMapSelectionViewState();
}

class _CollectionMindMapSelectionViewState
    extends State<CollectionMindMapSelectionView> {
  late final Set<int> _selectedIndexes;

  @override
  void initState() {
    super.initState();
    _selectedIndexes = Set<int>.from(
      List<int>.generate(widget.questions.length, (index) => index),
    );
  }

  bool get _allSelected =>
      widget.questions.isNotEmpty &&
      _selectedIndexes.length == widget.questions.length;

  void _toggleAll() {
    setState(() {
      if (_allSelected) {
        _selectedIndexes.clear();
      } else {
        _selectedIndexes.addAll(
          List<int>.generate(widget.questions.length, (index) => index),
        );
      }
    });
  }

  void _toggleQuestion(int index) {
    setState(() {
      if (!_selectedIndexes.add(index)) {
        _selectedIndexes.remove(index);
      }
    });
  }

  void _generate() {
    if (_selectedIndexes.isEmpty) return;
    final selectedQuestions = _selectedIndexes.toList()..sort();
    Get.to(
      () => CollectionMindMapView(
        keyword: widget.keyword,
        questions: selectedQuestions
            .map((index) => widget.questions[index])
            .toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('选择导图题目')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.keyword,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '已选择 ${_selectedIndexes.length} / ${widget.questions.length} 道题目',
                        style: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: widget.questions.isEmpty ? null : _toggleAll,
                  icon: Icon(
                    _allSelected
                        ? Icons.deselect_rounded
                        : Icons.select_all_rounded,
                    size: 19,
                  ),
                  label: Text(_allSelected ? '取消全选' : '全选'),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 8),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '仅将所选题目的内容用于 AI 分析，题目编号不会发送。',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
              physics: const BouncingScrollPhysics(),
              itemCount: widget.questions.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final question = widget.questions[index];
                final isSelected = _selectedIndexes.contains(index);
                return _QuestionSelectionCard(
                  key: ValueKey('mind-map-question-$index'),
                  question: question,
                  selected: isSelected,
                  onTap: () => _toggleQuestion(index),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          height: 50,
          child: FilledButton.icon(
            onPressed: _selectedIndexes.isEmpty ? null : _generate,
            icon: const Icon(Icons.auto_awesome_rounded),
            label: Text('生成思维导图（${_selectedIndexes.length}）'),
          ),
        ),
      ),
    );
  }
}

class _QuestionSelectionCard extends StatelessWidget {
  const _QuestionSelectionCard({
    super.key,
    required this.question,
    required this.selected,
    required this.onTap,
  });

  final Question question;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final typeColor = question.isJudge
        ? const Color(0xFF7C3AED)
        : const Color(0xFF2563EB);
    return Material(
      color: selected
          ? scheme.primaryContainer.withValues(alpha: 0.28)
          : scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.42)
                  : scheme.outlineVariant.withValues(alpha: 0.55),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: selected,
                onChanged: (_) => onTap(),
                visualDensity: VisualDensity.compact,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: typeColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        question.isJudge ? '判断题' : '单选题',
                        style: TextStyle(
                          color: typeColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      question.content,
                      style: const TextStyle(fontSize: 15, height: 1.55),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
