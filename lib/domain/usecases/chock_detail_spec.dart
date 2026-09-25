import '../models/chock_arrangement.dart';

/// The numbers the end view and the detail zoom letter onto the drawing.
///
/// They are the plates' own dimensions — the gap from the tyre's outer face,
/// the seating distance from the running gear, the nails per chock, the
/// staple diameter, the overhang limit — collected in one place so the
/// painters carry no numbers of their own. A painter that invented a
/// millimetre would be indistinguishable, on screen, from one quoting the
/// handbook.
class ChockDetailSpec {
  /// Seating distance of the chock from the running gear, in centimetres
  /// (tracked; plate-03).
  final ({int minCm, int maxCm})? seating;

  /// Gap between a lateral chock and the tyre's outer face, in millimetres
  /// (wheeled; plate-06, tightened over a coupling).
  final ({int minMm, int maxMm})? lateralGap;

  final int? nailsPerLongitudinalChock;
  final int? nailsPerLateralChock;
  final int? nailDiameterMm;
  final int? nailLengthMm;
  final int? stapleMinDiameterMm;

  /// Overhang past the end of the open wagon before a guard wagon is required
  /// (plate-05).
  final int? maxOverhangMm;

  /// The citation to show under the drawing. Empty when nothing was resolved.
  final String referenceId;

  const ChockDetailSpec({
    this.seating,
    this.lateralGap,
    this.nailsPerLongitudinalChock,
    this.nailsPerLateralChock,
    this.nailDiameterMm,
    this.nailLengthMm,
    this.stapleMinDiameterMm,
    this.maxOverhangMm,
    this.referenceId = '',
  });

  bool get isEmpty =>
      seating == null &&
      lateralGap == null &&
      nailsPerLongitudinalChock == null &&
      maxOverhangMm == null;
}

Map<String, dynamic>? _rule(Map<String, dynamic> rules, String id) {
  for (final entry in (rules['rules'] as List?) ?? const []) {
    final map = entry as Map<String, dynamic>;
    if (map['id'] == id) return map;
  }
  return null;
}

int? _int(Object? raw) => raw is num ? raw.toInt() : null;

/// Collects the dimensions for one placement's detail drawings from
/// `rules.json` and the chosen [arrangement].
///
/// Anything the data does not carry stays null and is simply not lettered
/// onto the drawing — the same rule the rest of the app follows for a missing
/// value.
ChockDetailSpec chockDetailSpec({
  required Map<String, dynamic> rules,
  ChockArrangement? arrangement,
}) {
  final nails = _rule(rules, 'rule-chock-nail-count');
  final tracked = _rule(rules, 'rule-tracked-chock-arrangement');
  final overhang = _rule(rules, 'rule-overhang-guard-wagon');

  return ChockDetailSpec(
    seating: arrangement?.seatingDistance,
    lateralGap: arrangement?.lateralGap,
    nailsPerLongitudinalChock: _int(nails?['nailsPerLongitudinalChock']),
    nailsPerLateralChock: _int(nails?['nailsPerLateralChock']),
    nailDiameterMm: _int(nails?['nailDiameterMm']),
    nailLengthMm: _int(nails?['nailLengthMm']),
    stapleMinDiameterMm: _int(tracked?['stapleMinDiameterMm']),
    maxOverhangMm: _int(overhang?['maxOverhangMm']),
    referenceId: (arrangement?.referenceId.isNotEmpty ?? false)
        ? arrangement!.referenceId
        : (nails?['referenceId'] as String?) ?? '',
  );
}
