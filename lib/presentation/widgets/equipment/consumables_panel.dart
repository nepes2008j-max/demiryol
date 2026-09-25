import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/usecases/consumables.dart';
import '../../../domain/usecases/wire_lashing_angle.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../common/handbook_reference_chip.dart';

/// What to draw from stores for this vehicle, worked out from the method and
/// the layout case the trainee chose.
///
/// The handbook's tables were all in the app already — chocks per case, nails
/// per chock, wire and staples per weight bracket — but nothing ever
/// multiplied them out, so a trainee could finish a configuration without once
/// being told how many nails it takes. A line whose quantity needs a figure
/// the source lacks is still listed, greyed, with what is missing: leaving it
/// out would understate the job.
class ConsumablesPanel extends ConsumerWidget {
  final String placementId;
  final Vehicle vehicle;
  final List<String> requiredHardwareIds;

  const ConsumablesPanel({
    super.key,
    required this.placementId,
    required this.vehicle,
    required this.requiredHardwareIds,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements = ref.watch(measurementsProvider).valueOrNull;
    final rules = ref.watch(rulesProvider).valueOrNull;
    if (measurements == null || rules == null) return const SizedBox.shrink();

    // Table 7's answer for this lashing, when its angles have been measured.
    // It is passed in so the list can say when the two handbook sources for
    // the strand count disagree rather than printing one of them as if it
    // were the only one.
    final dimensions = ref.watch(userDimensionsProvider);
    final axis = dimensions[UserDimensionsNotifier.lashingAxisAngleKey(placementId)];
    final floor = dimensions[UserDimensionsNotifier.lashingFloorAngleKey(placementId)];
    final byAngle = (axis == null || floor == null)
        ? null
        : lashingStrandCount(
            axisAngleDeg: axis,
            floorAngleDeg: floor,
            measurements: measurements,
          ).strands;

    final lines = consumablesFor(
      vehicle: vehicle,
      arrangement: ref.watch(placementSelectedArrangementProvider(placementId)),
      requiredHardwareIds: requiredHardwareIds,
      measurements: measurements,
      rules: rules,
      strandsFromMeasuredAngles: byAngle,
    );

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.consumablesHeading,
              style: TextStyle(
                  fontSize: AppText.sectionTitle,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5)),
          const SizedBox(height: 2),
          const Text(AppStrings.consumablesSubtitle,
              style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
          const SizedBox(height: 10),
          if (lines.isEmpty)
            const Text(AppStrings.consumablesNothingYet,
                style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary))
          else
            for (final line in lines) _ConsumableRow(line: line),
        ],
      ),
    );
  }
}

class _ConsumableRow extends StatelessWidget {
  final ConsumableLine line;

  const _ConsumableRow({required this.line});

  @override
  Widget build(BuildContext context) {
    final resolved = line.isResolved;
    final color = resolved ? AppColors.textPrimary : AppColors.textSecondary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 74,
            child: Text(
              resolved ? '${line.quantity} ${line.unit}' : '—',
              style: TextStyle(
                fontFamily: AppText.mono,
                fontSize: AppText.label,
                fontWeight: FontWeight.bold,
                color: resolved ? AppColors.label : AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(line.name, style: TextStyle(fontSize: AppText.body, color: color)),
                if (line.specification != null)
                  Text(line.specification!,
                      style: const TextStyle(
                          fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
                if (line.note != null)
                  Text(line.note!,
                      style: const TextStyle(
                          fontSize: AppText.caption, color: AppColors.offNominal)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Bounded: a citation label can be as long as
          // "Madda 31 / Tablisa 11,13", and as a plain row child the chip is
          // measured with unbounded width — it would push the row past its
          // card rather than ellipsising inside its own box.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 130),
            child: HandbookReferenceChip(referenceId: line.referenceId),
          ),
        ],
      ),
    );
  }
}
