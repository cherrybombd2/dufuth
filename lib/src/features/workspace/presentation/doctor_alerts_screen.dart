import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/doctor_workspace_repository.dart';

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
const _bookedBg = Color(0xFFE8FBF4);
const _bookedText = Color(0xFF067647);
const _cancelledBg = Color(0xFFFEE4E2);
const _cancelledText = Color(0xFFB42318);
const _rescheduledBg = Color(0xFFFFF4E5);
const _rescheduledText = Color(0xFFB54708);
const _errorBg = Color(0xFFFEE4E2);
const _errorText = Color(0xFFB42318);
const _successBg = Color(0xFFE8FBF4);
const _successText = Color(0xFF067647);

class DoctorAlertsScreen extends ConsumerStatefulWidget {
  const DoctorAlertsScreen({
    super.key,
    required this.refreshSeed,
  });

  final int refreshSeed;

  @override
  ConsumerState<DoctorAlertsScreen> createState() => _DoctorAlertsScreenState();
}

class _DoctorAlertsScreenState extends ConsumerState<DoctorAlertsScreen> {
  List<DoctorWorkspaceAlert>? _alerts;
  bool _loading = true;
  bool _refreshing = false;
  String? _error;
  String? _message;
  bool _messageIsError = false;
  String? _busyAlertId;
  String? _busyAction;
  bool _isMarkingAllRead = false;
  Timer? _expiryTimer;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(doctorWorkspaceRepositoryProvider).cachedAlerts;
    _alerts = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
    _expiryTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant DoctorAlertsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.refreshSeed != widget.refreshSeed) {
      _load(showRefresh: _alerts != null);
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
      _loading = _alerts == null;
    });

    try {
      final alerts =
          await ref.read(doctorWorkspaceRepositoryProvider).fetchAlerts();
      if (!mounted) return;
      setState(() => _alerts = alerts);
    } catch (error) {
      if (!mounted) return;
      if (_alerts == null) {
        setState(() => _error = error.toString());
      } else {
        _showMessage(error.toString(), isError: true);
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  Future<void> _markRead(DoctorWorkspaceAlert alert) async {
    if (!alert.isPending || _busyAlertId != null) return;
    await _updateOne(alert, 'read', 'read', 'Alert marked as read.');
  }

  Future<void> _dismiss(DoctorWorkspaceAlert alert) async {
    if (alert.isDismissed || _busyAlertId != null) return;
    await _updateOne(alert, 'dismissed', 'dismiss', 'Alert dismissed.');
  }

  Future<void> _updateOne(
    DoctorWorkspaceAlert alert,
    String status,
    String action,
    String successMessage,
  ) async {
    final previous = List<DoctorWorkspaceAlert>.from(_alerts ?? const []);
    setState(() {
      _busyAlertId = alert.id;
      _busyAction = action;
      _message = null;
      _alerts = previous
          .map((item) => item.id == alert.id ? item.copyWith(status: status) : item)
          .toList();
    });

    try {
      await ref.read(doctorWorkspaceRepositoryProvider).updateAlertStatus(
            alert.id,
            status,
          );
      await _load(showRefresh: true);
      _showMessage(successMessage);
    } catch (error) {
      if (!mounted) return;
      setState(() => _alerts = previous);
      _showMessage(error.toString(), isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _busyAlertId = null;
          _busyAction = null;
        });
      }
    }
  }

  Future<void> _markAllRead(List<DoctorWorkspaceAlert> visible) async {
    final pending = visible.where((item) => item.isPending).toList();
    if (pending.isEmpty || _isMarkingAllRead) return;

    final previous = List<DoctorWorkspaceAlert>.from(_alerts ?? const []);
    final pendingIds = pending.map((item) => item.id).toSet();
    setState(() {
      _isMarkingAllRead = true;
      _message = null;
      _alerts = previous
          .map((item) => pendingIds.contains(item.id) ? item.copyWith(status: 'read') : item)
          .toList();
    });

    try {
      final repository = ref.read(doctorWorkspaceRepositoryProvider);
      for (final alert in pending) {
        await repository.updateAlertStatus(alert.id, 'read');
      }
      await _load(showRefresh: true);
      _showMessage('All pending alerts marked as read.');
    } catch (error) {
      if (!mounted) return;
      setState(() => _alerts = previous);
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
      if (mounted) {
        setState(() => _message = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final alerts = _alerts;

    if (_loading && alerts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && alerts == null) {
      return _DoctorAlertsErrorState(
        message: _error!,
        onRetry: () => _load(),
      );
    }

    final visible = _visibleAlerts(alerts ?? const []);
    final heroAlert = visible.isEmpty ? null : visible.first;

    return Container(
      color: _pageBg,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () => _load(showRefresh: true),
          child: ListView(
            key: const PageStorageKey('doctor-alerts-screen'),
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
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
                'Doctor Alerts',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _darkBlue,
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Stay on top of new bookings, cancellations, and reschedules tied to your clinic schedule.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _mutedText,
                      height: 1.4,
                    ),
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                _DoctorAlertBanner(
                  message: _message!,
                  isSuccess: !_messageIsError,
                ),
              ],
              if (heroAlert != null) ...[
                SizedBox(height: _message == null ? 18 : 14),
                _LatestDoctorAlertHero(alert: heroAlert),
                const SizedBox(height: 22),
              ] else
                const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'ALERTS',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: _deepText,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                    ),
                  ),
                  TextButton(
                    onPressed:
                        _isMarkingAllRead ? null : () => _markAllRead(visible),
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
                const _DoctorAlertsEmptyState()
              else
                for (final alert in visible) ...[
                  _DoctorAlertCard(
                    alert: alert,
                    busyAction: _busyAlertId == alert.id ? _busyAction : null,
                    onMarkRead: () => _markRead(alert),
                    onDismiss: () => _dismiss(alert),
                  ),
                  const SizedBox(height: 14),
                ],
            ],
          ),
        ),
      ),
    );
  }

  List<DoctorWorkspaceAlert> _visibleAlerts(List<DoctorWorkspaceAlert> alerts) {
    final visible = alerts
        .where((item) => !item.isDismissed)
        .where((item) => !_isExpired(item))
        .toList();
    visible.sort((left, right) {
      final rankCompare =
          _statusRank(left.status).compareTo(_statusRank(right.status));
      if (rankCompare != 0) return rankCompare;
      return right.remindAt.compareTo(left.remindAt);
    });
    return visible;
  }

  bool _isExpired(DoctorWorkspaceAlert alert) {
    final target = alert.appointmentStartAt ?? alert.remindAt;
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

class _LatestDoctorAlertHero extends StatelessWidget {
  const _LatestDoctorAlertHero({required this.alert});

  final DoctorWorkspaceAlert alert;

  @override
  Widget build(BuildContext context) {
    final summaryDate = alert.appointmentStartAt ?? alert.remindAt;
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
                  'LATEST ALERT',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Colors.white.withValues(alpha: 0.70),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  _valueOrFallback(alert.title, 'Doctor alert'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _AlertGenderPortrait(
                      gender: alert.patientGender,
                      width: 36,
                      height: 36,
                      fallbackBackground: Colors.white24,
                      fallbackColor: Colors.white,
                      fallbackIconSize: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${_valueOrFallback(alert.patientName, 'Patient')}   ${_friendlyDate(summaryDate)}   ${_time12(summaryDate)}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      _typeConfig(alert.alertType).icon,
                      color: Colors.white,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _typeConfig(alert.alertType).label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
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

class _DoctorAlertCard extends StatelessWidget {
  const _DoctorAlertCard({
    required this.alert,
    required this.busyAction,
    required this.onMarkRead,
    required this.onDismiss,
  });

  final DoctorWorkspaceAlert alert;
  final String? busyAction;
  final VoidCallback onMarkRead;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final isBusy = busyAction != null;
    final markReadBusy = busyAction == 'read';
    final dismissBusy = busyAction == 'dismiss';
    final type = _typeConfig(alert.alertType);
    final appointmentDate = alert.appointmentStartAt ?? alert.remindAt;

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
            children: [
              _DoctorAlertStatusPill(status: alert.status),
              const Spacer(),
              _DoctorAlertTypePill(config: type),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _valueOrFallback(alert.title, 'Doctor alert'),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          Text(
            _valueOrFallback(alert.message, 'Alert details will appear here.'),
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
              _AlertGenderPortrait(
                gender: alert.patientGender,
                width: 44,
                height: 44,
                fallbackBackground: const Color(0xFFE8F0FF),
                fallbackColor: _primaryBlue,
                fallbackIconSize: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _valueOrFallback(alert.patientName, 'Patient'),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: _deepText,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_valueOrFallback(alert.departmentName, 'Department')}   ${_fullDate(appointmentDate)}   ${_time12(appointmentDate)}',
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
                  'Posted ${_friendlyPosted(alert.remindAt)}',
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
                  onPressed: alert.isPending && !isBusy ? onMarkRead : null,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                    backgroundColor: const Color(0xFF4B8FF5),
                    foregroundColor: Colors.white,
                    shape: const StadiumBorder(),
                    disabledBackgroundColor:
                        const Color(0xFF4B8FF5).withValues(alpha: 0.45),
                  ),
                  child: Text(markReadBusy ? 'Updating...' : 'Mark Read'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: !alert.isDismissed && !isBusy ? onDismiss : null,
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

class _DoctorAlertStatusPill extends StatelessWidget {
  const _DoctorAlertStatusPill({required this.status});

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
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DoctorAlertTypePill extends StatelessWidget {
  const _DoctorAlertTypePill({required this.config});

  final _AlertTypeConfig config;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: config.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, size: 14, color: config.foreground),
          const SizedBox(width: 6),
          Text(
            config.label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: config.foreground,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _DoctorAlertBanner extends StatelessWidget {
  const _DoctorAlertBanner({
    required this.message,
    required this.isSuccess,
  });

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

class _DoctorAlertsEmptyState extends StatelessWidget {
  const _DoctorAlertsEmptyState();

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
            'No doctor alerts yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'New patient bookings and schedule changes linked to your profile will appear here. Dismissed alerts stay hidden.',
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

class _DoctorAlertsErrorState extends StatelessWidget {
  const _DoctorAlertsErrorState({
    required this.message,
    required this.onRetry,
  });

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
            const Icon(
              Icons.error_outline_rounded,
              size: 42,
              color: _errorText,
            ),
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

class _AlertGenderPortrait extends StatelessWidget {
  const _AlertGenderPortrait({
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
      'male' => 'assets/nav/profile_boy_tryout.png',
      'female' => 'assets/nav/profile_girl_tryout.png',
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

class _AlertTypeConfig {
  const _AlertTypeConfig({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
}

_AlertTypeConfig _typeConfig(String alertType) {
  return switch (alertType) {
    'new_booking' => const _AlertTypeConfig(
        label: 'BOOKED',
        icon: Icons.event_available_rounded,
        background: _bookedBg,
        foreground: _bookedText,
      ),
    'appointment_cancelled' => const _AlertTypeConfig(
        label: 'CANCELLED',
        icon: Icons.event_busy_rounded,
        background: _cancelledBg,
        foreground: _cancelledText,
      ),
    'appointment_rescheduled' => const _AlertTypeConfig(
        label: 'RESCHEDULED',
        icon: Icons.update_rounded,
        background: _rescheduledBg,
        foreground: _rescheduledText,
      ),
    _ => const _AlertTypeConfig(
        label: 'ALERT',
        icon: Icons.notifications_active_rounded,
        background: _pendingBg,
        foreground: _pendingText,
      ),
  };
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
  return '${_month(value.month)} ${value.day}, ${value.year}';
}

String _fullDate(DateTime value) {
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
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
