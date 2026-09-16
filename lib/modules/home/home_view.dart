import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';
import '../../core/routes/routes.dart';
import '../../core/theme/app_theme.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(HomeController());

    return Scaffold(
      body: Obx(() {
        if (controller.isImporting.value) {
          return _buildLoadingView(controller);
        }
        return _buildMainContent(controller, context);
      }),
    );
  }

  Widget _buildLoadingView(HomeController controller) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 24),
          Text(
            controller.importMessage.value.isEmpty
                ? '正在加载题库...'
                : controller.importMessage.value,
            style: TextStyle(fontSize: 16, color: Get.theme.textTheme.bodyLarge!.color),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(HomeController controller, BuildContext context) {
    return RefreshIndicator(
      onRefresh: controller.loadStats,
      color: Get.theme.colorScheme.primary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(controller)),
          SliverToBoxAdapter(child: _buildFunctionGrid(controller)),
          SliverToBoxAdapter(child: _buildMockExamCard(controller)),
          SliverToBoxAdapter(child: _buildProgressSection(controller)),
          SliverToBoxAdapter(child: _buildStatsRow(controller)),
          SliverToBoxAdapter(child: _buildStudyTip(controller)),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildHeader(HomeController controller) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 24),
      child: Row(
        children: [
          Obx(() {
            final hasAvatar = controller.avatarPath.value.isNotEmpty;
            return GestureDetector(
              onTap: () => Get.toNamed(Routes.settings),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: hasAvatar
                        ? [Get.theme.colorScheme.primary, Get.theme.colorScheme.primary]
                        : [Get.theme.colorScheme.primary, Get.theme.colorScheme.primary.withValues(alpha: 0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Get.theme.colorScheme.primary.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  image: hasAvatar
                      ? DecorationImage(
                          image: FileImage(File(controller.avatarPath.value)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasAvatar
                    ? null
                    : Icon(Icons.person_rounded, color: Colors.white, size: 24),
              ),
            );
          }),
          const SizedBox(width: 14),
          Expanded(
            child: Obx(() {
              final hasNickname = controller.nickname.value.isNotEmpty;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasNickname ? controller.nickname.value : '执照题库',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: Get.theme.textTheme.headlineLarge!.color,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Obx(() {
                    if (controller.activeBankName.value.isNotEmpty) {
                      return GestureDetector(
                        onTap: () => Get.toNamed(Routes.questionBank),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.folder_outlined, size: 14, color: Get.theme.colorScheme.primary),
                            const SizedBox(width: 4),
                            Text(
                              controller.activeBankName.value,
                              style: TextStyle(
                                fontSize: 12,
                                color: Get.theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Icon(Icons.chevron_right_rounded, size: 14, color: Get.theme.colorScheme.primary),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  }),

                ],
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow(HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Row(
        children: [
          _buildStatCard(
            '${controller.totalQuestions.value}',
            '总题数',
            Icons.library_books_outlined,
            Get.theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            '${controller.correctRate.toStringAsFixed(1)}%',
            '正确率',
            Icons.trending_up_rounded,
            const Color(0xFF10B981),
          ),
          const SizedBox(width: 10),
          _buildStatCard(
            '${controller.wrongCount.value}',
            '错题数',
            Icons.error_outline_rounded,
            const Color(0xFFF43F5E),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
        borderRadius: 16,
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
                fontSize: 18,
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
      ),
    );
  }

  Widget _buildFunctionGrid(HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('学习功能'),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildSquareFunctionItem(
                  '刷题模式',
                  '考试练习',
                  Icons.edit_note_rounded,
                  Get.theme.colorScheme.primary,
                  () => _showPracticeModeDialog(),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildSquareFunctionItem(
                  '背题模式',
                  '快速记忆',
                  Icons.visibility_rounded,
                  Get.theme.colorScheme.primary.withValues(alpha: 0.85),
                  () => _showMemorizeModeDialog(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSquareFunctionItem(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1.0,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [color, color.withValues(alpha: 0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.3),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Positioned(
                  right: -20,
                  bottom: -20,
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Positioned(
                  right: 20,
                  bottom: 20,
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Icon(icon, size: 28, color: Colors.white),
                      ),
                      const Spacer(),
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
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

  Widget _buildMainFunctionItem(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Get.theme.cardColor,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, size: 20, color: color),
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
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: Get.theme.textTheme.bodySmall!.color,
                    ),
                  ],
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 4,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withValues(alpha: 0.6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFunctionItem(String title, String subtitle, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: color),
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

  Widget _buildMockExamCard(HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GestureDetector(
        onTap: () => _showMockExamDialog(controller),
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
                child: const Icon(Icons.quiz_rounded, size: 24, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '模拟考试',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '随机300题，检验学习成果',
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
                child: const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSection(HomeController controller) {
    final total = controller.totalQuestions.value > 0 ? controller.totalQuestions.value : 1;
    final practicedRate = controller.practicedCount.value / total;
    final correctRate = controller.practicedCount.value > 0
        ? controller.correctCount.value / controller.practicedCount.value
        : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('学习进度'),
          const SizedBox(height: 12),
          GlassCard(
            padding: const EdgeInsets.all(20),
            borderRadius: 18,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildProgressRing(
                        '练习进度',
                        practicedRate,
                        '${(practicedRate * 100).toStringAsFixed(0)}%',
                        Get.theme.colorScheme.primary,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 60,
                      color: Get.theme.dividerColor,
                    ),
                    Expanded(
                      child: _buildProgressRing(
                        '正确率',
                        correctRate,
                        '${(correctRate * 100).toStringAsFixed(0)}%',
                        const Color(0xFF10B981),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildProgressBar(
                  '已收藏',
                  controller.favoriteCount.value,
                  total,
                  const Color(0xFFF97316),
                ),
                const SizedBox(height: 10),
                _buildProgressBar(
                  '待练习',
                  total - controller.practicedCount.value,
                  total,
                  const Color(0xFF8B5CF6),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRing(String label, double progress, String value, Color color) {
    return Column(
      children: [
        SizedBox(
          width: 64,
          height: 64,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 5,
                  backgroundColor: color.withValues(alpha: 0.08),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Get.theme.textTheme.bodySmall!.color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressBar(String label, int current, int total, Color color) {
    final progress = total > 0 ? current / total : 0.0;
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: Get.theme.textTheme.bodyMedium!.color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: color.withValues(alpha: 0.08),
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 6,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 48,
          child: Text(
            '$current/$total',
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudyTip(HomeController controller) {
    final total = controller.totalQuestions.value > 0 ? controller.totalQuestions.value : 1;
    final practicedRate = controller.practicedCount.value / total;

    String tipTitle;
    String tipContent;
    IconData tipIcon;
    Color tipColor;

    if (controller.practicedCount.value == 0) {
      tipTitle = '开始学习';
      tipContent = '你还没有开始练习，从刷题模式开始吧！';
      tipIcon = Icons.rocket_launch_rounded;
      tipColor = Get.theme.colorScheme.primary;
    } else if (practicedRate < 0.3) {
      tipTitle = '继续加油';
      tipContent = '已完成${(practicedRate * 100).toStringAsFixed(0)}%，建议每天练习50题';
      tipIcon = Icons.trending_up_rounded;
      tipColor = const Color(0xFFF97316);
    } else if (controller.wrongCount.value > 10) {
      tipTitle = '重点复习';
      tipContent = '你有${controller.wrongCount.value}道错题，建议优先复习错题本';
      tipIcon = Icons.error_outline_rounded;
      tipColor = const Color(0xFFF43F5E);
    } else {
      tipTitle = '表现优秀';
      tipContent = '正确率${controller.correctRate.toStringAsFixed(1)}%，可以尝试模拟考试';
      tipIcon = Icons.emoji_events_rounded;
      tipColor = const Color(0xFF10B981);
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        borderRadius: 14,
        tintColor: tipColor.withValues(alpha: 0.04),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            tipColor.withValues(alpha: 0.08),
            tipColor.withValues(alpha: 0.02),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: tipColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(tipIcon, size: 20, color: tipColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tipTitle,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: tipColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    tipContent,
                    style: TextStyle(
                      fontSize: 12,
                      color: Get.theme.textTheme.bodyMedium!.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
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

  void _showPracticeModeDialog() {
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
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
              '选择刷题方式',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Get.theme.textTheme.headlineSmall!.color),
            ),
            const SizedBox(height: 16),
            _buildModeOption('顺序刷题', '按顺序逐题练习', Icons.sort_rounded, 'sequential'),
            _buildModeOption('随机刷题', '随机抽取题目练习', Icons.shuffle_rounded, 'random'),
            _buildModeOption('错题刷题', '重做做错的题目', Icons.error_outline_rounded, 'wrong'),
            _buildModeOption('收藏刷题', '练习收藏的题目', Icons.favorite_outline_rounded, 'favorite'),
          ],
        ),
      ),
    );
  }

  Widget _buildModeOption(String title, String subtitle, IconData icon, String mode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Get.back();
            Get.toNamed(Routes.practice, arguments: {'subMode': mode, 'sheetName': ''});
          },
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
                    color: Get.theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: Get.theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Get.theme.textTheme.bodyLarge!.color)),
                      Text(subtitle, style: TextStyle(fontSize: 12, color: Get.theme.textTheme.bodySmall!.color)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 18, color: Get.theme.textTheme.bodySmall!.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMemorizeModeDialog() {
    final controller = Get.find<HomeController>();
    Get.bottomSheet(
      Container(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        decoration: BoxDecoration(
          color: Get.theme.cardColor,
          borderRadius: const BorderRadius.only(topLeft: Radius.circular(24), topRight: Radius.circular(24)),
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
              '选择题库',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Get.theme.textTheme.headlineSmall!.color),
            ),
            const SizedBox(height: 16),
            _buildSheetOption('全部题目', '${controller.totalQuestions.value}题', Icons.library_books_outlined, ''),
            ...controller.sheetNames.map((name) => _buildSheetOption(name, '', Icons.folder_outlined, name)),
          ],
        ),
      ),
    );
  }

  Widget _buildSheetOption(String title, String count, IconData icon, String sheetName) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Get.back();
            Get.toNamed(Routes.memorize, arguments: {'sheetName': sheetName});
          },
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
                    color: Get.theme.colorScheme.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 18, color: Get.theme.colorScheme.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Get.theme.textTheme.bodyLarge!.color)),
                ),
                if (count.isNotEmpty)
                  Text(count, style: TextStyle(fontSize: 12, color: Get.theme.textTheme.bodySmall!.color)),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 18, color: Get.theme.textTheme.bodySmall!.color),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showMockExamDialog(HomeController controller) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('开始模拟考试', style: TextStyle(color: Get.theme.textTheme.headlineSmall!.color)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('将从题库中随机抽取300道题目组成试卷。', style: TextStyle(color: Get.theme.textTheme.bodyLarge!.color)),
            const SizedBox(height: 12),
            Text('当前题库总题数: ${controller.totalQuestions.value}题', style: TextStyle(fontSize: 13, color: Get.theme.textTheme.bodySmall!.color)),
            const SizedBox(height: 8),
            Text('考试过程中每题选择后立即判断对错，结束后显示总成绩。', style: TextStyle(fontSize: 13, color: Get.theme.textTheme.bodySmall!.color)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              Get.toNamed(Routes.mockExam);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('开始考试'),
          ),
        ],
      ),
    );
  }
}
