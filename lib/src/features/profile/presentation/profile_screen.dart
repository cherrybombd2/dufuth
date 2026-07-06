import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/domain/auth_flow_exception.dart';
import '../../auth/presentation/auth_ui.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({
    required this.profile,
    required this.email,
    super.key,
  });

  final SessionProfile profile;
  final String email;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _dateOfBirthController;

  late SessionProfile _profile;
  late String _email;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _message;
  bool _messageIsSuccess = false;

  @override
  void initState() {
    super.initState();
    _profile = widget.profile;
    _email = widget.email;
    _fullNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _dateOfBirthController = TextEditingController();
    _syncControllers();
  }

  @override
  void didUpdateWidget(covariant ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.profile != widget.profile || oldWidget.email != widget.email) {
      _profile = widget.profile;
      _email = widget.email;
      if (!_isEditing) {
        _syncControllers();
      }
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateOfBirthController.dispose();
    super.dispose();
  }

  void _syncControllers() {
    _fullNameController.text = _profile.fullName;
    _emailController.text = _email;
    _phoneController.text = _profile.phoneNumber ?? '';
    _dateOfBirthController.text = _profile.dateOfBirth ?? '';
  }

  void _toggleEditing() {
    if (_isSaving) return;
    setState(() {
      if (_isEditing) {
        _syncControllers();
      }
      _isEditing = !_isEditing;
      _message = null;
    });
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _message = null;
    });

    try {
      final session = await ref.read(authRepositoryProvider).updatePatientProfile(
            fullName: _fullNameController.text,
            phoneNumber: _phoneController.text,
            gender: _profile.gender,
            address: _profile.address,
            dateOfBirth: _profile.dateOfBirth,
          );
      ref.read(appSessionOverrideProvider.notifier).state = session;
      if (!mounted) return;

      setState(() {
        _profile = session.profile!;
        _email = session.user?.email ?? _email;
        _syncControllers();
        _isEditing = false;
        _message = 'Profile updated successfully.';
        _messageIsSuccess = true;
      });
    } on AuthFlowException catch (error) {
      if (!mounted) return;
      setState(() {
        _message = error.message.isEmpty
            ? 'We could not update your profile right now.'
            : error.message;
        _messageIsSuccess = false;
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: SafeArea(
        child: ListView(
          key: const PageStorageKey<String>('patient-profile-tab-view'),
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 24,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _PatientProfilePortrait(gender: _profile.gender),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Patient Profile',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                        color: const Color(0xFF153B74),
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _emailValue(_email),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                        color: const Color(0xFF5D6B82),
                                      ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _isEditing ? 'Editing enabled' : 'View only',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                        color: _isEditing
                                            ? const Color(0xFF2C7DF7)
                                            : const Color(0xFF5D6B82),
                                        fontWeight: _isEditing
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        IconButton.filledTonal(
                          onPressed: _isSaving ? null : _toggleEditing,
                          icon: Icon(
                            _isEditing ? Icons.close_rounded : Icons.edit_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    _ProfileSectionCard(
                      title: 'Personal Information',
                      description:
                          'Basic identity and contact details for your profile.',
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _fullNameController,
                            enabled: _isEditing && !_isSaving,
                            decoration: authInputDecoration(
                              label: 'Full Name',
                              icon: Icons.person_outline_rounded,
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your full name.';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _emailController,
                            enabled: false,
                            decoration: authInputDecoration(
                              label: 'Email Address',
                              icon: Icons.mail_outline_rounded,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _phoneController,
                            enabled: _isEditing && !_isSaving,
                            keyboardType: TextInputType.phone,
                            decoration: authInputDecoration(
                              label: 'Phone Number',
                              icon: Icons.call_outlined,
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _dateOfBirthController,
                            enabled: false,
                            decoration: authInputDecoration(
                              label: 'Date of Birth (YYYY-MM-DD)',
                              icon: Icons.cake_outlined,
                            ).copyWith(
                              helperText:
                                  'Date of birth can only be set during signup.',
                              helperStyle: const TextStyle(
                                color: Color(0xFF5D6B82),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_message != null) ...[
                      const SizedBox(height: 16),
                      _ProfileStatusBanner(
                        message: _message!,
                        isSuccess: _messageIsSuccess,
                      ),
                    ],
                    const SizedBox(height: 20),
                    if (_isEditing) ...[
                      SizedBox(
                        height: 52,
                        child: FilledButton(
                          onPressed: _isSaving ? null : _saveProfile,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2C7DF7),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            textStyle: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          child: _isSaving
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Text('Save Profile'),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      height: 52,
                      child: OutlinedButton.icon(
                        onPressed:
                            _isSaving ? null : () => ref.read(authRepositoryProvider).signOut(),
                        icon: const Icon(Icons.logout_rounded),
                        label: const Text('Sign Out'),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF153B74),
                          side: const BorderSide(color: Color(0xFFD6E0EE)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emailValue(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return 'Not provided';
    return trimmed;
  }
}

class _PatientProfilePortrait extends StatelessWidget {
  const _PatientProfilePortrait({required this.gender});

  final String? gender;

  @override
  Widget build(BuildContext context) {
    final normalized = gender?.trim().toLowerCase();
    final asset = switch (normalized) {
      'male' => 'assets/profile/boy_3d.png',
      'female' => 'assets/profile/girl_3d.png',
      _ => null,
    };

    if (asset == null) {
      return const SizedBox(
        width: 90,
        height: 90,
        child: Icon(
          Icons.person_rounded,
          size: 56,
          color: Color(0xFF2C7DF7),
        ),
      );
    }

    return Image.asset(
      asset,
      width: 90,
      height: 90,
      fit: BoxFit.contain,
    );
  }
}

class _ProfileSectionCard extends StatelessWidget {
  const _ProfileSectionCard({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBFF),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDCE7F6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
                  color: const Color(0xFF153B74),
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: theme.textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF5D6B82),
                  height: 1.45,
                ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _ProfileStatusBanner extends StatelessWidget {
  const _ProfileStatusBanner({
    required this.message,
    required this.isSuccess,
  });

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
        style: TextStyle(
          color: isSuccess ? const Color(0xFF067647) : const Color(0xFFB42318),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
