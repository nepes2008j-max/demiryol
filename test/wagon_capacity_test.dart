import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/usecases/wagon_capacity.dart';

Map<String, dynamic> _rules() =>
    jsonDecode(File('assets/data/rules.json').readAsStringSync()) as Map<String, dynamic>;

VehicleOnWagon _v(
  String name, {
  double? lengthCm,
  VehicleCategory category = VehicleCategory.tracked,
  bool spans = false,
  bool primary = true,
}) =>
    VehicleOnWagon(
      placementId: 'p-$name',
      designation: name,
      category: category,
      lengthCm: lengthCm,
      spansCoupling: spans,
      isPrimaryWagon: primary,
    );

void main() {
  final rules = _rules();

  group('clearanceBetween', () {
    test('two tracked vehicles on one flatcar take the 100 mm the plate dimensions', () {
      final gap = clearanceBetween(
          VehicleCategory.tracked, VehicleCategory.tracked, rules);
      expect(gap?.mm, 100);
      expect(gap?.referenceId, isNotEmpty);
    });

    test('two wheeled vehicles in a row take 50 mm', () {
      expect(
        clearanceBetween(VehicleCategory.wheeled, VehicleCategory.wheeled, rules)?.mm,
        50,
      );
    });

    test('a mixed pair takes the mixed-row figure', () {
      expect(
        clearanceBetween(VehicleCategory.tracked, VehicleCategory.wheeled, rules)?.mm,
        270,
      );
    });
  });

  group('wagonLengthBudget', () {
    test('one vehicle uses no clearance — a gap needs two vehicles', () {
      final budget = wagonLengthBudget(
        deckLengthCm: 1340,
        vehicles: [_v('T-34', lengthCm: 670)],
        rules: rules,
      );
      expect(budget.clearanceCm, 0);
      expect(budget.usedCm, 670);
      expect(budget.remainingCm, 670);
      expect(budget.isOverloaded, isFalse);
    });

    test('two vehicles are charged exactly one gap between them', () {
      final budget = wagonLengthBudget(
        deckLengthCm: 1340,
        vehicles: [_v('T-34', lengthCm: 670), _v('T-54', lengthCm: 620)],
        rules: rules,
      );
      // 100 mm = 10 cm, once, not twice.
      expect(budget.clearanceCm, 10);
      expect(budget.usedCm, 1300);
      expect(budget.remainingCm, 40);
      expect(budget.gapMm, 100);
    });

    test('a load longer than the deck reports as overloaded, by how much', () {
      final budget = wagonLengthBudget(
        deckLengthCm: 1340,
        vehicles: [_v('T-34', lengthCm: 670), _v('IS-4', lengthCm: 900)],
        rules: rules,
      );
      expect(budget.isOverloaded, isTrue);
      expect(budget.remainingCm, closeTo(-240, 0.001));
      expect(checkWagonCapacity(budget).status, CheckStatus.fail);
    });

    test('a missing deck length makes the budget uncomputable, never a guess', () {
      final budget = wagonLengthBudget(
        deckLengthCm: null,
        vehicles: [_v('T-34', lengthCm: 670)],
        rules: rules,
      );
      expect(budget.isComputable, isFalse);
      expect(budget.remainingCm, isNull);
      expect(budget.usedFraction, isNull);
      final check = checkWagonCapacity(budget);
      expect(check.status, CheckStatus.unknown);
    });

    test('a vehicle with no length is named rather than counted as zero', () {
      final budget = wagonLengthBudget(
        deckLengthCm: 1340,
        vehicles: [_v('T-34', lengthCm: 670), _v('IS-4')],
        rules: rules,
      );
      expect(budget.vehiclesWithoutLength, ['IS-4']);
      expect(budget.isComputable, isFalse);
      expect(checkWagonCapacity(budget).status, CheckStatus.unknown);
      expect(checkWagonCapacity(budget).detail, contains('IS-4'));
    });

    test('a coupling-spanning vehicle is charged to one wagon only', () {
      final onFirst = wagonLengthBudget(
        deckLengthCm: 1340,
        vehicles: [_v('ZIL-131', lengthCm: 704, category: VehicleCategory.wheeled,
            spans: true, primary: true)],
        rules: rules,
      );
      final onSecond = wagonLengthBudget(
        deckLengthCm: 1340,
        vehicles: [_v('ZIL-131', lengthCm: 704, category: VehicleCategory.wheeled,
            spans: true, primary: false)],
        rules: rules,
      );
      expect(onFirst.vehiclesLengthCm, 704);
      expect(onSecond.vehiclesLengthCm, 0, reason: 'must not be charged twice');
      expect(onSecond.spanningVehicles, ['ZIL-131']);
    });

    test('a full deck passes and reports what is left', () {
      final budget = wagonLengthBudget(
        deckLengthCm: 1340,
        vehicles: [
          _v('ZIL-131', lengthCm: 704, category: VehicleCategory.wheeled),
          _v('Ural-4320', lengthCm: 600, category: VehicleCategory.wheeled),
        ],
        rules: rules,
      );
      expect(budget.clearanceCm, 5); // 50 mm between wheeled vehicles
      expect(budget.remainingCm, closeTo(31, 0.001));
      expect(budget.usedFraction, closeTo(1309 / 1340, 0.0001));
      final check = checkWagonCapacity(budget);
      expect(check.status, CheckStatus.pass);
      expect(check.detail, contains('31'));
    });
  });

  group('regressions', () {
    test('a mixed three-vehicle load reports two gaps, not one', () {
      // The panel used to derive the gap count by dividing the total
      // clearance by the LARGEST gap, so a 100 mm gap next to a 270 mm one
      // came out as a single gap.
      final budget = wagonLengthBudget(
        deckLengthCm: 2000,
        vehicles: [
          _v('T-34', lengthCm: 600),
          _v('T-54', lengthCm: 600),
          _v('ZIL-131', lengthCm: 600, category: VehicleCategory.wheeled),
        ],
        rules: rules,
      );
      expect(budget.gapCount, 2);
      // 100 mm between the two tracked + 270 mm tracked-to-wheeled = 37 cm.
      expect(budget.clearanceCm, closeTo(37, 0.001));
      expect(budget.gapMm, 270, reason: 'the binding case is the larger gap');
      expect(budget.usedCm, closeTo(1837, 0.001));
    });

    test('gap count is zero for a single vehicle and never negative', () {
      final one = wagonLengthBudget(
          deckLengthCm: 1340, vehicles: [_v('T-34', lengthCm: 600)], rules: rules);
      final none = wagonLengthBudget(deckLengthCm: 1340, vehicles: const [], rules: rules);
      expect(one.gapCount, 0);
      expect(none.gapCount, 0);
      expect(none.usedCm, 0);
    });
  });
}
