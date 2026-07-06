class Doctor {
  const Doctor({
    required this.userId,
    required this.fullName,
    required this.departmentId,
    this.specialization,
    this.gender,
    this.bio,
    this.consultationMode,
    this.yearsOfExperience,
    this.linkedAccountEmail,
    this.isActive = true,
  });

  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      userId: json['user_id'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      departmentId: json['department_id'] as String? ?? '',
      specialization: json['specialization'] as String?,
      gender: json['gender'] as String?,
      bio: json['bio'] as String?,
      consultationMode: json['consultation_mode'] as String?,
      yearsOfExperience: json['years_of_experience'] as int?,
      linkedAccountEmail: json['linked_account_email'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String userId;
  final String fullName;
  final String departmentId;
  final String? specialization;
  final String? gender;
  final String? bio;
  final String? consultationMode;
  final int? yearsOfExperience;
  final String? linkedAccountEmail;
  final bool isActive;
}

class DoctorDraft {
  const DoctorDraft({
    this.userId,
    required this.fullName,
    required this.departmentId,
    this.specialization,
    required this.gender,
    this.bio,
    this.consultationMode,
    this.yearsOfExperience,
    this.isActive = true,
  });

  factory DoctorDraft.fromDoctor(Doctor doctor) {
    return DoctorDraft(
      userId: doctor.userId,
      fullName: doctor.fullName,
      departmentId: doctor.departmentId,
      specialization: doctor.specialization,
      gender: doctor.gender ?? '',
      bio: doctor.bio,
      consultationMode: doctor.consultationMode,
      yearsOfExperience: doctor.yearsOfExperience,
      isActive: doctor.isActive,
    );
  }

  final String? userId;
  final String fullName;
  final String departmentId;
  final String? specialization;
  final String gender;
  final String? bio;
  final String? consultationMode;
  final int? yearsOfExperience;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'full_name': fullName,
      'department_id': departmentId,
      'specialization': specialization,
      'gender': gender,
      'bio': bio,
      'consultation_mode': consultationMode,
      'years_of_experience': yearsOfExperience,
      'is_active': isActive,
    };
  }
}

class UserLookupResult {
  const UserLookupResult({
    required this.uid,
    this.email,
    this.role,
    this.status,
    this.fullName,
    this.gender,
  });

  factory UserLookupResult.fromJson(Map<String, dynamic> json) {
    return UserLookupResult(
      uid: json['uid'] as String? ?? '',
      email: json['email'] as String?,
      role: json['role'] as String?,
      status: json['status'] as String?,
      fullName: json['full_name'] as String?,
      gender: json['gender'] as String?,
    );
  }

  final String uid;
  final String? email;
  final String? role;
  final String? status;
  final String? fullName;
  final String? gender;
}
