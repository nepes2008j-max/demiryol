import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/platform.dart';
import '../../data/models/vehicle.dart';
import '../../data/models/simulation_result.dart';
import '../../domain/models/schematic_element.dart';
import '../../domain/models/train_consist.dart';
import '../../domain/models/attempt_event.dart';
import '../../domain/models/chock_arrangement.dart';
import '../../domain/models/securing_placement.dart';
import '../../domain/models/trainee.dart';
import '../../domain/usecases/chock_arrangement_catalog.dart';
import '../../domain/usecases/deck_position.dart';
import '../../domain/usecases/flatcar_mesh_builder.dart';
import '../../domain/usecases/iron_spur_rules.dart';
import '../../domain/usecases/layout_conformance.dart';
import '../../domain/usecases/layout_derived_securing.dart';
import '../../domain/usecases/loading_scene_builder.dart';
import '../../domain/usecases/securing_measurements.dart';
import '../../domain/usecases/vehicle_mesh_catalog.dart';
import '../../domain/usecases/echelon_composition.dart';
import '../../domain/usecases/schematic_builder.dart';
import '../../domain/usecases/scoring.dart';
import '../../domain/usecases/wagon_capacity.dart';
import 'handbook_providers.dart';

/// State for the five-step loading flow: how many wagons, of what type, which
/// vehicles and how many of each, where the user placed them, and what each
/// placement is secured with.
///
/// This replaced the one-vehicle/one-platform pair the older wizard screens
/// used; those providers are gone, along with the Connect and Platform
/// Selection screens they served.
///
/// The invariant the old providers held is kept: a placement's [offset] is
/// presentation-only interaction state and must never be handed to
/// `EngineeringValidator` as a measurement. Whether a placement is correct is
/// decided from the case it represents — which wagons it rests on, the
/// vehicle's own data, and the handbook's layout rules — never from where the
/// user happened to drop it on a not-to-scale drawing.

/// How many wagons the user asked for in step 1.
/// Who is sitting this attempt.
///
/// Cleared with everything else when an attempt ends, so the next person to
/// sit down is asked for their own name rather than inheriting the last one's.
class TraineeNotifier extends StateNotifier<Trainee> {
  TraineeNotifier() : super(Trainee.unknown);

  void set(String givenName, String familyName) =>
      state = Trainee(givenName: givenName, familyName: familyName);

  void reset() => state = Trainee.unknown;
}

final traineeProvider =
    StateNotifierProvider<TraineeNotifier, Trainee>((ref) => TraineeNotifier());

/// Clears everything belonging to one attempt.
///
/// There was no such function, and nothing called any of the individual
/// `reset` methods: finishing an attempt and starting another left the
/// previous train, the previous equipment choices, the previous securing
/// layout and the previous wrong-action log all in place, so the second
/// attempt began half-done and was scored on the first one's mistakes.
///
/// Everything an attempt touched is listed here on purpose. A new piece of
/// per-attempt state that is not added to this list is a bug that will only
/// show up as a second attempt behaving oddly, which is the hardest kind to
/// notice — `test/attempt_lifecycle_test.dart` holds the list to the providers.
void resetAttempt(WidgetRef ref) {
  ref.read(traineeProvider.notifier).reset();
  ref.read(consistProvider.notifier).reset();
  ref.read(vehicleOrdersProvider.notifier).clear();
  ref.read(equipmentOrdersProvider.notifier).clear();
  ref.read(placementEquipmentProvider.notifier).reset();
  ref.read(placementSecuringMethodProvider.notifier).reset();
  ref.read(placementChockChoiceProvider.notifier).reset();
  ref.read(placementSecuringLayoutProvider.notifier).clear();
  ref.read(userDimensionsProvider.notifier).reset();
  ref.read(attemptLogProvider.notifier).reset();
  ref.read(wagonCountProvider.notifier).state = 0;
  ref.read(selectedWagonTypeProvider.notifier).state = null;
  ref.read(selectedPlacementIdProvider.notifier).state = null;
  ref.read(selectedVehicleCategoryProvider.notifier).state = null;
}

final wagonCountProvider = StateProvider<int>((ref) => 0);

/// The `platforms.json` id of the wagon type chosen in step 3, applied to
/// every wagon in the consist. Null until the user picks one.
final selectedWagonTypeProvider = StateProvider<String?>((ref) => null);

/// Which vehicle designations the user has added, and how many of each.
class VehicleOrdersNotifier extends StateNotifier<List<VehicleOrder>> {
  VehicleOrdersNotifier() : super(const []);

  /// Tapping a vehicle card adds one more of it — the interaction slide 3 of
  /// the customer brief asks for ("näçe gezek bassa şonçada ... awtomat
  /// köpelmeli").
  void add(String vehicleId) {
    final existing = _indexOf(vehicleId);
    if (existing == -1) {
      state = [...state, VehicleOrder(vehicleId: vehicleId, quantity: 1)];
      return;
    }
    state = [
      for (final o in state)
        if (o.vehicleId == vehicleId) o.withQuantity(o.quantity + 1) else o,
    ];
  }

  /// Removes one copy, dropping the row entirely at zero so the summary never
  /// shows "0 x T-54".
  void removeOne(String vehicleId) {
    final index = _indexOf(vehicleId);
    if (index == -1) return;
    final next = state[index].quantity - 1;
    state = [
      for (final o in state)
        if (o.vehicleId != vehicleId) o else if (next > 0) o.withQuantity(next),
    ];
  }

  void clear() => state = const [];

  int quantityOf(String vehicleId) {
    final index = _indexOf(vehicleId);
    return index == -1 ? 0 : state[index].quantity;
  }

  int get totalVehicles => state.fold(0, (sum, o) => sum + o.quantity);

  int _indexOf(String vehicleId) {
    for (var i = 0; i < state.length; i++) {
      if (state[i].vehicleId == vehicleId) return i;
    }
    return -1;
  }
}

final vehicleOrdersProvider =
    StateNotifierProvider<VehicleOrdersNotifier, List<VehicleOrder>>(
  (ref) => VehicleOrdersNotifier(),
);

/// How many of each piece of securing gear the trainee has asked for.
///
/// The mirror of [vehicleOrdersProvider], one step later in the operation. A
/// trainee orders vehicles and then puts them on wagons; they order gear the
/// same way and then seat it against the running gear. Keyed by the piece's
/// kind and the table row it came from — "ironSpur|Ş-303" — because the
/// handbook's tables carry several rows of the same kind and a count against
/// the kind alone would not say which row was meant.
///
/// Nothing here decides anything: the count is what the trainee asked for, and
/// what they actually seated is [placementSecuringLayoutProvider]. The two are
/// shown side by side so the difference is visible, which is the point.
class EquipmentOrdersNotifier extends StateNotifier<Map<String, int>> {
  EquipmentOrdersNotifier() : super(const {});

  /// The key a piece is counted under.
  static String keyFor(SecuringPieceKind kind, String typeCode) =>
      '${kind.name}|$typeCode';

  void add(String key) => state = {...state, key: (state[key] ?? 0) + 1};

  /// Removes one, dropping the row at zero so a tally never reads "0 ×".
  void removeOne(String key) {
    final next = (state[key] ?? 0) - 1;
    final out = {...state};
    if (next > 0) {
      out[key] = next;
    } else {
      out.remove(key);
    }
    state = out;
  }

  void setCount(String key, int count) {
    final out = {...state};
    if (count > 0) {
      out[key] = count;
    } else {
      out.remove(key);
    }
    state = out;
  }

  int countOf(String key) => state[key] ?? 0;

  int get total => state.values.fold(0, (sum, n) => sum + n);

  void clear() => state = const {};
}

final equipmentOrdersProvider =
    StateNotifierProvider<EquipmentOrdersNotifier, Map<String, int>>(
        (ref) => EquipmentOrdersNotifier());


/// The train being loaded — the wagons, and every vehicle placed on them.
///
/// Deliberately a thin wrapper: every transition lives on [TrainConsist] and
/// the clamping lives on [SchematicBuilder], both of which are pure and
/// covered by `dart test`. This class cannot be tested there itself, because
/// importing it pulls in `flutter_riverpod` and therefore `package:flutter`.
class ConsistNotifier extends StateNotifier<TrainConsist> {
  ConsistNotifier() : super(const TrainConsist());

  /// Rebuilds the wagon list from the step-1 count and step-3 type. Called
  /// whenever either changes; placements on wagons that no longer exist are
  /// dropped by [TrainConsist.withWagons] rather than left dangling.
  void setWagons({required int count, required String platformId}) {
    state = TrainConsist.ofWagons(count: count, platformId: platformId, previous: state);
  }

  /// Places one vehicle on one wagon, or across two when it spans their
  /// coupling. Returns the new placement's id so the caller can select it.
  String place({required String vehicleId, required List<String> wagonIds}) {
    final id = state.nextPlacementId;
    state = state.withVehiclePlaced(vehicleId: vehicleId, wagonIds: wagonIds);
    return id;
  }

  void remove(String placementId) => state = state.withoutPlacement(placementId);

  /// Drags one placement, clamped to the platform bounds exactly as the
  /// single-vehicle schematic was. Other placements are untouched — this is
  /// the per-placement replacement for the old single global drag offset.
  void dragBy(String placementId, SchematicPoint delta) {
    final placement = state.placementById(placementId);
    if (placement == null) return;
    state = state.withUpdatedPlacement(
      placement.withOffset(SchematicBuilder.clampVehicleOffset(placement.offset + delta)),
    );
  }

  /// Returns one placement to its centred starting position, leaving every
  /// other vehicle on the train untouched.
  void resetOffset(String placementId) {
    final placement = state.placementById(placementId);
    if (placement == null) return;
    state = state.withUpdatedPlacement(
      placement.withOffset(const SchematicPoint(0, 0)),
    );
  }

  void reset() => state = const TrainConsist();
}

final consistProvider = StateNotifierProvider<ConsistNotifier, TrainConsist>((ref) {
  final notifier = ConsistNotifier();
  // Changing the wagon count or type rebuilds the train, and
  // `TrainConsist.withWagons` drops any placement whose wagon no longer
  // exists. The per-placement maps are keyed by placement id and knew
  // nothing about that, so a dropped vehicle's equipment, securing method and
  // chock choice stayed in memory for the rest of the session. Pruning them
  // here keeps every store describing the same set of vehicles — including
  // the measured lashing angles, which are the newest thing to be keyed by
  // placement rather than by vehicle.
  notifier.addListener((consist) {
    final live = {for (final p in consist.placements) p.id};
    ref.read(placementEquipmentProvider.notifier).retainOnly(live);
    ref.read(placementSecuringMethodProvider.notifier).retainOnly(live);
    ref.read(placementChockChoiceProvider.notifier).retainOnly(live);
    // The gear a trainee placed belongs to that placement; a placement that
    // no longer exists must not leave its blocks behind for the next one.
    ref.read(placementSecuringLayoutProvider.notifier).retainOnly(live);
    ref.read(userDimensionsProvider.notifier).retainPlacements(live);
  }, fireImmediately: false);
  return notifier;
});

/// Which placement the securing step is currently configuring, and which one
/// a drag applies to on the placement screen. Null when nothing is selected.
final selectedPlacementIdProvider = StateProvider<String?>((ref) => null);

/// Equipment type selections, keyed by placement and then by hardware id
/// (`'placement-0' -> {'att-iron-spur': 'Ş-303'}`).
///
/// The old provider held a single flat `hardwareId -> typeCode` map, which
/// implicitly belonged to "the one vehicle". With several vehicles on the
/// train each needs its own, or securing the second vehicle would silently
/// overwrite the first one's hardware.
class PlacementEquipmentNotifier
    extends StateNotifier<Map<String, Map<String, String>>> {
  PlacementEquipmentNotifier() : super(const {});

  void select(String placementId, String hardwareId, String typeCode) {
    final forPlacement = {...?state[placementId], hardwareId: typeCode};
    state = {...state, placementId: forPlacement};
  }

  Map<String, String> forPlacement(String placementId) =>
      state[placementId] ?? const {};

  void clearPlacement(String placementId) {
    final next = {...state}..remove(placementId);
    state = next;
  }

  /// Drops every entry whose placement no longer exists.
  void retainOnly(Set<String> placementIds) {
    if (state.keys.every(placementIds.contains)) return;
    state = {
      for (final entry in state.entries)
        if (placementIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  void reset() => state = const {};
}

final placementEquipmentProvider = StateNotifierProvider<
    PlacementEquipmentNotifier, Map<String, Map<String, String>>>(
  (ref) => PlacementEquipmentNotifier(),
);

/// The approved securing method applied to each placement, keyed by placement
/// id. Per-placement for the same reason as the equipment map above.
class PlacementSecuringMethodNotifier extends StateNotifier<Map<String, int>> {
  PlacementSecuringMethodNotifier() : super(const {});

  void apply(String placementId, int methodNumber) =>
      state = {...state, placementId: methodNumber};

  int? forPlacement(String placementId) => state[placementId];

  void clearPlacement(String placementId) {
    final next = {...state}..remove(placementId);
    state = next;
  }

  /// Drops every entry whose placement no longer exists.
  void retainOnly(Set<String> placementIds) {
    if (state.keys.every(placementIds.contains)) return;
    state = {
      for (final entry in state.entries)
        if (placementIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  void reset() => state = const {};
}

final placementSecuringMethodProvider =
    StateNotifierProvider<PlacementSecuringMethodNotifier, Map<String, int>>(
  (ref) => PlacementSecuringMethodNotifier(),
);

/// The chock layout case, and (for a tracked vehicle) the lateral restraint,
/// chosen for each placement.
///
/// Per placement for the same reason as the equipment picks and the securing
/// method above: two copies of one designation on a wagon are secured
/// independently, so one trainee decision must never leak onto the other.
class PlacementChockChoiceNotifier extends StateNotifier<Map<String, ChockChoice>> {
  PlacementChockChoiceNotifier() : super(const {});

  void chooseArrangement(String placementId, String arrangementId) {
    final current = state[placementId] ?? const ChockChoice();
    state = {...state, placementId: current.copyWith(arrangementId: arrangementId)};
  }

  void chooseLateralRestraint(String placementId, String restraintId) {
    final current = state[placementId] ?? const ChockChoice();
    state = {...state, placementId: current.copyWith(lateralRestraintId: restraintId)};
  }

  ChockChoice forPlacement(String placementId) => state[placementId] ?? const ChockChoice();

  void clearPlacement(String placementId) {
    final next = {...state}..remove(placementId);
    state = next;
  }

  /// Drops every entry whose placement no longer exists.
  void retainOnly(Set<String> placementIds) {
    if (state.keys.every(placementIds.contains)) return;
    state = {
      for (final entry in state.entries)
        if (placementIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  void reset() => state = const {};
}

/// Dimensions the instructor has typed in, keyed `deck:<platformId>` or
/// `veh:<vehicleId>`, in centimetres.
///
/// The handbook extract dimensions nothing — no wagon deck, no vehicle — so
/// without this the deck budget could never be computed for any load. A typed
/// figure is the instructor's, not the handbook's, and every screen that uses
/// one says so; it is kept in its own store precisely so it can never be
/// mistaken for an extracted value.
class UserDimensionsNotifier extends StateNotifier<Map<String, double>> {
  UserDimensionsNotifier() : super(const {});

  static String deckKey(String platformId) => 'deck:$platformId';
  static String vehicleKey(String vehicleId) => 'veh:$vehicleId';
  static String weightKey(String vehicleId) => 'weight:$vehicleId';


  /// The two angles of a placement's wire lashing, in degrees rather than
  /// centimetres. They live in this store for the same reason the lengths do:
  /// they are measured on the wagon by the person doing the job, never read
  /// out of the handbook, and everything computed from one is labelled as
  /// theirs.
  static String lashingAxisAngleKey(String placementId) => 'axisdeg:$placementId';
  static String lashingFloorAngleKey(String placementId) => 'floordeg:$placementId';

  /// Stores one figure. Zero and negatives are rejected rather than stored:
  /// no length, and no installed angle, is either.
  void set(String key, double value) {
    if (value <= 0) return;
    state = {...state, key: value};
  }

  void clear(String key) {
    final next = {...state}..remove(key);
    state = next;
  }

  double? value(String key) => state[key];

  /// Drops the figures belonging to placements that no longer exist.
  ///
  /// Only placement-keyed entries are touched. A vehicle's weight and length
  /// are keyed by vehicle id and outlive any one placement of it: an
  /// instructor who types a T-72's weight, deletes it from the wagon and puts
  /// it back should not have to type the weight again.
  void retainPlacements(Set<String> placementIds) {
    bool belongsToDeadPlacement(String key) {
      for (final prefix in const ['axisdeg:', 'floordeg:']) {
        if (key.startsWith(prefix)) {
          return !placementIds.contains(key.substring(prefix.length));
        }
      }
      return false;
    }

    if (!state.keys.any(belongsToDeadPlacement)) return;
    state = {
      for (final entry in state.entries)
        if (!belongsToDeadPlacement(entry.key)) entry.key: entry.value,
    };
  }

  void reset() => state = const {};
}

final userDimensionsProvider =
    StateNotifierProvider<UserDimensionsNotifier, Map<String, double>>(
  (ref) => UserDimensionsNotifier(),
);

/// Wrong actions taken during this attempt that no check can see, because
/// they were rejected before they became part of a configuration.
///
/// Reset with the consist: a new load is a new attempt.
class AttemptLogNotifier extends StateNotifier<List<AttemptEvent>> {
  AttemptLogNotifier() : super(const []);

  /// Records one wrong action. The same action repeated is recorded again —
  /// an instructor wants to see that a trainee tried the tank wagon three
  /// times, not that they tried it once.
  void record(AttemptEvent event) => state = [...state, event];

  void reset() => state = const [];
}

final attemptLogProvider =
    StateNotifierProvider<AttemptLogNotifier, List<AttemptEvent>>(
  (ref) => AttemptLogNotifier(),
);

/// How far the load on one wagon actually hangs past its ends, in
/// millimetres, or null when nothing on it can be modelled.
///
/// Measured off the same scene the trainee is looking at, so the guard-wagon
/// verdict and the figure on the screen cannot disagree.
final wagonOverhangProvider = Provider.family<double?, String>((ref, wagonId) {
  final consist = ref.watch(consistProvider);
  final platform = ref.watch(consistPlatformProvider).valueOrNull;
  final vehicles = ref.watch(effectiveVehiclesProvider);
  if (platform == null || vehicles.isEmpty) return null;
  final byId = {for (final v in vehicles) v.id: v};
  final onboard = consist.placementsOn(wagonId);
  if (onboard.isEmpty) return null;
  final diagram = ref.watch(wagonSchematicProvider(wagonId));

  final loads = <PlacedLoad>[];
  for (final placement in onboard) {
    final vehicle = byId[placement.vehicleId];
    if (vehicle == null) continue;
    final spec = VehicleMeshCatalog.specFor(vehicle);
    if (spec == null) continue;
    loads.add(PlacedLoad(
      placementId: placement.id,
      designation: vehicle.handbookDesignation,
      spec: spec,
      positionFraction: diagram == null
          ? 0.5
          : deckPositionOf(diagram, placement.id).fraction,
    ));
  }
  if (loads.isEmpty) return null;

  final scene = buildLoadedWagonScene(
    loads: loads,
    flatcarSpec: FlatcarMeshSpec.fromPlatformFigures(
      lengthCm: platform.lengthCm.asDouble,
      widthCm: platform.widthCm.asDouble,
      deckHeightCm: platform.deckHeightCm.asDouble,
    ),
    includeTrackBed: false,
  );
  // The larger of the two ends, never their sum. plate-05 dimensions the
  // overhang "past the end of the open wagon" — one end — and caps it at
  // 400 mm, so adding the two together invented an overhang that neither end
  // had: a load standing 275 mm past each end of its deck read as 550 mm and
  // was failed for it.
  return math.max(
        scene.clearances.frontOverhangM,
        scene.clearances.rearOverhangM,
      ) *
      1000;
});

/// The space between neighbouring vehicles on each wagon, checked against
/// what the plates dimension for the pair.
///
/// A wagon carrying one vehicle contributes nothing. A wagon carrying two
/// contributes one check per gap — measured off the same three-dimensional
/// scene the trainee is looking at, so the figure in the report is the figure
/// on the screen.
final wagonClearanceChecksProvider = Provider<List<ValidationCheck>>((ref) {
  final consist = ref.watch(consistProvider);
  final platform = ref.watch(consistPlatformProvider).valueOrNull;
  final rules = ref.watch(rulesProvider).valueOrNull;
  final vehicles = ref.watch(effectiveVehiclesProvider);
  if (platform == null || rules == null || vehicles.isEmpty) return const [];
  final byId = {for (final v in vehicles) v.id: v};
  final layouts = ref.watch(placementSecuringLayoutProvider);

  final flatcarSpec = FlatcarMeshSpec.fromPlatformFigures(
    lengthCm: platform.lengthCm.asDouble,
    widthCm: platform.widthCm.asDouble,
    deckHeightCm: platform.deckHeightCm.asDouble,
    tieDownRings: platform.tieDownRings.numericValue?.toInt(),
  );

  final checks = <ValidationCheck>[];
  for (final wagon in consist.wagons) {
    final onboard = consist.placementsOn(wagon.id);
    if (onboard.length < 2) continue;
    final diagram = ref.watch(wagonSchematicProvider(wagon.id));

    final loads = <PlacedLoad>[];
    final vehicleByPlacement = <String, Vehicle>{};
    for (final placement in onboard) {
      final vehicle = byId[placement.vehicleId];
      if (vehicle == null) continue;
      final spec = VehicleMeshCatalog.specFor(vehicle);
      if (spec == null) continue;
      vehicleByPlacement[placement.id] = vehicle;
      loads.add(PlacedLoad(
        placementId: placement.id,
        designation: vehicle.handbookDesignation,
        spec: spec,
        positionFraction: diagram == null
            ? 0.5
            : deckPositionOf(diagram, placement.id).fraction,
        securing: layouts[placement.id] ?? SecuringLayout.empty,
      ));
    }
    // Two vehicles are needed to have a gap, and both must be modellable for
    // it to be measured; a wagon carrying an unmodellable vehicle contributes
    // no check rather than a guessed one.
    if (loads.length < 2) continue;

    final scene = buildLoadedWagonScene(loads: loads, flatcarSpec: flatcarSpec);
    for (final gap in scene.gaps) {
      final rear = vehicleByPlacement[gap.rearPlacementId];
      final front = vehicleByPlacement[gap.frontPlacementId];
      if (rear == null || front == null) continue;
      checks.add(checkPlacementClearance(
        gapMm: gap.gapMm,
        rearDesignation: rear.handbookDesignation,
        frontDesignation: front.handbookDesignation,
        rearCategory: rear.category,
        frontCategory: front.category,
        rules: rules,
      ));
    }
  }
  return checks;
});

/// The checks that belong to the train as a whole rather than to one vehicle:
/// whether each wagon's deck can take what is on it, whether the load hangs
/// far enough past a wagon's end to need a guard wagon, and whether the train
/// still fits an echelon class.
///
/// These could not live in `placementResultsProvider`, which evaluates one
/// placement at a time — a deck budget and an echelon class are properties of
/// the consist. They are surfaced beside the per-vehicle checks and counted in
/// the score exactly like them.
final consistChecksProvider = Provider<List<ValidationCheck>>((ref) {
  final consist = ref.watch(consistProvider);
  final rules = ref.watch(rulesProvider).valueOrNull;
  final platforms = ref.watch(platformsProvider).valueOrNull;
  if (rules == null || platforms == null || consist.wagons.isEmpty) return const [];

  final checks = <ValidationCheck>[];

  for (final wagon in consist.wagons) {
    final budget = ref.watch(wagonBudgetProvider(wagon.id));
    if (budget == null) continue;
    if (consist.placementsOn(wagon.id).isEmpty) continue;
    checks.add(checkWagonCapacity(budget));
    // The overhang the guard-wagon rule is about is how far the load actually
    // hangs past the end of the wagon, which depends on where the trainee put
    // it. The deck budget cannot say: it compares lengths and knows nothing
    // about position, so a machine run hard against one end read as no
    // overhang at all. Where the load can be modelled, the measurement comes
    // from the scene; the budget stays the fallback for a wagon carrying a
    // vehicle with no dimensions.
    //
    // The fallback used to finish that sentence with `: 0` — a budget that
    // came out positive reported no overhang, and `checkGuardWagon` passed it.
    // That is the length comparison answering a question about position after
    // all, and it passed every unmodellable vehicle on a deck it happened to
    // fit. What a budget can still prove is one direction, the same way the
    // wheeled axle-load check does: a load longer than its deck hangs off
    // somewhere, and the longer of the two ends carries at least half of the
    // excess. Where even that half exceeds the limit the failure is certain;
    // anything short of it is left undecided rather than passed.
    final measured = ref.watch(wagonOverhangProvider(wagon.id));
    final remaining = budget.remainingCm;
    final leastWorstEndMm =
        (remaining != null && remaining < 0) ? -remaining * 10 / 2 : null;
    checks.add(checkGuardWagon(
      overhangMm: measured ?? leastWorstEndMm,
      rules: rules,
    ));
  }

  // The space between two vehicles sharing a wagon is a property of the
  // consist too, not of either vehicle on its own.
  checks.addAll(ref.watch(wagonClearanceChecksProvider));
  return checks;
});

/// Where every stop block the trainee placed ended up, against where the
/// handbook says it should have been.
///
/// This is what the result sheet had no way to say. The three-dimensional view
/// could measure a block's seating distance live, but nothing carried that
/// through to the end of the attempt — so a trainee could put every block in
/// the wrong place and the report would never mention it.
///
/// Only placements the trainee actually worked on contribute. An untouched
/// placement still shows the handbook's own arrangement in the view, and
/// reporting that back as a correct answer would be marking them for something
/// they did not do.
/// Every iron spur the trainee placed, measured against the four stations a
/// set covers — one at each end of each track.
///
/// Keyed by placement, because the spur checks are appended to that
/// placement's own result: a spur belongs to the machine it is holding, the
/// way the seating distance of a wood block does, and not to the train.
final placementSpurFindingsProvider =
    Provider<Map<String, List<SpurFinding>>>((ref) {
  final consist = ref.watch(consistProvider);
  final layouts = ref.watch(placementSecuringLayoutProvider);
  final platform = ref.watch(consistPlatformProvider).valueOrNull;
  final vehicles = ref.watch(effectiveVehiclesProvider);
  if (platform == null || vehicles.isEmpty) return const {};
  final byId = {for (final v in vehicles) v.id: v};

  final out = <String, List<SpurFinding>>{};
  for (final placement in consist.placements) {
    final vehicle = byId[placement.vehicleId];
    if (vehicle == null) continue;
    final requirement = ironSpurRequirementFor(vehicle);
    final layout = layouts[placement.id] ?? SecuringLayout.empty;
    final spursPlaced =
        layout.pieces.where((p) => p.kind == SecuringPieceKind.ironSpur).length;
    // A vehicle spurs do not apply to, with no spurs on it, is not a finding
    // at all — it is simply secured another way.
    if (!requirement.spursApply && spursPlaced == 0) continue;

    final spec = VehicleMeshCatalog.specFor(vehicle);
    if (spec == null) continue;
    final flatcarSpec = FlatcarMeshSpec.fromPlatformFigures(
      lengthCm: platform.lengthCm.asDouble,
      widthCm: platform.widthCm.asDouble,
      deckHeightCm: platform.deckHeightCm.asDouble,
      tieDownRings: platform.tieDownRings.numericValue?.toInt(),
    );
    final diagram = ref.watch(wagonSchematicProvider(placement.wagonIds.first));
    final fraction =
        diagram == null ? 0.5 : deckPositionOf(diagram, placement.id).fraction;
    final geometry = resolveLoadingGeometry(
      vehicleSpec: spec,
      flatcarSpec: flatcarSpec,
      positionFraction: fraction,
    );
    out[placement.id] = spurFindingsFor(
      placementId: placement.id,
      designation: vehicle.handbookDesignation,
      layout: layout,
      vehicle: geometry.vehicle,
      vehicleOffsetX: geometry.vehicleOffsetX,
      requirement: requirement,
    );
  }
  return out;
});

/// The spur findings for the whole attempt, in placement order — what the
/// result sheet prints.
final attemptSpurFindingsProvider = Provider<List<SpurFinding>>((ref) {
  final byPlacement = ref.watch(placementSpurFindingsProvider);
  final consist = ref.watch(consistProvider);
  return [
    for (final placement in consist.placements)
      ...?byPlacement[placement.id],
  ];
});

/// How many of each kind of gear the handbook asks for, against how many the
/// trainee actually laid on the wagon.
///
/// Keyed by placement. The counts come from the case the trainee chose, so a
/// placement with no arrangement chosen yet produces nothing to judge rather
/// than a verdict against a case nobody picked.
final placementPieceCountFindingsProvider =
    Provider<Map<String, List<PieceCountFinding>>>((ref) {
  final consist = ref.watch(consistProvider);
  final layouts = ref.watch(placementSecuringLayoutProvider);
  final vehicles = ref.watch(effectiveVehiclesProvider);
  final rules = ref.watch(rulesProvider).valueOrNull;
  if (vehicles.isEmpty || rules == null) return const {};
  final byId = {for (final v in vehicles) v.id: v};

  final out = <String, List<PieceCountFinding>>{};
  for (final placement in consist.placements) {
    final vehicle = byId[placement.vehicleId];
    if (vehicle == null) continue;
    final findings = pieceCountFindingsFor(
      placementId: placement.id,
      designation: vehicle.handbookDesignation,
      vehicle: vehicle,
      layout: layouts[placement.id] ?? SecuringLayout.empty,
      arrangement: ref.watch(placementSelectedArrangementProvider(placement.id)),
      restraint: ref.watch(placementSelectedRestraintProvider(placement.id)),
      rules: rules,
    );
    if (findings.isNotEmpty) out[placement.id] = findings;
  }
  return out;
});

/// The count findings for the whole attempt, in placement order.
final attemptPieceCountFindingsProvider =
    Provider<List<PieceCountFinding>>((ref) {
  final byPlacement = ref.watch(placementPieceCountFindingsProvider);
  final consist = ref.watch(consistProvider);
  return [
    for (final placement in consist.placements) ...?byPlacement[placement.id],
  ];
});

/// The verdicts on what was laid down: one per stated count, and one per
/// vehicle on how its stop blocks are seated.
///
/// These are the checks that make the placement exercise count for anything.
/// Every distance here was already being measured and printed; none of it
/// reached the mark until now, so a trainee could seat every block half a
/// metre out, or put down three chocks where the plate calls for eight, and
/// score exactly as well as one who did it right.
final layoutConformanceChecksProvider =
    Provider<List<ValidationCheck>>((ref) {
  final consist = ref.watch(consistProvider);
  final counts = ref.watch(placementPieceCountFindingsProvider);
  final seating = ref.watch(attemptSeatingFindingsProvider);
  final byPlacement = <String, List<SeatingFinding>>{};
  for (final finding in seating) {
    (byPlacement[finding.placementId] ??= <SeatingFinding>[]).add(finding);
  }

  final checks = <ValidationCheck>[];
  for (final placement in consist.placements) {
    checks.addAll(pieceCountChecks(counts[placement.id] ?? const []));
    final seatingCheck = seatingCheckFor(byPlacement[placement.id] ?? const []);
    if (seatingCheck != null) checks.add(seatingCheck);
  }
  return checks;
});

/// The spur verdicts for every placement — is the spur this vehicle's method
/// at all, is it the type Table 13 names, and did a full set of four reach the
/// four stations.
///
/// Kept beside the per-vehicle results rather than folded into them, because
/// these are decided from the *layout*, and the layout reaches the schematic,
/// which reads the results: folding them in closed a cycle between the three
/// providers. They are counted in the mark exactly like a validator check.
/// One placement's spur verdicts, for the analysis screen — which reviews a
/// single vehicle at a time.
final placementSpurChecksProvider =
    Provider.family<List<ValidationCheck>, String>((ref, placementId) {
  final consist = ref.watch(consistProvider);
  final placement = consist.placementById(placementId);
  if (placement == null) return const [];
  final vehicles = ref.watch(effectiveVehiclesProvider);
  final vehicle =
      vehicles.where((v) => v.id == placement.vehicleId).firstOrNull;
  if (vehicle == null) return const [];
  final layout =
      ref.watch(placementSecuringLayoutProvider)[placementId] ??
          SecuringLayout.empty;
  return ironSpurChecks(
    requirement: ironSpurRequirementFor(vehicle),
    findings: ref.watch(placementSpurFindingsProvider)[placementId] ?? const [],
    spursPlaced: layout.pieces
        .where((p) => p.kind == SecuringPieceKind.ironSpur)
        .length,
  );
});

final spurChecksProvider = Provider<List<ValidationCheck>>((ref) {
  final consist = ref.watch(consistProvider);
  final findings = ref.watch(placementSpurFindingsProvider);
  final layouts = ref.watch(placementSecuringLayoutProvider);
  final vehicles = ref.watch(effectiveVehiclesProvider);
  if (vehicles.isEmpty) return const [];
  final byId = {for (final v in vehicles) v.id: v};

  final checks = <ValidationCheck>[];
  for (final placement in consist.placements) {
    final vehicle = byId[placement.vehicleId];
    if (vehicle == null) continue;
    final layout = layouts[placement.id] ?? SecuringLayout.empty;
    checks.addAll(ironSpurChecks(
      requirement: ironSpurRequirementFor(vehicle),
      findings: findings[placement.id] ?? const [],
      spursPlaced: layout.pieces
          .where((p) => p.kind == SecuringPieceKind.ironSpur)
          .length,
    ));
  }
  return checks;
});

final attemptSeatingFindingsProvider = Provider<List<SeatingFinding>>((ref) {
  final consist = ref.watch(consistProvider);
  final layouts = ref.watch(placementSecuringLayoutProvider);
  if (layouts.isEmpty) return const [];
  final platform = ref.watch(consistPlatformProvider).valueOrNull;
  final vehicles = ref.watch(effectiveVehiclesProvider);
  if (platform == null || vehicles.isEmpty) return const [];
  final byId = {for (final v in vehicles) v.id: v};

  final findings = <SeatingFinding>[];
  for (final placement in consist.placements) {
    final layout = layouts[placement.id];
    if (layout == null || layout.isEmpty) continue;
    final vehicle = byId[placement.vehicleId];
    if (vehicle == null) continue;
    final spec = VehicleMeshCatalog.specFor(vehicle);
    if (spec == null) continue;

    final flatcarSpec = FlatcarMeshSpec.fromPlatformFigures(
      lengthCm: platform.lengthCm.asDouble,
      widthCm: platform.widthCm.asDouble,
      deckHeightCm: platform.deckHeightCm.asDouble,
      tieDownRings: platform.tieDownRings.numericValue?.toInt(),
    );
    // The same position the views draw, read off the same diagram, so the
    // sheet cannot disagree with what the trainee was looking at.
    final diagram = ref.watch(wagonSchematicProvider(placement.wagonIds.first));
    final fraction =
        diagram == null ? 0.5 : deckPositionOf(diagram, placement.id).fraction;
    final geometry = resolveLoadingGeometry(
      vehicleSpec: spec,
      flatcarSpec: flatcarSpec,
      positionFraction: fraction,
    );
    findings.addAll(seatingFindingsFor(
      placementId: placement.id,
      designation: vehicle.handbookDesignation,
      layout: layout,
      vehicle: geometry.vehicle,
      vehicleOffsetX: geometry.vehicleOffsetX,
      arrangement: ref.watch(placementSelectedArrangementProvider(placement.id)),
    ));
  }
  return findings;
});

/// The mark for this attempt: what passed, what failed, what could not be
/// decided, and what was done wrong on the way to it.
final attemptScoreProvider = Provider<AttemptScore>((ref) {
  final results = ref.watch(placementResultsProvider).valueOrNull ?? const {};
  final events = ref.watch(attemptLogProvider);
  return scoreAttempt(
    results: results.values,
    events: events,
    consistChecks: ref.watch(consistChecksProvider),
    layoutChecks: [
      ...ref.watch(spurChecksProvider),
      ...ref.watch(layoutConformanceChecksProvider),
    ],
  );
});

/// The vehicle catalogue with the instructor's own figures applied.
///
/// This is what the engineering path reads. Every rule that matters — the
/// KGUUB bracket, the chock size, the wheeled chock count, the lashing count,
/// the deck budget — is keyed on a combat weight or a length that the
/// handbook extract does not carry for a single vehicle, so all of them
/// reported "cannot be decided" for every load. A typed figure resolves them,
/// and `Vehicle.userSuppliedFields` keeps the provenance attached so a verdict
/// reached from one is never shown as a handbook result.
///
/// `vehiclesProvider` stays the untouched catalogue: the reference browser
/// must keep showing what the handbook says, not what an instructor typed.
final effectiveVehiclesProvider = Provider<List<Vehicle>>((ref) {
  final vehicles = ref.watch(vehiclesProvider).valueOrNull ?? const <Vehicle>[];
  final dimensions = ref.watch(userDimensionsProvider);
  if (dimensions.isEmpty) return vehicles;
  return [
    for (final vehicle in vehicles)
      vehicle.withUserSuppliedFigures(
        weightT: dimensions[UserDimensionsNotifier.weightKey(vehicle.id)],
        lengthCm: dimensions[UserDimensionsNotifier.vehicleKey(vehicle.id)],
      ),
  ];
});

/// The deck budget for one wagon: what the load uses and what is left.
///
/// Lengths come from the vehicle record first and from the instructor's entry
/// second; the clearance between neighbours comes from the plates. Vehicles
/// are ordered by where they have been dragged along the deck, so the pair
/// the clearance is charged between is the pair that actually stands together.
final wagonBudgetProvider = Provider.family<WagonLengthBudget?, String>((ref, wagonId) {
  final consist = ref.watch(consistProvider);
  final platform = ref.watch(consistPlatformProvider).valueOrNull;
  final rules = ref.watch(rulesProvider).valueOrNull;
  final vehicles = ref.watch(effectiveVehiclesProvider);
  if (platform == null || vehicles.isEmpty || rules == null) return null;

  final dimensions = ref.watch(userDimensionsProvider);
  final byId = {for (final v in vehicles) v.id: v};

  // Ordered by where each vehicle has been dragged along the deck, with the
  // order they were placed in as the tiebreak: Dart's sort is not stable, and
  // every offset is 0 until something is dragged, so without the tiebreak the
  // neighbour pairs — and therefore which clearance applies between them —
  // could change from one rebuild to the next.
  final placedOrder = {
    for (var i = 0; i < consist.placements.length; i++) consist.placements[i].id: i,
  };
  final onboard = consist.placementsOn(wagonId).toList()
    ..sort((a, b) {
      final byOffset = a.offset.dx.compareTo(b.offset.dx);
      if (byOffset != 0) return byOffset;
      return (placedOrder[a.id] ?? 0).compareTo(placedOrder[b.id] ?? 0);
    });

  final loaded = <VehicleOnWagon>[];
  for (final placement in onboard) {
    final vehicle = byId[placement.vehicleId];
    if (vehicle == null) continue;
    loaded.add(VehicleOnWagon(
      placementId: placement.id,
      designation: vehicle.handbookDesignation,
      category: vehicle.category,
      lengthCm: vehicle.lengthCm.asDouble,
      spansCoupling: placement.spansCoupling,
      isPrimaryWagon: placement.primaryWagonId == wagonId,
    ));
  }

  return wagonLengthBudget(
    deckLengthCm: platform.lengthCm.asDouble ??
        dimensions[UserDimensionsNotifier.deckKey(platform.id)],
    vehicles: loaded,
    rules: rules,
  );
});

final placementChockChoiceProvider =
    StateNotifierProvider<PlacementChockChoiceNotifier, Map<String, ChockChoice>>(
  (ref) => PlacementChockChoiceNotifier(),
);

/// The securing gear each placement has on it, keyed by placement id.
///
/// Per-placement for the same reason the equipment map is: two vehicles on one
/// train are secured separately, and a shared layout would have the second
/// one's blocks appear under the first.
///
/// An absent or empty entry is not "no gear" — it means the trainee has not
/// touched the arrangement yet, and the three-dimensional view shows the
/// handbook's own layout until they do. That is why [reset] stores nothing
/// rather than storing an empty layout: "back to the handbook arrangement" and
/// "start from an empty deck" would otherwise be the same state.
class PlacementSecuringLayoutNotifier
    extends StateNotifier<Map<String, SecuringLayout>> {
  PlacementSecuringLayoutNotifier() : super(const {});

  SecuringLayout forPlacement(String placementId) =>
      state[placementId] ?? SecuringLayout.empty;

  void put(String placementId, SecuringLayout layout) {
    if (layout.isEmpty) {
      reset(placementId);
      return;
    }
    state = {...state, placementId: layout};
  }

  void reset(String placementId) {
    if (!state.containsKey(placementId)) return;
    state = {...state}..remove(placementId);
  }

  /// Drops every entry whose placement no longer exists.
  void retainOnly(Set<String> placementIds) {
    if (state.keys.every(placementIds.contains)) return;
    state = {
      for (final entry in state.entries)
        if (placementIds.contains(entry.key)) entry.key: entry.value,
    };
  }

  void clear() => state = const {};
}

final placementSecuringLayoutProvider = StateNotifierProvider<
    PlacementSecuringLayoutNotifier, Map<String, SecuringLayout>>(
  (ref) => PlacementSecuringLayoutNotifier(),
);

/// The vehicle standing at one placement, or null when the placement or its
/// record cannot be resolved. Several of the derivation providers below need
/// it and none of them should repeat the lookup.
final placementVehicleProvider =
    Provider.family<Vehicle?, String>((ref, placementId) {
  final placement = ref.watch(consistProvider).placementById(placementId);
  if (placement == null) return null;
  final vehicles = ref.watch(effectiveVehiclesProvider);
  return vehicles.where((v) => v.id == placement.vehicleId).firstOrNull;
});

/// What the trainee's own placement in the 3D scene already says about the
/// equipment: attachment id to the handbook row they took the piece from.
///
/// This is not a suggestion and not a pre-filled answer. It is the record of
/// an act they performed — seating a sized block against the running gear —
/// read back in the vocabulary the securing step uses, so that step does not
/// ask them to state a second time what they have already done.
final layoutDerivedEquipmentProvider =
    Provider.family<Map<String, String>, String>((ref, placementId) {
  final vehicle = ref.watch(placementVehicleProvider(placementId));
  if (vehicle == null) return const {};
  final layout = ref.watch(placementSecuringLayoutProvider)[placementId];
  if (layout == null || layout.isEmpty) return const {};
  return equipmentAnsweredByLayout(layout, vehicle);
});

/// What the gear the trainee *ordered* in step 5 already states.
///
/// The order carries the kind and the table row it was picked from —
/// "ironSpur|Ş-303" — which is exactly the question the securing step asks.
/// Reading it back here is the same principle as reading the layout back: a
/// trainee who has already chosen a Ş-137 from the equipment list must not be
/// asked a second time which spur this vehicle takes.
final orderDerivedEquipmentProvider =
    Provider.family<Map<String, String>, String>((ref, placementId) {
  final vehicle = ref.watch(placementVehicleProvider(placementId));
  if (vehicle == null) return const {};
  final orders = ref.watch(equipmentOrdersProvider);
  if (orders.isEmpty) return const {};

  final out = <String, String>{};
  for (final key in orders.keys) {
    final parts = key.split('|');
    if (parts.length != 2) continue;
    final kind = SecuringPieceKind.values
        .firstWhereOrNull((k) => k.name == parts.first);
    if (kind == null) continue;
    final id = attachmentIdForPieceKind(kind, vehicle);
    // First order of a kind wins, the way the layout's first piece does.
    if (id != null) out.putIfAbsent(id, () => parts.last);
  }
  return out;
});

/// The equipment answers in force for one placement.
///
/// Three sources, weakest first: what was ordered, what was actually placed,
/// and what the trainee then changed by hand. Later beats earlier, because
/// each is a more recent statement of the same decision.
final effectivePlacementEquipmentProvider =
    Provider.family<Map<String, String>, String>((ref, placementId) {
  final ordered = ref.watch(orderDerivedEquipmentProvider(placementId));
  final derived = ref.watch(layoutDerivedEquipmentProvider(placementId));
  final explicit = ref.watch(placementEquipmentProvider)[placementId];
  return {...ordered, ...derived, ...?explicit};
});

/// The approved securing method the placed pieces amount to, or null when they
/// do not amount to exactly one. See [methodAnsweredByLayout].
final layoutDerivedMethodProvider =
    Provider.family<int?, String>((ref, placementId) {
  final vehicle = ref.watch(placementVehicleProvider(placementId));
  if (vehicle == null) return null;
  final layout = ref.watch(placementSecuringLayoutProvider)[placementId];
  if (layout == null || layout.isEmpty) return null;
  return methodAnsweredByLayout(layout, vehicle);
});

/// The securing method in force for one placement: the one the trainee applied
/// explicitly, otherwise the one their placement already states.
final effectiveSecuringMethodProvider =
    Provider.family<int?, String>((ref, placementId) =>
        ref.watch(placementSecuringMethodProvider)[placementId] ??
        ref.watch(layoutDerivedMethodProvider(placementId)));

/// The seating distance snapping should use for one placement, in metres.
///
/// Taken from the seating distance the handbook's own arrangements state for
/// this vehicle — the chosen case when there is one, otherwise the first
/// offered case that records a distance. It is used only to *assist* a drag;
/// the pass/fail check stays tied to the case the trainee actually chose, so
/// nothing here pre-selects an arrangement on their behalf.
final placementSnapSeatingDistanceProvider =
    Provider.family<double?, String>((ref, placementId) {
  final chosen = ref.watch(placementSelectedArrangementProvider(placementId));
  final range = chosen?.seatingDistance ??
      ref
          .watch(placementChockArrangementsProvider(placementId))
          .map((a) => a.seatingDistance)
          .whereType<({int minCm, int maxCm})>()
          .firstOrNull;
  if (range == null) return null;
  return (range.minCm + range.maxCm) / 2 / 100;
});

/// The arrangements offered for one placement, and the one chosen, resolved
/// against `rules.json`. Family-keyed by placement id so a screen can ask for
/// exactly the placement it is showing.
final placementChockArrangementsProvider =
    Provider.family<List<ChockArrangement>, String>((ref, placementId) {
  final rules = ref.watch(rulesProvider).valueOrNull;
  final vehicles = ref.watch(effectiveVehiclesProvider);
  final consist = ref.watch(consistProvider);
  if (rules == null || vehicles.isEmpty) return const [];
  final placement = consist.placementById(placementId);
  if (placement == null) return const [];
  final matches = vehicles.where((v) => v.id == placement.vehicleId);
  if (matches.isEmpty) return const [];
  return chockArrangementsFor(
    matches.first,
    // Whether the vehicle stands across a coupling is carried by the
    // placement itself, never inferred from a drag coordinate.
    overCoupling: placement.spansCoupling,
    rules: rules,
  );
});

/// The arrangement object behind a placement's chosen id, or null when
/// nothing has been chosen yet.
/// The lateral restraint the trainee chose for one placement — staples or side
/// blocks — resolved to the option record. Null until they choose, and always
/// null for a wheeled vehicle, which the plates give no such choice.
final placementSelectedRestraintProvider =
    Provider.family<LateralRestraintOption?, String>((ref, placementId) {
  final chosenId =
      ref.watch(placementChockChoiceProvider)[placementId]?.lateralRestraintId;
  if (chosenId == null) return null;
  final consist = ref.watch(consistProvider);
  final placement = consist.placementById(placementId);
  if (placement == null) return null;
  final vehicle = ref
      .watch(effectiveVehiclesProvider)
      .where((v) => v.id == placement.vehicleId)
      .firstOrNull;
  final rules = ref.watch(rulesProvider).valueOrNull;
  if (vehicle == null || rules == null) return null;
  for (final option in lateralRestraintOptionsFor(vehicle, rules)) {
    if (option.id == chosenId) return option;
  }
  return null;
});

final placementSelectedArrangementProvider =
    Provider.family<ChockArrangement?, String>((ref, placementId) {
  final chosenId = ref.watch(placementChockChoiceProvider)[placementId]?.arrangementId;
  if (chosenId == null) return null;
  for (final arrangement in ref.watch(placementChockArrangementsProvider(placementId))) {
    if (arrangement.id == chosenId) return arrangement;
  }
  return null;
});

/// The chosen wagon type resolved to its `platforms.json` record. Null until
/// step 3 has been completed.
final consistPlatformProvider = Provider<AsyncValue<Platform?>>((ref) {
  final platforms = ref.watch(platformsProvider);
  final id = ref.watch(selectedWagonTypeProvider);
  return platforms.whenData((list) {
    if (id == null) return null;
    for (final p in list) {
      if (p.id == id) return p;
    }
    return null;
  });
});

/// Engineering verdict for every placement on the train, keyed by placement
/// id.
///
/// This runs the existing single-vehicle [EngineeringValidator.evaluate]
/// once per placement rather than introducing a second validation path.
/// Every check, every citation and the never-guess-a-number invariant are
/// therefore exactly the ones already covered by the engineering tests; only
/// the number of times they run has changed.
///
/// Cross-vehicle rules — the clearances between vehicles and the
/// over-the-coupling case from the plates — are deliberately NOT decided
/// here yet; they need the consist as a whole, and are a separate step.
final placementResultsProvider =
    FutureProvider<Map<String, SimulationResult>>((ref) async {
  final consist = ref.watch(consistProvider);
  final platform = ref.watch(consistPlatformProvider).valueOrNull;
  final vehicles = ref.watch(effectiveVehiclesProvider);
  if (platform == null || vehicles.isEmpty) return const {};

  final validator = ref.watch(engineeringValidatorProvider);
  // The method in force, not merely the one applied in words: a trainee who
  // seated the blocks and ran the lashings has already chosen method 3, and
  // validating as though no method were chosen would fail them for a step
  // they completed.
  final methods = <String, int?>{
    for (final placement in consist.placements)
      placement.id: ref.watch(effectiveSecuringMethodProvider(placement.id)),
  };
  final byId = {for (final v in vehicles) v.id: v};

  // Every `ref.watch` happens BEFORE the first await. Watching after one is
  // not allowed in an async provider — the provider may already have been
  // disposed by then — and it went unnoticed here because the first pass
  // through the loop watches before awaiting anything: the defect only
  // appears from the second placement onwards, which is exactly the
  // two-vehicles-on-one-wagon case.
  final arrangements = <String, ChockArrangement?>{
    for (final placement in consist.placements)
      placement.id: ref.watch(placementSelectedArrangementProvider(placement.id)),
  };

  final results = <String, SimulationResult>{};
  for (final placement in consist.placements) {
    final vehicle = byId[placement.vehicleId];
    if (vehicle == null) continue;
    results[placement.id] = await validator.evaluate(
      vehicle: vehicle,
      platform: platform,
      appliedSecuringMethod: methods[placement.id],
      chosenChockArrangement: arrangements[placement.id],
      placementSpansCoupling: placement.spansCoupling,
    );
  }
  return results;
});

/// One wagon drawn as a schematic, with every vehicle the user has placed on
/// it — the step-4 and step-5 view.
///
/// Keyed by wagon id because a consist is several wagons, each drawn
/// separately: the handbook's own plates lay a train out the same way, one
/// flatcar at a time with its own securing arrangement.
///
/// Null until the wagon type, the vehicle catalogue and the attachment
/// catalogue have all loaded. As with the single-vehicle diagram, the offsets
/// carried in here are rendering state and never an input to any pass/fail
/// decision.
final wagonSchematicProvider =
    Provider.family<SchematicDiagram?, String>((ref, wagonId) {
  final consist = ref.watch(consistProvider);
  final platform = ref.watch(consistPlatformProvider).valueOrNull;
  final vehicles = ref.watch(vehiclesProvider).valueOrNull;
  final attachments = ref.watch(attachmentTypesProvider).valueOrNull;
  if (platform == null || vehicles == null || attachments == null) return null;

  final results = ref.watch(placementResultsProvider).valueOrNull ?? const {};
  final equipment = <String, Map<String, String>>{
    for (final placement in consist.placementsOn(wagonId))
      placement.id: ref.watch(effectivePlacementEquipmentProvider(placement.id)),
  };
  final measurements = ref.watch(measurementsProvider).valueOrNull;
  final rules = ref.watch(rulesProvider).valueOrNull;
  final byId = {for (final v in vehicles) v.id: v};

  final placements = <ConsistPlacement>[];
  for (final placement in consist.placementsOn(wagonId)) {
    final vehicle = byId[placement.vehicleId];
    if (vehicle == null) continue;
    placements.add(ConsistPlacement(
      placementId: placement.id,
      vehicle: vehicle,
      requiredHardwareIds: results[placement.id]?.requiredHardwareIds ?? const [],
      selectedHardwareTypes: equipment[placement.id] ?? const {},
      offset: placement.offset,
      chockArrangement: ref.watch(placementSelectedArrangementProvider(placement.id)),
    ));
  }

  return SchematicBuilder.buildConsist(
    platform: platform,
    placements: placements,
    attachments: attachments,
    measurements: measurements,
    rules: rules,
  );
});
