import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../departments/domain/department.dart';
import '../data/doctor_management_repository.dart';
import '../domain/doctor.dart';

const _pageBg = Color(0xFFF4F8FF);
const _primaryBlue = Color(0xFF2C7DF7);
const _darkBlue = Color(0xFF153B74);
const _mainText = Color(0xFF183153);
const _mutedText = Color(0xFF5D6B82);
const _softBorder = Color(0xFFD6E0EE);
const _progressBg = Color(0xFFDCE8FF);
const _successBg = Color(0xFFE8FBF4);
const _successText = Color(0xFF067647);
const _errorBg = Color(0xFFFEE4E2);
const _errorText = Color(0xFFB42318);
const _cautionBg = Color(0xFFFFF0F0);
const _cautionBorder = Color(0xFFFDB0AC);
const _positiveBorder = Color(0xFFA6F4C5);
const _linkedBg = Color(0xFFF5F9FF);
const _linkedBorder = Color(0xFFD7E5FF);
const _avatarTint = Color(0xFFE8F0FF);

class ManageDoctorsScreen extends ConsumerStatefulWidget {
  const ManageDoctorsScreen({super.key});

  @override
  ConsumerState<ManageDoctorsScreen> createState() =>
      _ManageDoctorsScreenState();
}

class _ManageDoctorsScreenState extends ConsumerState<ManageDoctorsScreen> {
  DoctorManagementData? _data;
  String? _loadError;
  String? _statusMessage;
  bool _statusIsSuccess = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  Timer? _statusTimer;

  List<Department> get _activeDepartments => (_data?.departments ?? [])
      .where((department) => department.isActive)
      .toList();

  @override
  void initState() {
    super.initState();
    final cached = ref.read(doctorManagementRepositoryProvider).cachedData;
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
      final data = await ref.read(doctorManagementRepositoryProvider).fetch();
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

  Future<void> _openCreateDialog() async {
    if (_activeDepartments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Create or reactivate at least one department before adding a doctor.',
          ),
        ),
      );
      return;
    }

    final draft = await showDialog<DoctorDraft>(
      context: context,
      builder: (context) => _DoctorEditorDialog(
        departments: _activeDepartments,
        repository: ref.read(doctorManagementRepositoryProvider),
      ),
    );
    if (!mounted || draft == null) return;
    await _runAction(
      successMessage: 'Doctor created successfully.',
      action: () => ref.read(doctorManagementRepositoryProvider).create(draft),
    );
  }

  Future<void> _openEditDialog(Doctor doctor) async {
    final departments = _activeDepartments;
    final departmentMissing = !departments.any(
      (item) => item.name == doctor.departmentId,
    );
    final dialogDepartments = departmentMissing
        ? [
            Department(
              name: doctor.departmentId,
              description: 'Current inactive department',
              isActive: true,
            ),
            ...departments,
          ]
        : departments;

    final draft = await showDialog<DoctorDraft>(
      context: context,
      builder: (context) => _DoctorEditorDialog(
        doctor: doctor,
        departments: dialogDepartments,
        repository: ref.read(doctorManagementRepositoryProvider),
      ),
    );
    if (!mounted || draft == null) return;
    await _runAction(
      successMessage: 'Doctor updated successfully.',
      action: () => ref
          .read(doctorManagementRepositoryProvider)
          .update(doctor.userId, draft),
    );
  }

  Future<void> _toggleActive(Doctor doctor) async {
    if (!doctor.isActive) {
      await _runAction(
        successMessage: 'Doctor activated successfully.',
        action: () => ref
            .read(doctorManagementRepositoryProvider)
            .setActive(doctor.userId, true),
      );
      return;
    }

    await _deactivateDoctor(doctor, forceDeactivate: false);
  }

  Future<void> _deactivateDoctor(
    Doctor doctor, {
    required bool forceDeactivate,
  }) async {
    setState(() => _saving = true);
    try {
      await ref
          .read(doctorManagementRepositoryProvider)
          .setActive(doctor.userId, false, forceDeactivate: forceDeactivate);
      await _load(showRefresh: true);
      _showStatus(
        forceDeactivate
            ? 'Doctor deactivated after confirmation.'
            : 'Doctor deactivated successfully.',
        isSuccess: true,
      );
    } on DoctorManagementException catch (error) {
      if (error.statusCode == 409 && !forceDeactivate && mounted) {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) =>
              _FutureAppointmentsDialog(message: error.message),
        );
        if (!mounted) return;
        if (confirm == true) {
          await _deactivateDoctor(doctor, forceDeactivate: true);
        }
      } else {
        _showStatus(error.message, isSuccess: false);
      }
    } catch (error) {
      _showStatus(error.toString(), isSuccess: false);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
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
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _showStatus(String message, {required bool isSuccess}) {
    _statusTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _statusMessage = message.isEmpty
          ? 'We could not save doctor information right now.'
          : message;
      _statusIsSuccess = isSuccess;
    });
    _statusTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() => _statusMessage = null);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('Manage Doctors')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: data == null || _saving ? null : _openCreateDialog,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Doctor'),
      ),
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

            final doctors = data?.doctors ?? [];
            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 90),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _primaryBlue,
                      backgroundColor: _progressBg,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _DoctorsHeaderCard(),
                  const SizedBox(height: 14),
                  if (_statusMessage != null) ...[
                    _StatusBanner(
                      message: _statusMessage!,
                      isSuccess: _statusIsSuccess,
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 6),
                  if (doctors.isEmpty)
                    const _EmptyDoctorsState()
                  else
                    for (final doctor in doctors) ...[
                      _DoctorCard(
                        doctor: doctor,
                        onEdit: () => _openEditDialog(doctor),
                        onToggleActive: () => _toggleActive(doctor),
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

class _DoctorsHeaderCard extends StatelessWidget {
  const _DoctorsHeaderCard();

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
              color: const Color(0xFFFFF3E7),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Image.asset(
              'assets/admin/doctor_icon.png',
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Doctors',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _darkBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create, edit, activate, and deactivate doctors. Doctors can only belong to active departments.',
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

class _DoctorCard extends StatelessWidget {
  const _DoctorCard({
    required this.doctor,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Doctor doctor;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final specialty = doctor.specialization?.trim();
    final bio = doctor.bio?.trim();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  doctor.fullName,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _darkBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(active: doctor.isActive),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            specialty == null || specialty.isEmpty
                ? 'No specialty added yet.'
                : specialty,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedText, height: 1.45),
          ),
          const SizedBox(height: 8),
          _MetaLine('Department: ${doctor.departmentId}'),
          _MetaLine('Mode: ${_valueOrNotSet(doctor.consultationMode)}'),
          _MetaLine(
            'Experience: ${doctor.yearsOfExperience == null ? 'not set' : '${doctor.yearsOfExperience} years'}',
          ),
          _MetaLine(
            'Linked account: ${_valueOrNotSet(doctor.linkedAccountEmail ?? doctor.userId)}',
          ),
          if (bio != null && bio.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              bio,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _mutedText, height: 1.45),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  label: 'Edit',
                  onPressed: onEdit,
                  background: Colors.white,
                  border: _softBorder,
                  foreground: _darkBlue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ActionButton(
                  label: doctor.isActive ? 'Deactivate' : 'Activate',
                  onPressed: onToggleActive,
                  background: doctor.isActive ? _cautionBg : _successBg,
                  border: doctor.isActive ? _cautionBorder : _positiveBorder,
                  foreground: doctor.isActive ? _errorText : _successText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _valueOrNotSet(String? value) {
    final trimmed = value?.trim();
    return trimmed == null || trimmed.isEmpty ? 'not set' : trimmed;
  }
}

class _DoctorEditorDialog extends StatefulWidget {
  const _DoctorEditorDialog({
    required this.departments,
    required this.repository,
    this.doctor,
  });

  final List<Department> departments;
  final DoctorManagementRepository repository;
  final Doctor? doctor;

  @override
  State<_DoctorEditorDialog> createState() => _DoctorEditorDialogState();
}

class _DoctorEditorDialogState extends State<_DoctorEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _specialtyController;
  late final TextEditingController _emailLookupController;
  late final TextEditingController _bioController;
  late final TextEditingController _consultationModeController;
  late final TextEditingController _yearsController;
  String? _departmentId;
  String? _gender;
  bool _isActive = true;
  UserLookupResult? _linkedUser;
  List<UserLookupResult> _lookupResults = [];
  String? _lookupMessage;
  bool _searching = false;
  Timer? _searchDebounce;

  bool get _isEditing => widget.doctor != null;

  @override
  void initState() {
    super.initState();
    final doctor = widget.doctor;
    _departmentId = doctor?.departmentId;
    _gender = doctor?.gender;
    _isActive = doctor?.isActive ?? true;
    _fullNameController = TextEditingController(text: doctor?.fullName ?? '');
    _specialtyController = TextEditingController(
      text: doctor?.specialization ?? '',
    );
    _emailLookupController = TextEditingController(
      text: doctor?.linkedAccountEmail ?? '',
    );
    _bioController = TextEditingController(text: doctor?.bio ?? '');
    _consultationModeController = TextEditingController(
      text: doctor?.consultationMode ?? '',
    );
    _yearsController = TextEditingController(
      text: doctor?.yearsOfExperience?.toString() ?? '',
    );
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _fullNameController.dispose();
    _specialtyController.dispose();
    _emailLookupController.dispose();
    _bioController.dispose();
    _consultationModeController.dispose();
    _yearsController.dispose();
    super.dispose();
  }

  void _onLookupChanged(String value) {
    _searchDebounce?.cancel();
    final query = value.trim();
    if (_linkedUser != null && query != (_linkedUser?.email ?? '')) {
      _linkedUser = null;
    }
    if (query.isEmpty) {
      setState(() {
        _lookupResults = [];
        _lookupMessage = null;
        _searching = false;
      });
      return;
    }
    if (query.length < 3) {
      setState(() {
        _lookupResults = [];
        _lookupMessage = 'Type at least 3 characters to search for an account.';
        _searching = false;
      });
      return;
    }

    setState(() {
      _searching = true;
      _lookupMessage = null;
    });
    _searchDebounce = Timer(const Duration(milliseconds: 350), () async {
      try {
        final results = await widget.repository.searchAccounts(query);
        if (!mounted) return;
        setState(() {
          _lookupResults = results;
          _lookupMessage = results.isEmpty
              ? 'No matching app account was found for that email yet.'
              : null;
          _searching = false;
        });
      } catch (_) {
        if (!mounted) return;
        setState(() {
          _lookupResults = [];
          _lookupMessage = 'We could not search user accounts right now.';
          _searching = false;
        });
      }
    });
  }

  void _selectLinkedUser(UserLookupResult user) {
    setState(() {
      _linkedUser = user;
      _emailLookupController.text = user.email ?? '';
      _lookupResults = [];
      _lookupMessage = 'Linked account selected.';
      if ((user.fullName ?? '').trim().isNotEmpty) {
        _fullNameController.text = user.fullName!.trim();
      }
      if (user.gender == 'Female' || user.gender == 'Male') {
        _gender = user.gender;
      }
    });
  }

  void _clearLinkedUser() {
    setState(() {
      _linkedUser = null;
      _emailLookupController.clear();
      _lookupResults = [];
      _lookupMessage =
          'Doctor profile will stay unlinked until you select an app account.';
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    String? optional(TextEditingController controller) {
      final value = controller.text.trim();
      return value.isEmpty ? null : value;
    }

    Navigator.of(context).pop(
      DoctorDraft(
        userId: _linkedUser?.uid ?? widget.doctor?.userId,
        fullName: _fullNameController.text.trim(),
        departmentId: _departmentId!,
        specialization: optional(_specialtyController),
        gender: _gender!,
        bio: optional(_bioController),
        consultationMode: optional(_consultationModeController),
        yearsOfExperience: int.tryParse(_yearsController.text.trim()),
        isActive: _isActive,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: const Color(0xFFF8FCFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isEditing ? 'Edit Doctor' : 'Create Doctor',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _darkBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set up the doctor profile and link an app account if needed.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _mutedText,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DialogSection(
                    title: 'Professional Details',
                    description:
                        'Identify the doctor and assign the right department.',
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _departmentId,
                        decoration: _inputDecoration('Department'),
                        items: [
                          for (final department in widget.departments)
                            DropdownMenuItem(
                              value: department.name,
                              child: Text(department.name),
                            ),
                        ],
                        onChanged: (value) =>
                            setState(() => _departmentId = value),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Select a department.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _fullNameController,
                        decoration: _inputDecoration('Full Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the doctor name.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _specialtyController,
                        decoration: _inputDecoration('Specialty'),
                      ),
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String>(
                        initialValue: _gender,
                        decoration: _inputDecoration('Gender').copyWith(
                          helperText:
                              'Used for the doctor portal profile icon and other profile displays.',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'Female',
                            child: Text('Female'),
                          ),
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                        ],
                        onChanged: (value) => setState(() => _gender = value),
                        validator: (value) => value == null || value.isEmpty
                            ? 'Select a gender.'
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DialogSection(
                    title: 'Account Linking',
                    description:
                        'Link the doctor to an existing app account by searching with email.',
                    children: [
                      TextFormField(
                        controller: _emailLookupController,
                        keyboardType: TextInputType.emailAddress,
                        onChanged: _onLookupChanged,
                        decoration:
                            _inputDecoration(
                              'Find doctor app account by email (optional)',
                            ).copyWith(
                              helperText:
                                  'Start typing the doctor account email and tap a matching profile to link it.',
                              suffixIcon: _searching
                                  ? const Padding(
                                      padding: EdgeInsets.all(14),
                                      child: SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                    )
                                  : _emailLookupController.text.isEmpty
                                  ? null
                                  : IconButton(
                                      onPressed: _clearLinkedUser,
                                      icon: const Icon(Icons.close_rounded),
                                    ),
                            ),
                      ),
                      if (_lookupResults.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxHeight: 220),
                          child: ListView.separated(
                            shrinkWrap: true,
                            itemCount: _lookupResults.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (context, index) => _LookupResultCard(
                              user: _lookupResults[index],
                              onTap: () =>
                                  _selectLinkedUser(_lookupResults[index]),
                            ),
                          ),
                        ),
                      ],
                      if (_linkedUser != null) ...[
                        const SizedBox(height: 12),
                        _LinkedAccountCard(
                          user: _linkedUser!,
                          onClear: _clearLinkedUser,
                        ),
                      ],
                      if (_lookupMessage != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          _lookupMessage!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: _mutedText, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DialogSection(
                    title: 'Additional Details',
                    description:
                        'Optional profile information for the doctor record.',
                    children: [
                      TextFormField(
                        controller: _bioController,
                        maxLines: 3,
                        decoration: _inputDecoration('Bio'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _consultationModeController,
                        decoration: _inputDecoration('Consultation Mode'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _yearsController,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        decoration: _inputDecoration('Years of Experience'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DialogSection(
                    title: 'Visibility',
                    description:
                        'Control whether patients can book this doctor.',
                    children: [
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text(
                          'Active',
                          style: TextStyle(
                            color: _mainText,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Inactive doctors will not appear in patient booking.',
                          style: TextStyle(color: _mutedText),
                        ),
                        activeTrackColor: _primaryBlue,
                        inactiveTrackColor: _softBorder,
                        thumbColor: const WidgetStatePropertyAll(Colors.white),
                        value: _isActive,
                        onChanged: (value) => setState(() => _isActive = value),
                      ),
                    ],
                  ),
                  const SizedBox(height: 22),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 10,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: _primaryBlue,
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: const Text('Cancel'),
                        ),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: _primaryBlue,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(
                              _isEditing ? 'Save Changes' : 'Create Doctor',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LookupResultCard extends StatelessWidget {
  const _LookupResultCard({required this.user, required this.onTap});

  final UserLookupResult user;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 18,
                backgroundColor: _avatarTint,
                child: Icon(Icons.person_rounded, color: _primaryBlue),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _lookupTitle(user),
                      style: const TextStyle(
                        color: _darkBlue,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((user.email ?? '').isNotEmpty)
                      Text(
                        user.email!,
                        style: const TextStyle(color: _mutedText, fontSize: 12),
                      ),
                  ],
                ),
              ),
              Text(
                (user.role ?? 'USER').toUpperCase(),
                style: const TextStyle(
                  color: _mutedText,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LinkedAccountCard extends StatelessWidget {
  const _LinkedAccountCard({required this.user, required this.onClear});

  final UserLookupResult user;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _linkedBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _linkedBorder),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            radius: 18,
            backgroundColor: _avatarTint,
            child: Icon(Icons.check_circle_rounded, color: _primaryBlue),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (user.fullName ?? '').trim().isEmpty
                      ? 'Linked account selected'
                      : user.fullName!.trim(),
                  style: const TextStyle(
                    color: _darkBlue,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if ((user.email ?? '').isNotEmpty)
                  Text(
                    user.email!,
                    style: const TextStyle(color: _mutedText, fontSize: 12),
                  ),
                Text(
                  '${(user.role ?? 'USER').toUpperCase()} • ${(user.status ?? 'ACTIVE').toUpperCase()}',
                  style: const TextStyle(
                    color: _mutedText,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text(
                  'Selecting this account will fill the doctor name and gender automatically.',
                  style: TextStyle(color: _mutedText, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Clear linked account',
            onPressed: onClear,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}

class _FutureAppointmentsDialog extends StatelessWidget {
  const _FutureAppointmentsDialog({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      title: const Text('Deactivate Doctor With Future Appointments?'),
      content: Text(
        '$message\n\nIf you continue, patients may still have bookings attached to this doctor, so the hospital team should have an alternate plan already in place.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Keep Active'),
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
          child: const Text('Deactivate Anyway'),
        ),
      ],
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
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _darkBlue,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedText, height: 1.45),
          ),
          const SizedBox(height: 16),
          ...children,
        ],
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
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.bodySmall?.copyWith(color: _mutedText, fontSize: 12),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.onPressed,
    required this.background,
    required this.border,
    required this.foreground,
  });

  final String label;
  final VoidCallback onPressed;
  final Color background;
  final Color border;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          side: BorderSide(color: border),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
        child: Text(label),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: active ? _successBg : _errorBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'ACTIVE' : 'INACTIVE',
        style: TextStyle(
          color: active ? _successText : _errorText,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
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

class _EmptyDoctorsState extends StatelessWidget {
  const _EmptyDoctorsState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(
            Icons.medical_services_rounded,
            size: 42,
            color: _primaryBlue,
          ),
          const SizedBox(height: 12),
          Text(
            'No doctors yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _darkBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create doctor records after your departments are ready.',
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedText, height: 1.45),
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
                  ? 'We could not load doctors right now.'
                  : message,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: _mutedText, height: 1.45),
            ),
            const SizedBox(height: 14),
            FilledButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

String _lookupTitle(UserLookupResult user) {
  final name = user.fullName?.trim();
  if (name != null && name.isNotEmpty) return name;
  final email = user.email?.trim();
  if (email != null && email.isNotEmpty) return email;
  return user.uid;
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
