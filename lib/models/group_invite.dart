class GroupInvite {
  const GroupInvite({
    required this.id,
    required this.groupId,
    required this.inviteeName,
    this.inviteeEmail,
    this.inviteUrl,
    this.inviteeUserId,
    required this.status,
  });

  final int id;
  final int groupId;
  final String inviteeName;
  final String? inviteeEmail;
  final String? inviteUrl;
  final GroupInviteStatus status;
  final int? inviteeUserId;

  factory GroupInvite.fromJson(Map<String, dynamic> json) {
    return GroupInvite(
      id: json['id'] as int,
      groupId: json['group_id'] as int,
      inviteeName: json['invitee_name'] as String,
      inviteeEmail: json['invitee_email'] as String?,
      inviteUrl: json['invite_url'] as String?,
      inviteeUserId: json['invitee_user_id'] as int?,
      status: GroupInviteStatus.values.firstWhere(
        (value) => value.apiValue == (json['status'] as String? ?? 'invited'),
        orElse: () => GroupInviteStatus.invited,
      ),
    );
  }

  bool get isPending => status == GroupInviteStatus.invited;
}

enum GroupInviteStatus { invited, accepted, declined }

extension GroupInviteStatusApi on GroupInviteStatus {
  String get apiValue {
    switch (this) {
      case GroupInviteStatus.accepted:
        return 'accepted';
      case GroupInviteStatus.declined:
        return 'declined';
      case GroupInviteStatus.invited:
        return 'invited';
    }
  }

  String get label {
    switch (this) {
      case GroupInviteStatus.accepted:
        return 'Accepted';
      case GroupInviteStatus.declined:
        return 'Declined';
      case GroupInviteStatus.invited:
        return 'Invited';
    }
  }
}
