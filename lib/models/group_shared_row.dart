class GroupSharedEntry {
  const GroupSharedEntry({
    required this.date,
    required this.label,
    this.iconName,
  });

  final DateTime date;
  final String label;
  final String? iconName;

  factory GroupSharedEntry.fromJson(Map<String, dynamic> json) {
    final String rawDate = json['date'] as String;
    return GroupSharedEntry(
      date: DateTime.parse(rawDate),
      label: json['label'] as String? ?? 'Shift',
      iconName: json['icon'] as String?,
    );
  }
}

class GroupSharedRow {
  const GroupSharedRow({
    required this.memberName,
    required this.entries,
    this.memberId,
    this.startDate,
    this.endDate,
  });

  final String memberName;
  final List<GroupSharedEntry> entries;
  final int? memberId;
  final DateTime? startDate;
  final DateTime? endDate;

  factory GroupSharedRow.fromJson(Map<String, dynamic> json) {
    final List<dynamic> entryData = json['entries'] as List<dynamic>? ?? const [];
    List<GroupSharedEntry> parsed =
        entryData.map((item) => GroupSharedEntry.fromJson(item as Map<String, dynamic>)).toList();

    final String? startRaw = (json['start_date'] ?? json['week_start']) as String?;
    final String? endRaw = json['end_date'] as String?;
    DateTime? startDate = startRaw == null ? null : DateTime.parse(startRaw);
    DateTime? endDate = endRaw == null ? null : DateTime.parse(endRaw);

    if (parsed.isEmpty) {
      final List<dynamic> schedule = json['schedule'] as List<dynamic>? ?? const [];
      if (startDate != null) {
        parsed = [
          for (int i = 0; i < schedule.length; i++)
            GroupSharedEntry(
              date: startDate.add(Duration(days: i)),
              label: schedule[i].toString(),
            ),
        ];
        if (parsed.isNotEmpty) {
          endDate = parsed.last.date;
        }
      }
    } else {
      startDate ??= parsed.first.date;
      endDate ??= parsed.last.date;
    }

    return GroupSharedRow(
      memberName: json['member_name'] as String? ?? 'Member',
      entries: parsed,
      memberId: json['member_id'] as int?,
      startDate: startDate,
      endDate: endDate,
    );
  }
}
