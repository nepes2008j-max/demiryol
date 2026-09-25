import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/usecases/chock_arrangement_catalog.dart';
import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/domain/usecases/consumables.dart';
import 'package:railsim/domain/usecases/wire_lashing_angle.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Map<String, dynamic> _measurements() =>
    jsonDecode(File('assets/data/measurements.json').readAsStringSync())
        as Map<String, dynamic>;
Map<String, dynamic> _rules() =>
    jsonDecode(File('assets/data/rules.json').readAsStringSync()) as Map<String, dynamic>;

Vehicle _vehicle({
  HandbookField? weightT,
  VehicleCategory category = VehicleCategory.tracked,
}) =>
    Vehicle(
      id: 'veh-x',
      handbookDesignation: 'T-34',
      category: category,
      vehicleClass: 'x',
      lengthCm: _todo,
      widthCm: _todo,
      heightCm: _todo,
      weightT: weightT ?? _todo,
      groundClearanceCm: _todo,
      trackWidthMm: _todo,
      wheelBaseCm: _todo,
      manufacturer: 'x',
      country: 'x',
      approvedSecuringHardwareIds: const [],
      referenceId: 'para-21',
    );

void main() {
  final measurements = _measurements();
  final rules = _rules();
  final trackedCase = chockArrangementsFor(_vehicle(), overCoupling: false, rules: rules).first;

  ConsumableLine lineNamed(List<ConsumableLine> lines, String name) =>
      lines.firstWhere((l) => l.name == name);

  group('consumables', () {
    test('multiplies the nails out from the chock count and the plate rule', () {
      final lines = consumablesFor(
        vehicle: _vehicle(weightT: const HandbookField(26.0)),
        arrangement: trackedCase,
        requiredHardwareIds: const ['att-wood-chock', 'att-wire-lashing'],
        measurements: measurements,
        rules: rules,
      );
      final chocks = lineNamed(lines, 'Direg dörtgyraň agaç bölegi');
      final nails = lineNamed(lines, 'Çüý');
      expect(chocks.quantity, 4);
      // Four chocks at four 6x200 nails each.
      expect(nails.quantity, 16);
      expect(nails.specification, '6 mm x 200 mm');
    });

    test('resolves the chock size from the weight bracket', () {
      final lines = consumablesFor(
        vehicle: _vehicle(weightT: const HandbookField(26.0)),
        arrangement: trackedCase,
        requiredHardwareIds: const ['att-wood-chock'],
        measurements: measurements,
        rules: rules,
      );
      // Over 18 t: 180 x 200 mm.
      expect(lineNamed(lines, 'Direg dörtgyraň agaç bölegi').specification, '180x200 mm');
    });

    test('wire and staples come from TABLISSA No.1 for the weight bracket', () {
      final lines = consumablesFor(
        vehicle: _vehicle(weightT: const HandbookField(26.0)),
        arrangement: trackedCase,
        requiredHardwareIds: const ['att-wood-chock', 'att-wire-lashing'],
        measurements: measurements,
        rules: rules,
      );
      // 25.1-50.0 t: 85 m of wire, 8 strands per lashing, 12 staples.
      expect(lineNamed(lines, 'Sim (bir nusgaly çekmeler üçin)').quantity, 85);
      expect(lineNamed(lines, 'Ýaý şekilli demir skoba').quantity, 12);
    });

    test('an item whose quantity needs a missing figure is still listed, with why', () {
      // Dropping it would understate the job; inventing a number would be
      // worse. It is listed unresolved.
      final lines = consumablesFor(
        vehicle: _vehicle(),
        arrangement: trackedCase,
        requiredHardwareIds: const ['att-wood-chock', 'att-wire-lashing'],
        measurements: measurements,
        rules: rules,
      );
      final wire = lineNamed(lines, 'Sim (bir nusgaly çekmeler üçin)');
      expect(wire.quantity, isNull);
      expect(wire.isResolved, isFalse);
      expect(wire.note, isNotNull);
      // The chock count does not depend on weight, so it still resolves.
      expect(lineNamed(lines, 'Direg dörtgyraň agaç bölegi').quantity, 4);
    });

    test('reusable fittings are listed as a four-piece set, not consumed', () {
      final lines = consumablesFor(
        vehicle: _vehicle(weightT: const HandbookField(20.0)),
        arrangement: trackedCase,
        requiredHardwareIds: const ['att-kguub-1g'],
        measurements: measurements,
        rules: rules,
      );
      final set = lineNamed(lines, 'KGUUB uniwersal berkidiji (toplum)');
      expect(set.quantity, 4);
    });

    test('every line carries a citation', () {
      final lines = consumablesFor(
        vehicle: _vehicle(weightT: const HandbookField(20.0)),
        arrangement: trackedCase,
        requiredHardwareIds: const ['att-wood-chock', 'att-wire-lashing'],
        measurements: measurements,
        rules: rules,
      );
      expect(lines, isNotEmpty);
      for (final line in lines) {
        expect(line.referenceId, isNotEmpty, reason: line.name);
      }
    });
  });

  group('Table 7 strand count', () {
    test('reads the grid by axis angle (row) and floor angle (column)', () {
      expect(
        lashingStrandCount(axisAngleDeg: 30, floorAngleDeg: 30, measurements: measurements)
            .strands,
        2,
      );
      expect(
        lashingStrandCount(axisAngleDeg: 48, floorAngleDeg: 30, measurements: measurements)
            .strands,
        3,
      );
    });

    test('an illegible cell is an unknown, never a verdict', () {
      // The table's own note records that a few interior cells could not be
      // read off the plate. Reporting one of those as a forbidden combination
      // would be inventing a handbook prohibition out of a bad scan.
      final lookup =
          lashingStrandCount(axisAngleDeg: 78, floorAngleDeg: 58, measurements: measurements);
      expect(lookup.strands, isNull);
      expect(lookup.cellNotLegible, isTrue);
      expect(lookup.outsideTable, isFalse);

    });

    test('angles beyond the table are reported as outside it', () {
      final lookup =
          lashingStrandCount(axisAngleDeg: 95, floorAngleDeg: 30, measurements: measurements);
      expect(lookup.outsideTable, isTrue);
    });

    test('the wire line names both strand sources when they disagree', () {
      // plate-03 gives the strand count by weight, Table 7 by the measured
      // angles. Where they differ the list must say so rather than printing
      // one of them alone.
      final lines = consumablesFor(
        vehicle: _vehicle(weightT: const HandbookField(26.0)),
        arrangement: null,
        requiredHardwareIds: const ['att-wire-lashing'],
        measurements: measurements,
        rules: rules,
        strandsFromMeasuredAngles: 2,
      );
      final wire = lineNamed(lines, AppStrings.consumableWire);
      expect(wire.note, isNotNull);
      expect(wire.note, contains('2'));

      final agreeing = consumablesFor(
        vehicle: _vehicle(weightT: const HandbookField(26.0)),
        arrangement: null,
        requiredHardwareIds: const ['att-wire-lashing'],
        measurements: measurements,
        rules: rules,
        // What TABLISSA No.1 itself gives at this weight.
        strandsFromMeasuredAngles: 8,
      );
      expect(
        lineNamed(agreeing, AppStrings.consumableWire).note,
        isNull,
        reason: 'agreement is not something to warn about',
      );
    });
  });

  group('lashing angle table', () {
    test('maxFloorAngleDeg comes from the data, not a constant in code', () {
      expect(maxFloorAngleDeg(measurements), 45);
    });
  });
}
