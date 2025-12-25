class Worksite {
  const Worksite({
    required this.id,
    required this.userId,
    required this.hospitalName,
    required this.departmentName,
    required this.positionName,
  });

  final int id;
  final int userId;
  final String hospitalName;
  final String departmentName;
  final String positionName;

  factory Worksite.fromJson(Map<String, dynamic> json) {
    return Worksite(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      hospitalName: json['hospital_name'] as String,
      departmentName: json['department_name'] as String,
      positionName: json['position_name'] as String,
    );
  }
}
