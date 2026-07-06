# Firebase Setup For DUFUTH

This project is wired for:

- Firebase Auth
- Cloud Firestore
- Firebase Cloud Messaging

## Flutter App

1. Install the Firebase CLI
2. Install FlutterFire CLI
3. From the project root, run:

```bash
flutter pub add firebase_core firebase_auth cloud_firestore firebase_messaging
dart pub global activate flutterfire_cli
flutterfire configure
```

4. Replace the placeholder values in [lib/firebase_options.dart](C:\Users\eobi8\Documents\DUFUTH\lib\firebase_options.dart) with the generated file from `flutterfire configure`
5. Re-run:

```bash
flutter pub get
flutter run
```

## Firebase Console

1. Create or select a Firebase project
2. Enable Authentication
3. Enable Email/Password sign-in
4. Create a Cloud Firestore database
5. Enable Cloud Messaging

## Backend

1. Create a Firebase service account JSON from the Firebase console
2. Save the JSON outside version control
3. Copy `backend/.env.example` to `backend/.env`
4. Set:

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CREDENTIALS_PATH=C:/path/to/service-account.json
USE_FIRESTORE=true
FIREBASE_AUTH_REQUIRED=true
FCM_ENABLED=true
```

5. Install backend dependencies again:

```bash
cd backend
pip install -e .[dev]
uvicorn app.main:app --reload
```

## Notes

- The Flutter app currently skips Firebase initialization until real config values are present.
- The backend falls back to in-memory storage until `USE_FIRESTORE=true`.
- The backend only verifies Firebase bearer tokens when `FIREBASE_AUTH_REQUIRED=true`.
