import '../../core/localization/app_strings.dart';
import '../../data/models/simulation_result.dart';
import '../../data/models/vehicle.dart';
import 'wood_chock_sizing.dart';

/// The handbook-mandated type code for a required hardware slot, when the
/// extracted data fixes exactly one. Iron spurs/chock-boots are
/// vehicle-specific (Table 13 / Table 11, looked up by the vehicle's own
/// `ironSpurType`/`ironChockBootType` field); KGUUB tracked variants and the
/// wood-chock size are fixed by the vehicle's combat weight (Table 8 /
/// Table 3, matching `equipment_catalog.dart`'s own option typeCode
/// format). Returns null when the handbook extract does not fix a single
/// mandatory type for this slot (e.g. wire-lashing diameter, which Table 7
/// leaves to the installed angle, not a per-vehicle rule — or wood-chock
/// sizing when the vehicle's combat weight itself isn't available) — such
/// slots are never scored PASS/FAIL, only offered as informational choices.
String? requiredTypeCodeFor(String hardwareId, Vehicle vehicle, {Map<String, dynamic>? measurements}) {
  switch (hardwareId) {
    case 'att-iron-spur':
      return vehicle.ironSpurType;
    case 'att-iron-chock-boot':
      return vehicle.ironChockBootType;
    case 'att-kguub-1g':
      return 'KGUUB-1G';
    case 'att-kguub-2g':
      return 'KGUUB-2G';
    case 'att-kguub-1k':
      return 'KGUUB-1K';
    case 'att-kguub-2k':
      return 'KGUUB-2K';
    case 'att-wood-chock':
      if (measurements == null) return null;
      if (vehicle.category == VehicleCategory.wheeled) {
        // Table 2 sizes a wheeled vehicle's chock by WHEEL DIAMETER, which no
        // vehicle record carries. Returning the tracked weight bracket here
        // (which this did) mandated a size from the wrong table; with nothing
        // to look the right one up with, the honest answer is that the
        // handbook does not fix a size for this vehicle yet.
        return null;
      }
      if (!vehicle.bracketWeightT.isAvailable) return null;
      final range = matchingWoodChockWeightRange(vehicle.bracketWeightT.asDouble!, measurements);
      return range == null ? null : '$range t';
    default:
      return null;
  }
}

/// Compares a user's equipment-type selection against the handbook-mandated
/// type for that slot. Returns null when there is nothing to score yet (no
/// mandatory type for this slot, or no selection made) — this function
/// never guesses a PASS/FAIL verdict, matching `EngineeringValidator`'s own
/// unknown-over-assumption rule.
ValidationCheck? checkEquipmentSelection({
  required String referenceId,
  required String? requiredTypeCode,
  required String? selectedTypeCode,
}) {
  if (requiredTypeCode == null || selectedTypeCode == null) return null;
  final matches = selectedTypeCode == requiredTypeCode;
  return ValidationCheck(
    ruleId: 'rule-equipment-selection-match',
    label: AppStrings.equipmentSelectionCheckLabel,
    status: matches ? CheckStatus.pass : CheckStatus.fail,
    detail: matches
        ? AppStrings.equipmentSelectionMatchDetail(selectedTypeCode)
        : AppStrings.equipmentSelectionMismatchDetail(requiredTypeCode, selectedTypeCode),
    referenceId: referenceId,
  );
}
