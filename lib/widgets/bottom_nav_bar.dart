import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NurseBottomNav extends StatelessWidget {
  const NurseBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<NurseBottomNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppColors.outline),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (int i = 0; i < items.length; i++)
            _BottomItem(
              data: items[i],
              isActive: i == currentIndex,
              onTap: () => onTap(i),
            ),
        ],
      ),
    );
  }
}

class NurseBottomNavItem {
  const NurseBottomNavItem(this.icon, this.label, {this.badgeCount = 0});

  final IconData icon;
  final String label;
  final int badgeCount;
}

class _BottomItem extends StatelessWidget {
  const _BottomItem({
    required this.data,
    required this.isActive,
    required this.onTap,
  });

  final NurseBottomNavItem data;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = isActive ? AppColors.primary : AppColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(data.icon, color: color),
              if (data.badgeCount > 0)
                Positioned(
                  right: -10,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${data.badgeCount}',
                      style: AppTextStyles.caption.copyWith(color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            data.label,
            style: AppTextStyles.caption.copyWith(color: color),
          ),
        ],
      ),
    );
  }
}
