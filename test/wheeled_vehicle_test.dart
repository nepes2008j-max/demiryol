import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/securing_layout_builder.dart';
import 'package:railsim/domain/usecases/securing_measurements.dart';
import 'package:railsim/domain/usecases/securing_mesh_builder.dart';
import 'package:railsim/domain/usecases/securing_snap.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_catalog.dart';
import 'package:railsim/domain/usecases/wheeled_vehicle_mesh_builder.dart';

/// The three lorries, which had no three-dimensional model at all: the
/// catalogue refused every wheeled vehicle because the only builder made
/// tracked running gear.
List<Vehicle> _vehicles() =>
    ((jsonDecode(File('assets/data/vehicles.json').readAsStringSync())
                as Map<String, dynamic>)['vehicles'] as List)
        .cast<Map<String, dynamic>>()
        .map(Vehicle.fromJson)
        .toList();

void main() {
  final vehicles = _vehicles();
  final wheeled =
      vehicles.where((v) => v.category == VehicleCategory.wheeled).toList();
  // The wheeled vehicles the builder can honestly draw: the ones whose record
  // carries a length, a width, a height and an axle count. The catalogue is
  // built from the ministry's transport-characteristics table, which states the
  // first three for every vehicle and the fourth for none, so most lorries in
  // it keep the flat views — see 'refuses a wheeled vehicle whose axle count
  // nobody recorded' below, which is the invariant that replaced "every wheeled
  // vehicle must model".
  final trucks = wheeled.where((v) => v.axleCount != null).toList();

  group('the catalogue', () {
    test('models every wheeled vehicle it has the figures for', () {
      // The three lorries were the first wheeled vehicles the catalogue could
      // draw; the BTR APCs are wheeled too. Every wheeled record that carries
      // the four figures a solid needs must resolve a spec — one it refuses
      // with the figures in hand is a vehicle the trainee cannot place at all.
      expect(trucks.map((t) => t.id),
          containsAll(['veh-zil131', 'veh-kamaz43114', 'veh-ural4320']));
      expect(trucks.length, greaterThanOrEqualTo(3));
      for (final truck in trucks) {
        final spec = VehicleMeshCatalog.specFor(truck);
        expect(spec, isA<WheeledVehicleMeshSpec>(), reason: truck.id);
      }
    });

    test('refuses a wheeled vehicle whose axle count nobody recorded', () {
      // Plate 06 counts chocks by the axle count and the drawn wheels are what
      // a trainee reads that count off. Drawing a lorry on a guessed number of
      // axles and then measuring against it is the one thing this project does
      // not do, so the solid is withheld and the flat views stand.
      final unrecorded = wheeled.where((v) => v.axleCount == null).toList();
      expect(unrecorded, isNotEmpty,
          reason: 'the catalogue no longer holds a lorry without an axle count');
      for (final v in unrecorded) {
        expect(VehicleMeshCatalog.specFor(v), isNull, reason: v.id);
      }
    });

    test('each is built to the dimensions its own record states', () {
      for (final truck in trucks) {
        final spec = VehicleMeshCatalog.specFor(truck)! as WheeledVehicleMeshSpec;
        expect(spec.hullLengthM * 100, closeTo(truck.lengthCm.asDouble!, 1e-6),
            reason: truck.id);
        expect(spec.overallWidthM * 100, closeTo(truck.widthCm.asDouble!, 1e-6),
            reason: truck.id);
        expect(spec.overallHeightM * 100, closeTo(truck.heightCm.asDouble!, 1e-6),
            reason: truck.id);
      }
    });

    test('the axle count is the record\'s, because plate-06 counts by it', () {
      for (final truck in trucks) {
        final spec = VehicleMeshCatalog.specFor(truck)! as WheeledVehicleMeshSpec;
        expect(spec.axleCount, truck.axleCount, reason: truck.id);
        expect(spec.axleXs, hasLength(truck.axleCount!), reason: truck.id);
      }
    });

    test('the KamAZ is a cab-over and the other two are bonneted', () {
      WheeledVehicleMeshSpec of(String id) => VehicleMeshCatalog
          .specFor(vehicles.firstWhere((v) => v.id == id))! as WheeledVehicleMeshSpec;
      expect(of('veh-kamaz43114').cabOverEngine, isTrue);
      expect(of('veh-zil131').cabOverEngine, isFalse);
      expect(of('veh-ural4320').cabOverEngine, isFalse);
    });

    test('a lorry with no recorded dimensions is still not modelled', () {
      // The rule that governs every vehicle: no dimensions, no solid.
      final bare = Vehicle.fromJson({
        'id': 'veh-hypothetical-lorry',
        'handbookDesignation': 'x',
        'category': 'wheeled',
        'lengthCm': 'TODO: Fill from Handbook Page XX',
        'widthCm': 250,
        'heightCm': 290,
        'weightT': 'TODO',
        'groundClearanceCm': 'TODO',
        'trackWidthMm': 'TODO',
        'wheelBaseCm': 'TODO',
        'manufacturer': 'x',
        'country': 'x',
        'approvedSecuringHardware': <String>[],
        'referenceId': 'plate-05',
      });
      expect(VehicleMeshCatalog.specFor(bare), isNull);
    });
  });

  group('the built lorry', () {
    final spec = VehicleMeshCatalog.specFor(
        trucks.firstWhere((v) => v.id == 'veh-ural4320'))! as WheeledVehicleMeshSpec;
    final model = buildVehicleModel(spec);
    final bounds = model.mesh.bounds;

    test('stands on its wheels, on the ground plane', () {
      expect(bounds.min.y, closeTo(0, 0.01));
    });

    test('is exactly as long, wide and tall as the record says', () {
      expect(bounds.size.x, closeTo(spec.hullLengthM, 0.02));
      expect(bounds.size.z, closeTo(spec.overallWidthM, 0.02));
      expect(bounds.max.y, closeTo(spec.overallHeightM, 0.02));
    });

    test('has a wheel on each side of every axle', () {
      final wheels = model.mesh.faces.where((f) => f.partId == 'wheel');
      expect(wheels, isNotEmpty);
      expect(wheels.where((f) => f.centroid.z > 0).length,
          wheels.where((f) => f.centroid.z < 0).length);
      expect(model.wheelContactX, hasLength(spec.axleCount));
    });

    test('the securing gear bears against the outermost tyres', () {
      // Plate-06 puts a chock under the tyre, so "against the running gear"
      // has to mean the wheels and not the ends of the body.
      expect(model.trackContactX.front, lessThan(spec.halfLength));
      expect(model.trackContactX.rear, greaterThan(-spec.halfLength));
      expect(model.trackContactX.front,
          closeTo(model.wheelContactX.reduce((a, b) => a > b ? a : b) +
              spec.wheelRadiusM, 1e-9));
    });

    test('a stop block is never shorter than the tyre is wide', () {
      // The same plate-02 rule as for a track, read off the tyre instead.
      expect(SecuringLayoutBuilder.blockLengthFor(spec),
          greaterThanOrEqualTo(spec.runningGearWidthM));
      expect(spec.runningGearWidthM, spec.tyreWidthM);
    });

    test('it has a cab, a bed and a tilt — it reads as a lorry', () {
      final parts = model.mesh.faces.map((f) => f.partId).toSet();
      expect(parts, containsAll(<String>[
        'chassis', 'cab', 'cab.windscreen', 'bed.floor', 'bed.side',
        'bed.tilt', 'wheel', 'mudguard', 'bumper',
      ]));
    });

    test('a bonneted lorry has a bonnet and a cab-over does not', () {
      final bonneted = buildVehicleModel(spec).mesh.faces
          .any((f) => f.partId == 'bonnet');
      expect(bonneted, isTrue);
      final cabOver = buildVehicleModel(
              WheeledVehicleMeshSpec(
                  hullLengthM: spec.hullLengthM,
                  overallWidthM: spec.overallWidthM,
                  overallHeightM: spec.overallHeightM,
                  cabOverEngine: true))
          .mesh
          .faces
          .any((f) => f.partId == 'bonnet');
      expect(cabOver, isFalse);
    });

    test('it has four lashing eyes like everything else', () {
      expect(model.lashingEyes, hasLength(4));
      expect(model.gunReachX, 0, reason: 'a lorry has no gun');
    });
  });

  group('a lorry on the wagon', () {
    final spec = VehicleMeshCatalog.specFor(
        trucks.firstWhere((v) => v.id == 'veh-zil131'))! as WheeledVehicleMeshSpec;

    test('its load height is the deck plus its own recorded height', () {
      const flatcar = FlatcarMeshSpec.standardFourAxle;
      final scene = buildLoadingScene(vehicleSpec: spec, flatcarSpec: flatcar);
      expect(
        scene.clearances.loadTopAboveRailM,
        closeTo(flatcar.deckHeightM + spec.overallHeightM, 0.03),
      );
      // 2.50 m of lorry on a 2.87 m deck overhangs neither side.
      expect(scene.clearances.lateralOverhangM, 0);
    });

    test('centred on a standard flatcar it overhangs neither end', () {
      final scene = buildLoadingScene(
          vehicleSpec: spec,
          flatcarSpec: FlatcarMeshSpec.standardFourAxle,
          positionFraction: 0.5);
      expect(scene.clearances.frontOverhangM, 0);
      expect(scene.clearances.rearOverhangM, 0);
      // Unlike a tank, two of these do fit on one wagon.
      expect(scene.clearances.freeDeckLengthM, greaterThan(5.0));
    });

    test('two lorries do not fit on a standard flatcar either', () {
      // Two 7.04 m lorries need 14.08 m of a 13.30 m deck, before the 50 mm
      // the plates want between them. The scene says so rather than drawing
      // them through one another in silence.
      final scene = buildLoadedWagonScene(
        loads: [
          PlacedLoad(
              placementId: 'a', designation: 'ZIL-131',
              spec: spec, positionFraction: 0.0),
          PlacedLoad(
              placementId: 'b', designation: 'ZIL-131',
              spec: spec, positionFraction: 1.0),
        ],
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      );
      expect(scene.gaps.single.overlaps, isTrue);
    });

    test('on a long enough wagon they do, with the gap measured', () {
      final scene = buildLoadedWagonScene(
        loads: [
          PlacedLoad(
              placementId: 'a', designation: 'ZIL-131',
              spec: spec, positionFraction: 0.0),
          PlacedLoad(
              placementId: 'b', designation: 'ZIL-131',
              spec: spec, positionFraction: 1.0),
        ],
        flatcarSpec: FlatcarMeshSpec.fromPlatformFigures(
            lengthCm: 1600, widthCm: 287, deckHeightCm: 131),
      );
      expect(scene.gaps.single.overlaps, isFalse);
      // The plates want 50 mm between wheeled vehicles in a row; there is far
      // more than that here, and the figure is a measurement either way.
      expect(scene.gaps.single.gapMm, greaterThan(50));
    });

    test('it renders, and nothing comes out non-finite', () {
      final scene = buildLoadingScene(
          vehicleSpec: spec, flatcarSpec: FlatcarMeshSpec.standardFourAxle);
      final camera = Camera3.framing(scene.mesh.bounds, aspectRatio: 2.4);
      final faces = SceneProjection.render(scene.mesh,
          camera: camera, width: 800, height: 333);
      expect(faces.length, greaterThan(200));
      for (final f in faces) {
        for (final p in f.points) {
          expect(p.x.isFinite && p.y.isFinite, isTrue);
        }
      }
    });

    test('no face of it is degenerate', () {
      // The primitives' winding is held to the outward contract in
      // `scene3d_test.dart`; what a compound body can still go wrong in is a
      // collapsed face, which produces a zero normal and then sorts and
      // shades as noise.
      final model = buildVehicleModel(spec);
      for (final face in model.mesh.faces) {
        expect(face.vertices.length, greaterThanOrEqualTo(3));
        final n = face.normal;
        expect(n.length, closeTo(1.0, 1e-6),
            reason: 'degenerate face in ${face.partId}');
        for (final v in face.vertices) {
          expect(v.x.isFinite && v.y.isFinite && v.z.isFinite, isTrue);
        }
      }
    });
  });

  group('placing wood against a lorry\'s wheels', () {
    final spec = VehicleMeshCatalog.specFor(
        trucks.firstWhere((v) => v.id == 'veh-ural4320'))! as WheeledVehicleMeshSpec;
    final g = resolveLoadingGeometry(
        vehicleSpec: spec, flatcarSpec: FlatcarMeshSpec.standardFourAxle);
    final axles = [for (final x in spec.axleXs) x + g.vehicleOffsetX];

    BlockSeating seat(double x) => measureBlockSeating(
          layout: SecuringLayout([
            SecuringPiece(
              id: 'woodChock-1',
              kind: SecuringPieceKind.woodChock,
              x: x,
              z: g.vehicle.trackCenterZ,
              widthM: 0.20,
              heightM: 0.10,
              lengthM: 0.44,
            ),
          ]),
          vehicle: g.vehicle,
          vehicleOffsetX: g.vehicleOffsetX,
        ).single;

    test('the distance is measured from the nearest wheel, not the far end', () {
      // A block at the middle axle used to report its distance from the
      // outermost tyre — a metre and a half about nothing.
      final middle = seat(axles[1] + 0.12);
      expect(middle.wheelIndex, 1);
      expect(middle.axleNumber, 2);
      expect(middle.seatingDistanceCm, closeTo(12, 1e-6));
    });

    test('each axle can be the one a block is against', () {
      for (var i = 0; i < axles.length; i++) {
        final s = seat(axles[i] + 0.08);
        expect(s.wheelIndex, i, reason: 'axle ${i + 1}');
        expect(s.seatingDistanceCm, closeTo(8, 1e-6));
      }
    });

    test('a block behind a wheel reads the same distance as one ahead of it', () {
      final ahead = seat(axles[2] + 0.10);
      final behind = seat(axles[2] - 0.10);
      expect(ahead.seatingDistanceCm, closeTo(10, 1e-6));
      expect(behind.seatingDistanceCm, closeTo(10, 1e-6));
      expect(ahead.againstFrontOfRun, isTrue);
      expect(behind.againstFrontOfRun, isFalse);
      expect(ahead.wheelIndex, behind.wheelIndex);
    });

    test('touching the tyre reads zero', () {
      expect(seat(axles[0]).seatingDistanceCm, closeTo(0, 1e-9));
    });

    test('typing a distance seats it that far from the same wheel', () {
      // The entry and the readout must agree, whichever wheel it is against.
      for (var i = 0; i < axles.length; i++) {
        final start = seat(axles[i] + 0.30);
        final moved = SecuringPiece(
          id: 'woodChock-1',
          kind: SecuringPieceKind.woodChock,
          x: xForSeatingDistance(
            seating: start,
            vehicle: g.vehicle,
            vehicleOffsetX: g.vehicleOffsetX,
            distanceM: 0.05,
          ),
          z: g.vehicle.trackCenterZ,
          widthM: 0.20,
          heightM: 0.10,
          lengthM: 0.44,
        );
        final after = measureBlockSeating(
                layout: SecuringLayout([moved]),
                vehicle: g.vehicle,
                vehicleOffsetX: g.vehicleOffsetX)
            .single;
        expect(after.seatingDistanceCm, closeTo(5, 1e-6), reason: 'axle ${i + 1}');
        expect(after.wheelIndex, i, reason: 'axle ${i + 1}');
      }
    });

    test('a tracked vehicle still measures from the track and names no wheel', () {
      final tg = resolveLoadingGeometry(
          vehicleSpec: TrackedVehicleMeshSpec.t72,
          flatcarSpec: FlatcarMeshSpec.standardFourAxle);
      expect(tg.vehicle.wheelContactX, isEmpty);
      final s = measureBlockSeating(
        layout: SecuringLayout([
          SecuringPiece(
            id: 'woodChock-1',
            kind: SecuringPieceKind.woodChock,
            x: tg.vehicle.trackContactX.front + tg.vehicleOffsetX + 0.125,
            z: tg.vehicle.trackCenterZ,
            lengthM: 0.78,
          ),
        ]),
        vehicle: tg.vehicle,
        vehicleOffsetX: tg.vehicleOffsetX,
      ).single;
      expect(s.wheelIndex, isNull);
      expect(s.axleNumber, isNull);
      expect(s.seatingDistanceCm, closeTo(12.5, 1e-6));
    });
  });

  group('the assist and the readout agree, wheel by wheel', () {
    final spec = VehicleMeshCatalog.specFor(
        trucks.firstWhere((v) => v.id == 'veh-ural4320'))! as WheeledVehicleMeshSpec;
    const flatcar = FlatcarMeshSpec.standardFourAxle;
    final g = resolveLoadingGeometry(vehicleSpec: spec, flatcarSpec: flatcar);
    final axles = [for (final x in spec.axleXs) x + g.vehicleOffsetX];

    SecuringPiece blockAt(double x) => SecuringPiece(
          id: 'b',
          kind: SecuringPieceKind.woodChock,
          x: x,
          z: g.vehicle.trackCenterZ,
          widthM: 0.20,
          heightM: 0.10,
          lengthM: 0.44,
        );

    double readBack(double x) => measureBlockSeating(
          layout: SecuringLayout([blockAt(x)]),
          vehicle: g.vehicle,
          vehicleOffsetX: g.vehicleOffsetX,
        ).single.seatingDistanceCm;

    test('snapping to any wheel lands at the distance that was asked for', () {
      // Seating against the *outer edge* of the outermost tyre while
      // measuring from its *centre* meant asking for 12.5 cm produced a block
      // the panel called 67 cm away.
      for (var i = 0; i < axles.length; i++) {
        for (final side in const [1, -1]) {
          final dropped = axles[i] + side * 0.30;
          final snap = SecuringSnap.forBlock(
            piece: blockAt(dropped),
            x: dropped,
            z: g.vehicle.trackCenterZ,
            vehicle: g.vehicle,
            flatcarSpec: flatcar,
            vehicleOffsetX: g.vehicleOffsetX,
            seatingDistanceM: 0.125,
          );
          expect(readBack(snap.x), closeTo(12.5, 1e-6),
              reason: 'axle ${i + 1}, side $side');
        }
      }
    });

    test('every axle is reachable, not just the outer two', () {
      // The middle axle of a six-wheeler is two of its six wheels, and the
      // assist could not reach it at all while it only knew the ends.
      final dropped = axles[1] + 0.10;
      final snap = SecuringSnap.forBlock(
        piece: blockAt(dropped),
        x: dropped,
        z: g.vehicle.trackCenterZ,
        vehicle: g.vehicle,
        flatcarSpec: flatcar,
        vehicleOffsetX: g.vehicleOffsetX,
        seatingDistanceM: 0.125,
      );
      expect(snap.snapped, isTrue);
      expect(readBack(snap.x), closeTo(12.5, 1e-6));
      expect(
        measureBlockSeating(
                layout: SecuringLayout([blockAt(snap.x)]),
                vehicle: g.vehicle,
                vehicleOffsetX: g.vehicleOffsetX)
            .single
            .wheelIndex,
        1,
      );
    });

    test('a newly added block lands at the distance the panel reports', () {
      final piece = SecuringLayoutBuilder.newPiece(
        layout: SecuringLayout.empty,
        kind: SecuringPieceKind.woodChock,
        vehicle: g.vehicle,
        vehicleOffsetX: g.vehicleOffsetX,
        heightM: 0.10,
        widthM: 0.20,
        seatingDistanceM: 0.125,
      );
      expect(readBack(piece.x), closeTo(12.5, 1e-6));
    });

    test('a block dropped well clear of every wheel keeps its place', () {
      final clear = axles.first + 1.40;
      final snap = SecuringSnap.forBlock(
        piece: blockAt(clear),
        x: clear,
        z: 0,
        vehicle: g.vehicle,
        flatcarSpec: flatcar,
        vehicleOffsetX: g.vehicleOffsetX,
        seatingDistanceM: 0.125,
      );
      expect(snap.x, closeTo(clear, 1e-9));
      expect(snap.snapped, isFalse);
    });

    test('the guides mark each tyre, not a strip down the whole lorry', () {
      // A strip said the machine bears everywhere along its length, which is
      // the opposite of what plate-06 is about.
      final visual = buildSecuringVisual(
        vehicle: g.vehicle,
        flatcar: buildFlatcarModel(flatcar),
        vehicleOffsetX: g.vehicleOffsetX,
        layout: SecuringLayout.empty,
        showRunningGearGuides: true,
      );
      final guides = visual.mesh.faces.where((f) => f.partId == 'securing.guide');
      expect(guides, isNotEmpty);
      final centres = guides.map((f) => f.centroid.x.toStringAsFixed(1)).toSet();
      // One patch per wheel per side; the x centres collapse to the axles.
      expect(centres.length, greaterThanOrEqualTo(spec.axleCount));
    });

    test('a tracked vehicle keeps one continuous guide per track', () {
      final tg = resolveLoadingGeometry(
          vehicleSpec: TrackedVehicleMeshSpec.t72, flatcarSpec: flatcar);
      final visual = buildSecuringVisual(
        vehicle: tg.vehicle,
        flatcar: buildFlatcarModel(flatcar),
        vehicleOffsetX: tg.vehicleOffsetX,
        layout: SecuringLayout.empty,
        showRunningGearGuides: true,
      );
      final guides =
          visual.mesh.faces.where((f) => f.partId == 'securing.guide').toList();
      expect(guides, isNotEmpty);
      final span = guides.map((f) => f.centroid.x).toList()..sort();
      // One long outline each side, so its faces spread the bearing length.
      expect(span.last - span.first,
          greaterThan(TrackedVehicleMeshSpec.t72.trackContactLengthM * 0.5));
    });
  });
}
