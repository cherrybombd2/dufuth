import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';
import '../domain/faq_item.dart';

final faqRepositoryProvider = Provider<FaqRepository>((ref) {
  return FaqRepository(auth: ref.watch(firebaseAuthProvider));
});

class FaqRepository {
  FaqRepository({FirebaseAuth? auth, http.Client? client})
      : _auth = auth,
        _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static List<FaqItem>? _cachedPatientItems;
  static List<FaqItem>? _cachedAdminItems;

  List<FaqItem>? get cachedPatientItems => _cachedPatientItems;
  List<FaqItem>? get cachedAdminItems => _cachedAdminItems;

  Future<List<FaqItem>> fetchPatientItems() async {
    final items = await _getItems('${AppConfig.backendBaseUrl}/faq-items');
    _cachedPatientItems = items;
    return items;
  }

  Future<List<FaqItem>> fetchAdminItems() async {
    final items = await _getItems(
      '${AppConfig.backendBaseUrl}/faq-items/admin',
      authRequired: true,
    );
    _cachedAdminItems = items;
    return items;
  }

  Future<FaqItem> create(FaqDraft draft) async {
    final item = await _sendItem(
      method: 'POST',
      url: '${AppConfig.backendBaseUrl}/faq-items/admin',
      body: draft.toJson(),
    );
    await fetchAdminItems();
    _cachedPatientItems = null;
    return item;
  }

  Future<FaqItem> update(String id, FaqDraft draft) async {
    final item = await _sendItem(
      method: 'PUT',
      url: '${AppConfig.backendBaseUrl}/faq-items/admin/$id',
      body: draft.toJson(),
    );
    await fetchAdminItems();
    _cachedPatientItems = null;
    return item;
  }

  Future<FaqItem> setActive(String id, bool isActive) async {
    final item = await _sendItem(
      method: 'PATCH',
      url: '${AppConfig.backendBaseUrl}/faq-items/admin/$id/active',
      body: {'is_active': isActive},
    );
    _cachedAdminItems = _cachedAdminItems
        ?.map((cached) => cached.id == id ? item : cached)
        .toList();
    _cachedPatientItems = null;
    return item;
  }

  Future<List<FaqItem>> _getItems(
    String url, {
    bool authRequired = false,
  }) async {
    try {
      final headers = authRequired ? await _authHeaders() : <String, String>{};
      final response = await _client
          .get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 12));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as List<dynamic>;
        return json
            .map((item) => FaqItem.fromJson(item as Map<String, dynamic>))
            .toList();
      }
      throw FaqException(_backendMessage(response.body));
    } on SocketException {
      throw const FaqException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const FaqException('The backend took too long to respond.');
    }
  }

  Future<FaqItem> _sendItem({
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
        return FaqItem.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
      }
      throw FaqException(_backendMessage(response.body));
    } on SocketException {
      throw const FaqException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const FaqException('The backend took too long to respond.');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken(true);
    if (token == null) {
      throw const FaqException('Please sign in again before continuing.');
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
    return 'We could not load FAQ items right now.';
  }
}

class FaqException implements Exception {
  const FaqException(this.message);

  final String message;

  @override
  String toString() => message;
}
