import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/doctor_workspace_repository.dart';

class DoctorAppointmentDetailScreen extends ConsumerStatefulWidget {
  const DoctorAppointmentDetailScreen({
    required this.appointmentId,
    this.initialAppointment,
    super.key,
  });

  final String appointmentId;
  final DoctorWorkspaceAppointment? initialAppointment;

  @override
  ConsumerState<DoctorAppointmentDetailScreen> createState() =>
      _DoctorAppointmentDetailScreenState();
}

class _DoctorAppointmentDetailScreenState
    extends ConsumerState<DoctorAppointmentDetailScreen> {
  DoctorWorkspaceAppointment? _appointment;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _appointment = widget.initialAppointment;
    _loading = widget.initialAppointment == null;
    if (widget.initialAppointment == null) {
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await ref
          .read(doctorWorkspaceRepositoryProvider)
          .fetchAppointmentDetail(widget.appointmentId);
      if (!mounted) return;
      setState(() => _appointment = detail);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final appointment = _appointment;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: const Color(0xFFF4F8FF),
        foregroundColor: const Color(0xFF153B74),
        elevation: 0,
      ),
      body: SafeArea(
        child: _loading && appointment == null
            ? const Center(child: CircularProgressIndicator())
            : _error != null && appointment == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            size: 42,
                            color: Color(0xFFB42318),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _error ?? 'We could not load appointment details right now.',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: const Color(0xFF5D6B82),
                                  height: 1.45,
                                ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: _load,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [
                              BoxShadow(
                                color: Color(0x12000000),
                                blurRadius: 16,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  _DoctorDetailPortrait(gender: appointment?.patientGender),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _fallback(
                                            appointment?.patientName,
                                            'Patient',
                                          ),
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                color: const Color(0xFF153B74),
                                                fontWeight: FontWeight.w800,
                                              ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          appointment?.departmentName ?? 'Department',
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodyMedium
                                              ?.copyWith(
                                                color: const Color(0xFF5D6B82),
                                              ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _DoctorDetailLine(
                                label: 'Date',
                                value: _friendlyDate(appointment?.scheduledFor),
                              ),
                              const SizedBox(height: 12),
                              _DoctorDetailLine(
                                label: 'Time',
                                value: _time(appointment?.scheduledFor),
                              ),
                              const SizedBox(height: 12),
                              _DoctorDetailLine(
                                label: 'Status',
                                value: (appointment?.status ?? 'booked').toUpperCase(),
                              ),
                              const SizedBox(height: 12),
                              _DoctorDetailLine(
                                label: 'Appointment ID',
                                value: appointment?.id ?? widget.appointmentId,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
      ),
    );
  }
}

class _DoctorDetailPortrait extends StatelessWidget {
  const _DoctorDetailPortrait({required this.gender});

  final String? gender;

  @override
  Widget build(BuildContext context) {
    final normalized = gender?.trim().toLowerCase();
    final asset = switch (normalized) {
      'male' => 'assets/nav/profile_boy_tryout.png',
      'female' => 'assets/nav/profile_girl_tryout.png',
      _ => null,
    };
    if (asset == null) {
      return Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFFD7E7FF),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person_rounded,
          color: Color(0xFF2C7DF7),
          size: 28,
        ),
      );
    }
    return ClipOval(
      child: Image.asset(asset, width: 56, height: 56, fit: BoxFit.cover),
    );
  }
}

class _DoctorDetailLine extends StatelessWidget {
  const _DoctorDetailLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        children: [
          TextSpan(
            text: '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF153B74),
                  fontWeight: FontWeight.w700,
                ),
          ),
          TextSpan(
            text: value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5D6B82),
                  height: 1.45,
                ),
          ),
        ],
      ),
    );
  }
}

String _fallback(String? value, String defaultValue) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return defaultValue;
  }
  return trimmed;
}

String _friendlyDate(DateTime? value) {
  if (value == null) return 'Not available';
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(value.year, value.month, value.day);
  final difference = target.difference(today).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  return '${_monthShort(value.month)} ${value.day}, ${value.year}';
}

String _time(DateTime? value) {
  if (value == null) return 'Not available';
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
          ? value.hour - 12
          : value.hour;
  final suffix = value.hour >= 12 ? 'PM' : 'AM';
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute $suffix';
}

String _monthShort(int month) {
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return months[month - 1];
}
