import '../../data/models/simulation_result.dart';
import '../models/attempt_event.dart';

/// What a trainee's attempt came to.
///
/// The one rule this type exists to enforce: **an UNKNOWN check is never
/// counted as correct.** Most checks in this app are unknown, because the
/// handbook extract does not carry the numbers they need, and a score that
/// quietly treated "cannot be decided" as "done right" would hand out a good
/// mark for a configuration nobody has verified. Unknowns are reported on
/// their own line and kept out of the ratio entirely.
class AttemptScore {
  /// Checks the engine could decide, and did decide in the trainee's favour.
  final int passed;

  /// Checks the engine decided against them.
  final int failed;

  /// Checks it could not decide, for want of a figure the source does not
  /// give. Reported, never scored.
  final int unknown;

  /// Wrong actions that never reached a check — see [AttemptEvent].
  final int mistakes;

  const AttemptScore({
    required this.passed,
    required this.failed,
    required this.unknown,
    required this.mistakes,
  });

  /// Checks that could actually be decided either way.
  int get decidable => passed + failed;

  /// Share of the decidable checks that passed, or null when nothing could be
  /// decided at all — which is a real outcome here, not a zero.
  double? get ratio => decidable == 0 ? null : passed / decidable;

  /// A percentage for display, or null when there is nothing to take a
  /// percentage of.
  int? get percent => ratio == null ? null : (ratio! * 100).round();

  /// True when everything decidable passed and nothing was done wrong along
  /// the way. Deliberately not true when nothing could be decided.
  bool get isClean => failed == 0 && mistakes == 0 && decidable > 0;

  /// True when the attempt rests on checks that could not be decided, so the
  /// mark is partial whatever it says.
  bool get hasUndecided => unknown > 0;
}

/// Scores an attempt from the configurations it produced and the wrong actions
/// logged along the way.
///
/// Failures are counted from the checks themselves rather than logged
/// separately: a FAIL check already is a mistake, with its citation attached,
/// and counting it twice would punish it twice.
AttemptScore scoreAttempt({
  required Iterable<SimulationResult> results,
  required Iterable<AttemptEvent> events,

  /// Checks that belong to the train rather than to one vehicle — the deck
  /// budget, the guard wagon, the echelon class. They count exactly like the
  /// per-vehicle ones; leaving them out would let an overloaded wagon score a
  /// clean attempt.
  Iterable<ValidationCheck> consistChecks = const [],

  /// Checks decided from what the trainee actually laid on the wagon rather
  /// than from the vehicle's record — whether a full set of iron spurs reached
  /// the four stations, and whether they are the type Table 13 names.
  ///
  /// These belong to a vehicle as much as any validator check does; they are
  /// passed in separately only because they are computed from the layout,
  /// which the per-vehicle evaluation does not see.
  Iterable<ValidationCheck> layoutChecks = const [],
}) {
  var passed = 0;
  var failed = 0;
  var unknown = 0;
  for (final check in [
    for (final result in results) ...result.checks,
    ...consistChecks,
    ...layoutChecks,
  ]) {
    {
      switch (check.status) {
        case CheckStatus.pass:
          passed++;
        case CheckStatus.fail:
          failed++;
        case CheckStatus.unknown:
          unknown++;
      }
    }
  }
  return AttemptScore(
    passed: passed,
    failed: failed,
    unknown: unknown,
    mistakes: events.length,
  );
}

/// Every failed check across the attempt, as the mistake list an instructor
/// reads — each one already carries the paragraph or plate it comes from.
List<ValidationCheck> failedChecks(Iterable<SimulationResult> results) => [
      for (final result in results)
        for (final check in result.checks)
          if (check.status == CheckStatus.fail) check,
    ];
