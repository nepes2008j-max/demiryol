import 'weight_bracket.dart';

/// How many wire strands a lashing needs, from Table 7.
///
/// The table is a grid: the row is the angle between the lashing and the
/// flatcar's **longitudinal axis**, the column is its angle to the **floor**,
/// and the cell is the strand count. Some interior cells are null, and the
/// data's own note says why: they **were not legible when the plate was
/// extracted**, and are not to be used for a real calculation without going
/// back to the source page. So a null cell is an unknown, never a verdict —
/// reporting it as a forbidden combination would be this project inventing a
/// handbook prohibition out of a bad scan.
///
/// Both angles are properties of the lashing as installed, not of the vehicle,
/// which is why the app could never resolve this on its own and reported the
/// strand count as unknown for every configuration. Measured on the wagon and
/// typed in, the table answers it.
class LashingStrandLookup {
  final int? strands;

  /// True when the row and column both exist but the cell was not legible in
  /// the extract. The pair is inside the table; what the table says about it
  /// is simply not known here.
  final bool cellNotLegible;

  /// True when an angle falls outside every band the table covers.
  final bool outsideTable;

  const LashingStrandLookup({
    this.strands,
    this.cellNotLegible = false,
    this.outsideTable = false,
  });
}

Map<String, dynamic>? _table(Map<String, dynamic> measurements) =>
    measurements['wireLashingAngleTable'] as Map<String, dynamic>?;

/// Looks the pair of angles up in Table 7.
LashingStrandLookup lashingStrandCount({
  required double axisAngleDeg,
  required double floorAngleDeg,
  required Map<String, dynamic> measurements,
}) {
  final table = _table(measurements);
  if (table == null) return const LashingStrandLookup(outsideTable: true);

  final columns = ((table['floorAngleBandsDeg'] as List?) ?? const []).cast<String>();
  final columnIndex = columns.indexWhere((band) => valueMatchesRange(floorAngleDeg, band));
  if (columnIndex < 0) return const LashingStrandLookup(outsideTable: true);

  for (final entry in (table['rows'] as List?) ?? const []) {
    final row = entry as Map<String, dynamic>;
    final band = row['axisAngleBandDeg'] as String?;
    if (band == null || !valueMatchesRange(axisAngleDeg, band)) continue;
    final cells = (row['strandsRequired'] as List?) ?? const [];
    if (columnIndex >= cells.length) return const LashingStrandLookup(outsideTable: true);
    final cell = cells[columnIndex];
    if (cell == null) return const LashingStrandLookup(cellNotLegible: true);
    return LashingStrandLookup(strands: (cell as num).toInt());
  }
  return const LashingStrandLookup(outsideTable: true);
}

/// The cap the plate puts on a lashing's angle to the wagon floor.
int? maxFloorAngleDeg(Map<String, dynamic> measurements) =>
    (_table(measurements)?['maxAngleDeg'] as num?)?.toInt();
