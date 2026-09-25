import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A "Label: value" row used across detail dialogs.
class LabeledRow extends StatelessWidget {
  final String label;
  final String value;
  final double labelWidth;

  const LabeledRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 170,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: labelWidth,
            child: Text(label, style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: AppText.bodySmall))),
        ],
      ),
    );
  }
}
