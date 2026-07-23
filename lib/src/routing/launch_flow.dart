import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/app_update/application/app_update_provider.dart';
import '../features/app_update/presentation/forced_update_screen.dart';
import '../features/auth/application/app_session_provider.dart';
import '../features/auth/domain/app_session.dart';
import '../features/auth/presentation/account_state_screens.dart';
import '../features/auth/presentation/backend_unavailable_screen.dart';
import '../features/auth/presentation/profile_completion_screen.dart';
import '../features/auth/presentation/sign_in_screen.dart';
import '../features/onboarding/application/onboarding_preferences.dart';

class AppLaunchGateScreen extends ConsumerWidget {
  const AppLaunchGateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AppUpdateGate(child: _AppLaunchGateBody());
  }
}

class _AppLaunchGateBody extends ConsumerWidget {
  const _AppLaunchGateBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final onboardingAsync = ref.watch(onboardingSeenProvider);

    return onboardingAsync.when(
      loading: () => const AccountBootstrapScreen(),
      error: (_, _) => const AccountBootstrapScreen(),
      data: (seen) {
        if (!seen) {
          return const _RouteForwarderScreen(target: '/onboarding');
        }

        final sessionAsync = ref.watch(appSessionProvider);
        return sessionAsync.when(
          loading: () => const AccountBootstrapScreen(),
          error: (error, _) =>
              BackendUnavailableScreen(message: error.toString()),
          data: (session) {
            switch (session.status) {
              case AppSessionStatus.loading:
                return const AccountBootstrapScreen();
              case AppSessionStatus.signedOut:
              case AppSessionStatus.tokenExpired:
                return const _RouteForwarderScreen(target: '/sign-in');
              case AppSessionStatus.profileMissing:
                if (session.role == null || session.role == 'patient') {
                  return const _RouteForwarderScreen(
                    target: '/complete-profile',
                  );
                }
                return InvalidRoleFallbackScreen(role: session.role);
              case AppSessionStatus.backendUnavailable:
                return BackendUnavailableScreen(message: session.message);
              case AppSessionStatus.authenticated:
                final role = _normalizedRole(session.user?.role);
                final route = _workspaceRouteForRole(role);
                if (route == null) {
                  return InvalidRoleFallbackScreen(role: session.user?.role);
                }
                return _RouteForwarderScreen(target: route);
            }
          },
        );
      },
    );
  }
}

class RoleProtectedScreen extends ConsumerWidget {
  const RoleProtectedScreen({
    required this.requiredRole,
    required this.child,
    super.key,
  });

  final String requiredRole;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppUpdateGate(
      child: _RoleProtectedBody(
        requiredRole: requiredRole,
        child: child,
      ),
    );
  }
}

class _RoleProtectedBody extends ConsumerWidget {
  const _RoleProtectedBody({
    required this.requiredRole,
    required this.child,
  });

  final String requiredRole;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const AccountBootstrapScreen(),
      error: (error, _) => BackendUnavailableScreen(message: error.toString()),
      data: (session) {
        switch (session.status) {
          case AppSessionStatus.loading:
            return const AccountBootstrapScreen();
          case AppSessionStatus.signedOut:
          case AppSessionStatus.tokenExpired:
            return const SignInScreen();
          case AppSessionStatus.profileMissing:
            if (session.role == null || session.role == 'patient') {
              return const ProfileCompletionScreen();
            }
            return InvalidRoleFallbackScreen(role: session.role);
          case AppSessionStatus.backendUnavailable:
            return BackendUnavailableScreen(message: session.message);
          case AppSessionStatus.authenticated:
            final currentRole = _normalizedRole(session.user?.role);
            if (currentRole == null) {
              return InvalidRoleFallbackScreen(role: session.user?.role);
            }
            if (currentRole != requiredRole) {
              return AccessRestrictedScreen(
                currentRole: currentRole,
                onReturn: () =>
                    context.go(_workspaceRouteForRole(currentRole) ?? '/'),
              );
            }
            return child;
        }
      },
    );
  }
}

class MultiRoleProtectedScreen extends ConsumerWidget {
  const MultiRoleProtectedScreen({
    required this.allowedRoles,
    required this.child,
    super.key,
  });

  final Set<String> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppUpdateGate(
      child: _MultiRoleProtectedBody(
        allowedRoles: allowedRoles,
        child: child,
      ),
    );
  }
}

class _MultiRoleProtectedBody extends ConsumerWidget {
  const _MultiRoleProtectedBody({
    required this.allowedRoles,
    required this.child,
  });

  final Set<String> allowedRoles;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(appSessionProvider);

    return sessionAsync.when(
      loading: () => const AccountBootstrapScreen(),
      error: (error, _) => BackendUnavailableScreen(message: error.toString()),
      data: (session) {
        switch (session.status) {
          case AppSessionStatus.loading:
            return const AccountBootstrapScreen();
          case AppSessionStatus.signedOut:
          case AppSessionStatus.tokenExpired:
            return const SignInScreen();
          case AppSessionStatus.profileMissing:
            if (session.role == null || session.role == 'patient') {
              return const ProfileCompletionScreen();
            }
            return InvalidRoleFallbackScreen(role: session.role);
          case AppSessionStatus.backendUnavailable:
            return BackendUnavailableScreen(message: session.message);
          case AppSessionStatus.authenticated:
            final currentRole = _normalizedRole(session.user?.role);
            if (currentRole == null) {
              return InvalidRoleFallbackScreen(role: session.user?.role);
            }
            if (!allowedRoles.contains(currentRole)) {
              return AccessRestrictedScreen(
                currentRole: currentRole,
                onReturn: () =>
                    context.go(_workspaceRouteForRole(currentRole) ?? '/'),
              );
            }
            return child;
        }
      },
    );
  }
}

class AppUpdateGate extends ConsumerWidget {
  const AppUpdateGate({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final updateAsync = ref.watch(appUpdateGateProvider);

    return updateAsync.when(
      loading: () => const AccountBootstrapScreen(),
      error: (_, _) => child,
      data: (result) {
        if (result.isUpdateRequired) {
          return ForcedUpdateScreen(result: result);
        }
        return child;
      },
    );
  }
}

class _RouteForwarderScreen extends StatefulWidget {
  const _RouteForwarderScreen({required this.target});

  final String target;

  @override
  State<_RouteForwarderScreen> createState() => _RouteForwarderScreenState();
}

class _RouteForwarderScreenState extends State<_RouteForwarderScreen> {
  String? _lastScheduledTarget;

  void _scheduleNavigation() {
    if (_lastScheduledTarget == widget.target) return;
    _lastScheduledTarget = widget.target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final location = GoRouterState.of(context).uri.toString();
      if (location != widget.target) {
        context.go(widget.target);
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scheduleNavigation();
  }

  @override
  void didUpdateWidget(covariant _RouteForwarderScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleNavigation();
  }

  @override
  Widget build(BuildContext context) {
    return const AccountBootstrapScreen();
  }
}

String? _normalizedRole(String? role) {
  final value = role?.trim().toLowerCase();
  if (value == null || value.isEmpty) {
    return null;
  }
  if (value == 'patient' || value == 'doctor' || value == 'admin') {
    return value;
  }
  return null;
}

String? _workspaceRouteForRole(String? role) {
  switch (role) {
    case 'patient':
      return '/patient';
    case 'doctor':
      return '/doctor';
    case 'admin':
      return '/admin';
    default:
      return null;
  }
}
