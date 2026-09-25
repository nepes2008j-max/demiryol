import '../../data/models/vehicle.dart';

/// Which way a squared wood block lies on the wagon floor.
///
/// The distinction is not cosmetic: a longitudinal block (direg dörtgyraň agaç
/// bölegi) stops the vehicle rolling along the wagon and takes four nails,
/// while a lateral one (gapdal dörtgyraň agaç bölegi) lies across the wagon
/// under the tyre, sits 20-30 mm off its outer face and takes six.
enum ChockOrientation { longitudinal, lateral }

/// One documented way of seating the chocks under a vehicle.
///
/// Every field is read from `rules.json`, never chosen here — see
/// `chock_arrangement_catalog.dart`. The plates draw six cases for wheeled
/// vehicles (weight bracket x axle count, each on a single wagon and again
/// over the coupling of two) and two seating distances for tracked ones, and
/// until now the app hard-coded a single pair of chock positions and offered
/// none of them.
class ChockArrangement {
  final String id;
  final VehicleCategory appliesTo;

  /// Turkmen label for the choice list.
  final String label;

  /// Longitudinal squared blocks this arrangement calls for.
  final int chockCount;

  /// Transverse half-round insert blocks (tracked only; 0 for wheeled).
  final int insertCount;

  /// True where the plate doubles the count, with [doublingReason] naming
  /// which of its two conditions applied.
  final bool doubled;
  final String? doublingReason;

  /// The case is drawn for a vehicle standing over the coupling of two open
  /// wagons rather than on one.
  final bool spansCoupling;

  /// Axle count the case is drawn for, when it is drawn for a particular one.
  final int? axleCount;

  /// Upper bound of the weight bracket the case belongs to, in tonnes.
  final double? combatWeightMaxT;

  /// Lower bound of that bracket, exclusive, in tonnes — the top of the case
  /// below it in the same axle-count group.
  ///
  /// Not a figure of its own: the plate's cases are a partition ("four chocks
  /// up to 5.5 t, eight for 5.6-12 t"), so the bottom of one bracket is the
  /// top of the one under it, and `chock_arrangement_catalog.dart` derives it
  /// there rather than anybody writing a new number down. Null for the
  /// lightest case of a group, which has no bottom.
  ///
  /// It exists because [matches] only ever read [combatWeightMaxT]: the
  /// eight-chock case matched a 3.25 t lorry as readily as the four-chock one
  /// did, so whichever the trainee picked was marked correct.
  final double? combatWeightMinT;

  /// Seating distance of the chock from the running gear (tracked).
  final ({int minCm, int maxCm})? seatingDistance;

  /// Gap between a lateral chock and the tyre's outer face (wheeled).
  final ({int minMm, int maxMm})? lateralGap;

  final String referenceId;

  const ChockArrangement({
    required this.id,
    required this.appliesTo,
    required this.label,
    required this.chockCount,
    this.insertCount = 0,
    this.doubled = false,
    this.doublingReason,
    this.spansCoupling = false,
    this.axleCount,
    this.combatWeightMaxT,
    this.combatWeightMinT,
    this.seatingDistance,
    this.lateralGap,
    required this.referenceId,
  });

  /// True when this case is the one the handbook draws for a vehicle of
  /// [weightT] tonnes with [axles] axles standing over (or not over) a
  /// coupling. Null weight means the bracket cannot be decided — the caller
  /// must then treat *every* case as unconfirmed rather than picking one.
  bool matches({double? weightT, int? axles, required bool overCoupling}) {
    if (spansCoupling != overCoupling) return false;
    if (axleCount != null && axles != null && axleCount != axles) return false;
    if (combatWeightMaxT != null && weightT != null && weightT > combatWeightMaxT!) {
      return false;
    }
    // Exclusive: the bound is the top of the bracket below, and that bracket
    // owns its own top ("up to 5.5 t" takes a vehicle of exactly 5.5 t).
    if (combatWeightMinT != null && weightT != null && weightT <= combatWeightMinT!) {
      return false;
    }
    return true;
  }
}

/// One of the two ways the plate allows a tracked vehicle to be stopped from
/// sliding sideways: twelve iron staples, or squared blocks along the track's
/// faces. The plate joins them with "ýa-da" — either, not both — so this is a
/// genuine choice for the trainee, not a detail to be assumed.
class LateralRestraintOption {
  final String id;
  final String label;
  final String description;
  final int? staples;
  final String? blockSizeMm;
  final String referenceId;

  const LateralRestraintOption({
    required this.id,
    required this.label,
    required this.description,
    this.staples,
    this.blockSizeMm,
    required this.referenceId,
  });
}

/// What the trainee chose for one placement: which layout case, and (for a
/// tracked vehicle) which lateral restraint. Kept as one object so the two
/// travel together through the providers and the schematic builder.
class ChockChoice {
  final String? arrangementId;
  final String? lateralRestraintId;

  const ChockChoice({this.arrangementId, this.lateralRestraintId});

  ChockChoice copyWith({String? arrangementId, String? lateralRestraintId}) =>
      ChockChoice(
        arrangementId: arrangementId ?? this.arrangementId,
        lateralRestraintId: lateralRestraintId ?? this.lateralRestraintId,
      );

  bool get isEmpty => arrangementId == null && lateralRestraintId == null;

  @override
  bool operator ==(Object other) =>
      other is ChockChoice &&
      other.arrangementId == arrangementId &&
      other.lateralRestraintId == lateralRestraintId;

  @override
  int get hashCode => Object.hash(arrangementId, lateralRestraintId);
}
