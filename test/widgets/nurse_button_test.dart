import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurseshift_ui/widgets/nurse_button.dart';

void main() {
  group('NurseButton', () {
    testWidgets('invokes callback when tapped', (tester) async {
      var tapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: NurseButton(
                label: 'Add Colleague',
                onPressed: () => tapped = true,
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Add Colleague'));
      await tester.pumpAndSettle();

      expect(tapped, isTrue);
    });

    testWidgets('shows the loading indicator when requested', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NurseButton(
              label: 'Saving',
              isLoading: true,
              onPressed: null,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders leading and trailing widgets', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NurseButton(
              label: 'Invite',
              leading: const Icon(Icons.person),
              trailing: const Icon(Icons.chevron_right),
              onPressed: () {},
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.person), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });
  });
}
