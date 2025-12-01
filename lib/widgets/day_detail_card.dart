import 'package:flutter/material.dart';

import '../models/day_schedule.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'nurse_button.dart';

class DayDetailCard extends StatelessWidget {
  const DayDetailCard({
    super.key,
    required this.date,
    this.schedule,
    this.onViewMore,
    this.onViewSwaps,
  });

  final DateTime date;
  final DaySchedule? schedule;
  final VoidCallback? onViewMore;
  final VoidCallback? onViewSwaps;

  static const List<String> _weekdayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  static const List<String> _monthNames = [
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
  Widget build(BuildContext context) {
    final String friendlyDate =
        '${_weekdayNames[date.weekday - 1]}, ${_monthNames[date.month - 1]} ${date.day}';
    final bool hasSchedule = schedule != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            friendlyDate,
            style: AppTextStyles.headingMedium,
          ),
          const SizedBox(height: 6),
          Text(
            hasSchedule ? schedule!.title : 'Day Off',
            style: AppTextStyles.headingLarge,
          ),
          const SizedBox(height: 8),
          Text(
            hasSchedule
                ? schedule!.timeRange
                : 'NO ONE IS SCHEDULED ON THIS DAY',
            style: hasSchedule
                ? AppTextStyles.body.copyWith(color: AppColors.textSecondary)
                : AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                    letterSpacing: 0.6,
                  ),
          ),
          const SizedBox(height: 12),
          if (hasSchedule) ...[
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(schedule!.icon, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        schedule!.location,
                        style: AppTextStyles.body
                            .copyWith(color: AppColors.textPrimary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tap view more for shift details.',
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Create an event or add availability so the team knows your plan for the day.',
              style:
                  AppTextStyles.body.copyWith(color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: NurseButton(
              label: 'View More',
              style: NurseButtonStyle.ghost,
              onPressed: onViewMore,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: NurseButton(
              label: 'View Swaps',
              style: NurseButtonStyle.secondary,
              onPressed: onViewSwaps,
            ),
          ),
        ],
      ),
    );
  }
}
