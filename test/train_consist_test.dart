import 'package:test/test.dart';
import 'package:railsim/domain/models/schematic_element.dart';
import 'package:railsim/domain/models/train_consist.dart';

// `ConsistNotifier` and `VehicleOrdersNotifier` (presentation/providers) are
// thin wrappers around the pure transitions tested here — they aren't
// imported because they transitively pull in `flutter_riverpod` and therefore
// `package:flutter`, which does not compile under plain `dart test` (the same
// restriction documented in `schematic_interaction_test.dart`).

void main() {
  group('VehicleOrder', () {
    test('withQuantity replaces the count and keeps the vehicle', () {
      const order = VehicleOrder(vehicleId: 'veh-t54', quantity: 1);
      final grown = order.withQuantity(3);
      expect(grown.vehicleId, 'veh-t54');
      expect(grown.quantity, 3);
      expect(order.quantity, 1, reason: 'the original must not be mutated');
    });
  });

  group('TrainConsist.ofWagons', () {
    test('builds the requested number of wagons, all of the chosen type', () {
      final consist = TrainConsist.ofWagons(count: 5, platformId: 'plat-generic-open-flatcar');
      expect(consist.wagons.length, 5);
      expect(consist.wagons.map((w) => w.id), ['wagon-1', 'wagon-2', 'wagon-3', 'wagon-4', 'wagon-5']);
      expect(
        consist.wagons.every((w) => w.platformId == 'plat-generic-open-flatcar'),
        isTrue,
      );
    });

    test('a count of zero produces an empty consist rather than an error', () {
      final consist = TrainConsist.ofWagons(count: 0, platformId: 'plat-generic-open-flatcar');
      expect(consist.wagons, isEmpty);
      expect(consist.isEmpty, isTrue);
    });

    test('shrinking the consist drops placements whose wagon is gone', () {
      var consist = TrainConsist.ofWagons(count: 3, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      consist = consist.withVehiclePlaced(vehicleId: 'veh-b', wagonIds: ['wagon-3']);
      expect(consist.placements.length, 2);

      consist = TrainConsist.ofWagons(count: 2, platformId: 'plat-x', previous: consist);
      expect(consist.wagons.length, 2);
      expect(
        consist.placements.map((p) => p.vehicleId),
        ['veh-a'],
        reason: 'the vehicle on wagon-3 must go with the wagon, never dangle',
      );
    });

    test('a placement spanning a removed wagon is dropped too', () {
      var consist = TrainConsist.ofWagons(count: 2, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1', 'wagon-2']);
      consist = TrainConsist.ofWagons(count: 1, platformId: 'plat-x', previous: consist);
      expect(consist.placements, isEmpty);
    });
  });

  group('placing vehicles', () {
    test('two vehicles can sit on one wagon', () {
      var consist = TrainConsist.ofWagons(count: 1, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      consist = consist.withVehiclePlaced(vehicleId: 'veh-b', wagonIds: ['wagon-1']);

      final onWagon = consist.placementsOn('wagon-1');
      expect(onWagon.length, 2);
      expect(onWagon.map((p) => p.vehicleId), ['veh-a', 'veh-b']);
    });

    test('a vehicle over a coupling is reported on both wagons and spansCoupling', () {
      var consist = TrainConsist.ofWagons(count: 2, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1', 'wagon-2']);

      final placement = consist.placements.single;
      expect(placement.spansCoupling, isTrue);
      expect(placement.primaryWagonId, 'wagon-1');
      expect(consist.placementsOn('wagon-1'), hasLength(1));
      expect(consist.placementsOn('wagon-2'), hasLength(1));
    });

    test('a vehicle on a single wagon does not span a coupling', () {
      var consist = TrainConsist.ofWagons(count: 2, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      expect(consist.placements.single.spansCoupling, isFalse);
      expect(consist.placementsOn('wagon-2'), isEmpty);
    });

    test('placedCountOf counts copies of one designation across the train', () {
      var consist = TrainConsist.ofWagons(count: 2, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-t54', wagonIds: ['wagon-1']);
      consist = consist.withVehiclePlaced(vehicleId: 'veh-t54', wagonIds: ['wagon-2']);
      consist = consist.withVehiclePlaced(vehicleId: 'veh-2s3', wagonIds: ['wagon-2']);

      expect(consist.placedCountOf('veh-t54'), 2);
      expect(consist.placedCountOf('veh-2s3'), 1);
      expect(consist.placedCountOf('veh-never-placed'), 0);
    });
  });

  group('placement ids', () {
    test('each placement gets a distinct id', () {
      var consist = TrainConsist.ofWagons(count: 1, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      consist = consist.withVehiclePlaced(vehicleId: 'veh-b', wagonIds: ['wagon-1']);
      expect(consist.placements.map((p) => p.id).toSet(), hasLength(2));
    });

    test('a removed placement never has its id re-issued', () {
      // The per-placement equipment and securing-method maps are keyed by
      // this id, so re-issuing one would hand a new vehicle the deleted
      // vehicle's hardware selections.
      var consist = TrainConsist.ofWagons(count: 1, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      final firstId = consist.placements.single.id;

      consist = consist.withoutPlacement(firstId);
      consist = consist.withVehiclePlaced(vehicleId: 'veh-b', wagonIds: ['wagon-1']);

      expect(consist.placements.single.id, isNot(firstId));
    });

    test('rebuilding the wagon list preserves the id counter', () {
      var consist = TrainConsist.ofWagons(count: 2, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      final firstId = consist.placements.single.id;

      consist = TrainConsist.ofWagons(count: 3, platformId: 'plat-x', previous: consist);
      consist = consist.withVehiclePlaced(vehicleId: 'veh-b', wagonIds: ['wagon-3']);

      expect(consist.placements.map((p) => p.id).toSet(), hasLength(2));
      expect(consist.placements.map((p) => p.id), contains(firstId));
    });
  });

  group('offsets are per placement', () {
    test('moving one placement leaves the others where they were', () {
      var consist = TrainConsist.ofWagons(count: 1, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      consist = consist.withVehiclePlaced(vehicleId: 'veh-b', wagonIds: ['wagon-1']);
      final first = consist.placements[0];
      final second = consist.placements[1];

      consist = consist.withUpdatedPlacement(
        first.withOffset(const SchematicPoint(0.1, 0.0)),
      );

      expect(consist.placementById(first.id)!.offset, const SchematicPoint(0.1, 0.0));
      expect(
        consist.placementById(second.id)!.offset,
        const SchematicPoint(0, 0),
        reason: 'the old single global offset moved every vehicle at once; this must not',
      );
    });

    test('a new placement starts at the origin', () {
      var consist = TrainConsist.ofWagons(count: 1, platformId: 'plat-x');
      consist = consist.withVehiclePlaced(vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      expect(consist.placements.single.offset, const SchematicPoint(0, 0));
    });

    test('withOffset does not mutate the original placement', () {
      const placement = PlacedVehicle(id: 'p1', vehicleId: 'veh-a', wagonIds: ['wagon-1']);
      final moved = placement.withOffset(const SchematicPoint(0.2, 0.1));
      expect(placement.offset, const SchematicPoint(0, 0));
      expect(moved.offset, const SchematicPoint(0.2, 0.1));
      expect(moved.vehicleId, 'veh-a');
      expect(moved.wagonIds, ['wagon-1']);
    });
  });

  group('lookups', () {
    test('unknown ids return null rather than throwing', () {
      final consist = TrainConsist.ofWagons(count: 1, platformId: 'plat-x');
      expect(consist.placementById('nope'), isNull);
      expect(consist.wagonById('nope'), isNull);
    });

    test('wagonById finds the wagon and its platform type', () {
      final consist = TrainConsist.ofWagons(count: 2, platformId: 'plat-flatcar');
      expect(consist.wagonById('wagon-2')!.platformId, 'plat-flatcar');
    });
  });
}
