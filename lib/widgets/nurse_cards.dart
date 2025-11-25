import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';
import 'nurse_button.dart';

class ShiftCard extends StatelessWidget {
  const ShiftCard({
    super.key,
    required this.dayLabel,
    required this.dateNumber,
    required this.shiftType,
    required this.isHighlighted,
  });

  final String dayLabel;
  final String dateNumber;
  final String shiftType;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final Color background = isHighlighted ? AppColors.primary : AppColors.surfaceMuted;
    final Color foreground = isHighlighted ? Colors.white : AppColors.textPrimary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            dayLabel,
            style: AppTextStyles.caption.copyWith(
              color: isHighlighted ? Colors.white70 : AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            dateNumber,
            style: AppTextStyles.headingMedium.copyWith(color: foreground),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.nights_stay_rounded, size: 18, color: Colors.white70),
              const SizedBox(width: 6),
              Text(
                shiftType,
                style: AppTextStyles.body.copyWith(color: foreground),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.icon,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                shape: BoxShape.circle,
              ),
              child: icon,
            ),
            const SizedBox(width: 16),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.headingMedium),
                const SizedBox(height: 6),
                Text(subtitle, style: AppTextStyles.body),
              ],
            ),
          ),
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class ColleagueSuggestionCard extends StatelessWidget {
  const ColleagueSuggestionCard({
    super.key,
    required this.name,
    required this.department,
    required this.facility,
    this.onConnect,
  });

  final String name;
  final String department;
  final String facility;
  final VoidCallback? onConnect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.surfaceMuted,
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: AppTextStyles.headingMedium,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.headingMedium),
                Text(
                  department,
                  style: AppTextStyles.body.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  facility,
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
          NurseButton(
            label: 'Connect',
            onPressed: onConnect,
            style: NurseButtonStyle.secondary,
          ),
        ],
      ),
    );
  }
}
