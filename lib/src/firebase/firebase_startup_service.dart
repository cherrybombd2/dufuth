import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';
import 'firebase_bootstrap.dart';

String? _cachedToken;

final StreamController<String?> _tokenController = StreamController<String?>.broadcast();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (Firebase.apps.isEmpty && DefaultFirebaseOptions.isConfigured) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }
  debugPrint('Handling a background Firebase message: ${message.messageId}');
}

Future<void> initializeFirebaseStartupServices(
  FirebaseBootstrapState bootstrapState,
) async {
  if (bootstrapState != FirebaseBootstrapState.configured) {
    _tokenController.add(null);
    return;
  }

  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  final messaging = FirebaseMessaging.instance;
  await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );

  try {
    _cachedToken = await messaging.getToken();
    _tokenController.add(_cachedToken);
  } catch (error) {
    debugPrint('FCM token unavailable during startup: $error');
    _cachedToken = null;
    _tokenController.add(null);
  }

  FirebaseMessaging.onMessage.listen((message) {
    debugPrint('Foreground FCM message received: ${message.messageId}');
  });

  FirebaseMessaging.onMessageOpenedApp.listen((message) {
    debugPrint('Notification opened app: ${message.messageId}');
  });

  messaging.onTokenRefresh.listen((token) {
    _cachedToken = token;
    _tokenController.add(token);
  }, onError: (Object error) {
    debugPrint('FCM token refresh failed: $error');
  });
}

Stream<String?> firebaseMessagingTokenStream() => _tokenController.stream;

String? getCachedFirebaseMessagingToken() => _cachedToken;
