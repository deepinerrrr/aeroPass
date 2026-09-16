import 'package:flutter_test/flutter_test.dart';
import 'package:license_app/data/models/app_update_model.dart';

void main() {
  group('APP 更新清单', () {
    test('版本号更大时识别为新版本', () {
      final manifest = AppUpdateManifest.fromJson({
        'platform': 'android',
        'versionName': '1.0.1',
        'versionCode': 2,
        'apkUrl': 'https://example.com/aeropass.apk',
        'sha256': 'a' * 64,
        'sizeBytes': 1024,
      });

      expect(
        manifest.isNewerThan(
          currentVersionCode: 1,
          currentVersionName: '1.0.0',
        ),
        isTrue,
      );
    });

    test('版本号相同时用版本名称兜底比较', () {
      final manifest = AppUpdateManifest.fromJson({
        'platform': 'android',
        'versionName': '1.1.0',
        'versionCode': 2,
        'apkUrl': 'https://example.com/aeropass.apk',
        'sha256': 'b' * 64,
        'sizeBytes': 1024,
      });

      expect(
        manifest.isNewerThan(
          currentVersionCode: 2,
          currentVersionName: '1.0.9',
        ),
        isTrue,
      );
    });

    test('清单缺少校验值时视为无效', () {
      final manifest = AppUpdateManifest.fromJson({
        'platform': 'android',
        'versionName': '1.0.1',
        'versionCode': 2,
        'apkUrl': 'https://example.com/aeropass.apk',
        'sha256': '',
        'sizeBytes': 1024,
      });

      expect(manifest.isValidForAndroid(), isFalse);
    });
  });
}
