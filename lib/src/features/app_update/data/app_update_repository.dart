import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../core/app_config.dart';
import '../domain/app_update_policy.dart';

final appUpdateRepositoryProvider = Provider<AppUpdateRepository>((ref) {
  return AppUpdateRepository();
});

class AppUpdateGateResult {
  const AppUpdateGateResult({
    required this.installedVersion,
    required this.policy,
    required this.isUpdateRequired,
  });

  const AppUpdateGateResult.notRequired({
    required this.installedVersion,
    this.policy,
  }) : isUpdateRequired = false;

  final String installedVersion;
  final AppUpdatePolicy? policy;
  final bool isUpdateRequired;
}

class AppUpdateRepository {
  AppUpdateRepository({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AppUpdateGateResult> checkForRequiredUpdate() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final installedVersion = packageInfo.version;

    try {
      final response = await _client
          .get(Uri.parse('${AppConfig.backendBaseUrl}/app-version'))
          .timeout(const Duration(seconds: 6));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return AppUpdateGateResult.notRequired(
          installedVersion: installedVersion,
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final policy = AppUpdatePolicy.fromJson(json);
      return AppUpdateGateResult(
        installedVersion: installedVersion,
        policy: policy,
        isUpdateRequired: policy.requiresUpdate(installedVersion),
      );
    } on SocketException {
      return AppUpdateGateResult.notRequired(
        installedVersion: installedVersion,
      );
    } on TimeoutException {
      return AppUpdateGateResult.notRequired(
        installedVersion: installedVersion,
      );
    } on FormatException {
      return AppUpdateGateResult.notRequired(
        installedVersion: installedVersion,
      );
    }
  }
}
