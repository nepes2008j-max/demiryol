import 'dart:math' as math;

import '../models/scene3d.dart';
import 'mesh_primitives.dart';
import 'vehicle_mesh_builder.dart';

/// The dimensions a wheeled vehicle's model is built from.
///
/// Three of the fields are the record's own — length, width and height — and
/// they are the only three every reported measurement depends on: load height
/// above the rail, the width over the widest point, the overhang past the end
/// of the deck and the space to the next vehicle all come from those.
///
/// The rest — where the axles sit, how big the wheels are, how far back the
/// cab ends — are **drawing proportions**, and they are named as such. No
/// record in this catalogue carries a wheelbase or a ground clearance for any
/// lorry, and a model has to put the wheels somewhere. They are held here, in
/// one place, with defaults that make a three-axle military lorry look like
/// one, so that a reader can see exactly which numbers came from the source
/// and which did not.
class WheeledVehicleMeshSpec implements VehicleMeshSpec {
  /// Recorded: overall length.
  @override
  final double hullLengthM;

  /// Recorded: overall width.
  @override
  final double overallWidthM;

  /// Recorded: overall height, over the cab or the tilt, whichever is taller.
  @override
  final double overallHeightM;

  /// Drawing proportion unless a record supplies one.
  @override
  final double groundClearanceM;

  final int axleCount;

  /// Radius of one wheel, tyre included.
  final double wheelRadiusM;

  /// Width of one tyre — the bearing surface a stop block is seated against.
  final double tyreWidthM;

  /// Each axle's position along the vehicle, as a fraction of the half-length
  /// measured from the centre: `+1` is the nose, `-1` the tail.
  final List<double> axleFractions;

  /// How far back the cab reaches, as a fraction of the length.
  final double cabFraction;

  /// True for a cab-over-engine lorry (the KamAZ), false for a bonneted one
  /// (the ZIL and the Ural). It changes the silhouette more than anything
  /// else about these three.
  final bool cabOverEngine;

  /// A canvas tilt over the cargo bed, which is what takes a military lorry
  /// up to its recorded height.
  final bool hasTilt;

  const WheeledVehicleMeshSpec({
    required this.hullLengthM,
    required this.overallWidthM,
    required this.overallHeightM,
    this.groundClearanceM = 0.40,
    this.axleCount = 3,
    this.wheelRadiusM = 0.55,
    this.tyreWidthM = 0.32,
    this.axleFractions = const [0.63, -0.32, -0.70],
    this.cabFraction = 0.30,
    this.cabOverEngine = false,
    this.hasTilt = true,
  });

  @override
  double get halfLength => hullLengthM / 2;

  /// A tyre is the wheeled vehicle's bearing surface.
  @override
  double get runningGearWidthM => tyreWidthM;

  /// A lorry has nothing overhanging its body.
  @override
  double get lengthOverGunM => hullLengthM;

  /// Where the centre line of each wheel run sits, `±` from the middle.
  double get wheelCenterZ => overallWidthM / 2 - tyreWidthM / 2;

  /// The axle positions in metres along the vehicle.
  List<double> get axleXs =>
      [for (final f in axleFractions.take(axleCount)) f * halfLength];
}

/// The arch of a canvas tilt, from the rear of the bed to the back of the cab,
/// rising to exactly [top].
///
/// The height is hit by scaling off the tallest *sampled* point rather than
/// off the circle's radius. A polygon through a half circle never reaches the
/// radius unless a sample lands exactly at the apex, so scaling by the radius
/// left the lorry a few centimetres under its recorded height — and that
/// height is what the scene reports as the load's height above the rail.
List<Profile2> _tiltProfile({
  required double rear,
  required double front,
  required double base,
  required double top,
}) {
  final arc = MeshPrimitives.arc(
    cx: (rear + front) / 2,
    cy: base,
    radius: (front - rear) / 2,
    fromAngle: 0,
    toAngle: math.pi,
    steps: 12,
  );
  final peak = arc.map((p) => p.y).reduce(math.max) - base;
  final scale = peak <= 1e-9 ? 0.0 : (top - base) / peak;
  final profile = <Profile2>[
    p2(rear, base),
    p2(front, base),
    for (final p in arc) p2(p.x, base + (p.y - base) * scale),
  ];

  // The arc's own ends sit on the base line, at the same two points the
  // profile opens with, so the polygon can come back with a repeated vertex —
  // and a repeated vertex extrudes into a zero-area quad whose normal is the
  // zero vector, which then sorts and shades as noise. Whether the duplicate
  // appears at all came down to whether `cx + radius` rounded to exactly
  // `front`, so it was luck rather than geometry that kept it out. Dropped
  // here once, for every proportion the catalogue can now ask for.
  final deduped = <Profile2>[];
  for (final point in profile) {
    final last = deduped.isEmpty ? null : deduped.last;
    if (last != null &&
        (last.x - point.x).abs() < 1e-6 &&
        (last.y - point.y).abs() < 1e-6) {
      continue;
    }
    deduped.add(point);
  }
  final first = deduped.first;
  final last = deduped.last;
  if (deduped.length > 1 &&
      (first.x - last.x).abs() < 1e-6 &&
      (first.y - last.y).abs() < 1e-6) {
    deduped.removeLast();
  }
  return deduped;
}

/// Builds a wheeled vehicle: chassis, cab, cargo bed and its tilt, wheels on
/// their axles, mudguards and a bumper.
///
/// The reference points come back the same way a tracked vehicle's do, so the
/// securing gear does not care which it is holding down. What differs is what
/// "the running gear" means: for a lorry it is the tyres, and the plates put a
/// chock under each one rather than at the ends of a bearing length — so
/// [VehicleModel3.wheelContactX] carries every axle, and the front and rear of
/// it stand in for the track's ends.
VehicleModel3 buildWheeledVehicleModel(WheeledVehicleMeshSpec spec) {
  final halfL = spec.halfLength;
  final halfW = spec.overallWidthM / 2;
  final clearance = spec.groundClearanceM;
  final wheelZ = spec.wheelCenterZ;
  final axles = spec.axleXs;

  // ---- Chassis: two frame rails the body sits on ----
  final frameTop = clearance + 0.22;
  final rail = MeshPrimitives.box(
    corner: Vector3(-halfL * 0.98, clearance, halfW * 0.36),
    opposite: Vector3(halfL * 0.92, frameTop, halfW * 0.52),
    material: SurfaceMaterial.hullBelly,
    partId: 'chassis',
  );
  final chassis = rail + rail.mirroredZ();

  // ---- Cab ----
  final cabRear = halfL - spec.hullLengthM * spec.cabFraction;
  final cabRoof = frameTop + (spec.overallHeightM - frameTop) * 0.78;
  final bonnetTop = frameTop + (cabRoof - frameTop) * 0.42;
  final cabNose = spec.cabOverEngine ? halfL : halfL - spec.hullLengthM * 0.12;

  final cab = Mesh3.merge([
    // The cab box.
    MeshPrimitives.extrudeZ(
      [
        p2(cabRear, frameTop),
        p2(cabNose, frameTop),
        p2(cabNose, cabRoof - 0.16),
        // A raked windscreen, which is most of what makes a cab read as one.
        p2(cabNose - 0.22, cabRoof),
        p2(cabRear, cabRoof),
      ],
      zMin: -halfW * 0.94,
      zMax: halfW * 0.94,
      material: SurfaceMaterial.hullArmour,
      capMaterial: SurfaceMaterial.hullSide,
      partId: 'cab',
    ),
    // The windscreen itself, standing just proud of the raked plate.
    MeshPrimitives.extrudeZ(
      [
        p2(cabNose - 0.02, cabRoof - 0.60),
        p2(cabNose - 0.24, cabRoof - 0.02),
        p2(cabNose - 0.30, cabRoof - 0.06),
        p2(cabNose - 0.08, cabRoof - 0.64),
      ],
      zMin: -halfW * 0.86,
      zMax: halfW * 0.86,
      material: SurfaceMaterial.glazing,
      partId: 'cab.windscreen',
    ),
    // A bonnet ahead of the cab, on the two that have one.
    if (!spec.cabOverEngine)
      MeshPrimitives.box(
        corner: Vector3(cabNose, frameTop, -halfW * 0.80),
        opposite: Vector3(halfL - 0.18, bonnetTop, halfW * 0.80),
        material: SurfaceMaterial.hullArmour,
        partId: 'bonnet',
      ),
    // Front bumper.
    MeshPrimitives.box(
      corner: Vector3(halfL - 0.14, clearance + 0.10, -halfW * 0.92),
      opposite: Vector3(halfL, clearance + 0.34, halfW * 0.92),
      material: SurfaceMaterial.fender,
      partId: 'bumper',
    ),
  ]);

  // ---- Cargo bed, and the tilt over it ----
  final bedFloor = frameTop + 0.06;
  // The tail of the bed is the tail of the vehicle. It used to stop 4% short,
  // which left the drawn lorry 15 cm shorter than its record — and every
  // overhang the scene reports is measured off these bounds.
  final bedRear = -halfL;
  // The side panel takes a third of what is left above the bed floor, and is
  // held clear of the roof. On a low lorry — and the catalogue now carries
  // lorries from 1.4 m to 3.4 m tall — the floor can sit close enough to the
  // recorded height that the panel and the tilt above it have no room between
  // them, which produced a collapsed face and then shaded as noise.
  final bedSideTop = math.min(
    bedFloor + (spec.overallHeightM - bedFloor) * 0.34,
    spec.overallHeightM - 0.10,
  );
  final bed = Mesh3.merge([
    MeshPrimitives.box(
      corner: Vector3(bedRear, frameTop, -halfW),
      opposite: Vector3(cabRear - 0.10, bedFloor, halfW),
      material: SurfaceMaterial.stowage,
      partId: 'bed.floor',
    ),
    for (final side in const [1, -1])
      MeshPrimitives.box(
        corner: Vector3(bedRear, bedFloor, side * halfW),
        opposite: Vector3(cabRear - 0.10, bedSideTop, side * (halfW - 0.06)),
        material: SurfaceMaterial.stowage,
        partId: 'bed.side',
      ),
    MeshPrimitives.box(
      corner: Vector3(bedRear, bedFloor, -halfW),
      opposite: Vector3(bedRear + 0.06, bedSideTop, halfW),
      material: SurfaceMaterial.stowage,
      partId: 'bed.tailgate',
    ),
    // Only where the roof stands clear of the bed sides. Below that there is
    // no arch to draw, and drawing one anyway means a zero-height extrusion.
    if (spec.hasTilt && spec.overallHeightM > bedSideTop + 0.05)
      // A rounded canvas tilt: the recorded height is over this, which is why
      // it is drawn rather than left as an open bed a metre too short.
      MeshPrimitives.extrudeZ(
        _tiltProfile(
          rear: bedRear,
          front: cabRear - 0.10,
          base: bedSideTop,
          top: spec.overallHeightM,
        ),
        zMin: -halfW * 0.98,
        zMax: halfW * 0.98,
        material: SurfaceMaterial.tilt,
        partId: 'bed.tilt',
      ),
  ]);

  // ---- Wheels and mudguards ----
  final running = <Mesh3>[];
  for (final x in axles) {
    running.add(MeshPrimitives.cylinderZ(
      center: Vector3(x, spec.wheelRadiusM, wheelZ),
      radius: spec.wheelRadiusM,
      length: spec.tyreWidthM,
      material: SurfaceMaterial.tyre,
      segments: 16,
      partId: 'wheel',
    ));
    // The hub, so a wheel is not a featureless black disc.
    running.add(MeshPrimitives.cylinderZ(
      center: Vector3(x, spec.wheelRadiusM, wheelZ + spec.tyreWidthM * 0.10),
      radius: spec.wheelRadiusM * 0.52,
      length: spec.tyreWidthM * 0.5,
      material: SurfaceMaterial.roadWheel,
      segments: 12,
      partId: 'wheel.hub',
    ));
    // The mudguard is held inside the recorded width. Left to overhang the
    // tyre by its own margin it made the drawn lorry 16 cm wider than its
    // record — and the width the scene reports, and checks against the deck
    // edge, is measured off these bounds.
    running.add(MeshPrimitives.box(
      corner: Vector3(x - spec.wheelRadiusM * 1.15, spec.wheelRadiusM * 1.30,
          wheelZ - spec.tyreWidthM * 0.75),
      opposite: Vector3(x + spec.wheelRadiusM * 1.15,
          spec.wheelRadiusM * 1.30 + 0.06,
          math.min(wheelZ + spec.tyreWidthM * 0.75, halfW)),
      material: SurfaceMaterial.fender,
      partId: 'mudguard',
    ));
    // The axle beam across to the other side.
    running.add(MeshPrimitives.rod(
      a: Vector3(x, spec.wheelRadiusM, -wheelZ),
      b: Vector3(x, spec.wheelRadiusM, wheelZ),
      radius: 0.055,
      material: SurfaceMaterial.hullBelly,
      segments: 8,
      partId: 'axle',
    ));
  }
  final oneSide = Mesh3.merge(running);
  final runningGear = oneSide + oneSide.mirroredZ();

  // Towing eyes at each end, at the height a wire is shackled at.
  final eyeZ = halfW * 0.55;
  final lashingEyes = <Vector3>[
    Vector3(halfL - 0.10, clearance + 0.14, eyeZ),
    Vector3(halfL - 0.10, clearance + 0.14, -eyeZ),
    Vector3(-halfL + 0.10, clearance + 0.14, eyeZ),
    Vector3(-halfL + 0.10, clearance + 0.14, -eyeZ),
  ];

  return VehicleModel3(
    mesh: Mesh3.merge([chassis, cab, bed, runningGear]),
    spec: spec,
    lashingEyes: lashingEyes,
    // The outermost axles stand in for the ends of a track's bearing length,
    // so a stop block seated "against the running gear" lands against the
    // front and rear tyres, which is where plate-06 puts it.
    trackContactX: (
      front: axles.reduce(math.max) + spec.wheelRadiusM,
      rear: axles.reduce(math.min) - spec.wheelRadiusM,
    ),
    wheelContactX: axles,
    trackCenterZ: wheelZ,
    gunReachX: 0,
  );
}
