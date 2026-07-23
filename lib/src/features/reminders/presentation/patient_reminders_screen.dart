import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/patient_reminders_repository.dart';

const _pageBg = Color(0xFFF4F8FF);
const _primaryBlue = Color(0xFF2C7DF7);
const _heroStart = Color(0xFF4B8FF5);
const _heroEnd = Color(0xFF73A8F7);
const _darkBlue = Color(0xFF153B74);
const _deepText = Color(0xFF1D2939);
const _mutedText = Color(0xFF5D6B82);
const _subtleText = Color(0xFF667085);
const _lightText = Color(0xFF98A2B3);
const _progressBg = Color(0xFFDCE8FF);
const _pendingBg = Color(0xFFE6EFFF);
const _pendingText = Color(0xFF4E7FE8);
const _readBg = Color(0xFFF0F2F5);
const _readText = Color(0xFF667085);
const _dismissedBg = Color(0xFFF2F4F7);
const _dismissedText = Color(0xFF475467);
const _errorBg = Color(0xFFFEE4E2);
const _errorText = Color(0xFFB42318);
const _successBg = Color(0xFFE8FBF4);
const _successText = Color(0xFF067647);

class PatientRemindersScreen extends ConsumerStatefulWidget {
  const PatientRemindersScreen({super.key});

  @override
  ConsumerState<PatientRemindersScreen> createState() =>
      _PatientRemindersScreenState();
}

class _PatientRemindersScreenState
    extends ConsumerState<PatientRemindersScreen> {
  List<PatientReminder>? _reminders;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _message;
  bool _messageIsError = false;
  String? _busyReminderId;
  String? _busyAction;
  bool _isMarkingAllRead = false;
  Timer? _expiryTimer;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(patientRemindersRepositoryProvider).cachedReminders;
    _reminders = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
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
      _loading = _reminders == null;
    });

    try {
      final reminders =
          await ref.read(patientRemindersRepositoryProvider).fetchReminders();
      if (!mounted) return;
      setState(() => _reminders = reminders);
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

  Future<void> _markRead(PatientReminder reminder) async {
    if (!reminder.isPending || _busyReminderId != null) return;
    await _updateOne(reminder, 'read', 'read', 'Reminder marked as read.');
  }

  Future<void> _dismiss(PatientReminder reminder) async {
    if (reminder.isDismissed || _busyReminderId != null) return;
    await _updateOne(reminder, 'dismissed', 'dismiss', 'Reminder dismissed.');
  }

  Future<void> _updateOne(
    PatientReminder reminder,
    String status,
    String action,
    String successMessage,
  ) async {
    final previous = List<PatientReminder>.from(_reminders ?? []);
    setState(() {
      _busyReminderId = reminder.id;
      _busyAction = action;
      _message = null;
      _reminders = previous
          .map((item) => item.id == reminder.id ? item.copyWith(status: status) : item)
          .toList();
    });

    try {
      await ref.read(patientRemindersRepositoryProvider).updateStatus(reminder.id, status);
      await _load(showRefresh: true);
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() => _reminders = previous);
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyReminderId = null;
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _markAllRead(List<PatientReminder> visible) async {
    final pending = visible.where((item) => item.isPending).toList();
    if (pending.isEmpty || _isMarkingAllRead) return;

    final previous = List<PatientReminder>.from(_reminders ?? []);
    final pendingIds = pending.map((item) => item.id).toSet();
    setState(() {
      _isMarkingAllRead = true;
      _message = null;
      _reminders = previous
          .map((item) => pendingIds.contains(item.id) ? item.copyWith(status: 'read') : item)
          .toList();
    });

    try {
      final repository = ref.read(patientRemindersRepositoryProvider);
      for (final reminder in pending) {
        await repository.updateStatus(reminder.id, 'read');
      }
      await _load(showRefresh: true);
      _showMessage('All pending reminders marked as read.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _reminders = previous);
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() => _isMarkingAllRead = false);
      }
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    _messageTimer?.cancel();
    setState(() {
      _message = message;
      _messageIsError = isError;
    });
    _messageTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _message = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reminders = _reminders;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('Reminders')),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (_loading && reminders == null) {
              return const _SkeletonList();
            }
            if (_error != null && reminders == null) {
              return _FullErrorState(message: _error!, onRetry: () => _load());
            }

            final visible = _visibleReminders(reminders ?? []);
            final heroReminder = visible
                .where((item) => !item.isDismissed)
                .cast<PatientReminder?>()
                .firstOrNull;

            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _primaryBlue,
                      backgroundColor: _progressBg,
                    ),
                    const SizedBox(height: 14),
                  ],
                  Text(
                    'Reminders',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: _darkBlue,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Track upcoming appointment reminders and clear the ones you have already handled.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: _mutedText,
                          height: 1.4,
                        ),
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 14),
                    _StatusBanner(
                      message: _message!,
                      isSuccess: !_messageIsError,
                    ),
                  ],
                  if (heroReminder != null) ...[
                    SizedBox(height: _message == null ? 22 : 18),
                    _NextReminderHero(reminder: heroReminder),
                  ],
                  const SizedBox(height: 22),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'REMINDERS',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: _deepText,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.8,
                              ),
                        ),
                      ),
                      TextButton(
                        onPressed: _isMarkingAllRead
                            ? null
                            : () => _markAllRead(visible),
                        child: Text(
                          _isMarkingAllRead ? 'Updating...' : 'Mark all as read',
                          style: const TextStyle(
                            color: _primaryBlue,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  if (visible.isEmpty)
                    const _EmptyState()
                  else
                    for (final reminder in visible) ...[
                      _ReminderCard(
                        reminder: reminder,
                        busyAction: _busyReminderId == reminder.id ? _busyAction : null,
                        onMarkRead: () => _markRead(reminder),
                        onDismiss: () => _dismiss(reminder),
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

  List<PatientReminder> _visibleReminders(List<PatientReminder> reminders) {
    final visible = reminders
        .where((item) => item.status != 'cancelled' && !_isExpired(item))
        .toList();
    visible.sort((a, b) {
      final statusRank = _statusRank(a.status).compareTo(_statusRank(b.status));
      if (statusRank != 0) return statusRank;
      return a.remindAt.compareTo(b.remindAt);
    });
    return visible;
  }

  bool _isExpired(PatientReminder reminder) {
    final target = reminder.appointmentStartAt ?? reminder.remindAt;
    return !target.isAfter(DateTime.now());
  }

  int _statusRank(String status) {
    return switch (status) {
      'pending' => 0,
      'read' => 1,
      'dismissed' => 2,
      _ => 3,
    };
  }
}

class _NextReminderHero extends StatelessWidget {
  const _NextReminderHero({required this.reminder});

  final PatientReminder reminder;

  @override
  Widget build(BuildContext context) {
    final department = _valueOrFallback(reminder.departmentName, '');
    final title = department.isEmpty
        ? _displayTitle(reminder)
        : '$department Consultation';
    final summary = '${_friendlyDate(reminder.appointmentStartAt ?? reminder.remindAt)}   '
        '${_time12(reminder.appointmentStartAt ?? reminder.remindAt)}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_heroStart, _heroEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              top: -8,
              right: -16,
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEXT APPOINTMENT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.75),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _DoctorReminderAvatar(
                      gender: reminder.doctorGender,
                      width: 36,
                      height: 36,
                      backgroundColor: Colors.white24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$summary   ${_valueOrFallback(reminder.doctorName, 'Doctor')}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ReminderCard extends StatelessWidget {
  const _ReminderCard({
    required this.reminder,
    required this.busyAction,
    required this.onMarkRead,
    required this.onDismiss,
  });

  final PatientReminder reminder;
  final String? busyAction;
  final VoidCallback onMarkRead;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isBusy = busyAction != null;
    final markReadBusy = busyAction == 'read';
    final dismissBusy = busyAction == 'dismiss';

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
          _StatusPill(status: reminder.status),
          const SizedBox(height: 18),
          Text(
            _displayTitle(reminder),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _deepText,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            _displayMessage(reminder),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  height: 1.5,
                ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 16),
          Row(
            children: [
              _DoctorReminderAvatar(
                gender: reminder.doctorGender,
                width: 44,
                height: 44,
                backgroundColor: Color(0xFFE8F0FF),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _valueOrFallback(reminder.doctorName, 'Doctor'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _deepText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _valueOrFallback(reminder.departmentName, 'Department'),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: _lightText,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          const SizedBox(height: 14),
          Row(
            children: [
              const Icon(Icons.schedule_rounded, size: 18, color: _primaryBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Posted ${_friendlyPosted(reminder.remindAt)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF475467),
                        fontWeight: FontWeight.w500,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: reminder.isPending && !isBusy ? onMarkRead : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: _heroStart,
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    disabledBackgroundColor: _heroStart.withValues(alpha: 0.45),
                    disabledForegroundColor: Colors.white,
                  ),
                  child: Text(markReadBusy ? 'Updating...' : 'Mark Read'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: !reminder.isDismissed && !isBusy ? onDismiss : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    foregroundColor: _subtleText,
                    side: const BorderSide(color: Color(0xFFD0D5DD)),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(dismissBusy ? 'Updating...' : 'Dismiss'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      'pending' => (_pendingBg, _pendingText),
      'read' => (_readBg, _readText),
      'dismissed' => (_dismissedBg, _dismissedText),
      _ => (_readBg, _readText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.$2,
              fontWeight: FontWeight.w700,
              fontSize: 11,
            ),
      ),
    );
  }
}

class GenderPortrait extends StatelessWidget {
  const GenderPortrait({
    super.key,
    required this.gender,
    required this.width,
    required this.height,
    required this.fallbackBackground,
    required this.fallbackColor,
    required this.fallbackIconSize,
  });

  final String? gender;
  final double width;
  final double height;
  final Color fallbackBackground;
  final Color fallbackColor;
  final double fallbackIconSize;

  @override
  Widget build(BuildContext context) {
    final normalized = gender?.trim().toLowerCase();
    final asset = switch (normalized) {
      'male' => 'assets/profile/boy_3d.png',
      'female' => 'assets/profile/girl_3d.png',
      _ => null,
    };

    if (asset == null) {
      return Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: fallbackBackground,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.person_rounded,
          color: fallbackColor,
          size: fallbackIconSize,
        ),
      );
    }

    return ClipOval(
      child: Image.asset(
        asset,
        width: width,
        height: height,
        fit: BoxFit.cover,
      ),
    );
  }
}

class _DoctorReminderAvatar extends StatelessWidget {
  const _DoctorReminderAvatar({
    required this.gender,
    required this.width,
    required this.height,
    required this.backgroundColor,
  });

  final String? gender;
  final double width;
  final double height;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final shortestSide = width < height ? width : height;
    final normalized = gender?.trim().toLowerCase();
    final assetPath = normalized == 'female'
        ? 'assets/admin/female_doctor_icon.png'
        : 'assets/admin/doctor_icon.png';
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
      ),
      padding: EdgeInsets.all(shortestSide * 0.18),
      child: Image.asset(
        assetPath,
        fit: BoxFit.contain,
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? _successBg : _errorBg,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isSuccess ? _successText : _errorText,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.notifications_none_rounded,
            size: 42,
            color: _primaryBlue,
          ),
          const SizedBox(height: 12),
          Text(
            'No reminders yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Appointment reminders will appear here once you book a consultation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                ),
          ),
        ],
      ),
    );
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        const _SkeletonLine(width: 150, height: 32),
        const SizedBox(height: 10),
        const _SkeletonLine(width: double.infinity, height: 18),
        const SizedBox(height: 22),
        for (var index = 0; index < 3; index++) ...[
          Container(
            height: 176,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              borderRadius: BorderRadius.circular(28),
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  const _SkeletonLine({required this.width, required this.height});

  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE4EBF5),
          borderRadius: BorderRadius.circular(999),
        ),
      ),
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

String _displayTitle(PatientReminder reminder) {
  if (reminder.isAppointmentReminder) return 'Upcoming appointment reminder';
  return _valueOrFallback(reminder.title, 'Reminder');
}

String _displayMessage(PatientReminder reminder) {
  if (!reminder.isAppointmentReminder) {
    return _valueOrFallback(reminder.message, 'Reminder details will appear here.');
  }
  final doctor = _valueOrFallback(reminder.doctorName, 'your doctor');
  final when = reminder.appointmentStartAt ?? reminder.remindAt;
  return 'You have an appointment with $doctor ${_friendlyDate(when)} at ${_time12(when)}.';
}

String _friendlyPosted(DateTime value) {
  return '${_friendlyDate(value)} - ${_time12(value)}';
}

String _friendlyDate(DateTime value) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(value.year, value.month, value.day);
  final difference = date.difference(today).inDays;
  if (difference == 0) return 'Today';
  if (difference == 1) return 'Tomorrow';
  return '${_month(value.month)} ${value.day}';
}

String _time12(DateTime value) {
  final hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';
  return '$hour:$minute $period';
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

String _valueOrFallback(String? value, String fallback) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? fallback : trimmed;
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
