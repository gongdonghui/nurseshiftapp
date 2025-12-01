import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/calendar_event.dart';
import '../models/colleague.dart';
import '../models/swap_request.dart';

class CalendarApiClient {
  CalendarApiClient({
    http.Client? httpClient,
    String? baseUrl,
  })  : _client = httpClient ?? http.Client(),
        _baseUrl = baseUrl ??
            const String.fromEnvironment(
              'NURSESHIFT_API_URL',
              defaultValue: 'http://localhost:8000',
            );

  final http.Client _client;
  final String _baseUrl;

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

  Future<List<CalendarEvent>> fetchEventsForMonth(DateTime month) async {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 0);
    final response = await _client.get(
      _uri('/events', {
        'start_date': _formatDate(start),
        'end_date': _formatDate(end),
      }),
    );

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

  Future<List<SwapRequest>> fetchSwapRequestsForMonth(DateTime month) async {
    final DateTime start = DateTime(month.year, month.month, 1);
    final DateTime end = DateTime(month.year, month.month + 1, 0);
    final response = await _client.get(
      _uri('/swap-requests', {
        'start_date': _formatDate(start),
        'end_date': _formatDate(end),
        'status': 'pending',
      }),
    );

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
  }) {
    return {
      'title': title,
      'date': _formatDate(date),
      'start_time': _formatTimeOfDay(startTime),
      'end_time': _formatTimeOfDay(endTime),
      'location': location,
      'event_type': eventType,
      'notes': notes,
    };
  }
}

class ApiException implements Exception {
  ApiException(this.message);
  final String message;

  @override
  String toString() => message;
}
