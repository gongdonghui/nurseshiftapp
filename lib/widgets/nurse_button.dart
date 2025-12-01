import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

enum NurseButtonStyle { primary, secondary, ghost, destructive }

class NurseButton extends StatelessWidget {
  const NurseButton({
    super.key,
    required this.label,
    this.onPressed,
    this.leading,
    this.trailing,
    this.style = NurseButtonStyle.primary,
    this.isLoading = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final NurseButtonStyle style;
  final Widget? leading;
  final Widget? trailing;
  final bool isLoading;

  Color get _background {
    switch (style) {
      case NurseButtonStyle.secondary:
        return AppColors.surfaceMuted;
      case NurseButtonStyle.ghost:
        return Colors.transparent;
      case NurseButtonStyle.destructive:
        return Colors.white;
      case NurseButtonStyle.primary:
        return AppColors.primary;
    }
  }

  Color get _foreground {
    switch (style) {
      case NurseButtonStyle.secondary:
        return AppColors.textPrimary;
      case NurseButtonStyle.ghost:
        return AppColors.primary;
      case NurseButtonStyle.destructive:
        return Colors.red;
      case NurseButtonStyle.primary:
        return Colors.white;
    }
  }

  BorderSide? get _border {
    switch (style) {
      case NurseButtonStyle.ghost:
        return const BorderSide(color: AppColors.outline);
      case NurseButtonStyle.destructive:
        return BorderSide(color: Colors.red.shade300, width: 1.2);
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool disabled = onPressed == null;
    final Color background = disabled
        ? AppColors.surfaceMuted
        : _background;

    final Color foreground = disabled
        ? AppColors.textMuted
        : _foreground;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(26),
        border: _border == null ? null : Border.fromBorderSide(_border!),
        boxShadow: disabled || style != NurseButtonStyle.primary
            ? null
            : [
                BoxShadow(
                  color: AppColors.primary.withAlpha(51),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: disabled || isLoading ? null : onPressed,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  IconTheme(
                    data: IconThemeData(color: foreground, size: 20),
                    child: leading!,
                  ),
                  const SizedBox(width: 8),
                ],
                Flexible(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 200),
                    style: AppTextStyles.label.copyWith(color: foreground),
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (isLoading) ...[
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: foreground,
                    ),
                  ),
                ] else if (trailing != null) ...[
                  const SizedBox(width: 8),
                  IconTheme(
                    data: IconThemeData(color: foreground, size: 20),
                    child: trailing!,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
