import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';
import 'package:railsim/domain/usecases/wagon_capacity.dart';

/// A wagon carrying more than one vehicle.
///
/// The plates dimension the space between two tracked vehicles on one flatcar
/// — 100 mm — and until the scene could draw both, that rule sat in the data
/// and was read by nothing: the second machine was simply not rendered, so
/// neither the trainee nor the report could see whether the pair fitted.
Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

PlacedLoad _load(
  String id, {
  TrackedVehicleMeshSpec spec = TrackedVehicleMeshSpec.t72,
  required double at,
  double traverse = 0,
  SecuringLayout securing = SecuringLayout.empty,
}) =>
    PlacedLoad(
      placementId: id,
      designation: id,
      spec: spec,
      positionFraction: at,
      turretTraverse: traverse,
      securing: securing,
    );

void main() {
  final rules = _read('assets/data/rules.json');
  const flatcar = FlatcarMeshSpec.standardFourAxle;

  /// A deck long enough to actually get two tanks onto, so the geometry can be
  /// tested rather than the failure to fit.
  final longDeck = FlatcarMeshSpec.fromPlatformFigures(
      lengthCm: 2400, widthCm: 287, deckHeightCm: 131);

  group('drawing more than one', () {
    test('both vehicles are in the scene, in the order they stand', () {
      final scene = buildLoadedWagonScene(
        loads: [_load('rear', at: 0.0), _load('front', at: 1.0)],
        flatcarSpec: longDeck,
      );
      expect(scene.loads, hasLength(2));
      expect(scene.loads.first.placementId, 'rear');
      expect(scene.loads.last.placementId, 'front');
      expect(scene.loads.first.bounds.max.x,
          lessThan(scene.loads.last.bounds.max.x));
    });

    test('they are sorted along the wagon, whichever order they were listed in',
        () {
      // The gaps must be between actual neighbours, not between whichever two
      // the caller happened to name first.
      final scene = buildLoadedWagonScene(
        loads: [_load('front', at: 1.0), _load('rear', at: 0.0)],
        flatcarSpec: longDeck,
      );
      expect(scene.loads.map((l) => l.placementId), ['rear', 'front']);
      expect(scene.gaps.single.rearPlacementId, 'rear');
      expect(scene.gaps.single.frontPlacementId, 'front');
    });

    test('a single vehicle has no gaps at all', () {
      final scene = buildLoadedWagonScene(
        loads: [_load('only', at: 0.5)],
        flatcarSpec: flatcar,
      );
      expect(scene.gaps, isEmpty);
      expect(scene.loads, hasLength(1));
    });

    test('the drawn mesh really contains both machines', () {
      final one = buildLoadedWagonScene(
          loads: [_load('a', at: 0.0)], flatcarSpec: longDeck);
      final two = buildLoadedWagonScene(
        loads: [_load('a', at: 0.0), _load('b', at: 1.0)],
        flatcarSpec: longDeck,
      );
      expect(two.mesh.faces.length, greaterThan(one.mesh.faces.length));
      // And the load's overall extent covers both of them.
      expect(two.loadBounds.size.x, greaterThan(one.loadBounds.size.x));
    });

    test('hiding the vehicles hides all of them, gear and wagon left alone', () {
      final shown = buildLoadedWagonScene(
        loads: [_load('a', at: 0.0), _load('b', at: 1.0)],
        flatcarSpec: longDeck,
      );
      final hidden = buildLoadedWagonScene(
        loads: [_load('a', at: 0.0), _load('b', at: 1.0)],
        flatcarSpec: longDeck,
        includeVehicles: false,
      );
      expect(hidden.mesh.faces.length, lessThan(shown.mesh.faces.length));
      // The measurements are unchanged: they come from where the vehicles
      // stand, not from whether they are drawn.
      expect(hidden.loadBounds.size.x, closeTo(shown.loadBounds.size.x, 1e-9));
      expect(hidden.gaps.single.gapM, closeTo(shown.gaps.single.gapM, 1e-9));
    });
  });

  group('the space between them', () {
    test('is measured between their full extents, gun included', () {
      // A gun trained over the vehicle behind is exactly what a clearance is
      // there to prevent, so the hull is not what is measured.
      final gunForward = buildLoadedWagonScene(
        loads: [_load('rear', at: 0.35), _load('front', at: 0.65)],
        flatcarSpec: longDeck,
      );
      // The rear machine's gun points forward, into the space between them.
      // Traversing it over its own rear deck takes the muzzle out of the gap.
      final gunReversed = buildLoadedWagonScene(
        loads: [
          _load('rear', at: 0.35, traverse: 3.14159),
          _load('front', at: 0.65),
        ],
        flatcarSpec: longDeck,
      );
      expect(gunReversed.gaps.single.gapM,
          greaterThan(gunForward.gaps.single.gapM));

      // And turning the *front* machine's gun round makes it worse, because
      // that points its muzzle back at the vehicle behind.
      final wrongWay = buildLoadedWagonScene(
        loads: [
          _load('rear', at: 0.35),
          _load('front', at: 0.65, traverse: 3.14159),
        ],
        flatcarSpec: longDeck,
      );
      expect(wrongWay.gaps.single.gapM,
          lessThan(gunForward.gaps.single.gapM));
    });

    test('two vehicles set on top of one another report a negative gap', () {
      final scene = buildLoadedWagonScene(
        loads: [_load('a', at: 0.5), _load('b', at: 0.5)],
        flatcarSpec: longDeck,
      );
      expect(scene.gaps.single.overlaps, isTrue);
      expect(scene.gaps.single.gapM, lessThan(0));
    });

    test('two T-72s do not fit on a standard flatcar, and it shows', () {
      // 13.30 m of deck against two machines 9.53 m long over their guns.
      // This is a real answer, and the scene could not give it before.
      final scene = buildLoadedWagonScene(
        loads: [_load('rear', at: 0.0), _load('front', at: 1.0)],
        flatcarSpec: flatcar,
      );
      expect(scene.gaps.single.overlaps, isTrue);
    });

    test('the free deck length counts what both of them use', () {
      final one = buildLoadedWagonScene(
          loads: [_load('a', at: 0.2)], flatcarSpec: longDeck);
      final two = buildLoadedWagonScene(
        loads: [_load('a', at: 0.2), _load('b', at: 0.8)],
        flatcarSpec: longDeck,
      );
      expect(two.clearances.freeDeckLengthM,
          lessThan(one.clearances.freeDeckLengthM));
    });

    test('each vehicle keeps its own securing gear', () {
      const block = SecuringPiece(
          id: 'woodChock-1', kind: SecuringPieceKind.woodChock, x: 0, z: 1.39);
      final scene = buildLoadedWagonScene(
        loads: [
          _load('a', at: 0.0, securing: const SecuringLayout([block])),
          _load('b', at: 1.0),
        ],
        flatcarSpec: longDeck,
      );
      final rear = scene.loads.firstWhere((l) => l.placementId == 'a');
      final front = scene.loads.firstWhere((l) => l.placementId == 'b');
      expect(rear.layout.blocks, hasLength(1));
      expect(front.layout.blocks, isEmpty);
      // The scene's totals add both up.
      expect(scene.securing.blockCount, 1);
    });
  });

  group('checking that space against the plates', () {
    ValidationCheck check(double gapMm,
            {VehicleCategory rear = VehicleCategory.tracked,
            VehicleCategory front = VehicleCategory.tracked}) =>
        checkPlacementClearance(
          gapMm: gapMm,
          rearDesignation: 'T-72',
          frontDesignation: 'T-90S',
          rearCategory: rear,
          frontCategory: front,
          rules: rules,
        );

    test('two tracked vehicles need 100 mm, and 120 passes', () {
      final required =
          clearanceBetween(VehicleCategory.tracked, VehicleCategory.tracked, rules);
      expect(required?.mm, 100);
      final c = check(120);
      expect(c.status, CheckStatus.pass);
      expect(c.referenceId, 'plate-02');
      expect(c.detail, contains('100'));
    });

    test('80 mm fails, and says by how much it is short', () {
      final c = check(80);
      expect(c.status, CheckStatus.fail);
      expect(c.detail, contains('80'));
      expect(c.detail, contains('100'));
    });

    test('exactly 100 mm passes — the rule is a minimum', () {
      expect(check(100).status, CheckStatus.pass);
    });

    test('vehicles fouling one another is called out as such', () {
      final c = check(-45);
      expect(c.status, CheckStatus.fail);
      expect(c.detail, contains('45'));
    });

    test('a wheeled pair takes the wheeled figure, not the tracked one', () {
      final required = clearanceBetween(
          VehicleCategory.wheeled, VehicleCategory.wheeled, rules);
      expect(required?.mm, 50);
      expect(
          check(60,
                  rear: VehicleCategory.wheeled,
                  front: VehicleCategory.wheeled)
              .status,
          CheckStatus.pass);
    });

    test('a mixed pair takes the larger mixed-row figure', () {
      final required =
          clearanceBetween(VehicleCategory.tracked, VehicleCategory.wheeled, rules);
      expect(required?.mm, 270);
      // 120 mm clears a tracked pair and fails a mixed one.
      expect(
          check(120, front: VehicleCategory.wheeled).status, CheckStatus.fail);
    });

    test('with no rule for the pair it reports unknown rather than guessing', () {
      final c = checkPlacementClearance(
        gapMm: 120,
        rearDesignation: 'a',
        frontDesignation: 'b',
        rearCategory: VehicleCategory.tracked,
        frontCategory: VehicleCategory.tracked,
        rules: const {'rules': []},
      );
      expect(c.status, CheckStatus.unknown);
    });
  });
}
