import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'collection_controller.dart';
import '../../core/routes/routes.dart';
import '../../data/models/question_model.dart';

class CollectionListView extends StatefulWidget {
  const CollectionListView({super.key});

  @override
  State<CollectionListView> createState() => _CollectionListViewState();
}

class _CollectionListViewState extends State<CollectionListView> {
  final CollectionController controller = Get.put(CollectionController());
  final TextEditingController _searchEditingController =
      TextEditingController();

  @override
  void dispose() {
    _searchEditingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final total = controller.collections.length;
          final filtered = controller.filteredCollections.length;
          final isSearching = controller.searchQuery.value.trim().isNotEmpty;
          return Text(isSearching ? '我的合集 ($filtered/$total)' : '我的合集 ($total)');
        }),
      ),
      body: Obx(() {
        if (controller.isLoading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildCollectionList(controller);
      }),
    );
  }

  Widget _buildCollectionList(CollectionController controller) {
    return RefreshIndicator(
      onRefresh: controller.loadCollections,
      child: ListView(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(
          parent: BouncingScrollPhysics(),
        ),
        children: [
          _buildJudgeCollectionCreator(controller),
          const SizedBox(height: 22),
          _buildSearchField(controller),
          const SizedBox(height: 14),
          _buildSectionTitle('已创建合集'),
          const SizedBox(height: 10),
          if (controller.collections.isEmpty)
            _buildEmptyState()
          else if (controller.filteredCollections.isEmpty)
            _buildNoResultState(controller)
          else
            ...controller.filteredCollections.map(
              (collection) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildCollectionCard(controller, collection),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchField(CollectionController controller) {
    return TextField(
      controller: _searchEditingController,
      onChanged: (value) => controller.searchQuery.value = value,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: '搜索合集名称',
        prefixIcon: const Icon(Icons.search_rounded),
        isDense: true,
        filled: true,
        fillColor: Get.theme.cardColor,
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        suffixIcon: Obx(() {
          if (controller.searchQuery.value.isEmpty) {
            return const SizedBox.shrink();
          }
          return IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              _searchEditingController.clear();
              controller.searchQuery.value = '';
            },
            icon: const Icon(Icons.clear_rounded, size: 20),
          );
        }),
      ),
    );
  }

  Widget _buildNoResultState(CollectionController controller) {
    final keyword = controller.searchQuery.value.trim();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 12),
          const Text(
            '未找到匹配的合集',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          Text(
            '没有名称包含“$keyword”的合集，换个关键词试试',
            style: const TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildJudgeCollectionCreator(CollectionController controller) {
    final correctCreated = controller.collectionCountFor(true);
    final wrongCreated = controller.collectionCountFor(false);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.theme.colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Get.theme.colorScheme.primary.withValues(alpha: 0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Get.theme.colorScheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.rule_folder_rounded,
                  size: 20,
                  color: Get.theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '默认题库判断题',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Get.theme.textTheme.bodyLarge!.color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '按标准答案一键创建合集，重复操作会同步最新题目',
                      style: TextStyle(
                        fontSize: 12,
                        color: Get.theme.textTheme.bodySmall!.color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _buildJudgePresetRow(
            controller: controller,
            answerIsCorrect: true,
            availableCount: controller.correctJudgeCount.value,
            createdCount: correctCreated,
          ),
          const SizedBox(height: 10),
          _buildJudgePresetRow(
            controller: controller,
            answerIsCorrect: false,
            availableCount: controller.wrongJudgeCount.value,
            createdCount: wrongCreated,
          ),
        ],
      ),
    );
  }

  Widget _buildJudgePresetRow({
    required CollectionController controller,
    required bool answerIsCorrect,
    required int availableCount,
    required int createdCount,
  }) {
    final color = answerIsCorrect
        ? const Color(0xFF0D9488)
        : const Color(0xFFF97316);
    final label = answerIsCorrect ? '答案正确' : '答案错误';
    final isSyncing = controller.syncingJudgeAnswer.value == answerIsCorrect;
    final hasCollection = createdCount > 0;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            answerIsCorrect ? Icons.check_circle_rounded : Icons.cancel_rounded,
            size: 22,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Get.theme.textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  hasCollection
                      ? '默认题库 $availableCount 道 · 合集已收录 $createdCount 道'
                      : '默认题库共 $availableCount 道',
                  style: TextStyle(
                    fontSize: 11,
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton.tonal(
            onPressed:
                availableCount == 0 ||
                    controller.syncingJudgeAnswer.value != null
                ? null
                : () => controller.createJudgeCollection(answerIsCorrect),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            child: isSyncing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(hasCollection ? '同步' : '创建合集'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: Get.theme.textTheme.bodyLarge!.color,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: [
          Icon(
            Icons.collections_bookmark_outlined,
            size: 48,
            color: Colors.teal.shade300,
          ),
          const SizedBox(height: 12),
          const Text(
            '暂无合集',
            style: TextStyle(fontSize: 15, color: Colors.grey),
          ),
          const SizedBox(height: 6),
          const Text(
            '可在上方按判断题答案创建，或在题目详情页搜索关键词添加关联题目',
            style: TextStyle(fontSize: 12, color: Colors.grey),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCollectionCard(
    CollectionController controller,
    CollectionInfo collection,
  ) {
    const color = Color(0xFF0D9488);
    final isDeleting = controller.deletingKeyword.value == collection.keyword;
    return Card(
      child: InkWell(
        onTap: () =>
            Get.toNamed(Routes.collectionDetail, arguments: collection.keyword),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.collections_bookmark_rounded,
                  size: 22,
                  color: color,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      collection.keyword,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Get.theme.textTheme.bodyLarge!.color,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '收录 ${collection.questionCount} 道题目',
                      style: TextStyle(
                        fontSize: 12,
                        color: Get.theme.textTheme.bodySmall!.color,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${collection.questionCount}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 2),
              IconButton(
                onPressed: controller.deletingKeyword.value == null
                    ? () => _confirmDeleteCollection(controller, collection)
                    : null,
                tooltip: '删除合集',
                icon: isDeleting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.delete_outline_rounded, size: 20),
                color: Get.theme.colorScheme.error,
                visualDensity: VisualDensity.compact,
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Get.theme.textTheme.bodySmall!.color,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDeleteCollection(
    CollectionController controller,
    CollectionInfo collection,
  ) async {
    final confirmed = await Get.dialog<bool>(
      AlertDialog(
        title: const Text('删除合集？'),
        content: Text(
          '将删除“${collection.keyword}”及其 ${collection.questionCount} 条收录关系。题库原题、笔记和学习记录不会被删除。',
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(result: false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Get.back(result: true),
            style: FilledButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.error,
              foregroundColor: Get.theme.colorScheme.onError,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await controller.deleteCollection(collection.keyword);
    }
  }
}
