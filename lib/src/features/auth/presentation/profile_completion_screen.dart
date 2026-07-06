import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_ui.dart';
import '../application/app_session_provider.dart';
import '../data/auth_repository.dart';
import '../domain/auth_flow_exception.dart';

class ProfileCompletionScreen extends ConsumerStatefulWidget {
  const ProfileCompletionScreen({super.key});

  @override
  ConsumerState<ProfileCompletionScreen> createState() => _ProfileCompletionScreenState();
}

class _ProfileCompletionScreenState extends ConsumerState<ProfileCompletionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isSubmitting = false;
  String _selectedGender = 'Male';
  String? _error;

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final session = await ref.read(authRepositoryProvider).completePatientProfile(
            fullName: _fullNameController.text.trim(),
            phoneNumber: _phoneController.text.trim(),
            gender: _selectedGender,
            address: _addressController.text.trim(),
            dateOfBirth: _dobController.text.trim(),
          );
      ref.read(appSessionOverrideProvider.notifier).state = session;
      if (mounted) {
        context.go('/');
      }
    } on AuthFlowException catch (error) {
      setState(() => _error = error.message);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final keyboardInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: AuthBackground(
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: keyboardInset),
          child: AuthShell(
            maxWidth: 540,
            padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
            scrollable: true,
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  const AuthLogoMark(size: 78, padding: EdgeInsets.all(16)),
                  const SizedBox(height: 18),
                  Text(
                    'Complete your patient profile',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AuthColors.navy,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Your account is ready, but we still need a few details before opening your dashboard.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AuthColors.textMuted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xF7FFFFFF),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: AuthColors.border),
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          controller: _fullNameController,
                          decoration: authInputDecoration(
                            label: 'Full name',
                            icon: Icons.person_outline_rounded,
                            hint: 'Enter your full name',
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter your full name'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          decoration: authInputDecoration(
                            label: 'Phone number',
                            icon: Icons.phone_outlined,
                            hint: 'Enter your phone number',
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter your phone number'
                              : null,
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Gender',
                          style: TextStyle(
                            color: AuthColors.navy,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Female',
                                label: Text('Female'),
                                icon: Icon(Icons.woman_2_outlined),
                              ),
                              ButtonSegment(
                                value: 'Male',
                                label: Text('Male'),
                                icon: Icon(Icons.man_2_outlined),
                              ),
                            ],
                            selected: {_selectedGender},
                            onSelectionChanged: (value) {
                              setState(() => _selectedGender = value.first);
                            },
                            style: ButtonStyle(
                              backgroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AuthColors.blueSoft;
                                }
                                return Colors.white;
                              }),
                              foregroundColor: WidgetStateProperty.resolveWith((states) {
                                if (states.contains(WidgetState.selected)) {
                                  return AuthColors.blue;
                                }
                                return AuthColors.textMuted;
                              }),
                              side: const WidgetStatePropertyAll(
                                BorderSide(color: AuthColors.border),
                              ),
                              shape: WidgetStatePropertyAll(
                                RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              padding: const WidgetStatePropertyAll(
                                EdgeInsets.symmetric(vertical: 14),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _addressController,
                          decoration: authInputDecoration(
                            label: 'Address',
                            icon: Icons.location_on_outlined,
                            hint: 'Enter your address',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty ? 'Enter your address' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _dobController,
                          decoration: authInputDecoration(
                            label: 'Date of birth (optional)',
                            icon: Icons.calendar_month_outlined,
                            hint: 'YYYY-MM-DD',
                          ),
                        ),
                        const SizedBox(height: 18),
                        if (_error != null) ...[
                          AuthErrorBanner(_error!),
                          const SizedBox(height: 18),
                        ],
                        SizedBox(
                          width: double.infinity,
                          height: 58,
                          child: FilledButton(
                            onPressed: _isSubmitting ? null : _submit,
                            style: FilledButton.styleFrom(
                              backgroundColor: AuthColors.button,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Text(_isSubmitting ? 'Saving...' : 'Save profile'),
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
