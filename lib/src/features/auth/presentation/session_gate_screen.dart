import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/app_session_provider.dart';
import '../domain/app_session.dart';
import '../../home/presentation/home_screen.dart';
import 'account_state_screens.dart';
import 'backend_unavailable_screen.dart';
import 'profile_completion_screen.dart';
import 'sign_in_screen.dart';

class SessionGateScreen extends ConsumerWidget {
  const SessionGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const _AuthLoadingScreen(),
      error: (error, _) => BackendUnavailableScreen(
        message: error.toString(),
      ),
      data: (session) {
        switch (session.status) {
          case AppSessionStatus.loading:
            return const _AuthLoadingScreen();
          case AppSessionStatus.signedOut:
          case AppSessionStatus.tokenExpired:
            return const SignInScreen();
          case AppSessionStatus.authenticated:
            return const HomeScreen();
          case AppSessionStatus.profileMissing:
            if (session.role == null || session.role == 'patient') {
              return const ProfileCompletionScreen();
            }
            return InvalidRoleFallbackScreen(role: session.role);
          case AppSessionStatus.backendUnavailable:
            return BackendUnavailableScreen(
              message: session.message,
            );
        }
      },
    );
  }
}

class _AuthLoadingScreen extends StatelessWidget {
  const _AuthLoadingScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF5F7F8),
              colorScheme.primary.withValues(alpha: 0.08),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 84,
                    height: 84,
                    decoration: BoxDecoration(
                      color: colorScheme.primary,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.primary.withValues(alpha: 0.22),
                          blurRadius: 28,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.local_hospital_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'DUFUTH SmartCare',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Restoring your secure session...',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: const Color(0xFF52606D),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const CircularProgressIndicator(),
                  const SizedBox(height: 18),
                  Text(
                    'Checking Firebase authentication and loading your profile.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF7B8794),
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
