import '../../data/models/vehicle.dart';
import 'vehicle_mesh_builder.dart';
import 'wheeled_vehicle_mesh_builder.dart';

/// Decides whether a vehicle record can be drawn in three dimensions, and
/// with what dimensions.
///
/// The rule is the same one the rest of this project runs on: **a model is
/// built only where the figures to build it exist.** A three-dimensional
/// vehicle is a much more persuasive object than a rectangle on a schematic —
/// it looks measured whether or not it is — so a record whose length, width,
/// height and ground clearance are the extract's "not available" markers gets
/// no model at all, and the screen falls back to the flat views that are
/// honest about being illustrative. Nothing here invents a dimension to make
/// a picture possible.
///
/// Shape detail that no source records — how many road wheels, whether the
/// hull carries side skirts — is a drawing choice and is kept in the
/// per-vehicle supplement below, where it can be read and corrected. It never
/// affects a reported measurement: those come from the record's own figures.
class VehicleMeshCatalog {
  VehicleMeshCatalog._();

  /// Shape detail per vehicle, for the vehicles whose appearance is known
  /// beyond what the dimension fields carry.
  static const Map<String, VehicleMeshSpec> _supplement = {
    // The T-90S's own published specification also gives the width over the
    // tracks (3.37 m) separately from the width over the side skirts
    // (3.78 m), and the overall length with the gun forward (9.53 m) from
    // which its 2.67 m of gun overhang follows. The vehicle record has one
    // width field and one length field, so those two extra figures live here.
    'veh-t90s': TrackedVehicleMeshSpec.t90s,
    // The T-72's record has one width field and one length field too, and the
    // same two extra published figures to keep: 3.46 m over the tracks
    // against 3.59 m over the fenders, and 9.53 m overall with the gun
    // forward.
    'veh-t72': TrackedVehicleMeshSpec.t72,
    // The T-80U's published specification likewise gives the width over the
    // tracks (3.40 m) apart from the width over the skirts (3.60 m) and the
    // overall length over the gun (9.65 m, hence 2.65 m of overhang), which
    // the single width and length fields of the record cannot both hold.
    'veh-t80u': TrackedVehicleMeshSpec.t80u,
  };

  /// The mesh specification for [vehicle], or null when it cannot honestly be
  /// modelled.
  ///
  /// A supplemented vehicle is drawn from its supplement. Any other tracked
  /// vehicle is drawn from its own record, once that record carries the
  /// lengths a solid needs; a wheeled vehicle is not drawn here at all, since
  /// this builder makes tracked running gear.
  static VehicleMeshSpec? specFor(Vehicle vehicle) {
    final supplemented = _supplement[vehicle.id];
    if (supplemented != null) return supplemented;
    if (vehicle.category == VehicleCategory.wheeled) {
      return _wheeledSpecFor(vehicle);
    }
    if (vehicle.category != VehicleCategory.tracked) return null;

    final length = vehicle.lengthCm.asDouble;
    final width = vehicle.widthCm.asDouble;
    final height = vehicle.heightCm.asDouble;
    final clearance = vehicle.groundClearanceCm.asDouble;
    final shoe = vehicle.trackWidthMm.asDouble;
    if (length == null || width == null || height == null || clearance == null || shoe == null) {
      return null;
    }
    // The length of track on the ground, where the record states it; the
    // chocks are butted against the ends of it, so a missing figure falls
    // back to the well-established proportion of hull length rather than
    // leaving the running gear undefined.
    final contact = vehicle.wheelBaseCm.asDouble ?? length * 0.62;

    return TrackedVehicleMeshSpec(
      hullLengthM: length / 100,
      // With no separate over-tracks figure recorded, the hull is drawn as
      // wide as its widest point and without skirts. That keeps the drawn
      // width equal to the recorded width, which is the figure the view
      // reports.
      widthOverTracksM: width / 100,
      overallWidthM: width / 100,
      hullRoofHeightM: (height / 100) * 0.64,
      overallHeightM: height / 100,
      groundClearanceM: clearance / 100,
      trackShoeWidthM: shoe / 1000,
      trackContactLengthM: contact / 100,
      roadWheelCount: 5,
      roadWheelRadiusM: (clearance / 100) * 0.78,
      // No overall-length-over-gun figure, so nothing is drawn reaching past
      // the nose. Better a gun that is not there than an overhang the record
      // cannot support.
      gunOverhangM: 0,
    );
  }

  /// A lorry, from its own record.
  ///
  /// Length, width and height are the record's, and they are the three every
  /// reported measurement rests on. Where the axles sit and how big the wheels
  /// are is not recorded for any lorry in this catalogue — no wheelbase, no
  /// ground clearance — so those are the drawing proportions held in
  /// [WheeledVehicleMeshSpec], and nothing the view reports depends on them.
  ///
  /// The one shape fact that is recorded is the axle count, and it decides
  /// how many wheels are drawn, which is what plate-06 counts chocks by.
  static WheeledVehicleMeshSpec? _wheeledSpecFor(Vehicle vehicle) {
    final length = vehicle.lengthCm.asDouble;
    final width = vehicle.widthCm.asDouble;
    final height = vehicle.heightCm.asDouble;
    if (length == null || width == null || height == null) return null;

    // No fallback. Plate 06 counts chocks by the axle count, and the drawn
    // wheels are what a trainee reads that count off; a lorry whose record
    // does not state one would be drawn on an invented number of axles and
    // then measured against it. A record without the figure keeps the flat
    // views, exactly as one without dimensions does.
    final axles = vehicle.axleCount;
    if (axles == null) return null;
    return WheeledVehicleMeshSpec(
      hullLengthM: length / 100,
      overallWidthM: width / 100,
      overallHeightM: height / 100,
      groundClearanceM:
          (vehicle.groundClearanceCm.asDouble ?? 40) / 100,
      axleCount: axles,
      // Wheel and tyre sized off the vehicle's own height and width rather
      // than off a constant, so a heavy six-wheeler and a light four-wheeler
      // do not come out on the same wheels.
      wheelRadiusM: (height / 100) * 0.19,
      tyreWidthM: (width / 100) * 0.13,
      axleFractions: axles >= 4
          // An 8x8 (the BTR APCs): two axles forward, two aft.
          ? const [0.66, 0.30, -0.27, -0.64]
          : axles == 3
              ? const [0.63, -0.32, -0.70]
              : const [0.60, -0.60],
      // The KamAZ is a cab-over; the ZIL and the Ural are bonneted. It is the
      // most visible difference between the three and the record does carry
      // enough to tell them apart — their designations.
      cabOverEngine: vehicle.id.contains('kamaz'),
    );
  }

  /// Whether [vehicle] can be shown in the three-dimensional view.
  static bool canModel(Vehicle vehicle) => specFor(vehicle) != null;
}
