import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'question_bank_controller.dart';
import '../../core/theme/app_theme.dart';

class QuestionBankView extends StatelessWidget {
  const QuestionBankView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(QuestionBankController());

    return Scaffold(
      body: SafeArea(
        child: Obx(() {
          if (controller.isImporting.value) {
            return _buildImportingView(controller);
          }
          return _buildMainContent(controller);
        }),
      ),
    );
  }

  Widget _buildImportingView(QuestionBankController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              controller.importProgress.value.isEmpty
                  ? '正在导入题库...'
                  : controller.importProgress.value,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Get.theme.textTheme.bodyLarge!.color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(QuestionBankController controller) {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: _buildHeader()),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _buildImportButton(controller),
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _buildAdvancedFilterCard(controller),
          ),
        ),
        SliverToBoxAdapter(child: const SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: _buildSectionTitle('题库列表'),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 12)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: Obx(
            () => SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final bank = controller.banks[index];
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _buildBankCard(bank, controller),
                );
              }, childCount: controller.banks.length),
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Get.back(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Get.theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_rounded,
                size: 20,
                color: Get.theme.colorScheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '题库管理',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: Get.theme.textTheme.headlineLarge!.color,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '管理你的题库，导入新题库',
                  style: TextStyle(
                    fontSize: 13,
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImportButton(QuestionBankController controller) {
    return GestureDetector(
      onTap: () => _showImportFormatGuide(controller),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Get.theme.colorScheme.primary,
              Get.theme.colorScheme.primary.withValues(alpha: 0.8),
            ],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Get.theme.colorScheme.primary.withValues(alpha: 0.25),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.upload_file_rounded,
                size: 24,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '导入题库',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '选择 .xlsx 文件导入新题库',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.add_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showImportFormatGuide(QuestionBankController controller) async {
    const columns = [
      ('A', '题目内容', '必填，纯文本，不得为空'),
      ('B', '正确答案', '必填，仅限 A、B、C、D；判断题也可填“正确/错误”或“对/错”'),
      ('C', '题目编号', '必填，文本或数字均可；文件内不得重复'),
      ('D', '选项 A', '必填，填写选项正文'),
      ('E', '选项 B', '必填，填写选项正文'),
      ('F', '选项 C', '选择题按需填写；判断题留空'),
      ('G', '选项 D', '选择题按需填写；判断题留空'),
    ];

    final shouldChooseFile = await Get.dialog<bool>(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 4),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Get.theme.colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.table_view_rounded,
                size: 20,
                color: Get.theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Excel 导入格式规范')),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '仅支持 .xlsx 文件。每个工作表都按下列 A–G 列读取，第一行请直接填写题目数据，不要添加表头。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                ),
                const SizedBox(height: 14),
                ...columns.map(
                  (column) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 28,
                          height: 28,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Get.theme.colorScheme.primary.withValues(
                              alpha: 0.08,
                            ),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            column.$1,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: Get.theme.colorScheme.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                column.$2,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Get.theme.textTheme.bodyLarge!.color,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                column.$3,
                                style: TextStyle(
                                  fontSize: 12,
                                  height: 1.4,
                                  color: Get.theme.textTheme.bodySmall!.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '填写示例',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Get.theme.textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Get.theme.scaffoldBackgroundColor,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Get.theme.dividerColor),
                  ),
                  child: Text(
                    '选择题：\n航空器在管制空域内飞行时应遵守？ | A | 20101001 | 管制规则 | 目视飞行规则 | 通用飞行规则 | 其他规则\n\n'
                    '判断题：\n飞行人员必须持有效执照执行任务 | 正确 | 20101002 | 正确 | 错误 | （留空） | （留空）',
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: Get.theme.textTheme.bodySmall!.color,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '导入前会校验必填项、答案范围、选项对应关系和重复编号；发现问题时不会写入不完整题库。',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: Get.theme.colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton.icon(
            onPressed: () => Get.back(result: true),
            icon: const Icon(Icons.folder_open_rounded, size: 18),
            label: const Text('选择 .xlsx 文件'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
        ],
      ),
    );
    if (shouldChooseFile == true) {
      await controller.importFromExcel();
    }
  }

  Widget _buildAdvancedFilterCard(QuestionBankController controller) {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      borderRadius: 16,
      tintColor: const Color(0xFF6C4D7E).withValues(alpha: 0.05),
      child: Obx(() {
        final enabled = controller.isAutoFilterEnabled.value;
        final total = controller.activeBankTotal.value;
        final longest = controller.longestAnswerCount.value;
        final effective = controller.effectiveCount;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.auto_fix_high_rounded,
                    size: 20,
                    color: Color(0xFF8B5CF6),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '高级筛选',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Get.theme.textTheme.bodyLarge!.color,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '自动隐藏“正确答案为最长选项”的题目',
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
            Row(
              children: [
                _buildFilterStat(
                  '题库总量',
                  '$total',
                  Get.theme.textTheme.bodySmall!.color!,
                ),
                _buildFilterStat(
                  '答案最长',
                  '$longest',
                  longest > 0
                      ? const Color(0xFF8B5CF6)
                      : Get.theme.textTheme.bodySmall!.color!,
                ),
                _buildFilterStat(
                  '生效题数',
                  '$effective',
                  enabled
                      ? Get.theme.colorScheme.primary
                      : Get.theme.textTheme.bodySmall!.color!,
                  highlight: enabled,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Get.theme.scaffoldBackgroundColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Get.theme.dividerColor),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '隐藏答案最长题',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Get.theme.textTheme.bodyLarge!.color,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          enabled
                              ? '已开启：刷题/背题/模考/错题/收藏中将不再出现这类题目'
                              : '关闭后全部题目正常出现，可在搜索中查看标注',
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.4,
                            color: Get.theme.textTheme.bodySmall!.color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch.adaptive(
                    value: enabled,
                    activeTrackColor: Get.theme.colorScheme.primary,
                    onChanged: (v) => controller.toggleAutoFilter(v),
                  ),
                ],
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildFilterStat(
    String label,
    String value,
    Color color, {
    bool highlight = false,
  }) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: highlight
              ? Get.theme.colorScheme.primary.withValues(alpha: 0.08)
              : Get.theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: highlight
                ? Get.theme.colorScheme.primary.withValues(alpha: 0.25)
                : Get.theme.dividerColor,
          ),
        ),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Get.theme.textTheme.bodySmall!.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard(dynamic bank, QuestionBankController controller) {
    final isActive = bank.isActiveBank;
    final sourceIcon = bank.isFromFile
        ? Icons.folder_outlined
        : Icons.inventory_2_outlined;
    final sourceLabel = bank.isFromFile ? '文件导入' : '内置题库';

    return GestureDetector(
      onLongPress: () => _showBankActions(bank, controller),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        tintColor: isActive
            ? Get.theme.colorScheme.primary.withValues(alpha: 0.04)
            : null,
        gradient: isActive
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Get.theme.colorScheme.primary.withValues(alpha: 0.08),
                  Get.theme.colorScheme.primary.withValues(alpha: 0.02),
                ],
              )
            : null,
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        (isActive
                                ? Get.theme.colorScheme.primary
                                : Get.theme.textTheme.bodySmall!.color!)
                            .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    sourceIcon,
                    size: 22,
                    color: isActive
                        ? Get.theme.colorScheme.primary
                        : Get.theme.textTheme.bodySmall!.color,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              bank.name,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isActive
                                    ? Get.theme.colorScheme.primary
                                    : Get.theme.textTheme.bodyLarge!.color,
                              ),
                            ),
                          ),
                          if (isActive)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Get.theme.colorScheme.primary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '使用中',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: Get.theme.colorScheme.primary,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            sourceLabel,
                            style: TextStyle(
                              fontSize: 12,
                              color: Get.theme.textTheme.bodySmall!.color,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${bank.totalCount}题',
                            style: TextStyle(
                              fontSize: 12,
                              color: Get.theme.textTheme.bodySmall!.color,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (bank.sheetNameList.isNotEmpty) ...[
                            const SizedBox(width: 12),
                            Text(
                              '${bank.sheetNameList.length}个分类',
                              style: TextStyle(
                                fontSize: 12,
                                color: Get.theme.textTheme.bodySmall!.color,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    size: 20,
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                  onPressed: () => _showBankActions(bank, controller),
                ),
              ],
            ),
            if (!isActive) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () => controller.switchBank(bank.id!),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Get.theme.colorScheme.primary,
                    side: BorderSide(
                      color: Get.theme.colorScheme.primary.withValues(
                        alpha: 0.5,
                      ),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  child: const Text('切换为当前题库', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showBankActions(dynamic bank, QuestionBankController controller) {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Get.theme.dividerColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              bank.name,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: Get.theme.textTheme.headlineSmall!.color,
              ),
            ),
            const SizedBox(height: 16),
            if (!bank.isActiveBank)
              _buildActionOption(
                Icons.swap_horiz_rounded,
                '切换为当前题库',
                '切换到该题库进行学习',
                Get.theme.colorScheme.primary,
                () {
                  Get.back();
                  controller.switchBank(bank.id!);
                },
              ),
            _buildActionOption(
              Icons.delete_outline_rounded,
              '删除题库',
              '删除该题库及所有关联数据',
              const Color(0xFFF43F5E),
              () {
                Get.back();
                controller.showDeleteConfirmDialog(bank.id!, bank.name);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionOption(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: Get.theme.dividerColor),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                      Text(
                        subtitle,
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
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: Get.theme.textTheme.bodyLarge!.color,
        letterSpacing: -0.2,
      ),
    );
  }
}
