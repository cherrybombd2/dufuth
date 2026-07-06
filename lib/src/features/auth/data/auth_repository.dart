import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../firebase/auth_providers.dart';
import '../domain/auth_flow_exception.dart';
import '../domain/app_session.dart';
import 'auth_api_client.dart';

final authApiClientProvider = Provider<AuthApiClient>((ref) {
  return AuthApiClient();
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  final apiClient = ref.watch(authApiClientProvider);
  return AuthRepository(
    auth: auth,
    apiClient: apiClient,
  );
});

class AuthRepository {
  const AuthRepository({
    required FirebaseAuth? auth,
    required AuthApiClient apiClient,
  })  : _auth = auth,
        _apiClient = apiClient;

  final FirebaseAuth? _auth;
  final AuthApiClient _apiClient;

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    final auth = _requireAuth();
    try {
      await auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_mapFirebaseAuthError(error));
    }
  }

  Future<AppSession> signUpPatient({
    required String fullName,
    required String email,
    required String password,
    required String phoneNumber,
    required String gender,
    required String address,
    String? dateOfBirth,
  }) async {
    final auth = _requireAuth();
    try {
      final credential = await auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      final user = credential.user;
      if (user == null) {
        throw const AuthFlowException('Account created, but no signed-in user was returned.');
      }

      return _apiClient.createPatientProfile(
        user: user,
        fullName: fullName,
        phoneNumber: phoneNumber,
        gender: gender,
        address: address,
        dateOfBirth: dateOfBirth?.isEmpty ?? true ? null : dateOfBirth,
      );
    } on AuthFlowException {
      final currentUser = auth.currentUser;
      if (currentUser != null) {
        await currentUser.delete();
      }
      rethrow;
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_mapFirebaseAuthError(error));
    }
  }

  Future<AppSession> completePatientProfile({
    required String fullName,
    required String phoneNumber,
    required String gender,
    required String address,
    String? dateOfBirth,
  }) async {
    final user = _requireAuth().currentUser;
    if (user == null) {
      throw const AuthFlowException('You need to sign in again before completing your profile.');
    }

    return _apiClient.createPatientProfile(
      user: user,
      fullName: fullName,
      phoneNumber: phoneNumber,
      gender: gender,
      address: address,
      dateOfBirth: dateOfBirth?.isEmpty ?? true ? null : dateOfBirth,
    );
  }

  Future<AppSession> updatePatientProfile({
    required String fullName,
    String? phoneNumber,
    String? gender,
    String? address,
    String? dateOfBirth,
  }) async {
    final user = _requireAuth().currentUser;
    if (user == null) {
      throw const AuthFlowException('You need to sign in again before updating your profile.');
    }

    return _apiClient.updatePatientProfile(
      user: user,
      fullName: fullName.trim(),
      phoneNumber: _optionalValue(phoneNumber),
      gender: _optionalValue(gender),
      address: _optionalValue(address),
      dateOfBirth: _optionalValue(dateOfBirth),
    );
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final auth = _requireAuth();
    try {
      await auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFlowException(_mapFirebaseAuthError(error));
    }
  }

  Future<AppSession> restoreSession(User user) {
    return _apiClient.fetchSession(user);
  }

  Future<void> syncDeviceToken({
    required String token,
    required String platform,
  }) async {
    final user = _requireAuth().currentUser;
    if (user == null) {
      throw const AuthFlowException('You need to sign in again before syncing this device.');
    }
    await _apiClient.registerDeviceToken(
      user: user,
      token: token,
      platform: platform,
    );
  }

  Future<void> signOut() async {
    final auth = _requireAuth();
    await auth.signOut();
  }

  FirebaseAuth _requireAuth() {
    final auth = _auth;
    if (auth == null) {
      throw const AuthFlowException('Firebase Auth is not initialized yet.');
    }
    return auth;
  }

  String? _optionalValue(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }
    return trimmed;
  }

  String _mapFirebaseAuthError(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-email':
        return 'That email address is invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account was found for that email.';
      case 'wrong-password':
      case 'invalid-credential':
        return 'Wrong email or password.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password with at least 6 characters.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      default:
        return error.message ?? 'Authentication failed. Please try again.';
    }
  }
}
