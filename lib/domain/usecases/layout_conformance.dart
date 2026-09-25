import '../../core/localization/app_strings.dart';
import '../../data/models/simulation_result.dart';
import '../../data/models/vehicle.dart';
import '../models/chock_arrangement.dart';
import '../models/securing_placement.dart';
import 'securing_measurements.dart';
import 'wire_lashing_rule.dart';

/// Whether what the trainee actually laid on the wagon matches what the
/// handbook asks for — the right number of each piece, each one seated where
/// the plate dimensions it.
///
/// This is the check the program was missing. Every distance was already
/// measured: `seatingFindingsFor` produced a real PASS or FAIL for every stop
/// block, the result sheet printed it, the screen showed it — and it reached
/// the mark through no channel at all. A trainee who seated every block half a
/// metre from the running gear scored exactly the same as one who seated them
/// at twelve centimetres. Nor was any count ever checked: `checkChockArrangement`
/// asks whether the trainee picked the right *case*, never whether they then
/// put out the four or eight chocks that case calls for, so three chocks, or
/// eleven, passed silently.
///
/// Two kinds of finding come out of here, and both count in the mark:
///
///  * **Counts.** How many of each kind the chosen arrangement calls for
///    against how many are on the wagon. Too few and too many are both wrong;
///    a wagon carrying eleven chocks is not better secured than one carrying
///    eight, it is a wagon somebody lost count on.
///  * **Seating.** Whether every stop block is within the range the plate
///    dimensions, seated under the running gear, and turned the right way.
///
/// Only counts the source actually states are checked. The handbook gives a
/// number of chocks and inserts per vehicle (plate-02, plate-06), a number of
/// staples for the lateral restraint that uses them (plate-02), and a number of
/// lashings for a wheeled vehicle by weight (para. 55). It gives no count for
/// the KGUUB chocks, the packing boards, the side blocks or a tracked
/// vehicle's lashings, so none is checked — a check against an invented figure
/// would be worse than no check at all.
///
/// Iron spurs are deliberately absent: `iron_spur_rules.dart` already counts a
/// set of four and places them at their four stations, and checking them twice
/// would punish one mistake twice over.

/// One kind of piece: what the handbook asks for, and what is there.
class PieceCountFinding {
  final String placementId;

  /// The vehicle this gear is holding, for the sheet.
  final String designation;

  final SecuringPieceKind kind;

  /// How many the handbook asks for.
  final int requiredCount;

  /// How many the trainee put on the wagon.
  final int placedCount;

  final String referenceId;

  const PieceCountFinding({
    required this.placementId,
    required this.designation,
    required this.kind,
    required this.requiredCount,
    required this.placedCount,
    required this.referenceId,
  });

  bool get isCorrect => placedCount == requiredCount;
  bool get tooFew => placedCount < requiredCount;

  CheckStatus get status =>
      isCorrect ? CheckStatus.pass : CheckStatus.fail;

  /// What is wrong, in one line, or null when nothing is.
  String? get detail {
    if (isCorrect) return null;
    final name = AppStrings.pieceKindName(kind);
    return tooFew
        ? AppStrings.pieceCountTooFewDetail(name, placedCount, requiredCount)
        : AppStrings.pieceCountTooManyDetail(name, placedCount, requiredCount);
  }
}

/// Every count the handbook states for this vehicle, against what is placed.
///
/// [arrangement] is the case the trainee chose; with none chosen nothing here
/// can be judged, because the counts are the chosen case's own. [restraint] is
/// the lateral restraint they chose, which is where the staple count lives.
List<PieceCountFinding> pieceCountFindingsFor({
  required String placementId,
  required String designation,
  required Vehicle vehicle,
  required SecuringLayout layout,
  required ChockArrangement? arrangement,
  required LateralRestraintOption? restraint,
  required Map<String, dynamic> rules,
}) {
  final findings = <PieceCountFinding>[];

  void add(SecuringPieceKind kind, int required, String referenceId) {
    findings.add(PieceCountFinding(
      placementId: placementId,
      designation: designation,
      kind: kind,
      requiredCount: required,
      placedCount: layout.countOf(kind),
      referenceId: referenceId,
    ));
  }

  if (arrangement != null) {
    add(SecuringPieceKind.woodChock, arrangement.chockCount,
        arrangement.referenceId);
    // Wheeled cases carry no insert count; the plates seat inserts between the
    // road wheels of a tracked vehicle only.
    if (arrangement.insertCount > 0) {
      add(SecuringPieceKind.woodInsert, arrangement.insertCount,
          arrangement.referenceId);
    }
  }

  // The staple count belongs to the lateral restraint that uses staples; the
  // side-block option states a size instead and no number, so it is not
  // counted.
  final staples = restraint?.staples;
  if (staples != null) {
    add(SecuringPieceKind.staple, staples, restraint!.referenceId);
  }

  // Para. 55 brackets a wheeled vehicle's lashings by weight. Nothing in the
  // extract states how many a tracked vehicle takes — plate-03's table gives
  // the strands *within* one lashing, not the number of lashings — so a
  // tracked vehicle gets no lashing count check.
  if (vehicle.category == VehicleCategory.wheeled) {
    final weight = vehicle.bracketWeightT.asDouble;
    if (weight != null) {
      final lashings = requiredWireLashingCount(weight, rules);
      if (lashings != null) {
        add(SecuringPieceKind.wireLashing, lashings, 'para-55');
      }
    }
  }

  return findings;
}

/// The count verdicts, as the mark and the sheets read them.
List<ValidationCheck> pieceCountChecks(List<PieceCountFinding> findings) => [
      for (final finding in findings)
        ValidationCheck(
          ruleId: 'rule-piece-count-${finding.kind.name}',
          label: AppStrings.pieceCountCheckLabel(
              AppStrings.pieceKindName(finding.kind)),
          status: finding.status,
          detail: finding.detail ??
              AppStrings.pieceCountOkDetail(
                  AppStrings.pieceKindName(finding.kind), finding.requiredCount),
          referenceId: finding.referenceId,
        ),
    ];

/// One verdict per vehicle on how its stop blocks are seated.
///
/// Deliberately one check rather than one per block. Scoring each block
/// separately would hand a trainee who misplaced one of eight seven easy
/// passes to dilute it with, which is the opposite of counting the mistake;
/// this way a vehicle whose blocks are not all where the plate puts them fails
/// once, and the detail names every block that is out. The per-block figures
/// are still printed in full on the result sheet.
///
/// Returns nothing when no block could be judged — a piece the plates state no
/// distance for is measured and reported but never marked, and a vehicle
/// carrying only those has nothing here to be right or wrong about.
ValidationCheck? seatingCheckFor(List<SeatingFinding> findings) {
  final judged = [
    for (final finding in findings)
      if (finding.status != CheckStatus.unknown) finding,
  ];
  if (judged.isEmpty) return null;

  final wrong = [
    for (final finding in judged)
      if (finding.status == CheckStatus.fail) finding,
  ];
  final referenceId = judged.first.referenceId;
  if (wrong.isEmpty) {
    return ValidationCheck(
      ruleId: 'rule-seating-conformance',
      label: AppStrings.seatingConformanceLabel,
      status: CheckStatus.pass,
      detail: AppStrings.seatingConformanceOkDetail(judged.length),
      referenceId: referenceId,
    );
  }
  return ValidationCheck(
    ruleId: 'rule-seating-conformance',
    label: AppStrings.seatingConformanceLabel,
    status: CheckStatus.fail,
    detail: AppStrings.seatingConformanceWrongDetail(
      wrong.length,
      judged.length,
      [for (final f in wrong) _seatingFault(f)].join('; '),
    ),
    referenceId: referenceId,
  );
}

/// Why one block is wrong, short enough to sit in a list of them.
String _seatingFault(SeatingFinding finding) {
  if (!finding.underRunningGear) {
    return AppStrings.seatingFaultBesideRun(AppStrings.pieceLabel(finding.pieceId));
  }
  if (!finding.facesTheRun) {
    return AppStrings.seatingFaultWrongWay(AppStrings.pieceLabel(finding.pieceId));
  }
  final range = finding.requiredRange;
  if (range == null) {
    return AppStrings.seatingFaultOff(
        AppStrings.pieceLabel(finding.pieceId), finding.measuredCm);
  }
  return AppStrings.seatingFaultOutOfRange(
      AppStrings.pieceLabel(finding.pieceId), finding.measuredCm, range.minCm, range.maxCm);
}
