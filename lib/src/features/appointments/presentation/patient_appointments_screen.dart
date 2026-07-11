import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../data/patient_appointments_repository.dart';

const _pageBg = Color(0xFFF4F8FF);
const _primaryBlue = Color(0xFF2C7DF7);
const _darkBlue = Color(0xFF153B74);
const _mainText = Color(0xFF183153);
const _mutedText = Color(0xFF5D6B82);
const _segmentBg = Color(0xFFDCE8FF);
const _border = Color(0xFFE4EBF5);
const _successBg = Color(0xFFE8FBF4);
const _successText = Color(0xFF067647);
const _errorBg = Color(0xFFFEE4E2);
const _errorText = Color(0xFFB42318);
const _historyBg = Color(0xFFEFF4FF);
const _historyText = Color(0xFF175CD3);

class PatientAppointmentsScreen extends ConsumerStatefulWidget {
  const PatientAppointmentsScreen({
    super.key,
    this.onAppointmentsChanged,
    this.refreshToken = 0,
  });

  final VoidCallback? onAppointmentsChanged;
  final int refreshToken;

  @override
  ConsumerState<PatientAppointmentsScreen> createState() =>
      _PatientAppointmentsScreenState();
}

class _PatientAppointmentsScreenState
    extends ConsumerState<PatientAppointmentsScreen> {
  List<PatientAppointment>? _appointments;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _message;
  bool _messageIsError = false;
  bool _showHistory = false;
  String? _cancellingId;
  Timer? _expiryTimer;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(patientAppointmentsRepositoryProvider).cachedAppointments;
    _appointments = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant PatientAppointmentsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshToken != widget.refreshToken) {
      _load(showRefresh: _appointments != null);
    }
  }

  @override
  void dispose() {
    _expiryTimer?.cancel();
    _messageTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _error = null;
      _refreshing = showRefresh;
      _loading = _appointments == null;
    });

    try {
      final appointments =
          await ref.read(patientAppointmentsRepositoryProvider).fetchAppointments();
      if (!mounted) return;
      setState(() => _appointments = appointments);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _cancelAppointment(PatientAppointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => const _CancelAppointmentDialog(),
    );
    if (confirmed != true || !mounted) return;

    final previous = List<PatientAppointment>.from(_appointments ?? []);
    setState(() {
      _cancellingId = appointment.id;
      _appointments = previous
          .map((item) => item.id == appointment.id ? item.markCancelled() : item)
          .toList();
      _showMessage('Appointment cancelled successfully.');
    });

    try {
      await ref
          .read(patientAppointmentsRepositoryProvider)
          .cancelAppointment(appointment.id);
      await _load(showRefresh: true);
      widget.onAppointmentsChanged?.call();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _appointments = previous;
        _showMessage(error.toString(), isError: true);
      });
    } finally {
      if (mounted) {
        setState(() => _cancellingId = null);
      }
    }
  }

  Future<void> _reschedule(PatientAppointment appointment) async {
    final result = await context.push(
      '/reschedule-appointment',
      extra: appointment.toBookingAppointment(),
    );
    if (!mounted) return;
    await _load(showRefresh: true);
    widget.onAppointmentsChanged?.call();
    if (result != null) {
      setState(() => _showMessage('Appointment rescheduled successfully.'));
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageTimer?.cancel();
    _message = message;
    _messageIsError = isError;
    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _message = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final appointments = _appointments;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('Appointments')),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (_loading && appointments == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_error != null && appointments == null) {
              return _FullErrorState(message: _error!, onRetry: () => _load());
            }

            final visible = _visibleAppointments(appointments ?? []);

            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _primaryBlue,
                      backgroundColor: _segmentBg,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Appointments',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                color: _darkBlue,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ),
                      FilledButton.icon(
                        onPressed: () async {
                          final result = await context.push('/book-appointment');
                          if (!mounted) return;
                          if (result != null) {
                            await _load(showRefresh: true);
                            widget.onAppointmentsChanged?.call();
                          }
                        },
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Book'),
                        style: FilledButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Review your upcoming appointments or look back at past and cancelled visits.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _mutedText,
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 16),
                  _AppointmentSegmentedSwitch(
                    showHistory: _showHistory,
                    onChanged: (value) => setState(() => _showHistory = value),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    _MessageBanner(message: _message!, isError: _messageIsError),
                  ],
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    _EmptyAppointmentsState(
                      history: _showHistory,
                      onBook: () async {
                        final result = await context.push('/book-appointment');
                        if (!mounted) return;
                        if (result != null) {
                          await _load(showRefresh: true);
                          widget.onAppointmentsChanged?.call();
                        }
                      },
                    )
                  else
                    for (final appointment in visible) ...[
                      _AppointmentCard(
                        appointment: appointment,
                        historyView: _showHistory,
                        cancelling: _cancellingId == appointment.id,
                        onCancel: () => _cancelAppointment(appointment),
                        onReschedule: () => _reschedule(appointment),
                      ),
                      const SizedBox(height: 14),
                    ],
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  List<PatientAppointment> _visibleAppointments(
    List<PatientAppointment> appointments,
  ) {
    final visible = appointments.where((appointment) {
      return _showHistory ? !appointment.isUpcoming : appointment.isUpcoming;
    }).toList();
    visible.sort((a, b) {
      final comparison = a.startAt.compareTo(b.startAt);
      return _showHistory ? -comparison : comparison;
    });
    return visible;
  }
}

class _AppointmentSegmentedSwitch extends StatelessWidget {
  const _AppointmentSegmentedSwitch({
    required this.showHistory,
    required this.onChanged,
  });

  final bool showHistory;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: const ShapeDecoration(
        color: _segmentBg,
        shape: StadiumBorder(),
      ),
      child: Row(
        children: [
          _SegmentButton(
            label: 'Upcoming',
            selected: !showHistory,
            onTap: () => onChanged(false),
          ),
          _SegmentButton(
            label: 'History',
            selected: showHistory,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: ShapeDecoration(
            color: selected ? Colors.white : Colors.transparent,
            shape: const StadiumBorder(),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: selected ? _darkBlue : _mutedText,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.historyView,
    required this.cancelling,
    required this.onCancel,
    required this.onReschedule,
  });

  final PatientAppointment appointment;
  final bool historyView;
  final bool cancelling;
  final VoidCallback onCancel;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final active = appointment.isUpcoming && !historyView;

    return Container(
      padding: const EdgeInsets.all(18),
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  appointment.doctorName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _darkBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              _StatusBadge(appointment: appointment, historyView: historyView),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            appointment.departmentName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                ),
          ),
          const SizedBox(height: 14),
          _MetaRow(
            icon: Icons.calendar_month_rounded,
            text: _friendlyDate(appointment.startAt),
          ),
          const SizedBox(height: 10),
          _MetaRow(
            icon: Icons.access_time_rounded,
            text: '${_time(appointment.startAt)} - ${_time(appointment.endAt)}',
          ),
          if (active) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: cancelling ? null : onReschedule,
                    style: _neutralButtonStyle(),
                    child: const Text('Reschedule'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: cancelling ? null : onCancel,
                    style: _dangerButtonStyle(),
                    child: Text(cancelling ? 'Cancelling...' : 'Cancel'),
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              _historyMessage(appointment),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _mutedText,
                    height: 1.4,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  ButtonStyle _neutralButtonStyle() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      backgroundColor: Colors.white,
      foregroundColor: _darkBlue,
      side: const BorderSide(color: Color(0xFFD6E0EE)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }

  ButtonStyle _dangerButtonStyle() {
    return OutlinedButton.styleFrom(
      minimumSize: const Size.fromHeight(48),
      backgroundColor: const Color(0xFFFFF0F0),
      foregroundColor: _errorText,
      side: const BorderSide(color: Color(0xFFFDB0AC)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.appointment, required this.historyView});

  final PatientAppointment appointment;
  final bool historyView;

  @override
  Widget build(BuildContext context) {
    final label = appointment.isCancelled
        ? 'CANCELLED'
        : historyView
            ? 'PAST'
            : 'BOOKED';
    final bg = appointment.isCancelled
        ? _errorBg
        : historyView
            ? _historyBg
            : _successBg;
    final fg = appointment.isCancelled
        ? _errorText
        : historyView
            ? _historyText
            : _successText;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: _primaryBlue),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mainText,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ),
      ],
    );
  }
}

class _EmptyAppointmentsState extends StatelessWidget {
  const _EmptyAppointmentsState({required this.history, required this.onBook});

  final bool history;
  final VoidCallback onBook;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
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
        children: [
          const Icon(Icons.calendar_month_rounded, size: 42, color: _primaryBlue),
          const SizedBox(height: 12),
          Text(
            history ? 'No appointment history yet' : 'No upcoming appointments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            history
                ? 'Past visits and cancelled appointments will appear here once you have appointment activity.'
                : 'Your confirmed consultations will appear here once you book a time slot.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  height: 1.45,
                ),
          ),
          if (!history) ...[
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onBook,
              style: OutlinedButton.styleFrom(
                foregroundColor: _darkBlue,
                side: const BorderSide(color: _border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Book your first appointment'),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageBanner extends StatelessWidget {
  const _MessageBanner({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? _errorBg : _successBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isError ? _errorText : _successText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _CancelAppointmentDialog extends StatelessWidget {
  const _CancelAppointmentDialog();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cancel Appointment?'),
      content: const Text('Are you sure you want to cancel this appointment?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep Appointment'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: _errorText,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class _FullErrorState extends StatelessWidget {
  const _FullErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: _errorText),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: _mutedText,
                    height: 1.45,
                  ),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _historyMessage(PatientAppointment appointment) {
  if (appointment.isCancelled) {
    return 'This appointment was cancelled. The time slot has been released for future booking.';
  }
  if (appointment.isPast) {
    return 'This appointment time has already passed and is now kept in your history.';
  }
  return 'This appointment is not currently available for changes.';
}

String _friendlyDate(DateTime value) {
  final today = DateTime.now();
  final current = DateTime(today.year, today.month, today.day);
  final target = DateTime(value.year, value.month, value.day);
  final dayPart = '${_month(value.month)} ${value.day}';
  if (target == current) {
    return 'Today, $dayPart';
  }
  if (target == current.add(const Duration(days: 1))) {
    return 'Tomorrow, $dayPart';
  }
  return '$dayPart, ${value.year}';
}

String _time(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}

String _month(int month) {
  const months = [
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
