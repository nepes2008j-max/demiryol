import 'package:test/test.dart';

import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/chock_arrangement.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/layout_conformance.dart';
import 'package:railsim/domain/usecases/securing_measurements.dart';

Vehicle _vehicle({
  VehicleCategory category = VehicleCategory.tracked,
  double? weightT = 41.0,
  int? axleCount,
}) =>
    Vehicle(
      id: 'veh-test',
      handbookDesignation: 'T-72/M',
      category: category,
      vehicleClass: 'test',
      lengthCm: const HandbookField(686),
      widthCm: const HandbookField(378),
      heightCm: const HandbookField(223),
      weightT: HandbookField(weightT),
      groundClearanceCm: const HandbookField(49),
      trackWidthMm: const HandbookField(580),
      wheelBaseCm: const HandbookField(427),
      axleCount: axleCount,
      manufacturer: 'test',
      country: 'test',
      approvedSecuringHardwareIds: const [],
      referenceId: 'plate-02',
    );

/// The tracked case: four chocks, four inserts, seated 10-15 cm.
const _tracked = ChockArrangement(
  id: 'tracked-seating-standard',
  appliesTo: VehicleCategory.tracked,
  label: 'test',
  chockCount: 4,
  insertCount: 4,
  seatingDistance: (minCm: 10, maxCm: 15),
  referenceId: 'plate-03',
);

const _staples = LateralRestraintOption(
  id: 'lateral-staples',
  label: 'test',
  description: 'test',
  staples: 12,
  referenceId: 'plate-02',
);

const _sideBlocks = LateralRestraintOption(
  id: 'lateral-side-blocks',
  label: 'test',
  description: 'test',
  blockSizeMm: '100*100*2000',
  referenceId: 'plate-02',
);

/// `rules.json`'s wheeled lashing lookup, as the real file states it.
final _rules = <String, dynamic>{
  'rules': [
    {
      'id': 'rule-wheeled-lashing-count',
      'lookup': [
        {'combatWeightMaxT': 24.0, 'lashingsRequired': 4},
        {'combatWeightMaxT': 40.0, 'lashingsRequired': 8},
      ],
      'referenceId': 'para-55',
    },
  ],
};

SecuringLayout _layout({
  int chocks = 0,
  int inserts = 0,
  int staples = 0,
  int lashings = 0,
}) {
  var n = 0;
  SecuringPiece piece(SecuringPieceKind kind) => SecuringPiece(
        id: '${kind.name}-${++n}',
        kind: kind,
        x: 0,
        z: 0,
      );
  return SecuringLayout([
    for (var i = 0; i < chocks; i++) piece(SecuringPieceKind.woodChock),
    for (var i = 0; i < inserts; i++) piece(SecuringPieceKind.woodInsert),
    for (var i = 0; i < staples; i++) piece(SecuringPieceKind.staple),
    for (var i = 0; i < lashings; i++) piece(SecuringPieceKind.wireLashing),
  ]);
}

List<PieceCountFinding> _counts(
  SecuringLayout layout, {
  Vehicle? vehicle,
  ChockArrangement? arrangement = _tracked,
  LateralRestraintOption? restraint,
}) =>
    pieceCountFindingsFor(
      placementId: 'placement-0',
      designation: 'T-72/M',
      vehicle: vehicle ?? _vehicle(),
      layout: layout,
      arrangement: arrangement,
      restraint: restraint,
      rules: _rules,
    );

PieceCountFinding _of(
        List<PieceCountFinding> findings, SecuringPieceKind kind) =>
    findings.firstWhere((f) => f.kind == kind);

SeatingFinding _seating({
  required String pieceId,
  required double measuredCm,
  ({int minCm, int maxCm})? range = (minCm: 10, maxCm: 15),
  bool underRunningGear = true,
  bool facesTheRun = true,
  required CheckStatus status,
}) =>
    SeatingFinding(
      placementId: 'placement-0',
      pieceId: pieceId,
      designation: 'T-72/M',
      measuredCm: measuredCm,
      requiredRange: range,
      underRunningGear: underRunningGear,
      facesTheRun: facesTheRun,
      status: status,
      referenceId: 'plate-03',
    );

void main() {
  group('how many pieces the handbook asks for', () {
    test('the right number of everything passes', () {
      final findings = _counts(_layout(chocks: 4, inserts: 4));
      expect(findings, hasLength(2));
      for (final f in findings) {
        expect(f.status, CheckStatus.pass, reason: f.kind.name);
        expect(f.detail, isNull);
      }
    });

    test('too few chocks fails and says how many are missing', () {
      final f = _of(_counts(_layout(chocks: 3, inserts: 4)),
          SecuringPieceKind.woodChock);
      expect(f.status, CheckStatus.fail);
      expect(f.tooFew, isTrue);
      expect(f.detail, contains('3'));
      expect(f.detail, contains('4'));
      expect(f.detail, contains('1 sany kem'));
    });

    test('too MANY chocks fails too — losing count is not extra credit', () {
      final f = _of(_counts(_layout(chocks: 7, inserts: 4)),
          SecuringPieceKind.woodChock);
      expect(f.status, CheckStatus.fail);
      expect(f.tooFew, isFalse);
      expect(f.detail, contains('3 sany artyk'));
    });

    test('placing nothing at all fails every count', () {
      final findings = _counts(_layout());
      expect(findings, hasLength(2));
      expect(findings.every((f) => f.status == CheckStatus.fail), isTrue);
      expect(_of(findings, SecuringPieceKind.woodChock).placedCount, 0);
    });

    test('inserts are counted separately from chocks', () {
      final findings = _counts(_layout(chocks: 4, inserts: 2));
      expect(_of(findings, SecuringPieceKind.woodChock).status,
          CheckStatus.pass);
      expect(_of(findings, SecuringPieceKind.woodInsert).status,
          CheckStatus.fail);
    });

    test('nothing is judged until the trainee picks an arrangement', () {
      expect(_counts(_layout(chocks: 4), arrangement: null), isEmpty);
    });

    test('staples are counted against the restraint that uses them', () {
      final f = _of(
          _counts(_layout(chocks: 4, inserts: 4, staples: 9),
              restraint: _staples),
          SecuringPieceKind.staple);
      expect(f.requiredCount, 12);
      expect(f.status, CheckStatus.fail);
    });

    test('the side-block restraint states a size, not a count, so none is checked',
        () {
      final findings = _counts(_layout(chocks: 4, inserts: 4, staples: 9),
          restraint: _sideBlocks);
      expect(findings.where((f) => f.kind == SecuringPieceKind.staple), isEmpty);
    });

    test('a wheeled vehicle has its lashings counted by weight', () {
      final f = _of(
        _counts(
          _layout(chocks: 4, lashings: 4),
          vehicle: _vehicle(
              category: VehicleCategory.wheeled, weightT: 11.0, axleCount: 2),
          arrangement: const ChockArrangement(
            id: 'wheeled-2axle-5-6-12t',
            appliesTo: VehicleCategory.wheeled,
            label: 'test',
            chockCount: 4,
            referenceId: 'plate-06',
          ),
        ),
        SecuringPieceKind.wireLashing,
      );
      expect(f.requiredCount, 4);
      expect(f.status, CheckStatus.pass);
    });

    test('a tracked vehicle gets no lashing count — the extract states none',
        () {
      final findings = _counts(_layout(chocks: 4, inserts: 4, lashings: 2));
      expect(findings.where((f) => f.kind == SecuringPieceKind.wireLashing),
          isEmpty);
    });

    test('a wheeled vehicle with no weight gets no lashing count', () {
      final findings = _counts(
        _layout(chocks: 4, lashings: 4),
        vehicle: _vehicle(category: VehicleCategory.wheeled, weightT: null),
        arrangement: const ChockArrangement(
          id: 'wheeled-2axle-le-5-5t',
          appliesTo: VehicleCategory.wheeled,
          label: 'test',
          chockCount: 4,
          referenceId: 'plate-06',
        ),
      );
      expect(findings.where((f) => f.kind == SecuringPieceKind.wireLashing),
          isEmpty);
    });
  });

  group('the count verdicts', () {
    test('one check per stated count, each carrying its citation', () {
      final checks = pieceCountChecks(_counts(_layout(chocks: 4, inserts: 4)));
      expect(checks, hasLength(2));
      expect(checks.map((c) => c.ruleId),
          containsAll(['rule-piece-count-woodChock', 'rule-piece-count-woodInsert']));
      expect(checks.every((c) => c.status == CheckStatus.pass), isTrue);
      expect(checks.first.referenceId, 'plate-03');
    });

    test('a short count produces a failing check, not a quiet one', () {
      final checks = pieceCountChecks(_counts(_layout(chocks: 2, inserts: 4)));
      final chock =
          checks.firstWhere((c) => c.ruleId == 'rule-piece-count-woodChock');
      expect(chock.status, CheckStatus.fail);
    });
  });

  group('how the blocks are seated', () {
    test('all blocks within range is one passing check', () {
      final check = seatingCheckFor([
        _seating(pieceId: 'a', measuredCm: 12.0, status: CheckStatus.pass),
        _seating(pieceId: 'b', measuredCm: 11.5, status: CheckStatus.pass),
      ]);
      expect(check, isNotNull);
      expect(check!.status, CheckStatus.pass);
      expect(check.detail, contains('2'));
    });

    test('one block out of range fails the vehicle and names that block', () {
      final check = seatingCheckFor([
        _seating(pieceId: 'block-1', measuredCm: 12.0, status: CheckStatus.pass),
        _seating(pieceId: 'block-2', measuredCm: 48.0, status: CheckStatus.fail),
      ]);
      expect(check!.status, CheckStatus.fail);
      expect(check.detail, contains('block-2'));
      expect(check.detail, contains('48.0'));
      // The block that was right is not named as a fault.
      expect(check.detail, isNot(contains('block-1')));
    });

    test('a block beside the running gear is reported as that, not as a distance',
        () {
      final check = seatingCheckFor([
        _seating(
            pieceId: 'block-1',
            measuredCm: 12.0,
            underRunningGear: false,
            status: CheckStatus.fail),
      ]);
      expect(check!.detail, contains('gusenisanyň aşagynda däl'));
    });

    test('a block turned the wrong way is reported as that', () {
      final check = seatingCheckFor([
        _seating(
            pieceId: 'block-1',
            measuredCm: 12.0,
            facesTheRun: false,
            status: CheckStatus.fail),
      ]);
      expect(check!.detail, contains('ters goýlupdyr'));
    });

    test('pieces the plates dimension no distance for are not marked', () {
      // A spur and a KGUUB are measured and reported but never judged against
      // the wood block's range; a vehicle carrying only those has nothing here
      // to be right or wrong about.
      expect(
        seatingCheckFor([
          _seating(
              pieceId: 'spur-1', measuredCm: 2.0, status: CheckStatus.unknown),
        ]),
        isNull,
      );
      expect(seatingCheckFor(const []), isNull);
    });

    test('undecidable blocks do not dilute a verdict on the decidable ones', () {
      final check = seatingCheckFor([
        _seating(pieceId: 'block-1', measuredCm: 48.0, status: CheckStatus.fail),
        _seating(
            pieceId: 'spur-1', measuredCm: 2.0, status: CheckStatus.unknown),
      ]);
      expect(check!.status, CheckStatus.fail);
      expect(check.detail, contains('1'));
      expect(check.detail, isNot(contains('spur-1')));
    });
  });
}
