import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/platform.dart';
import '../../../data/models/simulation_result.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/models/securing_method.dart';
import '../../../domain/usecases/equipment_selection.dart';
import '../../../domain/usecases/securing_method_resolution.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';

/// "What have I done, what's left, what do I do next?" — derived entirely
/// from already-resolved domain state ([SimulationResult],
/// `placementEquipmentProvider`, `placementSecuringMethodProvider`). This
/// widget never decides PASS/FAIL/UNKNOWN itself; it only reads what
/// `EngineeringValidator` and the pure selection-comparison functions have
/// already determined and turns that into a checklist + a single "next
/// step" suggestion.
class ConfigurationStatusPanel extends ConsumerWidget {
  final Vehicle vehicle;
  final Platform platform;
  final SimulationResult result;

  /// The placed vehicle being summarised. Both the equipment selections and
  /// the applied securing method are stored per placement, so this panel
  /// reports on one vehicle on one wagon rather than on a single global
  /// selection shared by the whole train.
  final String placementId;

  const ConfigurationStatusPanel({
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
        ref.watch(effectivePlacementEquipmentProvider(placementId));
    final appliedMethod = ref.watch(effectiveSecuringMethodProvider(placementId));

    final items = <_StatusItem>[
      _StatusItem(
          done: true, label: AppStrings.configurationVehicleSelectedLabel(vehicle.handbookDesignation)),
      _StatusItem(done: true, label: AppStrings.configurationPlatformSelectedLabel(platform.name)),
    ];
    String? nextStep;

    final resolution =
        vehicle.category == VehicleCategory.tracked ? resolveSecuringMethodOptions(vehicle) : null;
    if (resolution is AlternativeSecuringMethods && appliedMethod == null) {
      items.add(const _StatusItem(done: false, label: AppStrings.configurationMethodPendingLabel));
      nextStep ??= AppStrings.configurationNextStepChooseMethod;
    } else if (resolution is AlternativeSecuringMethods &&
        !resolution.methodNumbers.contains(appliedMethod)) {
      items.add(const _StatusItem(done: false, error: true, label: AppStrings.configurationMethodInvalidLabel));
      nextStep ??= AppStrings.configurationNextStepChooseMethod;
    } else if (result.requiredHardwareIds.isEmpty) {
      items.add(const _StatusItem(done: false, label: AppStrings.configurationMethodUnknownLabel));
    } else {
      items.add(const _StatusItem(done: true, label: AppStrings.configurationMethodSelectedLabel));
    }

    for (final hardwareId in result.requiredHardwareIds) {
      final matches = attachments.where((a) => a.id == hardwareId);
      final name = matches.isEmpty ? hardwareId : matches.first.name;
      final requiredType = requiredTypeCodeFor(hardwareId, vehicle, measurements: measurements);
      final selected = equipmentSelections[hardwareId];

      if (requiredType == null) {
        // No single mandatory type for this slot (e.g. wire-lashing
        // diameter) — informational only, never blocks completion.
        items.add(_StatusItem(
          done: true,
          label: selected == null
              ? AppStrings.configurationEquipmentInfoLabel(name)
              : AppStrings.configurationEquipmentOkLabel(name),
        ));
        continue;
      }
      if (selected == null) {
        items.add(_StatusItem(done: false, label: AppStrings.configurationEquipmentPendingLabel(name)));
        nextStep ??= AppStrings.configurationNextStepChooseType(name);
      } else if (selected != requiredType) {
        items.add(_StatusItem(
            done: false, error: true, label: AppStrings.configurationEquipmentMismatchLabel(name)));
        nextStep ??= AppStrings.configurationNextStepFixMismatch(name);
      } else {
        items.add(_StatusItem(done: true, label: AppStrings.configurationEquipmentOkLabel(name)));
      }
    }

    final allDone = items.every((i) => i.done);
    nextStep ??= allDone ? AppStrings.configurationCompleteLabel : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.configurationStatusTitle,
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.bodySmall, letterSpacing: 0.5)),
          const SizedBox(height: 10),
          ...items.map((i) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      i.done
                          ? Icons.check_circle
                          : i.error
                              ? Icons.error
                              : Icons.radio_button_unchecked,
                      size: 14,
                      color: i.done
                          ? AppColors.inTolerance
                          : i.error
                              ? AppColors.outOfTolerance
                              : AppColors.offNominal,
                    ),
                    const SizedBox(width: 8),
                    Expanded(child: Text(i.label, style: const TextStyle(fontSize: AppText.bodySmall))),
                  ],
                ),
              )),
          if (nextStep != null) ...[
            const SizedBox(height: 10),
            const Divider(color: AppColors.hairline, height: 1),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.arrow_forward, size: 14, color: AppColors.label),
                const SizedBox(width: 8),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textPrimary),
                      children: [
                        const TextSpan(
                          text: '${AppStrings.configurationNextStepLabel} ',
                          style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.label),
                        ),
                        TextSpan(text: nextStep),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusItem {
  final bool done;
  final bool error;
  final String label;
  const _StatusItem({required this.done, this.error = false, required this.label});
}
