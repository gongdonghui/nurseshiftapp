import 'package:flutter/material.dart';

import 'add_event_page.dart';
import 'day_detail_page.dart';
import 'models/calendar_event.dart';
import 'models/colleague.dart';
import 'models/day_schedule.dart';
import 'services/calendar_api.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'theme/app_theme.dart';
import 'widgets/bottom_nav_bar.dart';
import 'widgets/day_detail_card.dart';
import 'widgets/month_calendar.dart';
import 'widgets/nurse_button.dart';
import 'widgets/nurse_cards.dart';
import 'widgets/nurse_text_field.dart';
import 'widgets/segmented_tabs.dart';
import 'models/swap_request.dart';
import 'utils/event_type_icon.dart';
import 'swap/swap_flow.dart';

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
  DateTime _focusedMonth = DateTime(2025, 11);
  late DateTime _selectedDate;
  final CalendarApiClient _apiClient = CalendarApiClient();
  List<CalendarEvent> _events = [];
  bool _isLoadingEvents = false;
  String? _loadError;
  int _activeEventsRequestId = 0;
  static const List<String> _swapShiftTypes = [
    'Day shift',
    'Evening shift',
    'Night shift',
  ];
  List<SwapRequest> _swapRequests = [];
  bool _isLoadingSwapRequests = false;
  String? _swapLoadError;
  List<Colleague> _colleagues = [];
  bool _isLoadingColleagues = false;
  String? _colleagueError;
  bool _hasLoadedColleagues = false;
  static const List<Map<String, String>> _swapInstructions = [
    {
      'title': 'Select the shift you want to get rid of',
      'description':
          'Open the NurseGrid calendar, navigate to the right date, and tap the shift to open its details.',
    },
    {
      'title': 'Choose Swap or Give Away',
      'description':
          'On the shift details screen, tap Swap to trade or Give Away to offer coverage.',
    },
    {
      'title': 'Tell NurseShift what you can work instead',
      'description':
          'Specify acceptable shift types, times, or date ranges. Leave it blank if you are flexible.',
    },
    {
      'title': 'Choose who can see your swap',
      'description':
          'Broadcast to all eligible colleagues, staffing pools, or target specific coworkers.',
    },
    {
      'title': 'Send or retract the request',
      'description':
          'Publish the swap/give away. Return to this shift any time to retract or edit the request.',
    },
  ];

  static const List<String> _monthNames = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime(_focusedMonth.year, _focusedMonth.month, 12);
    _loadEvents(_focusedMonth);
    _loadSwapRequests(_focusedMonth);
  }

  @override
  void dispose() {
    super.dispose();
  }

  Map<int, CalendarDayData> get _dayHighlights {
    final Color highlight = AppColors.primary.withAlpha(26);
    final Map<int, CalendarDayData> highlights = {};
    for (final CalendarEvent event in _events) {
      if (event.date.year == _focusedMonth.year &&
          event.date.month == _focusedMonth.month) {
        highlights[event.date.day] = CalendarDayData(
          icon: event.toDaySchedule().icon,
          iconColor: AppColors.primary,
          highlightColor: highlight,
        );
      }
    }
    return highlights;
  }

  CalendarEvent? get _selectedEvent => _eventForDate(_selectedDate);

  DaySchedule? get _selectedSchedule =>
      _selectedEvent?.toDaySchedule();

  List<SwapRequest> get _selectedSwapRequests {
    final CalendarEvent? event = _eventForDate(_selectedDate);
    if (event == null) return const [];
    return _swapRequests
        .where((request) => request.event.id == event.id)
        .toList();
  }

  List<CalendarEvent> get _currentMonthEvents => _events
      .where((event) =>
          event.date.year == _focusedMonth.year &&
          event.date.month == _focusedMonth.month)
      .toList();

  String get _focusedMonthLabel => _formatMonth(_focusedMonth);

  String _formatMonth(DateTime value) =>
      '${_monthNames[value.month - 1]} ${value.year}';

  bool get _hasSelectedShift => _selectedEvent != null;

  bool get _canSwapSelectedShift =>
      _hasSelectedShift && !_isPastDate(_selectedDate);

  bool _isPastDate(DateTime date) {
    final DateTime now = DateTime.now();
    final DateTime today = DateTime(now.year, now.month, now.day);
    return date.isBefore(today);
  }

  void _goToPreviousMonth() => _changeMonth(-1);

  void _goToNextMonth() => _changeMonth(1);

  void _changeMonth(int offset) {
    final DateTime newMonth =
        DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    final int daysInNewMonth =
        DateUtils.getDaysInMonth(newMonth.year, newMonth.month);
    final int newDay =
        _selectedDate.day > daysInNewMonth ? daysInNewMonth : _selectedDate.day;
    setState(() {
      _focusedMonth = newMonth;
      _selectedDate = DateTime(newMonth.year, newMonth.month, newDay);
    });
    _loadEvents(newMonth);
    _loadSwapRequests(newMonth);
  }

  void _handleDaySelected(DateTime date) {
    setState(() => _selectedDate = date);
    final CalendarEvent? event = _eventForDate(date);
    if (calendarTab == 0) {
      _openDayDetailPage(date);
    } else if (calendarTab == 1 && event != null) {
      _showSwapOptions(event);
    }
  }

  void _handleBottomNavTap(int value) {
    setState(() => bottomNavIndex = value);
    if (value == 1 && !_hasLoadedColleagues) {
      _loadColleagues();
    }
  }

  Future<void> _openDayDetailPage(DateTime date) async {
    final CalendarEvent? event = _eventForDate(date);
    final bool hasPendingSwap = event == null
        ? false
        : _swapRequests.any(
            (request) =>
                request.event.id == event.id &&
                request.status == SwapRequestStatus.pending,
          );
    final DayDetailResult? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DayDetailPage(
          date: date,
          schedule: event?.toDaySchedule(),
          event: event,
          apiClient: _apiClient,
          hasPendingSwap: hasPendingSwap,
        ),
      ),
    );
    if (result != null) {
      await _loadEvents();
      await _loadSwapRequests();
      if (!mounted) return;
      setState(() => _selectedDate = result.event?.date ?? result.date);
    }
  }

  Future<void> _openAddEventPage({DateTime? initialDate}) async {
    final CalendarEvent? event = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          apiClient: _apiClient,
          initialDate: initialDate ?? _selectedDate,
        ),
      ),
    );
    if (event != null) {
      await _loadEvents();
      if (!mounted) return;
      setState(() => _selectedDate = event.date);
    }
  }

  void _showComingSoon(String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  CalendarEvent? _eventForDate(DateTime date) {
    for (final CalendarEvent event in _events) {
      if (DateUtils.isSameDay(event.date, date)) {
        return event;
      }
    }
    return null;
  }

  Future<void> _loadEvents([DateTime? month]) async {
    final DateTime targetMonth = month ?? _focusedMonth;
    final int requestId = ++_activeEventsRequestId;
    setState(() {
      _isLoadingEvents = true;
      _loadError = null;
    });
    try {
      final List<CalendarEvent> events =
          await _apiClient.fetchEventsForMonth(targetMonth);
      if (!mounted) return;
      if (requestId != _activeEventsRequestId) return;
      setState(() {
        _events = events;
        if (_events.isNotEmpty &&
            !_events.any(
                (event) => DateUtils.isSameDay(event.date, _selectedDate))) {
          _selectedDate = _events.first.date;
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      if (requestId != _activeEventsRequestId) return;
      setState(() => _loadError = error.message);
    } catch (error) {
      if (!mounted) return;
      if (requestId != _activeEventsRequestId) return;
      setState(() => _loadError = 'Failed to load events: $error');
    } finally {
      if (!mounted) return;
      if (requestId != _activeEventsRequestId) return;
      setState(() => _isLoadingEvents = false);
    }
  }

  Future<void> _loadSwapRequests([DateTime? month]) async {
    final DateTime targetMonth = month ?? _focusedMonth;
    setState(() {
      _isLoadingSwapRequests = true;
      _swapLoadError = null;
    });
    try {
      final List<SwapRequest> requests =
          await _apiClient.fetchSwapRequestsForMonth(targetMonth);
      if (!mounted) return;
      setState(() => _swapRequests = requests);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _swapLoadError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _swapLoadError = 'Failed to load swaps: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingSwapRequests = false);
    }
  }

  Future<void> _loadColleagues() async {
    setState(() {
      _isLoadingColleagues = true;
      _colleagueError = null;
    });
    try {
      final List<Colleague> results = await _apiClient.fetchColleagues();
      if (!mounted) return;
      setState(() {
        _colleagues = results;
        _hasLoadedColleagues = true;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _colleagueError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _colleagueError = 'Failed to load colleagues: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingColleagues = false);
    }
  }

  Future<void> _showSwapOptions(CalendarEvent event) {
    final bool canSwap = !_isPastDate(event.date);
    return showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => SwapActionSheet(
        event: event,
        onViewDetails: () {
          Navigator.of(sheetContext).pop();
          _openDayDetailPage(event.date);
        },
        onSwap: () {
          Navigator.of(sheetContext).pop();
          _openSwapPreferences(event);
        },
        onGiveAway: () {
          Navigator.of(sheetContext).pop();
          _openGiveawayFlow(event);
        },
        swapEnabled: canSwap,
        disabledMessage: canSwap
            ? null
            : 'This shift has already passed. Swaps and giveaways are only available for upcoming shifts.',
      ),
    );
  }

  Future<void> _openGiveawayFlow(CalendarEvent event) async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => GiveawayPage(
          event: event,
          apiClient: _apiClient,
        ),
      ),
    );
    if (created == true) {
      await _loadSwapRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Giveaway request sent')),
      );
    }
  }

  Future<void> _openAddColleagueSheet() async {
    final Colleague? colleague = await showModalBottomSheet<Colleague>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddColleagueSheet(apiClient: _apiClient),
    );
    if (colleague != null && mounted) {
      setState(() {
        _colleagues = [colleague, ..._colleagues];
        _hasLoadedColleagues = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${colleague.name} added to colleagues')),
      );
    }
  }

  Future<void> _openSwapPreferences(CalendarEvent event) async {
    final bool? created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SwapPreferencesPage(
          event: event,
          apiClient: _apiClient,
          shiftTypes: _swapShiftTypes,
        ),
      ),
    );
    if (created == true) {
      await _loadSwapRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Swap request sent')),
      );
    }
  }

  Future<void> _confirmRetract(int requestId) async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => _RetractSheet(
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (confirmed == true) {
      await _retractRequest(requestId);
    }
  }

  Future<void> _retractRequest(int requestId) async {
    try {
      await _apiClient.retractSwapRequest(requestId);
      await _loadSwapRequests();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request retracted')),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to retract request: $error')),
      );
    }
  }

  Widget _buildActiveTab() {
    if (calendarTab == 0) return _buildMyEventsCard();
    if (calendarTab == 1) return _buildSwapCard();
    return _buildComingSoonCard(
      title: 'Open Shifts',
      description:
          'Browse available shifts from your facility and respond with a tap.',
      primaryActionLabel: 'Refresh',
    );
  }

  Widget _buildMyEventsCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_focusedMonthLabel, style: AppTextStyles.headingLarge),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a date to review your shifts.',
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              _MonthNavigationButton(
                icon: Icons.chevron_left,
                tooltip: 'Previous month',
                onPressed: _goToPreviousMonth,
              ),
              const SizedBox(width: 8),
              _MonthNavigationButton(
                icon: Icons.chevron_right,
                tooltip: 'Next month',
                onPressed: _goToNextMonth,
              ),
              IconButton(
                onPressed: () {},
                tooltip: 'Filters',
                icon: const Icon(Icons.tune),
              ),
              IconButton(
                onPressed: () {},
                tooltip: 'Notifications',
                icon: const Icon(Icons.notifications_none),
              ),
            ],
          ),
          const SizedBox(height: 24),
          MonthCalendar(
            month: _focusedMonth,
            selectedDate: _selectedDate,
            dayData: _dayHighlights,
            onDaySelected: _handleDaySelected,
          ),
          if (_isLoadingEvents) ...[
            const SizedBox(height: 12),
            const LinearProgressIndicator(),
          ],
          if (_loadError != null) ...[
            const SizedBox(height: 12),
            _InlineError(
              message: _loadError!,
              onRetry: _loadEvents,
            ),
          ],
          const SizedBox(height: 24),
          DayDetailCard(
            date: _selectedDate,
            schedule: _selectedSchedule,
            onViewMore: () => _showComingSoon('View more'),
            onViewSwaps:
                _canSwapSelectedShift ? () => setState(() => calendarTab = 1) : null,
          ),
          if (_selectedSwapRequests.any(
            (request) => request.status == SwapRequestStatus.pending,
          )) ...[
            const SizedBox(height: 12),
            _RetractBanner(
              onPressed: () => _confirmRetract(
                _selectedSwapRequests
                    .firstWhere((request) =>
                        request.status == SwapRequestStatus.pending)
                    .id,
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            width: double.infinity,
            child: NurseButton(
              label: 'Add Event',
              onPressed: _openAddEventPage,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSwapCard() {
    final List<SwapRequest> selectedSwapRequests = _selectedSwapRequests;
    final List<CalendarEvent> monthEvents = _currentMonthEvents;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _focusedMonthLabel,
                      style: AppTextStyles.headingLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap a shift on the calendar to swap or give it away.',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              _MonthNavigationButton(
                icon: Icons.chevron_left,
                tooltip: 'Previous month',
                onPressed: _goToPreviousMonth,
              ),
              const SizedBox(width: 8),
              _MonthNavigationButton(
                icon: Icons.chevron_right,
                tooltip: 'Next month',
                onPressed: _goToNextMonth,
              ),
            ],
          ),
          const SizedBox(height: 16),
          MonthCalendar(
            month: _focusedMonth,
            selectedDate: _selectedDate,
            dayData: _dayHighlights,
            onDaySelected: _handleDaySelected,
          ),
          const SizedBox(height: 16),
          DayDetailCard(
            date: _selectedDate,
            schedule: _selectedSchedule,
            onViewMore: () => _showComingSoon('Shift details'),
            onViewSwaps: _canSwapSelectedShift
                ? () => setState(() => calendarTab = 1)
                : null,
          ),
          if (_hasSelectedShift && !_canSwapSelectedShift) ...[
            const SizedBox(height: 12),
            const _SwapUnavailableBanner(),
          ],
          if (selectedSwapRequests.any(
            (request) => request.status == SwapRequestStatus.pending,
          )) ...[
            const SizedBox(height: 12),
            _RetractBanner(
              onPressed: () => _confirmRetract(
                selectedSwapRequests
                    .firstWhere((request) =>
                        request.status == SwapRequestStatus.pending)
                    .id,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Your scheduled shifts',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 12),
          if (monthEvents.isEmpty)
            Text(
              'No shifts have been added for ${_focusedMonthLabel.toLowerCase()}.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Column(
              children: [
                for (final CalendarEvent event in monthEvents) ...[
                  _ShiftSelectorTile(
                    event: event,
                    isSelected: DateUtils.isSameDay(event.date, _selectedDate),
                    onTap: () => _handleDaySelected(event.date),
                  ),
                  const SizedBox(height: 8),
                ],
              ],
            ),
          const SizedBox(height: 24),
          Text(
            'Existing requests for this shift',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 12),
          if (_isLoadingSwapRequests)
            const LinearProgressIndicator()
          else if (_swapLoadError != null)
            _InlineError(
              message: _swapLoadError!,
              onRetry: _loadSwapRequests,
            )
          else if (selectedSwapRequests.isEmpty)
            Text(
              'No pending swap or give away requests for this shift yet.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            )
          else
            Column(
              children: [
                for (final SwapRequest request in selectedSwapRequests) ...[
                  _SwapRequestCard(request: request),
                  const SizedBox(height: 12),
                ],
              ],
            ),
          const SizedBox(height: 24),
          Text(
            'How swapping works',
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 12),
          ...List.generate(
            _swapInstructions.length,
            (index) => Padding(
              padding: EdgeInsets.only(
                  bottom: index == _swapInstructions.length - 1 ? 0 : 12),
              child: _InstructionStep(
                index: index + 1,
                title: _swapInstructions[index]['title']!,
                description: _swapInstructions[index]['description']!,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComingSoonCard({
    required String title,
    required String description,
    required String primaryActionLabel,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 32,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.headingLarge),
          const SizedBox(height: 8),
          Text(description, style: AppTextStyles.body),
          const SizedBox(height: 16),
          SizedBox(
            height: 52,
            child: NurseButton(
              label: primaryActionLabel,
              onPressed: () => _showComingSoon(primaryActionLabel),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildColleaguesBody() {
    if (_colleagueError != null && _colleagues.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _InlineError(
            message: _colleagueError!,
            onRetry: _loadColleagues,
          ),
        ),
      );
    }

    final List<Widget> children = [
      Text('Stay connected with your team', style: AppTextStyles.headingLarge),
      const SizedBox(height: 8),
      Text(
        'Add colleagues so you can quickly reach out when you need coverage.',
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      if (_colleagueError != null)
        _InlineError(message: _colleagueError!, onRetry: _loadColleagues),
      if (_isLoadingColleagues && _colleagues.isEmpty) ...[
        const SizedBox(height: 32),
        const Center(child: CircularProgressIndicator()),
      ] else if (_colleagues.isEmpty) ...[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('No colleagues yet', style: AppTextStyles.headingMedium),
              const SizedBox(height: 6),
              Text(
                'Add your go-to teammates to share swaps faster.',
                style:
                    AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ] else ...[
        Column(
          children: [
            for (final Colleague colleague in _colleagues) ...[
              ColleagueSuggestionCard(
                name: colleague.name,
                department: colleague.department,
                facility: colleague.facility,
                buttonLabel: 'Message',
                onConnect: () => _showComingSoon('Messaging'),
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
        if (_isLoadingColleagues) const LinearProgressIndicator(),
      ],
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        width: double.infinity,
        child: NurseButton(
          label: 'Add Colleague',
          leading: const Icon(Icons.person_add_alt_1_rounded),
          onPressed: _openAddColleagueSheet,
        ),
      ),
    ];

    return RefreshIndicator(
      onRefresh: _loadColleagues,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: children,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: NurseBottomNav(
        items: const [
          NurseBottomNavItem(Icons.calendar_today, 'Calendar'),
          NurseBottomNavItem(Icons.groups_rounded, 'Colleagues'),
          NurseBottomNavItem(Icons.mail_outline, 'Inbox', badgeCount: 3),
        ],
        currentIndex: bottomNavIndex,
        onTap: _handleBottomNavTap,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (bottomNavIndex == 1) {
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: const Text('Colleagues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Add colleague',
            onPressed: _openAddColleagueSheet,
          ),
        ],
      );
    }
    return AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Calendar'),
            const SizedBox(height: 2),
            Text(
              _focusedMonthLabel,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _openAddEventPage,
          ),
        ],
      );
  }

  Widget _buildBody() {
    if (bottomNavIndex == 1) {
      return SafeArea(child: _buildColleaguesBody());
    }
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SegmentedTabs(
                    tabs: const ['My Events', 'Swaps', 'Open Shifts'],
                    activeIndex: calendarTab,
                    onChanged: (value) => setState(() => calendarTab = value),
                  ),
                  const SizedBox(height: 24),
                  _buildActiveTab(),
                  const SizedBox(height: 80),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              message,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: onRetry,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}

class _AddColleagueSheet extends StatefulWidget {
  const _AddColleagueSheet({required this.apiClient});

  final CalendarApiClient apiClient;

  @override
  State<_AddColleagueSheet> createState() => _AddColleagueSheetState();
}

class _AddColleagueSheetState extends State<_AddColleagueSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _facilityController = TextEditingController();
  final TextEditingController _roleController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _facilityController.dispose();
    _roleController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    final String department = _departmentController.text.trim();
    final String facility = _facilityController.text.trim();
    final String role = _roleController.text.trim();
    if (name.isEmpty || department.isEmpty || facility.isEmpty) {
      setState(() =>
          _errorMessage = 'Name, department, and facility are required.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final Colleague colleague = await widget.apiClient.createColleague(
        name: name,
        department: department,
        facility: facility,
        role: role.isEmpty ? null : role,
      );
      if (!mounted) return;
      Navigator.of(context).pop(colleague);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to add colleague: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final EdgeInsets padding = MediaQuery.of(context).viewInsets;
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          padding.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Add colleague', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            NurseTextField(
              label: 'Full name',
              controller: _nameController,
            ),
            const SizedBox(height: 12),
            NurseTextField(
              label: 'Department',
              controller: _departmentController,
            ),
            const SizedBox(height: 12),
            NurseTextField(
              label: 'Facility',
              controller: _facilityController,
            ),
            const SizedBox(height: 12),
            NurseTextField(
              label: 'Role (optional)',
              controller: _roleController,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(
                _errorMessage!,
                style: AppTextStyles.body.copyWith(color: Colors.red),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: NurseButton(
                label: _isSaving ? 'Saving...' : 'Save',
                onPressed: _isSaving ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InstructionStep extends StatelessWidget {
  const _InstructionStep({
    required this.index,
    required this.title,
    required this.description,
  });

  final int index;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: const BoxDecoration(
            color: AppColors.primary,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$index',
              style: AppTextStyles.label.copyWith(color: Colors.white),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTextStyles.label),
              const SizedBox(height: 4),
              Text(
                description,
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SwapRequestCard extends StatelessWidget {
  const _SwapRequestCard({required this.request});

  final SwapRequest request;

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    switch (request.status) {
      case SwapRequestStatus.fulfilled:
        statusColor = AppColors.success;
        break;
      case SwapRequestStatus.retracted:
        statusColor = AppColors.textSecondary;
        break;
      case SwapRequestStatus.pending:
        statusColor = AppColors.primary;
        break;
    }
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                request.mode.label,
                style: AppTextStyles.label,
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  request.status.label,
                  style: AppTextStyles.caption.copyWith(color: statusColor),
                ),
              ),
              const Spacer(),
              Text(
                request.event.timeRange,
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Wants: ${request.desiredShiftType}',
            style: AppTextStyles.body,
          ),
          const SizedBox(height: 4),
          Text(
            'Audience: ${request.audienceDescription}',
            style: AppTextStyles.caption,
          ),
          if (request.availableStartDate != null ||
              request.availableStartTime != null) ...[
            const SizedBox(height: 4),
            Text(
              _formatAvailability(request),
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (request.notes != null && request.notes!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              request.notes!,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }

  String _formatAvailability(SwapRequest request) {
    final StringBuffer buffer = StringBuffer('Available ');
    if (request.availableStartDate != null) {
      buffer.write(
        'between ${_humanDate(request.availableStartDate!)}'
        '${request.availableEndDate != null ? ' – ${_humanDate(request.availableEndDate!)}' : ''}',
      );
    }
    if (request.availableStartTime != null ||
        request.availableEndTime != null) {
      if (request.availableStartDate != null) {
        buffer.write(' · ');
      }
      final String start = request.availableStartTime != null
          ? _timeLabel(request.availableStartTime!)
          : 'any';
      final String end = request.availableEndTime != null
          ? _timeLabel(request.availableEndTime!)
          : 'any';
      buffer.write('between $start – $end');
    }
    return buffer.toString();
  }

  String _humanDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';

  String _timeLabel(TimeOfDay time) {
    final int hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
}

class _ShiftSelectorTile extends StatelessWidget {
  const _ShiftSelectorTile({
    required this.event,
    required this.isSelected,
    required this.onTap,
  });

  final CalendarEvent event;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color:
          isSelected ? AppColors.primary.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Icon(
                iconForEventType(event.eventType),
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.title,
                      style: AppTextStyles.label.copyWith(
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${event.date.day}/${event.date.month} • ${event.timeRange}',
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                color: isSelected ? AppColors.primary : AppColors.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RetractBanner extends StatelessWidget {
  const _RetractBanner({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                'Retract Swap or Give Away',
                style: AppTextStyles.label.copyWith(color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwapUnavailableBanner extends StatelessWidget {
  const _SwapUnavailableBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        'This shift already happened. Swap or give away requests are only available for upcoming shifts.',
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
    );
  }
}

class _RetractSheet extends StatelessWidget {
  const _RetractSheet({required this.onConfirm});

  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Retract request?', style: AppTextStyles.headingMedium),
            const SizedBox(height: 8),
            Text(
              'No one has accepted this swap yet. You can retract it now and make changes later.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: 'Retract request',
                style: NurseButtonStyle.secondary,
                onPressed: onConfirm,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: 'Keep request active',
                style: NurseButtonStyle.ghost,
                onPressed: () => Navigator.of(context).pop(false),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthNavigationButton extends StatelessWidget {
  const _MonthNavigationButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final Widget button = Material(
      color: AppColors.surfaceMuted,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          height: 36,
          width: 36,
          child: Icon(icon, size: 20, color: AppColors.textPrimary),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}
