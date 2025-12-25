import 'group_invite.dart';
import 'group_shared_row.dart';

class Group {
  const Group({
    required this.id,
    required this.name,
    this.description,
    required this.inviteMessage,
    required this.invites,
    required this.sharedCalendar,
  });

  final int id;
  final String name;
  final String? description;
  final String inviteMessage;
  final List<GroupInvite> invites;
  final List<GroupSharedRow> sharedCalendar;

  factory Group.fromJson(Map<String, dynamic> json) {
    final List<dynamic> inviteData = json['invites'] as List<dynamic>? ?? [];
    return Group(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      inviteMessage: json['invite_message'] as String,
      invites: inviteData
          .map((item) => GroupInvite.fromJson(item as Map<String, dynamic>))
          .toList(),
      sharedCalendar: (json['shared_calendar'] as List<dynamic>? ?? [])
          .map(
            (item) => GroupSharedRow.fromJson(item as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Group copyWith({
    int? id,
    String? name,
    String? description,
    String? inviteMessage,
    List<GroupInvite>? invites,
    List<GroupSharedRow>? sharedCalendar,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      inviteMessage: inviteMessage ?? this.inviteMessage,
      invites: invites ?? this.invites,
      sharedCalendar: sharedCalendar ?? this.sharedCalendar,
    );
  }
}
