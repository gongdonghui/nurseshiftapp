import 'package:flutter/material.dart';

const Map<String, IconData> _eventTypeIcons = {
  'regular': Icons.nights_stay_rounded,
  'charge': Icons.shield_moon_rounded,
  'preceptor': Icons.school_rounded,
  'charge_preceptor': Icons.workspace_premium_rounded,
  'on_call': Icons.phone_in_talk_rounded,
  'available': Icons.check_circle_rounded,
  'unavailable': Icons.block_flipped,
  'vacation': Icons.beach_access_rounded,
  'payday': Icons.attach_money_rounded,
  'personal': Icons.favorite_rounded,
  'night_shift': Icons.nights_stay_rounded,
  'float_shift': Icons.directions_boat,
  'conference': Icons.event_available,
};

IconData iconForEventType(String eventType) {
  return _eventTypeIcons[eventType] ?? Icons.event_note_rounded;
}
