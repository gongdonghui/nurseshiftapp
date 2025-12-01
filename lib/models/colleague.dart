class Colleague {
  const Colleague({
    required this.id,
    required this.name,
    required this.department,
    required this.facility,
    this.role,
    this.email,
  });

  final int id;
  final String name;
  final String department;
  final String facility;
  final String? role;
  final String? email;

  factory Colleague.fromJson(Map<String, dynamic> json) {
    return Colleague(
      id: json['id'] as int,
      name: json['name'] as String,
      department: json['department'] as String,
      facility: json['facility'] as String,
      role: json['role'] as String?,
      email: json['email'] as String?,
    );
  }
}
