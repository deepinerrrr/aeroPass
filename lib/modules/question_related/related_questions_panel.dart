import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data/database/database_helper.dart';
import '../../data/models/question_model.dart';
import '../question_detail/question_detail_view.dart';

typedef RelatedQuestionBuilder =
    Widget Function(
      BuildContext context,
      Question question,
      bool isPrimary,
      ValueChanged<String> search,
      List<ParentQuestionInfo> parentQuestions,
    );

class RelatedQuestionsPager extends StatefulWidget {
  final Question currentQuestion;
  final Axis primarySwipeDirection;
  final RelatedQuestionBuilder itemBuilder;

  const RelatedQuestionsPager({
    super.key,
    required this.currentQuestion,
    required this.primarySwipeDirection,
    required this.itemBuilder,
  });

  @override
  State<RelatedQuestionsPager> createState() => _RelatedQuestionsPagerState();
}

class _RelatedQuestionsPagerState extends State<RelatedQuestionsPager> {
  final _db = DatabaseHelper();
  final List<Question> _relatedQuestions = [];
  final Map<String, List<ParentQuestionInfo>> _parentMap = {};
  int _currentPage = 0;
  bool _isLoading = true;

  Axis get _relatedDirection => widget.primarySwipeDirection == Axis.vertical
      ? Axis.horizontal
      : Axis.vertical;

  @override
  void initState() {
    super.initState();
    _loadRelatedQuestions();
  }

  @override
  void didUpdateWidget(covariant RelatedQuestionsPager oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentQuestion.questionId != widget.currentQuestion.questionId ||
        oldWidget.currentQuestion.bankId != widget.currentQuestion.bankId) {
      _loadRelatedQuestions();
    }
  }

  Future<void> _loadRelatedQuestions() async {
    if (mounted) setState(() => _isLoading = true);
    final loaded = await _db.getRelatedQuestions(
      widget.currentQuestion.questionId,
      bankId: widget.currentQuestion.bankId,
    );
    final allIds = [
      widget.currentQuestion.questionId,
      ...loaded.map((e) => e.questionId),
    ];
    final map = await _db.getBulkParentQuestions(
      allIds,
      bankId: widget.currentQuestion.bankId,
    );
    if (!mounted) return;
    setState(() {
      _relatedQuestions
        ..clear()
        ..addAll(loaded);
      _parentMap
        ..clear()
        ..addAll(map);
      _currentPage = 0;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final questions = [widget.currentQuestion, ..._relatedQuestions];
    return Stack(
      children: [
        PageView.builder(
          key: PageStorageKey('related_${widget.currentQuestion.questionId}'),
          scrollDirection: _relatedDirection,
          itemCount: questions.length,
          onPageChanged: (index) => setState(() => _currentPage = index),
          itemBuilder: (context, index) => widget.itemBuilder(
            context,
            questions[index],
            index == 0,
            _showSearchDialog,
            _parentMap[questions[index].questionId] ?? const [],
          ),
        ),
        if (_isLoading)
          const Positioned.fill(
            child: ColoredBox(
              color: Colors.transparent,
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
        if (questions.length > 1)
          Positioned(
            top: 8,
            right: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Get.theme.colorScheme.primary.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${_currentPage + 1}/${questions.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showSearchDialog(String initialKeyword) async {
    final searchController = TextEditingController(text: initialKeyword.trim());
    final selected = <String, Question>{
      for (final question in _relatedQuestions) question.questionId: question,
    };
    final selectedKeywords = <String, String>{};
    var lastSearchKeyword = initialKeyword.trim();
    var results = <Question>[];
    var parentMap = <String, List<ParentQuestionInfo>>{};
    var loading = false;
    var hasSearched = false;
    var saving = false;

    void selectQuestion(Question q) {
      selected[q.questionId] = q;
      if (lastSearchKeyword.isNotEmpty) {
        selectedKeywords[q.questionId] = lastSearchKeyword;
      }
    }

    void deselectQuestion(String qid) {
      selected.remove(qid);
      selectedKeywords.remove(qid);
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> search() async {
            final keyword = searchController.text.trim();
            if (keyword.isEmpty) return;
            lastSearchKeyword = keyword;
            setDialogState(() {
              loading = true;
              hasSearched = true;
            });
            final matches = await _db.searchQuestions(
              keyword,
              bankId: widget.currentQuestion.bankId,
            );
            final ids = matches.map((e) => e.questionId).toList();
            final map = await _db.getBulkParentQuestions(
              ids,
              bankId: widget.currentQuestion.bankId,
            );
            if (!ctx.mounted) return;
            setDialogState(() {
              results = matches;
              parentMap = map;
              loading = false;
            });
          }

          if (!hasSearched && searchController.text.trim().isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) => search());
          }

          return AlertDialog(
            insetPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 24,
            ),
            titlePadding: const EdgeInsets.fromLTRB(20, 18, 12, 8),
            contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            title: Row(
              children: [
                const Expanded(
                  child: Text('搜索并添加关联题目', style: TextStyle(fontSize: 18)),
                ),
                IconButton(
                  onPressed: saving ? null : () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded),
                  tooltip: '关闭',
                ),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.sizeOf(context).height * 0.68,
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: searchController,
                          autofocus: initialKeyword.isEmpty,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => search(),
                          decoration: const InputDecoration(
                            hintText: '输入题干或题号关键词',
                            prefixIcon: Icon(Icons.search_rounded),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: loading ? null : search,
                        icon: const Icon(Icons.search_rounded),
                        tooltip: '搜索',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (loading) const LinearProgressIndicator(minHeight: 2),
                  if (hasSearched && !loading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '找到 ${results.length} 道题目，已选择 ${selected.length} 道',
                              style: TextStyle(
                                fontSize: 12,
                                color: Get.theme.textTheme.bodySmall?.color,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => setDialogState(() {
                              for (final q in results) {
                                if (q.questionId !=
                                    widget.currentQuestion.questionId) {
                                  selectQuestion(q);
                                }
                              }
                            }),
                            icon: const Icon(
                              Icons.done_all_rounded,
                              size: 16,
                            ),
                            label: const Text('全选'),
                            style: TextButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 6),
                  Expanded(
                    child: !hasSearched
                        ? const Center(child: Text('输入关键词搜索题库'))
                        : results.isEmpty && !loading
                        ? const Center(child: Text('未找到含有该关键词的其他题目'))
                        : ListView.builder(
                            itemCount: results.length,
                            itemBuilder: (context, index) {
                              final question = results[index];
                              final checked = selected.containsKey(
                                question.questionId,
                              );
                              final isCurrent =
                                  question.questionId ==
                                  widget.currentQuestion.questionId;
                              final parents =
                                  parentMap[question.questionId] ?? const [];
                              final otherParents = parents
                                  .where(
                                    (p) =>
                                        p.question.questionId !=
                                        widget.currentQuestion.questionId,
                                  )
                                  .toList();
                              return Card(
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    CheckboxListTile(
                                      value: checked,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                      title: Text(
                                        question.content,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      subtitle: Text(
                                        isCurrent
                                            ? 'No.${question.questionId} · 当前题目'
                                            : 'No.${question.questionId}',
                                      ),
                                      onChanged: isCurrent
                                          ? null
                                          : (_) => setDialogState(() {
                                              if (checked) {
                                                deselectQuestion(
                                                  question.questionId,
                                                );
                                              } else {
                                                selectQuestion(question);
                                              }
                                            }),
                                    ),
                                    if (otherParents.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          8,
                                        ),
                                        child: Wrap(
                                          spacing: 6,
                                          runSpacing: 4,
                                          children: [
                                            for (final p in otherParents)
                                              InkWell(
                                                borderRadius:
                                                    BorderRadius.circular(
                                                      12,
                                                    ),
                                                onTap: () {
                                                  Navigator.pop(ctx);
                                                  Get.to(() =>
                                                      QuestionDetailView(
                                                        question: p.question,
                                                      ));
                                                },
                                                child: _CollectionChip(
                                                  info: p,
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => setDialogState(() {
                  selected.clear();
                  selectedKeywords.clear();
                }),
                child: const Text('清空选择'),
              ),
              FilledButton.icon(
                onPressed: saving
                    ? null
                    : () async {
                        setDialogState(() => saving = true);
                        final nextRelated = selected.values.toList();
                        try {
                          await _db.saveRelatedQuestions(
                            widget.currentQuestion.questionId,
                            nextRelated,
                            bankId: widget.currentQuestion.bankId,
                            keywords: selectedKeywords,
                          );
                          if (!mounted || !ctx.mounted) return;
                          setState(() {
                            _relatedQuestions
                              ..clear()
                              ..addAll(nextRelated);
                            if (_currentPage > _relatedQuestions.length) {
                              _currentPage = 0;
                            }
                          });
                          Navigator.pop(ctx);
                        } catch (_) {
                          if (ctx.mounted) {
                            setDialogState(() => saving = false);
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              const SnackBar(content: Text('关联题目保存失败，请重试')),
                            );
                          }
                        }
                      },
                icon: const Icon(Icons.add_rounded),
                label: Text('添加 (${selected.length})'),
              ),
            ],
          );
        },
      ),
    );
    searchController.dispose();
  }
}

class QuestionSearchField extends StatefulWidget {
  final ValueChanged<String> onSearch;
  const QuestionSearchField({super.key, required this.onSearch});

  @override
  State<QuestionSearchField> createState() => _QuestionSearchFieldState();
}

class _QuestionSearchFieldState extends State<QuestionSearchField> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 138,
      height: 34,
      child: TextField(
        controller: _controller,
        textInputAction: TextInputAction.search,
        onSubmitted: (value) {
          widget.onSearch(value);
          _controller.clear();
        },
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(
          hintText: '搜索题库',
          isDense: true,
          prefixIcon: const Icon(Icons.search_rounded, size: 17),
          prefixIconConstraints: const BoxConstraints(minWidth: 32),
          contentPadding: const EdgeInsets.symmetric(vertical: 8),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: Get.theme.dividerColor),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: Get.theme.dividerColor),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(999),
            borderSide: BorderSide(color: Get.theme.colorScheme.primary),
          ),
        ),
      ),
    );
  }
}

/// 灰度矩阵：标准NTSC灰度转换。
const ColorFilter kGrayscaleFilter = ColorFilter.matrix(<double>[
  0.299, 0.587, 0.114, 0, 0,
  0.299, 0.587, 0.114, 0, 0,
  0.299, 0.587, 0.114, 0, 0,
  0, 0, 0, 1, 0,
]);

/// 对已收录到合集的题目内容使用置灰效果：灰度 + 降低不透明度，使"已收录"状态更明显。
Widget buildGrayedContent(Widget child) {
  return Opacity(
    opacity: 0.55,
    child: ColorFiltered(
      colorFilter: kGrayscaleFilter,
      child: child,
    ),
  );
}

/// 合集来源胶囊芯片：展示"收录于 No.X · 关键词"，点击可跳转到父题目。
/// 用于搜索弹窗结果列表和卡片内角标区域。
class _CollectionChip extends StatelessWidget {
  final ParentQuestionInfo info;
  const _CollectionChip({required this.info});

  @override
  Widget build(BuildContext context) {
    final kw = info.keywords.trim();
    final hasKw = kw.isNotEmpty;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.bookmark_added_rounded,
            size: 13,
            color: Colors.teal.shade700,
          ),
          const SizedBox(width: 4),
          Text(
            'No.${info.question.questionId}',
            style: TextStyle(
              fontSize: 11,
              color: Colors.teal.shade800,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hasKw) ...[
            Text(
              ' · ',
              style: TextStyle(fontSize: 11, color: Colors.teal.shade600),
            ),
            Text(
              kw,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: Colors.teal.shade700,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          const SizedBox(width: 2),
          Icon(
            Icons.arrow_forward_rounded,
            size: 12,
            color: Colors.teal.shade700,
          ),
        ],
      ),
    );
  }
}

/// 合集角标条：置于题目卡片 header 下方、题干上方（内容流内，非浮层），
/// 展示当前题目被哪些合集收录（父题目编号 + 创建关键词），点击可跳转。
/// 自身保持彩色，与下方置灰的题干/选项形成鲜明对比。
class CollectionBadgeBar extends StatelessWidget {
  final List<ParentQuestionInfo> parents;
  final ValueChanged<Question>? onTap;
  const CollectionBadgeBar({super.key, required this.parents, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (parents.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.teal.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.teal.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.layers_rounded,
              size: 16,
              color: Colors.teal.shade700,
            ),
            const SizedBox(width: 6),
            Text(
              '已收录于合集',
              style: TextStyle(
                fontSize: 12,
                color: Colors.teal.shade800,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  for (final p in parents)
                    InkWell(
                      borderRadius: BorderRadius.circular(999),
                      onTap: onTap == null ? null : () => onTap!(p.question),
                      child: _CollectionChip(info: p),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
