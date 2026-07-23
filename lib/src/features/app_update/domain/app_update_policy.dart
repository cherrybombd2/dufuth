class AppUpdatePolicy {
  const AppUpdatePolicy({
    required this.minimumRequiredVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.downloadUrl,
    required this.message,
  });

  factory AppUpdatePolicy.fromJson(Map<String, dynamic> json) {
    return AppUpdatePolicy(
      minimumRequiredVersion: _stringValue(json['minimumRequiredVersion']) ??
          _stringValue(json['minimum_required_version']) ??
          '1.0.0',
      latestVersion: _stringValue(json['latestVersion']) ??
          _stringValue(json['latest_version']) ??
          '1.0.0',
      forceUpdate: _boolValue(json['forceUpdate']) ??
          _boolValue(json['force_update']) ??
          false,
      downloadUrl: _stringValue(json['downloadUrl']) ??
          _stringValue(json['download_url']) ??
          'https://dufuth-smartcare-download.netlify.app/',
      message: _stringValue(json['message']) ??
          'Please update DUFUTH SmartCare to continue.',
    );
  }

  final String minimumRequiredVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String downloadUrl;
  final String message;

  bool requiresUpdate(String installedVersion) {
    return forceUpdate &&
        compareSemanticVersions(installedVersion, minimumRequiredVersion) < 0;
  }
}

int compareSemanticVersions(String left, String right) {
  final leftParts = _numericParts(left);
  final rightParts = _numericParts(right);
  final length = leftParts.length > rightParts.length
      ? leftParts.length
      : rightParts.length;

  for (var index = 0; index < length; index += 1) {
    final leftValue = index < leftParts.length ? leftParts[index] : 0;
    final rightValue = index < rightParts.length ? rightParts[index] : 0;
    if (leftValue != rightValue) {
      return leftValue.compareTo(rightValue);
    }
  }
  return 0;
}

List<int> _numericParts(String version) {
  final baseVersion = version.split('+').first.split('-').first;
  return baseVersion
      .split('.')
      .map((part) => int.tryParse(part.trim()) ?? 0)
      .toList(growable: false);
}

String? _stringValue(Object? value) {
  if (value is String && value.trim().isNotEmpty) {
    return value.trim();
  }
  return null;
}

bool? _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    final normalized = value.trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'yes') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'no') {
      return false;
    }
  }
  return null;
}
