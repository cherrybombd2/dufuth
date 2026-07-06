import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';
import '../domain/hospital_info.dart';

final hospitalInfoRepositoryProvider = Provider<HospitalInfoRepository>((ref) {
  return HospitalInfoRepository(auth: ref.watch(firebaseAuthProvider));
});

class HospitalInfoRepository {
  HospitalInfoRepository({FirebaseAuth? auth, http.Client? client})
    : _auth = auth,
      _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static HospitalInfo? _cachedInfo;

  HospitalInfo? get cachedInfo => _cachedInfo;

  Future<HospitalInfo> fetch() async {
    final uri = Uri.parse('${AppConfig.backendBaseUrl}/hospital-info');
    try {
      final response = await _client
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        _cachedInfo = HospitalInfo.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        return _cachedInfo!;
      }
      throw HospitalInfoException(_backendMessage(response.body));
    } on SocketException {
      throw const HospitalInfoException(
        'The backend is unreachable right now.',
      );
    } on TimeoutException {
      throw const HospitalInfoException(
        'The backend took too long to respond.',
      );
    }
  }

  Future<HospitalInfo> update(HospitalInfo info) async {
    final user = _auth?.currentUser;
    final token = await user?.getIdToken(true);
    if (token == null) {
      throw const HospitalInfoException('Please sign in again before saving.');
    }

    final uri = Uri.parse('${AppConfig.backendBaseUrl}/hospital-info');
    try {
      final response = await _client
          .put(
            uri,
            headers: {
              HttpHeaders.authorizationHeader: 'Bearer $token',
              HttpHeaders.contentTypeHeader: 'application/json',
            },
            body: jsonEncode(info.toJson()),
          )
          .timeout(const Duration(seconds: 12));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        _cachedInfo = HospitalInfo.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        return _cachedInfo!;
      }
      throw HospitalInfoException(_backendMessage(response.body));
    } on SocketException {
      throw const HospitalInfoException(
        'The backend is unreachable right now.',
      );
    } on TimeoutException {
      throw const HospitalInfoException(
        'The backend took too long to respond.',
      );
    }
  }

  String _backendMessage(String body) {
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final detail = json['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    } catch (_) {
      // Use the friendly fallback below.
    }
    return 'We could not load hospital information right now.';
  }
}

class HospitalInfoException implements Exception {
  const HospitalInfoException(this.message);

  final String message;

  @override
  String toString() => message;
}
