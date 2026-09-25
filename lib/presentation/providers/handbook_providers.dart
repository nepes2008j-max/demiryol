import 'package:collection/collection.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/attachment_type.dart';
import '../../data/models/handbook_photo.dart';
import '../../data/models/handbook_reference.dart';
import '../../data/models/handbook_rule.dart';
import '../../data/models/platform.dart';
import '../../data/models/principle.dart';
import '../../data/models/vehicle.dart';
import '../../data/repositories/admin_catalog.dart';
import '../../domain/models/securing_placement.dart';
import '../../data/models/vehicle_model_asset.dart';
import '../../data/models/vehicle_photo.dart';
import '../../domain/usecases/obj_mesh_loader.dart';
import '../../domain/usecases/generated/compiled_vehicle_models.dart';
import '../../domain/usecases/vehicle_mesh_catalog.dart';
import '../../data/repositories/handbook_repository.dart';
import '../../domain/usecases/engineering_validator.dart';
import '../../domain/usecases/reference_linker.dart';

final handbookRepositoryProvider = Provider<HandbookRepository>((ref) {
  return HandbookRepository();
});

final engineeringValidatorProvider = Provider<EngineeringValidator>((ref) {
  return EngineeringValidator(ref.watch(handbookRepositoryProvider));
});

/// What the instructor added on this machine, on top of the bundle.
final adminCatalogStoreProvider =
    Provider<AdminCatalogStore>((ref) => const AdminCatalogStore());

final adminCatalogProvider = FutureProvider<AdminCatalog>((ref) {
  return ref.watch(adminCatalogStoreProvider).load();
});

/// The instructor's own photograph for each piece of securing gear, by kind.
///
/// Empty until they add one. Where a kind has an entry the screens draw it
/// instead of the handbook figure, which is the point: the extract's plates
/// show a generic block, and an instructor with a photograph of the actual
/// item in their store can put that in front of the trainee instead.
final gearPhotosProvider = Provider<Map<SecuringPieceKind, String>>((ref) {
  final catalog = ref.watch(adminCatalogProvider).valueOrNull;
  if (catalog == null) return const {};
  return {
    for (final kind in SecuringPieceKind.values)
      if (catalog.photos[gearPhotoKey(kind)]?['figure'] != null)
        kind: catalog.photos[gearPhotoKey(kind)]!['figure']!,
  };
});

/// The instructor's own photographs of catalogue vehicles, by vehicle id.
///
/// Keyed by the same id the bundled catalogue uses, so this covers a vehicle
/// the instructor added *and* one that shipped with the app: replacing the
/// photograph of a T-72 is the same act as giving one to a machine that had
/// none, and there is no reason for the panel to treat them differently.
final vehicleAdminPhotosProvider =
    Provider<Map<String, Map<String, String>>>((ref) {
  final catalog = ref.watch(adminCatalogProvider).valueOrNull;
  if (catalog == null) return const {};
  return {
    for (final e in catalog.photos.entries)
      if (!e.key.startsWith('gear:')) e.key: e.value,
  };
});

/// The bundled catalogue plus whatever the instructor added.
///
/// Merged here rather than at every call site so an added vehicle simply is a
/// vehicle: the search, the picker, the validator and the 3-D view all read
/// this and none of them needs to know where a record came from.
final vehiclesProvider = FutureProvider<List<Vehicle>>((ref) async {
  final bundled = await ref.watch(handbookRepositoryProvider).getVehicles();
  final added = await ref.watch(adminCatalogProvider.future);
  return [...bundled, ...added.vehicles];
});

final platformsProvider = FutureProvider<List<Platform>>((ref) async {
  final bundled = await ref.watch(handbookRepositoryProvider).getPlatforms();
  final added = await ref.watch(adminCatalogProvider.future);
  return [...bundled, ...added.platforms];
});

final attachmentTypesProvider = FutureProvider<List<AttachmentType>>((ref) {
  return ref.watch(handbookRepositoryProvider).getAttachmentTypes();
});

final principlesProvider = FutureProvider<List<Principle>>((ref) {
  return ref.watch(handbookRepositoryProvider).getPrinciples();
});

final referencesProvider = FutureProvider<List<HandbookReference>>((ref) {
  return ref.watch(handbookRepositoryProvider).getReferences();
});

final photosProvider = FutureProvider<List<HandbookPhoto>>((ref) {
  return ref.watch(handbookRepositoryProvider).getPhotos();
});

/// Illustrative vehicle photographs by vehicle id — see [VehiclePhoto].
/// These are not handbook figures and are kept in a separate provider from
/// [photosProvider] so no screen can mix the two up: a widget that shows
/// cited figures cannot accidentally be handed one of these.
final vehiclePhotosProvider = FutureProvider<Map<String, VehiclePhoto>>((ref) {
  return ref.watch(handbookRepositoryProvider).getVehiclePhotos();
});

final ruleEntriesProvider = FutureProvider<List<HandbookRule>>((ref) {
  return ref.watch(handbookRepositoryProvider).getRuleEntries();
});

/// Raw `measurements.json` — the sizing tables the Required Equipment panel
/// reads to build its selectable options (see `equipment_catalog.dart`), and
/// that `SchematicBuilder` reads for the wood-chock element's real Table 3
/// dimensions.
final measurementsProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(handbookRepositoryProvider).getMeasurements();
});

/// Raw `rules.json` — `SchematicBuilder` reads this for the actual required
/// wire-lashing count (`rule-wheeled-lashing-count`) instead of a fixed
/// default.
final rulesProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(handbookRepositoryProvider).getRules();
});

/// Combines every browsable handbook collection so relationships between
/// them (figures, principles, rules, vehicles, platforms, hardware) can be
/// resolved by shared reference id — see [ReferenceLinker].
final referenceLinkerProvider = FutureProvider<ReferenceLinker>((ref) async {
  final photos = await ref.watch(photosProvider.future);
  final principles = await ref.watch(principlesProvider.future);
  final rules = await ref.watch(ruleEntriesProvider.future);
  final vehicles = await ref.watch(vehiclesProvider.future);
  final platforms = await ref.watch(platformsProvider.future);
  final attachments = await ref.watch(attachmentTypesProvider.future);
  return ReferenceLinker(
    photos: photos,
    principles: principles,
    rules: rules,
    vehicles: vehicles,
    platforms: platforms,
    attachments: attachments,
  );
});

/// Category chosen on the new Vehicle Category screen, so the Vehicle
/// Selection screen right after it only lists vehicles of that category —
/// never a fabricated category, always one of `Vehicle.category`'s actual
/// values in the loaded data.
/// The bundled model files, indexed by vehicle id. Empty until one is added.
final vehicleModelAssetsProvider =
    FutureProvider<Map<String, VehicleModelAsset>>((ref) {
  return ref.watch(handbookRepositoryProvider).getVehicleModels();
});

/// One vehicle's model file, read and fitted to the dimensions its record
/// states, or null when it has no file.
///
/// Null is the normal case and never an error: a vehicle without a model file
/// is drawn from its dimensions, which is what every vehicle in the catalogue
/// does today. What this provider adds is the door for a real one.
final vehicleMeshProvider =
    FutureProvider.family<FittedVehicleMesh?, String>((ref, vehicleId) async {
  // Every `ref.watch` happens BEFORE the first await, for the same reason it
  // does in `placementResultsProvider`: watching after one is not allowed in
  // an async provider, because the provider may have been disposed while the
  // await was outstanding and `ref` then throws. This one watched two
  // providers after awaiting — the model manifest and the repository — so a
  // vehicle whose catalogue read was still in flight when the screen was left
  // took the mesh down with an error rather than simply being abandoned.
  final vehiclesFuture = ref.watch(vehiclesProvider.future);
  final assetsFuture = ref.watch(vehicleModelAssetsProvider.future);
  final repository = ref.watch(handbookRepositoryProvider);

  final vehicles = await vehiclesFuture;
  final vehicle = vehicles.where((v) => v.id == vehicleId).firstOrNull;
  final spec = vehicle == null ? null : VehicleMeshCatalog.specFor(vehicle);
  if (spec == null) return null;

  // An asset file first: it can be inspected and replaced without a rebuild,
  // so a model that is allowed to ship that way should. A compiled-in model is
  // the fallback, for the ones whose licence forbids shipping them as a file
  // anybody could copy out of the bundle.
  final assets = await assetsFuture;
  final asset = assets[vehicleId];
  final compiled =
      asset == null ? CompiledVehicleModels.forVehicle(vehicleId) : null;
  if (asset == null && compiled == null) return null;

  final bytes = asset != null
      ? await repository.loadVehicleModelBytes(asset)
      : compiled!.bytes();
  if (bytes == null) return null;

  final loaded = MeshFileLoader.load(
    bytes,
    asset?.file ?? compiled!.fileName,
    // Fitted to the length over the gun, which is the model's own longest
    // dimension when the gun is trained forward — the way a model is almost
    // always authored.
    targetLengthM: spec.lengthOverGunM,
    recordedHeightM: spec.overallHeightM,
    recordedWidthM: spec.overallWidthM,
    convention: asset?.convention ?? ObjAxisConvention.yUpFacingMinusZ,
    materialFor: ObjMeshLoader.materialFromName,
  );
  if (loaded.mesh.isEmpty) return null;
  return FittedVehicleMesh(
    model: loaded,
    creditLine: asset?.creditLine ?? compiled!.creditLine,
    asset: asset,
  );
});

/// A vehicle's model file after loading: the mesh, the credit that has to be
/// shown with it, and how far it landed from the recorded dimensions.
class FittedVehicleMesh {
  final LoadedObjModel model;

  /// The credit that has to be shown wherever this mesh is drawn, whether it
  /// came from an asset file or from a compiled-in model.
  final String creditLine;

  /// The manifest entry, when the model is an asset file. Null for a
  /// compiled-in one, which has no file behind it.
  final VehicleModelAsset? asset;

  const FittedVehicleMesh({
    required this.model,
    required this.creditLine,
    this.asset,
  });
}

final selectedVehicleCategoryProvider = StateProvider<VehicleCategory?>((ref) => null);
