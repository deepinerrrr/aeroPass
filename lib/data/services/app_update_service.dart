import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_update_model.dart';

typedef UpdateProgressCallback =
    void Function(int receivedBytes, int totalBytes);

class AppUpdateException implements Exception {
  final String message;

  const AppUpdateException(this.message);

  @override
  String toString() => message;
}

class AppUpdateService {
  static const defaultManifestUrl = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://aeropass.langlai.top/api/appcast/android',
  );
  static const _legacyDefaultManifestUrl =
      'http://8.134.68.93/api/appcast/android';
  static const _manifestUrlPrefsKey = 'app_update_manifest_url';
  static const _autoCheckPrefsKey = 'app_update_auto_check';
  static const _ignoredVersionCodeKey = 'app_update_ignored_version_code';
  static const _channel = MethodChannel('com.example.license_app/app_update');

  Future<String> getManifestUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_manifestUrlPrefsKey)?.trim();
    if (saved == null || saved.isEmpty) {
      return defaultManifestUrl;
    }
    if (saved == _legacyDefaultManifestUrl) {
      await prefs.remove(_manifestUrlPrefsKey);
      return defaultManifestUrl;
    }
    return saved;
  }

  Future<void> setManifestUrl(String value) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = value.trim();
    if (normalized.isEmpty) {
      await prefs.remove(_manifestUrlPrefsKey);
    } else {
      await prefs.setString(_manifestUrlPrefsKey, normalized);
    }
  }

  Future<bool> isAutoCheckEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_autoCheckPrefsKey) ?? true;
  }

  Future<void> setAutoCheckEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_autoCheckPrefsKey, enabled);
  }

  Future<int?> getIgnoredVersionCode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_ignoredVersionCodeKey);
  }

  Future<void> setIgnoredVersionCode(int? versionCode) async {
    final prefs = await SharedPreferences.getInstance();
    if (versionCode == null || versionCode <= 0) {
      await prefs.remove(_ignoredVersionCodeKey);
    } else {
      await prefs.setInt(_ignoredVersionCodeKey, versionCode);
    }
  }

  Future<PackageInfo> getPackageInfo() {
    return PackageInfo.fromPlatform();
  }

  Future<AppUpdateManifest?> checkForUpdate() async {
    if (!Platform.isAndroid) {
      return null;
    }

    final packageInfo = await getPackageInfo();
    final currentVersionCode = int.tryParse(packageInfo.buildNumber) ?? 0;
    final manifestUrl = Uri.parse(await getManifestUrl());
    final response = await http
        .get(manifestUrl, headers: {'Accept': 'application/json'})
        .timeout(const Duration(seconds: 12));

    if (response.statusCode == 204 || response.body.trim().isEmpty) {
      return null;
    }
    if (response.statusCode != 200) {
      throw AppUpdateException('更新服务器暂时不可用：${response.statusCode}');
    }

    final jsonBody = jsonDecode(utf8.decode(response.bodyBytes));
    if (jsonBody is! Map<String, dynamic>) {
      throw const AppUpdateException('更新清单格式不正确');
    }

    final manifest = AppUpdateManifest.fromJson(jsonBody);
    if (!manifest.isValidForAndroid()) {
      throw const AppUpdateException('更新清单缺少 APK 地址或校验信息');
    }

    return manifest.isNewerThan(
          currentVersionCode: currentVersionCode,
          currentVersionName: packageInfo.version,
        )
        ? manifest
        : null;
  }

  Future<File> downloadApk(
    AppUpdateManifest manifest, {
    required UpdateProgressCallback onProgress,
  }) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(Uri.parse(manifest.apkUrl));
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppUpdateException('安装包下载失败：${response.statusCode}');
      }

      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/aeropass-${manifest.versionName}-${manifest.versionCode}.apk',
      );
      if (await file.exists()) {
        await file.delete();
      }

      final sink = file.openWrite();
      var received = 0;
      final total = response.contentLength > 0
          ? response.contentLength
          : manifest.sizeBytes;

      await for (final chunk in response) {
        received += chunk.length;
        sink.add(chunk);
        onProgress(received, total);
      }
      await sink.flush();
      await sink.close();
      return file;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> verifyPackage(File file, AppUpdateManifest manifest) async {
    final digest = await sha256.bind(file.openRead()).first;
    final actual = digest.toString().toLowerCase();
    if (actual != manifest.sha256) {
      throw const AppUpdateException('安装包校验失败，请重新下载');
    }
  }

  Future<bool> canRequestPackageInstalls() async {
    if (!Platform.isAndroid) {
      return false;
    }
    return await _channel.invokeMethod<bool>('canInstallPackages') ?? false;
  }

  Future<void> openInstallPermissionSettings() async {
    if (!Platform.isAndroid) {
      return;
    }
    await _channel.invokeMethod<void>('openInstallSettings');
  }

  Future<void> installApk(File file) async {
    if (!Platform.isAndroid) {
      throw const AppUpdateException('当前平台不支持应用内安装 APK');
    }
    await _channel.invokeMethod<void>('installApk', {
      'path': file.path,
      'mimeType': 'application/vnd.android.package-archive',
    });
  }

  String getUploadPortalUrl(String manifestUrl) {
    final uri = Uri.tryParse(manifestUrl);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return 'https://aeropass.langlai.top/admin';
    }
    return uri.replace(path: '/admin', query: '', fragment: '').toString();
  }
}
