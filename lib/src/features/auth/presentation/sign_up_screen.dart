import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_ui.dart';
import '../application/app_session_provider.dart';
import '../data/auth_repository.dart';
import '../domain/auth_flow_exception.dart';

class SignUpScreen extends ConsumerStatefulWidget {
  const SignUpScreen({super.key});

  @override
  ConsumerState<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends ConsumerState<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String _selectedGender = 'Male';
  String? _error;

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();
    final initialDate =
        _parseDateOfBirth(_dobController.text) ??
        DateTime(now.year - 18, now.month, now.day);
    final firstDate = DateTime(1900);
    final lastDate = now;

    final picked = await showDatePicker(
      context: context,
      initialDate: _clampDate(initialDate, firstDate, lastDate),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: 'Select date of birth',
    );

    if (picked == null || !mounted) return;
    setState(() {
      _dobController.text = _formatDateOfBirth(picked);
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  DateTime? _parseDateOfBirth(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  DateTime _clampDate(DateTime value, DateTime min, DateTime max) {
    if (value.isBefore(min)) return min;
    if (value.isAfter(max)) return max;
    return value;
  }

  String _formatDateOfBirth(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      final session = await ref.read(authRepositoryProvider).signUpPatient(
            fullName: _fullNameController.text.trim(),
            email: _emailController.text.trim(),
            password: _passwordController.text,
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

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('Create patient account'),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      extendBodyBehindAppBar: true,
      body: AuthBackground(
        child: AuthShell(
          maxWidth: 540,
          padding: const EdgeInsets.fromLTRB(24, 92, 24, 28),
          scrollable: true,
          child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const AuthLogoMark(size: 78, padding: EdgeInsets.all(16)),
                  const SizedBox(height: 18),
                  Text(
                    'Join DUFUTH SmartCare',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AuthColors.navy,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Create your patient account to book appointments, receive reminders, and stay connected with your care team.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AuthColors.textMuted,
                      height: 1.65,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 26),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xF7FFFFFF),
                      borderRadius: BorderRadius.circular(34),
                      border: Border.all(color: const Color(0x9ED7E4F4)),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x120A67D8),
                          blurRadius: 32,
                          offset: Offset(0, 18),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient registration',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            color: AuthColors.navy,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Fill in your details below to get started.',
                          style: TextStyle(color: AuthColors.textMuted),
                        ),
                        const SizedBox(height: 22),
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
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: authInputDecoration(
                            label: 'Email address',
                            icon: Icons.mail_outline_rounded,
                            hint: 'Enter your email',
                          ),
                          validator: (value) =>
                              value == null || value.trim().isEmpty ? 'Enter your email' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: authInputDecoration(
                            label: 'Phone number',
                            icon: Icons.phone_outlined,
                            hint: 'Enter your phone number',
                          ),
                          validator: (value) => value == null || value.trim().isEmpty
                              ? 'Enter your phone number'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          decoration: authInputDecoration(
                            label: 'Password',
                            icon: Icons.lock_outline_rounded,
                            hint: 'Create a password',
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: AuthColors.textMuted,
                              ),
                            ),
                          ),
                          validator: (value) =>
                              value == null || value.length < 6 ? 'Minimum 6 characters' : null,
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
                          readOnly: true,
                          onTap: _pickDateOfBirth,
                          decoration: authInputDecoration(
                            label: 'Date of birth (optional)',
                            icon: Icons.calendar_month_outlined,
                            hint: 'YYYY-MM-DD',
                            suffixIcon: IconButton(
                              onPressed: _pickDateOfBirth,
                              icon: const Icon(
                                Icons.arrow_drop_down_rounded,
                                color: AuthColors.textMuted,
                              ),
                            ),
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
                              textStyle: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            child: Text(
                              _isSubmitting ? 'Creating account...' : 'Create account',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  AuthFooterPrompt(
                    label: 'Already have an account?',
                    actionLabel: 'Log In',
                    onTap: () => context.go('/sign-in'),
                  ),
                ],
              ),
          ),
        ),
      ),
    );
  }
}
