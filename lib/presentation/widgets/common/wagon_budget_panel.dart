import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/simulation_result.dart';
import '../../../domain/usecases/wagon_capacity.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import 'handbook_reference_chip.dart';
import 'user_figure_dialog.dart';

/// How much of this wagon's deck the load takes and how much is left.
///
/// This is the panel that makes two vehicles on one wagon a real decision
/// rather than a drawing: it adds up the vehicles' lengths, charges the
/// clearance the plates require between neighbours (100 mm between two
/// tracked, 50 mm between two wheeled, 270 mm for a mixed pair), and reports
/// the remainder — or says exactly which figure is missing and offers to take
/// it, since the handbook extract dimensions neither the wagons nor the
/// vehicles.
class WagonBudgetPanel extends ConsumerWidget {
  final String wagonId;

  const WagonBudgetPanel({super.key, required this.wagonId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final budget = ref.watch(wagonBudgetProvider(wagonId));
    if (budget == null) return const SizedBox.shrink();

    final check = checkWagonCapacity(budget);
    final platform = ref.watch(consistPlatformProvider).valueOrNull;
    final statusColor = switch (check.status) {
      CheckStatus.pass => AppColors.inTolerance,
      CheckStatus.fail => AppColors.outOfTolerance,
      CheckStatus.unknown => AppColors.offNominal,
    };

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: statusColor.withValues(alpha: 0.6)),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(AppStrings.wagonCapacitySectionTitle,
                    style: TextStyle(
                        fontSize: AppText.caption,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                        color: AppColors.textSecondary)),
              ),
              HandbookReferenceChip(
                  referenceId: check.referenceId.isEmpty ? 'para-51' : check.referenceId),
            ],
          ),
          const SizedBox(height: 8),
          _BudgetBar(budget: budget, color: statusColor),
          const SizedBox(height: 8),
          _figures(budget),
          const SizedBox(height: 6),
          Text(check.detail,
              style: TextStyle(fontSize: AppText.bodySmall, color: statusColor)),
          if (budget.spanningVehicles.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              AppStrings.wagonCapacitySpanningNote(budget.spanningVehicles.join(', ')),
              style: const TextStyle(
                  fontSize: AppText.caption, color: AppColors.textSecondary),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (budget.deckLengthCm == null && platform != null)
                UserFigureButton(
                  label: AppStrings.wagonCapacityEnterDeckLength,
                  onPressed: () => showUserFigureDialog(
                    context,
                    ref,
                    title: AppStrings.wagonCapacityEnterDeckLength,
                    storageKey: UserDimensionsNotifier.deckKey(platform.id),
                    hint: AppStrings.wagonCapacityEnterHint,
                  ),
                ),
              for (final designation in budget.vehiclesWithoutLength)
                _VehicleLengthButton(designation: designation),
            ],
          ),
        ],
      ),
    );
  }

  Widget _figures(WagonLengthBudget budget) {
    final lines = <String>[
      if (budget.deckLengthCm != null)
        AppStrings.wagonCapacityDeckLabel(budget.deckLengthCm!.toStringAsFixed(0)),
      AppStrings.wagonCapacityUsedLabel(budget.usedCm.toStringAsFixed(0)),
      if (budget.gapCount > 0)
        AppStrings.wagonCapacityGapLabel(
            budget.gapMm ?? 0, budget.gapCount, budget.clearanceCm.toStringAsFixed(0)),
      budget.remainingCm != null
          ? AppStrings.wagonCapacityRemainingLabel(budget.remainingCm!.toStringAsFixed(0))
          : AppStrings.wagonCapacityRemainingUnknown,
    ];
    return Text(
      lines.join('  ·  '),
      style: const TextStyle(
          fontFamily: AppText.mono,
          fontSize: AppText.caption,
          color: AppColors.textPrimary),
    );
  }
}

/// The deck drawn as a bar with the load on it — a glance answer to "how much
/// is left" beside the exact figures.
class _BudgetBar extends StatelessWidget {
  final WagonLengthBudget budget;
  final Color color;

  const _BudgetBar({required this.budget, required this.color});

  @override
  Widget build(BuildContext context) {
    final fraction = budget.usedFraction;
    return Container(
      height: 16,
      decoration: BoxDecoration(
        color: AppColors.ground,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.zero,
      ),
      child: fraction == null
          ? const Center(
              child: Text('?',
                  style: TextStyle(
                      fontSize: AppText.caption, color: AppColors.textSecondary)),
            )
          : LayoutBuilder(
              builder: (context, constraints) => Stack(
                children: [
                  Container(
                    width: constraints.maxWidth * fraction,
                    decoration: BoxDecoration(color: color.withValues(alpha: 0.55)),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Offers to take the length of one vehicle the data does not dimension.
class _VehicleLengthButton extends ConsumerWidget {
  final String designation;

  const _VehicleLengthButton({required this.designation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider).valueOrNull ?? const [];
    final matches = vehicles.where((v) => v.handbookDesignation == designation);
    if (matches.isEmpty) return const SizedBox.shrink();
    final vehicle = matches.first;
    return UserFigureButton(
      label: '${AppStrings.wagonCapacityEnterVehicleLength} — $designation',
      onPressed: () => showUserFigureDialog(
        context,
        ref,
        title: '${AppStrings.wagonCapacityEnterVehicleLength} — $designation',
        storageKey: UserDimensionsNotifier.vehicleKey(vehicle.id),
        hint: AppStrings.wagonCapacityEnterHint,
      ),
    );
  }
}
