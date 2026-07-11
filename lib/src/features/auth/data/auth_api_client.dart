import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../domain/auth_flow_exception.dart';
import '../domain/app_session.dart';

class AuthApiClient {
  AuthApiClient({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<AppSession> fetchSession(User user) async {
    final session = await _fetchSessionWithToken(
      await user.getIdToken(),
    );

    if (session.status == AppSessionStatus.tokenExpired) {
      final refreshed = await _fetchSessionWithToken(
        await user.getIdToken(true),
      );
      if (refreshed.status == AppSessionStatus.tokenExpired) {
        return const AppSession.tokenExpired(
          message: 'Your session expired. Please sign in again.',
        );
      }
      return refreshed;
    }

    return session;
  }

  Future<void> registerDeviceToken({
    required User user,
    required String token,
    required String platform,
  }) async {
    final idToken = await user.getIdToken();
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/device-token');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $idToken',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({
              'token': token,
              'platform': platform,
            }),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }

      throw AuthFlowException(_parseBackendMessage(response.body, response.statusCode));
    } on SocketException {
      throw const AuthFlowException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const AuthFlowException('The backend took too long to respond.');
    }
  }

  Future<AppSession> createPatientProfile({
    required User user,
    required String fullName,
    required String phoneNumber,
    required String gender,
    required String address,
    String? dateOfBirth,
  }) async {
    final token = await user.getIdToken(true);
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/patient-profile');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({
              'full_name': fullName,
              'phone_number': phoneNumber,
              'gender': gender,
              'address': address,
              'date_of_birth': dateOfBirth,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseSessionResponse(response.body);
      }

      throw AuthFlowException(_parseBackendMessage(response.body, response.statusCode));
    } on SocketException {
      throw const AuthFlowException(
        'The backend is unreachable right now. Check that FastAPI is running.',
      );
    } on TimeoutException {
      throw const AuthFlowException('The backend took too long to respond.');
    }
  }

  Future<AppSession> updatePatientProfile({
    required User user,
    required String fullName,
    String? phoneNumber,
    String? gender,
    String? address,
    String? dateOfBirth,
  }) async {
    final token = await user.getIdToken(true);
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/patient-profile');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode({
              'full_name': fullName,
              'phone_number': phoneNumber,
              'gender': gender,
              'address': address,
              'date_of_birth': dateOfBirth,
            }),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return _parseSessionResponse(response.body);
      }

      throw AuthFlowException(_parseBackendMessage(response.body, response.statusCode));
    } on SocketException {
      throw const AuthFlowException(
        'The backend is unreachable right now. Check that FastAPI is running.',
      );
    } on TimeoutException {
      throw const AuthFlowException('The backend took too long to respond.');
    }
  }

  Future<AppSession> _fetchSessionWithToken(String? token) async {
    if (token == null) {
      return const AppSession.tokenExpired(
        message: 'Authentication token is unavailable.',
      );
    }

    final uri = Uri.parse('${AppConfig.backendBaseUrl}/auth/session');

    try {
      final response = await _client
          .get(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        return _parseSessionResponse(response.body);
      }

      if (response.statusCode == 404) {
        final missingProfile = _parseMissingProfileResponse(response.body);
        if (missingProfile != null || response.body.contains('PROFILE_MISSING')) {
          return AppSession.profileMissing(
            message: 'Your account exists, but your profile is missing.',
            role: missingProfile,
          );
        }
      }

      if (response.statusCode == 401) {
        return const AppSession.tokenExpired();
      }

      return AppSession.backendUnavailable(
        message: _parseBackendMessage(response.body, response.statusCode),
      );
    } on SocketException {
      return const AppSession.backendUnavailable(
        message: 'The backend is unreachable right now.',
      );
    } on TimeoutException {
      return const AppSession.backendUnavailable(
        message: 'The backend timed out while verifying your session.',
      );
    }
  }

  AppSession _parseSessionResponse(String body) {
    final json = jsonDecode(body) as Map<String, dynamic>;
    return AppSession(
      status: AppSessionStatus.authenticated,
      user: SessionUser.fromJson(json['user'] as Map<String, dynamic>),
      profile: SessionProfile.fromJson(json['profile'] as Map<String, dynamic>),
    );
  }

  String _parseBackendMessage(String body, int statusCode) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final detail = json['detail'];
      if (detail is String && detail.isNotEmpty) {
        if (detail == 'PROFILE_MISSING') {
          return 'Your account exists, but your profile is missing.';
        }
        return detail;
      }
    } catch (_) {
      // Fall back to a generic message.
    }
    return 'Backend request failed with status $statusCode.';
  }

  String? _parseMissingProfileResponse(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final detail = json['detail'];
      if (detail is String && detail == 'PROFILE_MISSING') {
        return null;
      }
      if (detail is Map<String, dynamic> && detail['code'] == 'PROFILE_MISSING') {
        final role = detail['role'];
        if (role is String && role.isNotEmpty) {
          return role;
        }
        return null;
      }
    } catch (_) {
      // Ignore parse errors and fall back.
    }
    if (body.contains('PROFILE_MISSING')) {
      return null;
    }
    return null;
  }
}
