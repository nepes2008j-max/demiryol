import '../../core/localization/app_strings.dart';
import '../../data/models/simulation_result.dart';
import '../../data/models/vehicle.dart';
import '../models/chock_arrangement.dart';

/// Builds the selectable chock arrangements for a vehicle straight out of
/// `rules.json`, the same way `equipment_catalog.dart` builds equipment
/// options out of `measurements.json`: every count, distance and gap here is
/// read from the data with its citation, and a missing rule yields an empty
/// list rather than an invented case.
///
/// The arrangements are the plates' own: six layout cases for wheeled
/// vehicles (`rule-wheeled-chock-arrangement`, plate-06) and two seating
/// distances for tracked ones (`rule-tracked-chock-seating-distance`,
/// plate-03, with the counts from `rule-tracked-chock-arrangement`,
/// plate-02).

Map<String, dynamic>? _rule(Map<String, dynamic> rules, String id) {
  for (final entry in (rules['rules'] as List?) ?? const []) {
    final map = entry as Map<String, dynamic>;
    if (map['id'] == id) return map;
  }
  return null;
}

int? _int(Object? raw) => raw is num ? raw.toInt() : null;
double? _double(Object? raw) => raw is num ? raw.toDouble() : null;

/// Every arrangement the handbook draws for this vehicle, in the order the
/// plate draws them.
///
/// [overCoupling] selects the half of the wheeled cases drawn for a vehicle
/// standing across the coupling of two open wagons — `PlacedVehicle.spansCoupling`
/// already carries that fact, so it is never inferred from a coordinate.
List<ChockArrangement> chockArrangementsFor(
  Vehicle vehicle, {
  required bool overCoupling,
  required Map<String, dynamic> rules,
}) {
  switch (vehicle.category) {
    case VehicleCategory.tracked:
      return _trackedArrangements(rules, overCoupling: overCoupling);
    case VehicleCategory.wheeled:
      return _wheeledArrangements(rules, overCoupling: overCoupling);
    case VehicleCategory.unknown:
      return const [];
  }
}

/// The tracked pair: the same four chocks and four inserts, seated at the
/// standard 10-15 cm from the running gear or at the alternate 10-20 cm the
/// plate's own panels show.
///
/// Both apply whether or not the vehicle stands across a coupling — the
/// plate draws that distinction for wheeled layouts, not for these seating
/// distances — so each case is stamped with the situation it is being
/// offered for. Leaving it at the default `false` made
/// [checkChockArrangement]'s coupling comparison fail every tracked vehicle
/// placed over a coupling, no matter which case the trainee picked.
List<ChockArrangement> _trackedArrangements(
  Map<String, dynamic> rules, {
  required bool overCoupling,
}) {
  final counts = _rule(rules, 'rule-tracked-chock-arrangement');
  final seating = _rule(rules, 'rule-tracked-chock-seating-distance');
  if (counts == null || seating == null) return const [];

  final chocks = _int(counts['longitudinalChocksPerVehicle']);
  final inserts = _int(counts['transverseInsertsPerVehicle']);
  if (chocks == null || inserts == null) return const [];

  final standardMin = _int(seating['distanceCmMin']);
  final standardMax = _int(seating['distanceCmMax']);
  final altMin = _int(seating['altDistanceCmMin']);
  final altMax = _int(seating['altDistanceCmMax']);

  final referenceId = (seating['referenceId'] as String?) ?? '';
  return [
    if (standardMin != null && standardMax != null)
      ChockArrangement(
        id: 'tracked-seating-standard',
        appliesTo: VehicleCategory.tracked,
        label: AppStrings.chockArrangementTrackedStandard(standardMin, standardMax),
        chockCount: chocks,
        insertCount: inserts,
        spansCoupling: overCoupling,
        seatingDistance: (minCm: standardMin, maxCm: standardMax),
        referenceId: referenceId,
      ),
    if (altMin != null && altMax != null)
      ChockArrangement(
        id: 'tracked-seating-alternate',
        appliesTo: VehicleCategory.tracked,
        label: AppStrings.chockArrangementTrackedAlternate(altMin, altMax),
        chockCount: chocks,
        insertCount: inserts,
        spansCoupling: overCoupling,
        seatingDistance: (minCm: altMin, maxCm: altMax),
        referenceId: referenceId,
      ),
  ];
}

/// The three wheeled cases drawn for this side of the coupling question.
List<ChockArrangement> _wheeledArrangements(
  Map<String, dynamic> rules, {
  required bool overCoupling,
}) {
  final arrangement = _rule(rules, 'rule-wheeled-chock-arrangement');
  if (arrangement == null) return const [];
  final gapRule = _rule(rules, 'rule-lateral-chock-gap');

  ({int minMm, int maxMm})? gap;
  if (gapRule != null) {
    final min = _int(overCoupling ? gapRule['overCouplingGapMmMin'] : gapRule['gapMmMin']);
    final max = _int(overCoupling ? gapRule['overCouplingGapMmMax'] : gapRule['gapMmMax']);
    if (min != null && max != null) gap = (minMm: min, maxMm: max);
  }

  final referenceId = (arrangement['referenceId'] as String?) ?? '';
  final cases = <ChockArrangement>[];
  for (final entry in (arrangement['cases'] as List?) ?? const []) {
    final map = entry as Map<String, dynamic>;
    if ((map['spansCoupling'] as bool? ?? false) != overCoupling) continue;
    final base = _int(map['baseChockCount']);
    if (base == null) continue;
    final doubled = map['doubled'] as bool? ?? false;
    final axles = _int(map['axleCount']);
    final maxWeight = _double(map['combatWeightMaxT']);
    cases.add(ChockArrangement(
      id: map['id'] as String,
      appliesTo: VehicleCategory.wheeled,
      label: AppStrings.chockArrangementWheeled(
        axles: axles,
        maxWeightT: maxWeight,
        overCoupling: overCoupling,
      ),
      // The plate states the doubling as a rule about the count, so the count
      // is doubled here rather than left to whoever renders it.
      chockCount: doubled ? base * 2 : base,
      doubled: doubled,
      doublingReason: map['doublingReason'] as String?,
      spansCoupling: overCoupling,
      axleCount: axles,
      combatWeightMaxT: maxWeight,
      lateralGap: gap,
      referenceId: referenceId,
    ));
  }
  return _withDerivedWeightFloors(cases);
}

/// Gives each case the bottom of its bracket, taken from the top of the case
/// below it.
///
/// The plate's cases are a partition of the weight range for a given axle
/// count — "four chocks up to 5.5 t, eight for 5.6-12 t" — but the data
/// records only each bracket's top, and [ChockArrangement.matches] therefore
/// accepted any case whose top was high enough. A 3.25 t lorry matched the
/// eight-chock case as well as the four-chock one, so the trainee was marked
/// correct whichever they chose.
///
/// No figure is invented here: the bottom of a bracket is read off the case
/// beneath it in the same axle-count group. The lightest case of a group keeps
/// no bottom, and a case whose group has only one member is unchanged.
List<ChockArrangement> _withDerivedWeightFloors(List<ChockArrangement> cases) {
  final byAxles = <int?, List<ChockArrangement>>{};
  for (final c in cases) {
    (byAxles[c.axleCount] ??= <ChockArrangement>[]).add(c);
  }
  final floors = <String, double>{};
  for (final group in byAxles.values) {
    final graded = [for (final c in group) if (c.combatWeightMaxT != null) c]
      ..sort((a, b) => a.combatWeightMaxT!.compareTo(b.combatWeightMaxT!));
    for (var i = 1; i < graded.length; i++) {
      floors[graded[i].id] = graded[i - 1].combatWeightMaxT!;
    }
  }
  if (floors.isEmpty) return cases;
  return [
    for (final c in cases)
      if (floors[c.id] == null)
        c
      else
        ChockArrangement(
          id: c.id,
          appliesTo: c.appliesTo,
          label: c.label,
          chockCount: c.chockCount,
          insertCount: c.insertCount,
          doubled: c.doubled,
          doublingReason: c.doublingReason,
          spansCoupling: c.spansCoupling,
          axleCount: c.axleCount,
          combatWeightMaxT: c.combatWeightMaxT,
          combatWeightMinT: floors[c.id],
          seatingDistance: c.seatingDistance,
          lateralGap: c.lateralGap,
          referenceId: c.referenceId,
        ),
  ];
}

/// The two documented ways of restraining a tracked vehicle sideways. Empty
/// for a wheeled vehicle: the plate gives this choice only for tracked ones.
List<LateralRestraintOption> lateralRestraintOptionsFor(
  Vehicle vehicle,
  Map<String, dynamic> rules,
) {
  if (vehicle.category != VehicleCategory.tracked) return const [];
  final rule = _rule(rules, 'rule-tracked-chock-arrangement');
  if (rule == null) return const [];

  final options = <LateralRestraintOption>[];
  for (final entry in (rule['lateralRestraintOptions'] as List?) ?? const []) {
    final map = entry as Map<String, dynamic>;
    final id = map['id'] as String?;
    if (id == null) continue;
    final staples = _int(map['staples']);
    final blockSize = map['blockSizeMm'] as String?;
    options.add(LateralRestraintOption(
      id: id,
      label: staples != null
          ? AppStrings.lateralRestraintStaples(staples)
          : AppStrings.lateralRestraintSideBlocks(blockSize ?? ''),
      description: (map['description'] as String?) ?? '',
      staples: staples,
      blockSizeMm: blockSize,
      referenceId: (rule['referenceId'] as String?) ?? '',
    ));
  }
  return options;
}

/// The arrangement the handbook's own rule picks for this vehicle, or null
/// when the vehicle's data cannot decide it.
///
/// Null is the normal answer today: the case is chosen by combat weight and
/// axle count, and no vehicle in the extract records a combat weight. The UI
/// must then offer every case as unconfirmed rather than pre-selecting one —
/// the same rule the securing-method selector follows.
ChockArrangement? recommendedArrangement(
  Vehicle vehicle,
  List<ChockArrangement> arrangements, {
  required bool overCoupling,
}) {
  final weight = vehicle.bracketWeightT.asDouble;
  if (weight == null) return null;
  if (vehicle.category == VehicleCategory.tracked) return null;

  for (final arrangement in arrangements) {
    if (arrangement.matches(
      weightT: weight,
      axles: vehicle.axleCount,
      overCoupling: overCoupling,
    )) {
      return arrangement;
    }
  }
  return null;
}


/// Scores the chosen chock layout case against the vehicle's own data.
///
/// Pure, like `checkEquipmentSelection` in `equipment_selection.dart`, so the
/// rule can be tested without a repository and so `EngineeringValidator` keeps
/// no second copy of it.
///
/// The case the plates draw is decided by combat weight and axle count, and no
/// vehicle in the extract records a combat weight — so the usual answer is
/// UNKNOWN, naming what is missing. That is deliberate: the choice is offered
/// so a trainee can work through it, but a case cannot be called correct
/// against a number the source does not have. The one thing always checkable
/// is the coupling case, because whether the vehicle stands across a coupling
/// is a fact `PlacedVehicle` carries rather than a measurement.
ValidationCheck checkChockArrangement({
  required Vehicle vehicle,
  required ChockArrangement? chosen,
  required bool spansCoupling,
}) {
  if (chosen == null) {
    return const ValidationCheck(
      ruleId: 'rule-chock-arrangement-selected',
      label: AppStrings.chockArrangementCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.chockArrangementNotSelectedDetail,
      referenceId: 'plate-06',
    );
  }

  if (chosen.spansCoupling != spansCoupling) {
    return ValidationCheck(
      ruleId: 'rule-chock-arrangement-selected',
      label: AppStrings.chockArrangementCheckLabel,
      status: CheckStatus.fail,
      detail: AppStrings.chockArrangementWrongCouplingCaseDetail(spansCoupling),
      referenceId: chosen.referenceId,
    );
  }

  final weight = vehicle.bracketWeightT.asDouble;
  if (weight == null) {
    return ValidationCheck(
      ruleId: 'rule-chock-arrangement-selected',
      label: AppStrings.chockArrangementCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.chockArrangementUnconfirmedDetail(chosen.chockCount),
      referenceId: chosen.referenceId,
    );
  }

  final matches = chosen.matches(
    weightT: weight,
    axles: vehicle.axleCount,
    overCoupling: spansCoupling,
  );
  return ValidationCheck(
    ruleId: 'rule-chock-arrangement-selected',
    label: AppStrings.chockArrangementCheckLabel,
    status: matches ? CheckStatus.pass : CheckStatus.fail,
    detail: matches
        ? AppStrings.chockArrangementAppliedDetail(chosen.chockCount)
        : AppStrings.chockArrangementWrongBracketDetail(weight),
    referenceId: chosen.referenceId,
  );
}
