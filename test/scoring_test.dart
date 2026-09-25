import 'package:test/test.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/domain/models/attempt_event.dart';
import 'package:railsim/domain/usecases/scoring.dart';

ValidationCheck _check(CheckStatus status, {String detail = 'x'}) => ValidationCheck(
      ruleId: 'r',
      label: 'l',
      status: status,
      detail: detail,
      referenceId: 'para-34',
    );

SimulationResult _result(List<ValidationCheck> checks) => SimulationResult(
      vehicleId: 'veh-x',
      platformId: 'plat-x',
      checks: checks,
      requiredHardwareIds: const [],
      appliedPrincipleIds: const [],
    );

AttemptEvent _event() => AttemptEvent(
      kind: AttemptEventKind.wrongWagonType,
      description: 'tank wagon',
      referenceId: 'para-51',
      at: DateTime(2026),
    );

void main() {
  group('scoreAttempt', () {
    test('an undecidable check is never scored as correct', () {
      // The rule the whole type exists for: most checks in this app are
      // unknown for want of a figure the source does not give, and counting
      // them as passes would award a good mark for an unverified load.
      final score = scoreAttempt(
        results: [_result([_check(CheckStatus.unknown), _check(CheckStatus.unknown)])],
        events: const [],
      );
      expect(score.unknown, 2);
      expect(score.decidable, 0);
      expect(score.ratio, isNull);
      expect(score.percent, isNull);
      expect(score.isClean, isFalse, reason: 'nothing was actually verified');
      expect(score.hasUndecided, isTrue);
    });

    test('the percentage is taken over decidable checks only', () {
      final score = scoreAttempt(
        results: [
          _result([
            _check(CheckStatus.pass),
            _check(CheckStatus.pass),
            _check(CheckStatus.fail),
            _check(CheckStatus.unknown),
            _check(CheckStatus.unknown),
          ])
        ],
        events: const [],
      );
      expect(score.passed, 2);
      expect(score.failed, 1);
      expect(score.unknown, 2);
      expect(score.decidable, 3);
      expect(score.percent, 67);
    });

    test('a clean attempt needs something decided, not merely nothing failed', () {
      final onlyUnknown =
          scoreAttempt(results: [_result([_check(CheckStatus.unknown)])], events: const []);
      final decided =
          scoreAttempt(results: [_result([_check(CheckStatus.pass)])], events: const []);
      expect(onlyUnknown.isClean, isFalse);
      expect(decided.isClean, isTrue);
    });

    test('logged wrong actions count as mistakes and spoil a clean run', () {
      final score = scoreAttempt(
        results: [_result([_check(CheckStatus.pass)])],
        events: [_event(), _event()],
      );
      expect(score.mistakes, 2);
      expect(score.isClean, isFalse);
      expect(score.percent, 100, reason: 'the checks still all passed');
    });

    test('checks are summed across every placement, not just the first', () {
      final score = scoreAttempt(
        results: [
          _result([_check(CheckStatus.pass)]),
          _result([_check(CheckStatus.fail), _check(CheckStatus.pass)]),
        ],
        events: const [],
      );
      expect(score.passed, 2);
      expect(score.failed, 1);
    });
  });

  group('failedChecks', () {
    test('collects every failure with its citation for the mistake list', () {
      final failures = failedChecks([
        _result([_check(CheckStatus.pass), _check(CheckStatus.fail, detail: 'too close')]),
        _result([_check(CheckStatus.fail, detail: 'overloaded')]),
      ]);
      expect(failures, hasLength(2));
      expect(failures.map((c) => c.detail), ['too close', 'overloaded']);
      expect(failures.every((c) => c.referenceId.isNotEmpty), isTrue);
    });
  });
}
