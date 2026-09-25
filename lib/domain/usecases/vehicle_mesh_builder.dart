import 'dart:math' as math;

import '../models/scene3d.dart';
import 'mesh_primitives.dart';
import 'wheeled_vehicle_mesh_builder.dart';

/// What every vehicle model — tracked or wheeled — has to be able to tell the
/// scene about itself.
///
/// The scene, the securing gear and every measurement below the picture work
/// in these terms and in no others, which is what lets a lorry stand on the
/// wagon beside a tank without either of them being a special case.
abstract class VehicleMeshSpec {
  /// Length of the body, excluding any armament overhang.
  double get hullLengthM;

  /// Widest point of the vehicle.
  double get overallWidthM;

  /// Top of the vehicle above the ground — its transport height.
  double get overallHeightM;

  /// Underside above the ground.
  double get groundClearanceM;

  /// Width of one bearing surface: a track shoe, or a tyre.
  ///
  /// The securing gear is sized and seated against this — a stop block is
  /// never shorter than it, and a block is "under the running gear" when its
  /// own width across the wagon overlaps it.
  double get runningGearWidthM;

  /// Half the body length. The nose is at `+x`, the tail at `-x`.
  double get halfLength;

  /// Full length including anything that overhangs the body — a gun trained
  /// forward. Equal to [hullLengthM] for a vehicle with no overhang.
  double get lengthOverGunM;
}

/// The dimensions a tracked vehicle's three-dimensional model is built from.
///
/// Every field is a real length in metres, and every one of them is used —
/// nothing here is a styling knob. That is the point: the model is a
/// *dimensioned* object, so what the trainee sees standing on the deck has
/// the true height, the true width over the tracks and the true overhang, and
/// the clearances the handbook cares about can be read off it. A model drawn
/// to look right rather than to measure right would be worse than no model,
/// because it would invite exactly the judgement it cannot support.
///
/// The vehicle's own origin is the **centre of the hull at ground level**:
/// `y = 0` is the face the tracks stand on, `+x` is towards the front of the
/// vehicle, `+z` is its right-hand side. Putting a vehicle on a wagon is then
/// a translation, and nothing inside the model needs to know about the deck.
class TrackedVehicleMeshSpec implements VehicleMeshSpec {
  /// Hull length, excluding any gun overhang.
  @override
  final double hullLengthM;

  /// Width across the outside of both tracks.
  final double widthOverTracksM;

  /// Widest point of the vehicle, over the side skirts. Equal to
  /// [widthOverTracksM] on a vehicle with no skirts.
  @override
  final double overallWidthM;

  /// Top of the hull roof above the ground.
  final double hullRoofHeightM;

  /// Top of the turret roof above the ground — the vehicle's transport height,
  /// and the figure the loading gauge is judged against.
  @override
  final double overallHeightM;

  /// Underside of the hull above the ground.
  @override
  final double groundClearanceM;

  /// Width of one track shoe.
  final double trackShoeWidthM;

  /// Length of track actually in contact with the ground.
  final double trackContactLengthM;

  final int roadWheelCount;
  final double roadWheelRadiusM;

  /// How far the gun reaches past the nose with the turret facing forward.
  /// Zero for a vehicle whose armament does not overhang.
  final double gunOverhangM;

  final double gunBarrelRadiusM;

  /// Bolt-on reactive armour across the glacis. False leaves the plate bare.
  final bool hasAppliqueArmour;

  /// Cylindrical fuel drums carried across the rear plate.
  final int rearFuelDrums;

  const TrackedVehicleMeshSpec({
    required this.hullLengthM,
    required this.widthOverTracksM,
    required this.overallWidthM,
    required this.hullRoofHeightM,
    required this.overallHeightM,
    required this.groundClearanceM,
    required this.trackShoeWidthM,
    required this.trackContactLengthM,
    required this.roadWheelCount,
    required this.roadWheelRadiusM,
    required this.gunOverhangM,
    this.gunBarrelRadiusM = 0.10,
    this.hasAppliqueArmour = false,
    this.rearFuelDrums = 0,
  });

  /// T-72 (Object 172M) — the baseline main battle tank the T-90 descends
  /// from, and the vehicle the handbook covers as "Object 172".
  ///
  /// Manufacturer's published specification: hull 6.86 m, 9.53 m overall with
  /// the gun forward (hence the same 2.67 m of overhang), 3.59 m over the
  /// fenders and 3.46 m over the tracks, 2.19 m to the turret roof, 41.0 t,
  /// 0.47 m ground clearance, 580 mm track shoes, 4.27 m of track on the
  /// ground. No reactive armour on the baseline hull — that is what most
  /// visibly separates it from the T-90S beside it.
  static const TrackedVehicleMeshSpec t72 = TrackedVehicleMeshSpec(
    hullLengthM: 6.86,
    widthOverTracksM: 3.46,
    overallWidthM: 3.59,
    hullRoofHeightM: 1.40,
    overallHeightM: 2.19,
    groundClearanceM: 0.47,
    trackShoeWidthM: 0.58,
    trackContactLengthM: 4.27,
    roadWheelCount: 6,
    roadWheelRadiusM: 0.375,
    gunOverhangM: 2.67,
    gunBarrelRadiusM: 0.105,
    hasAppliqueArmour: false,
    rearFuelDrums: 2,
  );

  /// T-90S — the export main battle tank, Uralvagonzavod.
  ///
  /// These figures are the manufacturer's published specification, **not**
  /// handbook data: the source handbook's Annex 14 catalogue stops at the
  /// Soviet-era vehicles and never names a T-90 of any variant. Everything
  /// built on them is marked accordingly wherever it reaches the trainee —
  /// see `VehicleDataSource.manufacturerSpec` and the badge it drives.
  ///
  /// * hull 6.86 m, 9.53 m overall with the gun forward (hence 2.67 m of
  ///   overhang), 3.78 m over the side skirts, 3.37 m over the tracks
  /// * 2.23 m to the turret roof, 0.49 m ground clearance
  /// * 580 mm track shoes, 4.27 m of track on the ground, six road wheels
  static const TrackedVehicleMeshSpec t90s = TrackedVehicleMeshSpec(
    hullLengthM: 6.86,
    widthOverTracksM: 3.37,
    overallWidthM: 3.78,
    hullRoofHeightM: 1.42,
    overallHeightM: 2.23,
    groundClearanceM: 0.49,
    trackShoeWidthM: 0.58,
    trackContactLengthM: 4.27,
    roadWheelCount: 6,
    roadWheelRadiusM: 0.375,
    gunOverhangM: 2.67,
    gunBarrelRadiusM: 0.105,
    hasAppliqueArmour: true,
    rearFuelDrums: 2,
  );

  /// T-80U — the gas-turbine main battle tank, Omsk.
  ///
  /// Manufacturer's published specification, **not** handbook data (the
  /// handbook's Annex 14 catalogue never names a T-80 of any variant): hull
  /// 7.0 m, 9.65 m overall with the gun forward (hence 2.65 m of overhang),
  /// 3.60 m over the side skirts, ~3.40 m over the tracks, 2.20 m to the
  /// turret roof, 0.45 m ground clearance, 580 mm track shoes, ~4.40 m of
  /// track on the ground, six road wheels. Carries Kontakt-5 reactive armour
  /// across the glacis and turret front.
  static const TrackedVehicleMeshSpec t80u = TrackedVehicleMeshSpec(
    hullLengthM: 7.00,
    widthOverTracksM: 3.40,
    overallWidthM: 3.60,
    hullRoofHeightM: 1.15,
    overallHeightM: 2.20,
    groundClearanceM: 0.45,
    trackShoeWidthM: 0.58,
    trackContactLengthM: 4.40,
    roadWheelCount: 6,
    roadWheelRadiusM: 0.33,
    gunOverhangM: 2.65,
    gunBarrelRadiusM: 0.105,
    hasAppliqueArmour: true,
    rearFuelDrums: 2,
  );

  /// Half the hull length — the nose is at `+x`, the rear plate at `-x`.
  @override
  double get halfLength => hullLengthM / 2;

  /// A track shoe is the tracked vehicle's bearing surface.
  @override
  double get runningGearWidthM => trackShoeWidthM;

  /// Distance from the centre line to the middle of one track.
  double get trackCenterOffsetM => widthOverTracksM / 2 - trackShoeWidthM / 2;

  /// The tank's full length with the gun trained straight ahead.
  @override
  double get lengthOverGunM => hullLengthM + gunOverhangM;
}

/// A built vehicle, with the few points on it that the rest of the scene has
/// to attach to.
///
/// The securing gear is placed against these rather than against numbers
/// re-derived from the spec, so a chock can never end up a hand's width from
/// the track it is supposed to be blocking.
class VehicleModel3 {
  final Mesh3 mesh;

  /// What the model was built from. Held as the shared interface so the
  /// securing gear, which only ever asks about the bearing surface and the
  /// body's extent, does not have to know whether it is holding down a tank
  /// or a lorry.
  final VehicleMeshSpec spec;

  /// Where the lashing wires are made fast on the vehicle: the front and rear
  /// towing eyes, in the vehicle's own frame.
  ///
  /// Their number and position are a property of *this drawing*, not of the
  /// handbook: no source records certified lashing points for any vehicle in
  /// this catalogue, so nothing may present these as the vehicle's own. They
  /// exist so a wire can be drawn between two real places.
  final List<Vector3> lashingEyes;

  /// The `x` range over which each track touches the deck. What a stop block
  /// must be butted against.
  ///
  /// For a wheeled vehicle this is the outermost tyres' outer edges, so that
  /// "seated against the running gear" means the same thing for both.
  final ({double front, double rear}) trackContactX;

  /// Where each wheel touches the deck, along the wagon.
  ///
  /// Empty for a tracked vehicle, which bears continuously along its track
  /// rather than at points. Plate-06 puts a chock under *each tyre* of a
  /// lorry, so a wheeled model has to say where those are — the ends of the
  /// bearing length are not enough.
  final List<double> wheelContactX;

  /// Centre-line offset of the two tracks, `±`.
  final double trackCenterZ;

  /// How far the gun reaches past the nose as the turret is currently
  /// traversed, along `+x`. Negative when it overhangs the rear instead.
  final double gunReachX;

  /// The same vehicle drawn from a model file instead of from primitives.
  ///
  /// Only the appearance is replaced. The lashing eyes, the track's bearing
  /// range and its centre line all come from the vehicle's recorded
  /// dimensions, and they have to: a downloaded mesh knows nothing about
  /// where a stop block goes, and every measurement the scene reports is taken
  /// against these points rather than against whatever the file happens to
  /// contain.
  VehicleModel3 withMesh(Mesh3 replacement) => VehicleModel3(
        mesh: replacement,
        spec: spec,
        lashingEyes: lashingEyes,
        trackContactX: trackContactX,
        wheelContactX: wheelContactX,
        trackCenterZ: trackCenterZ,
        gunReachX: gunReachX,
      );

  const VehicleModel3({
    required this.mesh,
    required this.spec,
    required this.lashingEyes,
    required this.trackContactX,
    this.wheelContactX = const [],
    required this.trackCenterZ,
    required this.gunReachX,
  });
}

/// Builds whichever kind of vehicle the specification describes.
///
/// The one door every caller comes through, so that a lorry standing on a
/// wagon beside a tank is not a special case anywhere above this line.
VehicleModel3 buildVehicleModel(
  VehicleMeshSpec spec, {
  double turretTraverse = 0.0,
}) =>
    spec is WheeledVehicleMeshSpec
        ? buildWheeledVehicleModel(spec)
        : buildTrackedVehicleModel(spec as TrackedVehicleMeshSpec,
            turretTraverse: turretTraverse);

/// Builds the three-dimensional model of a tracked vehicle from its
/// dimensions.
///
/// [turretTraverse] is the angle the turret is trained at, in radians, `0`
/// straight ahead and `pi` over the rear deck. It is a control, not a rule:
/// the source handbook's extract says nothing about which way a gun is to be
/// trained for carriage, so the view offers the angle and reports the
/// resulting overhang rather than asserting a correct answer.
VehicleModel3 buildTrackedVehicleModel(
  TrackedVehicleMeshSpec spec, {
  double turretTraverse = 0.0,
}) {
  final halfL = spec.halfLength;
  final tubHalfWidth = spec.widthOverTracksM / 2 - spec.trackShoeWidthM;
  // The sponsons stop 15 mm inside the outer face of the tracks. Physically
  // that is about right, and it keeps two large surfaces off the same plane:
  // drawn flush, the hull side and the track's outer face have no stable draw
  // order and flicker against each other wherever they overlap. The vehicle's
  // stated width over the tracks is unaffected — the tracks still define it.
  final sponsonHalfWidth = spec.widthOverTracksM / 2 - 0.015;
  final clearance = spec.groundClearanceM;
  final roof = spec.hullRoofHeightM;

  // ---- Lower hull (the tub between the tracks) ----
  final tubTop = clearance + (roof - clearance) * 0.42;
  final tub = MeshPrimitives.extrudeZ(
    [
      p2(-halfL, clearance),
      p2(halfL * 0.93, clearance),
      p2(halfL, clearance + 0.23),
      p2(halfL, tubTop),
      p2(-halfL, tubTop),
    ],
    zMin: -tubHalfWidth,
    zMax: tubHalfWidth,
    material: SurfaceMaterial.hullBelly,
    capMaterial: SurfaceMaterial.hullSide,
    partId: 'hull.lower',
  );

  // ---- Upper hull: the long sloped glacis, the roof, the rear plate, and
  // the sponsons that overhang the tracks. ----
  final glacisFootX = halfL;
  final glacisFootY = clearance + 0.23;
  final glacisTopX = halfL * 0.15;
  final glacisTopY = roof;
  final upperHull = MeshPrimitives.extrudeZ(
    [
      p2(-halfL, tubTop),
      p2(halfL, tubTop),
      p2(glacisFootX, glacisFootY + 0.18),
      p2(glacisTopX, glacisTopY),
      p2(-halfL * 0.80, glacisTopY),
      p2(-halfL, roof - 0.32),
    ],
    zMin: -sponsonHalfWidth,
    zMax: sponsonHalfWidth,
    material: SurfaceMaterial.hullArmour,
    capMaterial: SurfaceMaterial.hullSide,
    partId: 'hull.upper',
  );

  // ---- Reactive armour across the glacis ----
  Mesh3 applique = Mesh3.empty;
  if (spec.hasAppliqueArmour) {
    final dx = glacisTopX - glacisFootX;
    final dy = glacisTopY - (glacisFootY + 0.18);
    final len = math.sqrt(dx * dx + dy * dy);
    final ux = dx / len, uy = dy / len;
    // Outward normal of the glacis, pointing up and forward off the plate.
    final nx = uy, ny = -ux;
    const rows = 5;
    const blockGap = 0.06;
    final blockLen = len / rows - blockGap;
    final blocks = <Mesh3>[];
    for (var row = 0; row < rows; row++) {
      final s0 = row * (len / rows) + blockGap / 2;
      final ax = glacisFootX + ux * s0, ay = glacisFootY + 0.18 + uy * s0;
      final bx = ax + ux * blockLen, by = ay + uy * blockLen;
      const t = 0.11;
      // Three blocks across, leaving the driver's hatch lane clear.
      for (final lane in const [-0.98, -0.33, 0.33, 0.98]) {
        blocks.add(MeshPrimitives.extrudeZ(
          [
            p2(ax, ay),
            p2(bx, by),
            p2(bx + nx * t, by + ny * t),
            p2(ax + nx * t, ay + ny * t),
          ],
          zMin: lane - 0.28,
          zMax: lane + 0.28,
          material: SurfaceMaterial.appliqueArmour,
          partId: 'hull.applique',
        ));
      }
    }
    applique = Mesh3.merge(blocks);
  }

  // ---- Running gear, built once for the right-hand side and mirrored ----
  final trackInnerZ = spec.widthOverTracksM / 2 - spec.trackShoeWidthM;
  final trackOuterZ = spec.widthOverTracksM / 2;
  final wheelZ = (trackInnerZ + trackOuterZ) / 2;
  const trackThickness = 0.11;

  final sprocketX = -halfL * 0.89;
  final sprocketY = clearance + 0.29;
  final sprocketR = spec.roadWheelRadiusM * 0.80;
  final idlerX = halfL * 0.89;
  final idlerY = clearance + 0.11;
  final idlerR = spec.roadWheelRadiusM * 0.72;
  final contactHalf = spec.trackContactLengthM / 2;

  List<Profile2> line(Profile2 from, Profile2 to, int steps) => [
        for (var i = 0; i < steps; i++)
          p2(from.x + (to.x - from.x) * i / steps, from.y + (to.y - from.y) * i / steps),
      ];

  // The loop is walked counter-clockwise in xy: forward along the ground,
  // up and over the idler, back along the top run, down around the sprocket.
  const groundY = trackThickness / 2;
  final frontArc = MeshPrimitives.arc(
    cx: idlerX,
    cy: idlerY,
    radius: idlerR + trackThickness / 2,
    fromAngle: -math.pi * 0.44,
    toAngle: math.pi * 0.44,
    steps: 7,
  );
  final rearArc = MeshPrimitives.arc(
    cx: sprocketX,
    cy: sprocketY,
    radius: sprocketR + trackThickness / 2,
    fromAngle: math.pi * 0.56,
    toAngle: math.pi * 1.44,
    steps: 7,
  );
  final trackPath = <Profile2>[
    ...line(p2(-contactHalf, groundY), p2(contactHalf, groundY), 14),
    ...line(p2(contactHalf, groundY), frontArc.first, 2),
    ...frontArc,
    ...line(frontArc.last, rearArc.first, 16),
    ...rearArc,
    ...line(rearArc.last, p2(-contactHalf, groundY), 2),
  ];

  final trackBand = MeshPrimitives.linkChain(
    trackPath,
    thickness: trackThickness,
    zMin: trackInnerZ,
    zMax: trackOuterZ,
    material: SurfaceMaterial.trackLink,
    linkGap: 0.035,
    partId: 'track',
  );

  final roadWheels = <Mesh3>[];
  final n = math.max(2, spec.roadWheelCount);
  final firstWheelX = contactHalf - spec.roadWheelRadiusM * 0.55;
  final wheelStep = (firstWheelX * 2) / (n - 1);
  for (var i = 0; i < n; i++) {
    roadWheels.add(MeshPrimitives.cylinderZ(
      center: Vector3(firstWheelX - wheelStep * i, spec.roadWheelRadiusM + 0.03, wheelZ),
      radius: spec.roadWheelRadiusM,
      length: spec.trackShoeWidthM * 0.62,
      material: SurfaceMaterial.roadWheel,
      segments: 14,
      partId: 'track.roadWheel',
    ));
  }
  // Return rollers carrying the top run.
  for (var i = 0; i < 3; i++) {
    roadWheels.add(MeshPrimitives.cylinderZ(
      center: Vector3(-halfL * 0.5 + halfL * 0.5 * i, roof - 0.52, wheelZ),
      radius: 0.11,
      length: spec.trackShoeWidthM * 0.45,
      material: SurfaceMaterial.roadWheel,
      segments: 10,
      partId: 'track.returnRoller',
    ));
  }

  final sprocket = MeshPrimitives.cylinderZ(
    center: Vector3(sprocketX, sprocketY, wheelZ),
    radius: sprocketR,
    length: spec.trackShoeWidthM * 0.55,
    material: SurfaceMaterial.driveSprocket,
    segments: 12,
    partId: 'track.sprocket',
  );
  final idler = MeshPrimitives.cylinderZ(
    center: Vector3(idlerX, idlerY, wheelZ),
    radius: idlerR,
    length: spec.trackShoeWidthM * 0.55,
    material: SurfaceMaterial.driveSprocket,
    segments: 12,
    partId: 'track.idler',
  );

  final rightRunningGear =
      Mesh3.merge([trackBand, ...roadWheels, sprocket, idler]);
  final runningGear = rightRunningGear + rightRunningGear.mirroredZ();

  // ---- Side skirts, out at the vehicle's widest point ----
  Mesh3 skirts = Mesh3.empty;
  if (spec.overallWidthM > spec.widthOverTracksM + 0.01) {
    final skirtZ = spec.overallWidthM / 2;
    final right = MeshPrimitives.box(
      corner: Vector3(-halfL * 0.92, tubTop - 0.10, skirtZ - 0.05),
      opposite: Vector3(halfL * 0.94, tubTop + 0.42, skirtZ),
      material: SurfaceMaterial.fender,
      partId: 'skirt',
    );
    skirts = right + right.mirroredZ();
  }

  // ---- Turret: the plan outline at the ring, drawn in at the roof, so every
  // face between them is sloped armour. ----
  final turretCenterX = -spec.hullLengthM * 0.02;
  final turretHalfL = spec.hullLengthM * 0.255;
  final turretHalfW = spec.widthOverTracksM * 0.385;
  final ringPlan = <({double x, double z})>[
    (x: turretHalfL, z: 0.0),
    (x: turretHalfL * 0.86, z: turretHalfW * 0.58),
    (x: turretHalfL * 0.36, z: turretHalfW),
    (x: -turretHalfL * 0.52, z: turretHalfW),
    (x: -turretHalfL * 0.92, z: turretHalfW * 0.72),
    (x: -turretHalfL, z: 0.0),
    (x: -turretHalfL * 0.92, z: -turretHalfW * 0.72),
    (x: -turretHalfL * 0.52, z: -turretHalfW),
    (x: turretHalfL * 0.36, z: -turretHalfW),
    (x: turretHalfL * 0.86, z: -turretHalfW * 0.58),
  ];
  final turretRoofY = spec.overallHeightM;
  final turretBottom = [
    for (final p in ringPlan) Vector3(turretCenterX + p.x, roof - 0.04, p.z),
  ];
  final turretTop = [
    for (final p in ringPlan)
      Vector3(turretCenterX + p.x * 0.74, turretRoofY, p.z * 0.60),
  ];
  var turret = MeshPrimitives.loft(
    turretBottom,
    turretTop,
    material: SurfaceMaterial.turret,
    partId: 'turret',
  );

  // Commander's cupola. Deliberately drawn as a raised hatch ring that stops
  // flush with the turret roof rather than a drum standing proud of it: the
  // vehicle's published height is measured to the turret roof, and the scene
  // reports the height of its own highest point as the load's height above
  // the rail. A cupola modelled above the roof line would quietly make that
  // readout disagree with the specification it claims to come from.
  final cupolaRing = [
    for (var k = 0; k < 10; k++)
      Vector3(
        turretCenterX - 0.15 + 0.42 * math.cos(2 * math.pi * k / 10),
        0,
        0.55 + 0.42 * math.sin(2 * math.pi * k / 10),
      ),
  ];
  turret += MeshPrimitives.loft(
    [for (final v in cupolaRing) Vector3(v.x, turretRoofY - 0.22, v.z)],
    [for (final v in cupolaRing) Vector3(v.x, turretRoofY, v.z)],
    material: SurfaceMaterial.stowage,
    partId: 'turret.cupola',
  );

  // ---- Main armament ----
  final mantletX = turretCenterX + turretHalfL;
  final gunAxisY = roof + (turretRoofY - roof) * 0.46;
  final muzzleX = halfL + spec.gunOverhangM;
  if (spec.gunOverhangM > 0) {
    turret += MeshPrimitives.boxAt(
      center: Vector3(mantletX - 0.15, gunAxisY, 0),
      size: const Vector3(0.55, 0.62, 1.05),
      material: SurfaceMaterial.turret,
      partId: 'turret.mantlet',
    );
    // Thermal sleeve, then the thinner section out to the muzzle.
    final sleeveEnd = mantletX + (muzzleX - mantletX) * 0.55;
    turret += MeshPrimitives.rod(
      a: Vector3(mantletX, gunAxisY, 0),
      b: Vector3(sleeveEnd, gunAxisY, 0),
      radius: spec.gunBarrelRadiusM,
      material: SurfaceMaterial.gunBarrel,
      segments: 10,
      partId: 'gun',
    );
    turret += MeshPrimitives.rod(
      a: Vector3(sleeveEnd, gunAxisY, 0),
      b: Vector3(muzzleX, gunAxisY, 0),
      radius: spec.gunBarrelRadiusM * 0.68,
      material: SurfaceMaterial.gunBarrel,
      segments: 10,
      partId: 'gun',
    );
  }

  // The turret traverses about its own ring, and the gun goes with it.
  final turretPivot = Vector3(turretCenterX, 0, 0);
  turret = turret.rotatedY(turretTraverse, about: turretPivot);
  final gunTip = Vector3(muzzleX, gunAxisY, 0);
  final gunReach = turretPivot.x + (gunTip.x - turretPivot.x) * math.cos(turretTraverse);

  // ---- Rear stowage ----
  // Cylindrical fuel drums slung on the rear plate, lying fore-and-aft. They
  // stand proud of the rear plate, so they — not the hull — are the rearmost
  // point of the vehicle. The scene measures overhang from the model's own
  // bounds for exactly this reason.
  final drums = <Mesh3>[];
  for (var i = 0; i < spec.rearFuelDrums; i++) {
    final z = (i.isEven ? 1 : -1) * 0.62;
    drums.add(MeshPrimitives.rod(
      a: Vector3(-halfL + 0.02, roof - 0.14, z),
      b: Vector3(-halfL - 0.72, roof - 0.14, z),
      radius: 0.26,
      material: SurfaceMaterial.stowage,
      segments: 10,
      partId: 'stowage.fuelDrum',
    ));
  }

  final mesh = Mesh3.merge([
    tub,
    upperHull,
    applique,
    runningGear,
    skirts,
    turret,
    ...drums,
  ]);

  // Towing eyes: two on the nose at the bottom of the glacis, two on the rear
  // plate, at the height a wire is actually shackled at.
  final eyeZ = tubHalfWidth * 0.78;
  final lashingEyes = <Vector3>[
    Vector3(halfL - 0.05, clearance + 0.16, eyeZ),
    Vector3(halfL - 0.05, clearance + 0.16, -eyeZ),
    Vector3(-halfL + 0.05, clearance + 0.16, eyeZ),
    Vector3(-halfL + 0.05, clearance + 0.16, -eyeZ),
  ];

  return VehicleModel3(
    mesh: mesh,
    spec: spec,
    lashingEyes: lashingEyes,
    trackContactX: (front: contactHalf, rear: -contactHalf),
    trackCenterZ: wheelZ,
    gunReachX: gunReach,
  );
}
