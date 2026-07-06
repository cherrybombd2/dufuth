import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../firebase_options.dart';

enum FirebaseBootstrapState {
  configured,
  skipped,
}

final firebaseBootstrapStateProvider = Provider<FirebaseBootstrapState>(
  (_) => FirebaseBootstrapState.skipped,
);

final firebaseOptionsProvider = Provider<FirebaseOptions?>((_) => null);

Future<FirebaseBootstrapState> bootstrapFirebase() async {
  if (!DefaultFirebaseOptions.isConfigured) {
    return FirebaseBootstrapState.skipped;
  }

  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  return FirebaseBootstrapState.configured;
}
