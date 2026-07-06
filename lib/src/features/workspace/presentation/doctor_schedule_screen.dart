import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../availability_slots/domain/availability_slot.dart';
import '../data/doctor_workspace_repository.dart';

class DoctorScheduleScreen extends ConsumerStatefulWidget {
  const DoctorScheduleScreen({
    required this.doctorId,
    required this.refreshSeed,
    super.key,
  });

  final String doctorId;
  final int refreshSeed;

  @override
  ConsumerState<DoctorScheduleScreen> createState() =>
      _DoctorScheduleScreenState();
}

class _DoctorScheduleScreenState extends ConsumerState<DoctorScheduleScreen> {
  late DateTime _selectedDate;
  DoctorDayScheduleData? _schedule;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _inlineError;
  bool _openingAppointment = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = _dateOnly(DateTime.now());
    final cached = ref
        .read(doctorWorkspaceRepositoryProvider)
        .cachedDaySchedule(widget.doctorId, _selectedDate);
    _schedule = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
  }

  @override
  void didUpdateWidget(covariant DoctorScheduleScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.doctorId != widget.doctorId) {
      _selectedDate = _dateOnly(DateTime.now());
      final cached = ref
          .read(doctorWorkspaceRepositoryProvider)
          .cachedDaySchedule(widget.doctorId, _selectedDate);
      setState(() {
        _schedule = cached;
        _loading = cached == null;
        _error = null;
        _inlineError = null;
      });
      _load(showRefresh: cached != null);
      return;
    }
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _load(showRefresh: _schedule != null);
    }
  }

  Future<void> _load({
    bool showRefresh = false,
    DateTime? targetDate,
    bool preserveVisibleData = false,
  }) async {
    if (_refreshing) return;
    final requestDate = _dateOnly(targetDate ?? _selectedDate);
    setState(() {
      _error = null;
      _inlineError = null;
      _refreshing = showRefresh || preserveVisibleData;
      _loading = !preserveVisibleData && _schedule == null;
    });
    try {
      final data = await ref
          .read(doctorWorkspaceRepositoryProvider)
          .fetchDaySchedule(widget.doctorId, requestDate);
      if (!mounted) return;
      if (!_sameDate(_selectedDate, requestDate)) return;
      setState(() {
        _schedule = data;
        _error = null;
        _inlineError = null;
      });
    } catch (error) {
      if (!mounted) return;
      if (!_sameDate(_selectedDate, requestDate)) return;
      final message = error.toString();
      if (_schedule == null && !preserveVisibleData) {
        setState(() => _error = message);
      } else {
        setState(() => _inlineError = message);
      }
    } finally {
      if (mounted && _sameDate(_selectedDate, requestDate)) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _pickDate() async {
    final today = _dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: today.subtract(const Duration(days: 30)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    final nextDate = _dateOnly(picked);
    if (_sameDate(nextDate, _selectedDate)) return;
    final cached = ref
        .read(doctorWorkspaceRepositoryProvider)
        .cachedDaySchedule(widget.doctorId, nextDate);
    setState(() {
      _selectedDate = nextDate;
      if (cached != null) {
        _schedule = cached;
      }
      _loading = _schedule == null;
      _error = null;
      _inlineError = null;
    });
    await _load(
      showRefresh: true,
      targetDate: nextDate,
      preserveVisibleData: true,
    );
  }

  Future<void> _openBookedSlot(
    AvailabilitySlot slot,
    DoctorWorkspaceAppointment? appointment,
  ) async {
    if (_openingAppointment) return;
    if (appointment == null || appointment.id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment details are not available for this slot yet.'),
        ),
      );
      return;
    }

    setState(() => _openingAppointment = true);
    try {
      final detail = await ref
          .read(doctorWorkspaceRepositoryProvider)
          .fetchAppointmentDetail(appointment.id);
      if (!mounted) return;
      await context.push(
        '/doctor/appointments/${Uri.encodeComponent(detail.id)}',
        extra: detail,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    } finally {
      if (mounted) {
        setState(() => _openingAppointment = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _schedule;
    if (_loading && schedule == null) {
      return const ColoredBox(
        color: Color(0xFFF4F8FF),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null && schedule == null) {
      return ColoredBox(
        color: const Color(0xFFF4F8FF),
        child: SafeArea(
          child: Center(
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
                    _error ?? 'We could not load your schedule right now.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: const Color(0xFF5D6B82),
                          height: 1.45,
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _load(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final slots = schedule?.slots ?? const <AvailabilitySlot>[];
    final appointments = schedule?.appointments ?? const <DoctorWorkspaceAppointment>[];
    final bookedSlots = <AvailabilitySlot>[];
    final availableSlots = <AvailabilitySlot>[];
    final blockedSlots = <AvailabilitySlot>[];

    for (final slot in slots) {
      switch (slot.status.trim().toLowerCase()) {
        case 'booked':
          bookedSlots.add(slot);
          break;
        case 'blocked':
          blockedSlots.add(slot);
          break;
        default:
          availableSlots.add(slot);
          break;
      }
    }

    return Container(
      color: const Color(0xFFF4F8FF),
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(showRefresh: true),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'My Schedule',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF153B74),
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Review your available, booked, and blocked slots for the selected day.',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: const Color(0xFF5D6B82),
                                height: 1.45,
                              ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_month_rounded, size: 18),
                    label: Text(_shortDateLabel(_selectedDate)),
                  ),
                ],
              ),
              if (_refreshing && schedule != null) ...[
                const SizedBox(height: 14),
                const LinearProgressIndicator(
                  minHeight: 3,
                  color: Color(0xFF2C7DF7),
                  backgroundColor: Color(0xFFDCE8FF),
                ),
              ],
              if (_inlineError != null) ...[
                const SizedBox(height: 14),
                _DoctorScheduleBanner(
                  message: _inlineError!,
                  isError: true,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: _DoctorScheduleMetricCard(
                      label: 'Booked',
                      value: bookedSlots.length,
                      background: const Color(0xFFEAF2FF),
                      accent: const Color(0xFF2C7DF7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DoctorScheduleMetricCard(
                      label: 'Available',
                      value: availableSlots.length,
                      background: const Color(0xFFE8FBF4),
                      accent: const Color(0xFF067647),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _DoctorScheduleMetricCard(
                      label: 'Blocked',
                      value: blockedSlots.length,
                      background: const Color(0xFFFFF4E5),
                      accent: const Color(0xFFB54708),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (slots.isEmpty)
                const _DoctorScheduleEmptyCard()
              else ...[
                if (bookedSlots.isNotEmpty)
                  _DoctorSlotSectionCard(
                    title: 'Booked',
                    slots: bookedSlots,
                    appointments: appointments,
                    onTapSlot: _openBookedSlot,
                  ),
                if (availableSlots.isNotEmpty)
                  _DoctorSlotSectionCard(
                    title: 'Available',
                    slots: availableSlots,
                    appointments: appointments,
                    onTapSlot: _openBookedSlot,
                  ),
                if (blockedSlots.isNotEmpty)
                  _DoctorSlotSectionCard(
                    title: 'Blocked',
                    slots: blockedSlots,
                    appointments: appointments,
                    onTapSlot: _openBookedSlot,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DoctorScheduleMetricCard extends StatelessWidget {
  const _DoctorScheduleMetricCard({
    required this.label,
    required this.value,
    required this.background,
    required this.accent,
  });

  final String label;
  final int value;
  final Color background;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: accent,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5D6B82),
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _DoctorScheduleEmptyCard extends StatelessWidget {
  const _DoctorScheduleEmptyCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.schedule_rounded,
            size: 42,
            color: Color(0xFF2C7DF7),
          ),
          const SizedBox(height: 12),
          Text(
            'No slots for this date',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF153B74),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'When admin assigns availability to your profile, your working schedule will appear here.',
            textAlign: TextAlign.center,
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

class _DoctorSlotSectionCard extends StatelessWidget {
  const _DoctorSlotSectionCard({
    required this.title,
    required this.slots,
    required this.appointments,
    required this.onTapSlot,
  });

  final String title;
  final List<AvailabilitySlot> slots;
  final List<DoctorWorkspaceAppointment> appointments;
  final Future<void> Function(
    AvailabilitySlot slot,
    DoctorWorkspaceAppointment? appointment,
  ) onTapSlot;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: const Color(0xFF153B74),
                ),
          ),
          const SizedBox(height: 12),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: slots.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final slot = slots[index];
              final appointment = _matchAppointment(slot, appointments);
              final isBooked = slot.status.trim().toLowerCase() == 'booked';
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isBooked ? () => onTapSlot(slot, appointment) : null,
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_time(slot.startAt)} - ${_time(slot.endAt)}',
                                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFF183153),
                                    ),
                              ),
                              if (isBooked &&
                                  appointment?.patientName != null &&
                                  appointment!.patientName!.trim().isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  appointment.patientName!,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFF5D6B82),
                                        fontWeight: FontWeight.w600,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            if (isBooked) ...[
                              const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                                color: Color(0xFF5D6B82),
                              ),
                              const SizedBox(height: 8),
                            ],
                            _DoctorSlotStatusChip(status: slot.status),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  DoctorWorkspaceAppointment? _matchAppointment(
    AvailabilitySlot slot,
    List<DoctorWorkspaceAppointment> appointments,
  ) {
    for (final appointment in appointments) {
      if (appointment.slotId != null &&
          appointment.slotId!.isNotEmpty &&
          appointment.slotId == slot.id) {
        return appointment;
      }
    }
    for (final appointment in appointments) {
      if (_sameMinute(appointment.scheduledFor, slot.startAt)) {
        return appointment;
      }
    }
    return null;
  }
}

class _DoctorSlotStatusChip extends StatelessWidget {
  const _DoctorSlotStatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final normalized = status.trim().toLowerCase();
    final (background, foreground) = switch (normalized) {
      'booked' => (const Color(0xFFEAF2FF), const Color(0xFF2C7DF7)),
      'blocked' => (const Color(0xFFFFF4E5), const Color(0xFFB54708)),
      _ => (const Color(0xFFE8FBF4), const Color(0xFF067647)),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        normalized.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: foreground,
            ),
      ),
    );
  }
}

class _DoctorScheduleBanner extends StatelessWidget {
  const _DoctorScheduleBanner({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFEE4E2) : const Color(0xFFE8FBF4),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isError ? const Color(0xFFB42318) : const Color(0xFF067647),
            ),
      ),
    );
  }
}

String _shortDateLabel(DateTime value) {
  return '${_monthShort(value.month)} ${value.day}';
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

String _time(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

DateTime _dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

bool _sameDate(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;
}

bool _sameMinute(DateTime left, DateTime right) {
  return left.year == right.year &&
      left.month == right.month &&
      left.day == right.day &&
      left.hour == right.hour &&
      left.minute == right.minute;
}
