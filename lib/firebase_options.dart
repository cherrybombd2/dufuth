import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Replace these placeholders by running `flutterfire configure`.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError('This project is currently configured for Android only.');
    }
  }

  static bool get isConfigured =>
      android.apiKey != 'replace-me' &&
      android.appId != 'replace-me' &&
      android.projectId != 'replace-me';

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'replace-me',
    appId: 'replace-me',
    messagingSenderId: 'replace-me',
    projectId: 'replace-me',
    authDomain: 'replace-me',
    storageBucket: 'replace-me',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyA7jIjf033zXWPifZmqQH8PnNmJjTdzKXc',
    appId: '1:1048065806313:android:4c93cb32a71a7aa02f0578',
    messagingSenderId: '1048065806313',
    projectId: 'dufuth2',
    storageBucket: 'dufuth2.firebasestorage.app',
  );
}
