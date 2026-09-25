import '../../core/localization/app_strings.dart';
import '../../data/models/vehicle.dart';
import '../models/chock_arrangement.dart';
import 'weight_bracket.dart';
import 'wood_chock_sizing.dart';

/// One line of the materials a securing job needs, with the table it came
/// from.
class ConsumableLine {
  final String name;

  /// How many, when it could be worked out. Null means the handbook fixes the
  /// item but the quantity depends on a figure the data does not have — the
  /// line is still listed, with [note] saying what is missing, because
  /// dropping it would understate what the job needs.
  final num? quantity;
  final String unit;

  /// Size, type or condition — "150x180 mm", "6 mm x 200 mm".
  final String? specification;
  final String? note;
  final String referenceId;

  const ConsumableLine({
    required this.name,
    required this.quantity,
    required this.unit,
    this.specification,
    this.note,
    required this.referenceId,
  });

  bool get isResolved => quantity != null;
}

Map<String, dynamic>? _rule(Map<String, dynamic> rules, String id) {
  for (final entry in (rules['rules'] as List?) ?? const []) {
    final map = entry as Map<String, dynamic>;
    if (map['id'] == id) return map;
  }
  return null;
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> measurements, String table) =>
    (((measurements[table] as Map<String, dynamic>?)?['rows'] as List?) ?? const [])
        .cast<Map<String, dynamic>>();

Map<String, dynamic>? _consumablesRow(double weightT, Map<String, dynamic> measurements) {
  for (final row in _rows(measurements, 'trackedConsumablesByWeightTable')) {
    final range = row['combatWeightRangeT'] as String?;
    if (range != null && weightMatchesRange(weightT, range)) return row;
  }
  return null;
}

/// Strands laid up in one wire lashing for a tracked vehicle of this weight,
/// from plate-03's TABLISSA No.1, or null when no bracket covers the weight.
///
/// The handbook gives this figure twice — by weight here, and by installed
/// angle in Table 7 — and `consumablesFor` already reconciles the two on the
/// stores list. It is exposed on its own so a drawing can lay up the right
/// number of threads: a four-thread lashing and an eight-thread one are
/// visibly different things, and until this was readable the scene drew a
/// placeholder two.
int? trackedWireStrandsPerLashing(double weightT, Map<String, dynamic> measurements) {
  final row = _consumablesRow(weightT, measurements);
  return (row?['wireStrandsPerLashing'] as num?)?.toInt();
}

/// Everything a trainee has to draw from stores to secure one vehicle the way
/// they have configured it.
///
/// This is the arithmetic the handbook's tables are for and the app was never
/// doing: it knew the chock count from the layout case, the nails per chock
/// from plate-06, and the wire, staples and strand count per weight bracket
/// from TABLISSA No.1 — but it never multiplied any of it out, so a trainee
/// could finish a configuration without ever being told they need, say, 16
/// nails and 8 staples.
///
/// Nothing here is invented. Where a quantity depends on the combat weight and
/// none is recorded, the line still appears with its note, so the list never
/// silently understates the job.
///
/// [strandsFromMeasuredAngles] is Table 7's answer for the lashing angles as
/// measured, when they have been. The handbook gives the strand count twice —
/// by weight on plate-03's TABLISSA No.1 and by angle in Table 7 — and the two
/// need not agree. Where they disagree the line says so and names both,
/// because silently printing one of them would hide a question the person
/// doing the job has to settle against the source page.
List<ConsumableLine> consumablesFor({
  required Vehicle vehicle,
  required ChockArrangement? arrangement,
  required List<String> requiredHardwareIds,
  required Map<String, dynamic> measurements,
  required Map<String, dynamic> rules,
  int? strandsFromMeasuredAngles,
}) {
  final lines = <ConsumableLine>[];
  final weight = vehicle.bracketWeightT.asDouble;
  final wheeled = vehicle.category == VehicleCategory.wheeled;

  // --- Wood chocks, and the nails that hold each one down -------------------
  if (requiredHardwareIds.contains('att-wood-chock')) {
    final chockCount = arrangement?.chockCount;
    String? size;
    if (!wheeled && weight != null) {
      final dims = resolveWoodChockDimensions(weight, measurements);
      if (dims != null) size = '${dims.heightMm}x${dims.widthMm} mm';
    }
    lines.add(ConsumableLine(
      name: AppStrings.consumableWoodChock,
      quantity: chockCount,
      unit: AppStrings.consumableUnitPiece,
      specification: size,
      note: chockCount == null
          ? AppStrings.consumableNeedsArrangement
          : (size == null && !wheeled ? AppStrings.consumableNeedsWeight : null),
      referenceId: arrangement?.referenceId ?? 'para-21',
    ));

    final nailRule = _rule(rules, 'rule-chock-nail-count');
    final perChock = (nailRule?['nailsPerLongitudinalChock'] as num?)?.toInt();
    final diameter = (nailRule?['nailDiameterMm'] as num?)?.toInt();
    final length = (nailRule?['nailLengthMm'] as num?)?.toInt();
    lines.add(ConsumableLine(
      name: AppStrings.consumableNail,
      quantity: (chockCount != null && perChock != null) ? chockCount * perChock : null,
      unit: AppStrings.consumableUnitPiece,
      specification:
          (diameter != null && length != null) ? '$diameter mm x $length mm' : null,
      note: chockCount == null ? AppStrings.consumableNeedsArrangement : null,
      referenceId: (nailRule?['referenceId'] as String?) ?? 'para-25',
    ));
  }

  // --- Half-round insert blocks --------------------------------------------
  final insertCount = arrangement?.insertCount ?? 0;
  if (insertCount > 0) {
    lines.add(ConsumableLine(
      name: AppStrings.consumableInsertBlock,
      quantity: insertCount,
      unit: AppStrings.consumableUnitPiece,
      specification: _insertSize(measurements),
      referenceId: 'para-24',
    ));
  }

  // --- Wire lashings, staples: TABLISSA No.1, by combat weight --------------
  final row = weight == null ? null : _consumablesRow(weight, measurements);
  if (requiredHardwareIds.contains('att-wire-lashing')) {
    final strandsByWeight = (row?['wireStrandsPerLashing'] as num?)?.toInt();
    final disagrees = strandsByWeight != null &&
        strandsFromMeasuredAngles != null &&
        strandsFromMeasuredAngles != strandsByWeight;
    lines.add(ConsumableLine(
      name: AppStrings.consumableWire,
      quantity: (row?['wireLengthM'] as num?),
      unit: AppStrings.consumableUnitMetre,
      specification: row == null
          ? null
          : AppStrings.consumableWireSpec(
              strandsByWeight!, (row['wireKg'] as num).toDouble()),
      note: row == null
          ? AppStrings.consumableNeedsWeight
          : (disagrees
              ? AppStrings.consumableStrandSourcesDiffer(
                  strandsFromMeasuredAngles, strandsByWeight)
              : null),
      referenceId: 'plate-03',
    ));
  }

  if (!wheeled) {
    final perVehicle = (row?['staplesPerVehicle'] as num?)?.toInt();
    lines.add(ConsumableLine(
      name: AppStrings.consumableStaple,
      quantity: perVehicle,
      unit: AppStrings.consumableUnitPiece,
      specification: AppStrings.consumableStapleSpec,
      note: perVehicle == null ? AppStrings.consumableNeedsWeight : null,
      referenceId: 'plate-03',
    ));
  }

  // --- Reusable hardware is a set, not a consumable -------------------------
  for (final id in requiredHardwareIds) {
    final reusable = _reusableSet(id);
    if (reusable != null) {
      lines.add(ConsumableLine(
        name: reusable.name,
        quantity: reusable.count,
        unit: AppStrings.consumableUnitPiece,
        specification: AppStrings.consumableReusableSet,
        referenceId: reusable.referenceId,
      ));
    }
  }

  return lines;
}

String? _insertSize(Map<String, dynamic> measurements) {
  final rows = _rows(measurements, 'insertBlockTable');
  if (rows.isEmpty) return null;
  final row = rows.first;
  return '${row['heightMm']} mm x ${row['lengthMm']} mm';
}

/// The reusable fittings that come as a four-piece set per vehicle, rather
/// than being consumed: the plates state "toplum dört sany diregden ybarat".
({String name, int count, String referenceId})? _reusableSet(String hardwareId) =>
    switch (hardwareId) {
      'att-kguub-1g' || 'att-kguub-2g' => (
          name: AppStrings.consumableKguub,
          count: 4,
          referenceId: 'para-29'
        ),
      'att-kguub-1k' || 'att-kguub-2k' => (
          name: AppStrings.consumableKguub,
          count: 4,
          referenceId: 'para-30'
        ),
      'att-iron-spur' => (
          name: AppStrings.consumableIronSpur,
          count: 4,
          referenceId: 'para-31'
        ),
      'att-iron-chock-boot' => (
          name: AppStrings.consumableIronChockBoot,
          count: 4,
          referenceId: 'para-32'
        ),
      _ => null,
    };
