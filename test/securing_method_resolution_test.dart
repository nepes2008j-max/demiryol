import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/securing_method.dart';
import 'package:railsim/domain/usecases/securing_method_resolution.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({HandbookField? weightT, VehicleCategory? category}) => Vehicle(
      id: 'veh-x',
      handbookDesignation: 'veh-x',
      category: category ?? VehicleCategory.tracked,
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
      referenceId: 'para-34',
    );

void main() {
  group('resolveSecuringMethodOptions', () {
    test('missing combat weight still offers the three alternatives, marked unconfirmed', () {
      // The handbook gives a tracked vehicle these alternatives whatever its
      // weight; what a missing weight prevents is confirming the KGUUB
      // bracket and sizing the stop-blocks. Withholding the choice taught
      // nothing, since no vehicle in the extract records a weight.
      final resolution = resolveSecuringMethodOptions(_vehicle());
      expect(resolution, isA<AlternativeSecuringMethods>());
      final alternatives = resolution as AlternativeSecuringMethods;
      expect(alternatives.methodNumbers, [1, 3, 5]);
      expect(alternatives.eligibilityConfirmed, isFalse);
    });

    test('a resolved weight marks the alternatives as confirmed', () {
      final resolution =
          resolveSecuringMethodOptions(_vehicle(weightT: const HandbookField(20.0)));
      expect((resolution as AlternativeSecuringMethods).eligibilityConfirmed, isTrue);
    });

    test('a wheeled vehicle resolves no tracked-method set at all', () {
      // The six methods are the tracked-vehicle annex; a wheeled vehicle must
      // not be offered them just because its weight is missing.
      expect(
        resolveSecuringMethodOptions(_vehicle(category: VehicleCategory.wheeled)),
        isA<UnknownSecuringMethod>(),
      );
    });

    test('a weight within the KGUUB bracket offers methods 1, 3, and 5 as alternatives — never fewer, never merged', () {
      final resolution = resolveSecuringMethodOptions(_vehicle(weightT: const HandbookField(20.0)));
      expect(resolution, isA<AlternativeSecuringMethods>());
      expect((resolution as AlternativeSecuringMethods).methodNumbers, containsAll([1, 3, 5]));
    });

    test('a weight outside the KGUUB bracket (e.g. very light) still offers 3 and 5, but not 1', () {
      final resolution = resolveSecuringMethodOptions(_vehicle(weightT: const HandbookField(3.0)));
      final methods = (resolution as AlternativeSecuringMethods).methodNumbers;
      expect(methods, containsAll([3, 5]));
      expect(methods, isNot(contains(1)));
    });

    test('method 6 (clamp-tensioner) is never offered — no vehicle in the extract is confirmed object 765/675', () {
      final resolution =
          resolveSecuringMethodOptions(_vehicle(weightT: const HandbookField(20.0))) as AlternativeSecuringMethods;
      expect(resolution.methodNumbers, isNot(contains(6)));
    });
  });

  group('hardwareIdsForSecuringMethod — cumulative-within-one-method, never merged across methods', () {
    test('method 1 resolves the concrete KGUUB variant from the vehicle\'s own weight bracket', () {
      expect(hardwareIdsForSecuringMethod(1, _vehicle(weightT: const HandbookField(10.0))), ['att-kguub-1g']);
      expect(hardwareIdsForSecuringMethod(1, _vehicle(weightT: const HandbookField(30.0))), ['att-kguub-2g']);
    });

    test('method 3 is wood chock + wire lashing together, per its own handbook name', () {
      expect(hardwareIdsForSecuringMethod(3, _vehicle()), ['att-wood-chock', 'att-wire-lashing']);
    });

    test('method 5 is wood chock + spacer boards together, per its own handbook name', () {
      expect(hardwareIdsForSecuringMethod(5, _vehicle()), ['att-wood-chock', 'att-wood-packing']);
    });

    test('methods never share hardware ids beyond what their own name lists', () {
      final method1 = hardwareIdsForSecuringMethod(1, _vehicle(weightT: const HandbookField(10.0)));
      final method3 = hardwareIdsForSecuringMethod(3, _vehicle());
      expect(method1.toSet().intersection(method3.toSet()), isEmpty);
    });
  });

  test('methodReferenceId cites each method\'s own paragraph from sixApprovedTrackedMethods', () {
    expect(methodReferenceId(1), 'para-35');
    expect(methodReferenceId(3), 'para-40');
    expect(methodReferenceId(5), 'para-34');
  });
}
