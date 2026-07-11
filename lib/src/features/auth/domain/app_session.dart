enum AppSessionStatus {
  loading,
  signedOut,
  authenticated,
  profileMissing,
  backendUnavailable,
  tokenExpired,
}

class SessionUser {
  const SessionUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.status,
  });

  factory SessionUser.fromJson(Map<String, dynamic> json) {
    return SessionUser(
      uid: json['uid'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      status: json['status'] as String,
    );
  }

  final String uid;
  final String email;
  final String role;
  final String status;
}

class SessionProfile {
  const SessionProfile({
    required this.userId,
    required this.fullName,
    this.phoneNumber,
    this.gender,
    this.address,
    this.dateOfBirth,
    this.departmentId,
    this.specialization,
    this.bio,
    this.consultationMode,
    this.yearsOfExperience,
    this.title,
    this.isActive,
  });

  factory SessionProfile.fromJson(Map<String, dynamic> json) {
    return SessionProfile(
      userId: json['user_id'] as String,
      fullName: json['full_name'] as String? ?? '',
      phoneNumber: json['phone_number'] as String?,
      gender: json['gender'] as String?,
      address: json['address'] as String?,
      dateOfBirth: json['date_of_birth'] as String?,
      departmentId: json['department_id'] as String?,
      specialization: json['specialization'] as String?,
      bio: json['bio'] as String?,
      consultationMode: json['consultation_mode'] as String?,
      yearsOfExperience: json['years_of_experience'] as int?,
      title: json['title'] as String?,
      isActive: json['is_active'] as bool?,
    );
  }

  final String userId;
  final String fullName;
  final String? phoneNumber;
  final String? gender;
  final String? address;
  final String? dateOfBirth;
  final String? departmentId;
  final String? specialization;
  final String? bio;
  final String? consultationMode;
  final int? yearsOfExperience;
  final String? title;
  final bool? isActive;
}

class AppSession {
  const AppSession({
    required this.status,
    this.user,
    this.profile,
    this.message,
    this.role,
  });

  const AppSession.loading()
      : status = AppSessionStatus.loading,
        user = null,
        profile = null,
        message = null,
        role = null;

  const AppSession.signedOut()
      : status = AppSessionStatus.signedOut,
        user = null,
        profile = null,
        message = null,
        role = null;

  const AppSession.profileMissing({this.message, this.role})
      : status = AppSessionStatus.profileMissing,
        user = null,
        profile = null;

  const AppSession.backendUnavailable({this.message})
      : status = AppSessionStatus.backendUnavailable,
        user = null,
        profile = null,
        role = null;

  const AppSession.tokenExpired({this.message})
      : status = AppSessionStatus.tokenExpired,
        user = null,
        profile = null,
        role = null;

  final AppSessionStatus status;
  final SessionUser? user;
  final SessionProfile? profile;
  final String? message;
  final String? role;

  bool get isAuthenticated => status == AppSessionStatus.authenticated;
}
