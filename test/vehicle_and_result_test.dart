import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';

void main() {
  group('Vehicle.dataCompleteness', () {
    test('is 0.0 when every dimension is a TODO placeholder', () {
      const v = Vehicle(
        id: 'v1',
        handbookDesignation: 'Object 999',
        category: VehicleCategory.tracked,
        vehicleClass: 'TODO: Fill from Handbook Page XX',
        lengthCm: HandbookField('TODO: Fill from Handbook Page XX'),
        widthCm: HandbookField('TODO: Fill from Handbook Page XX'),
        heightCm: HandbookField('TODO: Fill from Handbook Page XX'),
        weightT: HandbookField('TODO: Fill from Handbook Page XX'),
        groundClearanceCm: HandbookField('TODO: Fill from Handbook Page XX'),
        trackWidthMm: HandbookField('TODO: Fill from Handbook Page XX'),
        wheelBaseCm: HandbookField('TODO: Fill from Handbook Page XX'),
        manufacturer: 'TODO: Fill from Handbook Page XX',
        country: 'TODO: Fill from Handbook Page XX',
        approvedSecuringHardwareIds: [],
        referenceId: 'para-31',
      );
      expect(v.dataCompleteness, 0.0);
    });

    test('reflects the fraction of real numeric fields', () {
      // Seven fields. Three went: the centre-of-gravity height and the
      // tie-down point count, because no source publishes either for any
      // vehicle and two permanently empty cells dragged every vehicle's badge
      // down while telling the trainee nothing; and the separate combat and
      // transport weights, which were merged into the one weight a vehicle
      // actually has.
      const v = Vehicle(
        id: 'v2',
        handbookDesignation: 'Test vehicle',
        category: VehicleCategory.tracked,
        vehicleClass: 'Main Battle Tank',
        lengthCm: HandbookField(953.0),
        widthCm: HandbookField(340.0),
        heightCm: HandbookField('TODO: Fill from Handbook Page XX'),
        weightT: HandbookField(41.0),
        groundClearanceCm: HandbookField('TODO: Fill from Handbook Page XX'),
        trackWidthMm: HandbookField('TODO: Fill from Handbook Page XX'),
        wheelBaseCm: HandbookField('TODO: Fill from Handbook Page XX'),
        manufacturer: 'TODO: Fill from Handbook Page XX',
        country: 'TODO: Fill from Handbook Page XX',
        approvedSecuringHardwareIds: [],
        referenceId: 'para-31',
      );
      // 3 of 7 fields available.
      expect(v.dataCompleteness, closeTo(3 / 7, 0.001));
    });
  });

  group('SimulationResult', () {
    test('overallPass is false when any check fails, regardless of unknowns', () {
      const result = SimulationResult(
        vehicleId: 'v1',
        platformId: 'p1',
        checks: [
          ValidationCheck(
            ruleId: 'r1',
            label: 'Check A',
            status: CheckStatus.pass,
            detail: 'ok',
            referenceId: 'para-1',
          ),
          ValidationCheck(
            ruleId: 'r2',
            label: 'Check B',
            status: CheckStatus.fail,
            detail: 'bad',
            referenceId: 'para-2',
          ),
        ],
        requiredHardwareIds: [],
        appliedPrincipleIds: [],
      );
      expect(result.overallPass, isFalse);
      expect(result.passCount, 1);
      expect(result.failCount, 1);
    });

    test('overallPass is true when checks are pass/unknown but never fail', () {
      const result = SimulationResult(
        vehicleId: 'v1',
        platformId: 'p1',
        checks: [
          ValidationCheck(
            ruleId: 'r1',
            label: 'Check A',
            status: CheckStatus.pass,
            detail: 'ok',
            referenceId: 'para-1',
          ),
          ValidationCheck(
            ruleId: 'r2',
            label: 'Check B',
            status: CheckStatus.unknown,
            detail: 'pending handbook data',
            referenceId: 'para-2',
          ),
        ],
        requiredHardwareIds: [],
        appliedPrincipleIds: [],
      );
      expect(result.overallPass, isTrue);
      expect(result.unknownCount, 1);
    });
  });
}
