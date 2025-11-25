import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

class NurseTextField extends StatelessWidget {
  const NurseTextField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.leadingIcon,
    this.trailing,
    this.onChanged,
    this.onSubmitted,
    this.isDense = false,
  });

  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final IconData? leadingIcon;
  final Widget? trailing;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool isDense;

  @override
  Widget build(BuildContext context) {
    final Widget textField = TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: AppTextStyles.body.copyWith(color: AppColors.textPrimary),
      decoration: InputDecoration(
        hintText: hint,
        isDense: isDense,
        prefixIcon: leadingIcon == null
            ? null
            : Icon(
                leadingIcon,
                color: AppColors.textMuted,
              ),
        suffixIcon: trailing,
      ),
    );

    if (label == null) {
      return textField;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label!, style: AppTextStyles.label),
        const SizedBox(height: 8),
        textField,
      ],
    );
  }
}
