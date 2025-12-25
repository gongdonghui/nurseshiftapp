import 'package:flutter/material.dart';

import 'calendar_event.dart';

enum SwapMode { swap, giveAway }

extension SwapModeName on SwapMode {
  String get apiValue => this == SwapMode.swap ? 'swap' : 'give_away';

  String get label => this == SwapMode.swap ? 'Swap' : 'Give Away';

  static SwapMode fromApi(String value) =>
      value == 'give_away' ? SwapMode.giveAway : SwapMode.swap;
}

enum SwapRequestStatus { pending, retracted, fulfilled }

extension SwapStatusName on SwapRequestStatus {
  static SwapRequestStatus fromApi(String value) {
    switch (value) {
      case 'fulfilled':
        return SwapRequestStatus.fulfilled;
      case 'retracted':
        return SwapRequestStatus.retracted;
      default:
        return SwapRequestStatus.pending;
    }
  }

  String get label {
    switch (this) {
      case SwapRequestStatus.fulfilled:
        return 'Fulfilled';
      case SwapRequestStatus.retracted:
        return 'Retracted';
      case SwapRequestStatus.pending:
        return 'Pending';
    }
  }
}

class SwapRequest {
  SwapRequest({
    required this.id,
    required this.mode,
    required this.status,
    required this.desiredShiftType,
    required this.visibleToAll,
    required this.shareWithStaffingPool,
    required this.targetedColleagues,
    required this.event,
    required this.createdAt,
    this.availableStartTime,
    this.availableEndTime,
    this.availableStartDate,
    this.availableEndDate,
    this.notes,
    this.acceptedByUserId,
    this.acceptedAt,
    this.acceptedByName,
    this.acceptedByEmail,
    this.ownerName,
    this.ownerEmail,
  });

  final int id;
  final SwapMode mode;
  final SwapRequestStatus status;
  final String desiredShiftType;
  final TimeOfDay? availableStartTime;
  final TimeOfDay? availableEndTime;
  final DateTime? availableStartDate;
  final DateTime? availableEndDate;
  final bool visibleToAll;
  final bool shareWithStaffingPool;
  final List<String> targetedColleagues;
  final String? notes;
  final CalendarEvent event;
  final DateTime createdAt;
  final int? acceptedByUserId;
  final DateTime? acceptedAt;
  final String? acceptedByName;
  final String? acceptedByEmail;
  final String? ownerName;
  final String? ownerEmail;

  factory SwapRequest.fromJson(Map<String, dynamic> json) {
    TimeOfDay? parseTime(String? value) {
      if (value == null) return null;
      final List<String> parts = value.split(':');
      if (parts.length < 2) return null;
      return TimeOfDay(
        hour: int.parse(parts[0]),
        minute: int.parse(parts[1]),
      );
    }

    DateTime? parseDate(String? value) =>
        value == null ? null : DateTime.parse(value);

    final List<dynamic> targets =
        json['targeted_colleagues'] as List<dynamic>? ?? [];
    return SwapRequest(
      id: json['id'] as int,
      mode: SwapModeName.fromApi(json['mode'] as String),
      status: SwapStatusName.fromApi(json['status'] as String),
      desiredShiftType: json['desired_shift_type'] as String,
      availableStartTime: parseTime(json['available_start_time'] as String?),
      availableEndTime: parseTime(json['available_end_time'] as String?),
      availableStartDate: parseDate(json['available_start_date'] as String?),
      availableEndDate: parseDate(json['available_end_date'] as String?),
      visibleToAll: json['visible_to_all'] as bool? ?? true,
      shareWithStaffingPool: json['share_with_staffing_pool'] as bool? ?? false,
      targetedColleagues: targets.map((target) => target as String).toList(),
      notes: json['notes'] as String?,
      event: CalendarEvent.fromJson(json['event'] as Map<String, dynamic>),
      createdAt: DateTime.parse(json['created_at'] as String),
      acceptedByUserId: json['accepted_by_user_id'] as int?,
      acceptedAt: json['accepted_at'] == null
          ? null
          : DateTime.parse(json['accepted_at'] as String),
      acceptedByName: json['accepted_by_name'] as String?,
      acceptedByEmail: json['accepted_by_email'] as String?,
      ownerName: json['owner_name'] as String?,
      ownerEmail: json['owner_email'] as String?,
    );
  }

  String get audienceDescription {
    if (visibleToAll) {
      return shareWithStaffingPool
          ? 'All colleagues + staffing pool'
          : 'All colleagues';
    }
    if (targetedColleagues.isEmpty) return 'Selected colleagues';
    return targetedColleagues.join(', ');
  }
}
