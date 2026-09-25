import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/simulation_result.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/usecases/handbook_photo_resolution.dart';
import '../../providers/handbook_providers.dart';
import 'required_equipment_panel.dart';

/// Configures the required equipment one component at a time — a small
/// wizard around [buildEquipmentCard] (the exact same card
/// [RequiredEquipmentPanel] uses for the all-at-once review view), with a
/// "● i / N" progress indicator and Previous/Next controls instead of
/// stacking every slot's card at once. Purely a navigation-position
/// concern (`_index`); no engineering state lives here.
class EquipmentConfigurationWizard extends ConsumerStatefulWidget {
  final SimulationResult result;
  final String placementId;
  final Vehicle vehicle;

  const EquipmentConfigurationWizard({
    super.key,
    required this.result,
    required this.placementId,
    required this.vehicle,
  });

  @override
  ConsumerState<EquipmentConfigurationWizard> createState() => _EquipmentConfigurationWizardState();
}

class _EquipmentConfigurationWizardState extends ConsumerState<EquipmentConfigurationWizard> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final ids = widget.result.requiredHardwareIds;
    if (ids.isEmpty) {
      return const Text(AppStrings.noHardwareResolvedYet,
          style: TextStyle(color: AppColors.textSecondary, fontSize: AppText.bodySmall));
    }
    if (_index >= ids.length) _index = ids.length - 1;

    final vehicle = widget.vehicle;
    final attachmentsAsync = ref.watch(attachmentTypesProvider);
    final measurementsAsync = ref.watch(measurementsProvider);
    final rulesAsync = ref.watch(rulesProvider);
    final linker = ref.watch(referenceLinkerProvider).valueOrNull;

    return attachmentsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text(AppStrings.errorPrefix(e)),
      data: (attachments) => measurementsAsync.when(
        loading: () => const CircularProgressIndicator(),
        error: (e, st) => Text(AppStrings.errorPrefix(e)),
        data: (measurements) {
          final card = buildEquipmentCard(
            hardwareId: ids[_index],
            placementId: widget.placementId,
            vehicle: vehicle,
            attachments: attachments,
            measurements: measurements,
            rules: rulesAsync.valueOrNull,
            photosFor: (hid, refId) => linker == null ? const [] : equipmentPhotosFor(hid, refId, linker),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.equipmentWizardProgress(_index + 1, ids.length),
                  style: const TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold, color: AppColors.label)),
              const SizedBox(height: 8),
              card,
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton.icon(
                    onPressed: _index > 0 ? () => setState(() => _index--) : null,
                    icon: const Icon(Icons.arrow_back, size: 16),
                    label: const Text(AppStrings.equipmentWizardPrevious),
                  ),
                  if (_index < ids.length - 1)
                    ElevatedButton.icon(
                      onPressed: () => setState(() => _index++),
                      icon: const Icon(Icons.arrow_forward, size: 16),
                      label: const Text(AppStrings.equipmentWizardNext),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}
