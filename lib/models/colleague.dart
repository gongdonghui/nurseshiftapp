class Colleague {
  const Colleague({
    required this.id,
    required this.name,
    required this.department,
    required this.facility,
    required this.status,
    this.role,
    this.email,
    this.invitationMessage,
  });

  final int id;
  final String name;
  final String department;
  final String facility;
  final ColleagueStatus status;
  final String? role;
  final String? email;
  final String? invitationMessage;

  factory Colleague.fromJson(Map<String, dynamic> json) {
    return Colleague(
      id: json['id'] as int,
      name: json['name'] as String,
      department: json['department'] as String,
      facility: json['facility'] as String,
      status: ColleagueStatus.values.firstWhere(
        (status) => status.apiValue == (json['status'] as String? ?? 'invited'),
        orElse: () => ColleagueStatus.invited,
      ),
      role: json['role'] as String?,
      email: json['email'] as String?,
      invitationMessage: json['invitation_message'] as String?,
    );
  }
}

enum ColleagueStatus { invited, accepted }

extension ColleagueStatusApi on ColleagueStatus {
  String get apiValue => this == ColleagueStatus.accepted ? 'accepted' : 'invited';

  String get label {
    switch (this) {
      case ColleagueStatus.accepted:
        return 'Accepted';
      case ColleagueStatus.invited:
        return 'Invited';
    }
  }
}
