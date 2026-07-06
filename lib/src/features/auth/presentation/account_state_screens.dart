import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/app_session_provider.dart';
import '../data/auth_repository.dart';
import 'auth_ui.dart';

class AccountBootstrapScreen extends StatelessWidget {
  const AccountBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const AuthLogoMark(size: 118, padding: EdgeInsets.all(18)),
                  const SizedBox(height: 26),
                  Text(
                    'Checking your account',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: AuthColors.navy,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Getting DUFUTH SmartCare ready for you...',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: AuthColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const CircularProgressIndicator(
                    color: AuthColors.blue,
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

class InvalidRoleFallbackScreen extends ConsumerWidget {
  const InvalidRoleFallbackScreen({
    super.key,
    this.role,
  });

  final String? role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _CenteredStateCard(
      icon: Icons.shield_outlined,
      title: 'We could not load your account right now.',
      message:
          'We could not determine which workspace to open for your account. Please try again.',
      primaryLabel: 'Retry',
      onPrimary: () => ref.invalidate(appSessionProvider),
      secondaryLabel: 'Sign out',
      onSecondary: () => ref.read(authRepositoryProvider).signOut(),
      footer: role == null
          ? null
          : Text(
              'Role received: $role',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AuthColors.textMuted),
            ),
    );
  }
}

class AccessRestrictedScreen extends StatelessWidget {
  const AccessRestrictedScreen({
    super.key,
    required this.currentRole,
    required this.onReturn,
  });

  final String currentRole;
  final VoidCallback onReturn;

  @override
  Widget build(BuildContext context) {
    return _CenteredStateCard(
      icon: Icons.lock_outline_rounded,
      title: 'This area is not available for your account.',
      message:
          'Please return to the workspace designed for your role to continue using DUFUTH SmartCare.',
      primaryLabel: 'Go to my workspace',
      onPrimary: onReturn,
      secondaryLabel: 'Back to sign in',
      onSecondary: () => context.go('/sign-in'),
    );
  }
}

class _CenteredStateCard extends StatelessWidget {
  const _CenteredStateCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
    this.footer,
  });

  final IconData icon;
  final String title;
  final String message;
  final String primaryLabel;
  final VoidCallback onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: AuthBackground(
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    border: Border.all(color: const Color(0xFFDCE7F6)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x100A67D8),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 74,
                        height: 74,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEAF4FF),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Icon(
                          icon,
                          color: AuthColors.blue,
                          size: 34,
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: AuthColors.navy,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: AuthColors.textMuted,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: FilledButton(
                          onPressed: onPrimary,
                          style: FilledButton.styleFrom(
                            backgroundColor: AuthColors.button,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                          ),
                          child: Text(primaryLabel),
                        ),
                      ),
                      if (secondaryLabel != null && onSecondary != null) ...[
                        const SizedBox(height: 10),
                        TextButton(
                          onPressed: onSecondary,
                          child: Text(secondaryLabel!),
                        ),
                      ],
                      if (footer != null) ...[
                        const SizedBox(height: 12),
                        footer!,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
