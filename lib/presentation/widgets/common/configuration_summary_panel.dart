import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_rule.dart';
import '../../../data/models/platform.dart';
import '../../../data/models/simulation_result.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/usecases/equipment_selection.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';

/// "BERKITME KONFIGURASIÝASY" — the final read-only recap shown right
/// before the user moves on to the full Engineering Analysis: vehicle,
/// platform, resolved method, every configured equipment slot with its
/// applied type, how many are configured/matching, and which checks
/// remain UNKNOWN for lack of source data. Every value here is read from
/// already-resolved state ([SimulationResult], the selection providers) —
/// nothing is computed fresh.
class ConfigurationSummaryPanel extends ConsumerWidget {
  final Vehicle vehicle;
  final Platform platform;
  final SimulationResult result;

  /// The placed vehicle being summarised. Both the equipment selections and
  /// the applied securing method are stored per placement, so this panel
  /// reports on one vehicle on one wagon rather than on a single global
  /// selection shared by the whole train.
  final String placementId;

  const ConfigurationSummaryPanel({
    super.key,
    required this.vehicle,
    required this.platform,
    required this.result,
    required this.placementId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachments = ref.watch(attachmentTypesProvider).valueOrNull ?? const [];
    final measurements = ref.watch(measurementsProvider).valueOrNull ?? const {};
    final equipmentSelections =
        ref.watch(placementEquipmentProvider)[placementId] ?? const <String, String>{};
    final appliedMethod = ref.watch(placementSecuringMethodProvider)[placementId];
    final rules = ref.watch(ruleEntriesProvider).valueOrNull ?? const <HandbookRule>[];

    final methodName = _methodName(rules, appliedMethod);
    final unknownChecks = result.checks.where((c) => c.status == CheckStatus.unknown).toList();

    var configuredCount = 0;
    var scoredCount = 0;
    var matchingCount = 0;
    final equipmentLines = <String>[];
    for (final hardwareId in result.requiredHardwareIds) {
      final matches = attachments.where((a) => a.id == hardwareId);
      final name = matches.isEmpty ? hardwareId : matches.first.name;
      final selected = equipmentSelections[hardwareId];
      if (selected != null) configuredCount++;
      final required = requiredTypeCodeFor(hardwareId, vehicle, measurements: measurements);
      if (required != null) {
        scoredCount++;
        if (selected == required) matchingCount++;
      }
      equipmentLines.add(AppStrings.configurationSummaryEquipmentLine(
          name, selected ?? AppStrings.configurationSummaryEquipmentPending));
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.labelDim),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.configurationSummaryHeading,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.bodySmall, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          _Line(label: AppStrings.configurationSummaryVehicleLabel, value: vehicle.handbookDesignation),
          _Line(label: AppStrings.configurationSummaryPlatformLabel, value: platform.name),
          _Line(
            label: AppStrings.configurationSummaryMethodLabel,
            value: methodName ?? AppStrings.configurationSummaryMethodPending,
          ),
          if (equipmentLines.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text(AppStrings.configurationSummaryEquipmentHeading,
                style: TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold, color: AppColors.label)),
            const SizedBox(height: 4),
            for (final line in equipmentLines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Text('• $line', style: const TextStyle(fontSize: AppText.bodySmall)),
              ),
            const SizedBox(height: 8),
            Text(
              AppStrings.configurationSummaryConfiguredCount(configuredCount, result.requiredHardwareIds.length),
              style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary),
            ),
            if (scoredCount > 0)
              Text(
                AppStrings.configurationSummaryMatchingCount(matchingCount, scoredCount),
                style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary),
              ),
          ],
          if (unknownChecks.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(AppStrings.configurationSummaryUnknownHeading,
                style: TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold, color: AppColors.offNominal)),
            const SizedBox(height: 4),
            for (final c in unknownChecks)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 1),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.warning_amber, size: 12, color: AppColors.offNominal),
                    const SizedBox(width: 6),
                    Expanded(
                        child: Text(c.label, style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.offNominal))),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.fact_check),
              label: const Text(AppStrings.configurationSummaryAnalysisButton),
              onPressed: () => context.go('/analysis'),
            ),
          ),
        ],
      ),
    );
  }

  String? _methodName(List<HandbookRule> rules, int? appliedMethod) {
    if (vehicle.ironSpurType != null) return 'Demir şpor — ${vehicle.ironSpurType}';
    if (vehicle.ironChockBootType != null) return 'Demir başmak — ${vehicle.ironChockBootType}';
    if (appliedMethod == null) return null;
    final matches = rules.where((r) => r.isMethod && r.methodNumber == appliedMethod);
    return matches.isEmpty ? '$appliedMethod-nji usul' : matches.first.displayTitle;
  }
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  const _Line({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
              width: 110,
              child: Text(label, style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold))),
        ],
      ),
    );
  }
}
