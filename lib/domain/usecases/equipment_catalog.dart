import '../../core/localization/app_strings.dart';
import '../../data/models/attachment_type.dart';
import '../../data/models/vehicle.dart';
import '../models/equipment_option.dart';
import 'wood_chock_sizing.dart';

/// Builds the list of selectable handbook-catalog entries for one required
/// hardware id, straight from the already-loaded `measurements.json` tables
/// (and, for wire lashing, `attachments.json`'s available-diameter list).
/// Returns an empty list for any hardware id with no catalog table in the
/// current extract — the UI must show "no catalog yet" rather than a
/// fabricated option.
List<EquipmentOption> equipmentOptionsFor(
  String hardwareId,
  Map<String, dynamic> measurements,
  List<AttachmentType> attachments, {
  /// Which vehicle the options are being offered for. It matters for the
  /// wood chock and nothing else: the handbook sizes a tracked vehicle's
  /// chock from Table 3 by combat weight and a wheeled vehicle's from
  /// Table 2 by wheel diameter, so offering one vehicle the other's table
  /// would put a size in front of the trainee that the handbook never
  /// prescribed for it. Defaults to tracked, which is what every caller
  /// meant while the catalogue held tracked vehicles only.
  VehicleCategory category = VehicleCategory.tracked,
}) {
  switch (hardwareId) {
    case 'att-iron-spur':
      return _fromRowTable(
        measurements['ironSpurTable'] as Map<String, dynamic>?,
        hardwareId,
        (row) => {
          AppStrings.equipmentOptionBasePlateLabel: '${row['basePlateMm']} mm',
          AppStrings.equipmentOptionCombHeightLabel: '${row['combHeightMm']} mm',
          AppStrings.equipmentOptionSetWeightLabel: '${row['setWeightKg4Spurs']} kg',
        },
      );
    case 'att-iron-chock-boot':
      return _fromRowTable(
        measurements['ironChockBootTable'] as Map<String, dynamic>?,
        hardwareId,
        (row) => {
          AppStrings.equipmentOptionBasePlateLabel: '${row['basePlateMm']} mm',
          AppStrings.equipmentOptionPinLabel: '${row['pinMm']} mm',
          AppStrings.equipmentOptionSetWeightLabel: '${row['setWeightKg4Boots']} kg',
          if (row['forVehicles'] != null)
            AppStrings.equipmentOptionForVehiclesLabel: (row['forVehicles'] as List).join(', '),
        },
      );
    case 'att-kguub-1g':
    case 'att-kguub-2g':
      return _fromRowTable(
        measurements['reusableChockTrackedTable'] as Map<String, dynamic>?,
        hardwareId,
        (row) => {
          AppStrings.equipmentOptionCombatWeightRangeLabel: '${row['combatWeightRangeT']} t',
          AppStrings.equipmentOptionBasePlateLabel: '${row['basePlateMm']} mm',
          AppStrings.equipmentOptionPinCountLabel: '${row['pinCount']}',
          AppStrings.equipmentOptionPinLabel: '${row['pinMm']} mm',
          AppStrings.equipmentOptionSetWeightLabel: '${row['setWeightKg4Posts']} kg',
        },
      );
    case 'att-kguub-1k':
    case 'att-kguub-2k':
      return _fromRowTable(
        measurements['reusableChockWheeledTable'] as Map<String, dynamic>?,
        hardwareId,
        (row) => {
          AppStrings.equipmentOptionCombatWeightRangeLabel: '${row['combatWeightRangeT']} t',
          AppStrings.equipmentOptionSetDimensionsLabel: '${row['setDimensionsMm']} mm',
          AppStrings.equipmentOptionSetWeightLabel: '${row['setWeightKg4Posts']} kg',
        },
      );
    case 'att-wood-chock':
      return _woodChockOptions(
        measurements[chockTableKeyFor(category)] as Map<String, dynamic>?,
        category,
      );
    case 'att-wood-packing':
      // Method 5 and the tracked plates both call for the half-round insert
      // block, and it had no catalogue at all — its card showed "no options"
      // while the plate dimensions it. plate-02 gives a range for each
      // dimension rather than one size, so the range is what is offered.
      return _fromRowTable(
        measurements['insertBlockTable'] as Map<String, dynamic>?,
        hardwareId,
        (row) => {
          AppStrings.equipmentOptionChockHeightLabel: '${row['heightMm']} mm',
          AppStrings.equipmentOptionInsertLengthLabel: '${row['lengthMm']} mm',
        },
      );
    case 'att-wire-lashing':
      return _wireLashingOptions(measurements['wireCoilTable'] as Map<String, dynamic>?, attachments);
    default:
      return const [];
  }
}

/// Wood-chock "size" options are the brackets of whichever table applies —
/// Table 3's combat-weight brackets for a tracked vehicle, Table 2's
/// wheel-diameter brackets for a wheeled one. The handbook fixes exactly one
/// per vehicle (see `wood_chock_sizing.dart`), but every bracket is shown so
/// the user can see and compare the real alternatives, same as iron
/// spurs/KGUUB.
List<EquipmentOption> _woodChockOptions(
  Map<String, dynamic>? table,
  VehicleCategory category,
) {
  if (table == null) return const [];
  final referenceId = table['referenceId'] as String? ?? '';
  final rows = (table['rows'] as List?) ?? const [];
  final wheeled = category == VehicleCategory.wheeled;
  return rows.map((r) {
    final row = r as Map<String, dynamic>;
    return EquipmentOption(
      hardwareId: 'att-wood-chock',
      typeCode: wheeled
          ? '${row['wheelDiameterRangeMm']} mm'
          : '${row['combatWeightRangeT']} t',
      specs: {
        AppStrings.equipmentOptionChockHeightLabel: '${row['chockHeightMm']} mm',
        AppStrings.equipmentOptionChockWidthLabel: '${row['chockWidthMm']} mm',
      },
      referenceId: referenceId,
    );
  }).toList();
}

List<EquipmentOption> _fromRowTable(
  Map<String, dynamic>? table,
  String hardwareId,
  Map<String, String> Function(Map<String, dynamic> row) specsOf,
) {
  if (table == null) return const [];
  final referenceId = table['referenceId'] as String? ?? '';
  final rows = (table['rows'] as List?) ?? const [];
  return rows.map((r) {
    final row = r as Map<String, dynamic>;
    return EquipmentOption(
      hardwareId: hardwareId,
      typeCode: row['type'] as String,
      specs: specsOf(row),
      referenceId: referenceId,
    );
  }).toList();
}

/// Wire-lashing "size" options are the diameters `attachments.json` lists as
/// available, enriched (when a matching row exists) with Table 1's real
/// coil length/weight — never a mandatory type, since the handbook leaves
/// the diameter choice to Table 7's angle-based strand count, not a fixed
/// per-vehicle rule.
List<EquipmentOption> _wireLashingOptions(
  Map<String, dynamic>? wireCoilTable,
  List<AttachmentType> attachments,
) {
  final match = attachments.where((a) => a.id == 'att-wire-lashing');
  final diameters = match.isEmpty ? const <int>[] : (match.first.diametersAvailableMm ?? const []);
  if (diameters.isEmpty || wireCoilTable == null) return const [];
  final referenceId = wireCoilTable['referenceId'] as String? ?? '';
  final rows = (wireCoilTable['rows'] as List?) ?? const [];
  final options = <EquipmentOption>[];
  for (final d in diameters) {
    final rowMatch = rows.where((r) => (r as Map<String, dynamic>)['wireDiameterMm'] == d);
    final row = rowMatch.isEmpty ? null : rowMatch.first as Map<String, dynamic>;
    options.add(EquipmentOption(
      hardwareId: 'att-wire-lashing',
      typeCode: '$d mm',
      specs: row == null
          ? const {}
          : {
              AppStrings.equipmentOptionCoilLengthLabel: '${row['standardCoilLengthM']} m',
              AppStrings.equipmentOptionCoilWeightLabel: '${row['standardCoilWeightKg']} kg',
            },
      referenceId: referenceId,
    ));
  }
  return options;
}
