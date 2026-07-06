import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/app_session_provider.dart';
import '../../auth/data/auth_repository.dart';
import '../../../firebase/auth_providers.dart';
import '../../../firebase/firebase_bootstrap.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bootstrapState = ref.watch(firebaseBootstrapStateProvider);
    final authState = ref.watch(authStateChangesProvider);
    final fcmToken = ref.watch(firebaseMessagingTokenProvider);
    final sessionAsync = ref.watch(appSessionProvider);
    final session = sessionAsync.valueOrNull;

    final authLabel = authState.maybeWhen(
      data: (user) => user == null ? 'Signed out' : 'Signed in as ${user.email ?? user.uid}',
      orElse: () => 'Auth state unavailable',
    );

    final tokenLabel = fcmToken.maybeWhen(
      data: (value) => value == null ? 'No device token yet' : 'Device token ready',
      orElse: () => 'Messaging not initialized',
    );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    const Color(0xFF138A6B),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(28),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'DUFUTH SmartCare',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Appointments, schedules, and hospital coordination in one place.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: Colors.white.withValues(alpha: 0.92),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: const [
                      _RoleChip(label: 'Patients'),
                      _RoleChip(label: 'Doctors'),
                      _RoleChip(label: 'Administrators'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _FirebaseStatusCard(
              bootstrapState: bootstrapState,
              authLabel: authLabel,
              tokenLabel: tokenLabel,
            ),
            const SizedBox(height: 20),
            if (session?.user != null && session?.profile != null)
              _SessionSummaryCard(
                role: session!.user!.role,
                fullName: session.profile!.fullName,
                email: session.user!.email,
                onSignOut: () => ref.read(authRepositoryProvider).signOut(),
              ),
            if (session?.user != null) const SizedBox(height: 20),
            const _SectionTitle(
              title: 'Core Features',
              subtitle: 'Starter modules planned for the first build.',
            ),
            const SizedBox(height: 12),
            const _FeatureCard(
              title: 'Patient Experience',
              items: [
                'Account creation and login',
                'Hospital info and FAQs',
                'Book, manage, and cancel appointments',
                'Reminders for upcoming visits',
              ],
            ),
            const SizedBox(height: 12),
            const _FeatureCard(
              title: 'Doctor Workspace',
              items: [
                'Daily schedule overview',
                'Upcoming patient bookings',
                'Slot-by-slot appointment tracking',
                'Cancellation and booking alerts',
              ],
            ),
            const SizedBox(height: 12),
            const _FeatureCard(
              title: 'Admin Control Center',
              items: [
                'Manage departments and doctors',
                'Create and control appointment slots',
                'Monitor hospital appointments',
                'Update hospital info and FAQs',
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionSummaryCard extends StatelessWidget {
  const _SessionSummaryCard({
    required this.role,
    required this.fullName,
    required this.email,
    required this.onSignOut,
  });

  final String role;
  final String fullName;
  final String email;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Active session',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text('$fullName • $role'),
            const SizedBox(height: 4),
            Text(email),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: onSignOut,
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FirebaseStatusCard extends StatelessWidget {
  const _FirebaseStatusCard({
    required this.bootstrapState,
    required this.authLabel,
    required this.tokenLabel,
  });

  final FirebaseBootstrapState bootstrapState;
  final String authLabel;
  final String tokenLabel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConfigured = bootstrapState == FirebaseBootstrapState.configured;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Firebase Setup Status',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              isConfigured
                  ? 'Firebase is initialized for Auth, Firestore, and Cloud Messaging.'
                  : 'Firebase is scaffolded, but still needs your real project configuration.',
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 14),
            Text(authLabel, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            Text(tokenLabel, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: const Color(0xFF52606D),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.title,
    required this.items,
  });

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            for (final item in items) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 3),
                    child: Icon(
                      Icons.check_circle,
                      size: 18,
                      color: Color(0xFF0B6E4F),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.20),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
