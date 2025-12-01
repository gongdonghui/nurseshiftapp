import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:nurseshift_ui/event_type_selection_page.dart';

void main() {
  testWidgets('Event type list scrolls to reveal items', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: EventTypeSelectionPage(selected: defaultEventType),
      ),
    );

    await tester.pumpAndSettle();

    final scrollable = tester.state<ScrollableState>(find.byType(Scrollable));
    final initialOffset = scrollable.position.pixels;

    await tester.drag(find.byType(Scrollable), const Offset(0, -500));
    await tester.pumpAndSettle();

    expect(scrollable.position.pixels, greaterThan(initialOffset));
  });
}
