import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';
import '../domain/department.dart';

final departmentRepositoryProvider = Provider<DepartmentRepository>((ref) {
  return DepartmentRepository(auth: ref.watch(firebaseAuthProvider));
});

class DepartmentRepository {
  DepartmentRepository({FirebaseAuth? auth, http.Client? client})
    : _auth = auth,
      _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static List<Department>? _cachedDepartments;

  List<Department>? get cachedDepartments => _cachedDepartments;

  Future<List<Department>> fetch() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/departments'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        _cachedDepartments = json
            .map((item) => Department.fromJson(item as Map<String, dynamic>))
            .toList();
        return _cachedDepartments!;
      }
      throw DepartmentException(_backendMessage(response.body));
    } on SocketException {
      throw const DepartmentException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const DepartmentException('The backend took too long to respond.');
    }
  }

  Future<Department> create(DepartmentDraft draft) async {
    final department = await _sendDepartment(
      method: 'POST',
      url: '${AppConfig.backendBaseUrl}/departments',
      body: draft.toJson(),
    );
    await fetch();
    return department;
  }

  Future<Department> update(String currentName, DepartmentDraft draft) async {
    final department = await _sendDepartment(
      method: 'PUT',
      url:
          '${AppConfig.backendBaseUrl}/departments/${Uri.encodeComponent(currentName)}',
      body: draft.toJson(),
    );
    await fetch();
    return department;
  }

  Future<Department> setActive(String name, bool isActive) async {
    final department = await _sendDepartment(
      method: 'PATCH',
      url:
          '${AppConfig.backendBaseUrl}/departments/${Uri.encodeComponent(name)}/active',
      body: {'is_active': isActive},
    );
    await fetch();
    return department;
  }

  Future<void> delete(String name) async {
    try {
      final response = await _client
          .delete(
            Uri.parse(
              '${AppConfig.backendBaseUrl}/departments/${Uri.encodeComponent(name)}',
            ),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 204) {
        await fetch();
        return;
      }
      throw DepartmentException(_backendMessage(response.body));
    } on SocketException {
      throw const DepartmentException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const DepartmentException('The backend took too long to respond.');
    }
  }

  Future<Department> _sendDepartment({
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
        return Department.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      throw DepartmentException(_backendMessage(response.body));
    } on SocketException {
      throw const DepartmentException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const DepartmentException('The backend took too long to respond.');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken(true);
    if (token == null) {
      throw const DepartmentException(
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
    return 'We could not load departments right now.';
  }
}

class DepartmentException implements Exception {
  const DepartmentException(this.message);

  final String message;

  @override
  String toString() => message;
}
