import 'schematic_element.dart';

/// How many of one vehicle designation the user has added to the load, set
/// on the Vehicle Selection screen by tapping a card repeatedly.
///
/// The quantity lives here rather than as N duplicated entries so the
/// selection screen can show "3 x T-54" as one row; the individual copies
/// only come into existence as [PlacedVehicle]s once the user puts them on
/// a wagon.
class VehicleOrder {
  final String vehicleId;
  final int quantity;

  const VehicleOrder({required this.vehicleId, required this.quantity});

  VehicleOrder withQuantity(int newQuantity) =>
      VehicleOrder(vehicleId: vehicleId, quantity: newQuantity);

  @override
  bool operator ==(Object other) =>
      other is VehicleOrder && other.vehicleId == vehicleId && other.quantity == quantity;

  @override
  int get hashCode => Object.hash(vehicleId, quantity);
}

/// One physical wagon in the consist.
///
/// [platformId] points at a `platforms.json` entry — several wagons in a
/// consist normally share the same platform type, so the type's specs are
/// looked up rather than copied here.
class WagonInstance {
  final String id;
  final String platformId;

  const WagonInstance({required this.id, required this.platformId});

  @override
  bool operator ==(Object other) =>
      other is WagonInstance && other.id == id && other.platformId == platformId;

  @override
  int get hashCode => Object.hash(id, platformId);
}

/// One vehicle placed on the consist by the user.
///
/// [wagonIds] normally holds a single wagon, but holds two when the vehicle
/// is set over the coupling between them. That is a real handbook case, not
/// an edge case: plate-06's layout diagram devotes three of its six drawings
/// to it, and it changes the required chock count and the lateral chock gap
/// (20-30 mm becomes 15-20 mm). Storing the wagons the vehicle rests on
/// states that case directly instead of trying to infer it from a schematic
/// coordinate — [offset] is deliberately not measured geometry.
///
/// [offset] is the same normalized, presentation-only drag offset the
/// single-vehicle schematic used, now carried per placement. As before it
/// must never reach the engineering validator as a measurement.
class PlacedVehicle {
  final String id;
  final String vehicleId;
  final List<String> wagonIds;
  final SchematicPoint offset;

  const PlacedVehicle({
    required this.id,
    required this.vehicleId,
    required this.wagonIds,
    this.offset = const SchematicPoint(0, 0),
  });

  /// True when the vehicle spans the coupling between two wagons — the case
  /// plate-06 draws separately and gives different chock rules for.
  bool get spansCoupling => wagonIds.length > 1;

  /// The wagon a single-wagon placement sits on, or the first of the two it
  /// spans. Used for grouping placements by wagon in the UI.
  String get primaryWagonId => wagonIds.first;

  PlacedVehicle withOffset(SchematicPoint newOffset) => PlacedVehicle(
        id: id,
        vehicleId: vehicleId,
        wagonIds: wagonIds,
        offset: newOffset,
      );

  @override
  bool operator ==(Object other) =>
      other is PlacedVehicle &&
      other.id == id &&
      other.vehicleId == vehicleId &&
      other.offset == offset &&
      _sameWagons(other.wagonIds);

  bool _sameWagons(List<String> other) {
    if (other.length != wagonIds.length) return false;
    for (var i = 0; i < wagonIds.length; i++) {
      if (other[i] != wagonIds[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(id, vehicleId, Object.hashAll(wagonIds), offset);
}

/// The train being loaded: the wagons chosen in step 1/3, and every vehicle
/// the user has placed onto them in step 4.
///
/// This replaces the old "one selected vehicle, one selected platform" pair.
/// It is a plain immutable value — all mutation goes through the notifier in
/// `consist_providers.dart`, so the whole load is one observable object.
class TrainConsist {
  final List<WagonInstance> wagons;
  final List<PlacedVehicle> placements;

  /// Counter behind [nextPlacementId]. It is carried in the value rather than
  /// held in the notifier so the whole consist stays pure and testable under
  /// plain `dart test` (the notifier cannot be imported there — it pulls in
  /// `flutter_riverpod` and therefore `package:flutter`).
  ///
  /// It only ever increases. Deriving the next id from the existing
  /// placements instead would re-issue the id of a removed placement, and the
  /// per-placement equipment and securing-method maps are keyed by that id —
  /// a new vehicle would silently inherit the deleted one's hardware.
  final int nextPlacementSeq;

  const TrainConsist({
    this.wagons = const [],
    this.placements = const [],
    this.nextPlacementSeq = 0,
  });

  /// Builds a consist of [count] wagons, all of the same type — the shape
  /// step 1 (how many) and step 3 (which type) produce between them.
  static TrainConsist ofWagons({
    required int count,
    required String platformId,
    TrainConsist previous = const TrainConsist(),
  }) =>
      previous.withWagons([
        for (var i = 0; i < count; i++)
          WagonInstance(id: 'wagon-${i + 1}', platformId: platformId),
      ]);

  String get nextPlacementId => 'placement-$nextPlacementSeq';

  /// Every vehicle resting on this wagon, including any that only span it as
  /// the second of a coupled pair.
  List<PlacedVehicle> placementsOn(String wagonId) =>
      placements.where((p) => p.wagonIds.contains(wagonId)).toList();

  PlacedVehicle? placementById(String placementId) {
    for (final p in placements) {
      if (p.id == placementId) return p;
    }
    return null;
  }

  WagonInstance? wagonById(String wagonId) {
    for (final w in wagons) {
      if (w.id == wagonId) return w;
    }
    return null;
  }

  /// How many copies of one vehicle designation are already on the train —
  /// compared against the [VehicleOrder] quantity so the placement screen
  /// knows what is left to place.
  int placedCountOf(String vehicleId) =>
      placements.where((p) => p.vehicleId == vehicleId).length;

  bool get isEmpty => wagons.isEmpty && placements.isEmpty;

  TrainConsist withWagons(List<WagonInstance> newWagons) {
    // Dropping wagons must not strand a placement on a wagon that no longer
    // exists, so any placement referencing a removed wagon goes with it.
    final ids = newWagons.map((w) => w.id).toSet();
    return TrainConsist(
      wagons: newWagons,
      placements: placements.where((p) => p.wagonIds.every(ids.contains)).toList(),
      nextPlacementSeq: nextPlacementSeq,
    );
  }

  /// Adds one vehicle to the train, on one wagon or across the two it spans.
  /// The placement takes [nextPlacementId] and the counter advances.
  TrainConsist withVehiclePlaced({
    required String vehicleId,
    required List<String> wagonIds,
  }) =>
      TrainConsist(
        wagons: wagons,
        placements: [
          ...placements,
          PlacedVehicle(id: nextPlacementId, vehicleId: vehicleId, wagonIds: wagonIds),
        ],
        nextPlacementSeq: nextPlacementSeq + 1,
      );

  TrainConsist withoutPlacement(String placementId) => TrainConsist(
        wagons: wagons,
        placements: placements.where((p) => p.id != placementId).toList(),
        nextPlacementSeq: nextPlacementSeq,
      );

  TrainConsist withUpdatedPlacement(PlacedVehicle updated) => TrainConsist(
        wagons: wagons,
        placements: [
          for (final p in placements) if (p.id == updated.id) updated else p,
        ],
        nextPlacementSeq: nextPlacementSeq,
      );
}
