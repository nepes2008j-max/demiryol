import '../../core/localization/app_strings.dart';
import '../../data/models/simulation_result.dart';
import '../../data/models/vehicle.dart';
import '../models/securing_placement.dart';
import 'securing_measurements.dart';
import 'vehicle_mesh_builder.dart';

/// What the handbook asks of a set of iron spurs (demir şpor, Ş-series), and
/// whether the trainee's four went where they belong.
///
/// The iron spur is the one piece of securing gear this application had no
/// opinion about at all. A trainee could bolt a Ş-350 under a T-72 that
/// Table 13 assigns a Ş-137, put three of them on one track and none on the
/// other, lay them beside the running gear instead of under it, and the
/// result sheet said nothing — because the only spur logic in the program was
/// "this vehicle names a spur type, so add `att-iron-spur` to the required
/// list", which is a statement about the stores issue, not about the job.
///
/// Four things about a spur are stated by the source and are therefore
/// checkable here:
///
///  1. **Which type.** Para. 31 is explicit that Table 13 maps a vehicle
///     designation to its spur type and part number. It is *not* a weight
///     bracket — the spur is chosen by what the vehicle is, and the weight
///     only shows through in that the heavier objects are the ones assigned
///     the bigger plates. So the type is looked up, never derived, and a
///     vehicle Table 13 does not name has no spur type at all.
///  2. **Whether spurs apply.** Following from the same sentence: a tracked
///     vehicle that Table 13 does not name is not secured with spurs. It goes
///     to the KGUUB, the wood blocks or the boots instead. Placing spurs under
///     it is a mistake in its own right, and one nothing used to catch.
///  3. **How many.** Table 10 states each type's mass as the mass of a set of
///     four (`setWeightKg4Spurs`). A set is four spurs; the count is the
///     table's own and is not a figure invented here.
///  4. **Where.** Four spurs, two tracks, two ends each — one spur at each end
///     of each track, which is the only arrangement of four that stops the
///     vehicle running either way. Each must sit under the track it works on
///     rather than beside it, and must present its comb towards the run.
///
/// What is deliberately **not** judged is the longitudinal standoff. Plate 03
/// dimensions 10-15 cm from the running gear for the squared *wood* block; no
/// figure of that kind is stated anywhere in this extract for a spur, whose
/// comb bites the track rather than wedging against it. The distance is
/// measured and reported, and left unjudged, rather than borrowed from a rule
/// written about a different piece of gear.

/// A set is four spurs — Table 10 states each type's mass per set of four.
const int kIronSpurSetCount = 4;

/// Whether iron spurs are this vehicle's securing method at all.
enum IronSpurEligibility {
  /// Table 13 names a spur type for this vehicle. Spurs are the method, and
  /// the named type is the only correct one.
  named,

  /// A tracked vehicle Table 13 does not name. Spurs are not its method;
  /// it is secured by one of the alternatives instead.
  notNamed,

  /// Not a tracked vehicle. The Ş-series seats under a track shoe and has
  /// nothing to do with a wheeled load.
  notApplicable,
}

/// One of the four places a spur seats: each track, each end of it.
enum SpurStation {
  leftRear,
  leftFront,
  rightRear,
  rightFront;

  /// `-1` for the left-hand track, `+1` for the right.
  int get trackSide =>
      this == SpurStation.leftRear || this == SpurStation.leftFront ? -1 : 1;

  /// True for the two stations at the forward end of their track.
  bool get atFront =>
      this == SpurStation.leftFront || this == SpurStation.rightFront;

  String get label => switch (this) {
        SpurStation.leftRear => AppStrings.spurStationLeftRear,
        SpurStation.leftFront => AppStrings.spurStationLeftFront,
        SpurStation.rightRear => AppStrings.spurStationRightRear,
        SpurStation.rightFront => AppStrings.spurStationRightFront,
      };

  static SpurStation of({required int trackSide, required bool atFront}) =>
      trackSide < 0
          ? (atFront ? SpurStation.leftFront : SpurStation.leftRear)
          : (atFront ? SpurStation.rightFront : SpurStation.rightRear);
}

/// What is wrong at one station, or [none] when nothing is.
enum SpurProblem {
  none,

  /// No spur at this end of this track.
  missing,

  /// More than one spur crowded onto the same station while another stands
  /// empty.
  doubled,

  /// A spur of a type other than the one Table 13 assigns this vehicle.
  wrongType,

  /// Laid beside the track rather than under it, so its comb bites the deck
  /// and nothing else.
  besideTheTrack,

  /// Comb turned away from the run: the vehicle would ride straight over it.
  wrongWay,

  /// Overlapping the bearing length rather than standing at its end — the
  /// spur is under the track's middle, where it holds nothing.
  overlapping,

  /// Spurs placed on a vehicle Table 13 does not assign them to.
  notPermitted,
}

/// What the handbook asks for, for one vehicle.
class IronSpurRequirement {
  final IronSpurEligibility eligibility;

  /// Table 13's answer, or null when it names none.
  final String? typeCode;

  /// Four, always — see [kIronSpurSetCount]. Carried on the requirement so a
  /// screen never has to know the constant.
  final int spursRequired;

  const IronSpurRequirement({
    required this.eligibility,
    this.typeCode,
    this.spursRequired = kIronSpurSetCount,
  });

  bool get spursApply => eligibility == IronSpurEligibility.named;

  /// Para. 31, which is where both the table and the rule that it governs the
  /// choice of type come from.
  String get referenceId => 'para-31';
}

/// What Table 13 asks of [vehicle].
IronSpurRequirement ironSpurRequirementFor(Vehicle vehicle) {
  if (vehicle.category != VehicleCategory.tracked) {
    return const IronSpurRequirement(
        eligibility: IronSpurEligibility.notApplicable);
  }
  final type = vehicle.ironSpurType;
  if (type == null) {
    return const IronSpurRequirement(eligibility: IronSpurEligibility.notNamed);
  }
  return IronSpurRequirement(
      eligibility: IronSpurEligibility.named, typeCode: type);
}

/// One station, and what the trainee did or did not put there.
class SpurFinding {
  final String placementId;

  /// The vehicle the spur is holding, for the sheet.
  final String designation;

  final SpurStation station;

  /// The piece that answered this station, or null when none did.
  final String? pieceId;

  /// The type code the placed spur carries, when it states one.
  final String? placedType;

  /// What Table 13 asked for, when it names one.
  final String? requiredType;

  /// How far the spur stands from the end of the bearing length, in
  /// centimetres. Reported, never judged — see the file comment. Null when
  /// no spur answered the station.
  final double? measuredCm;

  final SpurProblem problem;
  final CheckStatus status;
  final String referenceId;

  const SpurFinding({
    required this.placementId,
    required this.designation,
    required this.station,
    required this.problem,
    required this.status,
    required this.referenceId,
    this.pieceId,
    this.placedType,
    this.requiredType,
    this.measuredCm,
  });

  /// What went wrong here, in one line, or null when nothing did.
  String? get detail => switch (problem) {
        SpurProblem.none => null,
        SpurProblem.missing => AppStrings.spurMissingDetail(station.label),
        SpurProblem.doubled => AppStrings.spurDoubledDetail(station.label),
        SpurProblem.wrongType => AppStrings.spurWrongTypeDetail(
            station.label, placedType ?? '—', requiredType ?? '—'),
        SpurProblem.besideTheTrack =>
          AppStrings.spurBesideTrackDetail(station.label),
        SpurProblem.wrongWay => AppStrings.spurWrongWayDetail(station.label),
        SpurProblem.overlapping =>
          AppStrings.spurOverlappingDetail(station.label),
        SpurProblem.notPermitted => AppStrings.spurNotPermittedDetail,
      };
}

/// Measures every spur the trainee placed against the four stations a set
/// covers, and says what is wrong at each.
///
/// [seatings] are the same measurements the wood blocks are judged from, so a
/// spur and a chock on one wagon cannot be measured two different ways.
List<SpurFinding> spurFindingsFor({
  required String placementId,
  required String designation,
  required SecuringLayout layout,
  required VehicleModel3 vehicle,
  required double vehicleOffsetX,
  required IronSpurRequirement requirement,
}) {
  final spurs = [
    for (final piece in layout.pieces)
      if (piece.kind == SecuringPieceKind.ironSpur) piece,
  ];
  if (spurs.isEmpty && !requirement.spursApply) return const [];

  // Spurs on a vehicle the table does not name: one finding, because the
  // mistake is that they are here at all and naming four stations for them
  // would dress an error up as an arrangement.
  if (!requirement.spursApply) {
    return [
      SpurFinding(
        placementId: placementId,
        designation: designation,
        station: SpurStation.leftRear,
        pieceId: spurs.first.id,
        placedType: spurs.first.sizeTypeCode,
        problem: SpurProblem.notPermitted,
        status: CheckStatus.fail,
        referenceId: requirement.referenceId,
      ),
    ];
  }

  final measured = {
    for (final seating in measureBlockSeating(
      layout: SecuringLayout(spurs),
      vehicle: vehicle,
      vehicleOffsetX: vehicleOffsetX,
    ))
      seating.pieceId: seating,
  };

  // Which spur answered which station. A station is decided by the track the
  // spur sits nearest and the end of that track it stands at, both of which
  // the measurement already resolved — so a spur laid beside the track still
  // lands on the station it was aimed at, and is reported as beside it rather
  // than as a fifth spur nobody asked for.
  final atStation = <SpurStation, List<SecuringPiece>>{
    for (final station in SpurStation.values) station: <SecuringPiece>[],
  };
  for (final spur in spurs) {
    final seating = measured[spur.id];
    if (seating == null) continue;
    atStation[SpurStation.of(
      trackSide: seating.trackSide,
      atFront: seating.againstFrontOfRun,
    )]!
        .add(spur);
  }

  return [
    for (final station in SpurStation.values)
      () {
        final here = atStation[station]!;
        if (here.isEmpty) {
          return SpurFinding(
            placementId: placementId,
            designation: designation,
            station: station,
            requiredType: requirement.typeCode,
            problem: SpurProblem.missing,
            status: CheckStatus.fail,
            referenceId: requirement.referenceId,
          );
        }
        final spur = here.first;
        final seating = measured[spur.id]!;
        final problem = _problemFor(
          spur: spur,
          seating: seating,
          crowded: here.length > 1,
          requirement: requirement,
        );
        return SpurFinding(
          placementId: placementId,
          designation: designation,
          station: station,
          pieceId: spur.id,
          placedType: spur.sizeTypeCode,
          requiredType: requirement.typeCode,
          measuredCm: seating.seatingDistanceCm,
          problem: problem,
          status:
              problem == SpurProblem.none ? CheckStatus.pass : CheckStatus.fail,
          referenceId: requirement.referenceId,
        );
      }(),
  ];
}

/// The worst thing wrong with one seated spur.
///
/// Ordered so the trainee is told the thing that matters most first: a spur of
/// the wrong type is wrong wherever it sits, one beside the track holds
/// nothing whichever way it faces, and one laid backwards is a mistake even
/// when it is perfectly placed.
SpurProblem _problemFor({
  required SecuringPiece spur,
  required BlockSeating seating,
  required bool crowded,
  required IronSpurRequirement requirement,
}) {
  final required_ = requirement.typeCode;
  final placed = spur.sizeTypeCode;
  if (required_ != null && placed != null && placed != required_) {
    return SpurProblem.wrongType;
  }
  if (crowded) return SpurProblem.doubled;
  if (!seating.underRunningGear) return SpurProblem.besideTheTrack;
  if (seating.seatingDistanceM < 0) return SpurProblem.overlapping;
  if (!seating.facesTheRun) return SpurProblem.wrongWay;
  return SpurProblem.none;
}

/// The spur checks for one placement, as the analysis and the result sheet
/// read them.
///
/// Three checks, each answering a question the trainee can actually get wrong:
/// whether spurs belong on this vehicle at all, whether the right type was
/// used, and whether a full set went to the four stations.
List<ValidationCheck> ironSpurChecks({
  required IronSpurRequirement requirement,
  required List<SpurFinding> findings,
  required int spursPlaced,
}) {
  if (requirement.eligibility == IronSpurEligibility.notApplicable) {
    return const [];
  }

  if (!requirement.spursApply) {
    // Nothing placed and nothing asked for is not a finding — the vehicle is
    // simply secured another way, and the methods it *is* secured by are
    // checked elsewhere.
    if (spursPlaced == 0) return const [];
    return [
      ValidationCheck(
        ruleId: 'rule-iron-spur-applicability',
        label: AppStrings.spurApplicabilityLabel,
        status: CheckStatus.fail,
        detail: AppStrings.spurNotPermittedDetail,
        referenceId: requirement.referenceId,
      ),
    ];
  }

  final checks = <ValidationCheck>[
    ValidationCheck(
      ruleId: 'rule-iron-spur-type',
      label: AppStrings.spurTypeCheckLabel,
      status: _typeStatus(findings),
      detail: _typeDetail(requirement, findings),
      referenceId: requirement.referenceId,
    ),
    ValidationCheck(
      ruleId: 'rule-iron-spur-set-count',
      label: AppStrings.spurCountCheckLabel,
      status: spursPlaced == requirement.spursRequired
          ? CheckStatus.pass
          : CheckStatus.fail,
      detail: spursPlaced == requirement.spursRequired
          ? AppStrings.spurCountOkDetail(requirement.spursRequired)
          : AppStrings.spurCountWrongDetail(
              spursPlaced, requirement.spursRequired),
      // Para. 31, which is the paragraph Table 10 sits under. There is no
      // `table-10` reference record, and citing one would print a bare id
      // where the chip should carry a readable citation.
      referenceId: requirement.referenceId,
    ),
  ];

  // No findings at all is not four correct stations. `spurFindingsFor`
  // produces one finding per station whenever it runs, so an empty list means
  // it never ran — the placement could not be modelled, and where the spurs
  // are sitting was never measured. Reading that silence as "nothing is
  // wrong" passed the station check for five of the six vehicles Table 13
  // names, with not one spur on the wagon. Where nothing was measured the
  // check reports undecided, which is never scored as correct; the count
  // check beside it still fails an empty set.
  final wrongStations = [
    for (final finding in findings)
      if (finding.problem != SpurProblem.none) finding.station.label,
  ];
  checks.add(ValidationCheck(
    ruleId: 'rule-iron-spur-stations',
    label: AppStrings.spurStationsCheckLabel,
    status: findings.isEmpty
        ? CheckStatus.unknown
        : (wrongStations.isEmpty ? CheckStatus.pass : CheckStatus.fail),
    detail: findings.isEmpty
        ? AppStrings.spurStationsNotMeasuredDetail
        : wrongStations.isEmpty
            ? AppStrings.spurStationsOkDetail
        // Semicolons, because a station's own name carries a comma — "çep
        // gusenisa, öňki ujy" — and joining three of them with commas ran
        // six clauses together with nothing to separate the pairs.
        : AppStrings.spurStationsWrongDetail(wrongStations.join('; ')),
    referenceId: requirement.referenceId,
  ));
  return checks;
}

CheckStatus _typeStatus(List<SpurFinding> findings) {
  var sawType = false;
  for (final finding in findings) {
    if (finding.problem == SpurProblem.wrongType) return CheckStatus.fail;
    if (finding.placedType != null) sawType = true;
  }
  // No spur states a type yet — nothing has been got wrong and nothing has
  // been got right. The handbook's answer is still shown in the detail.
  return sawType ? CheckStatus.pass : CheckStatus.unknown;
}

String _typeDetail(
  IronSpurRequirement requirement,
  List<SpurFinding> findings,
) {
  final required_ = requirement.typeCode ?? '—';
  for (final finding in findings) {
    if (finding.problem == SpurProblem.wrongType) {
      return AppStrings.spurWrongTypeDetail(
          finding.station.label, finding.placedType ?? '—', required_);
    }
  }
  final sawType = findings.any((f) => f.placedType != null);
  return sawType
      ? AppStrings.spurTypeOkDetail(required_)
      : AppStrings.spurTypeNotStatedDetail(required_);
}
