import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Visual data used to decorate a specific day on the month grid.
class CalendarDayData {
  const CalendarDayData({
    this.icon,
    this.iconColor,
    this.highlightColor,
  });

  final IconData? icon;
  final Color? iconColor;
  final Color? highlightColor;
}

class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.month,
    this.selectedDate,
    required this.onDaySelected,
    this.dayData = const {},
  });

  final DateTime month;
  final DateTime? selectedDate;
  final ValueChanged<DateTime> onDaySelected;
  final Map<int, CalendarDayData> dayData;

  @override
  Widget build(BuildContext context) {
    final DateTime firstDay = DateTime(month.year, month.month, 1);
    final int daysInMonth = DateUtils.getDaysInMonth(month.year, month.month);
    final int leadingEmptyCells = firstDay.weekday % 7;

    final List<DateTime?> cells = <DateTime?>[
      for (int i = 0; i < leadingEmptyCells; i++) null,
      for (int day = 1; day <= daysInMonth; day++)
        DateTime(month.year, month.month, day),
    ];

    while (cells.length % 7 != 0) {
      cells.add(null);
    }

    final int totalRows = cells.length ~/ 7;

    return Column(
      children: [
        Row(
          children: const [
            _WeekdayLabel('Su'),
            _WeekdayLabel('M'),
            _WeekdayLabel('Tu'),
            _WeekdayLabel('W'),
            _WeekdayLabel('Th'),
            _WeekdayLabel('F'),
            _WeekdayLabel('Sa'),
          ],
        ),
        const SizedBox(height: 12),
        for (int row = 0; row < totalRows; row++) ...[
          Row(
            children: [
              for (int col = 0; col < 7; col++)
                Expanded(
                  child: _CalendarCell(
                    date: cells[row * 7 + col],
                    isSelected: _isSameDay(cells[row * 7 + col], selectedDate),
                    data: dayData[cells[row * 7 + col]?.day ?? -1],
                    onTap: onDaySelected,
                  ),
                ),
            ],
          ),
          if (row != totalRows - 1) const SizedBox(height: 8),
        ],
      ],
    );
  }

  static bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Center(
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
        ),
      ),
    );
  }
}

class _CalendarCell extends StatelessWidget {
  const _CalendarCell({
    required this.date,
    required this.isSelected,
    required this.onTap,
    this.data,
  });

  final DateTime? date;
  final bool isSelected;
  final CalendarDayData? data;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: AspectRatio(
        aspectRatio: 1,
        child: date == null ? const SizedBox.shrink() : _buildCellContent(),
      ),
    );
  }

  Widget _buildCellContent() {
    final bool hasHighlight = !isSelected && data?.highlightColor != null;

    final Color background = isSelected
        ? AppColors.primary
        : (data?.highlightColor ?? Colors.transparent);

    final Color textColor = isSelected
        ? Colors.white
        : hasHighlight
            ? AppColors.primary
            : AppColors.textPrimary;

    final Color iconColor =
        isSelected ? Colors.white : data?.iconColor ?? AppColors.primary;

    final TextStyle dayStyle = AppTextStyles.label.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      height: 1.0,
      color: textColor,
    );

    return GestureDetector(
      onTap: () => onTap(date!),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${date!.day}', style: dayStyle),
              if (data?.icon != null) ...[
                const SizedBox(height: 2),
                Icon(data!.icon, color: iconColor, size: 14),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
