import 'compiled_vehicle_model.dart';
import 'veh_t72_model.g.dart';

/// The vehicle models compiled into the binary, by vehicle id.
///
/// Checked only after `assets/data/vehicle_models.json`: a model shipped as an
/// ordinary asset always wins, because an asset can be inspected and replaced
/// without a rebuild. This map is for the models whose licence does not allow
/// them to be shipped that way — see [CompiledVehicleModel] for the clause.
///
/// Adding one is a tool's job, not a hand edit:
///
///     tools/import_sketchfab_model.py --archive <file> --vehicle veh-xx \
///         --emit dart --source-title ... --author ... --license ...
abstract final class CompiledVehicleModels {
  static const Map<String, CompiledVehicleModel> byVehicleId = {
    'veh-t72': veh_t72Model,
  };

  /// The compiled model for [vehicleId], or null when there is none — which
  /// is the normal case, and never an error.
  static CompiledVehicleModel? forVehicle(String vehicleId) {
    final model = byVehicleId[vehicleId];
    if (model == null || !model.isAttributed) return null;
    return model;
  }
}
