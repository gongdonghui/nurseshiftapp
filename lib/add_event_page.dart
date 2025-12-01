import 'package:flutter/material.dart';

import 'event_type_selection_page.dart';
import 'models/calendar_event.dart';
import 'services/calendar_api.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'widgets/month_calendar.dart';
import 'widgets/nurse_text_field.dart';

class AddEventPage extends StatefulWidget {
  AddEventPage({
    super.key,
    this.initialDate,
    this.existingEvent,
    CalendarApiClient? apiClient,
  }) : apiClient = apiClient ?? CalendarApiClient();

  final DateTime? initialDate;
  final CalendarEvent? existingEvent;
  final CalendarApiClient apiClient;

  @override
  State<AddEventPage> createState() => _AddEventPageState();
}

class _AddEventPageState extends State<AddEventPage> {
  static const String _defaultWorksiteLabel =
      'F.W. Huston Medical Center - Weight Management';

  late DateTime _focusedMonth;
  late DateTime _selectedDate;
  late Set<int> _multiDaySelection;
  final TextEditingController _noteController = TextEditingController();
  bool _isAddingNote = false;
  bool _isSaving = false;
  late EventTypeOption _selectedEventType;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  late String _worksiteLabel;

  bool get _isEditing => widget.existingEvent != null;

  @override
  void initState() {
    super.initState();
    final CalendarEvent? event = widget.existingEvent;
    final DateTime initialDate = event?.date ??
        widget.initialDate ??
        DateTime(2025, 11, 12);
    _focusedMonth = DateTime(initialDate.year, initialDate.month);
    _selectedDate = initialDate;
    _multiDaySelection =
        event != null ? {initialDate.day} : {12, 13, 14};
    _selectedEventType =
        findEventTypeById(event?.eventType ?? '') ?? defaultEventType;
    _startTime = event != null
        ? _parseTimeOfDay(event.startTime)
        : const TimeOfDay(hour: 19, minute: 0);
    _endTime = event != null
        ? _parseTimeOfDay(event.endTime)
        : const TimeOfDay(hour: 7, minute: 0);
    _worksiteLabel = event?.location ?? _defaultWorksiteLabel;
    if (event?.notes != null && event!.notes!.isNotEmpty) {
      _noteController.text = event.notes!;
      _isAddingNote = true;
    }
  }

  Map<int, CalendarDayData> get _highlightedDays {
    final Color highlight = AppColors.primary.withAlpha(31);
    final Set<int> days = {..._multiDaySelection, _selectedDate.day};
    return {
      for (final int day in days) day: CalendarDayData(highlightColor: highlight),
    };
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final CalendarEvent event = await (_isEditing
          ? widget.apiClient.updateEvent(
              id: widget.existingEvent!.id,
              title: _selectedEventType.name,
              date: _selectedDate,
              startTime: _startTime,
              endTime: _endTime,
              location: _worksiteLabel,
              eventType: _selectedEventType.id,
              notes: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            )
          : widget.apiClient.createEvent(
              title: _selectedEventType.name,
              date: _selectedDate,
              startTime: _startTime,
              endTime: _endTime,
              location: _worksiteLabel,
              eventType: _selectedEventType.id,
              notes: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            ));
      if (!mounted) return;
      Navigator.of(context).pop(event);
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Unexpected error: $error');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _handleDaySelected(DateTime date) {
    setState(() => _selectedDate = date);
  }

  void _toggleNoteField() {
    setState(() {
      _isAddingNote = true;
    });
  }

  Future<void> _selectEventType() async {
    final EventTypeOption? result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EventTypeSelectionPage(
          selected: _selectedEventType,
        ),
      ),
    );
    if (!mounted || result == null) return;
    setState(() => _selectedEventType = result);
  }

  Future<void> _pickTime({required bool isStart}) async {
    final TimeOfDay? result = await showTimePicker(
      context: context,
      initialTime: isStart ? _startTime : _endTime,
    );
    if (result == null) return;
    setState(() {
      if (isStart) {
        _startTime = result;
      } else {
        _endTime = result;
      }
    });
  }

  TimeOfDay _parseTimeOfDay(String value) {
    final List<String> parts = value.split(':');
    final int hour = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
    final int minute =
        parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeOfDay(TimeOfDay value) {
    final int hour = value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod;
    final String minutes = value.minute.toString().padLeft(2, '0');
    final String period = value.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minutes $period';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(_isEditing ? 'Edit Event' : 'Add Events'),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_isEditing ? 'Update' : 'Save'),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoTile(
                label: 'Calendar',
                value: 'Nursegrid',
                icon: Icons.event_note_rounded,
                trailing: _ChevronButton(onPressed: () {}),
              ),
              const SizedBox(height: 16),
              _InfoTile(
                label: 'Worksite',
                value: _worksiteLabel,
                icon: Icons.local_hospital_rounded,
                trailing: _ChevronButton(onPressed: () {}),
              ),
              const SizedBox(height: 16),
              _InfoTile(
                label: 'Event Type',
                value: _selectedEventType.name,
                icon: Icons.calendar_month_outlined,
                trailing: _ChevronButton(onPressed: _selectEventType),
                onTap: _selectEventType,
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _TimeCard(
                      label: 'Start Time',
                      value: _formatTimeOfDay(_startTime),
                      icon: Icons.nights_stay_rounded,
                      onTap: () => _pickTime(isStart: true),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TimeCard(
                      label: 'End Time',
                      value: _formatTimeOfDay(_endTime),
                      icon: Icons.wb_sunny_outlined,
                      onTap: () => _pickTime(isStart: false),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text('Notes', style: AppTextStyles.label),
              const SizedBox(height: 8),
              if (_isAddingNote)
                NurseTextField(
                  hint: 'Add context for your team...',
                  controller: _noteController,
                  leadingIcon: Icons.edit_note_rounded,
                )
              else
                TextButton.icon(
                  onPressed: _toggleNoteField,
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Note'),
                ),
              const SizedBox(height: 28),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x11000000),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'November 2025',
                                style: AppTextStyles.headingMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Tap a date to update your event.',
                                style: AppTextStyles.body.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () {},
                          icon: const Icon(Icons.expand_less_rounded),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    MonthCalendar(
                      month: _focusedMonth,
                      selectedDate: _selectedDate,
                      onDaySelected: _handleDaySelected,
                      dayData: _highlightedDays,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.label,
    required this.value,
    required this.icon,
    this.trailing,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final BorderRadius borderRadius = BorderRadius.circular(24);
    return Material(
      color: Colors.white,
      borderRadius: borderRadius,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            border: Border.all(color: AppColors.outline),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      value,
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  const _TimeCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppColors.outline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(height: 12),
              Text(
                label.toUpperCase(),
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: AppTextStyles.headingMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChevronButton extends StatelessWidget {
  const _ChevronButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onPressed,
      icon: const Icon(Icons.chevron_right),
      color: AppColors.textMuted,
    );
  }
}
