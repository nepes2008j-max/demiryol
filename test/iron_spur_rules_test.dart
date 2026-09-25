import 'package:test/test.dart';

import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/iron_spur_rules.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';

/// A tracked vehicle, optionally carrying Table 13's spur assignment.
Vehicle _vehicle({
  String? spur,
  VehicleCategory category = VehicleCategory.tracked,
}) =>
    Vehicle(
      id: 'veh-test',
      handbookDesignation: 'T-72/M',
      category: category,
      vehicleClass: 'test',
      lengthCm: const HandbookField(686),
      widthCm: const HandbookField(378),
      heightCm: const HandbookField(223),
      weightT: const HandbookField(41.0),
      groundClearanceCm: const HandbookField(49),
      trackWidthMm: const HandbookField(580),
      wheelBaseCm: const HandbookField(427),
      manufacturer: 'test',
      country: 'test',
      approvedSecuringHardwareIds: const [],
      referenceId: 'para-31',
      ironSpurType: spur,
    );

LoadingGeometry _geometry() => resolveLoadingGeometry(
      vehicleSpec: TrackedVehicleMeshSpec.t90s,
      flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      positionFraction: 0.5,
    );

/// A set of spurs seated the way the handbook asks: one at each end of each
/// track, under the running gear, comb turned towards the vehicle.
///
/// [standoffM] is how far each spur's working face stands off the end of the
/// bearing length. Small and positive, because a spur at a *negative* distance
/// is under the track's middle and holds nothing.
List<SecuringPiece> _fullSet(
  LoadingGeometry g, {
  String type = 'Ş-137',
  double standoffM = 0.02,
}) {
  final vehicle = g.vehicle;
  final rear = vehicle.trackContactX.rear + g.vehicleOffsetX;
  final front = vehicle.trackContactX.front + g.vehicleOffsetX;
  final z = vehicle.trackCenterZ;
  var n = 0;
  SecuringPiece at(double x, double z, ChockFacing facing) => SecuringPiece(
        id: 'spur-${++n}',
        kind: SecuringPieceKind.ironSpur,
        x: x,
        z: z,
        widthM: 0.14,
        heightM: 0.042,
        lengthM: 0.585,
        facing: facing,
        sizeTypeCode: type,
      );
  return [
    at(rear - standoffM, -z, ChockFacing.towardsFront),
    at(front + standoffM, -z, ChockFacing.towardsRear),
    at(rear - standoffM, z, ChockFacing.towardsFront),
    at(front + standoffM, z, ChockFacing.towardsRear),
  ];
}

List<SpurFinding> _findings(
  List<SecuringPiece> pieces, {
  String? spur = 'Ş-137',
  VehicleCategory category = VehicleCategory.tracked,
}) {
  final g = _geometry();
  return spurFindingsFor(
    placementId: 'placement-0',
    designation: 'T-72/M',
    layout: SecuringLayout(pieces),
    vehicle: g.vehicle,
    vehicleOffsetX: g.vehicleOffsetX,
    requirement:
        ironSpurRequirementFor(_vehicle(spur: spur, category: category)),
  );
}

void main() {
  group('which spur, and whether spurs at all', () {
    test('Table 13 names the type, and the type is not derived from weight', () {
      final r = ironSpurRequirementFor(_vehicle(spur: 'Ş-137'));
      expect(r.eligibility, IronSpurEligibility.named);
      expect(r.typeCode, 'Ş-137');
      expect(r.spursApply, isTrue);
      // A set is four, from Table 10's own "mass per set of four" column.
      expect(r.spursRequired, 4);
      expect(kIronSpurSetCount, 4);
    });

    test('a tracked vehicle Table 13 does not name is not secured with spurs', () {
      final r = ironSpurRequirementFor(_vehicle(spur: null));
      expect(r.eligibility, IronSpurEligibility.notNamed);
      expect(r.typeCode, isNull);
      expect(r.spursApply, isFalse);
    });

    test('a wheeled vehicle has nothing to do with the Ş-series', () {
      final r = ironSpurRequirementFor(
          _vehicle(spur: null, category: VehicleCategory.wheeled));
      expect(r.eligibility, IronSpurEligibility.notApplicable);
    });
  });

  group('the four stations', () {
    test('a full set correctly seated passes at every station', () {
      final findings = _findings(_fullSet(_geometry()));
      expect(findings, hasLength(4));
      expect(findings.map((f) => f.station).toSet(),
          SpurStation.values.toSet());
      for (final f in findings) {
        expect(f.problem, SpurProblem.none, reason: f.station.label);
        expect(f.status, CheckStatus.pass);
        expect(f.detail, isNull);
      }
    });

    test('a missing spur is reported as the station it is missing from', () {
      final set = _fullSet(_geometry())..removeAt(2); // right track, rear
      final findings = _findings(set);
      final missing = findings.where((f) => f.problem == SpurProblem.missing);
      expect(missing, hasLength(1));
      expect(missing.first.station, SpurStation.rightRear);
      expect(missing.first.status, CheckStatus.fail);
      expect(missing.first.detail, contains('sag'));
    });

    test('two spurs crowded on one station leave another bare', () {
      final g = _geometry();
      final set = _fullSet(g);
      // Move the right-rear spur onto the right-front station.
      set[2] = set[2].copyWith(
        x: g.vehicle.trackContactX.front + g.vehicleOffsetX + 0.02,
        facing: ChockFacing.towardsRear,
      );
      final findings = _findings(set);
      final byStation = {for (final f in findings) f.station: f};
      expect(byStation[SpurStation.rightRear]!.problem, SpurProblem.missing);
      expect(byStation[SpurStation.rightFront]!.problem, SpurProblem.doubled);
    });

    test('the wrong type is caught wherever it sits', () {
      final set = _fullSet(_geometry());
      set[0] = set[0].copyWith(sizeTypeCode: 'Ş-350');
      final findings = _findings(set);
      final wrong = findings.where((f) => f.problem == SpurProblem.wrongType);
      expect(wrong, hasLength(1));
      expect(wrong.first.detail, allOf(contains('Ş-350'), contains('Ş-137')));
    });

    test('a spur laid beside the track holds nothing', () {
      final g = _geometry();
      final set = _fullSet(g);
      // Well outside the track's own width, still on that side of the wagon.
      set[0] = set[0].copyWith(z: -(g.vehicle.trackCenterZ + 1.0));
      final findings = _findings(set);
      expect(
        findings.where((f) => f.problem == SpurProblem.besideTheTrack),
        hasLength(1),
      );
    });

    test('a spur turned the wrong way is caught even when placed exactly', () {
      final set = _fullSet(_geometry());
      set[0] = set[0].copyWith(facing: ChockFacing.towardsRear);
      final findings = _findings(set);
      expect(
        findings.where((f) => f.problem == SpurProblem.wrongWay),
        hasLength(1),
      );
    });

    test('a spur under the middle of the track is reported as overlapping', () {
      final g = _geometry();
      final set = _fullSet(g);
      // Half a metre inside the bearing length rather than at its end.
      set[0] = set[0].copyWith(
          x: g.vehicle.trackContactX.rear + g.vehicleOffsetX + 0.5);
      final findings = _findings(set);
      expect(
        findings.where((f) => f.problem == SpurProblem.overlapping),
        hasLength(1),
      );
    });

    test('spurs on a vehicle Table 13 does not name are one mistake, not four',
        () {
      final findings = _findings(_fullSet(_geometry()), spur: null);
      expect(findings, hasLength(1));
      expect(findings.first.problem, SpurProblem.notPermitted);
      expect(findings.first.status, CheckStatus.fail);
    });

    test('a vehicle spurs do not apply to, with none placed, is not a finding',
        () {
      expect(_findings(const [], spur: null), isEmpty);
    });
  });

  group('the verdicts', () {
    List<ValidationCheck> checksFor(List<SecuringPiece> pieces,
        {String? spur = 'Ş-137'}) {
      final findings = _findings(pieces, spur: spur);
      return ironSpurChecks(
        requirement: ironSpurRequirementFor(_vehicle(spur: spur)),
        findings: findings,
        spursPlaced: pieces.length,
      );
    }

    test('a correct set passes type, count and stations', () {
      final checks = checksFor(_fullSet(_geometry()));
      expect(checks, hasLength(3));
      expect(checks.every((c) => c.status == CheckStatus.pass), isTrue,
          reason: checks.map((c) => '${c.ruleId}=${c.status}').join(', '));
    });

    test('three spurs fail the count and name the bare station', () {
      final checks = checksFor(_fullSet(_geometry())..removeLast());
      final count =
          checks.firstWhere((c) => c.ruleId == 'rule-iron-spur-set-count');
      expect(count.status, CheckStatus.fail);
      expect(count.detail, contains('3'));
      expect(count.detail, contains('4'));

      final stations =
          checks.firstWhere((c) => c.ruleId == 'rule-iron-spur-stations');
      expect(stations.status, CheckStatus.fail);
      expect(stations.detail, contains(SpurStation.rightFront.label));
    });

    test('the type check cannot be decided when no spur states a type', () {
      // Built rather than copied: `copyWith` cannot clear a field, and what is
      // under test here is a spur placed without a stated size.
      final bare = [
        for (final p in _fullSet(_geometry()))
          SecuringPiece(
            id: p.id,
            kind: p.kind,
            x: p.x,
            z: p.z,
            widthM: p.widthM,
            heightM: p.heightM,
            lengthM: p.lengthM,
            facing: p.facing,
          ),
      ];
      final checks = checksFor(bare);
      final type = checks.firstWhere((c) => c.ruleId == 'rule-iron-spur-type');
      expect(type.status, CheckStatus.unknown);
      // The handbook's answer is still stated, so the trainee learns it.
      expect(type.detail, contains('Ş-137'));
    });

    test('spurs on an unnamed vehicle produce one applicability failure', () {
      final checks = checksFor(_fullSet(_geometry()), spur: null);
      expect(checks, hasLength(1));
      expect(checks.first.ruleId, 'rule-iron-spur-applicability');
      expect(checks.first.status, CheckStatus.fail);
    });

    test('an unnamed vehicle with no spurs raises nothing at all', () {
      expect(checksFor(const [], spur: null), isEmpty);
    });

    test('a wheeled vehicle is never asked about spurs', () {
      final checks = ironSpurChecks(
        requirement: ironSpurRequirementFor(
            _vehicle(category: VehicleCategory.wheeled)),
        findings: const [],
        spursPlaced: 0,
      );
      expect(checks, isEmpty);
    });
  });
}
