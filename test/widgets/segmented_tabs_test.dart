import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nurseshift_ui/theme/app_colors.dart';
import 'package:nurseshift_ui/widgets/segmented_tabs.dart';

void main() {
  group('SegmentedTabs', () {
    testWidgets('renders every provided tab', (tester) async {
      const tabs = ['My Events', 'Swaps', 'Open Shifts'];

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SegmentedTabs(
              tabs: tabs,
              activeIndex: 0,
              onChanged: _noop,
            ),
          ),
        ),
      );

      for (final label in tabs) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('passes selected index back through onChanged', (tester) async {
      var tappedIndex = -1;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SegmentedTabs(
              tabs: const ['My Events', 'Swaps'],
              activeIndex: 0,
              onChanged: (value) => tappedIndex = value,
            ),
          ),
        ),
      );

      await tester.tap(find.text('Swaps'));
      await tester.pumpAndSettle();

      expect(tappedIndex, 1);
    });

    testWidgets('applies the highlight color to the active tab', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SegmentedTabs(
              tabs: ['My Events', 'Swaps'],
              activeIndex: 1,
              onChanged: _noop,
            ),
          ),
        ),
      );

      final swapsText = tester.widget<Text>(find.text('Swaps'));
      final myEventsText = tester.widget<Text>(find.text('My Events'));

      expect(swapsText.style?.color, AppColors.primary);
      expect(myEventsText.style?.color, isNot(AppColors.primary));
    });
  });
}

void _noop(int _) {}
