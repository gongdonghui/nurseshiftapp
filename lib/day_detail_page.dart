import 'package:flutter/material.dart';

import 'add_event_page.dart';
import 'models/calendar_event.dart';
import 'models/day_schedule.dart';
import 'services/calendar_api.dart';
import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';
import 'widgets/day_detail_card.dart';
import 'widgets/nurse_button.dart';

class DayDetailResult {
  const DayDetailResult({
    required this.date,
    this.event,
    this.wasDeleted = false,
  });

  factory DayDetailResult.forEvent(CalendarEvent event) =>
      DayDetailResult(date: event.date, event: event);

  factory DayDetailResult.deleted(DateTime date) =>
      DayDetailResult(date: date, wasDeleted: true);

  final DateTime date;
  final CalendarEvent? event;
  final bool wasDeleted;
}

class DayDetailPage extends StatefulWidget {
  const DayDetailPage({
    super.key,
    required this.date,
    this.schedule,
    this.event,
    required this.apiClient,
    this.hasPendingSwap = false,
  });

  final DateTime date;
  final DaySchedule? schedule;
  final CalendarEvent? event;
  final CalendarApiClient apiClient;
  final bool hasPendingSwap;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  bool _isDeleting = false;

  DaySchedule? get _schedule =>
      widget.schedule ?? widget.event?.toDaySchedule();

  bool get _hasEvent => widget.event != null;

  bool get _canModifyEvent => _hasEvent && !widget.hasPendingSwap;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surfaceMuted,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Shift'),
        actions: [
          if (_hasEvent)
            TextButton(
              onPressed: _canModifyEvent ? _handleEditEvent : null,
              child: const Text('Edit'),
            ),
        ],
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              sliver: SliverList(
                delegate: SliverChildListDelegate(
                  [
                    DayDetailCard(
                      date: widget.date,
                      schedule: _schedule,
                      onViewMore: () =>
                          _showComingSoon(context, 'Shift details'),
                      onViewSwaps: () =>
                          _showComingSoon(context, 'View swaps'),
                    ),
                    const SizedBox(height: 20),
                    if (widget.hasPendingSwap) ...[
                      const _PendingSwapNotice(),
                      const SizedBox(height: 16),
                    ],
                    if (_hasEvent)
                      ..._buildShiftDetailSections()
                    else
                      _buildEmptyState(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildShiftDetailSections() {
    final CalendarEvent event = widget.event!;
    return [
      _ShiftSection(
        title: 'Shift Attributes',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AttributeRow(
              label: 'Workplace',
              value: event.location,
            ),
            const SizedBox(height: 12),
            _AttributeRow(
              label: 'Shift Type',
              value: event.title,
            ),
            const SizedBox(height: 12),
            _AttributeRow(
              label: 'Shift Time',
              value: event.timeRange,
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _ShiftSection(
        title: 'My Notes',
        child: event.notes != null && event.notes!.isNotEmpty
            ? Text(
                event.notes!,
                style: AppTextStyles.body
                    .copyWith(color: AppColors.textSecondary),
              )
            : Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () =>
                      _showComingSoon(context, 'Notes'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add New Note'),
                ),
              ),
      ),
      const SizedBox(height: 16),
      _ShiftSection(
        title: 'Shift Reflection',
        child: _ChevronTile(
          label: 'Add Shift Reflection',
          onTap: () => _showComingSoon(context, 'Shift reflection'),
        ),
      ),
      const SizedBox(height: 16),
      _ShiftSection(
        title: 'Shift Options',
        child: Column(
          children: [
            _ShiftOptionTile(
              label: 'Charge',
              value: _hasChargeRole(event.eventType),
            ),
            const Divider(height: 20),
            _ShiftOptionTile(
              label: 'Preceptor',
              value: _hasPreceptorRole(event.eventType),
            ),
            const Divider(height: 20),
            _ShiftOptionTile(
              label: 'Overtime',
              value: _hasOvertimeRole(event.eventType),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      _ShiftSection(
        title: 'Shift Actions',
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: 'Edit Event',
                style: NurseButtonStyle.secondary,
                onPressed: _canModifyEvent ? _handleEditEvent : null,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: 'Delete Event',
                style: NurseButtonStyle.destructive,
                isLoading: _isDeleting,
                onPressed: _canModifyEvent && !_isDeleting
                    ? _confirmDelete
                    : null,
              ),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('No scheduled event', style: AppTextStyles.headingMedium),
        const SizedBox(height: 8),
        Text(
          'Create an event or add availability so your team knows your plan for the day.',
          style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: NurseButton(
            label: 'Create Event',
            onPressed: _openAddEvent,
          ),
        ),
      ],
    );
  }

  void _showComingSoon(BuildContext context, String label) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label coming soon'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _openAddEvent() async {
    final CalendarEvent? event = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          initialDate: widget.date,
          apiClient: widget.apiClient,
        ),
      ),
    );
    if (event != null && mounted) {
      Navigator.of(context).pop(DayDetailResult.forEvent(event));
    }
  }

  Future<void> _handleEditEvent() async {
    if (!_canModifyEvent || widget.event == null) return;
    final CalendarEvent? event = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => AddEventPage(
          existingEvent: widget.event,
          apiClient: widget.apiClient,
        ),
      ),
    );
    if (event != null && mounted) {
      Navigator.of(context).pop(DayDetailResult.forEvent(event));
    }
  }

  Future<void> _confirmDelete() async {
    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => _DeleteSheet(
        onConfirm: () => Navigator.of(context).pop(true),
      ),
    );
    if (confirmed == true) {
      await _deleteEvent();
    }
  }

  Future<void> _deleteEvent() async {
    if (widget.event == null) return;
    setState(() => _isDeleting = true);
    try {
      await widget.apiClient.deleteEvent(widget.event!.id);
      if (!mounted) return;
      Navigator.of(context).pop(DayDetailResult.deleted(widget.date));
    } on ApiException catch (error) {
      _showError(error.message);
    } catch (error) {
      _showError('Failed to delete event: $error');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _hasChargeRole(String type) =>
      type.contains('charge');

  bool _hasPreceptorRole(String type) =>
      type.contains('preceptor');

  bool _hasOvertimeRole(String type) =>
      type == 'on_call';
}

class _ShiftSection extends StatelessWidget {
  const _ShiftSection({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
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
          Text(title, style: AppTextStyles.headingMedium),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AttributeRow extends StatelessWidget {
  const _AttributeRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
          style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
        ),
      ],
    );
  }
}

class _ChevronTile extends StatelessWidget {
  const _ChevronTile({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceMuted,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Text(label, style: AppTextStyles.body),
              const Spacer(),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _ShiftOptionTile extends StatelessWidget {
  const _ShiftOptionTile({
    required this.label,
    required this.value,
  });

  final String label;
  final bool value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: AppTextStyles.body),
        const Spacer(),
        Switch.adaptive(
          value: value,
          onChanged: null,
        ),
      ],
    );
  }
}

class _PendingSwapNotice extends StatelessWidget {
  const _PendingSwapNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info, color: Colors.orange),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'This shift has a pending swap request. Edit and delete actions are disabled until it is resolved.',
              style: AppTextStyles.body.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteSheet extends StatelessWidget {
  const _DeleteSheet({required this.onConfirm});

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
            Text('Delete this event?', style: AppTextStyles.headingMedium),
            const SizedBox(height: 8),
            Text(
              'This action cannot be undone. Your swap requests will be removed with the event.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: 'Delete Event',
                style: NurseButtonStyle.destructive,
                onPressed: onConfirm,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: NurseButton(
                label: 'Cancel',
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
