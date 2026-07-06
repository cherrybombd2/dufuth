import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';
import '../../departments/domain/department.dart';
import '../domain/doctor.dart';

final doctorManagementRepositoryProvider = Provider<DoctorManagementRepository>(
  (ref) {
    return DoctorManagementRepository(auth: ref.watch(firebaseAuthProvider));
  },
);

class DoctorManagementData {
  const DoctorManagementData({
    required this.doctors,
    required this.departments,
  });

  final List<Doctor> doctors;
  final List<Department> departments;
}

class DoctorManagementRepository {
  DoctorManagementRepository({FirebaseAuth? auth, http.Client? client})
    : _auth = auth,
      _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static DoctorManagementData? _cachedData;

  DoctorManagementData? get cachedData => _cachedData;

  Future<DoctorManagementData> fetch() async {
    final headers = await _authHeaders();
    try {
      final responses = await Future.wait([
        _client
            .get(
              Uri.parse('${AppConfig.backendBaseUrl}/doctors/admin'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12)),
        _client
            .get(
              Uri.parse('${AppConfig.backendBaseUrl}/departments'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12)),
      ]);

      if (responses.any((response) => response.statusCode != 200)) {
        final failed = responses.firstWhere(
          (response) => response.statusCode != 200,
        );
        throw DoctorManagementException(_backendMessage(failed.body));
      }

      final doctorsJson = jsonDecode(responses[0].body) as List<dynamic>;
      final departmentsJson = jsonDecode(responses[1].body) as List<dynamic>;
      _cachedData = DoctorManagementData(
        doctors: doctorsJson
            .map((item) => Doctor.fromJson(item as Map<String, dynamic>))
            .toList(),
        departments: departmentsJson
            .map((item) => Department.fromJson(item as Map<String, dynamic>))
            .toList(),
      );
      return _cachedData!;
    } on SocketException {
      throw const DoctorManagementException(
        'The backend is unreachable right now.',
      );
    } on TimeoutException {
      throw const DoctorManagementException(
        'The backend took too long to respond.',
      );
    }
  }

  Future<List<UserLookupResult>> searchAccounts(String query) async {
    if (query.trim().length < 3) {
      return [];
    }
    try {
      final response = await _client
          .get(
            Uri.parse(
              '${AppConfig.backendBaseUrl}/doctors/admin/user-search?query=${Uri.encodeQueryComponent(query.trim())}',
            ),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json
            .map(
              (item) => UserLookupResult.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      throw DoctorManagementException(_backendMessage(response.body));
    } on SocketException {
      throw const DoctorManagementException(
        'The backend is unreachable right now.',
      );
    } on TimeoutException {
      throw const DoctorManagementException(
        'The backend took too long to respond.',
      );
    }
  }

  Future<Doctor> create(DoctorDraft draft) async {
    final doctor = await _sendDoctor(
      method: 'POST',
      url: '${AppConfig.backendBaseUrl}/doctors/admin',
      body: draft.toJson(),
    );
    await fetch();
    return doctor;
  }

  Future<Doctor> update(String doctorId, DoctorDraft draft) async {
    final doctor = await _sendDoctor(
      method: 'PUT',
      url:
          '${AppConfig.backendBaseUrl}/doctors/admin/${Uri.encodeComponent(doctorId)}',
      body: draft.toJson(),
    );
    await fetch();
    return doctor;
  }

  Future<Doctor> setActive(
    String doctorId,
    bool isActive, {
    bool forceDeactivate = false,
  }) async {
    final doctor = await _sendDoctor(
      method: 'PATCH',
      url:
          '${AppConfig.backendBaseUrl}/doctors/admin/${Uri.encodeComponent(doctorId)}/active',
      body: {'is_active': isActive, 'force_deactivate': forceDeactivate},
    );
    await fetch();
    return doctor;
  }

  Future<Doctor> _sendDoctor({
    required String method,
    required String url,
    required Map<String, dynamic> body,
  }) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _authHeaders();
      late final http.Response response;
      if (method == 'POST') {
        response = await _client
            .post(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 12));
      } else if (method == 'PUT') {
        response = await _client
            .put(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 12));
      } else {
        response = await _client
            .patch(uri, headers: headers, body: jsonEncode(body))
            .timeout(const Duration(seconds: 12));
      }
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return Doctor.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      throw DoctorManagementException(
        _backendMessage(response.body),
        statusCode: response.statusCode,
      );
    } on SocketException {
      throw const DoctorManagementException(
        'The backend is unreachable right now.',
      );
    } on TimeoutException {
      throw const DoctorManagementException(
        'The backend took too long to respond.',
      );
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken(true);
    if (token == null) {
      throw const DoctorManagementException(
        'Please sign in again before continuing.',
      );
    }
    return {
      HttpHeaders.authorizationHeader: 'Bearer $token',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
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
    return 'We could not load doctors right now.';
  }
}

class DoctorManagementException implements Exception {
  const DoctorManagementException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}
