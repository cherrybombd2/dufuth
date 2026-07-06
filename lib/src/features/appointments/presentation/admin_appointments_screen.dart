import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../departments/domain/department.dart';
import '../../doctors/domain/doctor.dart';
import '../data/admin_appointments_repository.dart';

const _pageBg = Color(0xFFF4F8FF);
const _primaryBlue = Color(0xFF2C7DF7);
const _darkBlue = Color(0xFF153B74);
const _mainText = Color(0xFF183153);
const _mutedText = Color(0xFF5D6B82);
const _progressBg = Color(0xFFDCE8FF);
const _errorText = Color(0xFFB42318);
const _cancelledBg = Color(0xFFFEE4E2);
const _pastBg = Color(0xFFFFF4E5);
const _pastText = Color(0xFFB54708);
const _bookedBg = Color(0xFFE8FBF4);
const _bookedText = Color(0xFF067647);
const _softBorder = Color(0xFFD6E0EE);

enum _AppointmentView { upcoming, past, cancelled, all }

class AdminAppointmentsScreen extends ConsumerStatefulWidget {
  const AdminAppointmentsScreen({super.key});

  @override
  ConsumerState<AdminAppointmentsScreen> createState() =>
      _AdminAppointmentsScreenState();
}

class _AdminAppointmentsScreenState
    extends ConsumerState<AdminAppointmentsScreen> {
  AdminAppointmentsData? _data;
  String? _loadError;
  bool _loading = true;
  bool _refreshing = false;
  String? _selectedDepartmentId;
  String? _selectedDoctorId;
  DateTime? _selectedDate;
  _AppointmentView _view = _AppointmentView.upcoming;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(adminAppointmentsRepositoryProvider).cachedData;
    _data = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
  }

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _loadError = null;
      _refreshing = showRefresh;
      _loading = _data == null;
    });

    try {
      final data = await ref
          .read(adminAppointmentsRepositoryProvider)
          .fetch(_filters);
      if (!mounted) return;
      setState(() => _data = data);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loadError = error.toString());
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _refreshing = false;
        });
      }
    }
  }

  AdminAppointmentFilters get _filters => AdminAppointmentFilters(
        departmentId: _selectedDepartmentId,
        doctorId: _selectedDoctorId,
        date: _selectedDate,
      );

  List<Doctor> _filteredDoctors(AdminAppointmentsData data) {
    if (_selectedDepartmentId == null) {
      return data.doctors;
    }
    return data.doctors
        .where((doctor) => doctor.departmentId == _selectedDepartmentId)
        .toList();
  }

  void _changeDepartment(String? departmentId) {
    final data = _data;
    setState(() {
      _selectedDepartmentId = departmentId;
      if (data != null &&
          _selectedDoctorId != null &&
          departmentId != null &&
          !data.doctors.any(
            (doctor) =>
                doctor.userId == _selectedDoctorId &&
                doctor.departmentId == departmentId,
          )) {
        _selectedDoctorId = null;
      }
    });
    _load(showRefresh: _data != null);
  }

  void _changeDoctor(String? doctorId) {
    setState(() => _selectedDoctorId = doctorId);
    _load(showRefresh: _data != null);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime(2100, 12, 31),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = picked);
    _load(showRefresh: _data != null);
  }

  void _clearDate() {
    setState(() => _selectedDate = null);
    _load(showRefresh: _data != null);
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('Manage Appointments')),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (_loading && data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_loadError != null && data == null) {
              return _FullErrorState(
                message: _loadError!,
                onRetry: () => _load(),
              );
            }

            final visibleData = data!;
            final appointments = _visibleAppointments(visibleData);
            final doctors = _filteredDoctors(visibleData);

            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _primaryBlue,
                      backgroundColor: _progressBg,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _AdminHeaderCard(),
                  const SizedBox(height: 18),
                  _FiltersCard(
                    departments: visibleData.departments,
                    doctors: doctors,
                    selectedDepartmentId: _selectedDepartmentId,
                    selectedDoctorId: _selectedDoctorId,
                    selectedDate: _selectedDate,
                    selectedView: _view,
                    counts: _counts(visibleData),
                    onDepartmentChanged: _changeDepartment,
                    onDoctorChanged: _changeDoctor,
                    onViewChanged: (view) => setState(() => _view = view),
                    onPickDate: _pickDate,
                    onClearDate: _clearDate,
                  ),
                  const SizedBox(height: 20),
                  if (appointments.isEmpty)
                    _EmptyAppointmentsCard(view: _view)
                  else
                    ...appointments.map(
                      (appointment) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: _AppointmentCard(
                          appointment: appointment,
                          doctorName: _doctorName(appointment, visibleData.doctors),
                          departmentName:
                              _departmentName(appointment, visibleData.departments),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Map<_AppointmentView, int> _counts(AdminAppointmentsData data) {
    final filtered = _filteredAppointments(data);
    return {
      _AppointmentView.upcoming:
          filtered.where((appointment) => appointment.isUpcoming).length,
      _AppointmentView.past: filtered
          .where((appointment) => !appointment.isCancelled && appointment.isPast)
          .length,
      _AppointmentView.cancelled:
          filtered.where((appointment) => appointment.isCancelled).length,
      _AppointmentView.all: filtered.length,
    };
  }

  List<AdminAppointment> _visibleAppointments(AdminAppointmentsData data) {
    final filtered = _filteredAppointments(data);
    final visible = filtered.where((appointment) {
      return switch (_view) {
        _AppointmentView.upcoming => appointment.isUpcoming,
        _AppointmentView.past => !appointment.isCancelled && appointment.isPast,
        _AppointmentView.cancelled => appointment.isCancelled,
        _AppointmentView.all => true,
      };
    }).toList();

    visible.sort((a, b) {
      if (_view == _AppointmentView.past ||
          _view == _AppointmentView.cancelled) {
        return b.endAt.compareTo(a.endAt);
      }
      return a.startAt.compareTo(b.startAt);
    });
    return visible;
  }

  List<AdminAppointment> _filteredAppointments(AdminAppointmentsData data) {
    return data.appointments.where((appointment) {
      final departmentMatches = _selectedDepartmentId == null ||
          appointment.departmentId == _selectedDepartmentId ||
          appointment.departmentName == _selectedDepartmentId;
      final doctorMatches =
          _selectedDoctorId == null || appointment.doctorId == _selectedDoctorId;
      final dateMatches =
          _selectedDate == null || _sameDay(appointment.startAt, _selectedDate!);
      return departmentMatches && doctorMatches && dateMatches;
    }).toList();
  }

  String _doctorName(AdminAppointment appointment, List<Doctor> doctors) {
    if (appointment.doctorName != null && appointment.doctorName!.isNotEmpty) {
      return appointment.doctorName!;
    }
    final match = doctors.where((doctor) => doctor.userId == appointment.doctorId);
    return match.isEmpty ? 'Doctor' : match.first.fullName;
  }

  String _departmentName(
    AdminAppointment appointment,
    List<Department> departments,
  ) {
    if (appointment.departmentName.isNotEmpty) {
      return appointment.departmentName;
    }
    final match = departments.where(
      (department) => department.name == appointment.departmentId,
    );
    return match.isEmpty ? 'Department' : match.first.name;
  }

  bool _sameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _AdminHeaderCard extends StatelessWidget {
  const _AdminHeaderCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1EDFF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'assets/nav/dashboard_calendar.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Appointments',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: _darkBlue,
                        fontWeight: FontWeight.w800,
                        fontSize: 24,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Review active bookings first, then switch to past, cancelled, or full history when needed.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: _mutedText,
                        height: 1.45,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FiltersCard extends StatelessWidget {
  const _FiltersCard({
    required this.departments,
    required this.doctors,
    required this.selectedDepartmentId,
    required this.selectedDoctorId,
    required this.selectedDate,
    required this.selectedView,
    required this.counts,
    required this.onDepartmentChanged,
    required this.onDoctorChanged,
    required this.onViewChanged,
    required this.onPickDate,
    required this.onClearDate,
  });

  final List<Department> departments;
  final List<Doctor> doctors;
  final String? selectedDepartmentId;
  final String? selectedDoctorId;
  final DateTime? selectedDate;
  final _AppointmentView selectedView;
  final Map<_AppointmentView, int> counts;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onDoctorChanged;
  final ValueChanged<_AppointmentView> onViewChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 14),
          _DropdownField<String>(
            label: 'Department',
            value: selectedDepartmentId ?? '',
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All Departments'),
              ),
              ...departments.map(
                (department) => DropdownMenuItem<String>(
                  value: department.name,
                  child: Text(department.name),
                ),
              ),
            ],
            onChanged: (value) =>
                onDepartmentChanged(value == null || value.isEmpty ? null : value),
          ),
          const SizedBox(height: 14),
          _DropdownField<String>(
            label: 'Doctor',
            value: selectedDoctorId ?? '',
            items: [
              const DropdownMenuItem<String>(
                value: '',
                child: Text('All Doctors'),
              ),
              ...doctors.map(
                (doctor) => DropdownMenuItem<String>(
                  value: doctor.userId,
                  child: Text(doctor.fullName),
                ),
              ),
            ],
            onChanged: (value) =>
                onDoctorChanged(value == null || value.isEmpty ? null : value),
          ),
          const SizedBox(height: 14),
          _ViewSwitch(
            selected: selectedView,
            counts: counts,
            onChanged: onViewChanged,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPickDate,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    selectedDate == null
                        ? 'Filter by Date'
                        : _formatFullDate(selectedDate!),
                  ),
                ),
              ),
              if (selectedDate != null) ...[
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Clear date filter',
                  onPressed: onClearDate,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({
    required this.selected,
    required this.counts,
    required this.onChanged,
  });

  final _AppointmentView selected;
  final Map<_AppointmentView, int> counts;
  final ValueChanged<_AppointmentView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _progressBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: _AppointmentView.values.map((view) {
          final isSelected = view == selected;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(999),
                onTap: () => onChanged(view),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.white : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '${_viewLabel(view)} (${counts[view] ?? 0})',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isSelected ? _darkBlue : _mutedText,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.doctorName,
    required this.departmentName,
  });

  final AdminAppointment appointment;
  final String doctorName;
  final String departmentName;

  @override
  Widget build(BuildContext context) {
    final badge = _badgeData(appointment);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  doctorName,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: _darkBlue,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: badge.background,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  badge.label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: badge.foreground,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            departmentName,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${_formatFullDate(appointment.startAt)} - ${_formatTime(appointment.startAt)} - ${_formatTime(appointment.endAt)}',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mainText,
                  fontWeight: FontWeight.w600,
                ),
          ),
          if (appointment.isCancelled) ...[
            const SizedBox(height: 8),
            Text(
              'This appointment has been cancelled and should not count as an upcoming visit.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _errorText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ] else if (appointment.isPast) ...[
            const SizedBox(height: 8),
            Text(
              'This appointment is now in the past and is shown here for reference.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _pastText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyAppointmentsCard extends StatelessWidget {
  const _EmptyAppointmentsCard({required this.view});

  final _AppointmentView view;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.event_busy_rounded, color: _primaryBlue, size: 42),
          const SizedBox(height: 12),
          Text(
            'No appointments found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: _darkBlue,
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            _emptyMessage(view),
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
            const Icon(
              Icons.error_outline_rounded,
              color: _errorText,
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              message.isEmpty
                  ? 'We could not load appointments right now.'
                  : message,
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

class _DropdownField<T> extends StatelessWidget {
  const _DropdownField({
    required this.label,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  final String label;
  final T value;
  final List<DropdownMenuItem<T>> items;
  final ValueChanged<T?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<T>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _softBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}

class _BadgeData {
  const _BadgeData(this.label, this.background, this.foreground);

  final String label;
  final Color background;
  final Color foreground;
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: const [
      BoxShadow(
        color: Color(0x12000000),
        blurRadius: 16,
        offset: Offset(0, 8),
      ),
    ],
  );
}

_BadgeData _badgeData(AdminAppointment appointment) {
  if (appointment.isCancelled) {
    return const _BadgeData('CANCELLED', _cancelledBg, _errorText);
  }
  if (appointment.isPast) {
    return const _BadgeData('PAST', _pastBg, _pastText);
  }
  return const _BadgeData('BOOKED', _bookedBg, _bookedText);
}

String _viewLabel(_AppointmentView view) {
  return switch (view) {
    _AppointmentView.upcoming => 'Upcoming',
    _AppointmentView.past => 'Past',
    _AppointmentView.cancelled => 'Cancelled',
    _AppointmentView.all => 'All',
  };
}

String _emptyMessage(_AppointmentView view) {
  return switch (view) {
    _AppointmentView.upcoming =>
      'There are no upcoming appointments matching the current filters.',
    _AppointmentView.past =>
      'There are no past appointments matching the current filters.',
    _AppointmentView.cancelled =>
      'There are no cancelled appointments matching the current filters.',
    _AppointmentView.all =>
      'Try changing your filters or wait for new bookings to come in.',
  };
}

String _formatFullDate(DateTime value) {
  return '${_month(value.month)} ${value.day}, ${value.year}';
}

String _formatTime(DateTime value) {
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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
