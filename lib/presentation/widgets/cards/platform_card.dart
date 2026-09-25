import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/platform.dart';
import '../common/app_surfaces.dart';
import '../common/handbook_reference_chip.dart';
import '../common/instrument.dart';

class PlatformCard extends StatelessWidget {
  final Platform platform;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback? onInfoTap;

  /// Whether this wagon may carry the load the user ordered. A card for a
  /// wagon that may not is still shown and still tappable — rejecting it is
  /// the exercise — but it is marked, and tapping it explains why instead of
  /// loading anything onto it.
  final bool approved;

  const PlatformCard({
    super.key,
    required this.platform,
    required this.onTap,
    this.selected = false,
    this.onInfoTap,
    this.approved = true,
  });

  static IconData _wagonIcon(PlatformKind kind) {
    switch (kind) {
      case PlatformKind.coveredWagon:
        return Icons.inventory_2;
      case PlatformKind.tankWagon:
        return Icons.local_gas_station;
      case PlatformKind.openFlatcar:
      case PlatformKind.echelonClass:
        return Icons.train;
    }
  }

  @override
  Widget build(BuildContext context) {
    // A ruled row. Every wagon kind the trainee chooses between is listed,
    // approved or not, and a border around each one says nothing the rule and
    // the verdict chip do not already say.
    return Container(
      decoration: BoxDecoration(
        color: selected ? AppColors.instrument.withValues(alpha: 0.07) : Colors.transparent,
        border: const Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg, horizontal: AppSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(_wagonIcon(platform.kind),
                      color: approved ? AppColors.label : AppColors.textSecondary, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      platform.name.toUpperCase(),
                      style: AppText.legend(
                        size: AppText.sectionTitle,
                        color: approved ? AppColors.textPrimary : AppColors.textSecondary,
                        tracking: 1.4,
                      ),
                    ),
                  ),
                  if (!approved)
                    const Padding(
                      padding: EdgeInsets.only(right: AppSpace.xs),
                      child: VerdictChip(
                        tone: AppTone.fail,
                        label: AppStrings.wagonNotApprovedBadge,
                        dense: true,
                      ),
                    ),
                  if (onInfoTap != null)
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 18),
                      tooltip: AppStrings.platformDetailsTooltip,
                      visualDensity: VisualDensity.compact,
                      onPressed: onInfoTap,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              // A wagon that cannot be loaded leads with the reason: its spec
              // rows are all "not in the source" anyway, and four lines of that
              // buried the one thing the trainee needs to read.
              if (!approved && platform.displayNotApprovedReason != null) ...[
                Text(
                  platform.displayNotApprovedReason!,
                  style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
              ],
              // One table, so the four values share a right edge and none of
              // them is broken across two lines to fit a reserved width.
              ReadoutTable(
                dense: true,
                rows: [
                  if (approved && platform.maxAxleLoadWheeledT.isAvailable)
                    ReadoutRow(
                      label: AppStrings.maxAxleLoadLabel,
                      value: platform.maxAxleLoadWheeledT.display(),
                      unit: 't',
                    ),
                  if (platform.trainMaxWeightT != null)
                    ReadoutRow(
                      label: AppStrings.trainClassMaxWeightLabel,
                      value: platform.trainMaxWeightT!.display(),
                      unit: 't',
                    ),
                  if (approved)
                    ReadoutRow(
                      label: AppStrings.lengthLabel,
                      value: platform.lengthCm.isAvailable
                          ? platform.lengthCm.display()
                          : AppStrings.notAvailableShort,
                      unit: platform.lengthCm.isAvailable ? 'sm' : null,
                      valueColor: platform.lengthCm.isAvailable
                          ? AppColors.textPrimary
                          : AppColors.offNominal,
                    ),
                  if (approved)
                    ReadoutRow(
                      label: AppStrings.widthLabel,
                      value: platform.widthCm.isAvailable
                          ? platform.widthCm.display()
                          : AppStrings.notAvailableShort,
                      unit: platform.widthCm.isAvailable ? 'sm' : null,
                      valueColor: platform.widthCm.isAvailable
                          ? AppColors.textPrimary
                          : AppColors.offNominal,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              HandbookReferenceChip(referenceId: platform.referenceId),
            ],
          ),
        ),
      ),
    );
  }

}
