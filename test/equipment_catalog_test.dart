import 'package:test/test.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/domain/usecases/equipment_catalog.dart';

const _measurements = {
  'ironSpurTable': {
    'referenceId': 'para-31',
    'rows': [
      {'type': 'Ş-303', 'basePlateMm': '500x140x12', 'combHeightMm': 30, 'setWeightKg4Spurs': 38.8},
      {'type': 'Ş-350', 'basePlateMm': '375x130x12', 'combHeightMm': 25, 'setWeightKg4Spurs': 31.0},
    ],
  },
  'ironChockBootTable': {
    'referenceId': 'para-32',
    'rows': [
      {
        'type': 'KT-137',
        'basePlateMm': '170x130x8',
        'pinMm': '35x12',
        'setWeightKg4Boots': 11.4,
        'forVehicles': ['T-54', 'T-55'],
      },
    ],
  },
  'reusableChockTrackedTable': {
    'referenceId': 'para-29',
    'rows': [
      {
        'type': 'KGUUB-1G',
        'combatWeightRangeT': '7-25',
        'basePlateMm': '280x200x8',
        'pinCount': 6,
        'pinMm': '26x14',
        'setWeightKg4Posts': 26,
      },
    ],
  },
  'wireCoilTable': {
    'referenceId': 'para-19',
    'rows': [
      {'wireDiameterMm': 4, 'standardCoilLengthM': 202, 'standardCoilWeightKg': 20},
      {'wireDiameterMm': 5, 'standardCoilLengthM': 162, 'standardCoilWeightKg': 25},
    ],
  },
};

const _measurementsWithWoodChock = {
  'trackChockByWeightTable': {
    'referenceId': 'para-21',
    'rows': [
      {'combatWeightRangeT': 'up to 12.0', 'chockHeightMm': 75, 'chockWidthMm': 150},
      {'combatWeightRangeT': '12.1-18.0', 'chockHeightMm': 100, 'chockWidthMm': 180},
      {'combatWeightRangeT': 'over 18.0', 'chockHeightMm': 180, 'chockWidthMm': 200},
    ],
  },
};

const _attachments = [
  AttachmentType(
    id: 'att-wire-lashing',
    category: AttachmentCategory.rope,
    name: 'Steel wire lashing',
    diametersAvailableMm: [4, 5, 6],
    referenceId: 'table-7',
  ),
];

void main() {
  group('equipmentOptionsFor', () {
    test('iron spur options come straight from ironSpurTable rows, citing para-31', () {
      final options = equipmentOptionsFor('att-iron-spur', _measurements, const []);
      expect(options, hasLength(2));
      expect(options.map((o) => o.typeCode), containsAll(['Ş-303', 'Ş-350']));
      for (final o in options) {
        expect(o.referenceId, 'para-31');
        expect(o.specs.values, contains(contains('mm')));
      }
    });

    test('iron chock boot options include the forVehicles restriction as a spec line', () {
      final options = equipmentOptionsFor('att-iron-chock-boot', _measurements, const []);
      expect(options.single.typeCode, 'KT-137');
      expect(options.single.specs.values.any((v) => v.contains('T-54')), isTrue);
    });

    test('KGUUB tracked options come from reusableChockTrackedTable', () {
      final options = equipmentOptionsFor('att-kguub-1g', _measurements, const []);
      expect(options.single.typeCode, 'KGUUB-1G');
      expect(options.single.referenceId, 'para-29');
    });

    test('wire lashing options are the attachment-declared diameters, enriched from Table 1', () {
      final options = equipmentOptionsFor('att-wire-lashing', _measurements, _attachments);
      expect(options.map((o) => o.typeCode), containsAll(['4 mm', '5 mm', '6 mm']));
      final fourMm = options.firstWhere((o) => o.typeCode == '4 mm');
      expect(fourMm.specs.values.any((v) => v.contains('202')), isTrue);
      final sixMm = options.firstWhere((o) => o.typeCode == '6 mm');
      expect(sixMm.specs, isEmpty, reason: 'no Table 1 row for 6mm in this fixture — never fabricate one');
    });

    test('wood chock options are every Table 3 weight bracket, each with real height/width', () {
      final options = equipmentOptionsFor('att-wood-chock', _measurementsWithWoodChock, const []);
      expect(options, hasLength(3));
      expect(options.map((o) => o.typeCode), containsAll(['up to 12.0 t', '12.1-18.0 t', 'over 18.0 t']));
      final first = options.firstWhere((o) => o.typeCode == 'up to 12.0 t');
      expect(first.specs.values, containsAll(['75 mm', '150 mm']));
      expect(first.referenceId, 'para-21');
    });

    test('a hardware id with no catalog table produces no fabricated options', () {
      expect(equipmentOptionsFor('att-wood-chock', _measurements, const []), isEmpty);
      expect(equipmentOptionsFor('att-unknown-thing', _measurements, const []), isEmpty);
    });

    test('missing table in measurements.json produces no options rather than crashing', () {
      expect(equipmentOptionsFor('att-iron-spur', const {}, const []), isEmpty);
    });
  });
}
