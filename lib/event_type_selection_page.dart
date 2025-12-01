import 'package:flutter/material.dart';

import 'theme/app_colors.dart';
import 'theme/app_text_styles.dart';

enum EventTypeCategory { workShifts, availability, personal }

extension EventTypeCategoryLabel on EventTypeCategory {
  String get label {
    switch (this) {
      case EventTypeCategory.workShifts:
        return 'Work Shifts';
      case EventTypeCategory.availability:
        return 'Availability';
      case EventTypeCategory.personal:
        return 'Personal';
    }
  }
}

class EventTypeOption {
  const EventTypeOption({
    required this.id,
    required this.name,
    required this.description,
    required this.badgeColor,
    required this.category,
  });

  final String id;
  final String name;
  final String description;
  final Color badgeColor;
  final EventTypeCategory category;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EventTypeOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}

const Map<EventTypeCategory, List<EventTypeOption>> kEventTypeOptions = {
  EventTypeCategory.workShifts: [
    EventTypeOption(
      id: 'regular',
      name: 'Regular Shift',
      description: 'Working a regular shift during this time',
      badgeColor: AppColors.primary,
      category: EventTypeCategory.workShifts,
    ),
    EventTypeOption(
      id: 'charge',
      name: 'Charge Shift',
      description: 'Acting as a charge nurse for this shift',
      badgeColor: AppColors.primary,
      category: EventTypeCategory.workShifts,
    ),
    EventTypeOption(
      id: 'preceptor',
      name: 'Preceptor Shift',
      description: 'Precepting this shift',
      badgeColor: AppColors.primary,
      category: EventTypeCategory.workShifts,
    ),
    EventTypeOption(
      id: 'charge_preceptor',
      name: 'Charge & Preceptor',
      description: 'Acting as charge and precepting this shift',
      badgeColor: AppColors.primary,
      category: EventTypeCategory.workShifts,
    ),
    EventTypeOption(
      id: 'on_call',
      name: 'On Call',
      description: 'On call to work this time',
      badgeColor: AppColors.primary,
      category: EventTypeCategory.workShifts,
    ),
  ],
  EventTypeCategory.availability: [
    EventTypeOption(
      id: 'available',
      name: 'Available To Work',
      description: 'Available to work during this time',
      badgeColor: AppColors.info,
      category: EventTypeCategory.availability,
    ),
    EventTypeOption(
      id: 'unavailable',
      name: 'Unavailable to Work',
      description: 'Marks you as unavailable for swaps and pickups',
      badgeColor: AppColors.info,
      category: EventTypeCategory.availability,
    ),
  ],
  EventTypeCategory.personal: [
    EventTypeOption(
      id: 'vacation',
      name: 'Vacation',
      description: 'Scheduled vacation days',
      badgeColor: AppColors.success,
      category: EventTypeCategory.personal,
    ),
    EventTypeOption(
      id: 'payday',
      name: 'Payday',
      description: 'Paid on this date',
      badgeColor: AppColors.success,
      category: EventTypeCategory.personal,
    ),
    EventTypeOption(
      id: 'personal',
      name: 'Personal',
      description: 'Personal event will only show up on your calendar',
      badgeColor: AppColors.success,
      category: EventTypeCategory.personal,
    ),
  ],
};

EventTypeOption get defaultEventType =>
    kEventTypeOptions[EventTypeCategory.workShifts]!.first;

EventTypeOption? findEventTypeById(String id) {
  for (final List<EventTypeOption> options in kEventTypeOptions.values) {
    for (final EventTypeOption option in options) {
      if (option.id == id) return option;
    }
  }
  return null;
}

class EventTypeSelectionPage extends StatelessWidget {
  const EventTypeSelectionPage({
    super.key,
    required this.selected,
  });

  final EventTypeOption selected;

  void _handleSelect(BuildContext context, EventTypeOption option) {
    Navigator.of(context).pop(option);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Event Types'),
      ),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(bottom: 24),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  if (index >= EventTypeCategory.values.length) {
                    return null;
                  }
                  final category = EventTypeCategory.values[index];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionHeader(label: category.label),
                      ..._buildCategoryList(context, category),
                      if (index != EventTypeCategory.values.length - 1)
                        const SizedBox(height: 12),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildCategoryList(
    BuildContext context,
    EventTypeCategory category,
  ) {
    final List<EventTypeOption> options = kEventTypeOptions[category]!;
    return [
      for (int i = 0; i < options.length; i++)
        _EventTypeTile(
          option: options[i],
          isSelected: options[i] == selected,
          showDivider: i != options.length - 1,
          onTap: () => _handleSelect(context, options[i]),
        ),
    ];
  }
}

class _EventTypeTile extends StatelessWidget {
  const _EventTypeTile({
    required this.option,
    required this.isSelected,
    required this.showDivider,
    required this.onTap,
  });

  final EventTypeOption option;
  final bool isSelected;
  final bool showDivider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color tileColor = isSelected ? AppColors.surfaceMuted : Colors.white;
    return Column(
      children: [
        Material(
          color: tileColor,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _EventTypeBadge(option: option),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          option.name,
                          style: AppTextStyles.label,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          option.description,
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.textSecondary,
                            height: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 20,
            endIndent: 20,
            color: AppColors.outline,
          ),
      ],
    );
  }
}

class _EventTypeBadge extends StatelessWidget {
  const _EventTypeBadge({required this.option});

  final EventTypeOption option;

  @override
  Widget build(BuildContext context) {
    switch (option.id) {
      case 'charge':
        return _SquareBadge(label: 'C', color: option.badgeColor);
      case 'preceptor':
        return _SquareBadge(label: 'P', color: option.badgeColor);
      case 'charge_preceptor':
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SquareBadge(label: 'C', color: option.badgeColor),
            const SizedBox(width: 6),
            _SquareBadge(label: 'P', color: option.badgeColor),
          ],
        );
      case 'on_call':
        return _IconBadge(icon: Icons.phone, color: option.badgeColor);
      case 'available':
        return _IconBadge(
          icon: Icons.flag_outlined,
          color: option.badgeColor,
        );
      case 'unavailable':
        return _IconBadge(
          icon: Icons.do_not_disturb_on_outlined,
          color: option.badgeColor,
        );
      case 'vacation':
        return _IconBadge(icon: Icons.beach_access, color: option.badgeColor);
      case 'payday':
        return _IconBadge(icon: Icons.attach_money, color: option.badgeColor);
      case 'personal':
        return _IconBadge(
          icon: Icons.person_outline,
          color: option.badgeColor,
        );
      default:
        return _SquareBadge(label: '', color: option.badgeColor);
    }
  }
}

class _SquareBadge extends StatelessWidget {
  const _SquareBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: label.isEmpty
          ? null
          : Text(
              label,
              style: AppTextStyles.label.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withAlpha(31),
        borderRadius: BorderRadius.circular(12),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      color: AppColors.surfaceMuted,
      child: Text(
        label.toUpperCase(),
        style: AppTextStyles.caption.copyWith(
          color: AppColors.textSecondary,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
