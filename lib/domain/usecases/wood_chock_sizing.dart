import '../../data/models/vehicle.dart';
import 'weight_bracket.dart';

/// The Table 3 (para. 21) weight-bracket string (e.g. `"up to 12.0"`) that
/// actually matches this combat weight — the handbook-mandated wood-chock
/// size for this vehicle. Returns null when no bracket matches (never a
/// guessed bracket).
String? matchingWoodChockWeightRange(double weightT, Map<String, dynamic> measurements) {
  final rows = _rows(measurements);
  for (final row in rows) {
    final range = row['combatWeightRangeT'] as String;
    if (weightMatchesRange(weightT, range)) return range;
  }
  return null;
}

/// The real height/width Table 3 gives for one specific weight-bracket
/// string, straight from the row — used both for the vehicle's
/// auto-resolved bracket and for whichever bracket the user selects in the
/// Required Equipment panel.
({int heightMm, int widthMm})? woodChockDimensionsForRange(
  String range,
  Map<String, dynamic> measurements,
) {
  for (final row in _rows(measurements)) {
    if (row['combatWeightRangeT'] == range) {
      return (heightMm: row['chockHeightMm'] as int, widthMm: row['chockWidthMm'] as int);
    }
  }
  return null;
}

/// Table 3 dimensions for a tracked vehicle's own combat weight — the same
/// lookup `EngineeringValidator`'s wood-chock-sizing check performs,
/// exposed separately so the schematic can show the resolved height/width
/// without putting engineering-verdict logic in the painter. Returns null
/// when no bracket matches (never a guessed size).
({int heightMm, int widthMm})? resolveWoodChockDimensions(
  double weightT,
  Map<String, dynamic> measurements,
) {
  final range = matchingWoodChockWeightRange(weightT, measurements);
  return range == null ? null : woodChockDimensionsForRange(range, measurements);
}

/// The half-round transverse insert block's size, from plate-02's insert
/// block table.
///
/// The table states each dimension as a **range** (90–100 mm high,
/// 300–400 mm long) rather than a single figure, because the plate does. A
/// drawn solid needs one number, so the midpoint is used — and
/// [rangeLabel] carries the range itself, which is what every screen shows
/// beside the piece. Reporting "95 mm" as though the handbook said 95 mm
/// would be exactly the false precision this project refuses; reporting
/// "90-100 mm" and drawing something inside it is not.
({double heightMm, double lengthMm, String rangeLabel})? insertBlockDimensions(
  Map<String, dynamic> measurements,
) {
  final rows = ((measurements['insertBlockTable'] as Map<String, dynamic>?)?['rows']
          as List?)
      ?.cast<Map<String, dynamic>>();
  if (rows == null || rows.isEmpty) return null;
  final row = rows.first;
  final height = _midpointMm(row['heightMm']);
  final length = _midpointMm(row['lengthMm']);
  if (height == null || length == null) return null;
  return (
    heightMm: height,
    lengthMm: length,
    rangeLabel: '${row['heightMm']} x ${row['lengthMm']} mm',
  );
}

/// The middle of a `"90-100"` range, or the number itself when the cell holds
/// one. Null for anything else, so an unreadable cell produces no block
/// rather than a block of some default size.
double? _midpointMm(Object? raw) {
  if (raw is num) return raw.toDouble();
  if (raw is! String) return null;
  final parts = raw.split('-');
  if (parts.length == 2) {
    final lo = double.tryParse(parts[0].trim());
    final hi = double.tryParse(parts[1].trim());
    if (lo != null && hi != null) return (lo + hi) / 2;
  }
  return double.tryParse(raw.trim());
}

List<Map<String, dynamic>> _rows(Map<String, dynamic> measurements) {
  final table = measurements['trackChockByWeightTable'] as Map<String, dynamic>?;
  return ((table?['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();
}


// ---------------------------------------------------------------------------
// Wheeled vehicles size their chocks from Table 2 — by WHEEL DIAMETER, not by
// weight. Everything above reads `trackChockByWeightTable`, which is the
// tracked table; feeding a lorry through it would hand back a size the
// handbook never prescribed for it.
// ---------------------------------------------------------------------------

/// The Table 2 wheel-diameter bracket (e.g. `"800-1099"`) matching this wheel
/// diameter, or null when none does.
String? matchingWheelChockDiameterRange(
  double wheelDiameterMm,
  Map<String, dynamic> measurements,
) {
  for (final row in _wheelRows(measurements)) {
    final range = row['wheelDiameterRangeMm'] as String?;
    if (range != null && valueMatchesRange(wheelDiameterMm, range)) return range;
  }
  return null;
}

/// The height/width Table 2 gives for one wheel-diameter bracket.
({int heightMm, int widthMm})? wheelChockDimensionsForRange(
  String range,
  Map<String, dynamic> measurements,
) {
  for (final row in _wheelRows(measurements)) {
    if (row['wheelDiameterRangeMm'] == range) {
      return (heightMm: row['chockHeightMm'] as int, widthMm: row['chockWidthMm'] as int);
    }
  }
  return null;
}

/// Which of the two chock tables applies to a vehicle: Table 3 (by combat
/// weight) for a tracked one, Table 2 (by wheel diameter) for a wheeled one.
///
/// Exposed so the equipment catalogue and the required-type lookup agree on
/// the answer instead of each deciding for itself.
String chockTableKeyFor(VehicleCategory category) =>
    category == VehicleCategory.wheeled
        ? 'wheelChockByWheelDiameterTable'
        : 'trackChockByWeightTable';

List<Map<String, dynamic>> _wheelRows(Map<String, dynamic> measurements) {
  final table = measurements['wheelChockByWheelDiameterTable'] as Map<String, dynamic>?;
  return ((table?['rows'] as List?) ?? const []).cast<Map<String, dynamic>>();
}
