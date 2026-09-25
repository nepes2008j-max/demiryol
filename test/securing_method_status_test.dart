import 'package:test/test.dart';
import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/securing_method.dart';
import 'package:railsim/domain/usecases/securing_method_resolution.dart';
import 'package:railsim/domain/usecases/securing_method_status.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({
  VehicleCategory category = VehicleCategory.tracked,
  String? ironSpurType,
  String? ironChockBootType,
  HandbookField? weightT,
}) =>
    Vehicle(
      id: 'veh-x',
      handbookDesignation: 'veh-x',
      category: category,
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
  group('resolveSecuringMethodOptions — never mistakes a wheeled vehicle for a tracked alternative set', () {
    test('a wheeled vehicle is always UnknownSecuringMethod, regardless of weight', () {
      final resolution = resolveSecuringMethodOptions(
        _vehicle(category: VehicleCategory.wheeled, weightT: const HandbookField(20.0)),
      );
      expect(resolution, isA<UnknownSecuringMethod>());
    });
  });

  group('securingMethodStatusLabel', () {
    test('an iron-spur vehicle reports the mandatory spur, naming the type', () {
      // The type code is the point: the nine object-index entries carry no
      // dimensions at all, and the spur the handbook assigns them is the one
      // firm fact on their card.
      expect(securingMethodStatusLabel(_vehicle(ironSpurType: 'Ş-303')),
          AppStrings.securingStatusIronSpurTyped('Ş-303'));
      expect(securingMethodStatusLabel(_vehicle(ironSpurType: 'Ş-303')), contains('Ş-303'));
    });

    test('an iron-chock-boot vehicle reports the mandatory boot, naming the type', () {
      expect(
        securingMethodStatusLabel(_vehicle(ironChockBootType: 'KT-137')),
        AppStrings.securingStatusIronChockBootTyped('KT-137'),
      );
    });

    test('a generic tracked vehicle with known weight reports alternatives available', () {
      expect(
        securingMethodStatusLabel(_vehicle(weightT: const HandbookField(20.0))),
        AppStrings.securingStatusAlternatives,
      );
    });

    test('a tracked vehicle with unknown weight reports alternatives, flagged unconfirmed', () {
      // Its own label, not the plain "alternatives available" one: the card
      // must not let an unchecked eligibility read as a checked one.
      expect(securingMethodStatusLabel(_vehicle()),
          AppStrings.securingStatusAlternativesUnconfirmed);
      expect(AppStrings.securingStatusAlternativesUnconfirmed,
          isNot(AppStrings.securingStatusAlternatives));
    });

    test('a wheeled vehicle within the wire-lashing weight range reports the wire-lashing status', () {
      expect(
        securingMethodStatusLabel(
            _vehicle(category: VehicleCategory.wheeled, weightT: const HandbookField(20.0))),
        AppStrings.securingStatusWireLashing,
      );
    });

    test('a wheeled vehicle above the wire-lashing weight range reports unknown', () {
      expect(
        securingMethodStatusLabel(
            _vehicle(category: VehicleCategory.wheeled, weightT: const HandbookField(50.0))),
        AppStrings.securingStatusUnknown,
      );
    });
  });
}
