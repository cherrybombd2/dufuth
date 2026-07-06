import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/auth_providers.dart';
import '../data/auth_repository.dart';
import '../domain/app_session.dart';

final appSessionOverrideProvider = StateProvider<AppSession?>((ref) => null);

final appSessionProvider = StreamProvider<AppSession>((ref) async* {
  final auth = ref.watch(firebaseAuthProvider);
  final repository = ref.watch(authRepositoryProvider);
  final overrideSession = ref.watch(appSessionOverrideProvider);

  if (auth == null) {
    yield const AppSession.signedOut();
    return;
  }

  yield const AppSession.loading();

  final currentUser = auth.currentUser;
  if (currentUser != null && overrideSession?.user?.uid == currentUser.uid) {
    yield overrideSession!;
  }

  await for (final User? user in auth.authStateChanges()) {
    if (user == null) {
      ref.read(appSessionOverrideProvider.notifier).state = null;
      yield const AppSession.signedOut();
      continue;
    }

    final latestOverrideSession = ref.read(appSessionOverrideProvider);
    if (latestOverrideSession?.user?.uid == user.uid) {
      yield latestOverrideSession!;
      continue;
    }

    yield const AppSession.loading();

    final session = await repository.restoreSession(user);
    if (session.status == AppSessionStatus.tokenExpired) {
      await repository.signOut();
      yield const AppSession.tokenExpired(
        message: 'Your session expired. Please sign in again.',
      );
      continue;
    }

    yield session;
  }
});
