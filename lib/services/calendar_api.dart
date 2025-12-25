import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/auth_session.dart';
import '../models/calendar_event.dart';
import '../models/colleague.dart';
import '../models/group.dart';
import '../models/group_invite.dart';
import '../models/group_invite_link.dart';
import '../models/group_shared_row.dart';
import '../models/swap_request.dart';
import '../models/worksite.dart';
import '../models/user.dart';

class CalendarApiClient {
  CalendarApiClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _client = httpClient ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'NURSESHIFT_API_URL',
              defaultValue: 'http://api.art168.cn:8000',
            );

  final http.Client _client;
  final String _baseUrl;

  String get baseUrl => _baseUrl;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final Uri base = Uri.parse(_baseUrl);
    return Uri(
      scheme: base.scheme,
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: '${base.path}$path',
      queryParameters: query,
    );
  }

  Future<List<CalendarEvent>> fetchEventsForMonth(
    DateTime month, {
    int? userId,
  }) async {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 0);
    final Map<String, dynamic> params = {
      'start_date': _formatDate(start),
      'end_date': _formatDate(end),
    };
    if (userId != null) {
      params['user_id'] = userId.toString();
    }
    final response = await _client.get(_uri('/events', params));

    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load events (${response.statusCode}): ${response.body}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => CalendarEvent.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<CalendarEvent> createEvent({
    required String title,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String location,
    required String eventType,
    String? notes,
    int? userId,
  }) async {
    final Map<String, dynamic> payload = _buildEventPayload(
      title: title,
      date: date,
      startTime: startTime,
      endTime: endTime,
      location: location,
      eventType: eventType,
      notes: notes,
      userId: userId,
    );
    debugPrint(
      'Creating event for user ${userId ?? 'default'}: ${jsonEncode(payload)}',
    );

    final response = await _client.post(
      _uri('/events'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to create event (${response.statusCode}): ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return CalendarEvent.fromJson(data);
  }

  Future<CalendarEvent> updateEvent({
    required int id,
    required String title,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String location,
    required String eventType,
    String? notes,
  }) async {
    final Map<String, dynamic> payload = _buildEventPayload(
      title: title,
      date: date,
      startTime: startTime,
      endTime: endTime,
      location: location,
      eventType: eventType,
      notes: notes,
    );

    final response = await _client.put(
      _uri('/events/$id'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to update event (${response.statusCode}): ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return CalendarEvent.fromJson(data);
  }

  Future<void> deleteEvent(int id) async {
    final response = await _client.delete(_uri('/events/$id'));
    if (response.statusCode != 204) {
      throw ApiException(
        'Failed to delete event (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<List<SwapRequest>> fetchSwapRequestsForMonth(
    DateTime month, {
    int? userId,
  }) async {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 0);
    final Map<String, dynamic> params = {
      'start_date': _formatDate(start),
      'end_date': _formatDate(end),
      'status': 'pending',
    };
    if (userId != null) {
      params['user_id'] = userId.toString();
    }
    final response = await _client.get(_uri('/swap-requests', params));

    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load swap requests (${response.statusCode}): ${response.body}',
      );
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => SwapRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SwapRequest> createSwapRequest({
    required int eventId,
    required SwapMode mode,
    required String desiredShiftType,
    TimeOfDay? availableStartTime,
    TimeOfDay? availableEndTime,
    DateTimeRange? availableDateRange,
    required bool visibleToAll,
    required bool shareWithStaffingPool,
    required List<String> targetedColleagues,
    String? notes,
  }) async {
    final Map<String, dynamic> payload = {
      'event_id': eventId,
      'mode': mode.apiValue,
      'desired_shift_type': desiredShiftType,
      'available_start_time': _formatNullableTimeOfDay(availableStartTime),
      'available_end_time': _formatNullableTimeOfDay(availableEndTime),
      'available_start_date': _formatNullableDate(availableDateRange?.start),
      'available_end_date': _formatNullableDate(availableDateRange?.end),
      'visible_to_all': visibleToAll,
      'share_with_staffing_pool': shareWithStaffingPool,
      'notes': notes,
      'targeted_colleagues': visibleToAll ? <String>[] : targetedColleagues,
    };

    final response = await _client.post(
      _uri('/swap-requests'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to create swap request (${response.statusCode}): ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return SwapRequest.fromJson(data);
  }

  Future<List<Worksite>> fetchWorksites(int userId) async {
    final response = await _client.get(
      _uri('/worksites', {'user_id': userId.toString()}),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load worksites (${response.statusCode}): ${response.body}',
      );
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Worksite.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Worksite> createWorksite({
    required int userId,
    required String hospitalName,
    required String departmentName,
    required String positionName,
  }) async {
    final response = await _client.post(
      _uri('/worksites'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'hospital_name': hospitalName,
        'department_name': departmentName,
        'position_name': positionName,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to save worksite (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Worksite.fromJson(data);
  }

  Future<void> deleteWorksite(int worksiteId) async {
    final response = await _client.delete(_uri('/worksites/$worksiteId'));
    if (response.statusCode != 204) {
      throw ApiException(
        'Failed to delete worksite (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<User> updateAvatar({
    required int userId,
    String? avatarData,
  }) async {
    final response = await _client.post(
      _uri('/users/$userId/avatar'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'avatar_data': avatarData}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to update avatar (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return User.fromJson(data);
  }

  Future<SwapRequest> retractSwapRequest(int requestId) async {
    final response = await _client.post(_uri('/swap-requests/$requestId/retract'));
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to retract swap (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return SwapRequest.fromJson(data);
  }

  Future<List<SwapRequest>> fetchInboxSwapRequests(int userId) async {
    final response = await _client.get(
      _uri('/inbox/swap-requests', {'user_id': userId.toString()}),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load inbox (${response.statusCode}): ${response.body}',
      );
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => SwapRequest.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<SwapRequest> acceptSwapRequest({
    required int requestId,
    required int userId,
  }) async {
    final response = await _client.post(
      _uri('/swap-requests/$requestId/accept'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to accept request (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return SwapRequest.fromJson(data);
  }

  Future<void> declineSwapRequest({
    required int requestId,
    required int userId,
  }) async {
    final response = await _client.post(
      _uri('/swap-requests/$requestId/decline'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to decline request (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<List<Colleague>> fetchColleagues() async {
    final response = await _client.get(_uri('/colleagues'));
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load colleagues (${response.statusCode}): ${response.body}',
      );
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Colleague.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Colleague> createColleague({
    required String name,
    required String department,
    required String facility,
    String? role,
    String? email,
  }) async {
    final Map<String, dynamic> payload = {
      'name': name,
      'department': department,
      'facility': facility,
      'role': role,
      'email': email,
    };

    final response = await _client.post(
      _uri('/colleagues'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to create colleague (${response.statusCode}): ${response.body}',
      );
    }

    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Colleague.fromJson(data);
  }

  Future<Colleague> acceptColleague(int id) async {
    final response = await _client.post(_uri('/colleagues/$id/accept'));
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to accept colleague (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Colleague.fromJson(data);
  }

  Future<List<Group>> fetchGroups({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    final Map<String, String> query = {};
    if (startDate != null) {
      query['start_date'] = _formatDate(startDate);
    }
    if (endDate != null) {
      query['end_date'] = _formatDate(endDate);
    }
    final response = await _client.get(_uri('/group-shared', query));
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load groups (${response.statusCode}): ${response.body}',
      );
    }
    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .map((item) => Group.fromJson(item as Map<String, dynamic>))
        .toList();
  }

  Future<Group> createGroup({
    required String name,
    String? description,
  }) async {
    final response = await _client.post(
      _uri('/group-shared'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'description': description,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to create group (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Group.fromJson(data);
  }

  Future<void> deleteGroup(int id) async {
    final response = await _client.delete(_uri('/group-shared/$id'));
    if (response.statusCode != 204) {
      throw ApiException(
        'Failed to delete group (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<Group> inviteToGroup({
    required int groupId,
    required String inviteeName,
    required String inviteeEmail,
  }) async {
    final response = await _client.post(
      _uri('/group-shared/$groupId/invites'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'invitee_name': inviteeName,
        'invitee_email': inviteeEmail,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to send invite (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Group.fromJson(data);
  }

  Future<GroupInviteLinkCreateResponse> createGroupInviteLink({
    required int groupId,
    String role = 'member',
    int expiresInSeconds = 604800,
    int maxUses = 20,
  }) async {
    final response = await _client.post(
      _uri('/groups/$groupId/invites'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': role,
        'expiresInSeconds': expiresInSeconds,
        'maxUses': maxUses,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to create invite (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return GroupInviteLinkCreateResponse.fromJson(data);
  }

  Future<GroupInvitePreview> fetchInvitePreview(String token) async {
    final response = await _client.get(_uri('/invites/$token/preview'));
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200) {
      return GroupInvitePreview.fromJson(data);
    }
    if (response.statusCode == 400) {
      return GroupInvitePreview.fromJson(data);
    }
    throw ApiException(
      'Failed to load invite (${response.statusCode}): ${response.body}',
    );
  }

  Future<GroupInviteRedeemResponse> redeemInvite({
    required String token,
    required String userId,
  }) async {
    final response = await _client.post(
      _uri('/invites/$token/redeem'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'userId': userId}),
    );
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 || response.statusCode == 400) {
      return GroupInviteRedeemResponse.fromJson(data);
    }
    throw ApiException(
      'Failed to redeem invite (${response.statusCode}): ${response.body}',
    );
  }

  Future<Group> acceptGroupInvite({
    required int inviteId,
    required int userId,
  }) async {
    final response = await _client.post(
      _uri('/group-shared/invites/$inviteId/accept'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to accept invite (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Group.fromJson(data);
  }

  Future<Group> declineGroupInvite({
    required int inviteId,
    required int userId,
  }) async {
    final response = await _client.post(
      _uri('/group-shared/invites/$inviteId/decline'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'user_id': userId}),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to decline invite (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Group.fromJson(data);
  }

  Future<Group> acceptInviteByToken({
    required String token,
    required int userId,
  }) async {
    final response = await _client.post(
      _uri('/group-invites/accept-by-token'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'token': token, 'user_id': userId}),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to accept invite (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Group.fromJson(data);
  }

  Future<Group> shareGroupWeek({
    required int groupId,
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _client.post(
      _uri('/group-shared/$groupId/share'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to share schedule (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Group.fromJson(data);
  }

  Future<Group> cancelGroupShare({
    required int groupId,
    required int userId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final response = await _client.post(
      _uri('/group-shared/$groupId/share/cancel'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'start_date': _formatDate(startDate),
        'end_date': _formatDate(endDate),
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Failed to cancel share (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return Group.fromJson(data);
  }

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      _uri('/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (response.statusCode != 200) {
      throw ApiException(
        'Login failed (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(data);
  }

  Future<AuthSession> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    required bool acceptPrivacy,
    required bool acceptDisclaimer,
  }) async {
    final response = await _client.post(
      _uri('/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name,
        'email': email,
        'password': password,
        'confirm_password': confirmPassword,
        'accept_privacy': acceptPrivacy,
        'accept_disclaimer': acceptDisclaimer,
      }),
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Registration failed (${response.statusCode}): ${response.body}',
      );
    }
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;
    return AuthSession.fromJson(data);
  }

  Future<void> logout() async {
    final response = await _client.post(_uri('/auth/logout'));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        'Logout failed (${response.statusCode}): ${response.body}',
      );
    }
  }

  Future<String> fetchLegalDocument(String path) async {
    final Uri uri = _uri(path);
    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw ApiException(
        'Failed to load document (${response.statusCode})',
      );
    }
    return response.body;
  }

  String _formatDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

  String _formatTimeOfDay(TimeOfDay value) =>
      '${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}:00';

  String? _formatNullableDate(DateTime? value) =>
      value == null ? null : _formatDate(value);

  String? _formatNullableTimeOfDay(TimeOfDay? value) =>
      value == null ? null : _formatTimeOfDay(value);

  Map<String, dynamic> _buildEventPayload({
    required String title,
    required DateTime date,
    required TimeOfDay startTime,
    required TimeOfDay endTime,
    required String location,
    required String eventType,
    String? notes,
    int? userId,
  }) {
    final Map<String, dynamic> payload = {
      'title': title,
      'date': _formatDate(date),
      'start_time': _formatTimeOfDay(startTime),
      'end_time': _formatTimeOfDay(endTime),
      'location': location,
      'event_type': eventType,
      'notes': notes,
    };
    if (userId != null) {
      payload['user_id'] = userId;
    }
    return payload;
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
