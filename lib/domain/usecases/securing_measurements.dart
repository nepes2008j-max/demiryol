import 'dart:math' as math;

import '../../core/localization/app_strings.dart';
import '../../data/models/simulation_result.dart';
import '../models/chock_arrangement.dart';
import '../models/securing_placement.dart';
import 'vehicle_mesh_builder.dart';

/// How one placed block actually sits against the running gear.
///
/// This is the payoff of letting the trainee move the gear by hand. The
/// handbook's plates dimension exactly one thing about a stop block — how far
/// its working face stands off the running gear — and until the scene was
/// built from real metres there was nothing in this application that distance
/// could be measured on. Now there is: the trainee puts the block somewhere,
/// and the model says how far off the track it ended up.
class BlockSeating {
  final String pieceId;

  /// Distance from the block's working face to the end of the track's bearing
  /// length it is seated against, in metres. Negative when the block overlaps
  /// the running gear rather than standing off it.
  final double seatingDistanceM;

  /// True when the block is seated ahead of the running gear it is against —
  /// the forward end of a track, or the forward side of a tyre.
  final bool againstFrontOfRun;

  /// Which wheel the block is seated against, counted from the front axle,
  /// or null for a tracked vehicle.
  ///
  /// A track bears continuously and a block goes against one of its two ends.
  /// A lorry bears at points and plate-06 puts a chock under **each tyre**, so
  /// a block between the middle and rear axles of a six-wheeler is against a
  /// particular wheel, and saying which is the difference between a useful
  /// figure and a distance to something the trainee was not aiming at.
  final int? wheelIndex;

  /// `+1` for the right-hand track, `-1` for the left.
  final int trackSide;

  /// How far the block's centre is from that track's centre line, across the
  /// wagon.
  final double lateralOffsetM;

  /// True when the block's own width across the wagon overlaps the track's —
  /// that is, it really is under the running gear rather than beside it.
  final bool underRunningGear;

  /// True when the wedge's working face is turned towards the vehicle, so the
  /// block can actually stop it. A block laid the wrong way round presents
  /// its slope to the track and would simply be ridden over.
  final bool facesTheRun;

  const BlockSeating({
    required this.pieceId,
    required this.seatingDistanceM,
    required this.againstFrontOfRun,
    required this.trackSide,
    required this.lateralOffsetM,
    required this.underRunningGear,
    required this.facesTheRun,
    this.wheelIndex,
  });

  double get seatingDistanceCm => seatingDistanceM * 100;

  /// The block is standing off the running gear rather than under or over it.
  bool get isClearOfRun => seatingDistanceM >= 0;

  /// The axle the block is against, numbered from one for the interface.
  int? get axleNumber => wheelIndex == null ? null : wheelIndex! + 1;
}

/// Measures every **stop block** in [layout] against the vehicle standing at
/// [vehicleOffsetX].
///
/// Half-round inserts and packing boards are not measured: the plates seat an
/// insert between the road wheels and dimension no distance from the running
/// gear for it, so a seating distance computed for one is a number about
/// nothing — and it read as a large negative one, failing a correctly placed
/// piece against a range never written about it.
List<BlockSeating> measureBlockSeating({
  required SecuringLayout layout,
  required VehicleModel3 vehicle,
  required double vehicleOffsetX,
}) {
  final trackHalf = vehicle.spec.runningGearWidthM / 2;

  return [
    for (final piece in layout.stopBlocks)
      () {
        final side = piece.z >= 0 ? 1 : -1;
        final trackZ = side * vehicle.trackCenterZ;
        final against = _bearingPointFor(piece, vehicle, vehicleOffsetX);
        // Positive when the working face stands clear of the running gear:
        // ahead of what it is against, or behind it.
        final distance = against.againstFront
            ? piece.x - against.x
            : against.x - piece.x;
        final blockHalf = piece.lengthM / 2;
        final overlap = math.min(piece.z + blockHalf, trackZ + trackHalf) -
            math.max(piece.z - blockHalf, trackZ - trackHalf);
        return BlockSeating(
          pieceId: piece.id,
          seatingDistanceM: distance,
          againstFrontOfRun: against.againstFront,
          wheelIndex: against.wheelIndex,
          trackSide: side,
          lateralOffsetM: (piece.z - trackZ).abs(),
          underRunningGear: overlap > 0,
          // A block ahead of the run must present its face rearwards, and one
          // behind it must present its face forwards.
          facesTheRun: against.againstFront
              ? piece.facing == ChockFacing.towardsRear
              : piece.facing == ChockFacing.towardsFront,
        );
      }(),
  ];
}

/// Every point on the running gear a block can be seated against, along the
/// wagon and in world coordinates.
///
/// For a **tracked** vehicle that is the two ends of the bearing length, which
/// is what plate-03 dimensions from. For a **wheeled** one it is each tyre's
/// contact patch, because plate-06 puts a chock under every tyre.
///
/// One list, used by the measurement, by the snap assist and by where a newly
/// added piece lands — because when they disagreed, asking the assist for a
/// block 12.5 cm from the wheel produced one the readout called 67 cm away,
/// and no amount of nudging could reconcile them.
List<double> bearingPointsFor(VehicleModel3 vehicle, double vehicleOffsetX) {
  if (vehicle.wheelContactX.isNotEmpty) {
    return [for (final x in vehicle.wheelContactX) x + vehicleOffsetX];
  }
  return [
    vehicle.trackContactX.rear + vehicleOffsetX,
    vehicle.trackContactX.front + vehicleOffsetX,
  ];
}

/// The point on the running gear a block is seated against, and which side of
/// it the block is on.
///
/// For a **tracked** vehicle that is one of the two ends of the bearing
/// length, which is what plate-03 dimensions from. For a **wheeled** one it is
/// the nearest tyre's contact patch — plate-06 puts a chock under each tyre,
/// so a block between the middle and rear axles of a six-wheeler is against
/// the wheel it is nearest, not against the far end of the vehicle. Measuring
/// a lorry from its outermost tyre gave a figure about nothing: a block
/// correctly seated at the middle axle read as being a metre and a half from
/// "the running gear".
({double x, bool againstFront, int? wheelIndex}) _bearingPointFor(
  SecuringPiece piece,
  VehicleModel3 vehicle,
  double vehicleOffsetX,
) {
  final wheeled = vehicle.wheelContactX.isNotEmpty;
  final points = bearingPointsFor(vehicle, vehicleOffsetX);
  var index = 0;
  var best = double.infinity;
  for (var i = 0; i < points.length; i++) {
    final d = (piece.x - points[i]).abs();
    if (d < best) {
      best = d;
      index = i;
    }
  }
  final at = points[index];
  if (!wheeled) {
    // A track's two ends: the front one is the second of the pair, and which
    // side of it the block sits on is decided by the end rather than by the
    // block, because a block inside the bearing length is a mistake and must
    // read as a negative distance rather than as a positive one.
    final againstFront = index == 1;
    return (x: at, againstFront: againstFront, wheelIndex: null);
  }
  return (x: at, againstFront: piece.x >= at, wheelIndex: index);
}

/// The `x` that puts a block's working face exactly [distanceM] from the end
/// of the bearing length it is seated against.
///
/// The inverse of the seating measurement, and it exists because placing a
/// block to a centimetre by dragging it through a perspective view is not
/// something anyone should have to do. The trainee types the distance the
/// plate calls for, or steps it a centimetre at a time, and the block goes
/// exactly there.
double xForSeatingDistance({
  required BlockSeating seating,
  required VehicleModel3 vehicle,
  required double vehicleOffsetX,
  required double distanceM,
}) {
  final wheel = seating.wheelIndex;
  final double contact;
  if (wheel != null && wheel < vehicle.wheelContactX.length) {
    // Measured from the wheel it is against, so typing a figure and reading
    // one back cannot disagree.
    contact = vehicle.wheelContactX[wheel] + vehicleOffsetX;
  } else {
    contact = seating.againstFrontOfRun
        ? vehicle.trackContactX.front + vehicleOffsetX
        : vehicle.trackContactX.rear + vehicleOffsetX;
  }
  return seating.againstFrontOfRun ? contact + distanceM : contact - distanceM;
}

/// One placed stop block, measured, and what the handbook asked for.
///
/// This is what the result sheet needs and had no way to say: where the
/// trainee put each block, where it should have been, and whether the two
/// agree. Until the gear could be placed by hand there was nothing to
/// compare; now there is.
class SeatingFinding {
  final String placementId;
  final String pieceId;

  /// The vehicle the block is holding down, for the sheet.
  final String designation;

  /// Where the trainee actually put it.
  final double measuredCm;

  /// What the chosen arrangement calls for, when one has been chosen and it
  /// states a distance. Null leaves the finding unjudged.
  final ({int minCm, int maxCm})? requiredRange;

  final bool underRunningGear;
  final bool facesTheRun;
  final CheckStatus status;

  /// The plate or paragraph the range came from.
  final String referenceId;

  const SeatingFinding({
    required this.placementId,
    required this.pieceId,
    required this.designation,
    required this.measuredCm,
    required this.requiredRange,
    required this.underRunningGear,
    required this.facesTheRun,
    required this.status,
    required this.referenceId,
  });

  /// The middle of the required range — the single figure to aim at, for a
  /// sheet that has room for one number rather than two.
  double? get targetCm => requiredRange == null
      ? null
      : (requiredRange!.minCm + requiredRange!.maxCm) / 2;

  /// How far off the trainee was, signed. Null when nothing was required.
  double? get errorCm {
    final range = requiredRange;
    if (range == null) return null;
    if (measuredCm < range.minCm) return measuredCm - range.minCm;
    if (measuredCm > range.maxCm) return measuredCm - range.maxCm;
    return 0;
  }
}

/// Turns one placement's layout into findings for the result sheet.
List<SeatingFinding> seatingFindingsFor({
  required String placementId,
  required String designation,
  required SecuringLayout layout,
  required VehicleModel3 vehicle,
  required double vehicleOffsetX,
  required ChockArrangement? arrangement,
}) {
  final seatings = measureBlockSeating(
    layout: layout,
    vehicle: vehicle,
    vehicleOffsetX: vehicleOffsetX,
  );
  return [
    for (final seating in seatings)
      () {
        final piece = layout.byId(seating.pieceId);
        final check = checkSeatingDistance(
          seating: seating,
          arrangement: arrangement,
          kind: piece?.kind ?? SecuringPieceKind.woodChock,
        );
        return SeatingFinding(
          placementId: placementId,
          pieceId: seating.pieceId,
          designation: designation,
          measuredCm: seating.seatingDistanceCm,
          requiredRange: piece?.kind == SecuringPieceKind.woodChock
              ? arrangement?.seatingDistance
              : null,
          underRunningGear: seating.underRunningGear,
          facesTheRun: seating.facesTheRun,
          status: check.status,
          referenceId: check.referenceId,
        );
      }(),
  ];
}

/// Checks a block's seating distance against the range the chosen
/// [arrangement] states.
///
/// Returns `unknown` — never a guessed verdict — when the arrangement carries
/// no seating distance, which is the case for every wheeled arrangement (those
/// dimension a lateral gap from the tyre instead) and for any case the extract
/// did not record one for. The citation is the arrangement's own, so the
/// trainee can go straight to the plate the number came from.
ValidationCheck checkSeatingDistance({
  required BlockSeating seating,
  required ChockArrangement? arrangement,
  SecuringPieceKind kind = SecuringPieceKind.woodChock,
}) {
  // The 10-15 cm range is written about the squared wood stop block. A KGUUB
  // has a rule of its own (`rule-kguub-chock-spacing`: 0.5 m from where the
  // track rests on the rail), and a spur or a boot is bolted through the deck
  // rather than seated off the running gear. Their distance is worth
  // measuring and is measured; judging it against the wood block's range
  // would fail a correctly placed piece.
  if (kind != SecuringPieceKind.woodChock) {
    return ValidationCheck(
      ruleId: 'rule-chock-seating-distance',
      label: AppStrings.seatingDistanceCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.seatingDistanceOtherHardwareDetail,
      referenceId: arrangement?.referenceId ?? 'plate-02',
    );
  }
  final range = arrangement?.seatingDistance;
  if (arrangement == null || range == null) {
    return ValidationCheck(
      ruleId: 'rule-chock-seating-distance',
      label: AppStrings.seatingDistanceCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.seatingDistanceUnknownDetail,
      referenceId: arrangement?.referenceId ?? 'plate-02',
    );
  }
  if (!seating.underRunningGear) {
    return ValidationCheck(
      ruleId: 'rule-chock-seating-distance',
      label: AppStrings.seatingDistanceCheckLabel,
      status: CheckStatus.fail,
      detail: AppStrings.seatingDistanceNotUnderRunDetail(
          seating.lateralOffsetM * 100),
      referenceId: arrangement.referenceId,
    );
  }
  if (!seating.facesTheRun) {
    return ValidationCheck(
      ruleId: 'rule-chock-seating-distance',
      label: AppStrings.seatingDistanceCheckLabel,
      status: CheckStatus.fail,
      detail: AppStrings.seatingDistanceWrongWayDetail,
      referenceId: arrangement.referenceId,
    );
  }
  final cm = seating.seatingDistanceCm;
  final within = cm >= range.minCm && cm <= range.maxCm;
  return ValidationCheck(
    ruleId: 'rule-chock-seating-distance',
    label: AppStrings.seatingDistanceCheckLabel,
    status: within ? CheckStatus.pass : CheckStatus.fail,
    detail: within
        ? AppStrings.seatingDistanceOkDetail(cm, range.minCm, range.maxCm)
        : AppStrings.seatingDistanceOutOfRangeDetail(cm, range.minCm, range.maxCm),
    referenceId: arrangement.referenceId,
  );
}
