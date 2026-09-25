import '../../core/localization/app_strings.dart';
import '../../data/models/simulation_result.dart';
import '../../data/models/vehicle.dart';

/// One vehicle standing on the wagon whose budget is being worked out.
class VehicleOnWagon {
  final String placementId;
  final String designation;
  final VehicleCategory category;

  /// The vehicle's length in centimetres, from its record or from a figure
  /// the instructor typed in. Null when neither exists — which is the normal
  /// case for a handbook-extracted vehicle, since the extract dimensions
  /// nothing.
  final double? lengthCm;

  /// True when this vehicle rests across the coupling of two wagons.
  final bool spansCoupling;

  /// True when the wagon being budgeted is the first of the two it spans.
  /// The length is counted there and nowhere else, so a coupling-spanning
  /// vehicle is never charged to two wagons at once.
  final bool isPrimaryWagon;

  const VehicleOnWagon({
    required this.placementId,
    required this.designation,
    required this.category,
    required this.lengthCm,
    this.spansCoupling = false,
    this.isPrimaryWagon = true,
  });

  bool get countsAgainstThisWagon => !spansCoupling || isPrimaryWagon;
}

/// How much of a wagon's deck the load uses, and how much is left.
///
/// Every quantity is either measured or explicitly absent: [deckLengthCm] and
/// each vehicle's length come from the data or from an instructor's entry,
/// and the gap between neighbours comes from the plates' own clearance rule.
/// When a figure is missing the budget says which one, rather than filling it
/// in — a "remaining 4.2 m" produced from a guessed deck length would be the
/// most dangerous number in the app.
class WagonLengthBudget {
  final double? deckLengthCm;

  /// Summed length of the vehicles counted against this wagon.
  final double vehiclesLengthCm;

  /// Total clearance the handbook requires between those vehicles.
  final double clearanceCm;

  /// The largest per-gap clearance in play, in millimetres, and the plate case
  /// it came from.
  final int? gapMm;
  final String? gapCase;

  /// How many gaps were charged — one fewer than the number of vehicles
  /// counted. Carried explicitly because it cannot be recovered from the
  /// total: a mixed load charges gaps of different sizes, so dividing the
  /// total by the largest one under-reports them.
  final int gapCount;

  /// Vehicles on the wagon whose length nothing could supply.
  final List<String> vehiclesWithoutLength;

  /// Vehicles resting across a coupling, whose length is charged to the first
  /// wagon of the pair.
  final List<String> spanningVehicles;

  final String referenceId;

  const WagonLengthBudget({
    required this.deckLengthCm,
    required this.vehiclesLengthCm,
    required this.clearanceCm,
    required this.gapMm,
    required this.gapCase,
    required this.gapCount,
    required this.vehiclesWithoutLength,
    required this.spanningVehicles,
    required this.referenceId,
  });

  /// Deck taken by vehicles plus the clearances between them.
  double get usedCm => vehiclesLengthCm + clearanceCm;

  /// What is left of the deck, or null while any figure is missing.
  double? get remainingCm =>
      isComputable ? (deckLengthCm! - usedCm) : null;

  /// True only when every input exists: the deck length and every vehicle's
  /// length.
  bool get isComputable => deckLengthCm != null && vehiclesWithoutLength.isEmpty;

  bool get isOverloaded => (remainingCm ?? 0) < 0;

  /// Fraction of the deck in use, clamped for a progress bar. Null when the
  /// budget cannot be computed.
  double? get usedFraction {
    if (!isComputable || deckLengthCm! <= 0) return null;
    return (usedCm / deckLengthCm!).clamp(0.0, 1.0);
  }
}

Map<String, dynamic>? _rule(Map<String, dynamic> rules, String id) {
  for (final entry in (rules['rules'] as List?) ?? const []) {
    final map = entry as Map<String, dynamic>;
    if (map['id'] == id) return map;
  }
  return null;
}

/// The clearance the plates require between two neighbouring vehicles on one
/// wagon, chosen by what the pair is.
///
/// plate-02 dimensions 100 mm between two tracked vehicles on one flatcar and
/// 270 mm between vehicles in a mixed row; plate-05 dimensions 50 mm between
/// wheeled vehicles in a row. A mixed pair takes the mixed-row figure, which
/// is the larger of the two and the only one the source states for vehicles
/// of different kinds standing together.
({int mm, String case_, String referenceId})? clearanceBetween(
  VehicleCategory a,
  VehicleCategory b,
  Map<String, dynamic> rules,
) {
  final rule = _rule(rules, 'rule-placement-clearance');
  final cases = (rule?['clearances'] as List?) ?? const [];
  String wanted;
  if (a == VehicleCategory.tracked && b == VehicleCategory.tracked) {
    wanted = 'between two tracked vehicles on one flatcar';
  } else if (a == VehicleCategory.wheeled && b == VehicleCategory.wheeled) {
    wanted = 'between wheeled vehicles in a row';
  } else {
    wanted = 'between vehicles in a mixed consist row';
  }
  for (final entry in cases) {
    final map = entry as Map<String, dynamic>;
    if (map['case'] == wanted) {
      final mm = map['minMm'];
      if (mm is num) {
        return (
          mm: mm.toInt(),
          case_: wanted,
          referenceId: (map['referenceId'] as String?) ??
              (rule?['referenceId'] as String?) ??
              '',
        );
      }
    }
  }
  return null;
}

/// Checks the measured space between two neighbouring loads against what the
/// plates dimension for that pair.
///
/// The gap comes from the three-dimensional scene, measured between the loads'
/// full extents; the requirement comes from [clearanceBetween]. Until both
/// existed this rule was in the data and read by nothing — the app knew that
/// two tracked vehicles on one flatcar need 100 mm between them and had no way
/// to find out whether they had it.
ValidationCheck checkPlacementClearance({
  required double gapMm,
  required String rearDesignation,
  required String frontDesignation,
  required VehicleCategory rearCategory,
  required VehicleCategory frontCategory,
  required Map<String, dynamic> rules,
}) {
  final required = clearanceBetween(rearCategory, frontCategory, rules);
  if (required == null) {
    return const ValidationCheck(
      ruleId: 'rule-placement-clearance',
      label: AppStrings.placementClearanceCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.placementClearanceUnknownDetail,
      referenceId: 'plate-02',
    );
  }
  if (gapMm < 0) {
    return ValidationCheck(
      ruleId: 'rule-placement-clearance',
      label: AppStrings.placementClearanceCheckLabel,
      status: CheckStatus.fail,
      detail: AppStrings.placementClearanceOverlapDetail(
          rearDesignation, frontDesignation, -gapMm),
      referenceId: required.referenceId,
    );
  }
  final ok = gapMm >= required.mm;
  return ValidationCheck(
    ruleId: 'rule-placement-clearance',
    label: AppStrings.placementClearanceCheckLabel,
    status: ok ? CheckStatus.pass : CheckStatus.fail,
    detail: ok
        ? AppStrings.placementClearanceOkDetail(
            rearDesignation, frontDesignation, gapMm, required.mm)
        : AppStrings.placementClearanceTooCloseDetail(
            rearDesignation, frontDesignation, gapMm, required.mm),
    referenceId: required.referenceId,
  );
}

/// Works out the deck budget for one wagon.
///
/// [vehicles] must be in the order they stand along the wagon, because the
/// clearance is charged once per gap between neighbours — n vehicles have
/// n-1 gaps, and charging one per vehicle would quietly consume a gap's worth
/// of deck that the handbook does not ask for.
WagonLengthBudget wagonLengthBudget({
  required double? deckLengthCm,
  required List<VehicleOnWagon> vehicles,
  required Map<String, dynamic> rules,
}) {
  final counted = vehicles.where((v) => v.countsAgainstThisWagon).toList();

  var lengthCm = 0.0;
  final missing = <String>[];
  for (final vehicle in counted) {
    final length = vehicle.lengthCm;
    if (length == null) {
      missing.add(vehicle.designation);
    } else {
      lengthCm += length;
    }
  }

  var clearanceCm = 0.0;
  var gapCount = 0;
  int? gapMm;
  String? gapCase;
  var referenceId = '';
  for (var i = 1; i < counted.length; i++) {
    final gap = clearanceBetween(counted[i - 1].category, counted[i].category, rules);
    if (gap == null) continue;
    clearanceCm += gap.mm / 10.0;
    gapCount++;
    // Report the largest gap in play, so the panel names the binding case.
    if (gapMm == null || gap.mm > gapMm) {
      gapMm = gap.mm;
      gapCase = gap.case_;
      referenceId = gap.referenceId;
    }
  }

  return WagonLengthBudget(
    deckLengthCm: deckLengthCm,
    vehiclesLengthCm: lengthCm,
    clearanceCm: clearanceCm,
    gapMm: gapMm,
    gapCase: gapCase,
    gapCount: gapCount,
    vehiclesWithoutLength: missing,
    spanningVehicles: [
      for (final v in vehicles.where((v) => v.spansCoupling)) v.designation,
    ],
    referenceId: referenceId,
  );
}

/// Scores the wagon's load against its deck.
///
/// FAIL only when the numbers actually say the load does not fit; UNKNOWN
/// while any length is missing, naming what is needed to decide it. Nothing
/// here guesses a deck length: with no dimension in the handbook extract, an
/// invented one would turn every overload into a pass or every fit into a
/// failure.
ValidationCheck checkWagonCapacity(WagonLengthBudget budget) {
  if (budget.deckLengthCm == null) {
    return const ValidationCheck(
      ruleId: 'rule-wagon-length-budget',
      label: AppStrings.wagonCapacityCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.wagonCapacityNoDeckLengthDetail,
      referenceId: 'para-51',
    );
  }
  if (budget.vehiclesWithoutLength.isNotEmpty) {
    return ValidationCheck(
      ruleId: 'rule-wagon-length-budget',
      label: AppStrings.wagonCapacityCheckLabel,
      status: CheckStatus.unknown,
      detail: AppStrings.wagonCapacityNoVehicleLengthDetail(
          budget.vehiclesWithoutLength.join(', ')),
      referenceId: 'para-51',
    );
  }
  final remaining = budget.remainingCm!;
  if (remaining < 0) {
    return ValidationCheck(
      ruleId: 'rule-wagon-length-budget',
      label: AppStrings.wagonCapacityCheckLabel,
      status: CheckStatus.fail,
      detail: AppStrings.wagonCapacityOverloadedDetail(
          (-remaining).toStringAsFixed(0), budget.gapMm ?? 0),
      referenceId: budget.referenceId.isEmpty ? 'para-51' : budget.referenceId,
    );
  }
  return ValidationCheck(
    ruleId: 'rule-wagon-length-budget',
    label: AppStrings.wagonCapacityCheckLabel,
    status: CheckStatus.pass,
    detail: AppStrings.wagonCapacityFitsDetail(remaining.toStringAsFixed(0)),
    referenceId: budget.referenceId.isEmpty ? 'para-51' : budget.referenceId,
  );
}
