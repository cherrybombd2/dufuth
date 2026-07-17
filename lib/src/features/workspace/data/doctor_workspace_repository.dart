import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';
import '../../availability_slots/domain/availability_slot.dart';

final doctorWorkspaceRepositoryProvider = Provider<DoctorWorkspaceRepository>(
  (ref) => DoctorWorkspaceRepository(auth: ref.watch(firebaseAuthProvider)),
);

class DoctorWorkspaceAppointment {
  const DoctorWorkspaceAppointment({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.departmentName,
    required this.scheduledFor,
    required this.status,
    required this.createdAt,
    this.patientName,
    this.patientGender,
    this.slotId,
  });

  factory DoctorWorkspaceAppointment.fromJson(Map<String, dynamic> json) {
    return DoctorWorkspaceAppointment(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      patientName: json['patient_name'] as String?,
      patientGender: json['patient_gender'] as String?,
      doctorId: json['doctor_id'] as String? ?? '',
      departmentName: json['department'] as String? ?? '',
      scheduledFor: DateTime.parse(json['scheduled_for'] as String).toLocal(),
      slotId: json['slot_id'] as String?,
      status: json['status'] as String? ?? 'booked',
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String patientId;
  final String? patientName;
  final String? patientGender;
  final String doctorId;
  final String departmentName;
  final DateTime scheduledFor;
  final String? slotId;
  final String status;
  final DateTime createdAt;

  bool get isBooked => status == 'booked';

  bool get isCancelled => status == 'cancelled';

  bool get isUpcoming => !isCancelled && scheduledFor.add(const Duration(minutes: 30)).isAfter(DateTime.now());

  bool get isToday {
    final now = DateTime.now();
    return scheduledFor.year == now.year &&
        scheduledFor.month == now.month &&
        scheduledFor.day == now.day;
  }
}

class DoctorWorkspaceData {
  const DoctorWorkspaceData({
    required this.appointments,
  });

  final List<DoctorWorkspaceAppointment> appointments;
}

class DoctorWorkspaceAlert {
  const DoctorWorkspaceAlert({
    required this.id,
    required this.doctorId,
    required this.alertType,
    required this.title,
    required this.message,
    required this.remindAt,
    required this.status,
    required this.createdAt,
    this.patientId,
    this.patientName,
    this.patientGender,
    this.departmentName,
    this.appointmentId,
    this.slotId,
    this.appointmentStartAt,
    this.appointmentEndAt,
  });

  factory DoctorWorkspaceAlert.fromJson(Map<String, dynamic> json) {
    return DoctorWorkspaceAlert(
      id: json['id'] as String? ?? '',
      doctorId: json['doctor_id'] as String? ?? '',
      patientId: json['patient_id'] as String?,
      patientName: json['patient_name'] as String?,
      patientGender: json['patient_gender'] as String?,
      departmentName: json['department_name'] as String?,
      alertType: json['alert_type'] as String? ?? 'new_booking',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      remindAt: DateTime.parse(json['remind_at'] as String).toLocal(),
      status: json['status'] as String? ?? 'pending',
      appointmentId: json['appointment_id'] as String?,
      slotId: json['slot_id'] as String?,
      appointmentStartAt: _parseWorkspaceDate(json['appointment_start_at']),
      appointmentEndAt: _parseWorkspaceDate(json['appointment_end_at']),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    );
  }

  final String id;
  final String doctorId;
  final String? patientId;
  final String? patientName;
  final String? patientGender;
  final String? departmentName;
  final String alertType;
  final String title;
  final String message;
  final DateTime remindAt;
  final String status;
  final String? appointmentId;
  final String? slotId;
  final DateTime? appointmentStartAt;
  final DateTime? appointmentEndAt;
  final DateTime createdAt;

  bool get isPending => status == 'pending';

  bool get isDismissed => status == 'dismissed';

  DoctorWorkspaceAlert copyWith({String? status}) {
    return DoctorWorkspaceAlert(
      id: id,
      doctorId: doctorId,
      patientId: patientId,
      patientName: patientName,
      patientGender: patientGender,
      departmentName: departmentName,
      alertType: alertType,
      title: title,
      message: message,
      remindAt: remindAt,
      status: status ?? this.status,
      appointmentId: appointmentId,
      slotId: slotId,
      appointmentStartAt: appointmentStartAt,
      appointmentEndAt: appointmentEndAt,
      createdAt: createdAt,
    );
  }
}

class DoctorDayScheduleData {
  const DoctorDayScheduleData({
    required this.selectedDate,
    required this.slots,
    required this.appointments,
  });

  final DateTime selectedDate;
  final List<AvailabilitySlot> slots;
  final List<DoctorWorkspaceAppointment> appointments;
}

class DoctorWorkspaceRepository {
  DoctorWorkspaceRepository({FirebaseAuth? auth, http.Client? client})
      : _auth = auth,
        _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static DoctorWorkspaceData? _cachedData;
  static final Map<String, DoctorDayScheduleData> _cachedDaySchedules = {};
  static List<DoctorWorkspaceAlert>? _cachedAlerts;

  DoctorWorkspaceData? get cachedData => _cachedData;

  List<DoctorWorkspaceAlert>? get cachedAlerts => _cachedAlerts;

  DoctorDayScheduleData? cachedDaySchedule(String doctorId, DateTime selectedDate) {
    return _cachedDaySchedules[_dayScheduleKey(doctorId, selectedDate)];
  }

  Future<DoctorWorkspaceData> fetchSchedule(String doctorId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/doctors/$doctorId/schedule'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final appointments = (json['appointments'] as List<dynamic>? ?? const [])
            .map((item) => DoctorWorkspaceAppointment.fromJson(item as Map<String, dynamic>))
            .toList();
        _cachedData = DoctorWorkspaceData(appointments: appointments);
        return _cachedData!;
      }
      throw DoctorWorkspaceException(_backendMessage(response.body));
    } on SocketException {
      throw const DoctorWorkspaceException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const DoctorWorkspaceException('The backend took too long to respond.');
    }
  }

  Future<DoctorDayScheduleData> fetchDaySchedule(
    String doctorId,
    DateTime selectedDate,
  ) async {
    try {
      final headers = await _authHeaders();
      final dateKey = _dateOnly(selectedDate);
      final slotUri =
          Uri.parse('${AppConfig.backendBaseUrl}/availability-slots').replace(
            queryParameters: {
              'doctor_id': doctorId,
              'selected_date': dateKey,
            },
          );
      final scheduleUri =
          Uri.parse('${AppConfig.backendBaseUrl}/doctors/$doctorId/schedule').replace(
        queryParameters: {'selected_date': dateKey},
      );
      final responses = await Future.wait([
        _client.get(slotUri, headers: headers).timeout(const Duration(seconds: 12)),
        _client.get(scheduleUri, headers: headers).timeout(const Duration(seconds: 12)),
      ]);
      if (responses.any((response) => response.statusCode != 200)) {
        final failed = responses.firstWhere((response) => response.statusCode != 200);
        throw DoctorWorkspaceException(_backendMessage(failed.body));
      }

      final slots = (jsonDecode(responses[0].body) as List<dynamic>)
          .map((item) => AvailabilitySlot.fromJson(item as Map<String, dynamic>))
          .toList();
      final appointments = (jsonDecode(responses[1].body) as Map<String, dynamic>)['appointments']
              as List<dynamic>? ??
          const [];
      final parsedAppointments = appointments
          .map((item) => DoctorWorkspaceAppointment.fromJson(item as Map<String, dynamic>))
          .where((item) => _sameDate(item.scheduledFor, selectedDate))
          .toList()
        ..sort((a, b) => a.scheduledFor.compareTo(b.scheduledFor));

      final data = DoctorDayScheduleData(
        selectedDate: DateTime(selectedDate.year, selectedDate.month, selectedDate.day),
        slots: slots..sort((a, b) => a.startAt.compareTo(b.startAt)),
        appointments: parsedAppointments,
      );
      _cachedDaySchedules[_dayScheduleKey(doctorId, selectedDate)] = data;
      return data;
    } on SocketException {
      throw const DoctorWorkspaceException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const DoctorWorkspaceException('The backend took too long to respond.');
    }
  }

  Future<DoctorWorkspaceAppointment> fetchAppointmentDetail(String appointmentId) async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/doctors/appointments/$appointmentId'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        return DoctorWorkspaceAppointment.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
      }
      throw DoctorWorkspaceException(_backendMessage(response.body));
    } on SocketException {
      throw const DoctorWorkspaceException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const DoctorWorkspaceException('The backend took too long to respond.');
    }
  }

  Future<List<DoctorWorkspaceAlert>> fetchAlerts() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/doctors/alerts'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final alerts = (jsonDecode(response.body) as List<dynamic>)
            .map((item) => DoctorWorkspaceAlert.fromJson(item as Map<String, dynamic>))
            .toList();
        _cachedAlerts = alerts;
        return alerts;
      }
      throw DoctorWorkspaceException(_backendMessage(response.body));
    } on SocketException {
      throw const DoctorWorkspaceException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const DoctorWorkspaceException('The backend took too long to respond.');
    }
  }

  Future<DoctorWorkspaceAlert> updateAlertStatus(String alertId, String status) async {
    try {
      final response = await _client
          .patch(
            Uri.parse(
              '${AppConfig.backendBaseUrl}/doctors/alerts/${Uri.encodeComponent(alertId)}/status',
            ),
            headers: await _authHeaders(),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final alert = DoctorWorkspaceAlert.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _cachedAlerts = _cachedAlerts
            ?.map((item) => item.id == alert.id ? alert : item)
            .toList();
        return alert;
      }
      throw DoctorWorkspaceException(_backendMessage(response.body));
    } on SocketException {
      throw const DoctorWorkspaceException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const DoctorWorkspaceException('The backend took too long to respond.');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken(true);
    if (token == null) {
      throw const DoctorWorkspaceException(
        'Please sign in again before viewing your dashboard.',
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
    return 'We could not load the doctor workspace right now.';
  }

  String _dayScheduleKey(String doctorId, DateTime selectedDate) {
    return '$doctorId:${_dateOnly(selectedDate)}';
  }

  bool _sameDate(DateTime left, DateTime right) {
    return left.year == right.year &&
        left.month == right.month &&
        left.day == right.day;
  }

  String _dateOnly(DateTime value) {
    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

}

DateTime? _parseWorkspaceDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.parse(value).toLocal();
}

class DoctorWorkspaceException implements Exception {
  const DoctorWorkspaceException(this.message);

  final String message;

  @override
  String toString() => message;
}
