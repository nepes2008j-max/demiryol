import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// A compact "is this handbook value available?" row — a green check when
/// it is, an amber warning when it isn't — used wherever a card or dialog
/// needs to show data-availability at a glance instead of a raw value row
/// that would otherwise just read "Elýeterli däl" for most vehicles in
/// this extract.
class DataStatusRow extends StatelessWidget {
  final bool available;
  final String label;
  final double fontSize;

  const DataStatusRow({super.key, required this.available, required this.label, this.fontSize = 11});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            available ? Icons.check_circle : Icons.warning_amber,
            size: fontSize + 3,
            color: available ? AppColors.inTolerance : AppColors.offNominal,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: TextStyle(fontSize: fontSize))),
        ],
      ),
    );
  }
}
