import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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

const Map<String, Color> _eventTypeColors = {
  'regular': Color(0xFF4FB6E0),
  'charge': Color(0xFF8B6CE1),
  'preceptor': Color(0xFF53C082),
  'charge_preceptor': Color(0xFFEF7EC7),
  'on_call': Color(0xFFFFB74D),
  'available': Color(0xFF4CAF50),
  'unavailable': Color(0xFFE57373),
  'vacation': Color(0xFFFFD54F),
  'payday': Color(0xFF4DB6AC),
  'personal': Color(0xFFFF8A80),
  'night_shift': Color(0xFF53C082),
  'float_shift': Color(0xFF80CBC4),
  'conference': Color(0xFFBA68C8),
};

Color colorForEventType(String eventType) {
  return _eventTypeColors[eventType] ?? AppColors.primary;
}
