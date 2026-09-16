import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../home/home_controller.dart';
import '../../core/routes/routes.dart';
import '../../core/theme/app_theme.dart';

class ToolsView extends StatelessWidget {
  const ToolsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<HomeController>();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildSearchBar()),
            SliverToBoxAdapter(child: _buildToolSection(controller)),
            SliverToBoxAdapter(child: _buildQuickStats(controller)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '工具',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: Get.theme.textTheme.headlineLarge!.color,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '学习辅助工具集',
                style: TextStyle(
                  fontSize: 14,
                  color: Get.theme.textTheme.bodySmall!.color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: GestureDetector(
        onTap: () => Get.toNamed(Routes.search),
        child: GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          borderRadius: 14,
          child: Row(
            children: [
              Icon(Icons.search_rounded, color: Get.theme.textTheme.bodySmall!.color, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '搜索题目关键字...',
                  style: TextStyle(
                    fontSize: 14,
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Get.theme.colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.tune_rounded,
                  size: 16,
                  color: Get.theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildToolSection(HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('学习工具'),
          const SizedBox(height: 12),
          _buildToolItem(
            icon: Icons.error_outline_rounded,
            title: '错题本',
            subtitle: '重点攻克薄弱环节',
            count: '${controller.wrongCount.value}题',
            color: const Color(0xFFF43F5E),
            onTap: () => Get.toNamed(Routes.wrong),
          ),
          const SizedBox(height: 8),
          _buildToolItem(
            icon: Icons.favorite_rounded,
            title: '收藏题库',
            subtitle: '随时复习重点题目',
            count: '${controller.favoriteCount.value}题',
            color: const Color(0xFFF97316),
            onTap: () => Get.toNamed(Routes.favorite),
          ),
          const SizedBox(height: 8),
          _buildToolItem(
            icon: Icons.collections_bookmark_rounded,
            title: '我的合集',
            subtitle: '按关键词查看收录的题目合集',
            count: '',
            color: const Color(0xFF0D9488),
            onTap: () => Get.toNamed(Routes.collectionList),
          ),
          const SizedBox(height: 8),
          _buildToolItem(
            icon: Icons.bar_chart_rounded,
            title: '学习统计',
            subtitle: '查看学习数据报告',
            count: '',
            color: const Color(0xFF10B981),
            onTap: () => Get.toNamed(Routes.stats),
          ),
          const SizedBox(height: 8),
          _buildToolItem(
            icon: Icons.folder_outlined,
            title: '题库管理',
            subtitle: '导入、切换和管理题库',
            count: '',
            color: const Color(0xFF8B5CF6),
            onTap: () => Get.toNamed(Routes.questionBank),
          ),
        ],
      ),
    );
  }

  Widget _buildToolItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required String count,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 16,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Get.theme.textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 2),
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
            if (count.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  count,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Get.theme.textTheme.bodySmall!.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('学习数据'),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 18,
            child: Row(
              children: [
                _buildStatItem(
                  '总题数',
                  '${controller.totalQuestions.value}',
                  Icons.library_books_outlined,
                  Get.theme.colorScheme.primary,
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Get.theme.dividerColor,
                ),
                _buildStatItem(
                  '正确率',
                  '${controller.correctRate.toStringAsFixed(1)}%',
                  Icons.trending_up_rounded,
                  const Color(0xFF10B981),
                ),
                Container(
                  width: 1,
                  height: 48,
                  color: Get.theme.dividerColor,
                ),
                _buildStatItem(
                  '已练习',
                  '${controller.practicedCount.value}',
                  Icons.check_circle_outline_rounded,
                  const Color(0xFF8B5CF6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Get.theme.textTheme.headlineSmall!.color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Get.theme.textTheme.bodySmall!.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
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
