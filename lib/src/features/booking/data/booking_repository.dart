import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';
import '../../availability_slots/domain/availability_slot.dart';
import '../../departments/domain/department.dart';
import '../../doctors/domain/doctor.dart';

final bookingRepositoryProvider = Provider<BookingRepository>((ref) {
  return BookingRepository(auth: ref.watch(firebaseAuthProvider));
});

class BookingData {
  const BookingData({required this.departments, required this.doctors});

  final List<Department> departments;
  final List<Doctor> doctors;
}

class BookingAppointment {
  const BookingAppointment({
    required this.id,
    required this.departmentId,
    required this.departmentName,
    required this.doctorId,
    required this.doctorName,
    required this.startAt,
    required this.endAt,
  });

  final String id;
  final String departmentId;
  final String departmentName;
  final String doctorId;
  final String doctorName;
  final DateTime startAt;
  final DateTime endAt;
}

class BookingRepository {
  BookingRepository({FirebaseAuth? auth, http.Client? client})
    : _auth = auth,
      _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static BookingData? _cachedData;

  BookingData? get cachedData => _cachedData;

  Future<BookingData> fetchReferenceData() async {
    final headers = await _authHeaders();
    try {
      final responses = await Future.wait([
        _client
            .get(
              Uri.parse('${AppConfig.backendBaseUrl}/departments/active'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12)),
        _client
            .get(
              Uri.parse('${AppConfig.backendBaseUrl}/doctors'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12)),
      ]);
      if (responses.any((response) => response.statusCode != 200)) {
        final failed = responses.firstWhere(
          (response) => response.statusCode != 200,
        );
        throw BookingException(_backendMessage(failed.body));
      }
      final departments = (jsonDecode(responses[0].body) as List<dynamic>)
          .map((item) => Department.fromJson(item as Map<String, dynamic>))
          .where((item) => item.isActive)
          .toList();
      final doctors = (jsonDecode(responses[1].body) as List<dynamic>)
          .map((item) => Doctor.fromJson(item as Map<String, dynamic>))
          .where((item) => item.isActive)
          .toList();
      _cachedData = BookingData(departments: departments, doctors: doctors);
      return _cachedData!;
    } on SocketException {
      throw const BookingException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const BookingException('The backend took too long to respond.');
    }
  }

  Future<List<AvailabilitySlot>> fetchAvailableSlots({
    required String departmentId,
    required String doctorId,
    required DateTime date,
  }) async {
    try {
      final uri =
          Uri.parse(
            '${AppConfig.backendBaseUrl}/availability-slots/available',
          ).replace(
            queryParameters: {
              'department_id': departmentId,
              'doctor_id': doctorId,
              'selected_date': _date(date),
            },
          );
      final response = await _client
          .get(uri, headers: await _authHeaders())
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return (jsonDecode(response.body) as List<dynamic>)
            .map(
              (item) => AvailabilitySlot.fromJson(item as Map<String, dynamic>),
            )
            .toList();
      }
      throw BookingException(_backendMessage(response.body));
    } on SocketException {
      throw const BookingException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const BookingException('The backend took too long to respond.');
    }
  }

  Future<void> confirmAppointment({
    required String departmentId,
    required String doctorId,
    required String slotId,
  }) async {
    await _send(
      'POST',
      '${AppConfig.backendBaseUrl}/appointments/book',
      {
        'department_id': departmentId,
        'doctor_id': doctorId,
        'slot_id': slotId,
      },
      expectedStatus: 201,
    );
  }

  Future<void> rescheduleAppointment({
    required String appointmentId,
    required String departmentId,
    required String doctorId,
    required String slotId,
  }) async {
    await _send(
      'POST',
      '${AppConfig.backendBaseUrl}/appointments/${Uri.encodeComponent(appointmentId)}/reschedule',
      {
        'department_id': departmentId,
        'doctor_id': doctorId,
        'slot_id': slotId,
      },
    );
  }

  Future<void> _send(
    String method,
    String url,
    Map<String, dynamic> body, {
    int expectedStatus = 200,
  }) async {
    try {
      final uri = Uri.parse(url);
      final response = switch (method) {
        'POST' =>
          await _client
              .post(
                uri,
                headers: await _authHeaders(),
                body: jsonEncode(body),
              )
              .timeout(const Duration(seconds: 18)),
        _ => throw const BookingException('Unsupported booking operation.'),
      };
      if (response.statusCode == expectedStatus ||
          (response.statusCode >= 200 && response.statusCode < 300)) {
        return;
      }
      throw BookingException(_backendMessage(response.body));
    } on SocketException {
      throw const BookingException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const BookingException('The backend took too long to respond.');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken(true);
    if (token == null) {
      throw const BookingException('Please sign in again before continuing.');
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
      // Friendly fallback below.
    }
    return 'We could not load booking data right now.';
  }
}

class BookingException implements Exception {
  const BookingException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _date(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}
