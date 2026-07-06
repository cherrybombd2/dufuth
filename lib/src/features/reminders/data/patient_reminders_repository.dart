import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../core/app_config.dart';
import '../../../firebase/auth_providers.dart';

final patientRemindersRepositoryProvider = Provider<PatientRemindersRepository>(
  (ref) => PatientRemindersRepository(auth: ref.watch(firebaseAuthProvider)),
);

class PatientReminder {
  const PatientReminder({
    required this.id,
    required this.patientId,
    required this.reminderType,
    required this.title,
    required this.message,
    required this.remindAt,
    required this.status,
    this.appointmentId,
    this.slotId,
    this.doctorId,
    this.doctorName,
    this.doctorGender,
    this.departmentName,
    this.appointmentStartAt,
    this.appointmentEndAt,
  });

  factory PatientReminder.fromJson(Map<String, dynamic> json) {
    return PatientReminder(
      id: json['id'] as String? ?? '',
      patientId: json['patient_id'] as String? ?? '',
      reminderType: json['reminder_type'] as String? ?? '',
      title: json['title'] as String? ?? '',
      message: json['message'] as String? ?? '',
      remindAt: DateTime.parse(json['remind_at'] as String).toLocal(),
      status: json['status'] as String? ?? 'pending',
      appointmentId: json['appointment_id'] as String?,
      slotId: json['slot_id'] as String?,
      doctorId: json['doctor_id'] as String?,
      doctorName: json['doctor_name'] as String?,
      doctorGender: json['doctor_gender'] as String?,
      departmentName: json['department_name'] as String?,
      appointmentStartAt: _parseDate(json['appointment_start_at']),
      appointmentEndAt: _parseDate(json['appointment_end_at']),
    );
  }

  final String id;
  final String patientId;
  final String reminderType;
  final String title;
  final String message;
  final DateTime remindAt;
  final String status;
  final String? appointmentId;
  final String? slotId;
  final String? doctorId;
  final String? doctorName;
  final String? doctorGender;
  final String? departmentName;
  final DateTime? appointmentStartAt;
  final DateTime? appointmentEndAt;

  bool get isPending => status == 'pending';

  bool get isDismissed => status == 'dismissed';

  bool get isAppointmentReminder => reminderType == 'appointment_reminder';

  PatientReminder copyWith({String? status}) {
    return PatientReminder(
      id: id,
      patientId: patientId,
      reminderType: reminderType,
      title: title,
      message: message,
      remindAt: remindAt,
      status: status ?? this.status,
      appointmentId: appointmentId,
      slotId: slotId,
      doctorId: doctorId,
      doctorName: doctorName,
      doctorGender: doctorGender,
      departmentName: departmentName,
      appointmentStartAt: appointmentStartAt,
      appointmentEndAt: appointmentEndAt,
    );
  }

  static DateTime? _parseDate(Object? value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.parse(value).toLocal();
  }
}

class PatientRemindersRepository {
  PatientRemindersRepository({FirebaseAuth? auth, http.Client? client})
      : _auth = auth,
        _client = client ?? http.Client();

  final FirebaseAuth? _auth;
  final http.Client _client;

  static List<PatientReminder>? _cachedReminders;

  List<PatientReminder>? get cachedReminders => _cachedReminders;

  Future<List<PatientReminder>> fetchReminders() async {
    try {
      final response = await _client
          .get(
            Uri.parse('${AppConfig.backendBaseUrl}/reminders'),
            headers: await _authHeaders(),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode == 200) {
        final reminders = (jsonDecode(response.body) as List<dynamic>)
            .map((item) => PatientReminder.fromJson(item as Map<String, dynamic>))
            .toList();
        _cachedReminders = reminders;
        return reminders;
      }
      throw PatientRemindersException(_backendMessage(response.body));
    } on SocketException {
      throw const PatientRemindersException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const PatientRemindersException('The backend took too long to respond.');
    }
  }

  Future<PatientReminder> updateStatus(String reminderId, String status) async {
    try {
      final response = await _client
          .patch(
            Uri.parse(
              '${AppConfig.backendBaseUrl}/reminders/${Uri.encodeComponent(reminderId)}/status',
            ),
            headers: await _authHeaders(),
            body: jsonEncode({'status': status}),
          )
          .timeout(const Duration(seconds: 12));
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final reminder = PatientReminder.fromJson(
          jsonDecode(response.body) as Map<String, dynamic>,
        );
        _cachedReminders = _cachedReminders
            ?.map((item) => item.id == reminder.id ? reminder : item)
            .toList();
        return reminder;
      }
      throw PatientRemindersException(_backendMessage(response.body));
    } on SocketException {
      throw const PatientRemindersException('The backend is unreachable right now.');
    } on TimeoutException {
      throw const PatientRemindersException('The backend took too long to respond.');
    }
  }

  Future<Map<String, String>> _authHeaders() async {
    final token = await _auth?.currentUser?.getIdToken();
    if (token == null) {
      throw const PatientRemindersException(
        'Please sign in again before viewing reminders.',
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
      if (detail is String && detail.isNotEmpty) return detail;
    } catch (_) {
      // Friendly fallback below.
    }
    return 'We could not load reminders right now.';
  }
}

class PatientRemindersException implements Exception {
  const PatientRemindersException(this.message);

  final String message;

  @override
  String toString() => message;
}
