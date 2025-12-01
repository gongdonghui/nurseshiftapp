import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nurseshift_ui/day_detail_page.dart';
import 'package:nurseshift_ui/models/calendar_event.dart';
import 'package:nurseshift_ui/services/calendar_api.dart';

void main() {
  testWidgets('Day detail page scrolls when content exceeds viewport',
      (tester) async {
    final CalendarEvent event = CalendarEvent(
      id: 1,
      date: DateTime(2025, 11, 12),
      title: 'Telemetry Shift',
      startTime: '07:00:00',
      endTime: '19:00:00',
      timeRange: '7:00 AM - 7:00 PM',
      location: 'Evergreen Hospital',
      eventType: 'day_shift',
      notes:
          'Detailed notes ' * 50, // repeat text to guarantee the page is tall
    );

    await tester.pumpWidget(
      MaterialApp(
        home: DayDetailPage(
          date: event.date,
          schedule: event.toDaySchedule(),
          event: event,
          apiClient: CalendarApiClient(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final ScrollableState scrollable =
        tester.state<ScrollableState>(find.byType(Scrollable));
    final double initialOffset = scrollable.position.pixels;

    await tester.drag(
      find.byType(Scrollable),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(initialOffset));
  });
}
