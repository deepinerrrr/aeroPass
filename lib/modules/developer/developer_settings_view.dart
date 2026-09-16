import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'developer_settings_controller.dart';
import '../../data/services/ai_service.dart';
import 'package:url_launcher/url_launcher.dart';

class DeveloperSettingsView extends StatelessWidget {
  const DeveloperSettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.put(DeveloperSettingsController());

    return Scaffold(
      backgroundColor: Get.theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('开发者选项'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => Get.back(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: controller.resetToDefault,
            tooltip: '恢复默认',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('API Key 配置'),
            const SizedBox(height: 12),
            _buildApiKeySection(controller),
            const SizedBox(height: 24),
            _buildSectionTitle('系统提示词'),
            const SizedBox(height: 12),
            _buildSystemPromptSection(controller),
            const SizedBox(height: 24),
            _buildSectionTitle('模型参数'),
            const SizedBox(height: 12),
            _buildModelParamsSection(controller),
            const SizedBox(height: 24),
            _buildDeactivateButton(controller),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Get.theme.textTheme.bodySmall?.color,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildApiKeySection(DeveloperSettingsController controller) {
    return Container(
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Get.theme.dividerColor),
      ),
      child: Column(
        children: [
          _buildApiKeyTile(
            icon: Icons.smart_toy_rounded,
            title: 'Qwen API Key',
            modelType: AiModelType.qwen,
          ),
          Divider(height: 1, color: Get.theme.dividerColor),
          _buildApiKeyTile(
            icon: Icons.smart_toy_rounded,
            title: 'DeepSeek API Key',
            modelType: AiModelType.deepseek,
          ),
        ],
      ),
    );
  }

  Widget _buildApiKeyTile({
    required IconData icon,
    required String title,
    required AiModelType modelType,
  }) {
    return InkWell(
      onTap: () => _showApiKeyDialog(modelType, title),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5CF6).withValues(alpha: 0.1),
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
                      color: Get.theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 2),
                  FutureBuilder<String>(
                    future: AiService.getApiKey(modelType),
                    builder: (context, snapshot) {
                      final apiKey = snapshot.data ?? '';
                      final masked = apiKey.length > 8
                          ? '${apiKey.substring(0, 4)}****${apiKey.substring(apiKey.length - 4)}'
                          : '未设置';
                      return Text(
                        masked,
                        style: TextStyle(
                          fontSize: 12,
                          color: Get.theme.textTheme.bodySmall?.color,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: Get.theme.textTheme.bodySmall?.color,
            ),
          ],
        ),
      ),
    );
  }

  void _showApiKeyDialog(AiModelType modelType, String title) async {
    final currentKey = await AiService.getApiKey(modelType);
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
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                modelConfig.apiKeyGuide,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: Get.theme.textTheme.bodySmall?.color,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: textController,
                obscureText: obscure.value,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: '请输入API Key',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
              onPressed: () async {
                final key = textController.text.trim();
                if (key.isNotEmpty) {
                  await AiService.setApiKey(modelType, key);
                  Get.back();
                  Get.snackbar(
                    '成功',
                    'API Key已保存',
                    backgroundColor: Colors.green,
                    colorText: Colors.white,
                  );
                }
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

  Widget _buildSystemPromptSection(DeveloperSettingsController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Get.theme.dividerColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.psychology_rounded,
                size: 18,
                color: Get.theme.colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '自定义系统提示词',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Get.theme.textTheme.bodyLarge?.color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '支持变量占位符：\${question_id}, \${question_type}, \${content}, \${options}, \${answer}',
            style: TextStyle(
              fontSize: 11,
              color: Get.theme.textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 12),
          Obx(
            () => TextField(
              controller: TextEditingController(
                text: controller.customSystemPrompt.value,
              )..selection = TextSelection.collapsed(offset: 0),
              onChanged: (value) => controller.customSystemPrompt.value = value,
              maxLines: 10,
              style: TextStyle(
                fontSize: 13,
                fontFamily: 'monospace',
                color: Get.theme.textTheme.bodyMedium?.color,
              ),
              decoration: InputDecoration(
                hintText: '输入自定义系统提示词...',
                filled: true,
                fillColor: Get.theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Get.theme.dividerColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Get.theme.dividerColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Get.theme.colorScheme.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                await controller.saveCustomSystemPrompt(
                  controller.customSystemPrompt.value,
                );
                Get.snackbar(
                  '成功',
                  '系统提示词已保存',
                  backgroundColor: Colors.green,
                  colorText: Colors.white,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Get.theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('保存提示词'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModelParamsSection(DeveloperSettingsController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Get.theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Get.theme.dividerColor),
      ),
      child: Column(
        children: [
          Obx(
            () => _buildSliderTile(
              icon: Icons.thermostat_rounded,
              title: 'Temperature',
              subtitle: '控制回答的随机性（值越高越有创意）',
              value: controller.temperature.value,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              onChanged: (value) => controller.temperature.value = value,
              onChangeEnd: (value) => controller.saveTemperature(value),
              valueLabel: controller.temperature.value.toStringAsFixed(1),
            ),
          ),
          const SizedBox(height: 16),
          Obx(
            () => _buildSliderTile(
              icon: Icons.short_text_rounded,
              title: 'Max Tokens',
              subtitle: '最大生成token数',
              value: controller.maxTokens.value.toDouble(),
              min: 500,
              max: 4000,
              divisions: 14,
              onChanged: (value) => controller.maxTokens.value = value.toInt(),
              onChangeEnd: (value) => controller.saveMaxTokens(value.toInt()),
              valueLabel: '${controller.maxTokens.value}',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliderTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
    required ValueChanged<double> onChangeEnd,
    required String valueLabel,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: Get.theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Get.theme.textTheme.bodyLarge?.color,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Get.theme.colorScheme.primary.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          valueLabel,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Get.theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: Get.theme.textTheme.bodySmall?.color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: Get.theme.colorScheme.primary,
            inactiveTrackColor: Get.theme.colorScheme.primary.withValues(
              alpha: 0.2,
            ),
            thumbColor: Get.theme.colorScheme.primary,
            overlayColor: Get.theme.colorScheme.primary.withValues(alpha: 0.2),
          ),
          child: Slider(
            value: value,
            min: min,
            max: max,
            divisions: divisions,
            onChanged: onChanged,
            onChangeEnd: onChangeEnd,
          ),
        ),
      ],
    );
  }

  Widget _buildDeactivateButton(DeveloperSettingsController controller) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: () async {
          await controller.deactivateDeveloperMode();
          Get.back();
          Get.snackbar(
            '提示',
            '已退出开发者模式',
            backgroundColor: Colors.orange,
            colorText: Colors.white,
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: const Text('退出开发者模式'),
      ),
    );
  }
}
