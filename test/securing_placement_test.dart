import 'package:test/test.dart';

import 'dart:convert';
import 'dart:io';

import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/chock_arrangement.dart';
import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/domain/usecases/scene3d_picking.dart';
import 'package:railsim/domain/usecases/securing_hardware_catalog.dart';
import 'package:railsim/domain/usecases/securing_layout_builder.dart';
import 'package:railsim/domain/usecases/securing_measurements.dart';
import 'package:railsim/domain/usecases/securing_mesh_builder.dart';
import 'package:railsim/domain/usecases/securing_snap.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';

LoadingGeometry _geometry({double position = 0.5}) => resolveLoadingGeometry(
      vehicleSpec: TrackedVehicleMeshSpec.t90s,
      flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      positionFraction: position,
    );

SecuringLayout _arrangement({double position = 0.5, double seating = 0.125}) {
  final g = _geometry(position: position);
  return SecuringLayoutBuilder.handbookArrangement(
    vehicle: g.vehicle,
    flatcar: g.flatcar,
    vehicleOffsetX: g.vehicleOffsetX,
    chockHeightM: 0.16,
    chockWidthM: 0.20,
    chockSizeTypeCode: 'up to 12.0 t',
    seatingDistanceM: seating,
  );
}

const _trackedArrangement = ChockArrangement(
  id: 'tracked-standard',
  appliesTo: VehicleCategory.tracked,
  label: 'test',
  chockCount: 4,
  seatingDistance: (minCm: 10, maxCm: 15),
  referenceId: 'plate-02',
);

const _noDistanceArrangement = ChockArrangement(
  id: 'wheeled',
  appliesTo: VehicleCategory.wheeled,
  label: 'test',
  chockCount: 8,
  referenceId: 'plate-05',
);

void main() {
  group('the layout the trainee is holding', () {
    test('the handbook arrangement seats a block at each end of each track', () {
      final layout = _arrangement();
      expect(layout.blocks, hasLength(4));
      expect(layout.blocks.where((b) => b.z > 0), hasLength(2));
      expect(layout.blocks.where((b) => b.z < 0), hasLength(2));
      // Each block's size came from a real table row, and says which.
      for (final block in layout.blocks) {
        expect(block.sizeTypeCode, 'up to 12.0 t');
      }
    });

    test('plate-02\'s four transverse inserts are laid out when sized', () {
      final g = _geometry();
      final layout = SecuringLayoutBuilder.handbookArrangement(
        vehicle: g.vehicle,
        flatcar: g.flatcar,
        vehicleOffsetX: g.vehicleOffsetX,
        chockHeightM: 0.18,
        chockWidthM: 0.20,
        insertHeightM: 0.095,
        insertLengthM: 0.350,
        insertSizeTypeCode: '90-100 x 300-400 mm',
      );
      final inserts =
          layout.pieces.where((p) => p.kind == SecuringPieceKind.woodInsert);
      expect(inserts, hasLength(4));
      expect(inserts.where((p) => p.z > 0), hasLength(2));
      expect(inserts.where((p) => p.z < 0), hasLength(2));
      // Seated between the road wheels, well inside the ends where the stop
      // blocks are.
      final front = g.vehicle.trackContactX.front + g.vehicleOffsetX;
      final rear = g.vehicle.trackContactX.rear + g.vehicleOffsetX;
      for (final insert in inserts) {
        expect(insert.x, greaterThan(rear));
        expect(insert.x, lessThan(front));
        // Labelled with the range the table states, never a single figure.
        expect(insert.sizeTypeCode, '90-100 x 300-400 mm');
      }
    });

    test('no insert size means no inserts, like every other piece', () {
      final layout = _arrangement();
      expect(layout.pieces.where((p) => p.kind == SecuringPieceKind.woodInsert),
          isEmpty);
    });

    test('a stop block is never shorter than the track is wide', () {
      // plate-02: "the chock's length must not be less than the width of the
      // vehicle's track".
      const spec = TrackedVehicleMeshSpec.t90s;
      expect(SecuringLayoutBuilder.blockLengthFor(spec),
          greaterThanOrEqualTo(spec.trackShoeWidthM));
      for (final block in _arrangement().blocks) {
        expect(block.lengthM, greaterThanOrEqualTo(spec.trackShoeWidthM));
      }
    });

    test('a block ahead of the running gear presents its face rearwards', () {
      final g = _geometry();
      final front = g.vehicle.trackContactX.front + g.vehicleOffsetX;
      final ahead = _arrangement().blocks.firstWhere((b) => b.x > front);
      expect(ahead.facing, ChockFacing.towardsRear);
      // The body extends away from the vehicle, not into it.
      expect(ahead.span.back, greaterThan(ahead.span.face));
    });

    test('the working face is the anchor, so a block keeps its size when moved', () {
      final piece = _arrangement().blocks.first;
      final moved = piece.copyWith(x: piece.x + 1.5);
      expect((moved.span.face - moved.span.back).abs(),
          closeTo((piece.span.face - piece.span.back).abs(), 1e-12));
    });

    test('pieces can be added, moved and removed', () {
      var layout = _arrangement();
      final before = layout.blocks.length;
      final g = _geometry();
      final added = SecuringLayoutBuilder.newPiece(
        layout: layout,
        kind: SecuringPieceKind.woodChock,
        vehicle: g.vehicle,
        vehicleOffsetX: g.vehicleOffsetX,
        heightM: 0.2,
        widthM: 0.25,
      );
      layout = layout.add(added);
      expect(layout.blocks.length, before + 1);

      layout = layout.moveTo(added.id, x: 1.25, z: -0.9);
      expect(layout.byId(added.id)!.x, 1.25);
      expect(layout.byId(added.id)!.z, -0.9);

      layout = layout.remove(added.id);
      expect(layout.byId(added.id), isNull);
      expect(layout.blocks.length, before);
    });

    test('a new piece never takes an id another piece is using', () {
      var layout = SecuringLayout.empty;
      final ids = <String>{};
      for (var i = 0; i < 5; i++) {
        final id = layout.nextId(SecuringPieceKind.woodChock);
        expect(ids.add(id), isTrue, reason: 'reused id $id');
        layout = layout.add(SecuringPiece(
            id: id, kind: SecuringPieceKind.woodChock, x: 0, z: 0));
      }
    });

    test('each wire lashing is made fast to a ring that exists', () {
      final g = _geometry();
      final wires = SecuringLayoutBuilder.defaultLashings(
        vehicle: g.vehicle,
        flatcar: g.flatcar,
        vehicleOffsetX: g.vehicleOffsetX,
        runs: 8,
      );
      expect(wires, hasLength(8));
      for (final wire in wires) {
        expect(wire.ringIndex, isNotNull);
        expect(wire.ringIndex! < g.flatcar.tieDownRings.length, isTrue);
        expect(wire.eyeIndex! < g.vehicle.lashingEyes.length, isTrue);
      }
    });
  });

  group('picking a piece out of the scene', () {
    final layout = _arrangement();
    final scene = buildLoadingScene(
      vehicleSpec: TrackedVehicleMeshSpec.t90s,
      flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      securing: layout,
    );
    const width = 900.0;
    const height = 380.0;
    final camera = Camera3.framing(
      scene.flatcar.mesh.bounds.union(scene.loadBounds),
      yaw: 0.62,
      pitch: 0.45,
      aspectRatio: width / height,
    );

    test('a ray through a block comes back with that block\'s id', () {
      // Aim at the top of the block the way the trainee would: project a point
      // on it to the screen, then ask what is under that pixel.
      final block = layout.blocks.firstWhere((b) => b.z > 0);
      final target = Vector3(
        (block.span.face + block.span.back) / 2,
        scene.flatcar.deckTopY + block.heightM * 0.35,
        block.z,
      );
      final pixel = SceneProjection.project(target,
          camera: camera, width: width, height: height);
      expect(pixel, isNotNull);
      final pick = ScenePicking.pick(
        scene.securingMesh,
        ScenePicking.through(
            camera: camera, width: width, height: height, px: pixel!.x, py: pixel.y),
      );
      expect(pick, isNotNull);
      // The placement is part of the id: two vehicles on one wagon each
      // number their pieces from one, and without it a click on one machine's
      // block picked up the other machine's.
      expect(pick!.partId, securingPartId('placement-0', block.id));
      expect(placementOfPart(pick.partId), 'placement-0');
      expect(pieceOfPart(pick.partId), block.id);
    });

    test('the picker and the renderer agree about where a point is', () {
      // If they disagreed by even a little, a block would jump away from the
      // pointer the moment it was grabbed.
      final point = Vector3(1.2, scene.flatcar.deckTopY, -0.4);
      final pixel = SceneProjection.project(point,
          camera: camera, width: width, height: height)!;
      final ray = ScenePicking.through(
          camera: camera, width: width, height: height, px: pixel.x, py: pixel.y);
      final back = ScenePicking.planeY(ray, scene.flatcar.deckTopY);
      expect(back, isNotNull);
      expect(back!.x, closeTo(point.x, 1e-6));
      expect(back.z, closeTo(point.z, 1e-6));
    });

    test('a ray into empty sky picks nothing', () {
      final pick = ScenePicking.pick(
        scene.securingMesh,
        ScenePicking.through(
            camera: camera, width: width, height: height, px: 5, py: 5),
      );
      expect(pick, isNull);
    });

    test('a block behind the tank is still pickable, because the gear is picked alone', () {
      // The gear mesh carries no hull, so nothing of the vehicle can stand
      // between the pointer and the piece the trainee is reaching for.
      final ids = scene.securingMesh.faces
          .map((f) => f.partId)
          .whereType<String>()
          .toSet();
      for (final block in layout.blocks) {
        expect(ids, contains(securingPartId('placement-0', block.id)));
      }
      expect(ids.any((id) => id.startsWith('hull')), isFalse);
    });
  });

  group('snapping a block onto the running gear', () {
    final g = _geometry();
    final piece = _arrangement().blocks.first;

    SnapResult snap(double x, double z, {bool enabled = true}) =>
        SecuringSnap.forBlock(
          piece: piece,
          x: x,
          z: z,
          vehicle: g.vehicle,
          flatcarSpec: FlatcarMeshSpec.standardFourAxle,
          vehicleOffsetX: g.vehicleOffsetX,
          seatingDistanceM: 0.125,
          enabled: enabled,
        );

    test('a block dropped near a track is pulled onto its centre line', () {
      final result = snap(g.vehicle.trackContactX.front + g.vehicleOffsetX + 0.1,
          g.vehicle.trackCenterZ - 0.2);
      expect(result.z, closeTo(g.vehicle.trackCenterZ, 1e-9));
      expect(result.snapped, isTrue);
    });

    test('and seated at the handbook distance off the end of the bearing length', () {
      final front = g.vehicle.trackContactX.front + g.vehicleOffsetX;
      final result = snap(front + 0.30, g.vehicle.trackCenterZ);
      expect(result.x, closeTo(front + 0.125, 1e-9));
      expect(result.facing, ChockFacing.towardsRear);
    });

    test('a block seated behind the vehicle turns its face the other way', () {
      final rear = g.vehicle.trackContactX.rear + g.vehicleOffsetX;
      final result = snap(rear - 0.30, -g.vehicle.trackCenterZ);
      expect(result.x, closeTo(rear - 0.125, 1e-9));
      expect(result.facing, ChockFacing.towardsFront);
    });

    test('a block dropped well clear of the running gear stays where it was put', () {
      // The trainee has to be able to put a block in the wrong place, or the
      // measurement below the scene could never tell them anything.
      final result = snap(4.6, 0.0);
      expect(result.x, closeTo(4.6, 1e-9));
      expect(result.z, closeTo(0.0, 1e-9));
      expect(result.snapped, isFalse);
    });

    test('with snapping off, nothing is pulled anywhere', () {
      final near = g.vehicle.trackCenterZ - 0.05;
      final result = snap(0.0, near, enabled: false);
      expect(result.z, closeTo(near, 1e-9));
      expect(result.snapped, isFalse);
    });

    test('a block can still reach running gear that overhangs the deck', () {
      // The T-90S's tracks stand outboard of a narrow wagon's edge. Clamping
      // a block to the deck put the one position it belongs in out of reach
      // whenever the assist was switched off — "wherever I want" failed
      // exactly where it mattered.
      final narrow = FlatcarMeshSpec.fromPlatformFigures(
          lengthCm: 1330, widthCm: 260, deckHeightCm: 131);
      final narrowGeometry = resolveLoadingGeometry(
          vehicleSpec: TrackedVehicleMeshSpec.t90s, flatcarSpec: narrow);
      expect(narrowGeometry.vehicle.trackCenterZ,
          greaterThan(narrow.deckWidthM / 2),
          reason: 'this test is pointless unless the track overhangs');

      for (final enabled in const [true, false]) {
        final result = SecuringSnap.forBlock(
          piece: piece,
          x: narrowGeometry.vehicle.trackContactX.front +
              narrowGeometry.vehicleOffsetX +
              0.125,
          z: narrowGeometry.vehicle.trackCenterZ,
          vehicle: narrowGeometry.vehicle,
          flatcarSpec: narrow,
          vehicleOffsetX: narrowGeometry.vehicleOffsetX,
          seatingDistanceM: 0.125,
          enabled: enabled,
        );
        expect(result.z, closeTo(narrowGeometry.vehicle.trackCenterZ, 1e-9),
            reason: 'snap enabled: $enabled');
      }
    });

    test('a block can never be dragged off the wagon', () {
      const spec = FlatcarMeshSpec.standardFourAxle;
      final off = snap(99, 99);
      expect(off.x, lessThanOrEqualTo(spec.deckLengthM / 2));
      expect(off.z, lessThanOrEqualTo(spec.deckWidthM / 2));
      final other = snap(-99, -99);
      expect(other.x, greaterThanOrEqualTo(-spec.deckLengthM / 2));
      expect(other.z, greaterThanOrEqualTo(-spec.deckWidthM / 2));
    });
  });

  group('measuring how a block ended up sitting', () {
    final g = _geometry();
    final front = g.vehicle.trackContactX.front + g.vehicleOffsetX;

    List<BlockSeating> measure(SecuringPiece piece) => measureBlockSeating(
          layout: SecuringLayout([piece]),
          vehicle: g.vehicle,
          vehicleOffsetX: g.vehicleOffsetX,
        );

    SecuringPiece block({
      required double x,
      double? z,
      ChockFacing facing = ChockFacing.towardsRear,
    }) =>
        SecuringPiece(
          id: 'b1',
          kind: SecuringPieceKind.woodChock,
          x: x,
          z: z ?? g.vehicle.trackCenterZ,
          widthM: 0.20,
          heightM: 0.16,
          lengthM: 0.78,
          facing: facing,
        );

    test('a block seated 12 cm ahead of the track measures 12 cm', () {
      final seating = measure(block(x: front + 0.12)).single;
      expect(seating.seatingDistanceCm, closeTo(12, 1e-6));
      expect(seating.againstFrontOfRun, isTrue);
      expect(seating.underRunningGear, isTrue);
      expect(seating.facesTheRun, isTrue);
    });

    test('a block pushed sideways off the track is reported as not under it', () {
      final seating = measure(block(x: front + 0.12, z: 0.0)).single;
      expect(seating.underRunningGear, isFalse);
      expect(seating.lateralOffsetM, greaterThan(0.5));
    });

    test('a block laid the wrong way round is reported as such', () {
      final seating =
          measure(block(x: front + 0.12, facing: ChockFacing.towardsFront)).single;
      expect(seating.facesTheRun, isFalse);
    });

    test('a block shoved under the track measures a negative distance', () {
      final seating = measure(block(x: front - 0.30)).single;
      expect(seating.seatingDistanceM, lessThan(0));
      expect(seating.isClearOfRun, isFalse);
    });

    test('a half-round insert has no seating distance and is not given one', () {
      // The plate seats an insert between the road wheels and dimensions no
      // distance from the running gear for it. Measuring one anyway reported
      // over a metre of "distance" on a piece lying exactly where plate-02
      // puts it, and the panel failed it against a range never written about
      // it.
      final full = SecuringLayoutBuilder.handbookArrangement(
        vehicle: g.vehicle,
        flatcar: g.flatcar,
        vehicleOffsetX: g.vehicleOffsetX,
        chockHeightM: 0.16,
        chockWidthM: 0.20,
        insertHeightM: 0.095,
        insertLengthM: 0.350,
      );
      expect(full.pieces.where((p) => p.kind == SecuringPieceKind.woodInsert),
          hasLength(4));
      final measured = measureBlockSeating(
        layout: full,
        vehicle: g.vehicle,
        vehicleOffsetX: g.vehicleOffsetX,
      );
      expect(measured.map((m) => m.pieceId).where((id) => id.startsWith('woodInsert')),
          isEmpty);
      // Only the four stop blocks are measured.
      expect(measured, hasLength(4));
    });

    test('a packing board is not measured either', () {
      final layout = SecuringLayout([
        SecuringPiece(
          id: 'woodPacking-1',
          kind: SecuringPieceKind.woodPacking,
          x: g.vehicleOffsetX,
          z: g.vehicle.trackCenterZ,
        ),
      ]);
      expect(
        measureBlockSeating(
            layout: layout,
            vehicle: g.vehicle,
            vehicleOffsetX: g.vehicleOffsetX),
        isEmpty,
      );
    });

    test('an iron chock is a stop block and is measured', () {
      // It does the same job as the timber one and the same dimension governs
      // it, so it must not fall through the same gap the inserts did.
      final layout = SecuringLayout([
        SecuringPiece(
          id: 'ironChock-1',
          kind: SecuringPieceKind.ironChock,
          x: g.vehicle.trackContactX.front + g.vehicleOffsetX + 0.12,
          z: g.vehicle.trackCenterZ,
          lengthM: 0.78,
        ),
      ]);
      final measured = measureBlockSeating(
          layout: layout, vehicle: g.vehicle, vehicleOffsetX: g.vehicleOffsetX);
      expect(measured, hasLength(1));
      expect(measured.single.seatingDistanceCm, closeTo(12, 1e-6));
    });

    test('every block in a layout is measured', () {
      final seatings = measureBlockSeating(
        layout: _arrangement(),
        vehicle: g.vehicle,
        vehicleOffsetX: g.vehicleOffsetX,
      );
      expect(seatings, hasLength(4));
      // The handbook arrangement seats all four at the distance it was built
      // with, and all four correctly.
      for (final seating in seatings) {
        expect(seating.seatingDistanceCm, closeTo(12.5, 1e-6));
        expect(seating.underRunningGear, isTrue);
        expect(seating.facesTheRun, isTrue);
      }
    });
  });

  group('checking a seating distance against the plate', () {
    const seating = BlockSeating(
      pieceId: 'b1',
      seatingDistanceM: 0.12,
      againstFrontOfRun: true,
      trackSide: 1,
      lateralOffsetM: 0.0,
      underRunningGear: true,
      facesTheRun: true,
    );

    test('inside the stated range it passes, citing the plate', () {
      final check =
          checkSeatingDistance(seating: seating, arrangement: _trackedArrangement);
      expect(check.status, CheckStatus.pass);
      expect(check.referenceId, 'plate-02');
    });

    test('outside it, it fails and says what the range is', () {
      final check = checkSeatingDistance(
        seating: const BlockSeating(
          pieceId: 'b1',
          seatingDistanceM: 0.42,
          againstFrontOfRun: true,
          trackSide: 1,
          lateralOffsetM: 0.0,
          underRunningGear: true,
          facesTheRun: true,
        ),
        arrangement: _trackedArrangement,
      );
      expect(check.status, CheckStatus.fail);
      expect(check.detail, contains('10-15'));
    });

    test('a block that is not under the running gear fails before distance matters', () {
      final check = checkSeatingDistance(
        seating: const BlockSeating(
          pieceId: 'b1',
          seatingDistanceM: 0.12,
          againstFrontOfRun: true,
          trackSide: 1,
          lateralOffsetM: 0.9,
          underRunningGear: false,
          facesTheRun: true,
        ),
        arrangement: _trackedArrangement,
      );
      expect(check.status, CheckStatus.fail);
      expect(check.detail, AppStrings.seatingDistanceNotUnderRunDetail(90));
    });

    test('a block laid the wrong way round fails on that', () {
      final check = checkSeatingDistance(
        seating: const BlockSeating(
          pieceId: 'b1',
          seatingDistanceM: 0.12,
          againstFrontOfRun: true,
          trackSide: 1,
          lateralOffsetM: 0.0,
          underRunningGear: true,
          facesTheRun: false,
        ),
        arrangement: _trackedArrangement,
      );
      expect(check.status, CheckStatus.fail);
      expect(check.detail, AppStrings.seatingDistanceWrongWayDetail);
    });

    test('with no arrangement chosen the distance is measured but not judged', () {
      // The case is chosen by combat weight and nothing may pre-select one for
      // the trainee, so this is the normal state for a tracked vehicle.
      final check = checkSeatingDistance(seating: seating, arrangement: null);
      expect(check.status, CheckStatus.unknown);
    });

    test('an arrangement that states no distance yields no verdict either', () {
      final check = checkSeatingDistance(
          seating: seating, arrangement: _noDistanceArrangement);
      expect(check.status, CheckStatus.unknown);
      expect(check.referenceId, 'plate-05');
    });
  });

  group('everything the handbook lets the trainee put on the wagon', () {
    Map<String, dynamic> read(String path) =>
        jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

    final measurements = read('assets/data/measurements.json');
    final rules = read('assets/data/rules.json');
    final attachments = (read('assets/data/attachments.json')['attachmentTypes']
            as List)
        .cast<Map<String, dynamic>>()
        .map(AttachmentType.fromJson)
        .toList();
    final t90 = (read('assets/data/vehicles.json')['vehicles'] as List)
        .cast<Map<String, dynamic>>()
        .map(Vehicle.fromJson)
        .firstWhere((v) => v.id == 'veh-t90s');

    List<PlaceableHardware> catalogue({Vehicle? vehicle}) => placeableHardwareFor(
          vehicle: vehicle ?? t90,
          measurements: measurements,
          rules: rules,
          attachments: attachments,
          trackShoeWidthM: 0.58,
        );

    test('every kind of securing hardware in the source is placeable', () {
      final kinds = catalogue().map((h) => h.kind).toSet();
      expect(kinds, {
        SecuringPieceKind.woodChock,
        SecuringPieceKind.woodInsert,
        SecuringPieceKind.woodSideBlock,
        SecuringPieceKind.woodPacking,
        SecuringPieceKind.staple,
        SecuringPieceKind.ironChock,
        SecuringPieceKind.ironSpur,
        SecuringPieceKind.ironChockBoot,
        SecuringPieceKind.wireLashing,
      });
    });

    test('every entry carries a real size and a citation', () {
      final list = catalogue();
      expect(list.length, greaterThan(20));
      for (final h in list) {
        expect(h.typeCode, isNotEmpty, reason: h.kind.name);
        expect(h.referenceId, isNotEmpty, reason: h.typeCode);
        expect(h.heightM, greaterThan(0), reason: h.typeCode);
        expect(h.widthM, greaterThan(0), reason: h.typeCode);
        expect(h.lengthM, greaterThan(0), reason: h.typeCode);
        // Nothing absurd: every piece fits on a wagon.
        expect(h.widthM, lessThan(3.0), reason: h.typeCode);
        expect(h.heightM, lessThan(1.0), reason: h.typeCode);
      }
    });

    test('the stop-block brackets are Table 3, with the vehicle\'s one flagged', () {
      final chocks = catalogue()
          .where((h) => h.kind == SecuringPieceKind.woodChock)
          .toList();
      expect(chocks.map((c) => c.typeCode),
          ['up to 12.0 t', '12.1-18.0 t', 'over 18.0 t']);

      // Every bracket is offered whatever the vehicle weighs — the trainee is
      // meant to compare them. What the weight decides is which one is
      // *flagged*, and the weight on the record decides it: at 46.5 t that is
      // Table 3's last row. Nothing used to be flagged for any vehicle,
      // because the transport table's weight was withheld from Table 3.
      final matched =
          chocks.where((c) => c.matchesVehicle).toList();
      expect(matched, hasLength(1));
      expect(matched.single.typeCode, 'over 18.0 t');
      expect((matched.single.heightM * 1000).round(), 180);
      expect((matched.single.widthM * 1000).round(), 200);
      // plate-02: never shorter than the track is wide.
      expect(matched.single.lengthM, greaterThanOrEqualTo(0.58));
    });

    test('all eleven iron spurs and all four stop-boots are offered', () {
      final list = catalogue();
      expect(list.where((h) => h.kind == SecuringPieceKind.ironSpur), hasLength(11));
      expect(list.where((h) => h.kind == SecuringPieceKind.ironChockBoot),
          hasLength(4));
      // A spur's base plate runs across the wagon, under the track it seats
      // below — 580 mm of plate under a 580 mm shoe.
      final s429 = list.firstWhere((h) => h.typeCode == 'Ş-429');
      expect((s429.lengthM * 1000).round(), 580);
      expect((s429.widthM * 1000).round(), 130);
    });

    test('plate-02\'s side block is offered at its stated 100x100x2000 mm', () {
      final block = catalogue()
          .firstWhere((h) => h.kind == SecuringPieceKind.woodSideBlock);
      expect(block.typeCode, '100x100x2000 mm');
      expect((block.heightM * 1000).round(), 100);
      // The two-metre dimension runs along the wagon: the block is laid along
      // the face of the track.
      expect((block.widthM * 1000).round(), 2000);
      expect((block.lengthM * 1000).round(), 100);
    });

    test('a tracked vehicle is never offered the wheeled KGUUB variants', () {
      final types = catalogue()
          .where((h) => h.kind == SecuringPieceKind.ironChock)
          .map((h) => h.typeCode)
          .toSet();
      expect(types, {'KGUUB-1G', 'KGUUB-2G'});
    });

    test('a wheeled vehicle gets its own tables, not the tracked ones', () {
      final truck = (read('assets/data/vehicles.json')['vehicles'] as List)
          .cast<Map<String, dynamic>>()
          .map(Vehicle.fromJson)
          .firstWhere((v) => v.id == 'veh-ural4320');
      final list = catalogue(vehicle: truck);
      final kguub = list
          .where((h) => h.kind == SecuringPieceKind.ironChock)
          .map((h) => h.typeCode)
          .toSet();
      expect(kguub, {'KGUUB-1K', 'KGUUB-2K'});
      // Its stop blocks come from Table 2, by wheel diameter.
      final chocks =
          list.where((h) => h.kind == SecuringPieceKind.woodChock).toList();
      expect(chocks, hasLength(6));
      expect(chocks.first.typeCode, endsWith('mm'));
      // And plate-02's tracked lateral restraints are not offered to it.
      expect(list.where((h) => h.kind == SecuringPieceKind.woodSideBlock), isEmpty);
      expect(list.where((h) => h.kind == SecuringPieceKind.staple), isEmpty);
    });

    test('a piece with no stated size never reaches the palette', () {
      // Strip the insert table and the piece disappears rather than acquiring
      // a default size.
      final stripped = {...measurements}..remove('insertBlockTable');
      final list = placeableHardwareFor(
        vehicle: t90,
        measurements: stripped,
        rules: rules,
        attachments: attachments,
      );
      expect(list.where((h) => h.kind == SecuringPieceKind.woodInsert), isEmpty);
      expect(list, isNotEmpty, reason: 'the rest is unaffected');
    });

    test('every offered piece can be built into a mesh', () {
      final g = _geometry();
      for (final h in catalogue()) {
        final piece = SecuringPiece(
          id: '${h.kind.name}-1',
          kind: h.kind,
          x: g.vehicle.trackContactX.front + g.vehicleOffsetX + 0.125,
          z: g.vehicle.trackCenterZ,
          widthM: h.widthM,
          heightM: h.heightM,
          lengthM: h.lengthM,
          sizeTypeCode: h.typeCode,
          eyeIndex: 0,
          ringIndex: 0,
        );
        final visual = buildSecuringVisual(
          vehicle: g.vehicle,
          flatcar: g.flatcar,
          vehicleOffsetX: g.vehicleOffsetX,
          layout: SecuringLayout([piece]),
        );
        expect(visual.mesh.isEmpty, isFalse, reason: '${h.kind.name} ${h.typeCode}');
        for (final face in visual.mesh.faces) {
          for (final v in face.vertices) {
            expect(v.x.isFinite && v.y.isFinite && v.z.isFinite, isTrue,
                reason: h.typeCode);
          }
        }
      }
    });
  });

  group('placing to the centimetre', () {
    final g = _geometry();
    final front = g.vehicle.trackContactX.front + g.vehicleOffsetX;

    SecuringPiece block(double x) => SecuringPiece(
          id: 'b1',
          kind: SecuringPieceKind.woodChock,
          x: x,
          z: g.vehicle.trackCenterZ,
          widthM: 0.20,
          heightM: 0.18,
          lengthM: 0.78,
        );

    BlockSeating seatingOf(SecuringPiece piece) => measureBlockSeating(
          layout: SecuringLayout([piece]),
          vehicle: g.vehicle,
          vehicleOffsetX: g.vehicleOffsetX,
        ).single;

    test('a typed distance puts the block exactly there', () {
      // The point of the control: 12.5 cm means 12.5 cm, not "about that".
      final piece = block(front + 0.40);
      final moved = piece.copyWith(
        x: xForSeatingDistance(
          seating: seatingOf(piece),
          vehicle: g.vehicle,
          vehicleOffsetX: g.vehicleOffsetX,
          distanceM: 0.125,
        ),
      );
      expect(seatingOf(moved).seatingDistanceCm, closeTo(12.5, 1e-9));
    });

    test('it works at the rear of the vehicle too, where the sign flips', () {
      final rear = g.vehicle.trackContactX.rear + g.vehicleOffsetX;
      final piece = block(rear - 0.40).copyWith(facing: ChockFacing.towardsFront);
      final seating = seatingOf(piece);
      expect(seating.againstFrontOfRun, isFalse);
      final moved = piece.copyWith(
        x: xForSeatingDistance(
          seating: seating,
          vehicle: g.vehicle,
          vehicleOffsetX: g.vehicleOffsetX,
          distanceM: 0.10,
        ),
      );
      expect(seatingOf(moved).seatingDistanceCm, closeTo(10.0, 1e-9));
      expect(moved.x, lessThan(rear));
    });

    test('setting it round-trips through the measurement for any distance', () {
      for (final cm in const [0.0, 1.0, 10.0, 12.5, 15.0, 42.0]) {
        final piece = block(front + 0.9);
        final moved = piece.copyWith(
          x: xForSeatingDistance(
            seating: seatingOf(piece),
            vehicle: g.vehicle,
            vehicleOffsetX: g.vehicleOffsetX,
            distanceM: cm / 100,
          ),
        );
        expect(seatingOf(moved).seatingDistanceCm, closeTo(cm, 1e-9),
            reason: '$cm cm');
      }
    });

    test('a one-centimetre nudge moves it one centimetre', () {
      final piece = block(front + 0.125);
      final nudged = piece.copyWith(x: piece.x + 0.01);
      expect(seatingOf(nudged).seatingDistanceCm,
          closeTo(seatingOf(piece).seatingDistanceCm + 1, 1e-9));
    });
  });

  group('what the result sheet is told', () {
    final g = _geometry();

    SecuringLayout placed(double seatingCm) {
      final front = g.vehicle.trackContactX.front + g.vehicleOffsetX;
      return SecuringLayout([
        SecuringPiece(
          id: 'woodChock-1',
          kind: SecuringPieceKind.woodChock,
          x: front + seatingCm / 100,
          z: g.vehicle.trackCenterZ,
          widthM: 0.20,
          heightM: 0.18,
          lengthM: 0.78,
          facing: ChockFacing.towardsRear,
        ),
      ]);
    }

    List<SeatingFinding> findings(double seatingCm, {ChockArrangement? arrangement}) =>
        seatingFindingsFor(
          placementId: 'placement-0',
          designation: 'T-72',
          layout: placed(seatingCm),
          vehicle: g.vehicle,
          vehicleOffsetX: g.vehicleOffsetX,
          arrangement: arrangement ?? _trackedArrangement,
        );

    test('a block inside the range passes, with no error to report', () {
      final f = findings(12).single;
      expect(f.measuredCm, closeTo(12, 1e-6));
      expect(f.requiredRange, (minCm: 10, maxCm: 15));
      expect(f.errorCm, 0);
      expect(f.status, CheckStatus.pass);
    });

    test('a block short of it reports how far short, signed', () {
      final f = findings(6).single;
      expect(f.errorCm, closeTo(-4, 1e-6));
      expect(f.status, CheckStatus.fail);
    });

    test('and one beyond it, the same the other way', () {
      final f = findings(22).single;
      expect(f.errorCm, closeTo(7, 1e-6));
      expect(f.status, CheckStatus.fail);
    });

    test('the middle of the range is what the sheet aims at', () {
      expect(findings(12).single.targetCm, closeTo(12.5, 1e-9));
    });

    test('with no arrangement chosen the distance is reported but not judged', () {
      final f = findings(12, arrangement: _noDistanceArrangement).single;
      expect(f.measuredCm, closeTo(12, 1e-6));
      expect(f.requiredRange, isNull);
      expect(f.errorCm, isNull);
      expect(f.status, CheckStatus.unknown);
    });

    test('a half-round insert contributes nothing — it has no seating rule', () {
      final withInsert = SecuringLayout([
        ...placed(12).pieces,
        SecuringPiece(
          id: 'woodInsert-1',
          kind: SecuringPieceKind.woodInsert,
          x: g.vehicleOffsetX,
          z: g.vehicle.trackCenterZ,
        ),
      ]);
      final out = seatingFindingsFor(
        placementId: 'placement-0',
        designation: 'T-72',
        layout: withInsert,
        vehicle: g.vehicle,
        vehicleOffsetX: g.vehicleOffsetX,
        arrangement: _trackedArrangement,
      );
      expect(out, hasLength(1));
      expect(out.single.pieceId, 'woodChock-1');
    });
  });
}
