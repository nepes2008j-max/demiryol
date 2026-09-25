import 'dart:math' as math;

import '../models/scene3d.dart';
import '../models/securing_placement.dart';
import 'flatcar_mesh_builder.dart';
import 'securing_mesh_builder.dart';
import 'vehicle_mesh_builder.dart';

/// What the finished scene measures, once the vehicle is standing where the
/// trainee put it.
///
/// These are **measurements, not verdicts**. Nothing here says a load is legal
/// or illegal: the source handbook's extract carries no loading-gauge table
/// and no overhang limit, so asserting one would be inventing a rule. What the
/// view can honestly do is state the resulting figures — how high the load now
/// stands above the rail head, how far it reaches past the end of the deck —
/// and let the trainee take them to the rule that governs them.
class LoadingClearances {
  /// Height of the highest point of the load above the rail head: the deck
  /// height plus the vehicle's own height. The figure a loading gauge is
  /// judged against.
  final double loadTopAboveRailM;

  /// Height of the deck itself above the rail head.
  final double deckHeightM;

  /// How far the load reaches past the front end of the deck. Zero when it
  /// is within the deck.
  final double frontOverhangM;

  /// How far the load reaches past the rear end of the deck.
  final double rearOverhangM;

  /// How far the widest part of the load stands outside the edge of the deck,
  /// per side. Zero when the vehicle is narrower than the wagon.
  final double lateralOverhangM;

  /// Free deck ahead of and behind the load, added together — what is left
  /// for a second machine.
  final double freeDeckLengthM;

  /// Full width of the load, over its widest point.
  final double loadWidthM;

  const LoadingClearances({
    required this.loadTopAboveRailM,
    required this.deckHeightM,
    required this.frontOverhangM,
    required this.rearOverhangM,
    required this.lateralOverhangM,
    required this.freeDeckLengthM,
    required this.loadWidthM,
  });

  bool get overhangsDeck => frontOverhangM > 0.001 || rearOverhangM > 0.001;
  bool get overhangsSides => lateralOverhangM > 0.001;
}

/// One vehicle to put on the wagon.
///
/// A wagon can carry more than one — two tracked vehicles on a single flatcar
/// is a case the plates dimension, with 100 mm between them — so the scene
/// takes a list of these rather than a single vehicle. Each carries its own
/// position along the deck, its own turret angle and its own securing gear,
/// because each is secured separately.
class PlacedLoad {
  /// The placement this is, so the scene's output can be matched back to the
  /// consist and to the right securing layout.
  final String placementId;

  /// For the readouts and the report.
  final String designation;

  final VehicleMeshSpec spec;

  /// Where along the deck it stands: 0 hard against the rear end, 1 hard
  /// against the front.
  final double positionFraction;

  /// Radians, 0 forward and pi over the rear deck.
  final double turretTraverse;

  final SecuringLayout securing;

  /// A mesh loaded from a model file, already fitted, to draw instead of the
  /// built one.
  final Mesh3? meshOverride;

  const PlacedLoad({
    required this.placementId,
    required this.designation,
    required this.spec,
    this.positionFraction = 0.5,
    this.turretTraverse = 0.0,
    this.securing = SecuringLayout.empty,
    this.meshOverride,
  });
}

/// One vehicle as it ended up on the wagon.
class LoadOnWagon {
  final String placementId;
  final String designation;
  final VehicleModel3 vehicle;

  /// Where the vehicle's own origin sits along the wagon.
  final double vehicleOffsetX;

  /// Its extent as placed, including anything overhanging — a gun trained
  /// forward, the fuel drums on the rear plate.
  final Bounds3 bounds;

  final SecuringVisual securing;
  final SecuringLayout layout;

  const LoadOnWagon({
    required this.placementId,
    required this.designation,
    required this.vehicle,
    required this.vehicleOffsetX,
    required this.bounds,
    required this.securing,
    required this.layout,
  });
}

/// The space between two neighbouring loads on one wagon.
///
/// Measured between their **full** extents, not their hulls: a gun trained
/// over the vehicle behind is exactly what a clearance is there to prevent,
/// and a figure that ignored it would pass a load that fouls its neighbour.
class LoadGap {
  final String rearPlacementId;
  final String frontPlacementId;

  /// Metres between them along the deck. Negative when they overlap.
  final double gapM;

  const LoadGap({
    required this.rearPlacementId,
    required this.frontPlacementId,
    required this.gapM,
  });

  double get gapMm => gapM * 1000;

  /// True when the two loads are actually fouling one another.
  bool get overlaps => gapM < 0;
}

/// A wagon, the vehicles standing on it, the gear securing them, and the track
/// under all of it — one mesh, plus the figures that fall out of the
/// arrangement.
class LoadingScene3 {
  /// Everything, in world coordinates, ready to render.
  final Mesh3 mesh;

  /// The vehicle alone, as placed — for framing the camera on the load rather
  /// than on the whole train.
  final Bounds3 loadBounds;

  /// Every vehicle on the wagon, in the order they stand along it.
  final List<LoadOnWagon> loads;

  /// The space between each neighbouring pair — one fewer than there are
  /// loads, and empty for a wagon carrying one.
  final List<LoadGap> gaps;

  /// The load the caller listed first — the one being worked on.
  ///
  /// Explicitly *not* the first of [loads], which is sorted along the wagon:
  /// with a second vehicle standing behind the one being edited, the sorted
  /// first is the other machine, and every measurement taken against it came
  /// out against the wrong vehicle. A block seated 12.5 cm from its own
  /// running gear was reported at 1555 cm.
  final LoadOnWagon primary;

  /// The vehicle being worked on. Kept because most of this application still
  /// works one vehicle at a time.
  final VehicleModel3 vehicle;
  final FlatcarModel3 flatcar;
  final SecuringVisual securing;

  /// The gear alone, for picking: a ray cast against this comes back with the
  /// id of the piece the pointer is over and nothing else, so a block behind
  /// the tank is still selectable.
  final Mesh3 securingMesh;

  /// What the trainee is holding, laid out where they put it.
  final SecuringLayout layout;
  final LoadingClearances clearances;

  /// How far along the deck the vehicle's own centre sits, from the middle of
  /// the wagon. Kept so a caller can show the same number it set.
  final double vehicleOffsetX;

  const LoadingScene3({
    required this.mesh,
    required this.loadBounds,
    required this.vehicle,
    required this.flatcar,
    required this.loads,
    required this.gaps,
    required this.primary,
    required this.securing,
    required this.securingMesh,
    required this.layout,
    required this.clearances,
    required this.vehicleOffsetX,
  });
}

/// The wagon, the vehicle and where along the deck it stands — everything the
/// caller needs to place gear against, without building the scene's mesh.
///
/// Split out because the view needs these on every frame of a drag (to snap a
/// block against the running gear and to measure how it sits) while the mesh
/// only needs rebuilding when something actually moves. Resolving the two
/// together, as this file used to, meant building several thousand faces to
/// answer where one track ends.
class LoadingGeometry {
  final VehicleModel3 vehicle;
  final FlatcarModel3 flatcar;

  /// Where the vehicle's own origin sits along the wagon.
  final double vehicleOffsetX;

  const LoadingGeometry({
    required this.vehicle,
    required this.flatcar,
    required this.vehicleOffsetX,
  });
}

/// Works out where the vehicle stands on the wagon for a given position.
///
/// [positionFraction] slides it along the deck: `0.0` hard against the rear
/// end, `0.5` centred, `1.0` hard against the front. The travel is measured on
/// the **hull**, so a gun trained over the end of the wagon is allowed to
/// reach past the deck and be reported as overhang rather than silently
/// prevented.
LoadingGeometry resolveLoadingGeometry({
  required VehicleMeshSpec vehicleSpec,
  required FlatcarMeshSpec flatcarSpec,
  double positionFraction = 0.5,
  double turretTraverse = 0.0,
}) {
  final vehicle = buildVehicleModel(vehicleSpec, turretTraverse: turretTraverse);
  final flatcar = buildFlatcarModel(flatcarSpec);
  final travel = flatcarSpec.deckLengthM - vehicleSpec.hullLengthM;
  final t = positionFraction.clamp(0.0, 1.0);
  final offsetX = travel <= 0
      // A hull longer than the deck sits centred and is reported as
      // overhanging at both ends; there is nowhere else to put it.
      ? 0.0
      : flatcar.deckX.rear + vehicleSpec.halfLength + travel * t;
  return LoadingGeometry(
    vehicle: vehicle,
    flatcar: flatcar,
    vehicleOffsetX: offsetX,
  );
}

/// Assembles a wagon carrying one vehicle. A convenience over
/// [buildLoadedWagonScene] for the many callers that only ever have one; see
/// [resolveLoadingGeometry] for how the position is applied.
///
/// [turretTraverse] is in radians, `0` forward and `pi` over the rear deck.
LoadingScene3 buildLoadingScene({
  required VehicleMeshSpec vehicleSpec,
  required FlatcarMeshSpec flatcarSpec,
  double positionFraction = 0.5,
  double turretTraverse = 0.0,
  SecuringLayout securing = SecuringLayout.empty,
  String? selectedPieceId,
  bool showRunningGearGuides = false,
  bool includeTrackBed = true,
  bool includeVehicle = true,
  Mesh3? vehicleMeshOverride,
}) =>
    buildLoadedWagonScene(
      loads: [
        PlacedLoad(
          placementId: 'placement-0',
          designation: '',
          spec: vehicleSpec,
          positionFraction: positionFraction,
          turretTraverse: turretTraverse,
          securing: securing,
          meshOverride: vehicleMeshOverride,
        ),
      ],
      flatcarSpec: flatcarSpec,
      selectedPieceId: selectedPieceId,
      showRunningGearGuides: showRunningGearGuides,
      includeTrackBed: includeTrackBed,
      includeVehicles: includeVehicle,
    );

/// Assembles the loaded wagon, with however many vehicles are standing on it.
///
/// Two tracked vehicles on one flatcar is a case the plates dimension — 100 mm
/// between them — and the scene could not show it at all while it took a
/// single vehicle: the second machine on a wagon was simply not drawn, so
/// neither the trainee nor the report could see whether the pair fitted.
///
/// Each load carries its own position, turret angle and securing gear, because
/// each is secured separately. The gaps between neighbours come back measured;
/// what the plates require of them is `clearanceBetween` in
/// `wagon_capacity.dart`, which the caller pairs with these.
LoadingScene3 buildLoadedWagonScene({
  required List<PlacedLoad> loads,
  required FlatcarMeshSpec flatcarSpec,
  String? selectedPieceId,
  bool showRunningGearGuides = false,
  bool includeTrackBed = true,
  bool includeVehicles = true,
}) {
  assert(loads.isNotEmpty, 'a scene needs at least one vehicle');
  final flatcar = buildFlatcarModel(flatcarSpec);
  if (loads.isEmpty) {
    // Asserts are compiled out of a release build, and an empty wagon must
    // draw an empty wagon rather than throw on `first`.
    return LoadingScene3(
      mesh: flatcar.mesh,
      loadBounds: const Bounds3(Vector3.zero, Vector3.zero),
      loads: const [],
      gaps: const [],
      primary: LoadOnWagon(
        placementId: '',
        designation: '',
        vehicle: buildTrackedVehicleModel(TrackedVehicleMeshSpec.t72),
        vehicleOffsetX: 0,
        bounds: const Bounds3(Vector3.zero, Vector3.zero),
        securing: SecuringVisual.none,
        layout: SecuringLayout.empty,
      ),
      vehicle: buildTrackedVehicleModel(TrackedVehicleMeshSpec.t72),
      flatcar: flatcar,
      securing: SecuringVisual.none,
      securingMesh: Mesh3.empty,
      layout: SecuringLayout.empty,
      clearances: LoadingClearances(
        loadTopAboveRailM: flatcar.deckTopY,
        deckHeightM: flatcar.deckTopY,
        frontOverhangM: 0,
        rearOverhangM: 0,
        lateralOverhangM: 0,
        freeDeckLengthM: flatcarSpec.deckLengthM,
        loadWidthM: 0,
      ),
      vehicleOffsetX: 0,
    );
  }

  final placed = <LoadOnWagon>[];
  final meshes = <Mesh3>[];
  for (final load in loads) {
    final geometry = resolveLoadingGeometry(
      vehicleSpec: load.spec,
      flatcarSpec: flatcarSpec,
      positionFraction: load.positionFraction,
      turretTraverse: load.turretTraverse,
    );
    final vehicle = load.meshOverride == null
        ? geometry.vehicle
        : geometry.vehicle.withMesh(load.meshOverride!);
    final offsetX = geometry.vehicleOffsetX;
    final placedMesh =
        vehicle.mesh.translated(Vector3(offsetX, flatcar.deckTopY, 0));

    final securingVisual = buildSecuringVisual(
      vehicle: vehicle,
      flatcar: flatcar,
      vehicleOffsetX: offsetX,
      layout: load.securing,
      selectedPieceId: selectedPieceId,
      showRunningGearGuides: showRunningGearGuides,
      placementId: load.placementId,
    );

    placed.add(LoadOnWagon(
      placementId: load.placementId,
      designation: load.designation,
      vehicle: vehicle,
      vehicleOffsetX: offsetX,
      bounds: placedMesh.bounds,
      securing: securingVisual,
      layout: load.securing,
    ));
    if (includeVehicles) meshes.add(placedMesh);
    meshes.add(securingVisual.mesh);
  }

  // The one being worked on is the one the caller listed first, and it has to
  // be held on to *before* the sort below reorders everything.
  final primary = placed.first;

  // In the order they stand along the wagon, so the gaps are between actual
  // neighbours rather than between whichever two the caller listed first.
  placed.sort((a, b) => a.bounds.min.x.compareTo(b.bounds.min.x));
  final gaps = <LoadGap>[
    for (var i = 0; i + 1 < placed.length; i++)
      LoadGap(
        rearPlacementId: placed[i].placementId,
        frontPlacementId: placed[i + 1].placementId,
        gapM: placed[i + 1].bounds.min.x - placed[i].bounds.max.x,
      ),
  ];

  final trackBed = includeTrackBed
      ? buildTrackBedMesh(
          lengthM: flatcarSpec.deckLengthM * 1.55,
          railGaugeM: flatcarSpec.railGaugeM,
        )
      : Mesh3.empty;

  // The load as a whole: every vehicle on the wagon taken together, which is
  // what overhang and loading gauge are about.
  var loadBounds = placed.first.bounds;
  for (final load in placed.skip(1)) {
    loadBounds = loadBounds.union(load.bounds);
  }

  // The deck each load covers, unioned rather than summed: two vehicles
  // standing on the same spot are a mistake the trainee should see reported
  // as a fouled gap, not as twice the deck consumed.
  final covered = <({double from, double to})>[];
  for (final load in placed) {
    final from = math.max(load.bounds.min.x, flatcar.deckX.rear);
    final to = math.min(load.bounds.max.x, flatcar.deckX.front);
    if (to <= from) continue;
    if (covered.isNotEmpty && from <= covered.last.to) {
      covered[covered.length - 1] =
          (from: covered.last.from, to: math.max(covered.last.to, to));
    } else {
      covered.add((from: from, to: to));
    }
  }
  final usedLength =
      covered.fold<double>(0, (sum, span) => sum + (span.to - span.from));

  final clearances = LoadingClearances(
    loadTopAboveRailM: loadBounds.max.y,
    deckHeightM: flatcar.deckTopY,
    frontOverhangM: math.max(0, loadBounds.max.x - flatcar.deckX.front),
    rearOverhangM: math.max(0, flatcar.deckX.rear - loadBounds.min.x),
    lateralOverhangM: math.max(
      0,
      math.max(loadBounds.max.z, -loadBounds.min.z) - flatcarSpec.deckWidthM / 2,
    ),
    freeDeckLengthM: math.max(0, flatcarSpec.deckLengthM - usedLength),
    loadWidthM: loadBounds.size.z,
  );

  final securingMesh = Mesh3.merge([for (final load in placed) load.securing.mesh]);

  return LoadingScene3(
    mesh: Mesh3.merge([trackBed, flatcar.mesh, ...meshes]),
    loadBounds: loadBounds,
    loads: placed,
    gaps: gaps,
    primary: primary,
    vehicle: primary.vehicle,
    flatcar: flatcar,
    securing: SecuringVisual(
      mesh: securingMesh,
      blockCount:
          placed.fold(0, (n, load) => n + load.securing.blockCount),
      lashingRunCount:
          placed.fold(0, (n, load) => n + load.securing.lashingRunCount),
    ),
    securingMesh: securingMesh,
    layout: primary.layout,
    clearances: clearances,
    vehicleOffsetX: primary.vehicleOffsetX,
  );
}
