import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_ui.dart';
import '../data/auth_repository.dart';
import '../domain/auth_flow_exception.dart';

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
      _error = null;
    });

    try {
      await ref.read(authRepositoryProvider).signIn(
            email: _emailController.text,
            password: _passwordController.text,
          );
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
      body: AuthBackground(
        child: AuthShell(
          maxWidth: 500,
          padding: const EdgeInsets.fromLTRB(22, 18, 22, 10),
          scrollable: true,
          child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  const AuthLogoMark(size: 176, padding: EdgeInsets.all(14)),
                  const SizedBox(height: 16),
                  Text(
                    'DUFUTH SmartCare',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: AuthColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Welcome Back!',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.displaySmall?.copyWith(
                      color: AuthColors.navy,
                      fontWeight: FontWeight.w800,
                      fontSize: 33,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: authInputDecoration(
                      label: 'Email address',
                      icon: Icons.mail_outline_rounded,
                      hint: 'user@example.com',
                    ),
                    validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Enter your email' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: authInputDecoration(
                      label: 'Password',
                      icon: Icons.lock_outline_rounded,
                      hint: 'Password',
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
                        value == null || value.isEmpty ? 'Enter your password' : null,
                  ),
                  const SizedBox(height: 2),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => context.go('/forgot-password'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF4A5E74),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      ),
                      child: const Text(
                        'Forgot Password?',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    AuthErrorBanner(_error!),
                    const SizedBox(height: 12),
                  ] else
                    const SizedBox(height: 4),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: FilledButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        backgroundColor: AuthColors.button,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                        textStyle: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      child: Text(_isSubmitting ? 'Signing in...' : 'Login'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 220,
                    child: Stack(
                      children: [
                        Align(
                          alignment: const Alignment(0, -0.30),
                          child: Text(
                            "Don't have an account?",
                            textAlign: TextAlign.center,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: const Color(0xFF515E6E),
                              fontWeight: FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                        ),
                        Align(
                          alignment: const Alignment(0, 0.00),
                          child: TextButton(
                            onPressed: () => context.go('/sign-up'),
                            style: TextButton.styleFrom(
                              foregroundColor: AuthColors.navy,
                              textStyle: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w700,
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            ),
                            child: const Text('Sign Up'),
                          ),
                        ),
                        Positioned(
                          right: -2,
                          bottom: 10,
                          child: Image.asset(
                            'assets/auth/doctor_illustration.png',
                            height: 182,
                            fit: BoxFit.contain,
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
    );
  }
}
