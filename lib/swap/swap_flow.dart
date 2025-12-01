import 'package:flutter/material.dart';

import '../models/calendar_event.dart';
import '../models/swap_request.dart';
import '../services/calendar_api.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import '../utils/event_type_icon.dart';
import '../widgets/nurse_button.dart';

class SwapActionSheet extends StatelessWidget {
  const SwapActionSheet({
    super.key,
    required this.event,
    required this.onViewDetails,
    required this.onSwap,
    required this.onGiveAway,
    this.swapEnabled = true,
    this.disabledMessage,
  });

  final CalendarEvent event;
  final VoidCallback onViewDetails;
  final VoidCallback onSwap;
  final VoidCallback onGiveAway;
  final bool swapEnabled;
  final String? disabledMessage;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: AppTextStyles.headingLarge,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              _formatDate(event.date),
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(iconForEventType(event.eventType),
                      color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(event.timeRange, style: AppTextStyles.label),
                      const SizedBox(height: 4),
                      Text(
                        event.location,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: 'View Details',
                style: NurseButtonStyle.ghost,
                onPressed: onViewDetails,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: NurseButton(
                      label: 'Swap',
                      onPressed: swapEnabled ? onSwap : null,
                      leading: const Icon(Icons.swap_horiz_rounded),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 52,
                    child: NurseButton(
                      label: 'Give Away',
                      style: NurseButtonStyle.secondary,
                      onPressed: swapEnabled ? onGiveAway : null,
                      leading: const Icon(Icons.send_rounded),
                    ),
                  ),
                ),
              ],
            ),
            if (!swapEnabled && disabledMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  disabledMessage!,
                  style: AppTextStyles.body.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';

  String _weekday(int value) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(value - 1).clamp(0, 6)];
  }

  String _month(int value) {
    const names = [
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
    return names[(value - 1).clamp(0, 11)];
  }
}

class GiveawayPage extends StatefulWidget {
  const GiveawayPage({
    super.key,
    required this.event,
    required this.apiClient,
  });

  final CalendarEvent event;
  final CalendarApiClient apiClient;

  @override
  State<GiveawayPage> createState() => _GiveawayPageState();
}

class _GiveawayPageState extends State<GiveawayPage> {
  final TextEditingController _notesController = TextEditingController();
  bool _visibleToAll = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Giveaway'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SwapEventSummary(event: widget.event),
            const SizedBox(height: 24),
            _SectionHeader(label: 'Notes'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add instructions for your colleagues',
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(label: 'Visibility'),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Make giveaway visible to all colleagues?'),
              value: _visibleToAll,
              onChanged: (value) => setState(() => _visibleToAll = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.apiClient.createSwapRequest(
        eventId: widget.event.id,
        mode: SwapMode.giveAway,
        desiredShiftType: widget.event.eventType,
        visibleToAll: _visibleToAll,
        shareWithStaffingPool: false,
        targetedColleagues: const [],
        availableStartTime: null,
        availableEndTime: null,
        availableDateRange: null,
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }
}

class SwapPreferencesData {
  SwapPreferencesData({
    required this.event,
    required this.desiredShiftType,
    this.availableStartTime,
    this.availableEndTime,
    this.availableDateRange,
  });

  final CalendarEvent event;
  final String desiredShiftType;
  final TimeOfDay? availableStartTime;
  final TimeOfDay? availableEndTime;
  final DateTimeRange? availableDateRange;
}

class SwapPreferencesPage extends StatefulWidget {
  const SwapPreferencesPage({
    super.key,
    required this.event,
    required this.apiClient,
    required this.shiftTypes,
  });

  final CalendarEvent event;
  final CalendarApiClient apiClient;
  final List<String> shiftTypes;

  @override
  State<SwapPreferencesPage> createState() => _SwapPreferencesPageState();
}

class _SwapPreferencesPageState extends State<SwapPreferencesPage> {
  late String _selectedShiftType;
  TimeOfDay? _startAfter;
  TimeOfDay? _endBefore;
  DateTimeRange? _dateRange;

  @override
  void initState() {
    super.initState();
    _selectedShiftType = widget.shiftTypes.first;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Swap'),
        actions: [
          TextButton(
            onPressed: _handleNext,
            child: const Text('Next'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            SwapEventSummary(event: widget.event),
            const SizedBox(height: 24),
            _SectionHeader(label: 'Choose the shift type you want to work'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: widget.shiftTypes
                  .map(
                    (type) => ChoiceChip(
                      label: Text(type),
                      selected: _selectedShiftType == type,
                      onSelected: (_) =>
                          setState(() => _selectedShiftType = type),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            _SectionHeader(label: 'Choose the hours you want to work'),
            const SizedBox(height: 12),
            _TimePickerTile(
              label: 'Start After',
              value: _formatTime(_startAfter),
              onTap: () => _pickTime(isStart: true),
            ),
            const SizedBox(height: 12),
            _TimePickerTile(
              label: 'End Before',
              value: _formatTime(_endBefore),
              onTap: () => _pickTime(isStart: false),
            ),
            const SizedBox(height: 24),
            _SectionHeader(label: 'Choose the days you want to work'),
            const SizedBox(height: 12),
            _SelectionTile(
              label: _dateRange == null
                  ? 'Any dates'
                  : '${_formatDate(_dateRange!.start)} – ${_formatDate(_dateRange!.end)}',
              onTap: _pickDateRange,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickTime({required bool isStart}) async {
    final TimeOfDay initial = (isStart ? _startAfter : _endBefore) ??
        const TimeOfDay(hour: 9, minute: 0);
    final TimeOfDay? result = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (result != null) {
      setState(() {
        if (isStart) {
          _startAfter = result;
        } else {
          _endBefore = result;
        }
      });
    }
  }

  Future<void> _pickDateRange() async {
    final DateTimeRange initialRange = _dateRange ??
        DateTimeRange(
          start: widget.event.date,
          end: widget.event.date.add(const Duration(days: 7)),
        );
    final DateTimeRange? result = await showDateRangePicker(
      context: context,
      firstDate: DateTime(widget.event.date.year - 1),
      lastDate: DateTime(widget.event.date.year + 2),
      initialDateRange: initialRange,
    );
    if (result != null) {
      setState(() => _dateRange = result);
    }
  }

  void _handleNext() {
    final SwapPreferencesData data = SwapPreferencesData(
      event: widget.event,
      desiredShiftType: _selectedShiftType,
      availableStartTime: _startAfter,
      availableEndTime: _endBefore,
      availableDateRange: _dateRange,
    );
    Navigator.of(context)
        .push<bool>(
      MaterialPageRoute(
        builder: (_) => SwapReviewPage(
          preferences: data,
          apiClient: widget.apiClient,
        ),
      ),
    )
        .then((created) {
      if (created == true) {
        Navigator.of(context).pop(true);
      }
    });
  }

  String _formatTime(TimeOfDay? time) {
    if (time == null) return 'Any time';
    final int hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final String minute = time.minute.toString().padLeft(2, '0');
    final String period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDate(DateTime date) =>
      '${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
}

class SwapReviewPage extends StatefulWidget {
  const SwapReviewPage({
    super.key,
    required this.preferences,
    required this.apiClient,
  });

  final SwapPreferencesData preferences;
  final CalendarApiClient apiClient;

  @override
  State<SwapReviewPage> createState() => _SwapReviewPageState();
}

class _SwapReviewPageState extends State<SwapReviewPage> {
  final TextEditingController _notesController = TextEditingController();
  bool _visibleToAll = true;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Swap'),
        actions: [
          TextButton(
            onPressed: _isSubmitting ? null : _submit,
            child: _isSubmitting
                ? const SizedBox(
                    height: 14,
                    width: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Send'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            _SectionHeader(label: 'Notes'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Add instructions for your colleagues',
              ),
            ),
            const SizedBox(height: 24),
            _SectionHeader(label: 'Visibility'),
            const SizedBox(height: 12),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('Make swap visible to all colleagues?'),
              value: _visibleToAll,
              onChanged: (value) => setState(() => _visibleToAll = value),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit() async {
    setState(() => _isSubmitting = true);
    try {
      await widget.apiClient.createSwapRequest(
        eventId: widget.preferences.event.id,
        mode: SwapMode.swap,
        desiredShiftType: widget.preferences.desiredShiftType,
        availableStartTime: widget.preferences.availableStartTime,
        availableEndTime: widget.preferences.availableEndTime,
        availableDateRange: widget.preferences.availableDateRange,
        visibleToAll: _visibleToAll,
        shareWithStaffingPool: false,
        targetedColleagues: const [],
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send request: $error')),
      );
    } finally {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
    }
  }
}

class SwapEventSummary extends StatelessWidget {
  const SwapEventSummary({super.key, required this.event});

  final CalendarEvent event;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDate(event.date),
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 8),
          Text(
            event.timeRange,
            style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            event.title,
            style: AppTextStyles.label,
          ),
          const SizedBox(height: 4),
          Text(
            event.location,
            style:
                AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) =>
      '${_weekday(date.weekday)}, ${_month(date.month)} ${date.day}';

  String _weekday(int value) {
    const names = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return names[(value - 1).clamp(0, 6)];
  }

  String _month(int value) {
    const names = [
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
    return names[(value - 1).clamp(0, 11)];
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: AppTextStyles.headingMedium,
    );
  }
}

class _SelectionTile extends StatelessWidget {
  const _SelectionTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  const _TimePickerTile({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(label)),
        TextButton(onPressed: onTap, child: Text(value)),
      ],
    );
  }
}
