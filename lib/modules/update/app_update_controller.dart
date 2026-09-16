import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/app_update_model.dart';
import '../../data/services/app_update_service.dart';
import 'app_update_dialog.dart';

enum AppUpdatePhase {
  idle,
  checking,
  latest,
  available,
  downloading,
  verifying,
  installing,
  failed,
}

class AppUpdateController extends GetxController with WidgetsBindingObserver {
  final AppUpdateService _service;

  AppUpdateController({AppUpdateService? service})
    : _service = service ?? AppUpdateService();

  final phase = AppUpdatePhase.idle.obs;
  final manifest = Rxn<AppUpdateManifest>();
  final currentVersionText = '读取中'.obs;
  final manifestUrl = AppUpdateService.defaultManifestUrl.obs;
  final autoCheckEnabled = true.obs;
  final progress = 0.0.obs;
  final receivedBytes = 0.obs;
  final totalBytes = 0.obs;
  final errorMessage = ''.obs;
  final lastCheckedAt = Rxn<DateTime>();
  final isDialogShowing = false.obs;
  final hasVerifiedPackage = false.obs;

  bool _autoCheckScheduled = false;
  bool _waitingForInstallPermission = false;
  bool _resumingInstall = false;
  File? _verifiedApk;
  int? _verifiedVersionCode;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    refreshLocalState();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _waitingForInstallPermission &&
        !_resumingInstall) {
      _resumeInstallationAfterPermission();
    }
  }

  Future<void> refreshLocalState() async {
    final packageInfo = await _service.getPackageInfo();
    currentVersionText.value =
        '${packageInfo.version}+${packageInfo.buildNumber}';
    manifestUrl.value = await _service.getManifestUrl();
    autoCheckEnabled.value = await _service.isAutoCheckEnabled();
  }

  void scheduleStartupCheck() {
    if (_autoCheckScheduled) {
      return;
    }
    _autoCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await refreshLocalState();
      if (autoCheckEnabled.value) {
        await checkForUpdate(silent: true);
      }
    });
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    autoCheckEnabled.value = enabled;
    await _service.setAutoCheckEnabled(enabled);
  }

  Future<void> setManifestUrl(String url) async {
    await _service.setManifestUrl(url);
    manifestUrl.value = await _service.getManifestUrl();
  }

  Future<void> checkForUpdate({bool silent = false}) async {
    if (phase.value == AppUpdatePhase.checking ||
        phase.value == AppUpdatePhase.downloading ||
        phase.value == AppUpdatePhase.verifying ||
        phase.value == AppUpdatePhase.installing) {
      return;
    }

    errorMessage.value = '';
    phase.value = AppUpdatePhase.checking;
    try {
      final result = await _service.checkForUpdate();
      lastCheckedAt.value = DateTime.now();
      if (result == null) {
        manifest.value = null;
        phase.value = AppUpdatePhase.latest;
        if (!silent) {
          Get.snackbar(
            '已是最新版本',
            '当前版本 ${currentVersionText.value} 已是最新',
            snackPosition: SnackPosition.BOTTOM,
          );
        }
        return;
      }

      manifest.value = result;
      phase.value = AppUpdatePhase.available;

      // 静默自动检查时，若该版本已被用户忽略则不弹窗
      if (silent) {
        final ignoredVersionCode = await _service.getIgnoredVersionCode();
        if (ignoredVersionCode != null &&
            ignoredVersionCode == result.versionCode) {
          phase.value = AppUpdatePhase.idle;
          manifest.value = null;
          return;
        }
      }

      _showUpdateDialog(result);
    } catch (error) {
      errorMessage.value = error.toString();
      phase.value = AppUpdatePhase.failed;
      if (!silent) {
        Get.snackbar(
          '检查失败',
          errorMessage.value,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    }
  }

  Future<void> downloadAndInstall() async {
    final currentManifest = manifest.value;
    if (currentManifest == null) {
      return;
    }

    try {
      final verifiedApk = _verifiedApk;
      if (verifiedApk != null &&
          _verifiedVersionCode == currentManifest.versionCode &&
          await verifiedApk.exists()) {
        await _continueInstallation(verifiedApk);
        return;
      }

      progress.value = 0;
      receivedBytes.value = 0;
      totalBytes.value = currentManifest.sizeBytes;
      errorMessage.value = '';
      hasVerifiedPackage.value = false;
      phase.value = AppUpdatePhase.downloading;

      final apkFile = await _service.downloadApk(
        currentManifest,
        onProgress: (received, total) {
          receivedBytes.value = received;
          totalBytes.value = total;
          progress.value = total > 0 ? received / total : 0;
        },
      );

      phase.value = AppUpdatePhase.verifying;
      await _service.verifyPackage(apkFile, currentManifest);
      _verifiedApk = apkFile;
      _verifiedVersionCode = currentManifest.versionCode;
      hasVerifiedPackage.value = true;
      await _continueInstallation(apkFile);
    } catch (error) {
      errorMessage.value = error.toString();
      phase.value = AppUpdatePhase.failed;
    }
  }

  Future<void> _continueInstallation(File apkFile) async {
    phase.value = AppUpdatePhase.installing;
    errorMessage.value = '';
    if (Platform.isAndroid && !await _service.canRequestPackageInstalls()) {
      _waitingForInstallPermission = true;
      Get.snackbar(
        '需要允许安装',
        '请允许 aeroPass 安装来自本应用下载的更新包，返回 APP 后将自动继续。',
        snackPosition: SnackPosition.BOTTOM,
      );
      await _service.openInstallPermissionSettings();
      return;
    }

    _waitingForInstallPermission = false;
    await _service.installApk(apkFile);
  }

  Future<void> _resumeInstallationAfterPermission() async {
    final apkFile = _verifiedApk;
    if (apkFile == null || !await apkFile.exists()) {
      _waitingForInstallPermission = false;
      hasVerifiedPackage.value = false;
      errorMessage.value = '已下载的安装包不存在，请重新下载';
      phase.value = AppUpdatePhase.failed;
      return;
    }

    _resumingInstall = true;
    try {
      if (!await _service.canRequestPackageInstalls()) {
        _waitingForInstallPermission = false;
        errorMessage.value = '尚未获得安装权限，点击下方按钮可重新授权';
        phase.value = AppUpdatePhase.failed;
        return;
      }
      await _continueInstallation(apkFile);
    } catch (error) {
      _waitingForInstallPermission = false;
      errorMessage.value = error.toString();
      phase.value = AppUpdatePhase.failed;
    } finally {
      _resumingInstall = false;
    }
  }

  Future<void> openUploadPortal() async {
    final url = _service.getUploadPortalUrl(manifestUrl.value);
    var opened = false;
    try {
      opened = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
    } catch (_) {}
    if (!opened) {
      Get.snackbar('无法打开上传入口', url, snackPosition: SnackPosition.BOTTOM);
    }
  }

  /// 忽略当前检测到的新版本，后续自动检查时不再提示该版本。
  /// 用户手动「检查更新」时仍会正常弹窗。
  Future<void> ignoreCurrentUpdate() async {
    final currentManifest = manifest.value;
    if (currentManifest != null) {
      await _service.setIgnoredVersionCode(currentManifest.versionCode);
    }
    manifest.value = null;
    phase.value = AppUpdatePhase.idle;
  }

  void _showUpdateDialog(AppUpdateManifest updateManifest) {
    if (isDialogShowing.value) {
      return;
    }
    isDialogShowing.value = true;
    Get.dialog(
      AppUpdateDialog(controller: this, manifest: updateManifest),
      barrierDismissible: !updateManifest.force,
    ).whenComplete(() => isDialogShowing.value = false);
  }

  String get statusText {
    return switch (phase.value) {
      AppUpdatePhase.idle => '当前版本 ${currentVersionText.value}',
      AppUpdatePhase.checking => '正在检查新版本',
      AppUpdatePhase.latest => '当前已是最新版本',
      AppUpdatePhase.available => '发现新版本 ${manifest.value?.versionName ?? ''}',
      AppUpdatePhase.downloading => '正在下载 ${formatPercent(progress.value)}',
      AppUpdatePhase.verifying => '正在校验安装包',
      AppUpdatePhase.installing => '正在打开系统安装器',
      AppUpdatePhase.failed =>
        errorMessage.value.isEmpty ? '检查更新失败' : errorMessage.value,
    };
  }

  String formatPercent(double value) {
    final percent = (value.clamp(0, 1) * 100).toStringAsFixed(0);
    return '$percent%';
  }

  String formatBytes(int bytes) {
    if (bytes <= 0) {
      return '未知大小';
    }
    final mb = bytes / 1024 / 1024;
    if (mb >= 1) {
      return '${mb.toStringAsFixed(1)} MB';
    }
    final kb = bytes / 1024;
    return '${kb.toStringAsFixed(1)} KB';
  }

  Future<PackageInfo> packageInfo() => _service.getPackageInfo();
}
