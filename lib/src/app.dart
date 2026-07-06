import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'features/auth/application/app_session_provider.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/domain/app_session.dart';
import 'firebase/auth_providers.dart';
import 'routing/app_router.dart';
import 'theme/app_theme.dart';

class SmartCareApp extends ConsumerStatefulWidget {
  const SmartCareApp({super.key});

  @override
  ConsumerState<SmartCareApp> createState() => _SmartCareAppState();
}

class _SmartCareAppState extends ConsumerState<SmartCareApp> {
  String? _lastSyncedKey;
  bool _syncInFlight = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<AppSession>>(appSessionProvider, (previous, next) => _syncIfNeeded());
    ref.listen<AsyncValue<String?>>(firebaseMessagingTokenProvider, (previous, next) => _syncIfNeeded());

    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'DUFUTH SmartCare',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      routerConfig: router,
    );
  }

  Future<void> _syncIfNeeded() async {
    if (_syncInFlight) return;

    final session = ref.read(appSessionProvider).valueOrNull;
    final token = ref.read(firebaseMessagingTokenProvider).valueOrNull;
    if (session == null || !session.isAuthenticated || session.user == null || token == null) {
      return;
    }

    final syncKey = '${session.user!.uid}:$token';
    if (_lastSyncedKey == syncKey) {
      return;
    }

    _syncInFlight = true;
    try {
      await ref.read(authRepositoryProvider).syncDeviceToken(
            token: token,
            platform: _currentPlatformName(),
          );
      _lastSyncedKey = syncKey;
    } catch (error, stackTrace) {
      debugPrint('Device token sync failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _syncInFlight = false;
    }
  }

  String _currentPlatformName() {
    if (kIsWeb) return 'web';
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'android';
      case TargetPlatform.iOS:
        return 'ios';
      case TargetPlatform.windows:
        return 'windows';
      case TargetPlatform.macOS:
        return 'macos';
      case TargetPlatform.linux:
        return 'linux';
      case TargetPlatform.fuchsia:
        return 'fuchsia';
    }
  }
}
