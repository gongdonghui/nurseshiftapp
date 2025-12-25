class GroupInviteLinkCreateResponse {
  const GroupInviteLinkCreateResponse({
    required this.inviteUrl,
    required this.token,
    required this.expiresAt,
  });

  final String inviteUrl;
  final String token;
  final DateTime expiresAt;

  factory GroupInviteLinkCreateResponse.fromJson(Map<String, dynamic> json) {
    return GroupInviteLinkCreateResponse(
      inviteUrl: json['inviteUrl'] as String,
      token: json['token'] as String,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
    );
  }
}

class GroupInvitePreview {
  const GroupInvitePreview({
    required this.valid,
    this.group,
    this.expiresAt,
    this.remainingUses,
    this.reason,
  });

  final bool valid;
  final GroupInvitePreviewGroup? group;
  final DateTime? expiresAt;
  final int? remainingUses;
  final String? reason;

  factory GroupInvitePreview.fromJson(Map<String, dynamic> json) {
    return GroupInvitePreview(
      valid: json['valid'] as bool,
      group: json['group'] == null
          ? null
          : GroupInvitePreviewGroup.fromJson(
              json['group'] as Map<String, dynamic>,
            ),
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      remainingUses: json['remainingUses'] as int?,
      reason: json['reason'] as String?,
    );
  }
}

class GroupInvitePreviewGroup {
  const GroupInvitePreviewGroup({
    required this.id,
    required this.name,
    required this.memberCount,
  });

  final String id;
  final String name;
  final int memberCount;

  factory GroupInvitePreviewGroup.fromJson(Map<String, dynamic> json) {
    return GroupInvitePreviewGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      memberCount: json['memberCount'] as int,
    );
  }
}

class GroupInviteRedeemResponse {
  const GroupInviteRedeemResponse({
    required this.status,
    required this.groupId,
    this.reason,
  });

  final String status;
  final String groupId;
  final String? reason;

  factory GroupInviteRedeemResponse.fromJson(Map<String, dynamic> json) {
    return GroupInviteRedeemResponse(
      status: json['status'] as String,
      groupId: json['groupId'] as String,
      reason: json['reason'] as String?,
    );
  }
}
