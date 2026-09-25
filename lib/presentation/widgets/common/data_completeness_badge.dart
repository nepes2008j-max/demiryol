import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';

/// Honest indicator of how much of a vehicle/platform's spec is real
/// handbook data vs. still-pending TODO placeholders. Never hides this.
class DataCompletenessBadge extends StatelessWidget {
  final double completeness; // 0.0 - 1.0

  const DataCompletenessBadge({super.key, required this.completeness});

  @override
  Widget build(BuildContext context) {
    final pct = (completeness * 100).round();
    // Missing data is unconfirmed, never a failure: a record the extract does
    // not fill in has not failed a check, and drawing it in the interface's
    // one red would say the vehicle was rejected. Below the amber threshold
    // the badge only goes dimmer, not redder.
    final color = completeness >= 0.8 ? AppColors.inTolerance : AppColors.offNominal;
    final alpha = completeness >= 0.3 ? 1.0 : 0.75;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10 * alpha),
        border: Border.all(color: color.withValues(alpha: 0.55 * alpha)),
      ),
      child: Text(
        AppStrings.dataCompletenessBadge(pct),
        style: AppText.legend(
          size: AppText.caption,
          color: color.withValues(alpha: alpha),
          tracking: 1.0,
        ),
      ),
    );
  }
}
