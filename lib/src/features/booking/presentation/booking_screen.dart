import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../availability_slots/domain/availability_slot.dart';
import '../../booking/data/booking_repository.dart';
import '../../auth/application/app_session_provider.dart';
import '../../departments/domain/department.dart';
import '../../doctors/domain/doctor.dart';

class BookingScreen extends ConsumerStatefulWidget {
  const BookingScreen({super.key, this.currentAppointment});

  final BookingAppointment? currentAppointment;

  bool get isReschedule => currentAppointment != null;

  @override
  ConsumerState<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends ConsumerState<BookingScreen> {
  final List<Department> _departments = [];
  final List<Doctor> _allDoctors = [];
  final List<AvailabilitySlot> _slots = [];

  Department? _selectedDepartment;
  Doctor? _selectedDoctor;
  AvailabilitySlot? _selectedSlot;
  DateTime _selectedDate = _today();
  Timer? _slotRefreshTimer;
  String? _error;
  bool _isInitialLoading = true;
  bool _isRefreshing = false;
  bool _isLoadingDoctors = false;
  bool _isLoadingSlots = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    final appointment = widget.currentAppointment;
    if (appointment != null) {
      _selectedDate = _dateOnly(appointment.startAt);
    }
    _loadInitial();
    _slotRefreshTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      _refreshVisibleSlots(background: true);
    });
  }

  @override
  void dispose() {
    _slotRefreshTimer?.cancel();
    super.dispose();
  }

  List<Doctor> get _departmentDoctors {
    final department = _selectedDepartment;
    if (department == null) return [];
    return _allDoctors
        .where((doctor) => doctor.departmentId == department.name)
        .toList();
  }

  Future<void> _loadInitial() async {
    setState(() {
      _isInitialLoading = true;
      _error = null;
    });
    try {
      final data = await ref.read(bookingRepositoryProvider).fetchReferenceData();
      if (!mounted) return;
      setState(() {
        _departments
          ..clear()
          ..addAll(data.departments);
        _allDoctors
          ..clear()
          ..addAll(data.doctors);
        _isInitialLoading = false;
      });
      _prefillForReschedule();
    } on BookingException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _isInitialLoading = false;
      });
    }
  }

  Future<void> _refreshReferenceData() async {
    setState(() {
      _isRefreshing = true;
      _error = null;
    });
    final oldDepartment = _selectedDepartment?.name;
    final oldDoctor = _selectedDoctor?.userId;
    final oldSlot = _selectedSlot?.id;
    try {
      final data = await ref.read(bookingRepositoryProvider).fetchReferenceData();
      if (!mounted) return;
      setState(() {
        _departments
          ..clear()
          ..addAll(data.departments);
        _allDoctors
          ..clear()
          ..addAll(data.doctors);
        _selectedDepartment = _firstWhereOrNull(
          _departments,
          (item) => item.name == oldDepartment,
        );
        _selectedDoctor = _firstWhereOrNull(
          _allDoctors,
          (item) =>
              item.userId == oldDoctor &&
              item.departmentId == _selectedDepartment?.name,
        );
        if (_selectedDepartment == null || _selectedDoctor == null) {
          _slots.clear();
          _selectedSlot = null;
        }
      });
      await _refreshVisibleSlots(background: true, preferredSlotId: oldSlot);
    } on BookingException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isRefreshing = false);
    }
  }

  void _prefillForReschedule() {
    final appointment = widget.currentAppointment;
    if (appointment == null) return;
    final department = _firstWhereOrNull(
      _departments,
      (item) => item.name == appointment.departmentId,
    );
    final doctor = _firstWhereOrNull(
      _allDoctors,
      (item) => item.userId == appointment.doctorId,
    );
    setState(() {
      _selectedDepartment = department;
      if (doctor != null && doctor.departmentId == department?.name) {
        _selectedDoctor = doctor;
      }
    });
    _refreshVisibleSlots(background: true);
  }

  void _selectDepartment(Department department) {
    if (widget.isReschedule &&
        department.name != widget.currentAppointment?.departmentId) {
      return;
    }
    setState(() {
      _selectedDepartment = department;
      _selectedDoctor = null;
      _selectedSlot = null;
      _slots.clear();
      _isLoadingDoctors = true;
    });
    Timer(const Duration(milliseconds: 180), () {
      if (mounted) setState(() => _isLoadingDoctors = false);
    });
  }

  void _selectDoctor(Doctor doctor) {
    setState(() {
      _selectedDoctor = doctor;
      _selectedSlot = null;
      _slots.clear();
    });
    _refreshVisibleSlots();
  }

  Future<void> _selectDate(DateTime value) async {
    setState(() {
      _selectedDate = _dateOnly(value);
      _selectedSlot = null;
      _slots.clear();
    });
    await _refreshVisibleSlots();
  }

  Future<void> _showDatePicker() async {
    final today = _today();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(today) ? today : _selectedDate,
      firstDate: today,
      lastDate: today.add(const Duration(days: 30)),
    );
    if (picked != null) {
      await _selectDate(picked);
    }
  }

  Future<void> _refreshVisibleSlots({
    bool background = false,
    String? preferredSlotId,
  }) async {
    final department = _selectedDepartment;
    final doctor = _selectedDoctor;
    if (department == null || doctor == null || _isSubmitting) return;
    if (_isLoadingSlots && background) return;
    if (!background) {
      setState(() {
        _isLoadingSlots = true;
        _error = null;
      });
    }
    final previousSlotId = preferredSlotId ?? _selectedSlot?.id;
    try {
      final slots = await ref
          .read(bookingRepositoryProvider)
          .fetchAvailableSlots(
            departmentId: department.name,
            doctorId: doctor.userId,
            date: _selectedDate,
          );
      if (!mounted) return;
      setState(() {
        _slots
          ..clear()
          ..addAll(slots);
        _selectedSlot = _firstWhereOrNull(
          _slots,
          (item) => item.id == previousSlotId,
        );
        _selectedSlot ??= _slots.isNotEmpty ? _slots.first : null;
      });
    } on BookingException catch (error) {
      if (!mounted) return;
      if (!background) {
        setState(() => _error = error.message);
      }
    } finally {
      if (mounted && !background) {
        setState(() => _isLoadingSlots = false);
      }
    }
  }

  Future<void> _submit() async {
    final department = _selectedDepartment;
    final doctor = _selectedDoctor;
    final slot = _selectedSlot;
    if (department == null || doctor == null || slot == null || _isSubmitting) {
      return;
    }
    if (slot.startAt.isBefore(DateTime.now())) {
      setState(() {
        _error = 'This time slot has already passed. Please choose a later time.';
      });
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final repository = ref.read(bookingRepositoryProvider);
      if (widget.isReschedule) {
        await repository.rescheduleAppointment(
          appointmentId: widget.currentAppointment!.id,
          departmentId: department.name,
          doctorId: doctor.userId,
          slotId: slot.id,
        );
      } else {
        await repository.confirmAppointment(
          departmentId: department.name,
          doctorId: doctor.userId,
          slotId: slot.id,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on BookingException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(appSessionProvider).valueOrNull;
    final isPatientAccount = session?.user?.role == 'patient';
    final sessionRoleWarning = session?.user != null && !isPatientAccount
        ? 'Please sign in with a patient account to book appointments.'
        : null;
    final canSubmit =
        _selectedDepartment != null &&
        _selectedDoctor != null &&
        _selectedSlot != null &&
        !_isSubmitting &&
        isPatientAccount;

    return Scaffold(
      backgroundColor: _BookingColors.background,
      appBar: AppBar(
        title: Text(widget.isReschedule ? 'Reschedule Appointment' : 'Book Appointment'),
        backgroundColor: _BookingColors.background,
        foregroundColor: _BookingColors.darkBlue,
        elevation: 0,
      ),
      body: SafeArea(
        child: _isInitialLoading
            ? const _BookingSkeleton()
            : _error != null && _departments.isEmpty
            ? _FullErrorState(message: _error!, onRetry: _loadInitial)
            : RefreshIndicator(
                onRefresh: _refreshReferenceData,
                color: _BookingColors.blue,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  children: [
                    _TopHeading(
                      isReschedule: widget.isReschedule,
                      isRefreshing: _isRefreshing,
                      onRefresh: _refreshReferenceData,
                    ),
                    if (_isRefreshing) ...[
                      const SizedBox(height: 10),
                      const LinearProgressIndicator(
                        minHeight: 3,
                        color: _BookingColors.blue,
                        backgroundColor: Color(0xFFDCE8FF),
                      ),
                    ],
                    if (widget.currentAppointment case final appointment?) ...[
                      const SizedBox(height: 18),
                      _CurrentAppointmentCard(appointment: appointment),
                    ],
                    const SizedBox(height: 18),
                    _DateSelectionCard(
                      selectedDate: _selectedDate,
                      onDateSelected: _selectDate,
                      onManualDate: _showDatePicker,
                    ),
                    _SectionTitle(title: 'Choose Department'),
                    const SizedBox(height: 12),
                    _DepartmentSection(
                      departments: _departments,
                      selectedDepartment: _selectedDepartment,
                      lockedDepartmentId: widget.currentAppointment?.departmentId,
                      onSelected: _selectDepartment,
                    ),
                    const SizedBox(height: 24),
                    _DoctorSection(
                      doctors: _departmentDoctors,
                      selectedDepartment: _selectedDepartment,
                      selectedDoctor: _selectedDoctor,
                      isLoading: _isLoadingDoctors,
                      onSelected: _selectDoctor,
                    ),
                    const SizedBox(height: 24),
                    _SlotSection(
                      slots: _slots,
                      selectedDate: _selectedDate,
                      selectedDoctor: _selectedDoctor,
                      selectedSlot: _selectedSlot,
                      isLoading: _isLoadingSlots,
                      onSelected: (slot) => setState(() => _selectedSlot = slot),
                    ),
                    if (_selectedDepartment != null &&
                        _selectedDoctor != null &&
                        _selectedSlot != null) ...[
                      const SizedBox(height: 18),
                      _AppointmentSummaryCard(
                        isReschedule: widget.isReschedule,
                        department: _selectedDepartment!,
                        doctor: _selectedDoctor!,
                        slot: _selectedSlot!,
                      ),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 18),
                      _ErrorBanner(message: _error!),
                    ] else if (sessionRoleWarning != null) ...[
                      const SizedBox(height: 18),
                      _ErrorBanner(message: sessionRoleWarning),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: canSubmit ? _submit : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _BookingColors.blue,
                          foregroundColor: Colors.white,
                          disabledBackgroundColor: const Color(0xFFD8E2F2),
                          disabledForegroundColor: _BookingColors.muted,
                          minimumSize: const Size.fromHeight(56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: Text(
                          _isSubmitting
                              ? (widget.isReschedule ? 'Rescheduling...' : 'Confirming...')
                              : (widget.isReschedule
                                    ? 'Confirm Reschedule'
                                    : 'Confirm Appointment'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _TopHeading extends StatelessWidget {
  const _TopHeading({
    required this.isReschedule,
    required this.isRefreshing,
    required this.onRefresh,
  });

  final bool isReschedule;
  final bool isRefreshing;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                isReschedule ? 'Reschedule Visit' : 'Choose Department',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: _BookingColors.darkBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: isRefreshing ? null : onRefresh,
              icon: isRefreshing
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh_rounded, size: 18),
              label: Text(isRefreshing ? 'Refreshing' : 'Refresh'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          isReschedule
              ? 'Pick a new doctor, date, or slot for this appointment. Reschedules stay within the original department.'
              : 'Start by picking the clinic you want, then we will show available doctors and time slots.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: _BookingColors.muted,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Use Refresh to pull the latest departments, doctors, and slots.',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: _BookingColors.muted,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _CurrentAppointmentCard extends StatelessWidget {
  const _CurrentAppointmentCard({required this.appointment});

  final BookingAppointment appointment;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Current Appointment'),
          const SizedBox(height: 8),
          Text(
            '${appointment.doctorName} - ${appointment.departmentName}',
            style: const TextStyle(color: _BookingColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fullDate(appointment.startAt)} - ${_time(appointment.startAt)} - ${_time(appointment.endAt)}',
            style: const TextStyle(
              color: _BookingColors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _DateSelectionCard extends StatelessWidget {
  const _DateSelectionCard({
    required this.selectedDate,
    required this.onDateSelected,
    required this.onManualDate,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final VoidCallback onManualDate;

  @override
  Widget build(BuildContext context) {
    final dates = List.generate(5, (index) => _today().add(Duration(days: index)));
    return _WhiteCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _CardTitle('Selected Date'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final date in dates)
                ChoiceChip(
                  label: Text(_shortDateLabel(date)),
                  selected: _sameDay(date, selectedDate),
                  showCheckmark: true,
                  checkmarkColor: _BookingColors.darkBlue,
                  selectedColor: const Color(0xFFDDEBFF),
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: _sameDay(date, selectedDate)
                        ? _BookingColors.blue
                        : const Color(0xFFE4EBF5),
                    width: _sameDay(date, selectedDate) ? 1.5 : 1,
                  ),
                  labelStyle: const TextStyle(
                    color: _BookingColors.text,
                    fontWeight: FontWeight.w700,
                  ),
                  onSelected: (_) => onDateSelected(date),
                ),
            ],
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: onManualDate,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(_fullDate(selectedDate)),
          ),
        ],
      ),
    );
  }
}

class _DepartmentSection extends StatelessWidget {
  const _DepartmentSection({
    required this.departments,
    required this.selectedDepartment,
    required this.lockedDepartmentId,
    required this.onSelected,
  });

  final List<Department> departments;
  final Department? selectedDepartment;
  final String? lockedDepartmentId;
  final ValueChanged<Department> onSelected;

  @override
  Widget build(BuildContext context) {
    if (departments.isEmpty) {
      return const _EmptyStateCard(
        icon: Icons.apartment_rounded,
        title: 'No departments yet',
        message: 'Seed or create department records in Firestore to start booking.',
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final department in departments)
          _DepartmentCard(
            department: department,
            selected: selectedDepartment?.name == department.name,
            locked: lockedDepartmentId != null && lockedDepartmentId != department.name,
            onTap: () => onSelected(department),
          ),
      ],
    );
  }
}

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.selected,
    required this.locked,
    required this.onTap,
  });

  final Department department;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = locked
        ? const Color(0xFFF5F7FB)
        : selected
        ? const Color(0xFFDDEBFF)
        : Colors.white;
    return InkWell(
      onTap: locked ? null : onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 160,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: selected ? _BookingColors.blue : const Color(0xFFE4EBF5),
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: locked ? const Color(0xFFF0F3F8) : Colors.white,
              child: _DepartmentIcon(department: department, disabled: locked),
            ),
            const SizedBox(height: 12),
            Text(
              department.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: locked ? _BookingColors.muted : _BookingColors.darkBlue,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              department.description?.trim().isNotEmpty == true
                  ? department.description!
                  : 'Clinic department',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: _BookingColors.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            if (locked) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: const ShapeDecoration(
                  color: Color(0xFFE9EEF6),
                  shape: StadiumBorder(),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_rounded, size: 12, color: _BookingColors.muted),
                    SizedBox(width: 4),
                    Text(
                      'Same dept only',
                      style: TextStyle(
                        color: _BookingColors.muted,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Locked for this reschedule',
                style: TextStyle(
                  color: _BookingColors.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DepartmentIcon extends StatelessWidget {
  const _DepartmentIcon({required this.department, required this.disabled});

  final Department department;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final path = switch (department.iconKey) {
      'favorite' || 'cardiology' => 'assets/departments/cardiology.png',
      'child_care' || 'pediatrics' => 'assets/departments/pediatrics.png',
      'gynaecology' => 'assets/departments/gynaecology.png',
      'medical_services' || 'general_medicine' => 'assets/departments/general_medicine.png',
      _ => null,
    };
    if (path != null) {
      return Opacity(
        opacity: disabled ? 0.55 : 1,
        child: Image.asset(
          path,
          width: 36,
          height: 36,
          fit: BoxFit.contain,
          errorBuilder: (_, _, _) => _fallbackIcon(),
        ),
      );
    }
    return _fallbackIcon();
  }

  Widget _fallbackIcon() {
    final icon = switch (department.iconKey) {
      'favorite' => Icons.favorite_rounded,
      'child_care' => Icons.child_care_rounded,
      'medical_services' => Icons.medical_services_rounded,
      _ => Icons.local_hospital_rounded,
    };
    return Icon(icon, color: _BookingColors.blue, size: 32);
  }
}

class _DoctorSection extends StatelessWidget {
  const _DoctorSection({
    required this.doctors,
    required this.selectedDepartment,
    required this.selectedDoctor,
    required this.isLoading,
    required this.onSelected,
  });

  final List<Doctor> doctors;
  final Department? selectedDepartment;
  final Doctor? selectedDoctor;
  final bool isLoading;
  final ValueChanged<Doctor> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeaderRow(
          title: 'Choose Doctor',
          trailing: isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : null,
        ),
        const SizedBox(height: 12),
        if (selectedDepartment == null)
          const _EmptyStateCard(
            icon: Icons.medical_services_rounded,
            title: 'Pick a department first',
            message: 'Doctors will appear here once you choose a department.',
          )
        else if (!isLoading && doctors.isEmpty)
          const _EmptyStateCard(
            icon: Icons.person_search_rounded,
            title: 'No doctors available',
            message: 'There are no active doctors assigned to this department yet.',
          )
        else
          ...doctors.map(
            (doctor) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DoctorCard(
                doctor: doctor,
                selected: selectedDoctor?.userId == doctor.userId,
                onTap: () => onSelected(doctor),
              ),
            ),
          ),
      ],
    );
  }
}

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.selected,
    required this.onTap,
  });

  final Doctor doctor;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? _BookingColors.blue : const Color(0xFFE4EBF5),
            width: selected ? 1.4 : 1,
          ),
        ),
        child: Row(
          children: [
            _DoctorPortrait(gender: doctor.gender),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctor.fullName,
                    style: const TextStyle(
                      color: _BookingColors.darkBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.specialization?.trim().isNotEmpty == true
                        ? doctor.specialization!
                        : 'Specialist',
                    style: const TextStyle(color: _BookingColors.muted),
                  ),
                  if (doctor.bio?.trim().isNotEmpty == true) ...[
                    const SizedBox(height: 6),
                    Text(
                      doctor.bio!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: _BookingColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: _BookingColors.blue,
              ),
          ],
        ),
      ),
    );
  }
}

class _DoctorPortrait extends StatelessWidget {
  const _DoctorPortrait({required this.gender});

  final String? gender;

  @override
  Widget build(BuildContext context) {
    final normalized = gender?.toLowerCase();
    final path = normalized == 'male'
        ? 'assets/profile/boy_3d.png'
        : normalized == 'female'
        ? 'assets/profile/girl_3d.png'
        : null;
    if (path == null) {
      return const CircleAvatar(
        radius: 24,
        backgroundColor: Color(0xFFE6F0FF),
        child: Icon(Icons.person_rounded, color: _BookingColors.blue, size: 24),
      );
    }
    return ClipOval(
      child: Image.asset(path, width: 48, height: 48, fit: BoxFit.cover),
    );
  }
}

class _SlotSection extends StatelessWidget {
  const _SlotSection({
    required this.slots,
    required this.selectedDate,
    required this.selectedDoctor,
    required this.selectedSlot,
    required this.isLoading,
    required this.onSelected,
  });

  final List<AvailabilitySlot> slots;
  final DateTime selectedDate;
  final Doctor? selectedDoctor;
  final AvailabilitySlot? selectedSlot;
  final bool isLoading;
  final ValueChanged<AvailabilitySlot> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _HeaderRow(
          title: 'Available Slots',
          trailing: Text(
            _shortDateLabel(selectedDate),
            style: const TextStyle(
              color: _BookingColors.blue,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (selectedDoctor == null)
          const _EmptyStateCard(
            icon: Icons.schedule_rounded,
            title: 'Pick a doctor first',
            message: 'Available appointment times will appear here after a doctor is selected.',
          )
        else if (isLoading)
          const _EmptyStateCard(
            icon: Icons.hourglass_top_rounded,
            title: 'Loading available slots',
            message: 'Checking open appointment times for this doctor.',
          )
        else if (slots.isEmpty)
          const _EmptyStateCard(
            icon: Icons.event_busy_rounded,
            title: 'No open slots',
            message: 'Try another date or doctor to see more appointment times.',
          )
        else
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final slot in slots)
                  ChoiceChip(
                    label: Text('${_time(slot.startAt)} - ${_time(slot.endAt)}'),
                    selected: selectedSlot?.id == slot.id,
                    selectedColor: const Color(0xFFDDEBFF),
                    backgroundColor: Colors.white,
                    checkmarkColor: _BookingColors.darkBlue,
                    side: BorderSide(
                      color: selectedSlot?.id == slot.id
                          ? _BookingColors.blue
                          : const Color(0xFFE4EBF5),
                      width: selectedSlot?.id == slot.id ? 1.5 : 1,
                    ),
                    labelStyle: const TextStyle(
                      color: _BookingColors.text,
                      fontWeight: FontWeight.w700,
                    ),
                    onSelected: (_) => onSelected(slot),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _AppointmentSummaryCard extends StatelessWidget {
  const _AppointmentSummaryCard({
    required this.isReschedule,
    required this.department,
    required this.doctor,
    required this.slot,
  });

  final bool isReschedule;
  final Department department;
  final Doctor doctor;
  final AvailabilitySlot slot;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3FF),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CardTitle(isReschedule ? 'New Appointment Summary' : 'Appointment Summary'),
          const SizedBox(height: 8),
          Text(
            '${department.name} - ${doctor.fullName}',
            style: const TextStyle(color: _BookingColors.muted),
          ),
          const SizedBox(height: 4),
          Text(
            '${_fullDate(slot.startAt)} - ${_time(slot.startAt)} - ${_time(slot.endAt)}',
            style: const TextStyle(
              color: _BookingColors.blue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SectionTitle(title: title),
        ),
        ...?_optionalWidget(trailing),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        color: _BookingColors.darkBlue,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _CardTitle extends StatelessWidget {
  const _CardTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: _BookingColors.darkBlue,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _WhiteCard extends StatelessWidget {
  const _WhiteCard({required this.child, required this.padding});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: child,
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return _WhiteCard(
      padding: const EdgeInsets.all(22),
      child: Column(
        children: [
          Icon(icon, size: 42, color: _BookingColors.blue),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: _BookingColors.darkBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: _BookingColors.muted, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE4E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: const TextStyle(
          color: Color(0xFFB42318),
          fontWeight: FontWeight.w600,
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
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB42318),
              size: 46,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: _BookingColors.muted),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _BookingSkeleton extends StatelessWidget {
  const _BookingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      children: [
        Container(width: 220, height: 28, decoration: _skeletonDecoration()),
        const SizedBox(height: 14),
        Container(height: 56, decoration: _skeletonDecoration()),
        const SizedBox(height: 18),
        Container(height: 124, decoration: _skeletonDecoration(radius: 24)),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < 4; index++)
              Container(
                width: 160,
                height: 154,
                decoration: _skeletonDecoration(radius: 24),
              ),
          ],
        ),
        const SizedBox(height: 24),
        Container(height: 92, decoration: _skeletonDecoration(radius: 22)),
        const SizedBox(height: 12),
        Container(height: 92, decoration: _skeletonDecoration(radius: 22)),
      ],
    );
  }

  BoxDecoration _skeletonDecoration({double radius = 16}) {
    return BoxDecoration(
      color: Colors.white.withValues(alpha: 0.78),
      borderRadius: BorderRadius.circular(radius),
    );
  }
}

class _BookingColors {
  const _BookingColors._();

  static const background = Color(0xFFF4F8FF);
  static const blue = Color(0xFF2C7DF7);
  static const darkBlue = Color(0xFF153B74);
  static const text = Color(0xFF183153);
  static const muted = Color(0xFF5D6B82);
}

DateTime _today() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}

DateTime _dateOnly(DateTime value) {
  return DateTime(value.year, value.month, value.day);
}

bool _sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

String _shortDateLabel(DateTime value) {
  final today = _today();
  if (_sameDay(value, today)) return 'Today';
  if (_sameDay(value, today.add(const Duration(days: 1)))) return 'Tomorrow';
  return '${_month(value.month)} ${value.day}';
}

String _fullDate(DateTime value) {
  return '${_month(value.month)} ${value.day}, ${value.year}';
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

String _time(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

T? _firstWhereOrNull<T>(Iterable<T> items, bool Function(T item) test) {
  for (final item in items) {
    if (test(item)) return item;
  }
  return null;
}

List<Widget>? _optionalWidget(Widget? widget) {
  return widget == null ? null : [widget];
}
