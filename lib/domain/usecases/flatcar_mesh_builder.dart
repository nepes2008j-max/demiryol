import 'dart:math' as math;

import '../models/scene3d.dart';
import 'mesh_primitives.dart';

/// The dimensions of the open flatcar the load stands on.
///
/// The source handbook's `platforms.json` records `lengthCm`, `widthCm` and
/// `deckHeightCm` as unavailable for every wagon in the extract, so this
/// class carries a documented default — the four-axle open flatcar the
/// project's own design mockup depicts — and [fromPlatformFigures] overrides
/// each field the platform record *does* supply. That way the wagon is drawn
/// from handbook figures the moment they exist, and until then the view says
/// plainly that the wagon is the standard four-axle car and not a measured
/// one.
class FlatcarMeshSpec {
  /// Length of the load surface.
  final double deckLengthM;

  /// Width of the load surface.
  final double deckWidthM;

  /// Height of the load surface above the rail head — the figure that decides
  /// how much of the loading gauge the vehicle has left.
  final double deckHeightM;

  /// Thickness of the timber decking.
  final double deckThicknessM;

  /// Distance between the two bogie centres.
  final double bogieCentresM;

  /// Axle spacing within one bogie.
  final double bogieWheelBaseM;

  final double wheelRadiusM;

  /// Track gauge, rail centre to rail centre. 1.520 m on the network the
  /// handbook is written for.
  final double railGaugeM;

  /// Height of the side boards, drawn folded down for loading.
  final double sideBoardHeightM;

  /// Lashing rings along each side of the deck.
  final int tieDownRingsPerSide;

  const FlatcarMeshSpec({
    this.deckLengthM = 13.30,
    this.deckWidthM = 2.87,
    this.deckHeightM = 1.31,
    this.deckThicknessM = 0.11,
    this.bogieCentresM = 9.72,
    this.bogieWheelBaseM = 1.85,
    this.wheelRadiusM = 0.475,
    this.railGaugeM = 1.520,
    this.sideBoardHeightM = 0.42,
    this.tieDownRingsPerSide = 6,
  });

  /// The standard four-axle open flatcar, as drawn in the project's design
  /// mockup. Not a handbook figure — see the class doc.
  static const FlatcarMeshSpec standardFourAxle = FlatcarMeshSpec();

  /// The same wagon, with any figure the platform record actually states
  /// substituted in. Pass the platform's centimetre values; nulls keep the
  /// default. Doing the unit conversion here, once, is deliberate: nothing
  /// downstream of this point handles a length whose unit is in doubt.
  factory FlatcarMeshSpec.fromPlatformFigures({
    double? lengthCm,
    double? widthCm,
    double? deckHeightCm,
    int? tieDownRings,
  }) {
    const base = FlatcarMeshSpec.standardFourAxle;
    return FlatcarMeshSpec(
      deckLengthM: lengthCm != null ? lengthCm / 100 : base.deckLengthM,
      deckWidthM: widthCm != null ? widthCm / 100 : base.deckWidthM,
      deckHeightM: deckHeightCm != null ? deckHeightCm / 100 : base.deckHeightM,
      deckThicknessM: base.deckThicknessM,
      // The running gear is proportioned to the deck so a wagon given a real
      // length does not end up with its bogies under the middle of nowhere.
      bogieCentresM: (lengthCm != null ? lengthCm / 100 : base.deckLengthM) * 0.73,
      bogieWheelBaseM: base.bogieWheelBaseM,
      wheelRadiusM: base.wheelRadiusM,
      railGaugeM: base.railGaugeM,
      sideBoardHeightM: base.sideBoardHeightM,
      tieDownRingsPerSide:
          tieDownRings != null && tieDownRings > 1 ? (tieDownRings / 2).ceil() : base.tieDownRingsPerSide,
    );
  }

  /// True when every figure came from the default rather than from a platform
  /// record — which is the case the caption has to disclose.
  bool get isDefaultGeometry =>
      deckLengthM == standardFourAxle.deckLengthM &&
      deckWidthM == standardFourAxle.deckWidthM &&
      deckHeightM == standardFourAxle.deckHeightM;

  double get halfLength => deckLengthM / 2;

  /// Top of the load surface above the rail head. Everything that stands on
  /// the wagon is translated up by this.
  double get deckTopY => deckHeightM;
}

/// The built wagon, with the points the load and its securing gear attach to.
class FlatcarModel3 {
  final Mesh3 mesh;
  final FlatcarMeshSpec spec;

  /// Height of the load surface — what a vehicle is lifted by to stand on it.
  final double deckTopY;

  /// The `x` range of the load surface. A vehicle is in bounds when its own
  /// bounds lie inside this; anything outside it is overhang.
  final ({double rear, double front}) deckX;

  /// Every lashing ring on the deck, in world coordinates.
  final List<Vector3> tieDownRings;

  const FlatcarModel3({
    required this.mesh,
    required this.spec,
    required this.deckTopY,
    required this.deckX,
    required this.tieDownRings,
  });

  /// The ring nearest a given point — how a wire finds the ring it is
  /// actually made fast to instead of one chosen by index.
  Vector3 nearestRing(Vector3 to) {
    var best = tieDownRings.first;
    var bestD = double.infinity;
    for (final ring in tieDownRings) {
      final d = (ring - to).length;
      if (d < bestD) {
        bestD = d;
        best = ring;
      }
    }
    return best;
  }
}

/// Splits a long box into [segments] shorter ones along the wagon's length.
///
/// The renderer sorts faces by the distance from the eye to the face centre,
/// which is exact for small faces and wrong for long ones: a 13-metre deck
/// plank has its centre over the middle of the wagon, so a bogie standing at
/// the near end — genuinely closer to the eye than that centre — sorted in
/// front of the deck and was drawn straight over it. Cutting the long pieces
/// into segments puts each face's centre near the part of the wagon it
/// actually covers, and the order comes out right. It is the standard price
/// of a painter's-algorithm renderer, paid where it is needed rather than
/// everywhere.
Mesh3 _segmentedBox({
  required Vector3 corner,
  required Vector3 opposite,
  required SurfaceMaterial material,
  required int segments,
  String? partId,
}) {
  final x0 = math.min(corner.x, opposite.x);
  final x1 = math.max(corner.x, opposite.x);
  final step = (x1 - x0) / segments;
  return Mesh3.merge([
    for (var i = 0; i < segments; i++)
      MeshPrimitives.box(
        corner: Vector3(x0 + step * i, corner.y, corner.z),
        opposite: Vector3(x0 + step * (i + 1), opposite.y, opposite.z),
        material: material,
        partId: partId,
      ),
  ]);
}

/// Builds the flatcar: timber deck, steel underframe, folded side boards,
/// two four-wheel bogies, couplers, and the deck rings.
FlatcarModel3 buildFlatcarModel(FlatcarMeshSpec spec) {
  final halfL = spec.halfLength;
  final halfW = spec.deckWidthM / 2;
  final deckTop = spec.deckTopY;
  final deckBottom = deckTop - spec.deckThicknessM;

  // ---- Timber deck, laid as individual planks so the surface has a grain
  // and the eye can read a length along it. ----
  // The planks butt against one another. An actual modelled gap would look
  // straight through the wagon — there is no continuous floor under the
  // planking, only two sills and a centre girder — and a full-width plate to
  // close it competes with the far planks in the depth sort and prints over
  // them. The line between planks is the painter's edge stroke instead.
  const plankGap = 0.0;
  final plankCount = math.max(6, (spec.deckWidthM / 0.34).round());
  final plankWidth = spec.deckWidthM / plankCount;
  // Twelve segments along the wagon. Each face's centre then lies within
  // half a metre of the part of the deck it covers, which is what keeps the
  // running gear underneath from sorting in front of it.
  const deckSegments = 12;
  final planks = <Mesh3>[
    for (var i = 0; i < plankCount; i++)
      _segmentedBox(
        corner: Vector3(-halfL, deckBottom, -halfW + i * plankWidth + plankGap / 2),
        opposite:
            Vector3(halfL, deckTop, -halfW + (i + 1) * plankWidth - plankGap / 2),
        material: SurfaceMaterial.deckPlank,
        segments: deckSegments,
        partId: 'wagon.deck',
      ),
  ];

  // ---- Underframe: two side sills, a centre sill, and a headstock at each
  // end. ----
  const sillDepth = 0.34;
  // The planking really does rest on the sills, but the model leaves 20 mm
  // between them. Flush, the sill's top face and the plank's underside are
  // coplanar, and two coplanar surfaces have no stable draw order — the pair
  // flickered against each other along the whole length of the wagon. The gap
  // is under the deck and invisible.
  final sillTop = deckBottom - 0.02;
  final sillBottom = deckBottom - sillDepth;
  final rightSill = _segmentedBox(
    corner: Vector3(-halfL, sillBottom, halfW - 0.10),
    opposite: Vector3(halfL, sillTop, halfW),
    material: SurfaceMaterial.wagonFrame,
    segments: 8,
    partId: 'wagon.sill',
  );
  final frame = <Mesh3>[
    rightSill,
    rightSill.mirroredZ(),
    _segmentedBox(
      corner: Vector3(-halfL, sillBottom - 0.06, -0.28),
      opposite: Vector3(halfL, sillTop - 0.12, 0.28),
      material: SurfaceMaterial.wagonFrame,
      segments: 8,
      partId: 'wagon.centreSill',
    ),
    for (final sign in const [1, -1])
      MeshPrimitives.box(
        corner: Vector3(sign * (halfL - 0.16), sillBottom, -halfW),
        opposite: Vector3(sign * halfL, sillTop, halfW),
        material: SurfaceMaterial.wagonFrame,
        partId: 'wagon.headstock',
      ),
  ];

  // ---- Side boards, folded down against the sills for loading, and the
  // stanchion pockets they hinge in. ----
  final boards = <Mesh3>[];
  final rightBoard = _segmentedBox(
    corner: Vector3(-halfL + 0.20, sillBottom - spec.sideBoardHeightM, halfW),
    opposite: Vector3(halfL - 0.20, sillTop - 0.02, halfW + 0.06),
    material: SurfaceMaterial.deckEdge,
    segments: 8,
    partId: 'wagon.sideBoard',
  );
  boards.addAll([rightBoard, rightBoard.mirroredZ()]);
  for (var i = 0; i < 8; i++) {
    final x = -halfL + 0.9 + i * (spec.deckLengthM - 1.8) / 7;
    final pocket = MeshPrimitives.box(
      corner: Vector3(x - 0.09, sillTop - 0.22, halfW - 0.02),
      opposite: Vector3(x + 0.09, deckTop + 0.05, halfW + 0.07),
      material: SurfaceMaterial.deckEdge,
      partId: 'wagon.stanchionPocket',
    );
    boards.addAll([pocket, pocket.mirroredZ()]);
  }

  // ---- Bogies ----
  final bogies = <Mesh3>[];
  final wheelZ = spec.railGaugeM / 2;
  final wheelY = spec.wheelRadiusM;
  for (final sign in const [1, -1]) {
    final bx = sign * spec.bogieCentresM / 2;
    // Segmented like the deck above it: as one 2.5 m box its end face sorted
    // in front of the deck and printed a black bar across the planking.
    bogies.add(_segmentedBox(
      corner: Vector3(bx - spec.bogieWheelBaseM / 2 - 0.35, wheelY - 0.12, -wheelZ - 0.16),
      opposite: Vector3(bx + spec.bogieWheelBaseM / 2 + 0.35, sillBottom - 0.04, wheelZ + 0.16),
      material: SurfaceMaterial.bogie,
      segments: 4,
      partId: 'wagon.bogie',
    ));
    for (final axleSign in const [1, -1]) {
      final ax = bx + axleSign * spec.bogieWheelBaseM / 2;
      bogies.add(MeshPrimitives.rod(
        a: Vector3(ax, wheelY, -wheelZ),
        b: Vector3(ax, wheelY, wheelZ),
        radius: 0.075,
        material: SurfaceMaterial.bogie,
        segments: 8,
        partId: 'wagon.axle',
      ));
      for (final z in [wheelZ, -wheelZ]) {
        bogies.add(MeshPrimitives.cylinderZ(
          center: Vector3(ax, wheelY, z + (z > 0 ? 0.035 : -0.035)),
          radius: spec.wheelRadiusM,
          length: 0.14,
          material: SurfaceMaterial.wagonWheel,
          segments: 16,
          partId: 'wagon.wheel',
        ));
      }
    }
  }

  // ---- Couplers ----
  final couplers = <Mesh3>[
    for (final sign in const [1, -1]) ...[
      MeshPrimitives.boxAt(
        center: Vector3(sign * (halfL + 0.28), sillTop - 0.18, 0),
        size: const Vector3(0.56, 0.20, 0.22),
        material: SurfaceMaterial.wagonFrame,
        partId: 'wagon.coupler',
      ),
      MeshPrimitives.boxAt(
        center: Vector3(sign * (halfL + 0.55), sillTop - 0.18, 0),
        size: const Vector3(0.30, 0.34, 0.34),
        material: SurfaceMaterial.wagonFrame,
        partId: 'wagon.coupler',
      ),
    ],
  ];

  // ---- Deck rings ----
  final rings = <Vector3>[];
  final ringMeshes = <Mesh3>[];
  final n = math.max(2, spec.tieDownRingsPerSide);
  for (var i = 0; i < n; i++) {
    final x = -halfL + 0.7 + i * (spec.deckLengthM - 1.4) / (n - 1);
    for (final z in [halfW - 0.13, -(halfW - 0.13)]) {
      final at = Vector3(x, deckTop, z);
      rings.add(at);
      ringMeshes.add(MeshPrimitives.ringZUp(
        center: Vector3(x, deckTop + 0.05, z),
        radius: 0.09,
        barRadius: 0.018,
        material: SurfaceMaterial.tieDownRing,
        // Six coarse segments: at any zoom this trainer is used at, a deck
        // ring is a few pixels across, and a smoother one would cost more
        // faces than the whole gun barrel.
        segments: 6,
        partId: 'wagon.ring',
      ));
    }
  }

  return FlatcarModel3(
    mesh: Mesh3.merge([...planks, ...frame, ...boards, ...bogies, ...couplers, ...ringMeshes]),
    spec: spec,
    deckTopY: deckTop,
    deckX: (rear: -halfL, front: halfL),
    tieDownRings: rings,
  );
}

/// The permanent way under the wagon: two rails on sleepers over ballast.
///
/// Drawn because a wagon floating in space gives the eye nothing to judge
/// deck height against, and deck height is what decides the remaining loading
/// gauge over the load.
Mesh3 buildTrackBedMesh({
  required double lengthM,
  double railGaugeM = 1.520,
  double railHeadWidthM = 0.072,
}) {
  final halfL = lengthM / 2;
  final parts = <Mesh3>[];

  // Ballast, with the shoulder it actually has: wide at the bottom, drawn in
  // at the top. Its top stops a centimetre below the sleepers rather than
  // level with them — two coplanar surfaces have no stable draw order, and
  // the pair of them flickered against each other along the whole train.
  const ballastSegments = 10;
  for (var i = 0; i < ballastSegments; i++) {
    final a = -halfL + (lengthM / ballastSegments) * i;
    final b = a + lengthM / ballastSegments;
    parts.add(MeshPrimitives.loft(
      [
        Vector3(a, -0.62, -2.45),
        Vector3(b, -0.62, -2.45),
        Vector3(b, -0.62, 2.45),
        Vector3(a, -0.62, 2.45),
      ],
      [
        Vector3(a, -0.21, -1.85),
        Vector3(b, -0.21, -1.85),
        Vector3(b, -0.21, 1.85),
        Vector3(a, -0.21, 1.85),
      ],
      material: SurfaceMaterial.ballast,
      partId: 'track.ballast',
    ));
  }

  // Sleepers at 0.55 m centres.
  const sleeperPitch = 0.62;
  final sleeperCount = (lengthM / sleeperPitch).floor();
  for (var i = 0; i <= sleeperCount; i++) {
    final x = -halfL + i * sleeperPitch;
    parts.add(MeshPrimitives.box(
      corner: Vector3(x - 0.11, -0.20, -1.35),
      opposite: Vector3(x + 0.11, -0.04, 1.35),
      material: SurfaceMaterial.sleeper,
      partId: 'track.sleeper',
    ));
  }

  // Rails. The rail head is y = 0 — the datum every height in the scene is
  // measured from, including the wagon's deck height and the loading gauge.
  const railSegments = 10;
  for (final z in [railGaugeM / 2, -railGaugeM / 2]) {
    for (var i = 0; i < railSegments; i++) {
      final a = -halfL + (lengthM / railSegments) * i;
      final b = a + lengthM / railSegments;
      parts.add(MeshPrimitives.extrudeZ(
        [p2(a, -0.04), p2(b, -0.04), p2(b, 0.0), p2(a, 0.0)],
        zMin: z - railHeadWidthM / 2,
        zMax: z + railHeadWidthM / 2,
        material: SurfaceMaterial.railHead,
        partId: 'track.rail',
      ));
    }
  }

  return Mesh3.merge(parts);
}
