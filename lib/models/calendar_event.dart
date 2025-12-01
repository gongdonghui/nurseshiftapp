import '../utils/event_type_icon.dart';
import 'day_schedule.dart';

class CalendarEvent {
  const CalendarEvent({
    required this.id,
    required this.date,
    required this.title,
    required this.startTime,
    required this.endTime,
    required this.timeRange,
    required this.location,
    required this.eventType,
    this.notes,
  });

  final int id;
  final DateTime date;
  final String title;
  final String startTime;
  final String endTime;
  final String timeRange;
  final String location;
  final String eventType;
  final String? notes;

  factory CalendarEvent.fromJson(Map<String, dynamic> json) {
    return CalendarEvent(
      id: json['id'] as int,
      date: DateTime.parse(json['date'] as String),
      title: json['title'] as String,
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      timeRange: json['time_range'] as String,
      location: json['location'] as String,
      eventType: json['event_type'] as String,
      notes: json['notes'] as String?,
    );
  }

  DaySchedule toDaySchedule() {
    return DaySchedule(
      title: title,
      timeRange: timeRange,
      location: location,
      icon: iconForEventType(eventType),
    );
  }
}
