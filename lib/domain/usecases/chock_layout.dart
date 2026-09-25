import '../models/chock_arrangement.dart';

/// Where the chosen arrangement's chocks sit along the vehicle, as normalized
/// x fractions of the schematic's layout space.
///
/// This exists because the count was previously not a quantity at all: the
/// schematic drew wood chocks at a hard-coded `[0.30, 0.70]` whatever the
/// handbook said, so a case calling for eight chocks and a case calling for
/// four looked identical. The count now comes from the chosen
/// [ChockArrangement], which read it from the plate.
///
/// One returned x is one *pair* — the schematic's hardware elements carry a
/// point per side of the vehicle, and a chock on the near track always has
/// its twin on the far one. The spacing between the pairs is a drawing
/// convention, not a measured distance: the plates dimension a chock's
/// distance from the running gear (10-15 cm) and from the tyre's outer face
/// (20-30 mm), never its position along the wagon, so these elements stay
/// marked `isGeometrySchematic`.
class ChockLayout {
  const ChockLayout._();

  /// Fraction of the vehicle's own length kept clear at each end, so the
  /// outermost chock reads as seated against the running gear rather than
  /// floating off it.
  static const _endInset = 0.06;

  /// The x fractions for one arrangement's longitudinal chocks.
  ///
  /// When [runPositions] is given — the x of each tyre, or of each end of a
  /// track — the chocks are seated **against those**, ahead of and behind each
  /// one in turn, because that is where the plate puts them: "the chock's long
  /// side is laid across the wagon, under the tyre". Spreading eight chocks
  /// evenly along the vehicle instead drew a row of blocks under the middle of
  /// the load, which is not an arrangement the handbook contains.
  ///
  /// Without run positions it falls back to an even spread, so a diagram that
  /// has no run indicator still draws the right number.
  static List<double> chockPairPositions(
    ChockArrangement arrangement, {
    required double vehicleLeft,
    required double vehicleRight,
    List<double> runPositions = const [],
  }) {
    final pairs = _pairCount(arrangement.chockCount);
    if (pairs == 0) return const [];
    if (runPositions.isEmpty) {
      return _spread(pairs, vehicleLeft, vehicleRight, _endInset);
    }

    // Ahead of and behind each run position in turn, nearest the ends first,
    // until the arrangement's count is used up.
    final span = (vehicleRight - vehicleLeft).abs();
    final reach = span * _againstRunOffset;
    final sorted = [...runPositions]..sort();
    final positions = <double>[];
    for (var round = 0; positions.length < pairs; round++) {
      for (final run in sorted) {
        if (positions.length >= pairs) break;
        // Round 0 seats a chock ahead of the wheel, round 1 behind it, and a
        // third round (only reached by the doubled cases) doubles up outside.
        final offset = reach * (1 + round ~/ 2) * (round.isEven ? -1 : 1);
        positions.add(run + offset);
      }
      if (round > 6) break; // never loop forever on an absurd count
    }
    positions.sort();
    return positions;
  }

  /// How far from a tyre or track end a chock is seated, as a fraction of the
  /// vehicle's length. A drawing convention: the plates dimension this gap in
  /// millimetres (20-30 mm from the tyre's outer face) but never as a
  /// proportion of the vehicle, and no vehicle here has a measured length.
  static const _againstRunOffset = 0.06;

  /// The x fractions for the transverse half-round insert blocks, which the
  /// plate seats between the road wheels rather than at the vehicle's ends.
  /// Empty when the arrangement calls for none (every wheeled case).
  static List<double> insertPairPositions(
    ChockArrangement arrangement, {
    required double vehicleLeft,
    required double vehicleRight,
  }) {
    final pairs = _pairCount(arrangement.insertCount);
    if (pairs == 0) return const [];
    // Inset further than the chocks: the inserts go between the road wheels,
    // inboard of the blocks seated at the ends.
    return _spread(pairs, vehicleLeft, vehicleRight, 0.28);
  }

  /// Chocks come in pairs, one per side; an odd count still needs the extra
  /// one drawn, so the pair count rounds up rather than losing it.
  static int _pairCount(int chockCount) => chockCount <= 0 ? 0 : (chockCount + 1) ~/ 2;

  static List<double> _spread(int count, double left, double right, double insetFraction) {
    if (count <= 0) return const [];
    final span = right - left;
    if (span <= 0) return List.filled(count, left);
    final inset = span * insetFraction;
    final first = left + inset;
    final last = right - inset;
    if (count == 1) return [(first + last) / 2];
    final step = (last - first) / (count - 1);
    return [for (var i = 0; i < count; i++) first + step * i];
  }
}
