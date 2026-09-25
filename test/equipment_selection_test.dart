import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/usecases/equipment_selection.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

const _measurements = {
  'trackChockByWeightTable': {
    'rows': [
      {'combatWeightRangeT': 'up to 12.0', 'chockHeightMm': 75, 'chockWidthMm': 150},
      {'combatWeightRangeT': '12.1-18.0', 'chockHeightMm': 100, 'chockWidthMm': 180},
    ],
  },
};

Vehicle _vehicle({String? ironSpurType, String? ironChockBootType, HandbookField? weightT}) => Vehicle(
      id: 'veh-x',
      handbookDesignation: 'veh-x',
      category: VehicleCategory.tracked,
      vehicleClass: 'TODO: Fill from Handbook Page XX',
      lengthCm: _todo,
      widthCm: _todo,
      heightCm: _todo,
      weightT: weightT ?? _todo,
      groundClearanceCm: _todo,
      trackWidthMm: _todo,
      wheelBaseCm: _todo,
      manufacturer: 'TODO: Fill from Handbook Page XX',
      country: 'TODO: Fill from Handbook Page XX',
      approvedSecuringHardwareIds: const [],
      ironSpurType: ironSpurType,
      ironChockBootType: ironChockBootType,
      referenceId: 'para-31',
    );

void main() {
  group('requiredTypeCodeFor', () {
    test('iron spur/chock-boot slots resolve to the vehicle\'s own field', () {
      expect(requiredTypeCodeFor('att-iron-spur', _vehicle(ironSpurType: 'Ş-303')), 'Ş-303');
      expect(
        requiredTypeCodeFor('att-iron-chock-boot', _vehicle(ironChockBootType: 'KT-137')),
        'KT-137',
      );
    });

    test('KGUUB tracked slots resolve to a fixed type label', () {
      expect(requiredTypeCodeFor('att-kguub-1g', _vehicle()), 'KGUUB-1G');
      expect(requiredTypeCodeFor('att-kguub-2g', _vehicle()), 'KGUUB-2G');
    });

    test('a slot the handbook does not fix to one type (e.g. wire lashing) returns null', () {
      expect(requiredTypeCodeFor('att-wire-lashing', _vehicle()), isNull);
    });

    test('wood chock resolves the matching Table 3 weight bracket, in the catalog\'s own format', () {
      final vehicle = _vehicle(weightT: const HandbookField(10.0));
      expect(
        requiredTypeCodeFor('att-wood-chock', vehicle, measurements: _measurements),
        'up to 12.0 t',
      );
    });

    test('wood chock returns null when combat weight or measurements are unavailable — never guessed', () {
      expect(requiredTypeCodeFor('att-wood-chock', _vehicle(), measurements: _measurements), isNull);
      expect(
        requiredTypeCodeFor('att-wood-chock', _vehicle(weightT: const HandbookField(10.0))),
        isNull,
      );
    });
  });

  group('checkEquipmentSelection', () {
    test('matching selection is PASS with the matched type named', () {
      final check = checkEquipmentSelection(
        referenceId: 'para-31',
        requiredTypeCode: 'Ş-303',
        selectedTypeCode: 'Ş-303',
      );
      expect(check!.status, CheckStatus.pass);
      expect(check.detail, contains('Ş-303'));
      expect(check.referenceId, 'para-31');
    });

    test('mismatched selection is FAIL naming both the required and selected type', () {
      final check = checkEquipmentSelection(
        referenceId: 'para-31',
        requiredTypeCode: 'Ş-303',
        selectedTypeCode: 'Ş-350',
      );
      expect(check!.status, CheckStatus.fail);
      expect(check.detail, allOf(contains('Ş-303'), contains('Ş-350')));
    });

    test('no verdict is produced when there is nothing to score yet', () {
      expect(
        checkEquipmentSelection(referenceId: 'para-31', requiredTypeCode: null, selectedTypeCode: 'Ş-303'),
        isNull,
        reason: 'no single mandatory type for this slot — never invent one to score against',
      );
      expect(
        checkEquipmentSelection(referenceId: 'para-31', requiredTypeCode: 'Ş-303', selectedTypeCode: null),
        isNull,
        reason: 'nothing selected yet — never guess a verdict',
      );
    });
  });
}
