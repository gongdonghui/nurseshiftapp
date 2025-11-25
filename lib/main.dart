import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/nurse_button.dart';
import 'widgets/nurse_cards.dart';
import 'widgets/nurse_text_field.dart';
import 'widgets/segmented_tabs.dart';

void main() {
  runApp(const NurseShiftApp());
}

class NurseShiftApp extends StatelessWidget {
  const NurseShiftApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NurseShift UI Kit',
      theme: buildAppTheme(),
      home: const NurseShiftDemoPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class NurseShiftDemoPage extends StatefulWidget {
  const NurseShiftDemoPage({super.key});

  @override
  State<NurseShiftDemoPage> createState() => _NurseShiftDemoPageState();
}

class _NurseShiftDemoPageState extends State<NurseShiftDemoPage> {
  int calendarTab = 0;
  int bottomNavIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Calendar'),
            SizedBox(height: 2),
            Text(
              'November 2025',
              style: TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SegmentedTabs(
                tabs: const ['My Events', 'Swaps', 'Open Shifts'],
                activeIndex: calendarTab,
                onChanged: (value) => setState(() => calendarTab = value),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: const [
                  ShiftCard(
                    dayLabel: 'Wed',
                    dateNumber: '12',
                    shiftType: 'Night Shift',
                    isHighlighted: true,
                  ),
                  ShiftCard(
                    dayLabel: 'Thu',
                    dateNumber: '13',
                    shiftType: 'Night Shift',
                    isHighlighted: true,
                  ),
                  ShiftCard(
                    dayLabel: 'Fri',
                    dateNumber: '14',
                    shiftType: 'Night Shift',
                    isHighlighted: true,
                  ),
                  ShiftCard(
                    dayLabel: 'Mon',
                    dateNumber: '25',
                    shiftType: 'Floating',
                    isHighlighted: false,
                  ),
                ],
              ),
              const SizedBox(height: 32),
              InfoCard(
                title: 'No Available Open Shifts',
                subtitle: 'You will see the open shift opportunities here.',
                icon: const Icon(Icons.calendar_month, color: Colors.black54),
                trailing: NurseButton(
                  label: 'Notify Me',
                  style: NurseButtonStyle.primary,
                  onPressed: () {},
                ),
              ),
              const SizedBox(height: 32),
              Row(
                children: const [
                  Text('Colleagues', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                  Spacer(),
                  Icon(Icons.add, color: Colors.black87),
                ],
              ),
              const SizedBox(height: 16),
              const NurseTextField(
                hint: 'Search colleagues',
                leadingIcon: Icons.search,
              ),
              const SizedBox(height: 16),
              ColleagueSuggestionCard(
                name: 'Isabel Zhang',
                department: 'Weight Management',
                facility: 'F.W. Huston Medical Center',
                onConnect: () {},
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.info_outline, size: 18, color: Colors.black54),
                  SizedBox(width: 8),
                  Text('You have reached end of suggestions.'),
                ],
              ),
              const SizedBox(height: 120),
            ],
          ),
        ),
      ),
      bottomNavigationBar: NurseBottomNav(
        items: const [
          NurseBottomNavItem(Icons.calendar_today, 'Calendar'),
          NurseBottomNavItem(Icons.groups_rounded, 'Colleagues'),
          NurseBottomNavItem(Icons.work_outline, 'Jobs'),
          NurseBottomNavItem(Icons.school_outlined, 'Learn'),
          NurseBottomNavItem(Icons.mail_outline, 'Inbox', badgeCount: 3),
        ],
        currentIndex: bottomNavIndex,
        onTap: (value) => setState(() => bottomNavIndex = value),
      ),
      floatingActionButton: NurseButton(
        label: 'Add Colleagues',
        leading: const Icon(Icons.person_add_alt_1),
        onPressed: () {},
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }
}
