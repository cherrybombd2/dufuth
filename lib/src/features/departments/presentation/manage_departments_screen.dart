import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/department_repository.dart';
import '../domain/department.dart';

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
const _deactivateBg = Color(0xFFFFF0F0);
const _deactivateBorder = Color(0xFFFDB0AC);
const _activateBorder = Color(0xFFA6F4C5);

class ManageDepartmentsScreen extends ConsumerStatefulWidget {
  const ManageDepartmentsScreen({super.key});

  @override
  ConsumerState<ManageDepartmentsScreen> createState() =>
      _ManageDepartmentsScreenState();
}

class _ManageDepartmentsScreenState
    extends ConsumerState<ManageDepartmentsScreen> {
  List<Department>? _departments;
  String? _loadError;
  String? _statusMessage;
  bool _statusIsSuccess = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(departmentRepositoryProvider).cachedDepartments;
    _departments = cached;
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
      _loading = _departments == null;
    });

    try {
      final departments = await ref.read(departmentRepositoryProvider).fetch();
      if (!mounted) return;
      setState(() => _departments = departments);
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
    final draft = await showDialog<DepartmentDraft>(
      context: context,
      builder: (context) => const _DepartmentEditorDialog(),
    );
    if (!mounted || draft == null) return;
    await _runAction(
      successMessage: 'Department created successfully.',
      action: () => ref.read(departmentRepositoryProvider).create(draft),
    );
  }

  Future<void> _openEditDialog(Department department) async {
    final draft = await showDialog<DepartmentDraft>(
      context: context,
      builder: (context) => _DepartmentEditorDialog(department: department),
    );
    if (!mounted || draft == null) return;
    await _runAction(
      successMessage: 'Department updated successfully.',
      action: () =>
          ref.read(departmentRepositoryProvider).update(department.name, draft),
    );
  }

  Future<void> _handleActivateToggle(Department department) async {
    if (!department.isActive) {
      await _runAction(
        successMessage: 'Department activated successfully.',
        action: () => ref
            .read(departmentRepositoryProvider)
            .setActive(department.name, true),
      );
      return;
    }

    final decision = await showDialog<_DeactivateDecision>(
      context: context,
      builder: (context) => _DeactivateDepartmentDialog(department: department),
    );
    if (!mounted || decision == null) return;

    if (decision == _DeactivateDecision.deactivate) {
      await _runAction(
        successMessage: 'Department deactivated successfully.',
        action: () => ref
            .read(departmentRepositoryProvider)
            .setActive(department.name, false),
      );
      return;
    }

    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteDepartmentDialog(department: department),
    );
    if (!mounted || shouldDelete != true) return;

    await _runAction(
      successMessage: 'Department deleted successfully.',
      action: () =>
          ref.read(departmentRepositoryProvider).delete(department.name),
    );
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
          ? 'We could not complete that department action right now.'
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
    final departments = _departments;

    return Scaffold(
      backgroundColor: _pageBg,
      appBar: AppBar(title: const Text('Manage Departments')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saving ? null : _openCreateDialog,
        backgroundColor: _primaryBlue,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Department'),
      ),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (_loading && departments == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_loadError != null && departments == null) {
              return _FullErrorState(
                message: _loadError!,
                onRetry: () => _load(),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 90),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: _primaryBlue,
                      backgroundColor: _progressTrack,
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _DepartmentsHeaderCard(),
                  const SizedBox(height: 14),
                  if (_statusMessage != null) ...[
                    _StatusBanner(
                      message: _statusMessage!,
                      isSuccess: _statusIsSuccess,
                    ),
                    const SizedBox(height: 20),
                  ] else
                    const SizedBox(height: 6),
                  if (departments == null || departments.isEmpty)
                    const _EmptyDepartmentState()
                  else
                    for (final department in departments) ...[
                      _DepartmentCard(
                        department: department,
                        onEdit: () => _openEditDialog(department),
                        onToggleActive: () => _handleActivateToggle(department),
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

class _DepartmentsHeaderCard extends StatelessWidget {
  const _DepartmentsHeaderCard();

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
            decoration: BoxDecoration(
              color: const Color(0xFFEAF2FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.apartment_rounded,
              color: _primaryBlue,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Departments',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: _darkBlue,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Create, update, activate, and deactivate hospital departments.',
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

class _DepartmentCard extends StatelessWidget {
  const _DepartmentCard({
    required this.department,
    required this.onEdit,
    required this.onToggleActive,
  });

  final Department department;
  final VoidCallback onEdit;
  final VoidCallback onToggleActive;

  @override
  Widget build(BuildContext context) {
    final description = department.description?.trim();
    final iconKey = department.iconKey?.trim();

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
                  department.name,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: _darkBlue,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _StatusBadge(active: department.isActive),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description == null || description.isEmpty
                ? 'No description added yet.'
                : description,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: _mutedText, height: 1.45),
          ),
          const SizedBox(height: 10),
          Text(
            'Icon: ${iconKey == null || iconKey.isEmpty ? 'not set' : iconKey}',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: _mutedText, fontSize: 12),
          ),
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
                  label: department.isActive ? 'Deactivate' : 'Activate',
                  onPressed: onToggleActive,
                  background: department.isActive ? _deactivateBg : _successBg,
                  border: department.isActive
                      ? _deactivateBorder
                      : _activateBorder,
                  foreground: department.isActive ? _errorText : _successText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DepartmentEditorDialog extends StatefulWidget {
  const _DepartmentEditorDialog({this.department});

  final Department? department;

  @override
  State<_DepartmentEditorDialog> createState() =>
      _DepartmentEditorDialogState();
}

class _DepartmentEditorDialogState extends State<_DepartmentEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _iconKeyController;
  late bool _isActive;

  bool get _isEditing => widget.department != null;

  @override
  void initState() {
    super.initState();
    final department = widget.department;
    _nameController = TextEditingController(text: department?.name ?? '');
    _descriptionController = TextEditingController(
      text: department?.description ?? '',
    );
    _iconKeyController = TextEditingController(text: department?.iconKey ?? '');
    _isActive = department?.isActive ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _iconKeyController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final description = _descriptionController.text.trim();
    final iconKey = _iconKeyController.text.trim();
    Navigator.of(context).pop(
      DepartmentDraft(
        name: _nameController.text.trim(),
        description: description.isEmpty ? null : description,
        iconKey: iconKey.isEmpty ? null : iconKey,
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
                    _isEditing ? 'Edit Department' : 'Create Department',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: _darkBlue,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Enter the department details below.',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _mutedText,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _DialogSection(
                    title: 'Department Details',
                    description:
                        'Basic information patients and staff will see.',
                    children: [
                      TextFormField(
                        controller: _nameController,
                        decoration: _inputDecoration('Department Name'),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter a department name.'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descriptionController,
                        maxLines: 3,
                        decoration: _inputDecoration('Description'),
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _iconKeyController,
                        decoration: _inputDecoration('Icon Key'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _DialogSection(
                    title: 'Visibility',
                    description:
                        'Control whether patients can choose this department.',
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
                          'Inactive departments will not appear to patients.',
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
                  const SizedBox(height: 20),
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
                              _isEditing ? 'Save Changes' : 'Create Department',
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

enum _DeactivateDecision { deactivate, delete }

class _DeactivateDepartmentDialog extends StatelessWidget {
  const _DeactivateDepartmentDialog({required this.department});

  final Department department;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      title: const Text('Deactivate Department?'),
      content: Text(
        '${department.name} will disappear from patient booking screens. '
        'You can deactivate it to keep its records, or delete it completely '
        'if it has no linked doctors, slots, or appointment history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Keep Active'),
        ),
        OutlinedButton(
          onPressed: () =>
              Navigator.of(context).pop(_DeactivateDecision.delete),
          style: OutlinedButton.styleFrom(
            foregroundColor: _errorText,
            side: const BorderSide(color: _deactivateBorder),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Delete'),
        ),
        FilledButton(
          onPressed: () =>
              Navigator.of(context).pop(_DeactivateDecision.deactivate),
          style: FilledButton.styleFrom(
            backgroundColor: _errorText,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: const Text('Deactivate'),
        ),
      ],
    );
  }
}

class _DeleteDepartmentDialog extends StatelessWidget {
  const _DeleteDepartmentDialog({required this.department});

  final Department department;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      title: const Text('Delete Department?'),
      content: Text(
        'Delete ${department.name} completely? This only works if it has no '
        'linked doctors, slots, or appointment history.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
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
          child: const Text('Delete'),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.active});

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

class _EmptyDepartmentState extends StatelessWidget {
  const _EmptyDepartmentState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: _cardDecoration(),
      child: Column(
        children: [
          const Icon(Icons.apartment_rounded, size: 42, color: _primaryBlue),
          const SizedBox(height: 12),
          Text(
            'No departments yet',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: _darkBlue,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first department to start building the hospital directory.',
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
                  ? 'We could not load departments right now.'
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
