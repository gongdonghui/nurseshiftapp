import 'package:flutter/material.dart';

class DaySchedule {
  const DaySchedule({
    required this.title,
    required this.timeRange,
    required this.location,
    required this.icon,
  });

  final String title;
  final String timeRange;
  final String location;
  final IconData icon;
}
