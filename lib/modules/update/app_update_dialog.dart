import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../data/models/app_update_model.dart';
import 'app_update_controller.dart';

class AppUpdateDialog extends StatelessWidget {
  final AppUpdateController controller;
  final AppUpdateManifest manifest;

  const AppUpdateDialog({
    super.key,
    required this.controller,
    required this.manifest,
  });

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !manifest.force,
      child: Obx(() {
        final phase = controller.phase.value;
        final isBusy =
            phase == AppUpdatePhase.downloading ||
            phase == AppUpdatePhase.verifying ||
            phase == AppUpdatePhase.installing;

        return AlertDialog(
          backgroundColor: Get.theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                color: Get.theme.colorScheme.primary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '发现新版本 ${manifest.versionName}',
                  style: TextStyle(
                    color: Get.theme.textTheme.headlineSmall!.color,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildMetaRow('当前版本', controller.currentVersionText.value),
                const SizedBox(height: 6),
                _buildMetaRow(
                  '安装包',
                  controller.formatBytes(manifest.sizeBytes),
                ),
                if (manifest.force) ...[
                  const SizedBox(height: 10),
                  _buildForceBadge(),
                ],
                const SizedBox(height: 14),
                Text(
                  '更新内容',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Get.theme.textTheme.bodyLarge!.color,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 150),
                  child: SingleChildScrollView(
                    child: Text(
                      manifest.releaseNotes.isEmpty
                          ? '修复问题并优化体验。'
                          : manifest.releaseNotes,
                      style: TextStyle(
                        height: 1.45,
                        fontSize: 13,
                        color: Get.theme.textTheme.bodyMedium!.color,
                      ),
                    ),
                  ),
                ),
                if (isBusy || phase == AppUpdatePhase.failed) ...[
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: phase == AppUpdatePhase.downloading
                        ? controller.progress.value.clamp(0, 1)
                        : phase == AppUpdatePhase.failed
                        ? (controller.hasVerifiedPackage.value
                              ? 1
                              : controller.progress.value.clamp(0, 1))
                        : null,
                    minHeight: 7,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _progressText(phase),
                    style: TextStyle(
                      fontSize: 12,
                      color: phase == AppUpdatePhase.failed
                          ? Colors.redAccent
                          : Get.theme.textTheme.bodySmall!.color,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!manifest.force && !isBusy) ...[
              TextButton(
                onPressed: () => Get.back(),
                child: const Text('稍后再说'),
              ),
              TextButton(
                onPressed: () async {
                  await controller.ignoreCurrentUpdate();
                  Get.back();
                },
                child: const Text('忽略此版本'),
              ),
            ],
            ElevatedButton.icon(
              onPressed: isBusy ? null : controller.downloadAndInstall,
              icon: Icon(_buttonIcon(phase), size: 17),
              label: Text(_buttonText(phase)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Get.theme.colorScheme.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Get.theme.colorScheme.primary
                    .withValues(alpha: 0.45),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildMetaRow(String label, String value) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Get.theme.textTheme.bodySmall!.color,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Get.theme.textTheme.bodyMedium!.color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildForceBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF97316).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const Text(
        '此版本为必要更新',
        style: TextStyle(
          color: Color(0xFFF97316),
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  String _progressText(AppUpdatePhase phase) {
    return switch (phase) {
      AppUpdatePhase.downloading =>
        '下载中 ${controller.formatPercent(controller.progress.value)} · ${controller.formatBytes(controller.receivedBytes.value)} / ${controller.formatBytes(controller.totalBytes.value)}',
      AppUpdatePhase.verifying => '正在校验安装包完整性',
      AppUpdatePhase.installing => '正在打开系统安装器',
      AppUpdatePhase.failed => controller.errorMessage.value,
      _ => '',
    };
  }

  IconData _buttonIcon(AppUpdatePhase phase) {
    return switch (phase) {
      AppUpdatePhase.failed => Icons.refresh_rounded,
      _ => Icons.download_rounded,
    };
  }

  String _buttonText(AppUpdatePhase phase) {
    return switch (phase) {
      AppUpdatePhase.downloading => '下载中',
      AppUpdatePhase.verifying => '校验中',
      AppUpdatePhase.installing => '安装中',
      AppUpdatePhase.failed =>
        controller.hasVerifiedPackage.value ? '继续安装' : '重新下载',
      _ => '下载并安装',
    };
  }
}
