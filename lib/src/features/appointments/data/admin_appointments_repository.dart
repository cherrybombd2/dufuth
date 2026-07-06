import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';
import '../../departments/domain/department.dart';
import '../../doctors/domain/doctor.dart';

final adminAppointmentsRepositoryProvider =
    Provider<AdminAppointmentsRepository>((ref) {
      return AdminAppointmentsRepository(auth: ref.watch(firebaseAuthProvider));
    });

class AdminAppointmentsData {
  const AdminAppointmentsData({
    required this.appointments,
    required this.departments,
    required this.doctors,
  });

  final List<AdminAppointment> appointments;
  final List<Department> departments;
  final List<Doctor> doctors;
}

class AdminAppointmentFilters {
  const AdminAppointmentFilters({
    this.departmentId,
    this.doctorId,
    this.date,
  });

  final String? departmentId;
  final String? doctorId;
  final DateTime? date;
}

class AdminAppointment {
  const AdminAppointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.departmentId,
    required this.departmentName,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.doctorName,
  });

  factory AdminAppointment.fromJson(Map<String, dynamic> json) {
    final start =
        _parseDateTime(json['start_at'] ?? json['scheduled_for']) ??
            DateTime.now();
    final end =
        _parseDateTime(json['end_at']) ?? start.add(const Duration(minutes: 30));
    return AdminAppointment(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      doctorId: json['doctor_id'] as String? ?? '',
      doctorName: json['doctor_name'] as String?,
      departmentId: _string(json['department_id']) ?? _string(json['department']) ?? '',
      departmentName:
          _string(json['department_name']) ?? _string(json['department']) ?? '',
      startAt: start,
      endAt: end,
      status: json['status'] as String? ?? 'booked',
    );
  }

  final String id;
  final String patientId;
  final String doctorId;
  final String? doctorName;
  final String departmentId;
  final String departmentName;
  final DateTime startAt;
  final DateTime endAt;
  final String status;

  bool get isCancelled => status.toLowerCase() == 'cancelled';

  bool get isPast => !endAt.isAfter(DateTime.now());

  bool get isUpcoming => !isCancelled && !isPast;

  static DateTime? _parseDateTime(Object? value) {
    if (value is String && value.isNotEmpty) {
      return DateTime.parse(value).toLocal();
    }
    return null;
  }

  static String? _string(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }
}

class AdminAppointmentsRepository {
  AdminAppointmentsRepository({FirebaseAuth? auth, http.Client? client})
    : _auth = auth,
      _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static AdminAppointmentsData? _cachedData;

  AdminAppointmentsData? get cachedData => _cachedData;

  Future<AdminAppointmentsData> fetch(AdminAppointmentFilters filters) async {
    final headers = await _authHeaders();
    try {
      final appointmentsUri =
          Uri.parse('${AppConfig.backendBaseUrl}/appointments').replace(
            queryParameters: {
              if (filters.departmentId != null)
                'department_id': filters.departmentId!,
              if (filters.doctorId != null) 'doctor_id': filters.doctorId!,
              if (filters.date != null) 'selected_date': _date(filters.date!),
            },
          );
      final responses = await Future.wait([
        _client
            .get(appointmentsUri, headers: headers)
            .timeout(const Duration(seconds: 12)),
        _client
            .get(
              Uri.parse('${AppConfig.backendBaseUrl}/departments'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12)),
        _client
            .get(
              Uri.parse('${AppConfig.backendBaseUrl}/doctors/admin'),
              headers: headers,
            )
            .timeout(const Duration(seconds: 12)),
      ]);

      if (responses.any((response) => response.statusCode != 200)) {
        final failed = responses.firstWhere(
          (response) => response.statusCode != 200,
        );
        throw AdminAppointmentsException(_backendMessage(failed.body));
      }

      final appointments = (jsonDecode(responses[0].body) as List<dynamic>)
          .map((item) => AdminAppointment.fromJson(item as Map<String, dynamic>))
          .toList();
      final departments = (jsonDecode(responses[1].body) as List<dynamic>)
          .map((item) => Department.fromJson(item as Map<String, dynamic>))
          .toList();
      final doctors = (jsonDecode(responses[2].body) as List<dynamic>)
          .map((item) => Doctor.fromJson(item as Map<String, dynamic>))
          .toList();

      _cachedData = AdminAppointmentsData(
        appointments: appointments,
        departments: departments,
        doctors: doctors,
      );
      return _cachedData!;
    } on SocketException {
      throw const AdminAppointmentsException(
        'The backend is unreachable right now.',
      );
    } on TimeoutException {
      throw const AdminAppointmentsException(
        'The backend took too long to respond.',
      );
    } on FormatException {
      throw const AdminAppointmentsException(
        'We could not read appointments right now.',
      );
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken(true);
    if (token == null) {
      throw const AdminAppointmentsException(
        'Please sign in again before continuing.',
      );
    }
    return {
      HttpHeaders.authorizationHeader: 'Bearer $token',
      HttpHeaders.contentTypeHeader: 'application/json',
    };
  }

  String _date(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
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
    return 'We could not load appointments right now.';
  }
}

class AdminAppointmentsException implements Exception {
  const AdminAppointmentsException(this.message);

  final String message;

  @override
  String toString() => message;
}
