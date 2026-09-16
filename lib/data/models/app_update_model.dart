class AppUpdateManifest {
  final String platform;
  final String versionName;
  final int versionCode;
  final String apkUrl;
  final String sha256;
  final int sizeBytes;
  final String releaseNotes;
  final bool force;
  final DateTime? publishedAt;

  const AppUpdateManifest({
    required this.platform,
    required this.versionName,
    required this.versionCode,
    required this.apkUrl,
    required this.sha256,
    required this.sizeBytes,
    required this.releaseNotes,
    required this.force,
    required this.publishedAt,
  });

  factory AppUpdateManifest.fromJson(Map<String, dynamic> json) {
    return AppUpdateManifest(
      platform: json['platform'] as String? ?? 'android',
      versionName: json['versionName'] as String? ?? '',
      versionCode: _asInt(json['versionCode']),
      apkUrl: json['apkUrl'] as String? ?? '',
      sha256: (json['sha256'] as String? ?? '').toLowerCase(),
      sizeBytes: _asInt(json['sizeBytes']),
      releaseNotes: json['releaseNotes'] as String? ?? '',
      force: json['force'] as bool? ?? false,
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? ''),
    );
  }

  bool isValidForAndroid() {
    return platform == 'android' &&
        versionName.isNotEmpty &&
        versionCode > 0 &&
        apkUrl.isNotEmpty &&
        sha256.length == 64;
  }

  bool isNewerThan({
    required int currentVersionCode,
    required String currentVersionName,
  }) {
    if (versionCode > currentVersionCode) {
      return true;
    }
    if (versionCode < currentVersionCode) {
      return false;
    }
    return _compareVersionNames(versionName, currentVersionName) > 0;
  }

  static int _asInt(dynamic value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }

  static int _compareVersionNames(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length = leftParts.length > rightParts.length
        ? leftParts.length
        : rightParts.length;
    for (var index = 0; index < length; index++) {
      final leftValue = index < leftParts.length ? leftParts[index] : 0;
      final rightValue = index < rightParts.length ? rightParts[index] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  static List<int> _versionParts(String value) {
    return value
        .split(RegExp(r'[^0-9]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}
