import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurseshift_ui/models/calendar_event.dart';
import 'package:nurseshift_ui/swap/swap_flow.dart';

void main() {
  final CalendarEvent event = CalendarEvent(
    id: 1,
    date: DateTime.now().add(const Duration(days: 1)),
    title: 'Regular Shift',
    startTime: '07:00:00',
    endTime: '19:00:00',
    timeRange: '7:00 AM - 7:00 PM',
    location: 'Evergreen Medical Center',
    eventType: 'day_shift',
    notes: null,
  );

  testWidgets('disables swap actions when flagged', (tester) async {
    var swapCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwapActionSheet(
            event: event,
            onViewDetails: () {},
            onSwap: () => swapCount++,
            onGiveAway: () {},
            swapEnabled: false,
            disabledMessage: 'Past shifts cannot be swapped',
          ),
        ),
      ),
    );

    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();

    expect(swapCount, 0);
    expect(find.text('Past shifts cannot be swapped'), findsOneWidget);
  });

  testWidgets('invokes actions when swapping is allowed', (tester) async {
    var swapCount = 0;
    var giveawayCount = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SwapActionSheet(
            event: event,
            onViewDetails: () {},
            onSwap: () => swapCount++,
            onGiveAway: () => giveawayCount++,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Swap'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Give Away'));
    await tester.pumpAndSettle();

    expect(swapCount, 1);
    expect(giveawayCount, 1);
  });
}
