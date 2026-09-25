import 'dart:math' as math;

import '../models/securing_placement.dart';
import 'flatcar_mesh_builder.dart';
import 'securing_measurements.dart';
import 'vehicle_mesh_builder.dart';

/// Where a piece being dragged wants to settle.
class SnapResult {
  final double x;
  final double z;
  final ChockFacing facing;

  /// True when the position was pulled onto the running gear rather than left
  /// exactly where the pointer was.
  final bool snapped;

  const SnapResult({
    required this.x,
    required this.z,
    required this.facing,
    required this.snapped,
  });
}

/// Assists a block onto the running gear without ever insisting on it.
///
/// Placing a block by eye through a perspective view is genuinely hard: a
/// centimetre on the deck is a pixel or two on the screen, and being under the
/// track is the difference between a stop block and a piece of timber lying on
/// the floor. So a block dragged near a track is pulled onto its centre line
/// and seated at the handbook distance from the end of the bearing length.
///
/// It is an assist, not a rule. Snapping is a toggle the trainee can switch
/// off, and even with it on, a block dragged clear of the running gear stays
/// exactly where it was put — including somewhere wrong, which they have to be
/// able to do or the measurement below the scene would never say anything they
/// did not already know.
class SecuringSnap {
  SecuringSnap._();

  /// How near a track's centre line a block must be dragged before it is
  /// pulled onto it. Roughly half a track's width.
  static const double lateralReachM = 0.32;

  /// How near an end of the bearing length a block must be before it is
  /// seated against it.
  static const double longitudinalReachM = 0.50;

  static SnapResult forBlock({
    required SecuringPiece piece,
    required double x,
    required double z,
    required VehicleModel3 vehicle,
    required FlatcarMeshSpec flatcarSpec,
    required double vehicleOffsetX,
    required double seatingDistanceM,
    bool enabled = true,
  }) {
    // Keep the piece on the wagon whatever else happens: a block dragged over
    // the side would be reported as securing a load it is not touching.
    //
    // It is the block's *centre* that is held on the deck, not its whole
    // footprint. A machine wider than the wagon has its running gear standing
    // over the edge — the T-90S's tracks overhang this deck by a quarter of a
    // metre each side — so a block seated under such a track must be allowed
    // to overhang with it. Holding the footprint inside the deck put the one
    // place a block belongs out of reach.
    final halfLength = flatcarSpec.deckLengthM / 2;
    // Far enough out to reach the running gear even when the running gear is
    // outboard of the deck edge, which is the whole case this has to serve: a
    // machine wider than its wagon still needs a block under its track, and
    // clamping to the deck alone put that one position out of reach whenever
    // the assist was switched off.
    final reachZ = math.max(
      flatcarSpec.deckWidthM / 2,
      vehicle.trackCenterZ + vehicle.spec.runningGearWidthM / 2,
    );
    var outX = x.clamp(-halfLength, halfLength).toDouble();
    var outZ = z.clamp(-reachZ, reachZ).toDouble();
    var facing = piece.facing;
    var snapped = false;

    if (!enabled) {
      return SnapResult(x: outX, z: outZ, facing: facing, snapped: false);
    }

    // Across the wagon: onto the nearer track's centre line.
    for (final side in const [1, -1]) {
      final trackZ = side * vehicle.trackCenterZ;
      if ((outZ - trackZ).abs() <= lateralReachM) {
        outZ = trackZ;
        snapped = true;
        break;
      }
    }

    // Along the wagon: seated the handbook distance off the nearest point the
    // running gear bears on, with the working face turned towards it.
    //
    // "The nearest point" and not "the nearer end": a lorry bears on every
    // tyre, and plate-06 puts a chock under each one. Snapping only to the
    // ends left the middle axle of a six-wheeler — two of its six wheels —
    // with no assist at all, and seated the outer blocks against the tyre's
    // outer edge while the readout measured from its centre, so asking for
    // 12.5 cm produced a block the panel called 67 cm away.
    final points = bearingPointsFor(vehicle, vehicleOffsetX);
    var bestSeated = outX;
    var bestFacing = facing;
    var bestDistance = double.infinity;
    for (final point in points) {
      for (final side in const [1, -1]) {
        final seated = point + side * seatingDistanceM;
        final d = (outX - seated).abs();
        if (d < bestDistance) {
          bestDistance = d;
          bestSeated = seated;
          bestFacing =
              side > 0 ? ChockFacing.towardsRear : ChockFacing.towardsFront;
        }
      }
    }
    if (bestDistance <= longitudinalReachM) {
      outX = bestSeated;
      facing = bestFacing;
      snapped = true;
    }

    return SnapResult(x: outX, z: outZ, facing: facing, snapped: snapped);
  }

  /// The deck ring a lashing's loose end is nearest — a wire is made fast to a
  /// ring or to nothing, so dragging one chooses among the rings that exist
  /// rather than dropping the end anywhere on the deck.
  ///
  /// Returns `0` for a wagon with no rings, which is not an index into
  /// anything: callers must check for an empty ring list first.
  static int nearestRingIndex(FlatcarModel3 flatcar, double x, double z) {
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < flatcar.tieDownRings.length; i++) {
      final ring = flatcar.tieDownRings[i];
      final d = math.pow(ring.x - x, 2) + math.pow(ring.z - z, 2);
      if (d < bestD) {
        bestD = d.toDouble();
        best = i;
      }
    }
    return best;
  }
}
