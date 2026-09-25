import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/chock_arrangement.dart';
import 'package:railsim/domain/usecases/chock_detail_spec.dart';
import 'package:railsim/domain/usecases/equipment_catalog.dart';
import 'package:railsim/domain/usecases/equipment_selection.dart';
import 'package:railsim/domain/usecases/wood_chock_sizing.dart';
import 'package:railsim/domain/usecases/chock_layout.dart';
import 'package:railsim/domain/usecases/chock_arrangement_catalog.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({
  VehicleCategory category = VehicleCategory.wheeled,
  HandbookField? weightT,
  int? axleCount,
}) =>
    Vehicle(
      id: 'veh-x',
      handbookDesignation: 'veh-x',
      category: category,
      vehicleClass: 'x',
      lengthCm: _todo,
      widthCm: _todo,
      heightCm: _todo,
      weightT: weightT ?? _todo,
      groundClearanceCm: _todo,
      trackWidthMm: _todo,
      wheelBaseCm: _todo,
      axleCount: axleCount,
      manufacturer: 'x',
      country: 'x',
      approvedSecuringHardwareIds: const [],
      referenceId: 'plate-05',
    );

Map<String, dynamic> _rules() =>
    jsonDecode(File('assets/data/rules.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  final rules = _rules();

  group('tracked arrangements', () {
    final arrangements = chockArrangementsFor(
      _vehicle(category: VehicleCategory.tracked),
      overCoupling: false,
      rules: rules,
    );

    test('offers both seating distances the plate draws', () {
      expect(arrangements.map((a) => a.id),
          containsAll(['tracked-seating-standard', 'tracked-seating-alternate']));
      expect(arrangements.first.seatingDistance, (minCm: 10, maxCm: 15));
      expect(arrangements.last.seatingDistance, (minCm: 10, maxCm: 20));
    });

    test('carries the plate\'s four chocks and four inserts', () {
      // "Her bir zynjyrly maşyn dört sany direg agaç bölekleri we keseligine
      // dört sany ýarym aýlaw agaç bölekleri arkaly berkidilýär" — plate-02.
      for (final arrangement in arrangements) {
        expect(arrangement.chockCount, 4);
        expect(arrangement.insertCount, 4);
        expect(arrangement.referenceId, isNotEmpty);
      }
    });

    test('a tracked vehicle is never given the wheeled layout cases', () {
      for (final arrangement in arrangements) {
        expect(arrangement.appliesTo, VehicleCategory.tracked);
      }
    });
  });

  group('wheeled arrangements', () {
    test('the single-wagon and over-coupling cases are separate sets', () {
      final onWagon = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules);
      final overCoupling = chockArrangementsFor(_vehicle(), overCoupling: true, rules: rules);
      expect(onWagon, hasLength(3));
      expect(overCoupling, hasLength(3));
      for (final a in onWagon) {
        expect(a.spansCoupling, isFalse);
      }
      for (final a in overCoupling) {
        expect(a.spansCoupling, isTrue);
      }
    });

    test('counts follow the weight bracket, with the doubling applied', () {
      final onWagon = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules);
      final light = onWagon.firstWhere((a) => a.id == 'wheeled-2axle-le-5-5t');
      final heavy = onWagon.firstWhere((a) => a.id == 'wheeled-2axle-5-6-12t');
      final threeAxle = onWagon.firstWhere((a) => a.id == 'wheeled-3axle');
      expect(light.chockCount, 4);
      expect(heavy.chockCount, 8);
      // Doubled at the middle and rear axle tyres of a three-axle vehicle.
      expect(threeAxle.doubled, isTrue);
      expect(threeAxle.chockCount, 16);
      expect(threeAxle.doublingReason, isNotNull);
    });

    test('the lateral gap tightens over a coupling', () {
      final onWagon = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules);
      final overCoupling = chockArrangementsFor(_vehicle(), overCoupling: true, rules: rules);
      expect(onWagon.first.lateralGap, (minMm: 20, maxMm: 30));
      expect(overCoupling.first.lateralGap, (minMm: 15, maxMm: 20));
    });
  });

  group('lateral restraint', () {
    test('a tracked vehicle gets the two alternatives the plate joins with "or"', () {
      final options =
          lateralRestraintOptionsFor(_vehicle(category: VehicleCategory.tracked), rules);
      expect(options.map((o) => o.id), ['lateral-staples', 'lateral-side-blocks']);
      expect(options.first.staples, 12);
      expect(options.last.blockSizeMm, '100*100*2000');
    });

    test('a wheeled vehicle is offered none — the plate gives this choice for tracked only', () {
      expect(lateralRestraintOptionsFor(_vehicle(), rules), isEmpty);
    });
  });

  group('recommendedArrangement', () {
    test('is null with no combat weight, so nothing is pre-selected on a guess', () {
      final arrangements = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules);
      expect(
        recommendedArrangement(_vehicle(axleCount: 2), arrangements, overCoupling: false),
        isNull,
      );
    });

    test('picks the bracket the handbook draws when the weight is known', () {
      final arrangements = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules);
      final vehicle = _vehicle(weightT: const HandbookField(4.0), axleCount: 2);
      expect(
        recommendedArrangement(vehicle, arrangements, overCoupling: false)?.id,
        'wheeled-2axle-le-5-5t',
      );
    });

    test('a three-axle vehicle gets the three-axle case, not the two-axle one', () {
      final arrangements = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules);
      final vehicle = _vehicle(weightT: const HandbookField(9.0), axleCount: 3);
      expect(
        recommendedArrangement(vehicle, arrangements, overCoupling: false)?.id,
        'wheeled-3axle',
      );
    });
  });

  group('checkChockArrangement', () {
    final wheeled = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules);
    final overCoupling = chockArrangementsFor(_vehicle(), overCoupling: true, rules: rules);

    test('nothing chosen is UNKNOWN, never a quiet pass', () {
      final check = checkChockArrangement(
          vehicle: _vehicle(), chosen: null, spansCoupling: false);
      expect(check.status, CheckStatus.unknown);
      expect(check.referenceId, isNotEmpty);
    });

    test('a case drawn for a coupling fails on a vehicle standing on one wagon', () {
      // This is the one part that is checkable without a weight, because
      // spanning a coupling is a fact the placement carries.
      final check = checkChockArrangement(
        vehicle: _vehicle(),
        chosen: overCoupling.first,
        spansCoupling: false,
      );
      expect(check.status, CheckStatus.fail);
    });

    test('a right case with no combat weight stays UNKNOWN', () {
      final check = checkChockArrangement(
        vehicle: _vehicle(axleCount: 2),
        chosen: wheeled.first,
        spansCoupling: false,
      );
      expect(check.status, CheckStatus.unknown);
      expect(check.detail, contains('agramy'));
    });

    test('the matching bracket passes and a wrong one fails, once the weight is known', () {
      final light = _vehicle(weightT: const HandbookField(4.0), axleCount: 2);
      expect(
        checkChockArrangement(
                vehicle: light, chosen: wheeled.first, spansCoupling: false)
            .status,
        CheckStatus.pass,
      );
      final heavy = _vehicle(weightT: const HandbookField(11.0), axleCount: 2);
      expect(
        checkChockArrangement(
                vehicle: heavy,
                chosen: wheeled.firstWhere((a) => a.id == 'wheeled-2axle-le-5-5t'),
                spansCoupling: false)
            .status,
        CheckStatus.fail,
      );
    });
  });

  group('ChockLayout', () {
    test('draws one position per pair, spread across the vehicle', () {
      const arrangement = ChockArrangement(
        id: 'x',
        appliesTo: VehicleCategory.wheeled,
        label: 'x',
        chockCount: 8,
        referenceId: 'plate-06',
      );
      final xs = ChockLayout.chockPairPositions(arrangement,
          vehicleLeft: 0.30, vehicleRight: 0.70);
      expect(xs, hasLength(4));
      expect(xs.first, greaterThan(0.30));
      expect(xs.last, lessThan(0.70));
      for (var i = 1; i < xs.length; i++) {
        expect(xs[i], greaterThan(xs[i - 1]));
      }
    });

    test('a bigger count really draws more chocks — the old drawing never changed', () {
      const four = ChockArrangement(
          id: 'a', appliesTo: VehicleCategory.wheeled, label: 'a', chockCount: 4,
          referenceId: 'plate-06');
      const sixteen = ChockArrangement(
          id: 'b', appliesTo: VehicleCategory.wheeled, label: 'b', chockCount: 16,
          referenceId: 'plate-06');
      expect(
        ChockLayout.chockPairPositions(four, vehicleLeft: 0.3, vehicleRight: 0.7).length,
        lessThan(ChockLayout
            .chockPairPositions(sixteen, vehicleLeft: 0.3, vehicleRight: 0.7)
            .length),
      );
    });

    test('inserts sit inboard of the chocks, and only where the case has them', () {
      const tracked = ChockArrangement(
          id: 't', appliesTo: VehicleCategory.tracked, label: 't', chockCount: 4,
          insertCount: 4, referenceId: 'plate-02');
      const wheeledCase = ChockArrangement(
          id: 'w', appliesTo: VehicleCategory.wheeled, label: 'w', chockCount: 4,
          referenceId: 'plate-06');
      final inserts =
          ChockLayout.insertPairPositions(tracked, vehicleLeft: 0.3, vehicleRight: 0.7);
      final chocks =
          ChockLayout.chockPairPositions(tracked, vehicleLeft: 0.3, vehicleRight: 0.7);
      expect(inserts, hasLength(2));
      expect(inserts.first, greaterThan(chocks.first));
      expect(inserts.last, lessThan(chocks.last));
      expect(
          ChockLayout.insertPairPositions(wheeledCase,
              vehicleLeft: 0.3, vehicleRight: 0.7),
          isEmpty);
    });
  });

  group('chockDetailSpec', () {
    test('collects the plate figures the detail drawings letter on', () {
      final wheeled = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules);
      final spec = chockDetailSpec(rules: rules, arrangement: wheeled.first);
      expect(spec.nailsPerLongitudinalChock, 4);
      expect(spec.nailsPerLateralChock, 6);
      expect(spec.nailDiameterMm, 6);
      expect(spec.nailLengthMm, 200);
      expect(spec.stapleMinDiameterMm, 12);
      expect(spec.maxOverhangMm, 400);
      expect(spec.lateralGap, (minMm: 20, maxMm: 30));
      expect(spec.isEmpty, isFalse);
    });

    test('carries the tracked seating distance when that case is chosen', () {
      final tracked = chockArrangementsFor(
          _vehicle(category: VehicleCategory.tracked),
          overCoupling: false,
          rules: rules);
      final spec = chockDetailSpec(rules: rules, arrangement: tracked.last);
      expect(spec.seating, (minCm: 10, maxCm: 20));
    });

    test('invents nothing when the rules are absent', () {
      final spec = chockDetailSpec(rules: const {'rules': []}, arrangement: null);
      expect(spec.isEmpty, isTrue);
      expect(spec.nailsPerLongitudinalChock, isNull);
      expect(spec.maxOverhangMm, isNull);
    });
  });

  group('regressions', () {
    test('a tracked vehicle over a coupling is not failed for its seating case', () {
      // The tracked seating distances apply on one wagon and across a
      // coupling alike; building them with a hardcoded spansCoupling:false
      // made every such placement fail whichever case was chosen.
      final arrangements = chockArrangementsFor(
        _vehicle(category: VehicleCategory.tracked),
        overCoupling: true,
        rules: rules,
      );
      expect(arrangements, isNotEmpty);
      for (final arrangement in arrangements) {
        expect(arrangement.spansCoupling, isTrue);
        final check = checkChockArrangement(
          vehicle: _vehicle(category: VehicleCategory.tracked),
          chosen: arrangement,
          spansCoupling: true,
        );
        expect(check.status, isNot(CheckStatus.fail), reason: arrangement.id);
      }
    });

    test('a wheeled chock size comes from Table 2, not the tracked weight table', () {
      // Table 2 is keyed on wheel diameter and uses bracket wordings the
      // parser did not understand ("under 500", "1600 and above").
      final measurements = jsonDecode(
              File('assets/data/measurements.json').readAsStringSync())
          as Map<String, dynamic>;
      expect(matchingWheelChockDiameterRange(450, measurements), 'under 500');
      expect(matchingWheelChockDiameterRange(1700, measurements), '1600 and above');
      expect(matchingWheelChockDiameterRange(900, measurements), '800-1099');
      expect(wheelChockDimensionsForRange('800-1099', measurements),
          (heightMm: 75, widthMm: 120));

      final wheeledOptions = equipmentOptionsFor(
          'att-wood-chock', measurements, const [],
          category: VehicleCategory.wheeled);
      final trackedOptions = equipmentOptionsFor(
          'att-wood-chock', measurements, const [],
          category: VehicleCategory.tracked);
      expect(wheeledOptions.map((o) => o.typeCode), contains('under 500 mm'));
      expect(trackedOptions.map((o) => o.typeCode), contains('up to 12.0 t'));
      expect(wheeledOptions.map((o) => o.typeCode),
          isNot(contains('up to 12.0 t')));
    });

    test('a wheeled vehicle is never handed a tracked weight bracket as mandatory', () {
      final measurements = jsonDecode(
              File('assets/data/measurements.json').readAsStringSync())
          as Map<String, dynamic>;
      final lorry = _vehicle(
          category: VehicleCategory.wheeled,
          weightT: const HandbookField(8.0));
      expect(
        requiredTypeCodeFor('att-wood-chock', lorry, measurements: measurements),
        isNull,
      );
    });
  });
}
