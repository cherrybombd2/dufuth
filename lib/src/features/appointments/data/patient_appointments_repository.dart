import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';
import '../../booking/data/booking_repository.dart';

final patientAppointmentsRepositoryProvider =
    Provider<PatientAppointmentsRepository>((ref) {
  return PatientAppointmentsRepository(auth: ref.watch(firebaseAuthProvider));
});

class PatientAppointment {
  const PatientAppointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.doctorName,
    this.doctorGender,
    required this.departmentId,
    required this.departmentName,
    required this.startAt,
    required this.endAt,
    required this.status,
    this.slotId,
  });

  factory PatientAppointment.fromJson(Map<String, dynamic> json) {
    return PatientAppointment(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      doctorId: json['doctor_id'] as String? ?? '',
      doctorName: json['doctor_name'] as String? ?? 'Doctor',
      doctorGender: json['doctor_gender'] as String?,
      departmentId: json['department_id'] as String? ?? '',
      departmentName: json['department_name'] as String? ?? '',
      startAt: DateTime.parse(json['start_at'] as String).toLocal(),
      endAt: DateTime.parse(json['end_at'] as String).toLocal(),
      slotId: json['slot_id'] as String?,
      status: json['status'] as String? ?? 'booked',
    );
  }

  final String id;
  final String patientId;
  final String doctorId;
  final String doctorName;
  final String? doctorGender;
  final String departmentId;
  final String departmentName;
  final DateTime startAt;
  final DateTime endAt;
  final String? slotId;
  final String status;

  bool get isCancelled => status == 'cancelled';

  bool get isPast => endAt.isBefore(DateTime.now());

  bool get isUpcoming => !isCancelled && !isPast;

  PatientAppointment markCancelled() {
    return PatientAppointment(
      id: id,
      patientId: patientId,
      doctorId: doctorId,
      doctorName: doctorName,
      doctorGender: doctorGender,
      departmentId: departmentId,
      departmentName: departmentName,
      startAt: startAt,
      endAt: endAt,
      slotId: slotId,
      status: 'cancelled',
    );
  }

  BookingAppointment toBookingAppointment() {
    return BookingAppointment(
      id: id,
      departmentId: departmentId,
      departmentName: departmentName,
      doctorId: doctorId,
      doctorName: doctorName,
      startAt: startAt,
      endAt: endAt,
    );
  }
}

class PatientAppointmentsRepository {
  PatientAppointmentsRepository({FirebaseAuth? auth, http.Client? client})
      : _auth = auth,
        _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static List<PatientAppointment>? _cachedAppointments;
  static DateTime? _cachedAppointmentsAt;
  static Future<List<PatientAppointment>>? _inFlightFetch;
  static const Duration _appointmentsTtl = Duration(seconds: 45);

  List<PatientAppointment>? get cachedAppointments => _cachedAppointments;
  bool get hasFreshCachedAppointments =>
      _cachedAppointments != null &&
      _cachedAppointmentsAt != null &&
      DateTime.now().difference(_cachedAppointmentsAt!) <= _appointmentsTtl;

  Future<List<PatientAppointment>> fetchAppointments({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _inFlightFetch != null) {
      return _inFlightFetch!;
    }
    if (!forceRefresh && hasFreshCachedAppointments) {
      return _cachedAppointments!;
    }
    final request = _fetchAppointmentsFromNetwork();
    _inFlightFetch = request;
    try {
      return await request;
    } finally {
      if (identical(_inFlightFetch, request)) {
        _inFlightFetch = null;
      }
    }
  }

  Future<List<PatientAppointment>> _fetchAppointmentsFromNetwork() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/appointments/mine'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final appointments = (jsonDecode(response.body) as List<dynamic>)
            .map((item) => PatientAppointment.fromJson(item as Map<String, dynamic>))
            .toList();
        _cachedAppointments = appointments;
        _cachedAppointmentsAt = DateTime.now();
        return appointments;
      }
      throw PatientAppointmentsException(_backendMessage(response.body));
    } on SocketException {
      throw const PatientAppointmentsException(
        'The backend is unreachable right now.',
      );
    } on TimeoutException {
      throw const PatientAppointmentsException(
        'The backend took too long to respond.',
      );
    }
  }

  Future<PatientAppointment> cancelAppointment(String appointmentId) async {
    try {
      final response = await _client
          .post(
            Uri.parse(
              '${AppConfig.backendBaseUrl}/appointments/${Uri.encodeComponent(appointmentId)}/cancel',
            ),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 18));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final appointment = PatientAppointment.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _cachedAppointments = _cachedAppointments
            ?.map((item) => item.id == appointment.id ? appointment : item)
            .toList();
        _cachedAppointmentsAt = DateTime.now();
        return appointment;
      }
      throw PatientAppointmentsException(_backendMessage(response.body));
    } on SocketException {
      throw const PatientAppointmentsException(
        'The backend is unreachable right now.',
      );
    } on TimeoutException {
      throw const PatientAppointmentsException(
        'The backend took too long to respond.',
      );
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken();
    if (token == null) {
      throw const PatientAppointmentsException(
        'Please sign in again before viewing appointments.',
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
      // Friendly fallback below.
    }
    return 'We could not load your appointments right now.';
  }
}

class PatientAppointmentsException implements Exception {
  const PatientAppointmentsException(this.message);

  final String message;

  @override
  String toString() => message;
}
