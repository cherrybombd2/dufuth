import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hospital_info_repository.dart';
import '../domain/hospital_info.dart';

class ManageHospitalInfoScreen extends ConsumerStatefulWidget {
  const ManageHospitalInfoScreen({super.key});

  @override
  ConsumerState<ManageHospitalInfoScreen> createState() =>
      _ManageHospitalInfoScreenState();
}

class _ManageHospitalInfoScreenState
    extends ConsumerState<ManageHospitalInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  final _hospitalNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _workingHoursController = TextEditingController();
  final _visitingHoursController = TextEditingController();
  final _websiteController = TextEditingController();
  final _aboutController = TextEditingController();
  final _patientNoticeController = TextEditingController();

  HospitalInfo? _info;
  String? _loadError;
  String? _statusMessage;
  bool _statusIsSuccess = false;
  bool _loading = true;
  bool _refreshing = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final cached = ref.read(hospitalInfoRepositoryProvider).cachedInfo;
    if (cached != null) {
      _applyInfo(cached);
      _loading = false;
    }
    _load(showRefresh: cached != null);
  }

  @override
  void dispose() {
    _hospitalNameController.dispose();
    _taglineController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _workingHoursController.dispose();
    _visitingHoursController.dispose();
    _websiteController.dispose();
    _aboutController.dispose();
    _patientNoticeController.dispose();
    super.dispose();
  }

  Future<void> _load({bool showRefresh = false}) async {
    setState(() {
      _loadError = null;
      _refreshing = showRefresh;
      _loading = _info == null;
    });

    try {
      final info = await ref.read(hospitalInfoRepositoryProvider).fetch();
      if (!mounted) return;
      setState(() => _applyInfo(info));
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _saving = true;
      _statusMessage = null;
    });

    final nextInfo = HospitalInfo(
      hospitalName: _hospitalNameController.text.trim(),
      tagline: _optional(_taglineController),
      address: _optional(_addressController),
      phone: _optional(_phoneController),
      email: _optional(_emailController),
      workingHours: _optional(_workingHoursController),
      visitingHours: _optional(_visitingHoursController),
      website: _optional(_websiteController),
      about: _optional(_aboutController),
      patientNotice: _optional(_patientNoticeController),
    );

    try {
      final saved = await ref
          .read(hospitalInfoRepositoryProvider)
          .update(nextInfo);
      if (!mounted) return;
      setState(() {
        _applyInfo(saved);
        _statusIsSuccess = true;
        _statusMessage = 'Hospital information updated successfully.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _statusIsSuccess = false;
        _statusMessage = error.toString().isEmpty
            ? 'We could not save hospital information right now.'
            : error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  void _applyInfo(HospitalInfo info) {
    _info = info;
    _hospitalNameController.text = info.hospitalName;
    _taglineController.text = info.tagline ?? '';
    _addressController.text = info.address ?? '';
    _phoneController.text = info.phone ?? '';
    _emailController.text = info.email ?? '';
    _workingHoursController.text = info.workingHours ?? '';
    _visitingHoursController.text = info.visitingHours ?? '';
    _websiteController.text = info.website ?? '';
    _aboutController.text = info.about ?? '';
    _patientNoticeController.text = info.patientNotice ?? '';
  }

  String? _optional(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F8FF),
      appBar: AppBar(title: const Text('Manage Hospital Info')),
      body: SafeArea(
        top: false,
        child: Builder(
          builder: (context) {
            if (_loading && _info == null) {
              return const Center(child: CircularProgressIndicator());
            }
            if (_loadError != null && _info == null) {
              return _AdminFullErrorState(
                message: _loadError!,
                onRetry: () => _load(),
              );
            }

            return RefreshIndicator(
              onRefresh: () => _load(showRefresh: true),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
                children: [
                  if (_refreshing) ...[
                    const LinearProgressIndicator(
                      minHeight: 3,
                      color: Color(0xFF2C7DF7),
                      backgroundColor: Color(0xFFDCE8FF),
                    ),
                    const SizedBox(height: 14),
                  ],
                  const _AdminHeaderPanel(),
                  const SizedBox(height: 14),
                  if (_statusMessage != null) ...[
                    _StatusMessageBox(
                      message: _statusMessage!,
                      isSuccess: _statusIsSuccess,
                    ),
                    const SizedBox(height: 18),
                  ],
                  _AdminFormCard(
                    formKey: _formKey,
                    hospitalNameController: _hospitalNameController,
                    taglineController: _taglineController,
                    addressController: _addressController,
                    phoneController: _phoneController,
                    emailController: _emailController,
                    workingHoursController: _workingHoursController,
                    visitingHoursController: _visitingHoursController,
                    websiteController: _websiteController,
                    aboutController: _aboutController,
                    patientNoticeController: _patientNoticeController,
                    saving: _saving,
                    onSave: _save,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _AdminHeaderPanel extends StatelessWidget {
  const _AdminHeaderPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF4FF),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Center(
              child: Image.asset(
                'assets/nav/file_icon.png',
                width: 34,
                height: 34,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hospital Information',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: const Color(0xFF153B74),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Control the public-facing hospital details shown to patients in the app.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: const Color(0xFF5D6B82),
                    height: 1.4,
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

class _StatusMessageBox extends StatelessWidget {
  const _StatusMessageBox({required this.message, required this.isSuccess});

  final String message;
  final bool isSuccess;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isSuccess ? const Color(0xFFE8FBF4) : const Color(0xFFFEE4E2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: isSuccess ? const Color(0xFF067647) : const Color(0xFFB42318),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _AdminFormCard extends StatelessWidget {
  const _AdminFormCard({
    required this.formKey,
    required this.hospitalNameController,
    required this.taglineController,
    required this.addressController,
    required this.phoneController,
    required this.emailController,
    required this.workingHoursController,
    required this.visitingHoursController,
    required this.websiteController,
    required this.aboutController,
    required this.patientNoticeController,
    required this.saving,
    required this.onSave,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController hospitalNameController;
  final TextEditingController taglineController;
  final TextEditingController addressController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController workingHoursController;
  final TextEditingController visitingHoursController;
  final TextEditingController websiteController;
  final TextEditingController aboutController;
  final TextEditingController patientNoticeController;
  final bool saving;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
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
      child: Form(
        key: formKey,
        child: Column(
          children: [
            _AdminTextField(
              controller: hospitalNameController,
              label: 'Hospital Name',
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Enter the hospital name.';
                }
                return null;
              },
            ),
            _AdminTextField(controller: taglineController, label: 'Tagline'),
            _AdminTextField(
              controller: addressController,
              label: 'Address',
              maxLines: 2,
            ),
            _AdminTextField(controller: phoneController, label: 'Phone'),
            _AdminTextField(controller: emailController, label: 'Email'),
            _AdminTextField(
              controller: workingHoursController,
              label: 'Working Hours',
            ),
            _AdminTextField(
              controller: visitingHoursController,
              label: 'Visiting Hours',
            ),
            _AdminTextField(controller: websiteController, label: 'Website'),
            _AdminTextField(
              controller: aboutController,
              label: 'About',
              maxLines: 4,
            ),
            _AdminTextField(
              controller: patientNoticeController,
              label: 'Patient Notice',
              maxLines: 3,
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: saving ? null : onSave,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2C7DF7),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  textStyle: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                child: Text(saving ? 'Saving...' : 'Save Hospital Info'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AdminTextField extends StatelessWidget {
  const _AdminTextField({
    required this.controller,
    required this.label,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: controller,
        maxLines: maxLines,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          fillColor: const Color(0xFFF8FBFF),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          labelStyle: const TextStyle(color: Color(0xFF5D6B82)),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFDCE8FF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF2C7DF7), width: 1.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB42318)),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.5),
          ),
        ),
      ),
    );
  }
}

class _AdminFullErrorState extends StatelessWidget {
  const _AdminFullErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              color: Color(0xFFB42318),
              size: 42,
            ),
            const SizedBox(height: 14),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF5D6B82),
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
