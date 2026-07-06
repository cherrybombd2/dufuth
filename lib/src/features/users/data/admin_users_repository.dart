import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>((ref) {
  return AdminUsersRepository(auth: ref.watch(firebaseAuthProvider));
});

class AdminUsersRepository {
  AdminUsersRepository({FirebaseAuth? auth, http.Client? client})
    : _auth = auth,
      _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static AdminUsersData? _cachedData;

  AdminUsersData? get cachedData => _cachedData;

  Future<AdminUsersData> fetch(AdminUserFilters filters) async {
    try {
      final uri = Uri.parse(
        '${AppConfig.backendBaseUrl}/users/admin',
      ).replace(queryParameters: filters.toQueryParameters());
      final response = await _client
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        final users = json
            .map((item) => AdminUserAccount.fromJson(item as Map<String, dynamic>))
            .toList();
        _cachedData = AdminUsersData(
          users: users,
          currentUserId: _auth?.currentUser?.uid,
        );
        return _cachedData!;
      }
      throw AdminUsersException(_backendMessage(response.body));
    } on SocketException {
      throw const AdminUsersException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const AdminUsersException('The backend took too long to respond.');
    }
  }

  Future<void> updateStatus({
    required String userId,
    required String status,
  }) async {
    try {
      final response = await _client
          .patch(
            Uri.parse(
              '${AppConfig.backendBaseUrl}/users/admin/${Uri.encodeComponent(userId)}/status',
            ),
            headers: await _authHeaders(),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return;
      }
      throw AdminUsersException(_backendMessage(response.body));
    } on SocketException {
      throw const AdminUsersException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const AdminUsersException('The backend took too long to respond.');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken(true);
    if (token == null) {
      throw const AdminUsersException('Please sign in again before continuing.');
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
    return 'We could not load users right now.';
  }
}

class AdminUsersData {
  const AdminUsersData({
    required this.users,
    required this.currentUserId,
  });

  final List<AdminUserAccount> users;
  final String? currentUserId;
}

class AdminUserFilters {
  const AdminUserFilters({
    this.role,
    this.status,
    this.query,
  });

  final String? role;
  final String? status;
  final String? query;

  Map<String, String> toQueryParameters() {
    return {
      if (role != null && role!.isNotEmpty) 'role': role!,
      if (status != null && status!.isNotEmpty) 'status': status!,
      if (query != null && query!.trim().isNotEmpty) 'query': query!.trim(),
    };
  }
}

class AdminUserAccount {
  const AdminUserAccount({
    required this.uid,
    required this.role,
    required this.status,
    this.email,
    this.fullName,
    this.phone,
  });

  final String uid;
  final String? email;
  final String role;
  final String status;
  final String? fullName;
  final String? phone;

  bool get isActive => status == 'active';

  String get displayName {
    final name = fullName?.trim();
    if (name != null && name.isNotEmpty) return name;
    final userEmail = email?.trim();
    if (userEmail != null && userEmail.isNotEmpty) return userEmail;
    return 'User';
  }

  factory AdminUserAccount.fromJson(Map<String, dynamic> json) {
    return AdminUserAccount(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String? ?? 'patient',
      status: json['status'] as String? ?? 'active',
      fullName: json['full_name'] as String?,
      phone: json['phone'] as String?,
    );
  }
}

class AdminUsersException implements Exception {
  const AdminUsersException(this.message);

  final String message;

  @override
  String toString() => message;
}
