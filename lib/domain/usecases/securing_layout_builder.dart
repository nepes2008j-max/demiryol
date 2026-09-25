import 'dart:math' as math;

import '../models/securing_placement.dart';
import 'flatcar_mesh_builder.dart';
import 'securing_measurements.dart';
import 'vehicle_mesh_builder.dart';

/// Where the securing gear starts before the trainee touches it, and where a
/// newly added piece lands.
///
/// The starting arrangement is the handbook's own: a stop block seated ahead
/// of and behind each track at the seating distance the plates dimension
/// (10–15 cm for a tracked vehicle), and a wire lashing from each attachment
/// point on the vehicle to the nearest deck ring. From there the trainee moves
/// them. That is deliberately the right way round — they begin with something
/// defensible and have to keep it defensible while they work, rather than
/// beginning with an empty deck and no idea what "correct" looks like.
class SecuringLayoutBuilder {
  SecuringLayoutBuilder._();

  /// Fallback seating distance, in metres, for a case whose arrangement does
  /// not state one. The midpoint of the tracked plates' 10–15 cm.
  static const double defaultSeatingDistanceM = 0.125;

  /// How much of the track's width a block is drawn to span. The plates give
  /// a block's height and width but never its length, so the length follows
  /// the running gear it bears against, which is the one thing about it that
  /// is not arbitrary — and `rule-tracked-chock-arrangement` states the floor
  /// directly: "the chock's length must not be less than the width of the
  /// vehicle's track". [blockLengthFor] enforces that floor whatever this
  /// factor is set to.
  static const double _blockLengthFactor = 1.35;

  /// The length of a stop block across the wagon, for a vehicle with this
  /// track. Never shorter than the track is wide, per plate-02's own rule.
  static double blockLengthFor(VehicleMeshSpec spec) => math.max(
        spec.runningGearWidthM,
        spec.runningGearWidthM * _blockLengthFactor,
      );

  /// The handbook arrangement for a tracked vehicle on a flatcar.
  ///
  /// [chockHeightM] and [chockWidthM] come from Table 3 and may be null, in
  /// which case **no blocks are produced at all**: a block of invented size
  /// seated at an exact distance would be false precision twice over.
  /// Lashings are still laid out, since a wire run needs no size to exist.
  static SecuringLayout handbookArrangement({
    required VehicleModel3 vehicle,
    required FlatcarModel3 flatcar,
    required double vehicleOffsetX,
    double? chockHeightM,
    double? chockWidthM,
    String? chockSizeTypeCode,
    double seatingDistanceM = defaultSeatingDistanceM,
    int blocksPerTrackEnd = 1,
    int lashingRuns = 4,
    int threadsPerLashing = 4,
    double? insertHeightM,
    double? insertLengthM,
    String? insertSizeTypeCode,
    int insertsPerSide = 2,
  }) {
    final pieces = <SecuringPiece>[];

    if (chockHeightM != null && chockWidthM != null && chockHeightM > 0 && chockWidthM > 0) {
      final blockLength = blockLengthFor(vehicle.spec);
      // One block ahead of the foremost point the running gear bears on and
      // one behind the rearmost — the ends of a track, or the outer tyres of
      // a lorry. Not one on each side of every point: behind the front end of
      // a track is *under* the track, which is not a place a stop block goes.
      final points = bearingPointsFor(vehicle, vehicleOffsetX);
      final foremost = points.reduce(math.max);
      final rearmost = points.reduce(math.min);
      var n = 0;
      for (final side in const [1, -1]) {
        final z = side * vehicle.trackCenterZ;
        {
          for (final end in const [1, -1]) {
            final contact = end > 0 ? foremost : rearmost;
            for (var i = 0; i < math.max(1, blocksPerTrackEnd); i++) {
              n++;
              pieces.add(SecuringPiece(
                id: 'woodChock-$n',
                kind: SecuringPieceKind.woodChock,
                // The working face stands off the running gear by the seating
                // distance; a doubled block sits directly outboard of the
                // first.
                x: contact + end * seatingDistanceM,
                z: z + (i == 0 ? 0.0 : (side * blockLength * i)),
                widthM: chockWidthM,
                heightM: chockHeightM,
                lengthM: blockLength,
                facing:
                    end > 0 ? ChockFacing.towardsRear : ChockFacing.towardsFront,
                sizeTypeCode: chockSizeTypeCode,
              ));
            }
          }
        }
      }
    }

    // The transverse half-round insert blocks. `rule-tracked-chock-arrangement`
    // calls for four per vehicle, two a side, seated between the road wheels:
    // the first pair stops the vehicle running forward along the track, the
    // second stops it running back. Like the stop blocks they are drawn only
    // at a size that came from the handbook — plate-02's insert block table —
    // and not at all without one.
    if (insertHeightM != null && insertLengthM != null && insertsPerSide > 0) {
      final contactHalf =
          (vehicle.trackContactX.front - vehicle.trackContactX.rear).abs() / 2;
      final centre =
          (vehicle.trackContactX.front + vehicle.trackContactX.rear) / 2 + vehicleOffsetX;
      var n = 0;
      for (final side in const [1, -1]) {
        for (var i = 0; i < insertsPerSide; i++) {
          // Spread symmetrically about the middle of the bearing length, well
          // inside the ends where the stop blocks are.
          final fraction = insertsPerSide == 1
              ? 0.0
              : -0.45 + (0.90 * i / (insertsPerSide - 1));
          n++;
          pieces.add(SecuringPiece(
            id: 'woodInsert-$n',
            kind: SecuringPieceKind.woodInsert,
            x: centre + contactHalf * fraction,
            z: side * vehicle.trackCenterZ,
            widthM: insertLengthM,
            heightM: insertHeightM,
            lengthM: vehicle.spec.runningGearWidthM,
            facing: fraction <= 0 ? ChockFacing.towardsFront : ChockFacing.towardsRear,
            sizeTypeCode: insertSizeTypeCode,
          ));
        }
      }
    }

    pieces.addAll(defaultLashings(
      vehicle: vehicle,
      flatcar: flatcar,
      vehicleOffsetX: vehicleOffsetX,
      runs: lashingRuns,
      threads: threadsPerLashing,
    ));

    return SecuringLayout(pieces);
  }

  /// One wire from each attachment point on the vehicle, made fast to the
  /// deck ring that lies outboard of it and beyond the end of the machine, so
  /// the run takes the load along the wagon rather than straight down.
  static List<SecuringPiece> defaultLashings({
    required VehicleModel3 vehicle,
    required FlatcarModel3 flatcar,
    required double vehicleOffsetX,
    int runs = 4,
    int threads = 4,
  }) {
    final eyes = vehicle.lashingEyes;
    if (eyes.isEmpty || flatcar.tieDownRings.isEmpty) return const [];
    final wanted = math.max(1, runs);
    final perEye = (wanted / eyes.length).ceil();
    final out = <SecuringPiece>[];
    for (var e = 0; e < eyes.length && out.length < wanted; e++) {
      final eye = eyes[e];
      for (var r = 0; r < perEye && out.length < wanted; r++) {
        final reach = 1.35 + r * 1.05;
        final target = Vector3ish(
          eye.x + vehicleOffsetX + (eye.x >= 0 ? reach : -reach),
          eye.z * 1.8,
        );
        final ringIndex = nearestRingIndex(flatcar, target.x, target.z);
        out.add(SecuringPiece(
          id: 'wireLashing-${out.length + 1}',
          kind: SecuringPieceKind.wireLashing,
          x: flatcar.tieDownRings[ringIndex].x,
          z: flatcar.tieDownRings[ringIndex].z,
          eyeIndex: e,
          ringIndex: ringIndex,
          threads: threads,
        ));
      }
    }
    return out;
  }

  /// The deck ring nearest a point, by index — the wire has to be made fast
  /// to a ring that exists, so dragging a lashing chooses among rings rather
  /// than landing anywhere on the deck.
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

  /// A new piece dropped onto the deck, seated against the nearest end of the
  /// nearest track — where a trainee reaching for a block almost always means
  /// to put it, and a starting point they can then drag anywhere.
  static SecuringPiece newPiece({
    required SecuringLayout layout,
    required SecuringPieceKind kind,
    required VehicleModel3 vehicle,
    required double vehicleOffsetX,
    double? heightM,
    double? widthM,
    double? lengthM,
    String? sizeTypeCode,
    double seatingDistanceM = defaultSeatingDistanceM,
  }) {
    final blockLength = blockLengthFor(vehicle.spec);
    // Ahead of the foremost point the running gear bears on — the front of a
    // track, or the front tyre — measured the same way the panel measures it,
    // so a piece lands where the figure beside it says it has.
    final points = bearingPointsFor(vehicle, vehicleOffsetX);
    final front = points.reduce(math.max);
    // Unless something is already there, in which case it lands clear of it
    // rather than inside it.
    final occupied = layout.blocks
        .where((p) => (p.z - vehicle.trackCenterZ).abs() < blockLength)
        .length;
    return SecuringPiece(
      id: layout.nextId(kind),
      kind: kind,
      x: front + seatingDistanceM + occupied * 0.45,
      z: vehicle.trackCenterZ,
      widthM: widthM ?? 0.20,
      heightM: heightM ?? 0.16,
      // The catalogue states the extent across the wagon for most pieces —
      // an iron spur's base plate is as wide as the track it seats under.
      // Where it does not, the length follows the running gear.
      lengthM: lengthM ??
          (kind == SecuringPieceKind.woodInsert
              ? vehicle.spec.runningGearWidthM
              : blockLength),
      facing: ChockFacing.towardsRear,
      sizeTypeCode: sizeTypeCode,
    );
  }
}

/// A two-coordinate point on the deck. A local shorthand so this file does not
/// pull in the 3D vector type for what is a plan position.
class Vector3ish {
  final double x;
  final double z;
  const Vector3ish(this.x, this.z);
}
