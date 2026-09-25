import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/securing_method.dart';
import 'package:railsim/domain/usecases/securing_method_resolution.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({HandbookField? weightT, HandbookField? lengthCm}) => Vehicle(
      id: 'veh-x',
      handbookDesignation: 'T-34',
      category: VehicleCategory.tracked,
      vehicleClass: 'x',
      lengthCm: lengthCm ?? _todo,
      widthCm: _todo,
      heightCm: _todo,
      weightT: weightT ?? _todo,
      groundClearanceCm: _todo,
      trackWidthMm: _todo,
      wheelBaseCm: _todo,
      manufacturer: 'x',
      country: 'x',
      approvedSecuringHardwareIds: const [],
      referenceId: 'para-34',
    );

void main() {
  group('withUserSuppliedFigures', () {
    test('fills an empty field and records where the figure came from', () {
      final withWeight = _vehicle().withUserSuppliedFigures(weightT: 26.5);
      expect(withWeight.weightT.asDouble, 26.5);
      expect(withWeight.userSuppliedFields, contains('weightT'));
      expect(withWeight.hasUserSuppliedFigures, isTrue);
    });

    test('never overwrites a figure the handbook already gives', () {
      final extracted = _vehicle(weightT: const HandbookField(32.0));
      final result = extracted.withUserSuppliedFigures(weightT: 99.0);
      expect(result.weightT.asDouble, 32.0, reason: 'the handbook wins');
      expect(result.hasUserSuppliedFigures, isFalse);
      expect(identical(result, extracted), isTrue, reason: 'no needless copy');
    });

    test('leaves the vehicle untouched when nothing was supplied', () {
      final vehicle = _vehicle();
      expect(identical(vehicle.withUserSuppliedFigures(), vehicle), isTrue);
      expect(vehicle.hasUserSuppliedFigures, isFalse);
    });

    test('carries both figures independently', () {
      final both = _vehicle().withUserSuppliedFigures(weightT: 20, lengthCm: 670);
      expect(both.userSuppliedFields, {'weightT', 'lengthCm'});
      expect(both.lengthCm.asDouble, 670);
    });
  });

  group('what a supplied weight unlocks', () {
    test('the KGUUB bracket becomes decidable', () {
      // The whole point of the feature: with no weight every tracked vehicle
      // got an unconfirmed set of methods, because no record in the extract
      // carries one.
      final before = resolveSecuringMethodOptions(_vehicle());
      expect((before as AlternativeSecuringMethods).eligibilityConfirmed, isFalse);

      final after = resolveSecuringMethodOptions(
          _vehicle().withUserSuppliedFigures(weightT: 20.0));
      final resolved = after as AlternativeSecuringMethods;
      expect(resolved.eligibilityConfirmed, isTrue);
      expect(resolved.methodNumbers, contains(1), reason: '20 t is inside the KGUUB range');
    });

    test('a weight outside the KGUUB range drops method 1 rather than failing', () {
      final heavy = resolveSecuringMethodOptions(
          _vehicle().withUserSuppliedFigures(weightT: 50.0));
      final resolved = heavy as AlternativeSecuringMethods;
      expect(resolved.eligibilityConfirmed, isTrue);
      expect(resolved.methodNumbers, isNot(contains(1)));
      expect(resolved.methodNumbers, containsAll([3, 5]));
    });
  });
}
