class HospitalInfo {
  const HospitalInfo({
    required this.hospitalName,
    this.tagline,
    this.address,
    this.phone,
    this.email,
    this.workingHours,
    this.visitingHours,
    this.website,
    this.about,
    this.patientNotice,
  });

  factory HospitalInfo.fromJson(Map<String, dynamic> json) {
    return HospitalInfo(
      hospitalName: json['hospital_name'] as String? ?? 'DUFUTH SmartCare',
      tagline: json['tagline'] as String?,
      address: json['address'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      workingHours: json['working_hours'] as String?,
      visitingHours: json['visiting_hours'] as String?,
      website: json['website'] as String?,
      about: json['about'] as String?,
      patientNotice: json['patient_notice'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'hospital_name': hospitalName,
      'tagline': tagline,
      'address': address,
      'phone': phone,
      'email': email,
      'working_hours': workingHours,
      'visiting_hours': visitingHours,
      'website': website,
      'about': about,
      'patient_notice': patientNotice,
    };
  }

  final String hospitalName;
  final String? tagline;
  final String? address;
  final String? phone;
  final String? email;
  final String? workingHours;
  final String? visitingHours;
  final String? website;
  final String? about;
  final String? patientNotice;
}
