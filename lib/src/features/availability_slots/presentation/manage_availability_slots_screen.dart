import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../departments/domain/department.dart';
import '../../doctors/domain/doctor.dart';
import '../data/availability_slot_repository.dart';
import '../domain/availability_slot.dart';

const _pageBg = Color(0xFFF4F8FF);
const _primaryBlue = Color(0xFF2C7DF7);
const _darkBlue = Color(0xFF153B74);
const _mainText = Color(0xFF183153);
const _mutedText = Color(0xFF5D6B82);
const _softBorder = Color(0xFFD6E0EE);
const _progressTrack = Color(0xFFDCE8FF);
const _successBg = Color(0xFFE8FBF4);
const _successText = Color(0xFF067647);
const _errorBg = Color(0xFFFEE4E2);
const _errorText = Color(0xFFB42318);
const _bookedBg = Color(0xFFFFF4E5);
const _bookedText = Color(0xFFB54708);
const _cautionBg = Color(0xFFFFF0F0);
const _cautionBorder = Color(0xFFFDB0AC);
const _positiveBorder = Color(0xFFA6F4C5);

enum _SlotView { upcoming, past, all }

class ManageAvailabilitySlotsScreen extends ConsumerStatefulWidget {
  const ManageAvailabilitySlotsScreen({super.key});

  @override
  ConsumerState<ManageAvailabilitySlotsScreen> createState() =>
      _ManageAvailabilitySlotsScreenState();
}

class _ManageAvailabilitySlotsScreenState
    extends ConsumerState<ManageAvailabilitySlotsScreen> {
  AvailabilitySlotData? _data;
  String? _loadError;
  String? _statusMessage;
  bool _statusIsSuccess = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  bool _cleaning = false;
  String? _departmentId;
  String? _doctorId;
  DateTime? _selectedDate;
  _SlotView _view = _SlotView.upcoming;
  Timer? _statusTimer;

  List<Department> get _activeDepartments =>
      (_data?.departments ?? []).where((item) => item.isActive).toList();

  List<Doctor> get _activeDoctors =>
      (_data?.doctors ?? []).where((item) => item.isActive).toList();

  List<Doctor> get _filteredDoctors {
    final doctors = _activeDoctors;
    if (_departmentId == null) return doctors;
    return doctors.where((item) => item.departmentId == _departmentId).toList();
  }

  SlotFilters get _filters => SlotFilters(
    departmentId: _departmentId,
    doctorId: _doctorId,
    date: _selectedDate,
  );

  @override
  void initState() {
    super.initState();
    final cached = ref.read(availabilitySlotRepositoryProvider).cachedData;
    _data = cached;
    _loading = cached == null;
    _load(showRefresh: cached != null);
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _loadError = null;
      _refreshing = showRefresh;
      _loading = _data == null;
    });
    try {
      final data = await ref
          .read(availabilitySlotRepositoryProvider)
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

  Future<void> _chooseDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (!mounted || picked == null) return;
    setState(() => _selectedDate = picked);
    await _load(showRefresh: true);
  }

  Future<void> _openSingleDialog([AvailabilitySlot? slot]) async {
    if (_activeDepartments.isEmpty || _activeDoctors.isEmpty) return;
    final draft = await showDialog<SlotDraft>(
      context: context,
      builder: (context) => _SingleSlotDialog(
        departments: _activeDepartments,
        doctors: _activeDoctors,
        slot: slot,
      ),
    );
    if (!mounted || draft == null) return;
    await _runAction(
      successMessage: slot == null
          ? 'Slot created successfully.'
          : 'Slot updated successfully.',
      action: () {
        final repository = ref.read(availabilitySlotRepositoryProvider);
        return slot == null
            ? repository.create(draft)
            : repository.update(slot.id, draft);
      },
    );
  }

  Future<void> _openBulkDialog() async {
    if (_activeDepartments.isEmpty || _activeDoctors.isEmpty) return;
    final draft = await showDialog<BulkSlotDraft>(
      context: context,
      builder: (context) => _BulkSlotDialog(
        departments: _activeDepartments,
        doctors: _activeDoctors,
      ),
    );
    if (!mounted || draft == null) return;
    await _runAction(
      successMessage: 'Slots created successfully.',
      action: () =>
          ref.read(availabilitySlotRepositoryProvider).bulkCreate(draft),
    );
  }

  Future<void> _openAutoDialog() async {
    if (_activeDepartments.isEmpty || _activeDoctors.isEmpty) return;
    final draft = await showDialog<AutoGenerateDraft>(
      context: context,
      builder: (context) => _AutoGenerateDialog(
        departments: _activeDepartments,
        doctors: _activeDoctors,
      ),
    );
    if (!mounted || draft == null) return;
    await _runAction(
      successMessage: 'Repeated schedule generated successfully.',
      action: () =>
          ref.read(availabilitySlotRepositoryProvider).autoGenerate(draft),
    );
  }

  Future<void> _toggleSlot(AvailabilitySlot slot) async {
    if (slot.isBooked || slot.isPast) return;
    final nextStatus = slot.isBlocked ? 'available' : 'blocked';
    if (nextStatus == 'blocked' && slot.isNearTerm) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => _NearTermBlockDialog(slot: slot),
      );
      if (!mounted || confirmed != true) return;
    }
    await _runAction(
      successMessage: slot.isBlocked
          ? 'Slot activated successfully.'
          : 'Slot blocked successfully.',
      action: () => ref
          .read(availabilitySlotRepositoryProvider)
          .updateStatus(slot.id, nextStatus),
    );
  }

  Future<void> _confirmCleanup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _CleanupDialog(
        hasFilters: _departmentId != null || _doctorId != null,
      ),
    );
    if (!mounted || confirmed != true) return;
    setState(() => _cleaning = true);
    try {
      final result = await ref
          .read(availabilitySlotRepositoryProvider)
          .cleanup(_filters);
      await _load(showRefresh: true);
      final message = result.deleted == 0
          ? 'No expired non-booked slots needed cleanup.'
          : '${result.deleted} expired non-booked slot(s) removed. ${result.matched} matched after checking ${result.checked} slot(s).';
      _showStatus(message, isSuccess: true);
    } catch (error) {
      _showStatus(error.toString(), isSuccess: false);
    } finally {
      if (mounted) setState(() => _cleaning = false);
    }
  }

  Future<void> _runAction({
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    setState(() => _saving = true);
    try {
      await action();
      await _load(showRefresh: true);
      _showStatus(successMessage, isSuccess: true);
    } catch (error) {
      _showStatus(error.toString(), isSuccess: false);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showStatus(String message, {required bool isSuccess}) {
    _statusTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _statusMessage = message;
      _statusIsSuccess = isSuccess;
    });
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _statusMessage = null);
    });
  }

  List<AvailabilitySlot> _visibleSlots(List<AvailabilitySlot> slots) {
    return switch (_view) {
      _SlotView.upcoming => slots.where((slot) => !slot.isPast).toList(),
      _SlotView.past => slots.where((slot) => slot.isPast).toList(),
      _SlotView.all => slots,
    };
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final slots = data == null
        ? <AvailabilitySlot>[]
        : _visibleSlots(data.slots);
    final canCreate =
        _activeDepartments.isNotEmpty && _activeDoctors.isNotEmpty && !_saving;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('Manage Availability Slots')),
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
            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 100),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _primaryBlue,
                      backgroundColor: _progressTrack,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _HeaderCard(),
                  const SizedBox(height: 14),
                  if (_statusMessage != null) ...[
                    _StatusBanner(
                      message: _statusMessage!,
                      isSuccess: _statusIsSuccess,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _CleanupCard(
                    isCleaning: _cleaning,
                    onCleanup: _confirmCleanup,
                  ),
                  const SizedBox(height: 18),
                  _FiltersCard(
                    departments: data?.departments ?? const [],
                    doctors: data?.doctors ?? const [],
                    departmentId: _departmentId,
                    doctorId: _doctorId,
                    selectedDate: _selectedDate,
                    view: _view,
                    allSlots: data?.slots ?? const [],
                    canCreate: canCreate,
                    onDepartmentChanged: (value) async {
                      setState(() {
                        _departmentId = value;
                        if (_doctorId != null &&
                            !_filteredDoctors.any(
                              (doctor) => doctor.userId == _doctorId,
                            )) {
                          _doctorId = null;
                        }
                      });
                      await _load(showRefresh: true);
                    },
                    onDoctorChanged: (value) async {
                      setState(() => _doctorId = value);
                      await _load(showRefresh: true);
                    },
                    onViewChanged: (value) => setState(() => _view = value),
                    onDateTap: _chooseDate,
                    onClearDate: () async {
                      setState(() => _selectedDate = null);
                      await _load(showRefresh: true);
                    },
                    onAddSlot: () => _openSingleDialog(),
                    onBulkCreate: _openBulkDialog,
                    onAutoGenerate: _openAutoDialog,
                  ),
                  const SizedBox(height: 18),
                  if (slots.isEmpty)
                    _EmptySlotsState(view: _view)
                  else
                    for (final slot in slots) ...[
                      _SlotCard(
                        slot: slot,
                        onEdit: () => _openSingleDialog(slot),
                        onToggle: () => _toggleSlot(slot),
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
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard();

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
              color: const Color(0xFFE9F9F1),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'assets/admin/availability_icon.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Availability Slots',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _darkBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Filter, create, bulk-create, edit, activate, and block time slots for patient booking.',
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

class _CleanupCard extends StatelessWidget {
  const _CleanupCard({required this.isCleaning, required this.onCleanup});

  final bool isCleaning;
  final VoidCallback onCleanup;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Data Cleanup'),
          const SizedBox(height: 8),
          Text(
            'Remove expired available or blocked slots that are more than 24 hours old. Booked slots are kept for history.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedText, height: 1.45),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: isCleaning ? null : onCleanup,
            icon: isCleaning
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cleaning_services_rounded),
            label: Text(isCleaning ? 'Cleaning Up...' : 'Delete Expired Slots'),
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
    required this.departmentId,
    required this.doctorId,
    required this.selectedDate,
    required this.view,
    required this.allSlots,
    required this.canCreate,
    required this.onDepartmentChanged,
    required this.onDoctorChanged,
    required this.onViewChanged,
    required this.onDateTap,
    required this.onClearDate,
    required this.onAddSlot,
    required this.onBulkCreate,
    required this.onAutoGenerate,
  });

  final List<Department> departments;
  final List<Doctor> doctors;
  final String? departmentId;
  final String? doctorId;
  final DateTime? selectedDate;
  final _SlotView view;
  final List<AvailabilitySlot> allSlots;
  final bool canCreate;
  final ValueChanged<String?> onDepartmentChanged;
  final ValueChanged<String?> onDoctorChanged;
  final ValueChanged<_SlotView> onViewChanged;
  final VoidCallback onDateTap;
  final VoidCallback onClearDate;
  final VoidCallback onAddSlot;
  final VoidCallback onBulkCreate;
  final VoidCallback onAutoGenerate;

  @override
  Widget build(BuildContext context) {
    final activeDepartments = departments
        .where((item) => item.isActive)
        .toList();
    final filteredDoctors = doctors
        .where((item) => item.isActive)
        .where(
          (item) => departmentId == null || item.departmentId == departmentId,
        )
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle('Filters'),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            initialValue: departmentId,
            decoration: _inputDecoration('Department'),
            items: [
              const DropdownMenuItem(
                value: null,
                child: Text('All Departments'),
              ),
              for (final department in activeDepartments)
                DropdownMenuItem(
                  value: department.name,
                  child: Text(department.name),
                ),
            ],
            onChanged: onDepartmentChanged,
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String?>(
            initialValue: doctorId,
            decoration: _inputDecoration('Doctor'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Doctors')),
              for (final doctor in filteredDoctors)
                DropdownMenuItem(
                  value: doctor.userId,
                  child: Text(doctor.fullName),
                ),
            ],
            onChanged: onDoctorChanged,
          ),
          const SizedBox(height: 14),
          _ViewRail(view: view, slots: allSlots, onChanged: onViewChanged),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDateTap,
                  icon: const Icon(Icons.calendar_month_rounded),
                  label: Text(
                    selectedDate == null
                        ? 'Filter by Date'
                        : _friendlyDate(selectedDate!),
                  ),
                ),
              ),
              if (selectedDate != null) ...[
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  tooltip: 'Clear date filter',
                  onPressed: onClearDate,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  onPressed: canCreate ? onAddSlot : null,
                  icon: const Icon(Icons.alarm_add_rounded),
                  label: const Text('Add Slot'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: canCreate ? onBulkCreate : null,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('Bulk Create'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: canCreate ? onAutoGenerate : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Auto Generate'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewRail extends StatelessWidget {
  const _ViewRail({
    required this.view,
    required this.slots,
    required this.onChanged,
  });

  final _SlotView view;
  final List<AvailabilitySlot> slots;
  final ValueChanged<_SlotView> onChanged;

  @override
  Widget build(BuildContext context) {
    final upcoming = slots.where((slot) => !slot.isPast).length;
    final past = slots.where((slot) => slot.isPast).length;
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: _progressTrack,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          _RailChip(
            label: 'Upcoming ($upcoming)',
            selected: view == _SlotView.upcoming,
            onTap: () => onChanged(_SlotView.upcoming),
          ),
          _RailChip(
            label: 'Past ($past)',
            selected: view == _SlotView.past,
            onTap: () => onChanged(_SlotView.past),
          ),
          _RailChip(
            label: 'All (${slots.length})',
            selected: view == _SlotView.all,
            onTap: () => onChanged(_SlotView.all),
          ),
        ],
      ),
    );
  }
}

class _RailChip extends StatelessWidget {
  const _RailChip({
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
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
            ).copyWith(color: selected ? _darkBlue : _mutedText),
          ),
        ),
      ),
    );
  }
}

class _SlotCard extends StatelessWidget {
  const _SlotCard({
    required this.slot,
    required this.onEdit,
    required this.onToggle,
  });

  final AvailabilitySlot slot;
  final VoidCallback onEdit;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final locked = slot.isBooked || slot.isPast;
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
                  '${_time(slot.startAt)} - ${_time(slot.endAt)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _darkBlue,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _StatusPill(status: slot.status),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _friendlyDate(slot.startAt),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: _mainText,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          _MetaLine('Department: ${slot.departmentName}'),
          _MetaLine('Doctor: ${slot.doctorName}'),
          if (slot.isBooked) ...[
            const SizedBox(height: 8),
            const Text(
              'Booked slots are locked to protect existing appointments.',
              style: TextStyle(
                color: _bookedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (slot.isPast && !slot.isBooked) ...[
            const SizedBox(height: 8),
            const Text(
              'This slot is in the past and is shown for reference only.',
              style: TextStyle(
                color: _mutedText,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Edit',
                  onPressed: locked ? null : onEdit,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: slot.isBlocked ? 'Activate' : 'Block',
                  onPressed: locked ? null : onToggle,
                  background: slot.isBlocked ? _successBg : _cautionBg,
                  border: slot.isBlocked ? _positiveBorder : _cautionBorder,
                  foreground: slot.isBlocked ? _successText : _errorText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SingleSlotDialog extends StatefulWidget {
  const _SingleSlotDialog({
    required this.departments,
    required this.doctors,
    this.slot,
  });

  final List<Department> departments;
  final List<Doctor> doctors;
  final AvailabilitySlot? slot;

  @override
  State<_SingleSlotDialog> createState() => _SingleSlotDialogState();
}

class _SingleSlotDialogState extends State<_SingleSlotDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _departmentId =
      widget.slot?.departmentId ?? _firstDepartmentName(widget.departments);
  late String? _doctorId = widget.slot?.doctorId;
  late DateTime? _date = widget.slot?.startAt;
  late String? _start = widget.slot == null
      ? null
      : _time(widget.slot!.startAt);
  late String? _end = widget.slot == null ? null : _time(widget.slot!.endAt);
  late String _status = widget.slot?.status == 'blocked'
      ? 'blocked'
      : 'available';

  List<Doctor> get _doctors => widget.doctors
      .where((doctor) => doctor.isActive)
      .where(
        (doctor) =>
            _departmentId == null || doctor.departmentId == _departmentId,
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _doctorId ??= _firstDoctorId(_doctors);
  }

  @override
  Widget build(BuildContext context) {
    final times = _timeOptions(_date);
    final endTimes = times
        .where((item) => _start == null || _minutes(item) > _minutes(_start!))
        .toList();
    return _SlotDialogShell(
      title: widget.slot == null ? 'Create Slot' : 'Edit Slot',
      subtitle:
          'Choose the department, doctor, date, time range, and slot status.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _DialogSection(
              title: 'Assignment',
              description:
                  'Choose which department and doctor this slot belongs to.',
              children: [
                _DepartmentField(
                  value: _departmentId,
                  departments: widget.departments,
                  onChanged: (value) {
                    setState(() {
                      _departmentId = value;
                      _doctorId = _firstDoctorId(_doctors);
                    });
                  },
                ),
                const SizedBox(height: 14),
                _DoctorField(
                  value: _doctorId,
                  doctors: _doctors,
                  onChanged: (value) => setState(() => _doctorId = value),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DialogSection(
              title: 'Schedule',
              description: 'Pick the date and exact time range for this slot.',
              children: [
                _DateField(
                  value: _date,
                  onPicked: (value) => setState(() => _date = value),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _start,
                  decoration: _inputDecoration('Start Time'),
                  items: [
                    for (final time in times)
                      DropdownMenuItem(value: time, child: Text(time)),
                  ],
                  onChanged: (value) => setState(() {
                    _start = value;
                    if (_end != null &&
                        value != null &&
                        _minutes(_end!) <= _minutes(value)) {
                      _end = null;
                    }
                  }),
                  validator: (value) =>
                      value == null ? 'Select a start time.' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _end,
                  decoration: _inputDecoration('End Time'),
                  items: [
                    for (final time in endTimes)
                      DropdownMenuItem(value: time, child: Text(time)),
                  ],
                  onChanged: (value) => setState(() => _end = value),
                  validator: (value) =>
                      value == null ? 'Select an end time.' : null,
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DialogSection(
              title: 'Availability Status',
              description:
                  'Choose whether patients can book this slot immediately.',
              children: [
                _StatusField(
                  value: _status,
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'available'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DialogActions(
              primaryLabel: widget.slot == null
                  ? 'Create Slot'
                  : 'Save Changes',
              onSubmit: _submit,
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final date = _date;
    final start = _start;
    final end = _end;
    if (date == null || start == null || end == null) return;
    if (_isToday(date) && _minutes(start) < _nextHalfHourMinutes()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Past times cannot be used for today. Please choose a future time.',
          ),
        ),
      );
      return;
    }
    if (_minutes(end) <= _minutes(start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End time must be later than start time.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      SlotDraft(
        departmentId: _departmentId!,
        doctorId: _doctorId!,
        date: date,
        startTime: start,
        endTime: end,
        status: _status,
      ),
    );
  }

}

class _BulkSlotDialog extends StatefulWidget {
  const _BulkSlotDialog({required this.departments, required this.doctors});

  final List<Department> departments;
  final List<Doctor> doctors;

  @override
  State<_BulkSlotDialog> createState() => _BulkSlotDialogState();
}

class _BulkSlotDialogState extends State<_BulkSlotDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _departmentId = _firstDepartmentName(widget.departments);
  String? _doctorId;
  DateTime? _date;
  String _status = 'available';
  String? _error;
  final List<_EditableRange> _ranges = [
    _EditableRange('09:00', '10:00'),
    _EditableRange('10:00', '11:00'),
    _EditableRange('13:00', '14:00'),
  ];

  List<Doctor> get _doctors => widget.doctors
      .where((doctor) => doctor.isActive)
      .where(
        (doctor) =>
            _departmentId == null || doctor.departmentId == _departmentId,
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _doctorId = _firstDoctorId(_doctors);
  }

  @override
  Widget build(BuildContext context) {
    final times = _timeOptions(_date);
    return _SlotDialogShell(
      title: 'Bulk Create Slots',
      subtitle: 'Add multiple time ranges at once, using one line per slot.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _DialogSection(
              title: 'Assignment',
              description:
                  'Choose where these slots belong before generating them.',
              children: [
                _DepartmentField(
                  value: _departmentId,
                  departments: widget.departments,
                  onChanged: (value) {
                    setState(() {
                      _departmentId = value;
                      _doctorId = _firstDoctorId(_doctors);
                    });
                  },
                ),
                const SizedBox(height: 14),
                _DoctorField(
                  value: _doctorId,
                  doctors: _doctors,
                  onChanged: (value) => setState(() => _doctorId = value),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DialogSection(
              title: 'Bulk Slot Setup',
              description:
                  'Choose the date, default status, and slot times to create.',
              children: [
                _DateField(
                  value: _date,
                  onPicked: (value) => setState(() {
                    _date = value;
                    _normalizeRangesForDate(value);
                  }),
                ),
                const SizedBox(height: 14),
                _StatusField(
                  value: _status,
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'available'),
                ),
                const SizedBox(height: 14),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Time Ranges',
                    style: TextStyle(
                      color: _darkBlue,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                for (var i = 0; i < _ranges.length; i++) ...[
                  _RangeRow(
                    range: _ranges[i],
                    times: times,
                    canRemove: _ranges.length > 1,
                    onChanged: () => setState(() {}),
                    onRemove: () => setState(() => _ranges.removeAt(i)),
                  ),
                  const SizedBox(height: 10),
                ],
                OutlinedButton.icon(
                  onPressed: () => setState(() {
                    final previousEnd = _ranges.last.end;
                    final nextEnd = _nextTime(previousEnd);
                    _ranges.add(_EditableRange(previousEnd, nextEnd));
                  }),
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Add Another Time Range'),
                ),
                const SizedBox(height: 10),
                Text(
                  _error ??
                      'Pick the start and end time for each slot you want to create.',
                  style: TextStyle(
                    color: _error == null
                        ? _mutedText
                        : const Color(0xFFD92D20),
                    fontSize: 12,
                    fontWeight: _error == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DialogActions(primaryLabel: 'Create Slots', onSubmit: _submit),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final error = _bulkError(_ranges, _date);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(
      BulkSlotDraft(
        departmentId: _departmentId!,
        doctorId: _doctorId!,
        date: _date!,
        status: _status,
        ranges: _ranges
            .map(
              (item) =>
                  TimeRangeDraft(startTime: item.start!, endTime: item.end!),
            )
            .toList(),
      ),
    );
  }

  void _normalizeRangesForDate(DateTime? date) {
    final times = _timeOptions(date);
    for (final range in _ranges) {
      if (range.start != null && !times.contains(range.start)) {
        range.start = null;
        range.end = null;
        continue;
      }

      final endTimes = times
          .where(
            (item) =>
                range.start == null || _minutes(item) > _minutes(range.start!),
          )
          .toList();
      if (range.end != null && !endTimes.contains(range.end)) {
        range.end = null;
      }
    }
  }
}

class _AutoGenerateDialog extends StatefulWidget {
  const _AutoGenerateDialog({required this.departments, required this.doctors});

  final List<Department> departments;
  final List<Doctor> doctors;

  @override
  State<_AutoGenerateDialog> createState() => _AutoGenerateDialogState();
}

class _AutoGenerateDialogState extends State<_AutoGenerateDialog> {
  final _formKey = GlobalKey<FormState>();
  late String? _departmentId = _firstDepartmentName(widget.departments);
  String? _doctorId;
  DateTime? _startDate;
  DateTime? _endDate;
  final Set<int> _weekdays = {0, 2, 4};
  String _start = '09:00';
  String _end = '17:00';
  int _duration = 30;
  String _status = 'available';

  List<Doctor> get _doctors => widget.doctors
      .where((doctor) => doctor.isActive)
      .where(
        (doctor) =>
            _departmentId == null || doctor.departmentId == _departmentId,
      )
      .toList();

  @override
  void initState() {
    super.initState();
    _doctorId = _firstDoctorId(_doctors);
  }

  @override
  Widget build(BuildContext context) {
    final times = _timeOptions(null);
    final endTimes = times
        .where((item) => _minutes(item) > _minutes(_start))
        .toList();
    return _SlotDialogShell(
      title: 'Auto Generate Slots',
      subtitle:
          'Build a repeated doctor schedule across selected weekdays and a date range.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            _DialogSection(
              title: 'Assignment',
              description:
                  'Choose the department and doctor for this repeated schedule.',
              children: [
                _DepartmentField(
                  value: _departmentId,
                  departments: widget.departments,
                  onChanged: (value) {
                    setState(() {
                      _departmentId = value;
                      _doctorId = _firstDoctorId(_doctors);
                    });
                  },
                ),
                const SizedBox(height: 14),
                _DoctorField(
                  value: _doctorId,
                  doctors: _doctors,
                  onChanged: (value) => setState(() => _doctorId = value),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DialogSection(
              title: 'Date Range',
              description:
                  'Choose the window where this pattern should be applied.',
              children: [
                _DateField(
                  label: 'Start Date',
                  value: _startDate,
                  onPicked: (value) => setState(() => _startDate = value),
                ),
                const SizedBox(height: 14),
                _DateField(
                  label: 'End Date',
                  value: _endDate,
                  onPicked: (value) => setState(() => _endDate = value),
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DialogSection(
              title: 'Repeat On',
              description:
                  'Pick the weekdays that should receive generated slots.',
              children: [
                Wrap(
                  spacing: 8,
                  children: [
                    for (final item in const [
                      'Mon',
                      'Tue',
                      'Wed',
                      'Thu',
                      'Fri',
                      'Sat',
                      'Sun',
                    ])
                      FilterChip(
                        label: Text(item),
                        selected: _weekdays.contains(
                          const [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ].indexOf(item),
                        ),
                        onSelected: (selected) {
                          final index = const [
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                            'Sun',
                          ].indexOf(item);
                          setState(
                            () => selected
                                ? _weekdays.add(index)
                                : _weekdays.remove(index),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 18),
            _DialogSection(
              title: 'Daily Time Window',
              description:
                  'Choose the working hours and slot length to split automatically.',
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _start,
                  decoration: _inputDecoration('Start Time'),
                  items: [
                    for (final item in times)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (value) => setState(() {
                    _start = value ?? _start;
                    if (_minutes(_end) <= _minutes(_start)) {
                      _end = _nextTime(_start);
                    }
                  }),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _end,
                  decoration: _inputDecoration('End Time'),
                  items: [
                    for (final item in endTimes)
                      DropdownMenuItem(value: item, child: Text(item)),
                  ],
                  onChanged: (value) => setState(() => _end = value ?? _end),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<int>(
                  initialValue: _duration,
                  decoration: _inputDecoration('Slot Duration'),
                  items: const [
                    DropdownMenuItem(value: 30, child: Text('30 minutes')),
                    DropdownMenuItem(value: 45, child: Text('45 minutes')),
                    DropdownMenuItem(value: 60, child: Text('60 minutes')),
                    DropdownMenuItem(value: 90, child: Text('90 minutes')),
                    DropdownMenuItem(value: 120, child: Text('120 minutes')),
                  ],
                  onChanged: (value) => setState(() => _duration = value ?? 30),
                ),
                const SizedBox(height: 14),
                _StatusField(
                  value: _status,
                  onChanged: (value) =>
                      setState(() => _status = value ?? 'available'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _DialogActions(primaryLabel: 'Generate Slots', onSubmit: _submit),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    if (_weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select at least one weekday.')),
      );
      return;
    }
    if (_startDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select a start date.')));
      return;
    }
    if (_endDate == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Select an end date.')));
      return;
    }
    if (_endDate!.isBefore(_startDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('End date must be on or after start date.'),
        ),
      );
      return;
    }
    Navigator.of(context).pop(
      AutoGenerateDraft(
        departmentId: _departmentId!,
        doctorId: _doctorId!,
        startDate: _startDate!,
        endDate: _endDate!,
        weekdays: _weekdays.toList(),
        startTime: _start,
        endTime: _end,
        slotDurationMinutes: _duration,
        status: _status,
      ),
    );
  }
}

class _SlotDialogShell extends StatelessWidget {
  const _SlotDialogShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: const Color(0xFFF8FCFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: _darkBlue,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: _mutedText,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _DialogSection extends StatelessWidget {
  const _DialogSection({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(title),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedText, height: 1.45),
          ),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }
}

class _DepartmentField extends StatelessWidget {
  const _DepartmentField({
    required this.value,
    required this.departments,
    required this.onChanged,
  });

  final String? value;
  final List<Department> departments;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _inputDecoration('Department'),
      items: [
        for (final item in departments)
          DropdownMenuItem(value: item.name, child: Text(item.name)),
      ],
      onChanged: onChanged,
      validator: (value) =>
          value == null || value.isEmpty ? 'Select a department.' : null,
    );
  }
}

class _DoctorField extends StatelessWidget {
  const _DoctorField({
    required this.value,
    required this.doctors,
    required this.onChanged,
  });

  final String? value;
  final List<Doctor> doctors;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: doctors.any((doctor) => doctor.userId == value)
          ? value
          : null,
      decoration: _inputDecoration('Doctor'),
      items: [
        for (final item in doctors)
          DropdownMenuItem(value: item.userId, child: Text(item.fullName)),
      ],
      onChanged: onChanged,
      validator: (value) =>
          value == null || value.isEmpty ? 'Select a doctor.' : null,
    );
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.value,
    required this.onPicked,
    this.label = 'Date',
  });

  final DateTime? value;
  final String label;
  final ValueChanged<DateTime> onPicked;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      readOnly: true,
      controller: TextEditingController(
        text: value == null ? '' : _friendlyDate(value!),
      ),
      decoration: _inputDecoration(
        label,
      ).copyWith(suffixIcon: const Icon(Icons.calendar_month_rounded)),
      onTap: () async {
        final now = DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? now,
          firstDate: DateTime(now.year, now.month, now.day),
          lastDate: now.add(const Duration(days: 365)),
        );
        if (picked != null) onPicked(picked);
      },
      validator: (_) => value == null ? 'Select a date.' : null,
    );
  }
}

class _StatusField extends StatelessWidget {
  const _StatusField({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: _inputDecoration('Status'),
      items: const [
        DropdownMenuItem(value: 'available', child: Text('Available')),
        DropdownMenuItem(value: 'blocked', child: Text('Blocked')),
      ],
      onChanged: onChanged,
    );
  }
}

class _RangeRow extends StatelessWidget {
  const _RangeRow({
    required this.range,
    required this.times,
    required this.canRemove,
    required this.onChanged,
    required this.onRemove,
  });

  final _EditableRange range;
  final List<String> times;
  final bool canRemove;
  final VoidCallback onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final start = times.contains(range.start) ? range.start : null;
    final endTimes = times
        .where(
          (item) =>
              start == null || _minutes(item) > _minutes(start),
        )
        .toList();
    final end = endTimes.contains(range.end) ? range.end : null;
    return Row(
      children: [
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: start,
            decoration: _inputDecoration('Start'),
            items: [
              for (final item in times)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) {
              range.start = value;
              if (range.end != null &&
                  value != null &&
                  _minutes(range.end!) <= _minutes(value)) {
                range.end = null;
              }
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            initialValue: end,
            decoration: _inputDecoration('End'),
            items: [
              for (final item in endTimes)
                DropdownMenuItem(value: item, child: Text(item)),
            ],
            onChanged: (value) {
              range.end = value;
              onChanged();
            },
          ),
        ),
        const SizedBox(width: 10),
        IconButton.filledTonal(
          onPressed: canRemove ? onRemove : null,
          icon: const Icon(Icons.delete_outline_rounded),
        ),
      ],
    );
  }
}

class _EditableRange {
  _EditableRange(this.start, this.end);
  String? start;
  String? end;
}

class _DialogActions extends StatelessWidget {
  const _DialogActions({required this.primaryLabel, required this.onSubmit});

  final String primaryLabel;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Wrap(
        spacing: 12,
        runSpacing: 10,
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(onPressed: onSubmit, child: Text(primaryLabel)),
        ],
      ),
    );
  }
}

class _CleanupDialog extends StatelessWidget {
  const _CleanupDialog({required this.hasFilters});

  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Clean Up Old Slots?'),
      content: Text(
        'This will permanently remove expired available or blocked slots that ended more than 24 hours ago${hasFilters ? ' for the current filters' : ''}. Booked slots will be kept.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep Slots'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _errorText),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete Expired Slots'),
        ),
      ],
    );
  }
}

class _NearTermBlockDialog extends StatelessWidget {
  const _NearTermBlockDialog({required this.slot});

  final AvailabilitySlot slot;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Block Near-Term Slot?'),
      content: Text(
        'This slot is scheduled for ${_friendlyDate(slot.startAt)} at ${_time(slot.startAt)}. Blocking a near-term slot can affect current hospital operations if staff are already expecting it.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep Available'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: _errorText),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Block Slot'),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final colors = switch (status) {
      'available' => (_successBg, _successText),
      'blocked' => (_errorBg, _errorText),
      'booked' => (_bookedBg, _bookedText),
      _ => (const Color(0xFFE8EEF8), _darkBlue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: colors.$2,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    this.background = Colors.white,
    this.border = _softBorder,
    this.foreground = _darkBlue,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        backgroundColor: background,
        foregroundColor: foreground,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
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
      width: double.infinity,
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

class _EmptySlotsState extends StatelessWidget {
  const _EmptySlotsState({required this.view});

  final _SlotView view;

  @override
  Widget build(BuildContext context) {
    final helper = switch (view) {
      _SlotView.upcoming =>
        'There are no upcoming slots matching the current filters.',
      _SlotView.past => 'There are no past slots matching the current filters.',
      _SlotView.all =>
        'Create new availability slots or relax the current filters.',
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.schedule_rounded, size: 42, color: _primaryBlue),
          const SizedBox(height: 12),
          Text(
            'No slots found',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _darkBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            helper,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedText),
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
              size: 42,
              color: _errorText,
            ),
            const SizedBox(height: 14),
            Text(
              message.isEmpty
                  ? 'We could not load availability slots right now.'
                  : message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _mutedText),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: _darkBlue,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MetaLine extends StatelessWidget {
  const _MetaLine(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        text,
        style: const TextStyle(color: _mutedText, fontSize: 12),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _softBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _errorText),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: _errorText, width: 1.5),
    ),
  );
}

BoxDecoration _cardDecoration() {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(24),
    boxShadow: const [
      BoxShadow(color: Color(0x12000000), blurRadius: 16, offset: Offset(0, 8)),
    ],
  );
}

List<String> _timeOptions(DateTime? date) {
  final start = _isToday(date) ? _nextHalfHourMinutes() : 0;
  return [
    for (var minutes = start; minutes <= 1410; minutes += 30)
      '${(minutes ~/ 60).toString().padLeft(2, '0')}:${(minutes % 60).toString().padLeft(2, '0')}',
  ];
}

int _minutes(String value) {
  final parts = value.split(':');
  return int.parse(parts[0]) * 60 + int.parse(parts[1]);
}

int _nextHalfHourMinutes() {
  final now = DateTime.now();
  final total = now.hour * 60 + now.minute;
  return ((total + 29) ~/ 30) * 30;
}

bool _isToday(DateTime? date) {
  if (date == null) return false;
  final now = DateTime.now();
  return date.year == now.year &&
      date.month == now.month &&
      date.day == now.day;
}

String _nextTime(String? value) {
  final base = value == null ? 540 : _minutes(value);
  final next = (base + 30).clamp(30, 1439).toInt();
  return '${(next ~/ 60).toString().padLeft(2, '0')}:${(next % 60).toString().padLeft(2, '0')}';
}

String? _bulkError(List<_EditableRange> ranges, DateTime? date) {
  if (ranges.isEmpty) return 'Add at least one time range.';
  if (ranges.any((range) => range.start == null || range.end == null)) {
    return 'Select both start and end time for every row.';
  }
  if (ranges.any((range) => _minutes(range.end!) <= _minutes(range.start!))) {
    return 'Each end time must be later than its start time.';
  }
  final keys = ranges.map((range) => '${range.start}-${range.end}').toSet();
  if (keys.length != ranges.length) {
    return 'Remove duplicate time ranges before continuing.';
  }
  if (_isToday(date) &&
      ranges.any((range) => _minutes(range.start!) < _nextHalfHourMinutes())) {
    return 'Past time ranges cannot be created for today. Choose future times only.';
  }
  return null;
}

String? _firstDepartmentName(List<Department> departments) {
  return departments.isEmpty ? null : departments.first.name;
}

String? _firstDoctorId(List<Doctor> doctors) {
  return doctors.isEmpty ? null : doctors.first.userId;
}

String _time(DateTime value) {
  return '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
}

String _friendlyDate(DateTime value) {
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
  return '${months[value.month - 1]} ${value.day}, ${value.year}';
}
