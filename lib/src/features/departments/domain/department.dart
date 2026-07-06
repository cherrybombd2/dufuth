class Department {
  const Department({
    required this.name,
    this.description,
    this.iconKey,
    this.isActive = true,
  });

  factory Department.fromJson(Map<String, dynamic> json) {
    return Department(
      name: json['name'] as String? ?? '',
      description: json['description'] as String?,
      iconKey: json['icon_key'] as String?,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String name;
  final String? description;
  final String? iconKey;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'icon_key': iconKey,
      'is_active': isActive,
    };
  }
}

class DepartmentDraft {
  const DepartmentDraft({
    required this.name,
    this.description,
    this.iconKey,
    this.isActive = true,
  });

  factory DepartmentDraft.fromDepartment(Department department) {
    return DepartmentDraft(
      name: department.name,
      description: department.description,
      iconKey: department.iconKey,
      isActive: department.isActive,
    );
  }

  final String name;
  final String? description;
  final String? iconKey;
  final bool isActive;

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'icon_key': iconKey,
      'is_active': isActive,
    };
  }
}
