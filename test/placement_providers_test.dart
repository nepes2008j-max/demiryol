@Tags(['flutter'])
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/domain/models/chock_arrangement.dart';
import 'package:railsim/presentation/providers/consist_providers.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';

/// Provider-level regressions that could not be written until `flutter test`
/// ran on this machine — which is how the defects they cover reached the app
/// in the first place.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
  });
  tearDown(() => container.dispose());

  Future<void> loadCatalogue() async {
    await container.read(vehiclesProvider.future);
    await container.read(platformsProvider.future);
    await container.read(attachmentTypesProvider.future);
    await container.read(rulesProvider.future);
  }

  Future<List<String>> seedTwoVehiclesOnOneWagon() async {
    await loadCatalogue();
    final platforms = await container.read(platformsProvider.future);
    final flatcar = platforms.first;
    container.read(selectedWagonTypeProvider.notifier).state = flatcar.id;
    container
        .read(consistProvider.notifier)
        .setWagons(count: 1, platformId: flatcar.id);
    final first = container
        .read(consistProvider.notifier)
        .place(vehicleId: 'veh-t-62', wagonIds: ['wagon-1']);
    final second = container
        .read(consistProvider.notifier)
        .place(vehicleId: 'veh-zil131', wagonIds: ['wagon-1']);
    return [first, second];
  }

  test('results are produced for TWO placements on one wagon', () async {
    // The regression: `placementResultsProvider` watched a provider *after*
    // an await inside its per-placement loop. One vehicle never tripped it
    // because that pass watches before awaiting; two did.
    final ids = await seedTwoVehiclesOnOneWagon();
    final results = await container.read(placementResultsProvider.future);
    expect(results.keys, containsAll(ids));
    for (final id in ids) {
      expect(results[id]!.checks, isNotEmpty, reason: '$id produced no checks');
    }
  });

  test('a wheeled vehicle resolves chocks even with no weight', () async {
    final ids = await seedTwoVehiclesOnOneWagon();
    final results = await container.read(placementResultsProvider.future);
    // veh-zil131 is the wheeled one; it used to come back with no required
    // hardware and no check at all.
    expect(results[ids[1]]!.requiredHardwareIds, contains('att-wood-chock'));
  });

  test('the weight on the record reaches the engineering path', () async {
    await seedTwoVehiclesOnOneWagon();
    final vehicle = container
        .read(effectiveVehiclesProvider)
        .firstWhere((v) => v.id == 'veh-t-62');
    // The transport table states 40 t without saying which weight it is. The
    // handbook's weight-keyed tables read it anyway: withholding it left them
    // undecidable for the whole catalogue.
    expect(vehicle.weightT.asDouble, 40.0);
    expect(vehicle.bracketWeightT.asDouble, 40.0);

    // A typed figure does not overwrite a stated one — the door is for the
    // records whose weight column is blank.
    container
        .read(userDimensionsProvider.notifier)
        .set(UserDimensionsNotifier.weightKey('veh-t-62'), 26.5);
    final after = container
        .read(effectiveVehiclesProvider)
        .firstWhere((v) => v.id == 'veh-t-62');
    expect(after.bracketWeightT.asDouble, 40.0);
  });

  test('deleting a placement clears all three of its per-placement stores', () async {
    final ids = await seedTwoVehiclesOnOneWagon();
    final doomed = ids.first;

    container.read(placementEquipmentProvider.notifier).select(doomed, 'att-wood-chock', 'x');
    container.read(placementSecuringMethodProvider.notifier).apply(doomed, 3);
    container
        .read(placementChockChoiceProvider.notifier)
        .chooseArrangement(doomed, 'tracked-seating-standard');

    container.read(consistProvider.notifier).remove(doomed);

    expect(container.read(placementEquipmentProvider).containsKey(doomed), isFalse);
    expect(container.read(placementSecuringMethodProvider).containsKey(doomed), isFalse);
    expect(container.read(placementChockChoiceProvider).containsKey(doomed), isFalse);
  });

  test('rebuilding the train prunes the state of placements it drops', () async {
    final ids = await seedTwoVehiclesOnOneWagon();
    container.read(placementSecuringMethodProvider.notifier).apply(ids.first, 3);

    // Rebuilding with zero wagons drops every placement.
    final platforms = await container.read(platformsProvider.future);
    container
        .read(consistProvider.notifier)
        .setWagons(count: 0, platformId: platforms.first.id);

    expect(container.read(consistProvider).placements, isEmpty);
    expect(container.read(placementSecuringMethodProvider), isEmpty);
  });

  test('the deck budget charges one gap between two vehicles', () async {
    final ids = await seedTwoVehiclesOnOneWagon();
    final platforms = await container.read(platformsProvider.future);
    container
        .read(userDimensionsProvider.notifier)
        .set(UserDimensionsNotifier.deckKey(platforms.first.id), 1340);
    container
        .read(userDimensionsProvider.notifier)
        .set(UserDimensionsNotifier.vehicleKey('veh-t-62'), 670);

    final budget = container.read(wagonBudgetProvider('wagon-1'))!;
    expect(ids, hasLength(2));
    expect(budget.gapCount, 1);
    // T-34 (tracked) beside ZIL-131 (wheeled) is the mixed-row case: 270 mm.
    expect(budget.gapMm, 270);
    expect(budget.deckLengthCm, 1340);
  });

  test('a chosen arrangement reaches the diagram', () async {
    final ids = await seedTwoVehiclesOnOneWagon();
    final arrangements = container.read(placementChockArrangementsProvider(ids.first));
    expect(arrangements, isNotEmpty);
    container
        .read(placementChockChoiceProvider.notifier)
        .chooseArrangement(ids.first, arrangements.first.id);
    final selected = container.read(placementSelectedArrangementProvider(ids.first));
    expect(selected, isA<ChockArrangement>());
    expect(selected!.id, arrangements.first.id);
  });



  test('deleting a placement drops its measured angles but keeps the weight',
      () async {
    final ids = await seedTwoVehiclesOnOneWagon();
    final lorry = ids[1];
    final dimensions = container.read(userDimensionsProvider.notifier);
    dimensions.set(UserDimensionsNotifier.weightKey('veh-zil131'), 10.0);
    dimensions.set(UserDimensionsNotifier.lashingAxisAngleKey(lorry), 30);
    dimensions.set(UserDimensionsNotifier.lashingFloorAngleKey(lorry), 40);

    container.read(consistProvider.notifier).remove(lorry);

    final state = container.read(userDimensionsProvider);
    expect(state.containsKey(UserDimensionsNotifier.lashingAxisAngleKey(lorry)), isFalse);
    expect(state.containsKey(UserDimensionsNotifier.lashingFloorAngleKey(lorry)), isFalse);
    // A vehicle's weight belongs to the vehicle, not to one placement of it:
    // an instructor who re-places the same lorry should not retype it.
    expect(state[UserDimensionsNotifier.weightKey('veh-zil131')], 10.0);
  });

  test('a deck budget that fits does not pass the guard-wagon rule', () async {
    // The fallback for a vehicle with no mesh spec read
    // `remaining < 0 ? excess : 0`, and `checkGuardWagon` passes a zero. So a
    // budget that came out positive declared "no guard wagon required" about a
    // position nothing had computed — the deck budget compares lengths and
    // knows nothing about where the machine was put. T-62 has no mesh spec, so
    // it takes the fallback.
    await loadCatalogue();
    final platforms = await container.read(platformsProvider.future);
    container.read(selectedWagonTypeProvider.notifier).state = platforms.first.id;
    container
        .read(consistProvider.notifier)
        .setWagons(count: 1, platformId: platforms.first.id);
    container
        .read(consistProvider.notifier)
        .place(vehicleId: 'veh-t-62', wagonIds: ['wagon-1']);

    final dimensions = container.read(userDimensionsProvider.notifier);
    dimensions.set(UserDimensionsNotifier.deckKey(platforms.first.id), 1330);

    // The budget is computable and the machine fits with room to spare.
    final budget = container.read(wagonBudgetProvider('wagon-1'))!;
    expect(budget.isComputable, isTrue);
    expect(budget.remainingCm, greaterThan(0));
    expect(container.read(wagonOverhangProvider('wagon-1')), isNull,
        reason: 'the fixture depends on this vehicle having no mesh spec');

    final guard = container
        .read(consistChecksProvider)
        .firstWhere((c) => c.ruleId == 'rule-overhang-guard-wagon');
    expect(guard.status, CheckStatus.unknown,
        reason: 'fitting on paper is not a measurement of either end');
  });

  test('an overloaded deck still fails the guard-wagon rule when it must',
      () async {
    // The one direction a length comparison can still prove: a load longer
    // than its deck hangs off somewhere, and the longer end carries at least
    // half the excess. Half of a metre of excess is 500 mm, past the 400 mm
    // limit, so the failure is certain without knowing the position.
    await loadCatalogue();
    final platforms = await container.read(platformsProvider.future);
    container.read(selectedWagonTypeProvider.notifier).state = platforms.first.id;
    container
        .read(consistProvider.notifier)
        .setWagons(count: 1, platformId: platforms.first.id);
    container
        .read(consistProvider.notifier)
        .place(vehicleId: 'veh-t-62', wagonIds: ['wagon-1']);

    final dimensions = container.read(userDimensionsProvider.notifier);
    dimensions.set(UserDimensionsNotifier.deckKey(platforms.first.id), 500);

    final guard = container
        .read(consistChecksProvider)
        .firstWhere((c) => c.ruleId == 'rule-overhang-guard-wagon');
    expect(guard.status, CheckStatus.fail);
  });

  test('a spur vehicle that cannot be modelled does not pass its station check',
      () async {
    // `placementSpurFindingsProvider` skips a vehicle with no mesh spec, so
    // `ironSpurChecks` was handed an empty finding list — and an empty list of
    // wrong stations read as "every station is right". Five of the six
    // spur-named vehicles in the catalogue have no spec, so a T-72K with not
    // one spur on it passed `rule-iron-spur-stations`.
    await loadCatalogue();
    final platforms = await container.read(platformsProvider.future);
    container.read(selectedWagonTypeProvider.notifier).state = platforms.first.id;
    container
        .read(consistProvider.notifier)
        .setWagons(count: 1, platformId: platforms.first.id);
    final id = container
        .read(consistProvider.notifier)
        .place(vehicleId: 'veh-t-72k', wagonIds: ['wagon-1']);

    expect(container.read(placementSpurFindingsProvider)[id], isNull,
        reason: 'the fixture depends on this vehicle having no mesh spec');

    final stations = container
        .read(spurChecksProvider)
        .firstWhere((c) => c.ruleId == 'rule-iron-spur-stations');
    expect(stations.status, isNot(CheckStatus.pass),
        reason: 'nothing was placed and nothing was measured');
  });

  test('a chock layout case is not correct merely for having a high enough top',
      () async {
    // plate-06's wheeled cases are brackets: four chocks up to 5.5 t, eight
    // for 5.6-12 t. `ChockArrangement.matches` only ever read the top of the
    // bracket, so the eight-chock case matched a 3.25 t lorry as happily as
    // the four-chock one and the trainee was marked correct either way.
    await loadCatalogue();
    final platforms = await container.read(platformsProvider.future);
    container.read(selectedWagonTypeProvider.notifier).state = platforms.first.id;
    container
        .read(consistProvider.notifier)
        .setWagons(count: 1, platformId: platforms.first.id);
    final id = container
        .read(consistProvider.notifier)
        .place(vehicleId: 'veh-gaz-53-yuk', wagonIds: ['wagon-1']);

    final arrangements = container.read(placementChockArrangementsProvider(id));
    final heavy = arrangements.firstWhere((a) => a.id == 'wheeled-2axle-5-6-12t');
    final light = arrangements.firstWhere((a) => a.id == 'wheeled-2axle-le-5-5t');

    container.read(placementChockChoiceProvider.notifier)
        .chooseArrangement(id, heavy.id);
    var results = await container.read(placementResultsProvider.future);
    expect(
        results[id]!
            .checks
            .firstWhere((c) => c.ruleId == 'rule-chock-arrangement-selected')
            .status,
        CheckStatus.fail,
        reason: 'a 3.25 t lorry is not in the 5.6-12 t bracket');

    container.read(placementChockChoiceProvider.notifier)
        .chooseArrangement(id, light.id);
    results = await container.read(placementResultsProvider.future);
    expect(
        results[id]!
            .checks
            .firstWhere((c) => c.ruleId == 'rule-chock-arrangement-selected')
            .status,
        CheckStatus.pass,
        reason: 'the case the plate draws for it must still pass');
  });
}
