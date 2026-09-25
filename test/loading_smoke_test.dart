import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/data/repositories/handbook_repository.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/engineering_validator.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/domain/usecases/scene3d_picking.dart';
import 'package:railsim/domain/usecases/securing_layout_builder.dart';
import 'package:railsim/domain/usecases/securing_measurements.dart';
import 'package:railsim/domain/usecases/securing_snap.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_catalog.dart';

/// Runs the engine and the scene over every combination the app can reach and
/// asserts only that nothing throws and nothing comes out non-finite.
///
/// A coverage net rather than a statement about correctness: the arithmetic is
/// pinned down by the tests beside this one. What this catches is the class
/// that hides in combinations — a wagon shorter than its load, a camera almost
/// level with the rail head, a piece dragged far off the deck — where each
/// input is reasonable and the pair of them is not.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('every vehicle against every platform', () async {
    final repo = HandbookRepository();
    final validator = EngineeringValidator(repo);
    final vehicles = await repo.getVehicles();
    final platforms = await repo.getPlatforms();
    var evaluations = 0;
    for (final v in vehicles) {
      for (final p in platforms) {
        for (final method in <int?>[null, 1, 2, 3, 4, 5, 6]) {
          await validator.evaluate(
              vehicle: v, platform: p, appliedSecuringMethod: method);
          evaluations++;
        }
      }
    }
    // Every vehicle, every wagon, every securing method, and the null case.
    expect(evaluations,
        vehicles.length * platforms.length * 7);
  });

  test('the 3D scene across positions, traverses and wagon sizes', () async {
    final repo = HandbookRepository();
    final vehicles = await repo.getVehicles();
    var scenes = 0;
    var picks = 0;
    for (final v in vehicles) {
      final spec = VehicleMeshCatalog.specFor(v);
      if (spec == null) continue;
      for (final deck in const [
        (l: 1330.0, w: 287.0, h: 131.0),
        (l: 600.0, w: 200.0, h: 100.0),   // a wagon shorter than the tank
        (l: 2000.0, w: 400.0, h: 160.0),
      ]) {
        final flatcar = FlatcarMeshSpec.fromPlatformFigures(
            lengthCm: deck.l, widthCm: deck.w, deckHeightCm: deck.h);
        for (final pos in const [0.0, 0.5, 1.0]) {
          for (final traverse in const [0.0, 1.57, 3.14159]) {
            final g = resolveLoadingGeometry(
                vehicleSpec: spec,
                flatcarSpec: flatcar,
                positionFraction: pos,
                turretTraverse: traverse);
            final layout = SecuringLayoutBuilder.handbookArrangement(
              vehicle: g.vehicle,
              flatcar: g.flatcar,
              vehicleOffsetX: g.vehicleOffsetX,
              chockHeightM: 0.18,
              chockWidthM: 0.20,
              insertHeightM: 0.095,
              insertLengthM: 0.35,
            );
            measureBlockSeating(
                layout: layout,
                vehicle: g.vehicle,
                vehicleOffsetX: g.vehicleOffsetX);
            for (final piece in layout.blocks) {
              for (final z in const [-9.0, 0.0, 9.0]) {
                SecuringSnap.forBlock(
                  piece: piece,
                  x: z * 2,
                  z: z,
                  vehicle: g.vehicle,
                  flatcarSpec: flatcar,
                  vehicleOffsetX: g.vehicleOffsetX,
                  seatingDistanceM: 0.125,
                  enabled: z != 0,
                );
              }
            }
            final scene = buildLoadingScene(
              vehicleSpec: spec,
              flatcarSpec: flatcar,
              positionFraction: pos,
              turretTraverse: traverse,
              securing: layout,
              selectedPieceId: layout.pieces.first.id,
              showRunningGearGuides: true,
            );
            scenes++;
            for (final yaw in const [0.0, 1.2, 3.0, -1.4]) {
              for (final pitch in const [-0.05, 0.4, 1.3]) {
                final base = Camera3.framing(
                    scene.flatcar.mesh.bounds.union(scene.loadBounds),
                    yaw: yaw,
                    pitch: pitch,
                    aspectRatio: 2.35);
                for (final zoom in const [0.45, 1.0, 4.0]) {
                  final cam = base.copyWith(distance: base.distance / zoom);
                  final faces = SceneProjection.render(scene.mesh,
                      camera: cam, width: 900, height: 383);
                  for (final f in faces) {
                    for (final pt in f.points) {
                      if (!pt.x.isFinite || !pt.y.isFinite) {
                        fail('non-finite projected point');
                      }
                    }
                  }
                  for (var px = 30.0; px < 900; px += 210) {
                    for (var py = 30.0; py < 383; py += 110) {
                      ScenePicking.pickNear(scene.securingMesh, cam,
                          width: 900, height: 383, px: px, py: py);
                      ScenePicking.planeY(
                          ScenePicking.through(
                              camera: cam,
                              width: 900,
                              height: 383,
                              px: px,
                              py: py),
                          scene.flatcar.deckTopY);
                      picks++;
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    // Every modellable vehicle over three wagons, three positions and three
    // turret angles, seen from thirty-six cameras apiece. Written as the
    // product rather than a constant so adding a vehicle widens the net
    // instead of failing here.
    final modellable = vehicles.where(VehicleMeshCatalog.canModel).length;
    expect(modellable, greaterThanOrEqualTo(2));
    expect(scenes, modellable * 3 * 3 * 3);
    expect(picks, greaterThan(10000));
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('an empty layout and a wagon with no gear survive everything', () {
    const flatcar = FlatcarMeshSpec.standardFourAxle;
    final scene = buildLoadingScene(
      vehicleSpec: TrackedVehicleMeshSpec.t90s,
      flatcarSpec: flatcar,
      securing: SecuringLayout.empty,
    );
    final cam = Camera3.framing(scene.mesh.bounds, aspectRatio: 2.0);
    expect(
        SceneProjection.render(scene.mesh, camera: cam, width: 400, height: 200),
        isNotEmpty);
    expect(
        ScenePicking.pickNear(scene.securingMesh, cam,
            width: 400, height: 200, px: 200, py: 100),
        isNull);
  });

  test('two vehicles on one wagon, over every angle and position', () async {
    final repo = HandbookRepository();
    final vehicles = await repo.getVehicles();
    final specs = vehicles
        .map(VehicleMeshCatalog.specFor)
        .whereType<TrackedVehicleMeshSpec>()
        .toList();
    expect(specs.length, greaterThanOrEqualTo(2));

    var scenes = 0;
    for (final deck in const [
      (l: 1330.0, w: 287.0),
      (l: 2400.0, w: 320.0),
      (l: 600.0, w: 200.0), // shorter than either machine
    ]) {
      final flatcar = FlatcarMeshSpec.fromPlatformFigures(
          lengthCm: deck.l, widthCm: deck.w, deckHeightCm: 131);
      for (final a in const [0.0, 0.5, 1.0]) {
        for (final b in const [0.0, 0.5, 1.0]) {
          for (final traverse in const [0.0, 3.14159]) {
            final scene = buildLoadedWagonScene(
              loads: [
                PlacedLoad(
                    placementId: 'a',
                    designation: 'a',
                    spec: specs.first,
                    positionFraction: a,
                    turretTraverse: traverse),
                PlacedLoad(
                    placementId: 'b',
                    designation: 'b',
                    spec: specs.last,
                    positionFraction: b),
              ],
              flatcarSpec: flatcar,
            );
            scenes++;
            expect(scene.loads, hasLength(2));
            expect(scene.gaps, hasLength(1));
            // The one being worked on is always the one listed first.
            expect(scene.primary.placementId, 'a');
            expect(scene.vehicleOffsetX, scene.primary.vehicleOffsetX);
            // Nothing non-finite, and no piece id shared between the two.
            expect(scene.gaps.single.gapM.isFinite, isTrue);
            expect(scene.clearances.freeDeckLengthM,
                lessThanOrEqualTo(flatcar.deckLengthM + 1e-9));
            expect(scene.clearances.freeDeckLengthM, greaterThanOrEqualTo(0));
            final cam = Camera3.framing(scene.mesh.bounds, aspectRatio: 2.4);
            for (final f in SceneProjection.render(scene.mesh,
                camera: cam, width: 600, height: 250)) {
              for (final p in f.points) {
                expect(p.x.isFinite && p.y.isFinite, isTrue);
              }
            }
          }
        }
      }
    }
    expect(scenes, 3 * 3 * 3 * 2);
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('an empty wagon is a programming error, caught loudly in development',
      () {
    // Every caller guards against it — the view always has its primary, and
    // the providers skip a wagon with nothing modellable on it — so reaching
    // here with no loads means a bug. The assert says so in a debug build;
    // the guard behind it keeps a release build from throwing on `first`
    // instead, which cannot be exercised from a test because asserts are on.
    expect(
      () => buildLoadedWagonScene(
        loads: const [],
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      ),
      throwsA(isA<AssertionError>()),
    );
  });
}
