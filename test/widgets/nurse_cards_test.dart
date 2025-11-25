import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurseshift_ui/widgets/nurse_cards.dart';

void main() {
  group('ColleagueSuggestionCard', () {
    testWidgets('notifies when Connect is tapped', (tester) async {
      var connectCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ColleagueSuggestionCard(
              name: 'Isabel Zhang',
              department: 'Weight Management',
              facility: 'F.W. Huston Medical Center',
              onConnect: () => connectCount++,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();

      expect(connectCount, 1);
    });
  });

  group('InfoCard', () {
    testWidgets('renders title, subtitle and optional icon', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: InfoCard(
              title: 'No Available Open Shifts',
              subtitle: 'You will see the open shift opportunities here.',
              icon: Icon(Icons.calendar_month),
            ),
          ),
        ),
      );

      expect(find.text('No Available Open Shifts'), findsOneWidget);
      expect(find.text('You will see the open shift opportunities here.'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_month), findsOneWidget);
    });
  });
}
