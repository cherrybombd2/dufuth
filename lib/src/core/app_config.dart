import 'dart:io';

class AppConfig {
  static const String _lanHost = '192.168.100.2';
  static const String _definedBackendBaseUrl = String.fromEnvironment(
    'DUFUTH_API_BASE_URL',
  );

  static String get backendBaseUrl {
    if (_definedBackendBaseUrl.isNotEmpty) {
      return _definedBackendBaseUrl;
    }

    if (Platform.isAndroid) {
      return 'http://$_lanHost:8000/api/v1';
    }
    return 'http://127.0.0.1:8000/api/v1';
  }
}
