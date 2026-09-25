import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle.dart';

/// Says out loud when a vehicle's figures did not come from the handbook.
///
/// Two kinds of record are not handbook-extracted. The three wheeled trucks
/// are the project's own design-mockup data, added so the wheeled half of the
/// handbook's rules could be reached at all; the T-90S carries the
/// manufacturer's published specification, because the handbook's catalogue
/// has no modern main battle tank in it at all. A trainee reading a weight
/// off one of those cards must be able to see that it is not an extracted
/// figure, so this badge sits wherever the card or the spec sheet shows one —
/// next to [DataCompletenessBadge], which answers the different question of
/// *how much* of the record is filled in.
///
/// Renders nothing for a handbook-sourced vehicle: the normal case needs no
/// mark, and a badge on every card would stop being read.
class DataSourceBadge extends StatelessWidget {
  final VehicleDataSource dataSource;

  /// True when at least one figure in play was typed in by the instructor
  /// rather than extracted. Badged for the same reason as mockup data: a
  /// number the handbook never supplied must never read as one it did.
  final bool hasUserFigures;

  const DataSourceBadge({
    super.key,
    required this.dataSource,
    this.hasUserFigures = false,
  });

  /// Whether this badge draws anything at all.
  ///
  /// Exposed because a caller laying out a row of badges needs to know before
  /// it lays them out: a widget that renders nothing still takes its share of
  /// a [Wrap]'s spacing, which leaves a gap with no badge in it.
  static bool isVisible(
    VehicleDataSource dataSource, {
    bool hasUserFigures = false,
  }) =>
      hasUserFigures || dataSource != VehicleDataSource.handbook;

  @override
  Widget build(BuildContext context) {
    if (!isVisible(dataSource, hasUserFigures: hasUserFigures)) {
      return const SizedBox.shrink();
    }
    if (hasUserFigures) {
      return Tooltip(
        message: AppStrings.wagonCapacityUserValueNote,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
          decoration: BoxDecoration(
            color: AppColors.label.withValues(alpha: 0.15),
            border: Border.all(color: AppColors.labelDim),
            borderRadius: BorderRadius.zero,
          ),
          child: const Text(
            AppStrings.wagonCapacityUserValueBadge,
            style: TextStyle(
              fontSize: 9,
              color: AppColors.label,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ),
      );
    }
    final (String badge, String tooltip) = switch (dataSource) {
      VehicleDataSource.manufacturerSpec => (
          AppStrings.dataSourceManufacturerBadge,
          AppStrings.dataSourceManufacturerTooltip,
        ),
      VehicleDataSource.transportTable => (
          AppStrings.dataSourceTransportTableBadge,
          AppStrings.dataSourceTransportTableTooltip,
        ),
      _ => (AppStrings.dataSourceMockupBadge, AppStrings.dataSourceMockupTooltip),
    };
    return Tooltip(
      message: tooltip,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.offNominal.withValues(alpha: 0.15),
          border: Border.all(color: AppColors.offNominal),
          borderRadius: BorderRadius.zero,
        ),
        child: Text(
          badge,
          style: const TextStyle(
            fontSize: AppText.caption,
            color: AppColors.offNominal,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}
