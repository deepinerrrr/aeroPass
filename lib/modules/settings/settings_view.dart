import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../home/home_controller.dart';
import '../developer/developer_settings_view.dart';
import '../developer/developer_settings_controller.dart';
import '../update/app_update_controller.dart';
import '../../data/database/database_helper.dart';
import '../../data/services/ai_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/routes/routes.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  int _versionClickCount = 0;
  DateTime? _lastClickTime;

  @override
  Widget build(BuildContext context) {
    final settingsController = Get.find<SettingsController>();
    final homeController = Get.find<HomeController>();
    final updateController = Get.find<AppUpdateController>();

    return Scaffold(
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _buildHeader()),
            SliverToBoxAdapter(child: _buildProfileSection(settingsController)),
            SliverToBoxAdapter(
              child: _buildAppearanceSection(settingsController),
            ),
            SliverToBoxAdapter(
              child: _buildSwipeModeSection(settingsController),
            ),
            SliverToBoxAdapter(child: _buildAiModelSection(settingsController)),
            SliverToBoxAdapter(child: _buildDataSection(homeController)),
            SliverToBoxAdapter(child: _buildUpdateSection(updateController)),
            const SliverToBoxAdapter(child: SizedBox(height: 100)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Text(
        '设置',
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w800,
          color: Get.theme.textTheme.headlineLarge!.color,
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildProfileSection(SettingsController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('个人信息'),
          const SizedBox(height: 10),
          GlassCard(
            borderRadius: 16,
            child: Column(
              children: [
                _buildAvatarTile(controller),
                _buildNicknameTile(controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarTile(SettingsController controller) {
    return InkWell(
      onTap: () => _pickAvatar(controller),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Get.theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.person_rounded,
                size: 18,
                color: Get.theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '头像',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Get.theme.textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '点击更换头像',
                    style: TextStyle(
                      fontSize: 12,
                      color: Get.theme.textTheme.bodySmall!.color,
                    ),
                  ),
                ],
              ),
            ),
            Obx(() {
              final hasAvatar = controller.avatarPath.value.isNotEmpty;
              return Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: hasAvatar
                      ? null
                      : Get.theme.colorScheme.primary.withValues(alpha: 0.1),
                  image: hasAvatar
                      ? DecorationImage(
                          image: FileImage(File(controller.avatarPath.value)),
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: hasAvatar
                    ? null
                    : Icon(
                        Icons.person_rounded,
                        color: Get.theme.colorScheme.primary,
                        size: 20,
                      ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildNicknameTile(SettingsController controller) {
    return InkWell(
      onTap: () => _showNicknameDialog(controller),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF97316).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.edit_rounded,
                size: 18,
                color: const Color(0xFFF97316),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '昵称',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Get.theme.textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Obx(
                    () => Text(
                      controller.nickname.value.isEmpty
                          ? '点击设置昵称'
                          : controller.nickname.value,
                      style: TextStyle(
                        fontSize: 12,
                        color: Get.theme.textTheme.bodySmall!.color,
                      ),
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

  Future<void> _pickAvatar(SettingsController controller) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      await controller.setAvatarPath(result.files.single.path!);
    }
  }

  void _showNicknameDialog(SettingsController controller) {
    final textController = TextEditingController(
      text: controller.nickname.value,
    );
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '设置昵称',
          style: TextStyle(color: Get.theme.textTheme.headlineSmall!.color),
        ),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLength: 20,
          decoration: InputDecoration(
            hintText: '请输入昵称',
            hintStyle: TextStyle(color: Get.theme.textTheme.bodySmall!.color),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Get.theme.dividerColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Get.theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Get.theme.colorScheme.primary,
                width: 2,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              controller.setNickname(textController.text.trim());
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Widget _buildAppearanceSection(SettingsController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('外观'),
          const SizedBox(height: 10),
          GlassCard(
            borderRadius: 16,
            child: Column(
              children: [
                Obx(
                  () => _buildSwitchTile(
                    Icons.dark_mode_rounded,
                    '深色模式',
                    '切换深色/浅色主题',
                    controller.isDarkMode.value,
                    (_) => controller.toggleDarkMode(),
                  ),
                ),
                _buildThemeColorSelector(controller),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile(
    IconData icon,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
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
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Get.theme.textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 1),
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
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: Get.theme.colorScheme.primary,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeColorSelector(SettingsController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => controller.toggleThemeExpanded(),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    size: 18,
                    color: Colors.orange.shade600,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '主题色',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Get.theme.textTheme.bodyLarge!.color,
                    ),
                  ),
                ),
                Obx(() {
                  final currentOption = controller.currentThemeColor;
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 18,
                        height: 18,
                        decoration: BoxDecoration(
                          color: currentOption.color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: currentOption.color.withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        currentOption.name,
                        style: TextStyle(
                          fontSize: 12,
                          color: currentOption.color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(width: 6),
                Obx(
                  () => AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: controller.isThemeExpanded.value ? 0.5 : 0,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 20,
                      color: Get.theme.textTheme.bodySmall!.color,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Obx(
            () => AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: controller.isThemeExpanded.value
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: Column(
                children: SettingsController.themeColors.map((option) {
                  final isSelected =
                      controller.themeColorKey.value == option.key;
                  return Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: GestureDetector(
                      onTap: () => controller.setThemeColor(option.key),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? option.color.withValues(alpha: 0.06)
                              : Get.theme.cardColor,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isSelected
                                ? option.color.withValues(alpha: 0.5)
                                : Get.theme.dividerColor.withValues(alpha: 0.5),
                            width: isSelected ? 1.5 : 0.5,
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: option.color.withValues(alpha: 0.12),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: option.color,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: option.color.withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: isSelected
                                  ? const Icon(
                                      Icons.check_rounded,
                                      color: Colors.white,
                                      size: 18,
                                    )
                                  : null,
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    option.name,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isSelected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? option.color
                                          : Get
                                                .theme
                                                .textTheme
                                                .bodyLarge!
                                                .color,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: option.complementaryColors.map((
                                      c,
                                    ) {
                                      return Container(
                                        width: 20,
                                        height: 20,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          color: c,
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            width: 1.5,
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: option.color.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '使用中',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: option.color,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwipeModeSection(SettingsController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('切换题目方式'),
          const SizedBox(height: 10),
          GlassCard(
            borderRadius: 16,
            child: Obx(
              () => RadioGroup<String>(
                groupValue: controller.swipeMode.value,
                onChanged: (value) {
                  if (value != null) controller.setSwipeMode(value);
                },
                child: Column(
                  children: [
                    _buildRadioTile(
                      Icons.swap_horiz_rounded,
                      '左右滑动切换',
                      '适用于刷题模式和背题模式',
                      'horizontal',
                      controller.swipeMode.value,
                    ),
                    _buildRadioTile(
                      Icons.swap_vert_rounded,
                      '上下滑动切换',
                      '适用于刷题模式和背题模式（卡片式）',
                      'vertical',
                      controller.swipeMode.value,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRadioTile(
    IconData icon,
    String title,
    String subtitle,
    String value,
    String groupValue,
  ) {
    final isSelected = value == groupValue;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  (isSelected
                          ? Get.theme.colorScheme.primary
                          : Get.theme.textTheme.bodySmall!.color!)
                      .withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 18,
              color: isSelected
                  ? Get.theme.colorScheme.primary
                  : Get.theme.textTheme.bodySmall!.color,
            ),
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
                const SizedBox(height: 1),
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
          Radio<String>(
            value: value,
            activeColor: Get.theme.colorScheme.primary,
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _buildAiModelSection(SettingsController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('AI 模型'),
          const SizedBox(height: 10),
          GlassCard(
            borderRadius: 16,
            child: Column(
              children: [
                Obx(() => _buildAiModelSelector(controller)),
                _buildApiKeyTile(
                  Icons.key_rounded,
                  'Qwen API Key',
                  '通义千问大模型密钥',
                  controller,
                  AiModelType.qwen,
                ),
                _buildApiKeyTile(
                  Icons.key_rounded,
                  'DeepSeek API Key',
                  'DeepSeek大模型密钥',
                  controller,
                  AiModelType.deepseek,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAiModelSelector(SettingsController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Get.theme.colorScheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.smart_toy_rounded,
              size: 18,
              color: Get.theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '默认模型',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Get.theme.textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  '选择AI问答使用的模型',
                  style: TextStyle(
                    fontSize: 12,
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(
              color: Get.theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: DropdownButton<String>(
              value: controller.currentAiModel.value,
              underline: const SizedBox.shrink(),
              isDense: true,
              icon: Icon(
                Icons.arrow_drop_down_rounded,
                color: Get.theme.colorScheme.primary,
                size: 20,
              ),
              style: TextStyle(
                fontSize: 13,
                color: Get.theme.textTheme.bodyLarge!.color,
                fontWeight: FontWeight.w500,
              ),
              items: const [
                DropdownMenuItem(value: 'qwen', child: Text('Qwen')),
                DropdownMenuItem(value: 'deepseek', child: Text('DeepSeek')),
              ],
              onChanged: (value) {
                if (value != null) controller.setCurrentAiModel(value);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyTile(
    IconData icon,
    String title,
    String subtitle,
    SettingsController controller,
    AiModelType modelType,
  ) {
    return InkWell(
      onTap: () => _showApiKeyDialog(controller, modelType, title),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: const Color(0xFF8B5CF6)),
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
                  const SizedBox(height: 1),
                  Obx(() {
                    final apiKey = modelType == AiModelType.qwen
                        ? controller.qwenApiKey.value
                        : controller.deepseekApiKey.value;
                    final masked = apiKey.length > 8
                        ? '${apiKey.substring(0, 4)}****${apiKey.substring(apiKey.length - 4)}'
                        : '未设置';
                    return Text(
                      masked,
                      style: TextStyle(
                        fontSize: 12,
                        color: Get.theme.textTheme.bodySmall!.color,
                      ),
                    );
                  }),
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

  void _showApiKeyDialog(
    SettingsController controller,
    AiModelType modelType,
    String title,
  ) {
    final currentKey = modelType == AiModelType.qwen
        ? controller.qwenApiKey.value
        : controller.deepseekApiKey.value;
    final textController = TextEditingController(text: currentKey);
    final obscure = true.obs;
    final modelConfig = AiService.getModelConfig(modelType);

    Get.dialog(
      Obx(
        () => AlertDialog(
          backgroundColor: Get.theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            title,
            style: TextStyle(color: Get.theme.textTheme.headlineSmall!.color),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                modelConfig.apiKeyGuide,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Get.theme.textTheme.bodySmall!.color,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                obscureText: obscure.value,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '请输入API Key',
                  hintStyle: TextStyle(
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Get.theme.dividerColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Get.theme.dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Get.theme.colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  suffixIcon: IconButton(
                    tooltip: obscure.value ? '显示密钥' : '隐藏密钥',
                    icon: Icon(
                      obscure.value
                          ? Icons.visibility_off_rounded
                          : Icons.visibility_rounded,
                      size: 18,
                    ),
                    onPressed: () => obscure.value = !obscure.value,
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton.icon(
              onPressed: () => _openApiKeyPage(modelConfig),
              icon: const Icon(Icons.open_in_new_rounded, size: 17),
              label: const Text('获取 API Key'),
            ),
            TextButton(onPressed: () => Get.back(), child: const Text('取消')),
            ElevatedButton(
              onPressed: () {
                final key = textController.text.trim();
                if (key.isNotEmpty) {
                  if (modelType == AiModelType.qwen) {
                    controller.setQwenApiKey(key);
                  } else {
                    controller.setDeepseekApiKey(key);
                  }
                }
                Get.back();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Get.theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('确定'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openApiKeyPage(AiModelConfig modelConfig) async {
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(modelConfig.apiKeyUrl),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened) {
      Get.snackbar(
        '无法打开网页',
        '请稍后重试，或在浏览器中访问 ${modelConfig.apiKeyUrl}',
        snackPosition: SnackPosition.BOTTOM,
      );
    }
  }

  Widget _buildDataSection(HomeController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('数据管理'),
          const SizedBox(height: 10),
          GlassCard(
            borderRadius: 16,
            child: Column(
              children: [
                _buildActionTile(
                  Icons.folder_outlined,
                  '题库管理',
                  '导入、切换和管理题库',
                  const Color(0xFF8B5CF6),
                  () => Get.toNamed(Routes.questionBank),
                ),
                _buildActionTile(
                  Icons.download_rounded,
                  '重新导入默认题库',
                  '从内置JSON重新导入',
                  Get.theme.colorScheme.primary,
                  () => _showReimportDialog(controller),
                ),
                _buildActionTile(
                  Icons.delete_forever_rounded,
                  '清除所有数据',
                  '清除题目、记录和进度',
                  const Color(0xFFF43F5E),
                  () => _showClearDataDialog(controller),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile(
    IconData icon,
    String title,
    String subtitle,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
                      color: Get.theme.textTheme.bodyLarge!.color,
                    ),
                  ),
                  const SizedBox(height: 1),
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

  Widget _buildUpdateSection(AppUpdateController controller) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: _handleVersionTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('版本更新'),
                const SizedBox(height: 2),
                Obx(() => Text(
                  'v${controller.currentVersionText.value}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Get.theme.textTheme.bodySmall!.color,
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 10),
          GlassCard(
            borderRadius: 16,
            child: Column(
              children: [
                Obx(
                  () => _buildSwitchTile(
                    Icons.notifications_active_rounded,
                    '启动时自动检查',
                    controller.autoCheckEnabled.value
                        ? '打开 APP 时自动检测新版本'
                        : '已关闭自动检测',
                    controller.autoCheckEnabled.value,
                    controller.setAutoCheckEnabled,
                  ),
                ),
                Obx(() {
                  final phase = controller.phase.value;
                  final isIdle = phase == AppUpdatePhase.idle ||
                      phase == AppUpdatePhase.latest;
                  return _buildActionTile(
                    Icons.system_update_alt_rounded,
                    '检查更新',
                    isIdle ? '' : controller.statusText,
                    Get.theme.colorScheme.primary,
                    () => controller.checkForUpdate(),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleVersionTap() {
    final now = DateTime.now();
    if (_lastClickTime != null &&
        now.difference(_lastClickTime!) > const Duration(seconds: 2)) {
      setState(() {
        _versionClickCount = 0;
      });
    }
    _lastClickTime = now;

    setState(() {
      _versionClickCount++;
    });

    if (_versionClickCount >= 10) {
      _versionClickCount = 0;
      _activateDeveloperMode();
    }
  }

  void _activateDeveloperMode() async {
    final controller = Get.put(DeveloperSettingsController());
    await controller.activateDeveloperMode();
    Get.to(() => const DeveloperSettingsView());
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Get.theme.textTheme.bodySmall!.color,
        letterSpacing: 0.5,
      ),
    );
  }

  void _showReimportDialog(HomeController controller) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '重新导入题库',
          style: TextStyle(color: Get.theme.textTheme.headlineSmall!.color),
        ),
        content: Text(
          '将清除现有题目数据并重新导入，是否继续？',
          style: TextStyle(color: Get.theme.textTheme.bodyLarge!.color),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () {
              Get.back();
              controller.importFromAsset();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.colorScheme.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(HomeController controller) {
    Get.dialog(
      AlertDialog(
        backgroundColor: Get.theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '清除所有数据',
          style: TextStyle(color: Get.theme.textTheme.headlineSmall!.color),
        ),
        content: Text(
          '此操作将清除所有题目、学习记录和进度数据，且不可恢复。确定要继续吗？',
          style: TextStyle(color: Get.theme.textTheme.bodyLarge!.color),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('取消')),
          ElevatedButton(
            onPressed: () async {
              Get.back();
              final db = DatabaseHelper();
              await db.clearAllData();
              await controller.loadStats();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('确定清除'),
          ),
        ],
      ),
    );
  }
}
