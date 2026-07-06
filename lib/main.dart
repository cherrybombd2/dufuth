import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_options.dart';
import 'src/app.dart';
import 'src/firebase/firebase_bootstrap.dart';
import 'src/firebase/firebase_startup_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrapState = await bootstrapFirebase();
  unawaited(initializeFirebaseStartupServices(bootstrapState));

  runApp(
    ProviderScope(
      overrides: [
        firebaseBootstrapStateProvider.overrideWithValue(bootstrapState),
        firebaseOptionsProvider.overrideWithValue(DefaultFirebaseOptions.currentPlatform),
      ],
      child: const SmartCareApp(),
    ),
  );
}
