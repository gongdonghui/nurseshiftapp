import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:app_links/app_links.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'add_event_page.dart';
import 'day_detail_page.dart';
import 'models/auth_session.dart';
import 'models/calendar_event.dart';
import 'models/colleague.dart';
import 'models/day_schedule.dart';
import 'models/group.dart';
import 'models/group_invite.dart';
import 'models/group_invite_link.dart';
import 'models/group_shared_row.dart';
import 'models/user.dart';
import 'models/worksite.dart';
import 'services/calendar_api.dart';
import 'invite/invite_preview_page.dart';
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
      title: 'mynurseshift',
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

enum InboxFilter { pending, fulfilled, all }

class _NurseShiftDemoPageState extends State<NurseShiftDemoPage> {
  int calendarTab = 0;
  int bottomNavIndex = 0;
  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  final CalendarApiClient _apiClient = CalendarApiClient();
  final ImagePicker _imagePicker = ImagePicker();
  final AppLinks _appLinks = AppLinks();
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
  List<SwapRequest> _inboxRequests = [];
  bool _isLoadingInbox = false;
  String? _inboxError;
  bool _hasLoadedInbox = false;
  final Set<int> _selectedInboxRequestIds = <int>{};
  final Set<int> _readInboxRequestIds = <int>{};
  bool _isProcessingInboxActions = false;
  InboxFilter _inboxFilter = InboxFilter.pending;
  List<Colleague> _colleagues = [];
  bool _isLoadingColleagues = false;
  String? _colleagueError;
  bool _hasLoadedColleagues = false;
  List<Group> _groups = [];
  bool _isLoadingGroups = false;
  String? _groupError;
  bool _hasLoadedGroups = false;
  final Map<int, String> _inviteLinksByGroupId = {};
  int? _selectedSharedGroupId;
  late DateTime _groupSharedWeekStart;
  User? _currentUser;
  bool _isAuthInProgress = false;
  bool _isRegisterMode = false;
  bool _isUpdatingAvatar = false;
  bool _acceptPrivacy = false;
  bool _acceptDisclaimer = false;
  StreamSubscription<Uri>? _inviteLinkSubscription;
  String? _pendingInviteToken;
  String? _activeInviteToken;
  static const String _pendingInviteTokenKey = 'pending_invite_token';
  String? _authError;
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
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
    final DateTime now = DateTime.now();
    _focusedMonth = DateTime(now.year, now.month);
    _selectedDate = DateTime(now.year, now.month, now.day);
    _groupSharedWeekStart = _startOfWeek(now);
    _loadPendingInviteToken();
    _initDeepLinkHandling();
  }

  @override
  void dispose() {
    _inviteLinkSubscription?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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

  bool get _isAuthenticated => _currentUser != null;

  Group? get _selectedSharedGroup {
    if (_selectedSharedGroupId == null) {
      return _groups.isNotEmpty ? _groups.first : null;
    }
    try {
      return _groups.firstWhere(
        (group) => group.id == _selectedSharedGroupId,
      );
    } catch (_) {
      return _groups.isNotEmpty ? _groups.first : null;
    }
  }

  Widget? get _userInfoLeadingButton {
    if (!_isAuthenticated) return null;
    return IconButton(
      icon: const Icon(Icons.account_circle_outlined),
      tooltip: 'Account',
      onPressed: _openUserInfoSheet,
    );
  }

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

  List<DateTime> get _currentWeekDates =>
      _datesForWeek(_startOfWeek(_selectedDate));

  List<DateTime> get _groupSharedWeekDates =>
      _datesForWeek(_groupSharedWeekStart);

  DateTime _startOfWeek(DateTime date) {
    final int difference = date.weekday % 7;
    return DateTime(date.year, date.month, date.day - difference);
  }

  List<DateTime> _datesForWeek(DateTime start) => List<DateTime>.generate(
        7,
        (index) => DateTime(start.year, start.month, start.day + index),
      );

  void _goToPreviousMonth() => _changeMonth(-1);

  void _goToNextMonth() => _changeMonth(1);

  void _shiftGroupSharedWeek(int offset) {
    if (offset == 0) return;
    final DateTime nextStart = DateTime(
      _groupSharedWeekStart.year,
      _groupSharedWeekStart.month,
      _groupSharedWeekStart.day + (offset * 7),
    );
    setState(() {
      _groupSharedWeekStart = nextStart;
    });
    _loadGroups(
      rangeStart: nextStart,
      rangeEnd: nextStart.add(const Duration(days: 6)),
    );
  }

  _WeekShareResult _rowsForWeek(Group? group, DateTime weekStart) {
    if (group == null) {
      return const _WeekShareResult(shared: <GroupSharedRow>[], missing: <GroupSharedRow>[]);
    }
    final Map<String, List<GroupSharedRow>> entriesByMember = {};
    for (final GroupSharedRow row in group.sharedCalendar) {
      final String key = '${row.memberId ?? row.memberName}';
      entriesByMember.putIfAbsent(key, () => []).add(row);
    }

    final DateTime weekEnd = weekStart.add(const Duration(days: 6));
    final List<GroupSharedRow> shared = [];
    final List<GroupSharedRow> missing = [];

    for (final List<GroupSharedRow> rows in entriesByMember.values) {
      GroupSharedRow? match;
      GroupSharedRow? latest;
      for (final GroupSharedRow row in rows) {
        final DateTime? rowStart = _rowStartDate(row);
        final DateTime? rowEnd = _rowEndDate(row);
        if (rowStart == null || rowEnd == null) continue;
        if (latest == null ||
            (_rowEndDate(row) ?? rowEnd)
                .isAfter(_rowEndDate(latest) ?? latest.endDate ?? rowEnd)) {
          latest = row;
        }
        final bool overlaps =
            !(rowEnd.isBefore(weekStart) || rowStart.isAfter(weekEnd));
        if (overlaps) {
          if (match == null) {
            match = row;
          } else {
            final DateTime? existingEnd = _rowEndDate(match);
            final DateTime? candidateEnd = _rowEndDate(row);
            if (existingEnd == null ||
                (candidateEnd != null && candidateEnd.isAfter(existingEnd))) {
              match = row;
            }
          }
        }
      }
      if (match != null) {
        shared.add(match);
      } else if (latest != null) {
        missing.add(latest);
      }
    }

    return _WeekShareResult(shared: shared, missing: missing);
  }

  DateTime? _rowStartDate(GroupSharedRow row) {
    if (row.startDate != null) return row.startDate;
    if (row.entries.isNotEmpty) return row.entries.first.date;
    return null;
  }

  DateTime? _rowEndDate(GroupSharedRow row) {
    if (row.endDate != null) return row.endDate;
    if (row.entries.isNotEmpty) return row.entries.last.date;
    return null;
  }

  String _formatWeekRange(DateTime start) {
    final DateTime end = start.add(const Duration(days: 6));
    final String startMonth = _monthNames[start.month - 1];
    final String endMonth = _monthNames[end.month - 1];
    if (start.month == end.month && start.year == end.year) {
      return '$startMonth ${start.day} – ${end.day}, ${start.year}';
    }
    if (start.year == end.year) {
      return '$startMonth ${start.day} – $endMonth ${end.day}, ${start.year}';
    }
    return '$startMonth ${start.day}, ${start.year} – '
        '$endMonth ${end.day}, ${end.year}';
  }

  String _formatFullDate(DateTime date) =>
      '${_monthNames[date.month - 1]} ${date.day}, ${date.year}';

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
    } else if (value == 2 && !_hasLoadedGroups) {
      _loadGroups(
        rangeStart: _groupSharedWeekStart,
        rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
      );
    }
  }

  List<_ExistingShare> _existingSharesForUser() {
    final User? user = _currentUser;
    if (user == null) return const <_ExistingShare>[];
    final List<_ExistingShare> items = [];
    for (final Group group in _groups) {
      for (final GroupSharedRow row in group.sharedCalendar) {
        if (row.memberId == user.id &&
            row.startDate != null &&
            row.endDate != null) {
          items.add(
            _ExistingShare(
              groupId: group.id,
              groupName: group.name,
              startDate: row.startDate!,
              endDate: row.endDate!,
            ),
          );
        }
      }
    }
    return items;
  }

  String _mimeForPath(String path) {
    final String lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  Future<void> _handleAvatarTap() async {
    final User? user = _currentUser;
    if (user == null || _isUpdatingAvatar) return;
    final XFile? file = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 600,
      imageQuality: 80,
    );
    if (file == null) return;
    setState(() => _isUpdatingAvatar = true);
    try {
      final List<int> bytes = await file.readAsBytes();
      final String mime = _mimeForPath(file.path);
      final String dataUrl = 'data:$mime;base64,${base64Encode(bytes)}';
      final User updated = await _apiClient.updateAvatar(
        userId: user.id,
        avatarData: dataUrl,
      );
      if (!mounted) return;
      setState(() => _currentUser = updated);
      _showInfoMessage('Avatar updated.');
    } on ApiException catch (error) {
      if (!mounted) return;
      _showInfoMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      _showInfoMessage('Failed to update avatar: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isUpdatingAvatar = false);
    }
  }

  Future<void> _handleRemoveAvatar() async {
    final User? user = _currentUser;
    if (user == null || _isUpdatingAvatar) return;
    setState(() => _isUpdatingAvatar = true);
    try {
      final User updated = await _apiClient.updateAvatar(
        userId: user.id,
        avatarData: null,
      );
      if (!mounted) return;
      setState(() => _currentUser = updated);
      _showInfoMessage('Reverted to default avatar.');
    } on ApiException catch (error) {
      if (!mounted) return;
      _showInfoMessage(error.message);
    } catch (error) {
      if (!mounted) return;
      _showInfoMessage('Failed to update avatar: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isUpdatingAvatar = false);
    }
  }

  void _showInfoMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _openLegalDocument({
    required String title,
    required String path,
  }) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LegalDocumentPage(
          title: title,
          path: path,
          apiClient: _apiClient,
        ),
      ),
    );
  }

  Future<void> _openUserInfoSheet() async {
    final User? user = _currentUser;
    if (user == null) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => _UserInfoSheet(
        user: user,
        onWorksites: _openWorksitesSheet,
        onPrivacy: () => _showInfoMessage('Privacy settings coming soon.'),
        onLogout: () {
          Navigator.of(sheetContext).pop();
          _handleLogout();
        },
        onAvatarTap: _handleAvatarTap,
        onRemoveAvatar: user.avatarUrl == null ? null : _handleRemoveAvatar,
        isUpdatingAvatar: _isUpdatingAvatar,
      ),
    );
  }

  Future<void> _openWorksitesSheet() async {
    final User? user = _currentUser;
    if (user == null) {
      _showInfoMessage('Log in to manage worksites.');
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _WorksitesSheet(
        apiClient: _apiClient,
        user: user,
      ),
    );
  }

  void _initDeepLinkHandling() {
    () async {
      try {
        final Uri? initialUri = await _appLinks.getInitialLink();
        if (initialUri != null) {
          _handleInviteUri(initialUri);
        }
      } on PlatformException catch (error) {
        debugPrint('Failed to get initial link: $error');
      } on FormatException catch (error) {
        debugPrint('Malformed initial link: $error');
      }
      _inviteLinkSubscription = _appLinks.uriLinkStream.listen(
        (Uri uri) => _handleInviteUri(uri),
        onError: (Object error) =>
            debugPrint('Invite link stream error: $error'),
      );
    }();
  }

  void _handleInviteUri(Uri uri) {
    final String? token = _extractInviteToken(uri);
    if (token == null || token.isEmpty) return;
    _enqueueInviteToken(token);
  }

  String? _extractInviteToken(Uri uri) {
    final String scheme = uri.scheme.toLowerCase();
    if (scheme == 'nurseshift') {
      if (uri.host.toLowerCase() != 'group-invite') return null;
      return uri.queryParameters['token'];
    }
    if (uri.pathSegments.length >= 2 &&
        uri.pathSegments[0].toLowerCase() == 'ginv') {
      return uri.pathSegments[1];
    }
    return null;
  }

  Future<void> _loadPendingInviteToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? token = prefs.getString(_pendingInviteTokenKey);
    if (token == null || token.isEmpty) return;
    if (!mounted) return;
    setState(() => _pendingInviteToken = token);
  }

  Future<void> _persistPendingInviteToken(String token) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pendingInviteTokenKey, token);
  }

  Future<void> _clearPendingInviteToken() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_pendingInviteTokenKey);
  }

  void _enqueueInviteToken(String token) {
    debugPrint('Received invite token: $token');
    final User? user = _currentUser;
    if (user == null) {
      setState(() => _pendingInviteToken = token);
      _persistPendingInviteToken(token);
    }
    _openInvitePreview(token);
  }

  Future<void> _openInvitePreview(String token) async {
    if (_activeInviteToken == token) return;
    _activeInviteToken = token;
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InvitePreviewPage(
          token: token,
          apiClient: _apiClient,
          currentUser: _currentUser,
          onLogin: _completeAuthentication,
          onJoined: (String groupId) async {
            await _loadGroups(
              rangeStart: _groupSharedWeekStart,
              rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
            );
            _selectedSharedGroupId = int.tryParse(groupId);
            await _clearPendingInviteToken();
          },
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _activeInviteToken = null);
  }

  Future<void> _completeAuthentication(AuthSession session) async {
    if (!mounted) return;
    setState(() {
      _currentUser = session.user;
    });
    debugPrint('Logged in as user id ${session.user.id}');
    await _loadEvents(_focusedMonth);
    await _loadSwapRequests(_focusedMonth);
    await _loadInboxRequests();
    if (_groups.isEmpty) {
      await _loadGroups(
        rangeStart: _groupSharedWeekStart,
        rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
      );
    }
    if (_pendingInviteToken != null && _activeInviteToken == null) {
      await _openInvitePreview(_pendingInviteToken!);
    }
  }

  Future<void> _handleAuthSubmit() async {
    if (_isAuthInProgress) return;
    if (_isRegisterMode) {
      await _handleRegister();
    } else {
      await _handleLogin();
    }
  }

  Future<void> _handleLogin() async {
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _authError = 'Email and password are required.');
      return;
    }
    setState(() {
      _isAuthInProgress = true;
      _authError = null;
    });
    try {
      final AuthSession session =
          await _apiClient.login(email: email, password: password);
      await _completeAuthentication(session);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _authError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _authError = 'Failed to sign in: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isAuthInProgress = false);
    }
  }

  Future<void> _handleRegister() async {
    final String name = _nameController.text.trim();
    final String email = _emailController.text.trim();
    final String password = _passwordController.text;
    final String confirm = _confirmPasswordController.text;
    if (name.isEmpty || email.isEmpty || password.isEmpty || confirm.isEmpty) {
      setState(() => _authError = 'All fields are required.');
      return;
    }
    if (password != confirm) {
      setState(() => _authError = 'Passwords do not match.');
      return;
    }
    if (!_acceptPrivacy || !_acceptDisclaimer) {
      setState(() => _authError = 'Please accept the privacy policy and disclaimer.');
      return;
    }
    setState(() {
      _isAuthInProgress = true;
      _authError = null;
    });
    try {
      final AuthSession session = await _apiClient.register(
        name: name,
        email: email,
        password: password,
        confirmPassword: confirm,
        acceptPrivacy: _acceptPrivacy,
        acceptDisclaimer: _acceptDisclaimer,
      );
      await _completeAuthentication(session);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _authError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _authError = 'Failed to register: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isAuthInProgress = false);
    }
  }

  Future<void> _handleLogout() async {
    setState(() {
      _currentUser = null;
      _groups = [];
      _hasLoadedGroups = false;
      _selectedSharedGroupId = null;
      _events = [];
      _swapRequests = [];
      _inboxRequests = [];
      _hasLoadedInbox = false;
      _pendingInviteToken = null;
      _activeInviteToken = null;
      _inviteLinksByGroupId.clear();
    });
    try {
      await _apiClient.logout();
    } catch (_) {
      // No-op; backend logout is stateless.
    }
  }

  void _toggleAuthMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _authError = null;
      _acceptPrivacy = false;
      _acceptDisclaimer = false;
    });
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
          currentUser: _currentUser,
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
    if (!_isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Log in to add events.')),
      );
      return;
    }
    final CalendarEvent? event = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          apiClient: _apiClient,
          initialDate: initialDate ?? _selectedDate,
          currentUser: _currentUser,
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
    if (!_isAuthenticated) {
      return;
    }
    final DateTime targetMonth = month ?? _focusedMonth;
    final int requestId = ++_activeEventsRequestId;
    setState(() {
      _isLoadingEvents = true;
      _loadError = null;
    });
    try {
      final int? userId = _currentUser?.id;
      final List<CalendarEvent> events = await _apiClient.fetchEventsForMonth(
        targetMonth,
        userId: userId,
      );
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
    if (!_isAuthenticated) {
      return;
    }
    final DateTime targetMonth = month ?? _focusedMonth;
    setState(() {
      _isLoadingSwapRequests = true;
      _swapLoadError = null;
    });
    try {
      final int? userId = _currentUser?.id;
      final List<SwapRequest> requests =
          await _apiClient.fetchSwapRequestsForMonth(targetMonth, userId: userId);
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

  Future<void> _loadInboxRequests() async {
    final User? user = _currentUser;
    if (user == null) return;
    setState(() {
      _isLoadingInbox = true;
      _inboxError = null;
    });
    try {
      final List<SwapRequest> requests =
          await _apiClient.fetchInboxSwapRequests(user.id);
      if (!mounted) return;
      setState(() {
        _inboxRequests = requests;
        _hasLoadedInbox = true;
        _selectedInboxRequestIds
            .removeWhere((id) => !_inboxRequests.any((req) => req.id == id));
        _readInboxRequestIds
            .removeWhere((id) => !_inboxRequests.any((req) => req.id == id));
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _inboxError = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _inboxError = 'Failed to load inbox: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingInbox = false);
    }
  }

  Future<void> _acceptInboxRequest(int requestId) async {
    final User? user = _currentUser;
    if (user == null) return;
    try {
      await _apiClient.acceptSwapRequest(requestId: requestId, userId: user.id);
      await _loadInboxRequests();
      await _loadSwapRequests();
      _showInfoMessage('Swap request accepted.');
    } on ApiException catch (error) {
      _showInfoMessage(error.message);
    } catch (error) {
      _showInfoMessage('Failed to accept request: $error');
    }
  }

  Future<void> _declineInboxRequest(int requestId) async {
    final User? user = _currentUser;
    if (user == null) return;
    try {
      await _apiClient.declineSwapRequest(requestId: requestId, userId: user.id);
      await _loadInboxRequests();
      _showInfoMessage('Request declined.');
    } on ApiException catch (error) {
      _showInfoMessage(error.message);
    } catch (error) {
      _showInfoMessage('Failed to decline request: $error');
    }
  }

  void _toggleInboxSelection(int requestId, bool selected) {
    setState(() {
      if (selected) {
        _selectedInboxRequestIds.add(requestId);
      } else {
        _selectedInboxRequestIds.remove(requestId);
      }
    });
  }

  void _clearInboxSelection() {
    if (_selectedInboxRequestIds.isEmpty) return;
    setState(() => _selectedInboxRequestIds.clear());
  }

  void _markSelectedInboxAsRead() {
    if (_selectedInboxRequestIds.isEmpty) return;
    final int count = _selectedInboxRequestIds.length;
    setState(() {
      _readInboxRequestIds.addAll(_selectedInboxRequestIds);
      _selectedInboxRequestIds.clear();
    });
    _showInfoMessage(
      'Marked $count request${count == 1 ? '' : 's'} as read.',
    );
  }

  bool _applyInboxFilter(SwapRequest request) {
    switch (_inboxFilter) {
      case InboxFilter.pending:
        return request.status == SwapRequestStatus.pending;
      case InboxFilter.fulfilled:
        return request.status == SwapRequestStatus.fulfilled;
      case InboxFilter.all:
        return true;
    }
  }

  Future<void> _batchAcceptSelected() async {
    final User? user = _currentUser;
    if (user == null || _selectedInboxRequestIds.isEmpty) return;
    setState(() => _isProcessingInboxActions = true);
    final List<int> ids = _selectedInboxRequestIds.toList();
    try {
      for (final int id in ids) {
        await _apiClient.acceptSwapRequest(requestId: id, userId: user.id);
      }
      await _loadInboxRequests();
      await _loadSwapRequests();
      _showInfoMessage(
        'Accepted ${ids.length} request${ids.length == 1 ? '' : 's'}.',
      );
    } on ApiException catch (error) {
      _showInfoMessage(error.message);
    } catch (error) {
      _showInfoMessage('Failed to accept selected requests: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessingInboxActions = false);
      }
    }
  }

  Future<void> _batchDeclineSelected() async {
    final User? user = _currentUser;
    if (user == null || _selectedInboxRequestIds.isEmpty) return;
    setState(() => _isProcessingInboxActions = true);
    final List<int> ids = _selectedInboxRequestIds.toList();
    try {
      for (final int id in ids) {
        await _apiClient.declineSwapRequest(requestId: id, userId: user.id);
      }
      await _loadInboxRequests();
      _showInfoMessage(
        'Declined ${ids.length} request${ids.length == 1 ? '' : 's'}.',
      );
    } on ApiException catch (error) {
      _showInfoMessage(error.message);
    } catch (error) {
      _showInfoMessage('Failed to decline selected requests: $error');
    } finally {
      if (mounted) {
        setState(() => _isProcessingInboxActions = false);
      }
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

  Future<void> _loadGroups({
    DateTime? rangeStart,
    DateTime? rangeEnd,
  }) async {
    final DateTime start = rangeStart ?? _groupSharedWeekStart;
    final DateTime end = rangeEnd ?? start.add(const Duration(days: 6));
    setState(() {
      _isLoadingGroups = true;
      _groupError = null;
    });
    try {
      final List<Group> results = await _apiClient.fetchGroups(
        startDate: start,
        endDate: end,
      );
      if (!mounted) return;
      setState(() {
        _groups = results;
        _hasLoadedGroups = true;
        _selectedSharedGroupId ??=
            results.isNotEmpty ? results.first.id : null;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _groupError = error.message;
        if (_groups.isEmpty) {
          final Group sample = _sampleGroup();
          _groups = [sample];
          _selectedSharedGroupId = sample.id;
          _hasLoadedGroups = true;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _groupError = 'Failed to load groups: $error';
        if (_groups.isEmpty) {
          final Group sample = _sampleGroup();
          _groups = [sample];
          _selectedSharedGroupId = sample.id;
          _hasLoadedGroups = true;
        }
      });
    } finally {
      if (!mounted) return;
      setState(() => _isLoadingGroups = false);
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
      if (!_colleagues.any((existing) => existing.id == colleague.id)) {
        setState(() {
          _colleagues = [colleague, ..._colleagues];
          _hasLoadedColleagues = true;
        });
      }
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
    return _buildGroupSharedView();
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
              if (_isAuthenticated) ...[
                IconButton(
                  tooltip: 'Share this week',
                  icon: const Icon(Icons.share_rounded),
                  onPressed: _openShareWeekSheet,
                ),
              ],
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
          if (_isAuthenticated) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 52,
              width: double.infinity,
              child: NurseButton(
                label: 'Share this week with a group',
                style: NurseButtonStyle.secondary,
                leading: const Icon(Icons.share_rounded),
                onPressed: _openShareWeekSheet,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openShareWeekSheet() async {
    if (!_isAuthenticated) return;
    if (!_hasLoadedGroups) {
      await _loadGroups(
        rangeStart: _groupSharedWeekStart,
        rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
      );
    }
    if (_groups.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Create a group before sharing your calendar.')),
      );
      return;
    }
    final Group initialGroup = _selectedSharedGroup ?? _groups.first;
    final DateTime startOfWeek = _startOfWeek(_selectedDate);
    final DateTimeRange initialRange = DateTimeRange(
      start: startOfWeek,
      end: startOfWeek.add(const Duration(days: 6)),
    );
    final ShareSheetResult? result = await showModalBottomSheet<ShareSheetResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _ShareWeekSheet(
        groups: _groups,
        initialGroupId: initialGroup.id,
        initialRange: initialRange,
        existingShares: _existingSharesForUser(),
      ),
    );
    if (!mounted || result == null || _currentUser == null) return;
    if (result.isCancellation) {
      await _cancelSharedRange(result.groupId, result.startDate, result.endDate);
      return;
    }
    await _shareRange(result.groupId, result.startDate, result.endDate);
  }

  Future<void> _shareRange(
    int groupId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final User? user = _currentUser;
    if (user == null) return;
    try {
      final Group updated = await _apiClient.shareGroupWeek(
        groupId: groupId,
        userId: user.id,
        startDate: startDate,
        endDate: endDate,
      );
      if (!mounted) return;
      _upsertGroup(updated);
      setState(() => _selectedSharedGroupId = groupId);
      final Group? target =
          _groups.firstWhere((group) => group.id == groupId, orElse: () => updated);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Shared your calendar with ${target?.name ?? 'the group'}')),
      );
      await _loadGroups(
        rangeStart: _groupSharedWeekStart,
        rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share schedule: $error')),
      );
    }
  }

  Future<void> _cancelSharedRange(
    int groupId,
    DateTime startDate,
    DateTime endDate,
  ) async {
    final User? user = _currentUser;
    if (user == null) return;
    try {
      final Group updated = await _apiClient.cancelGroupShare(
        groupId: groupId,
        userId: user.id,
        startDate: startDate,
        endDate: endDate,
      );
      if (!mounted) return;
      _upsertGroup(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Stopped sharing your calendar.')),
      );
      await _loadGroups(
        rangeStart: _groupSharedWeekStart,
        rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to cancel sharing: $error')),
      );
    }
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

  
  Widget _buildGroupSharedView() {
    if (!_hasLoadedGroups && !_isLoadingGroups) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_hasLoadedGroups && !_isLoadingGroups) {
          _loadGroups(
            rangeStart: _groupSharedWeekStart,
            rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
          );
        }
      });
    }
    final Group? selectedGroup = _selectedSharedGroup;
    final List<Group> groups = _groups;
    final List<DateTime> weekDates = _groupSharedWeekDates;
    final DateTime weekStart = _groupSharedWeekStart;
    final _WeekShareResult weekResult = _rowsForWeek(selectedGroup, weekStart);
    final List<GroupSharedRow> rowsForWeek = weekResult.shared;
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
          if (groups.isEmpty && _isLoadingGroups) ...[
            const Center(child: CircularProgressIndicator()),
          ] else if (groups.isEmpty) ...[
            Text(
              'No groups available. Create one to start sharing schedules.',
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ] else ...[
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                PopupMenuButton<int>(
                  onSelected: (value) {
                    setState(() => _selectedSharedGroupId = value);
                  },
                  itemBuilder: (context) => [
                    for (final Group group in groups)
                      PopupMenuItem<int>(
                        value: group.id,
                        child: Text(group.name),
                      ),
                  ],
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          Text(selectedGroup?.name ?? groups.first.name),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down_rounded),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: selectedGroup == null
                      ? null
                      : () => _openInviteMemberSheet(selectedGroup),
                  icon: const Icon(Icons.person_add_alt_1_rounded),
                  label: const Text('Invite'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    _formatWeekRange(weekStart),
                    style: AppTextStyles.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Previous week',
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => _shiftGroupSharedWeek(-1),
                ),
                IconButton(
                  tooltip: 'Next week',
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => _shiftGroupSharedWeek(1),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (selectedGroup == null) ...[
              Text(
                'Select a group to see everyone’s schedule.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ] else if (selectedGroup.sharedCalendar.isEmpty) ...[
              Text(
                'No shared calendar data yet. Ask members to publish their week.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ] else if (rowsForWeek.isEmpty) ...[
              Text(
                'No members have shared this week yet.',
                style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
              ),
            ] else ...[
              GestureDetector(
                onHorizontalDragEnd: (details) {
                  final double? velocity = details.primaryVelocity;
                  if (velocity == null) return;
                  if (velocity < -50) {
                    _shiftGroupSharedWeek(1);
                  } else if (velocity > 50) {
                    _shiftGroupSharedWeek(-1);
                  }
                },
                child: _GroupSharedMatrix(
                  rows: rowsForWeek,
                  dates: weekDates,
                ),
              ),
            ],
          ],
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

  Widget _buildInboxBody() {
    final List<SwapRequest> visibleRequests = _inboxRequests
        .where((request) => !_readInboxRequestIds.contains(request.id))
        .where(_applyInboxFilter)
        .toList();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadInboxRequests,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Inbox', style: AppTextStyles.headingLarge),
                    const SizedBox(height: 8),
                    Text(
                      'Review swap requests directed to you.',
                      style: AppTextStyles.body
                          .copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 20),
                    _InboxSummaryCard(
                      total: _inboxRequests.length,
                      pending: _inboxRequests
                          .where((request) =>
                              request.status == SwapRequestStatus.pending)
                          .length,
                      fulfilled: _inboxRequests
                          .where((request) =>
                              request.status == SwapRequestStatus.fulfilled)
                          .length,
                    ),
                    const SizedBox(height: 16),
                    _InboxFilterChips(
                      activeFilter: _inboxFilter,
                      onChanged: (value) => setState(() => _inboxFilter = value),
                    ),
                    const SizedBox(height: 16),
                    if (_selectedInboxRequestIds.isNotEmpty)
                      _InboxSelectionActions(
                        count: _selectedInboxRequestIds.length,
                        onClear: _isProcessingInboxActions
                            ? null
                            : _clearInboxSelection,
                        onAccept: _isProcessingInboxActions
                            ? null
                            : _batchAcceptSelected,
                        onDecline: _isProcessingInboxActions
                            ? null
                            : _batchDeclineSelected,
                        onMarkRead: _isProcessingInboxActions
                            ? null
                            : _markSelectedInboxAsRead,
                        isProcessing: _isProcessingInboxActions,
                      ),
                    if (_selectedInboxRequestIds.isNotEmpty)
                      const SizedBox(height: 16),
                    if (_isLoadingInbox)
                      const Center(child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: CircularProgressIndicator(),
                      ))
                    else if (_inboxError != null)
                      _InlineError(
                        message: _inboxError!,
                        onRetry: _loadInboxRequests,
                      )
                    else if (visibleRequests.isEmpty)
                      Text(
                        'No requests for this filter. Try selecting another category.',
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
            ),
            if (!_isLoadingInbox && _inboxError == null && visibleRequests.isNotEmpty)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final SwapRequest request = visibleRequests[index];
                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: index == visibleRequests.length - 1 ? 0 : 16,
                        ),
                        child: _InboxRequestCard(
                          request: request,
                          eventDateLabel: _formatFullDate(request.event.date),
                          isOwnedRequest: _currentUser != null &&
                              request.ownerEmail != null &&
                              request.ownerEmail!.toLowerCase() ==
                                  _currentUser!.email.toLowerCase(),
                          isSelected:
                              _selectedInboxRequestIds.contains(request.id),
                          onSelectionChanged: (value) =>
                              _toggleInboxSelection(request.id, value ?? false),
                          onAccept: _isProcessingInboxActions
                              ? null
                              : () => _acceptInboxRequest(request.id),
                          onDecline: _isProcessingInboxActions
                              ? null
                              : () => _declineInboxRequest(request.id),
                          actionsDisabled: _isProcessingInboxActions,
                        ),
                      );
                    },
                    childCount: visibleRequests.length,
                  ),
                ),
              ),
          ],
        ),
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
                buttonLabel: colleague.status == ColleagueStatus.accepted
                    ? 'Message'
                    : 'Copy Invite',
                onConnect: () {
                  if (colleague.status == ColleagueStatus.accepted) {
                    _showComingSoon('Messaging');
                  } else {
                    _copyColleagueInvite(colleague);
                  }
                },
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

  Widget _buildGroupsBody() {
    if (_groupError != null && _groups.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: _InlineError(
            message: _groupError!,
            onRetry: () => _loadGroups(
              rangeStart: _groupSharedWeekStart,
              rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
            ),
          ),
        ),
      );
    }
    final List<Widget> children = [
      Text('Coordinate with your teams', style: AppTextStyles.headingLarge),
      const SizedBox(height: 8),
      Text(
        'Create shared groups for units or pods to streamline swaps.',
        style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
      ),
      const SizedBox(height: 16),
      if (_groupError != null)
        _InlineError(
          message: _groupError!,
          onRetry: () => _loadGroups(
            rangeStart: _groupSharedWeekStart,
            rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
          ),
        ),
      if (_isLoadingGroups && _groups.isEmpty) ...[
        const SizedBox(height: 40),
        const Center(child: CircularProgressIndicator()),
      ] else if (_groups.isEmpty) ...[
        InfoCard(
          title: 'No groups yet',
          subtitle: 'Spin up a group so everyone sees swap updates at once.',
          icon: const Icon(Icons.groups_2_rounded, color: AppColors.primary),
          trailing: IconButton(
            onPressed: _openCreateGroupSheet,
            icon: const Icon(Icons.add),
          ),
        ),
      ] else ...[
        Column(
          children: [
            for (final Group group in _groups) ...[
              _GroupCard(
                group: group,
                onInvite: () => _openInviteMemberSheet(group),
                onCopyInvite: () => _copyGroupInvite(group),
                onCopyInviteLink: (invite) =>
                    _copyGroupInvite(group, invite: invite),
                currentUser: _currentUser,
                onAcceptInvite: (invite) =>
                    _respondToGroupInvite(invite: invite, accept: true),
                onDeclineInvite: (invite) =>
                    _respondToGroupInvite(invite: invite, accept: false),
                onDelete: () => _confirmDeleteGroup(group),
              ),
              const SizedBox(height: 16),
            ],
          ],
        ),
        if (_isLoadingGroups) const LinearProgressIndicator(),
      ],
      const SizedBox(height: 24),
      SizedBox(
        height: 52,
        width: double.infinity,
        child: NurseButton(
          label: 'Create Group',
          leading: const Icon(Icons.groups_2_rounded),
          onPressed: _openCreateGroupSheet,
        ),
      ),
    ];

    return RefreshIndicator(
      onRefresh: () => _loadGroups(
        rangeStart: _groupSharedWeekStart,
        rangeEnd: _groupSharedWeekStart.add(const Duration(days: 6)),
      ),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: children,
      ),
    );
  }

  Future<void> _copyColleagueInvite(Colleague colleague) async {
    final String invite = colleague.invitationMessage ??
        'Join me on NurseShift so we can swap coverage more easily!';
    await Clipboard.setData(ClipboardData(text: invite));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Copied invite message for ${colleague.name}'),
        action: SnackBarAction(
          label: 'Mark Accepted',
          onPressed: () => _markColleagueAccepted(colleague),
        ),
      ),
    );
  }

  Future<void> _markColleagueAccepted(Colleague colleague) async {
    try {
      final Colleague updated = await _apiClient.acceptColleague(colleague.id);
      if (!mounted) return;
      setState(() {
        _colleagues = _colleagues
            .map((c) => c.id == updated.id ? updated : c)
            .toList(growable: false);
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update colleague: $error')),
      );
    }
  }

  void _upsertGroup(Group group) {
    setState(() {
      final int index = _groups.indexWhere((item) => item.id == group.id);
      if (index == -1) {
        _groups = [group, ..._groups];
      } else {
        final List<Group> next = List<Group>.from(_groups);
        next[index] = group;
        _groups = next;
      }
      _hasLoadedGroups = true;
      _selectedSharedGroupId ??= group.id;
    });
  }

  Future<void> _openCreateGroupSheet() async {
    final Group? group = await showModalBottomSheet<Group>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddGroupSheet(apiClient: _apiClient),
    );
    if (group != null && mounted) {
      _upsertGroup(group);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group "${group.name}" created')),
      );
    }
  }

  Future<void> _openInviteMemberSheet(Group group) async {
    try {
      final GroupInviteLinkCreateResponse response =
          await _apiClient.createGroupInviteLink(groupId: group.id);
      if (!mounted) return;
      _inviteLinksByGroupId[group.id] = response.inviteUrl;
      final String message =
          'Join my group "${group.name}" on NurseShift. '
          'Tap this link to open the app or download it: ${response.inviteUrl}';
      await Share.share(message);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to invite: $error')),
      );
    }
  }

  Future<void> _copyGroupInvite(Group group, {GroupInvite? invite}) async {
    final String? inviteUrl =
        _inviteLinksByGroupId[group.id] ?? invite?.inviteUrl;
    final String text = inviteUrl != null
        ? 'Join my group "${group.name}" on NurseShift. Tap this link to open the app or download it: $inviteUrl'
        : group.inviteMessage;
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          inviteUrl != null
              ? 'Invite link copied for "${group.name}"'
              : 'Group invite copied for "${group.name}"',
        ),
      ),
    );
  }

  Future<void> _confirmDeleteGroup(Group group) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete group?'),
        content: Text(
          'Removing "${group.name}" will delete its shared calendar and invites.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _apiClient.deleteGroup(group.id);
      if (!mounted) return;
      setState(() {
        _groups.removeWhere((item) => item.id == group.id);
        if (_selectedSharedGroupId == group.id) {
          _selectedSharedGroupId =
              _groups.isNotEmpty ? _groups.first.id : null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Group "${group.name}" deleted')),
      );
    } on ApiException catch (error) {
      _showInfoMessage(error.message);
    } catch (error) {
      _showInfoMessage('Failed to delete group: $error');
    }
  }

  Future<void> _respondToGroupInvite({
    required GroupInvite invite,
    required bool accept,
  }) async {
    final User? user = _currentUser;
    if (user == null) {
      _showInfoMessage('Log in to respond to invites.');
      return;
    }
    try {
      final Group updated = accept
          ? await _apiClient.acceptGroupInvite(
              inviteId: invite.id,
              userId: user.id,
            )
          : await _apiClient.declineGroupInvite(
              inviteId: invite.id,
              userId: user.id,
            );
      if (!mounted) return;
      _upsertGroup(updated);
      _showInfoMessage(
        accept ? 'Invite accepted.' : 'Invite declined.',
      );
    } on ApiException catch (error) {
      _showInfoMessage(error.message);
    } catch (error) {
      _showInfoMessage('Failed to respond to invite: $error');
    }
  }

  Group _sampleGroup() {
    List<GroupSharedEntry> entriesFor(List<String> labels, String iconName) {
      final DateTime start = _startOfWeek(DateTime.now());
      return [
        for (int i = 0; i < labels.length; i++)
          GroupSharedEntry(
            date: start.add(Duration(days: i)),
            label: labels[i],
            iconName: iconName,
          ),
      ];
    }

    return Group(
      id: -1,
      name: 'Surgical Services',
      description: 'Shared calendar for 7S team swaps.',
      inviteMessage: 'Join our Surgical Services group on NurseShift.',
      invites: const [],
      sharedCalendar: [
        GroupSharedRow(
          memberName: 'Jamie Ortega',
          entries: entriesFor(['Day', 'Day', 'Off', 'Evening', 'Night', 'Off', 'Off'], 'regular'),
        ),
        GroupSharedRow(
          memberName: 'Reese Patel',
          entries: entriesFor(['Night', 'Night', 'Night', 'Off', 'Off', 'Day', 'Day'], 'night'),
        ),
        GroupSharedRow(
          memberName: 'Morgan Wills',
          entries: entriesFor(['Evening', 'Evening', 'Day', 'Day', 'Off', 'Off', 'Night'], 'evening'),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    if (!_isAuthenticated) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: _buildLoginBody(),
      );
    }
    final List<NurseBottomNavItem> navItems = [
      const NurseBottomNavItem(Icons.calendar_today, 'Calendar'),
      const NurseBottomNavItem(Icons.groups_rounded, 'Colleagues'),
      const NurseBottomNavItem(Icons.groups_2_rounded, 'Groups'),
      NurseBottomNavItem(
        Icons.mail_outline,
        'Inbox',
        badgeCount: _inboxRequests.isEmpty ? 0 : _inboxRequests.length,
      ),
    ];
    return Scaffold(
      appBar: _buildAppBar(),
      body: _buildBody(),
      bottomNavigationBar: NurseBottomNav(
        items: navItems,
        currentIndex: bottomNavIndex,
        onTap: _handleBottomNavTap,
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    if (bottomNavIndex == 2) {
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: _userInfoLeadingButton,
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.groups_2_rounded),
            tooltip: 'Create group',
            onPressed: _openCreateGroupSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _handleLogout,
          ),
        ],
      );
    } else if (bottomNavIndex == 1) {
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: _userInfoLeadingButton,
        title: const Text('Colleagues'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_rounded),
            tooltip: 'Add colleague',
            onPressed: _openAddColleagueSheet,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Log out',
            onPressed: _handleLogout,
          ),
        ],
      );
    }
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.transparent,
      leading: _userInfoLeadingButton,
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
        IconButton(
          icon: const Icon(Icons.logout),
          tooltip: 'Log out',
          onPressed: _handleLogout,
        ),
      ],
    );
  }

  Widget _buildLoginBody() {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isRegisterMode ? 'Create your account' : 'Welcome back',
                  style: AppTextStyles.headingLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegisterMode
                      ? 'Register to manage your shifts, swaps, and groups.'
                      : 'Sign in to manage your shifts, swaps, and groups.',
                  style:
                      AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                if (_isRegisterMode) ...[
                  NurseTextField(
                    label: 'Full Name',
                    hint: 'Jamie Ortega',
                    controller: _nameController,
                    leadingIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 16),
                ],
                NurseTextField(
                  label: 'Email',
                  hint: 'you@example.com',
                  controller: _emailController,
                  leadingIcon: Icons.email_outlined,
                ),
                const SizedBox(height: 16),
                NurseTextField(
                  label: 'Password',
                  hint: 'Enter your password',
                  controller: _passwordController,
                  leadingIcon: Icons.lock_outline,
                  obscureText: true,
                ),
                if (_isRegisterMode) ...[
                  const SizedBox(height: 16),
                  NurseTextField(
                    label: 'Confirm Password',
                    hint: 'Re-enter your password',
                    controller: _confirmPasswordController,
                    leadingIcon: Icons.lock_outline,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _LegalAcceptanceTile(
                    title: 'I agree to the Privacy Policy (North America)',
                    checked: _acceptPrivacy,
                    onChanged: (value) =>
                        setState(() => _acceptPrivacy = value),
                    onView: () => _openLegalDocument(
                      title: 'Privacy Policy',
                      path: '/legal/privacy',
                    ),
                  ),
                  _LegalAcceptanceTile(
                    title: 'I agree to the Disclaimer (North America)',
                    checked: _acceptDisclaimer,
                    onChanged: (value) =>
                        setState(() => _acceptDisclaimer = value),
                    onView: () => _openLegalDocument(
                      title: 'Disclaimer',
                      path: '/legal/disclaimer',
                    ),
                  ),
                ],
                if (_authError != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _authError!,
                    style: AppTextStyles.body.copyWith(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  height: 52,
                  width: double.infinity,
                  child: NurseButton(
                    label: _isAuthInProgress
                        ? (_isRegisterMode ? 'Creating account...' : 'Signing in...')
                        : (_isRegisterMode ? 'Create Account' : 'Sign In'),
                    onPressed: _isAuthInProgress ? null : _handleAuthSubmit,
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.center,
                  child: TextButton(
                    onPressed: _isAuthInProgress ? null : _toggleAuthMode,
                    child: Text(
                      _isRegisterMode
                          ? 'Already have an account? Sign in'
                          : 'Need an account? Register',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (bottomNavIndex == 2) {
      return SafeArea(child: _buildGroupsBody());
    } else if (bottomNavIndex == 1) {
      return SafeArea(child: _buildColleaguesBody());
    }
    if (bottomNavIndex == 3) {
      if (!_hasLoadedInbox && !_isLoadingInbox) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && !_hasLoadedInbox && !_isLoadingInbox) {
            _loadInboxRequests();
          }
        });
      }
      return _buildInboxBody();
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
                    tabs: const ['My Events', 'Swaps', 'Group Shared'],
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

class _UserInfoSheet extends StatelessWidget {
  const _UserInfoSheet({
    required this.user,
    required this.onWorksites,
    required this.onPrivacy,
    required this.onLogout,
    this.onAvatarTap,
    this.onRemoveAvatar,
    this.isUpdatingAvatar = false,
  });

  final User user;
  final VoidCallback onWorksites;
  final VoidCallback onPrivacy;
  final VoidCallback onLogout;
  final VoidCallback? onAvatarTap;
  final VoidCallback? onRemoveAvatar;
  final bool isUpdatingAvatar;

  String _initialFrom(String value) {
    if (value.isEmpty) return '';
    return value.substring(0, 1).toUpperCase();
  }

  String get _initials {
    final List<String> parts = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return user.name.isNotEmpty ? _initialFrom(user.name) : '?';
    }
    if (parts.length == 1) {
      return _initialFrom(parts.first);
    }
    final String first = _initialFrom(parts.first);
    final String last = _initialFrom(parts.last);
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Stack(
                  alignment: Alignment.center,
                  children: [
                    _AvatarView(
                      user: user,
                      radius: 28,
                      onTap: onAvatarTap,
                    ),
                    if (isUpdatingAvatar)
                      const SizedBox(
                        width: 32,
                        height: 32,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.name, style: AppTextStyles.headingMedium),
                      const SizedBox(height: 4),
                      Text(
                        user.email,
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
                      TextButton(
                        onPressed: isUpdatingAvatar ? null : onAvatarTap,
                        child: const Text('Change Avatar'),
                      ),
                      if (onRemoveAvatar != null)
                        TextButton(
                          onPressed: isUpdatingAvatar ? null : onRemoveAvatar,
                          child: const Text('Use Default Avatar'),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.business_rounded),
              title: const Text('Worksites'),
              subtitle: const Text('Manage hospitals and units'),
              onTap: onWorksites,
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Privacy'),
              subtitle: const Text('Control what colleagues can see'),
              onTap: onPrivacy,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: 'Log Out',
                style: NurseButtonStyle.destructive,
                onPressed: onLogout,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AvatarView extends StatelessWidget {
  const _AvatarView({
    required this.user,
    this.radius = 24,
    this.onTap,
  });

  final User user;
  final double radius;
  final VoidCallback? onTap;

  String _initialFrom(String value) {
    if (value.isEmpty) return '';
    return value.substring(0, 1).toUpperCase();
  }

  String get _initials {
    final List<String> parts = user.name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return user.name.isNotEmpty ? _initialFrom(user.name) : '?';
    }
    if (parts.length == 1) {
      return _initialFrom(parts.first);
    }
    final String first = _initialFrom(parts.first);
    final String last = _initialFrom(parts.last);
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final Widget avatar = user.avatarUrl != null && user.avatarUrl!.isNotEmpty
        ? CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(user.avatarUrl!),
            backgroundColor: AppColors.surfaceMuted,
          )
        : CircleAvatar(
            radius: radius,
            backgroundColor: AppColors.primary.withOpacity(0.15),
            child: Text(
              _initials,
              style:
                  AppTextStyles.headingMedium.copyWith(color: AppColors.primary),
            ),
          );
    if (onTap == null) {
      return avatar;
    }
    return GestureDetector(
      onTap: onTap,
      child: avatar,
    );
  }
}

class _WorksitesSheet extends StatefulWidget {
  const _WorksitesSheet({
    required this.apiClient,
    required this.user,
  });

  final CalendarApiClient apiClient;
  final User user;

  @override
  State<_WorksitesSheet> createState() => _WorksitesSheetState();
}

class _WorksitesSheetState extends State<_WorksitesSheet> {
  final TextEditingController _hospitalController = TextEditingController();
  final TextEditingController _departmentController = TextEditingController();
  final TextEditingController _positionController = TextEditingController();
  List<Worksite> _worksites = [];
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadWorksites();
  }

  @override
  void dispose() {
    _hospitalController.dispose();
    _departmentController.dispose();
    _positionController.dispose();
    super.dispose();
  }

  Future<void> _loadWorksites() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final List<Worksite> results =
          await widget.apiClient.fetchWorksites(widget.user.id);
      if (!mounted) return;
      setState(() {
        _worksites = results.length > 1 ? [results.last] : results;
        if (_worksites.isNotEmpty) {
          final Worksite worksite = _worksites.first;
          _hospitalController.text = worksite.hospitalName;
          _departmentController.text = worksite.departmentName;
          _positionController.text = worksite.positionName;
        } else {
          _hospitalController.clear();
          _departmentController.clear();
          _positionController.clear();
        }
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Failed to load worksites: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleAdd() async {
    if (_isSubmitting) return;
    final String hospital = _hospitalController.text.trim();
    final String department = _departmentController.text.trim();
    final String position = _positionController.text.trim();
    if (hospital.isEmpty || department.isEmpty || position.isEmpty) {
      setState(() => _error = 'All fields are required.');
      return;
    }
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final Worksite worksite = await widget.apiClient.createWorksite(
        userId: widget.user.id,
        hospitalName: hospital,
        departmentName: department,
        positionName: position,
      );
      if (!mounted) return;
      setState(() {
        _worksites = [worksite];
        _hospitalController.text = worksite.hospitalName;
        _departmentController.text = worksite.departmentName;
        _positionController.text = worksite.positionName;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Failed to add worksite: $error');
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleDelete(int worksiteId) async {
    try {
      await widget.apiClient.deleteWorksite(worksiteId);
      if (!mounted) return;
      setState(() {
        _worksites = [];
        _hospitalController.clear();
        _departmentController.clear();
        _positionController.clear();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = 'Failed to delete worksite: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final double bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 16,
          bottom: 16 + bottomInset,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Your Worksites',
                      style: AppTextStyles.headingMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'Reload',
                    onPressed: _isLoading ? null : _loadWorksites,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_error != null) ...[
                Text(
                  _error!,
                  style: AppTextStyles.body.copyWith(color: Colors.red),
                ),
                const SizedBox(height: 12),
              ],
              if (_isLoading)
                const Center(child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                ))
              else if (_worksites.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Add your hospital and department so your colleagues know where you work.',
                    style: AppTextStyles.body
                        .copyWith(color: AppColors.textSecondary),
                  ),
                )
              else
                Column(
                  children: _worksites
                      .map(
                        (worksite) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: ListTile(
                            title: Text(worksite.hospitalName),
                            subtitle: Text(
                              '${worksite.departmentName} · ${worksite.positionName}',
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline),
                              onPressed: () => _handleDelete(worksite.id),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              const SizedBox(height: 12),
              Text('Add Worksite', style: AppTextStyles.headingSmall),
              const SizedBox(height: 4),
              Text(
                'Each account can store one worksite. Saving a new one replaces the current entry.',
                style:
                    AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              NurseTextField(
                label: 'Hospital Name',
                hint: 'F.W. Huston Medical Center',
                controller: _hospitalController,
                leadingIcon: Icons.local_hospital_outlined,
              ),
              const SizedBox(height: 12),
              NurseTextField(
                label: 'Department',
                hint: 'Weight Management',
                controller: _departmentController,
                leadingIcon: Icons.business_center_outlined,
              ),
              const SizedBox(height: 12),
              NurseTextField(
                label: 'Position',
                hint: 'Charge Nurse',
                controller: _positionController,
                leadingIcon: Icons.badge_outlined,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: NurseButton(
                  label: _isSubmitting
                      ? 'Saving...'
                      : (_worksites.isEmpty ? 'Add Worksite' : 'Save Worksite'),
                  onPressed: _isSubmitting ? null : _handleAdd,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onInvite,
    required this.onCopyInvite,
    required this.onDelete,
    this.onCopyInviteLink,
    this.onAcceptInvite,
    this.onDeclineInvite,
    this.currentUser,
  });

  final Group group;
  final VoidCallback onInvite;
  final VoidCallback onCopyInvite;
  final VoidCallback onDelete;
  final ValueChanged<GroupInvite>? onCopyInviteLink;
  final ValueChanged<GroupInvite>? onAcceptInvite;
  final ValueChanged<GroupInvite>? onDeclineInvite;
  final User? currentUser;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(group.name, style: AppTextStyles.headingMedium),
                    if (group.description != null &&
                        group.description!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        group.description!,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: onCopyInvite,
                    tooltip: 'Copy invite',
                    icon: const Icon(Icons.copy_all_rounded),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Delete group',
                    icon: const Icon(Icons.delete_outline_rounded),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: NurseButton(
                    label: 'Invite Member',
                    style: NurseButtonStyle.secondary,
                    onPressed: onInvite,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 42,
                  child: NurseButton(
                    label: 'Copy Invite',
                    style: NurseButtonStyle.ghost,
                    onPressed: onCopyInvite,
                  ),
                ),
              ),
            ],
          ),
          if (group.invites.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('Invites', style: AppTextStyles.label),
            const SizedBox(height: 8),
            Column(
              children: [
                for (final GroupInvite invite in group.invites) ...[
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                invite.inviteeName,
                                style: AppTextStyles.body,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _statusColor(invite.status).withOpacity(0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                invite.status.label,
                                style: AppTextStyles.caption.copyWith(
                                  color: _statusColor(invite.status),
                                ),
                              ),
                            ),
                            if (invite.inviteUrl != null)
                              IconButton(
                                tooltip: 'Copy link',
                                onPressed: onCopyInviteLink == null
                                    ? null
                                    : () => onCopyInviteLink!(invite),
                                icon: const Icon(Icons.link_rounded),
                              ),
                          ],
                        ),
                        if (invite.inviteeEmail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            invite.inviteeEmail!,
                            style: AppTextStyles.caption
                                .copyWith(color: AppColors.textSecondary),
                          ),
                        ],
                        if (_shouldShowResponse(invite)) ...[
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: NurseButton(
                                    label: 'Accept',
                                    onPressed: onAcceptInvite == null
                                        ? null
                                        : () => onAcceptInvite!(invite),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: SizedBox(
                                  height: 40,
                                  child: OutlinedButton(
                                    onPressed: onDeclineInvite == null
                                        ? null
                                        : () => onDeclineInvite!(invite),
                                    child: const Text('Decline'),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }

  bool _shouldShowResponse(GroupInvite invite) {
    if (currentUser == null) return false;
    if (!invite.isPending) return false;
    final String email = currentUser!.email.toLowerCase();
    final bool emailMatch = invite.inviteeEmail != null &&
        invite.inviteeEmail!.toLowerCase() == email;
    final bool userMatch =
        invite.inviteeUserId != null && invite.inviteeUserId == currentUser!.id;
    return emailMatch || userMatch;
  }

  Color _statusColor(GroupInviteStatus status) {
    switch (status) {
      case GroupInviteStatus.accepted:
        return AppColors.success;
      case GroupInviteStatus.declined:
        return Colors.redAccent;
      case GroupInviteStatus.invited:
      default:
        return AppColors.textSecondary;
    }
  }
}

class _GroupSharedMatrix extends StatelessWidget {
  const _GroupSharedMatrix({required this.rows, required this.dates});

  final List<GroupSharedRow> rows;
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _GroupTimelineHeader(dates: dates),
        const SizedBox(height: 12),
        for (final GroupSharedRow row in rows) ...[
          _GroupTimelineRow(row: row, dates: dates),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

class _GroupTimelineHeader extends StatelessWidget {
  const _GroupTimelineHeader({required this.dates});

  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const SizedBox(width: 52, child: Text('Member', style: AppTextStyles.caption)),
          for (final DateTime date in dates)
            Expanded(
              child: Column(
                children: [
                  Text(
                    _weekdayLabel(date),
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textSecondary,
                      letterSpacing: 0.6,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${date.month}/${date.day}',
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static String _weekdayLabel(DateTime date) {
    const labels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return labels[(date.weekday - 1).clamp(0, 6)];
  }
}

class _GroupTimelineRow extends StatelessWidget {
  const _GroupTimelineRow({required this.row, required this.dates});

  final GroupSharedRow row;
  final List<DateTime> dates;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: AppColors.surfaceMuted,
              child: Text(
                row.memberName.isNotEmpty ? row.memberName[0].toUpperCase() : '?',
                style: AppTextStyles.caption,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(row.memberName, style: AppTextStyles.body)),
          ],
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final double cellWidth = (constraints.maxWidth - 52) / dates.length;
            return Row(
              children: [
                const SizedBox(width: 52),
                for (int i = 0; i < dates.length; i++)
                  SizedBox(
                    width: cellWidth,
                    child: Center(
                      child: _ShiftCell(entry: _entryForDate(dates[i])),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  GroupSharedEntry? _entryForDate(DateTime date) {
    try {
      return row.entries.firstWhere(
        (item) => DateUtils.isSameDay(item.date, date),
      );
    } catch (_) {
      return null;
    }
  }
}

class _ShiftCell extends StatelessWidget {
  const _ShiftCell({required this.entry});

  final GroupSharedEntry? entry;

  @override
  Widget build(BuildContext context) {
    final String label = entry?.label ?? '';
    final String value = label.toLowerCase();
    final String? iconName = _iconNameForEntry(entry);
    final Color color = iconName != null
        ? colorForEventType(iconName)
        : value.contains('night')
            ? const Color(0xFF53C082)
            : value.contains('evening')
                ? const Color(0xFFEF7EC7)
                : value.contains('day')
                    ? const Color(0xFF4FB6E0)
                    : AppColors.surfaceMuted;

    return Container(
      height: 28,
      width: 36,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: iconName != null
          ? Icon(
              iconForEventType(iconName),
              size: 16,
              color: Colors.white,
            )
          : Text(
              label.isEmpty ? '-' : label[0].toUpperCase(),
              style: AppTextStyles.caption.copyWith(color: Colors.white),
            ),
    );
  }

  String? _iconNameForEntry(GroupSharedEntry? entry) {
    if (entry == null) return null;
    final String? icon = entry.iconName;
    if (icon != null && icon.isNotEmpty) return icon;
    final String value = entry.label.toLowerCase();
    if (value.contains('night')) return 'night_shift';
    if (value.contains('evening')) return 'regular';
    if (value.contains('day')) return 'regular';
    if (value.contains('charge')) return 'charge';
    if (value.contains('preceptor')) return 'preceptor';
    if (value.contains('call')) return 'on_call';
    if (value.contains('vacation')) return 'vacation';
    if (value.contains('payday')) return 'payday';
    if (value.contains('personal')) return 'personal';
    if (value.contains('conference') || value.contains('meeting') || value.contains('education')) {
      return 'conference';
    }
    if (value.contains('available')) return 'available';
    if (value.contains('unavailable')) return 'unavailable';
    return null;
  }
}

class _ShareWeekSheet extends StatefulWidget {
  const _ShareWeekSheet({
    required this.groups,
    required this.initialGroupId,
    required this.initialRange,
    required this.existingShares,
  });

  final List<Group> groups;
  final int initialGroupId;
  final DateTimeRange initialRange;
  final List<_ExistingShare> existingShares;

  @override
  State<_ShareWeekSheet> createState() => _ShareWeekSheetState();
}

class _ShareWeekSheetState extends State<_ShareWeekSheet> {
  late int _selectedId;
  late DateTimeRange _selectedRange;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedId = widget.initialGroupId;
    _selectedRange = widget.initialRange;
  }

  @override
  Widget build(BuildContext context) {
    final Group activeGroup = widget.groups.firstWhere(
      (group) => group.id == _selectedId,
      orElse: () => widget.groups.first,
    );
    final List<_ExistingShare> existingForGroup = widget.existingShares
        .where((share) => share.groupId == _selectedId)
        .toList();
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share your calendar', style: AppTextStyles.headingMedium),
            const SizedBox(height: 4),
            Text(
              _formatRange(_selectedRange.start, _selectedRange.end),
              style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range),
              label: const Text('Choose date range'),
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 4),
              Text(
                _errorMessage!,
                style: AppTextStyles.caption.copyWith(color: Colors.red),
              ),
            ],
            const SizedBox(height: 16),
            ...widget.groups.map(
              (group) => RadioListTile<int>(
                title: Text(group.name),
                subtitle: group.description == null
                    ? null
                    : Text(
                        group.description!,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                value: group.id,
                groupValue: _selectedId,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _selectedId = value);
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 48,
              width: double.infinity,
              child: NurseButton(
                label: 'Share with ${activeGroup.name}',
                onPressed: _submitShare,
              ),
            ),
            if (existingForGroup.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('Your shared ranges', style: AppTextStyles.label),
              const SizedBox(height: 8),
              for (final _ExistingShare share in existingForGroup) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(_formatRange(share.startDate, share.endDate)),
                  subtitle: Text(
                    share.groupName,
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  trailing: TextButton(
                    onPressed: () => Navigator.of(context).pop(
                      ShareSheetResult.cancel(
                        groupId: share.groupId,
                        startDate: share.startDate,
                        endDate: share.endDate,
                      ),
                    ),
                    child: const Text('Stop sharing'),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickRange() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      initialDateRange: _selectedRange,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (range != null) {
      setState(() {
        _selectedRange = range;
        _errorMessage = null;
      });
    }
  }

  void _submitShare() {
    final int span = _selectedRange.end.difference(_selectedRange.start).inDays + 1;
    if (span > 180) {
      setState(
        () => _errorMessage = 'Please select 180 days or fewer when sharing.',
      );
      return;
    }
    Navigator.of(context).pop(
      ShareSheetResult.share(
        groupId: _selectedId,
        startDate: _selectedRange.start,
        endDate: _selectedRange.end,
      ),
    );
  }

  String _formatRange(DateTime start, DateTime end) {
    const List<String> months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final String startLabel =
        '${months[start.month - 1]} ${start.day}, ${start.year}';
    final String endLabel =
        '${months[end.month - 1]} ${end.day}, ${end.year}';
    return '$startLabel – $endLabel';
  }
}

class ShareSheetResult {
  ShareSheetResult.share({
    required this.groupId,
    required this.startDate,
    required this.endDate,
  }) : isCancellation = false;

  ShareSheetResult.cancel({
    required this.groupId,
    required this.startDate,
    required this.endDate,
  }) : isCancellation = true;

  final int groupId;
  final DateTime startDate;
  final DateTime endDate;
  final bool isCancellation;
}

class _ExistingShare {
  const _ExistingShare({
    required this.groupId,
    required this.groupName,
    required this.startDate,
    required this.endDate,
  });

  final int groupId;
  final String groupName;
  final DateTime startDate;
  final DateTime endDate;
}

class _WeekShareResult {
  const _WeekShareResult({
    required this.shared,
    required this.missing,
  });

  final List<GroupSharedRow> shared;
  final List<GroupSharedRow> missing;
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

class _AddGroupSheet extends StatefulWidget {
  const _AddGroupSheet({required this.apiClient});

  final CalendarApiClient apiClient;

  @override
  State<_AddGroupSheet> createState() => _AddGroupSheetState();
}

class _AddGroupSheetState extends State<_AddGroupSheet> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String name = _nameController.text.trim();
    final String description = _descriptionController.text.trim();
    if (name.isEmpty) {
      setState(() => _errorMessage = 'Group name is required.');
      return;
    }
    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });
    try {
      final Group group = await widget.apiClient.createGroup(
        name: name,
        description: description.isEmpty ? null : description,
      );
      if (!mounted) return;
      Navigator.of(context).pop(group);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Failed to create group: $error');
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
        padding: EdgeInsets.fromLTRB(24, 24, 24, padding.bottom + 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Create group', style: AppTextStyles.headingMedium),
            const SizedBox(height: 16),
            NurseTextField(
              label: 'Group name',
              controller: _nameController,
            ),
            const SizedBox(height: 12),
            NurseTextField(
              label: 'Description (optional)',
              controller: _descriptionController,
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
                label: _isSaving ? 'Saving...' : 'Create',
                onPressed: _isSaving ? null : _submit,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegalAcceptanceTile extends StatelessWidget {
  const _LegalAcceptanceTile({
    required this.title,
    required this.checked,
    required this.onChanged,
    required this.onView,
  });

  final String title;
  final bool checked;
  final ValueChanged<bool> onChanged;
  final VoidCallback onView;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      contentPadding: EdgeInsets.zero,
      value: checked,
      onChanged: (value) => onChanged(value ?? false),
      controlAffinity: ListTileControlAffinity.leading,
      title: Text(title, style: AppTextStyles.caption),
      secondary: TextButton(
        onPressed: onView,
        child: const Text('View'),
      ),
    );
  }
}

class LegalDocumentPage extends StatefulWidget {
  const LegalDocumentPage({
    super.key,
    required this.title,
    required this.path,
    required this.apiClient,
  });

  final String title;
  final String path;
  final CalendarApiClient apiClient;

  @override
  State<LegalDocumentPage> createState() => _LegalDocumentPageState();
}

class _LegalDocumentPageState extends State<LegalDocumentPage> {
  bool _isLoading = true;
  String? _content;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadDocument();
  }

  Future<void> _loadDocument() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final String html = await widget.apiClient.fetchLegalDocument(
        widget.path,
      );
      if (!mounted) return;
      setState(() {
        _content = html;
        _isLoading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.message;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to load document: $error';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : SingleChildScrollView(
                    child: Html(
                      data: _content ?? '',
                      style: {
                        'body': Style(
                          margin: Margins.zero,
                          fontSize: FontSize(15),
                          color: AppColors.textPrimary,
                        ),
                        'h1': Style(
                          fontSize: FontSize(26),
                          fontWeight: FontWeight.w700,
                        ),
                        'h2': Style(
                          fontSize: FontSize(20),
                          fontWeight: FontWeight.w600,
                        ),
                        'p': Style(
                          lineHeight: const LineHeight(1.5),
                          color: AppColors.textSecondary,
                        ),
                        'li': Style(
                          lineHeight: const LineHeight(1.5),
                          color: AppColors.textSecondary,
                        ),
                      },
                    ),
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
                  color: statusColor.withOpacity(0.15),
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

class _InboxSelectionActions extends StatelessWidget {
  const _InboxSelectionActions({
    required this.count,
    required this.onAccept,
    required this.onDecline,
    required this.onClear,
    required this.onMarkRead,
    required this.isProcessing,
  });

  final int count;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final VoidCallback? onClear;
  final VoidCallback? onMarkRead;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final String label =
        '$count request${count == 1 ? '' : 's'} selected';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: AppTextStyles.headingSmall,
                ),
              ),
              TextButton(
                onPressed: isProcessing ? null : onClear,
                child: const Text('Clear'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: NurseButton(
                    label: isProcessing ? 'Working...' : 'Accept selected',
                    onPressed: isProcessing ? null : onAccept,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed: isProcessing ? null : onDecline,
                    child: const Text('Decline selected'),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 46,
            width: double.infinity,
            child: OutlinedButton(
              onPressed: isProcessing ? null : onMarkRead,
              child: const Text('Mark as read'),
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxSummaryCard extends StatelessWidget {
  const _InboxSummaryCard({
    required this.total,
    required this.pending,
    required this.fulfilled,
  });

  final int total;
  final int pending;
  final int fulfilled;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          _SummaryMetric(
            label: 'Total',
            value: total,
          ),
          const SizedBox(width: 16),
          _SummaryMetric(
            label: 'Pending',
            value: pending,
          ),
          const SizedBox(width: 16),
          _SummaryMetric(
            label: 'Fulfilled',
            value: fulfilled,
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});

  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value.toString(),
            style: AppTextStyles.headingLarge,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InboxFilterChips extends StatelessWidget {
  const _InboxFilterChips({
    required this.activeFilter,
    required this.onChanged,
  });

  final InboxFilter activeFilter;
  final ValueChanged<InboxFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      children: [
        for (final InboxFilter filter in InboxFilter.values)
          ChoiceChip(
            label: Text(_labelForFilter(filter)),
            selected: activeFilter == filter,
            onSelected: (selected) {
              if (selected) onChanged(filter);
            },
          ),
      ],
    );
  }

  String _labelForFilter(InboxFilter filter) {
    switch (filter) {
      case InboxFilter.pending:
        return 'Pending';
      case InboxFilter.fulfilled:
        return 'Accepted';
      case InboxFilter.all:
        return 'All';
    }
  }
}

class _InboxRequestCard extends StatelessWidget {
  const _InboxRequestCard({
    required this.request,
    required this.eventDateLabel,
    required this.isOwnedRequest,
    required this.isSelected,
    required this.onSelectionChanged,
    required this.onAccept,
    required this.onDecline,
    required this.actionsDisabled,
  });

  final SwapRequest request;
  final String eventDateLabel;
  final bool isOwnedRequest;
  final bool isSelected;
  final ValueChanged<bool?> onSelectionChanged;
  final VoidCallback? onAccept;
  final VoidCallback? onDecline;
  final bool actionsDisabled;

  @override
  Widget build(BuildContext context) {
    final CalendarEvent event = request.event;
    final bool isPending = request.status == SwapRequestStatus.pending;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 24,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Checkbox(
                value: isSelected,
                onChanged: actionsDisabled ? null : onSelectionChanged,
              ),
              Icon(
                request.mode == SwapMode.swap
                    ? Icons.swap_horiz_rounded
                    : Icons.card_giftcard_rounded,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  request.ownerName ?? 'Colleague',
                  style: AppTextStyles.headingMedium,
                ),
              ),
              Chip(
                label: Text(request.status.label),
                backgroundColor: AppColors.surfaceMuted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 4),
          Text(
            eventDateLabel,
            style: AppTextStyles.body.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${event.location} • ${event.timeRange}',
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            'Preferred shift: ${request.desiredShiftType}',
            style: AppTextStyles.body,
          ),
          if (request.notes?.isNotEmpty ?? false) ...[
            const SizedBox(height: 8),
            Text(
              request.notes!,
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
          if (isOwnedRequest &&
              request.status == SwapRequestStatus.fulfilled &&
              request.acceptedByName != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    size: 20, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${request.acceptedByName} accepted this shift.',
                    style: AppTextStyles.body,
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: NurseButton(
                    label: 'Accept',
                    onPressed:
                        isPending && !actionsDisabled ? onAccept : null,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 46,
                  child: OutlinedButton(
                    onPressed:
                        isPending && !actionsDisabled ? onDecline : null,
                    child: const Text('Decline'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
          isSelected ? AppColors.primary.withOpacity(0.08) : Colors.white,
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
