import '../../domain/usecases/obj_mesh_loader.dart';

/// A three-dimensional model file bundled for one vehicle, with the licence
/// and attribution it is redistributed under.
///
/// Modelled on [VehiclePhoto] and for the same reason: an asset that came from
/// outside this project carries someone else's name on it, and the terms it
/// arrived under have to travel with it. A model with no licence recorded is
/// not loaded — the check is in [HandbookRepository], not in a convention
/// somebody has to remember.
///
/// The file is Wavefront OBJ or STL. OBJ is preferred — it carries part names,
/// so the tracks can be told from the hull and coloured accordingly — but STL
/// is read too, because that is what the sites which publish freely publish.
/// See `assets/models/README.md`.
class VehicleModelAsset {
  final String vehicleId;

  /// Path under `assets/`, e.g. `models/veh-t72.obj` or `models/veh-t72.stl`.
  final String file;

  /// The page the model came from, its author, and the terms.
  final String sourceTitle;
  final String sourceUrl;
  final String license;
  final String licenseUrl;
  final String author;

  /// Which way up and which way round the file was authored.
  final ObjAxisConvention convention;

  /// Anything the person who added it needs the next reader to know — a
  /// variant that differs from the record, a part that had to be deleted.
  final String? notes;

  const VehicleModelAsset({
    required this.vehicleId,
    required this.file,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.license,
    required this.licenseUrl,
    required this.author,
    this.convention = ObjAxisConvention.yUpFacingMinusZ,
    this.notes,
  });

  factory VehicleModelAsset.fromJson(Map<String, dynamic> json) =>
      VehicleModelAsset(
        vehicleId: json['vehicleId'] as String,
        file: json['file'] as String,
        sourceTitle: json['sourceTitle'] as String,
        sourceUrl: json['sourceUrl'] as String,
        license: json['license'] as String,
        licenseUrl: json['licenseUrl'] as String,
        author: json['author'] as String,
        convention: _convention(json['axisConvention'] as String?),
        notes: json['notes'] as String?,
      );

  static ObjAxisConvention _convention(String? raw) {
    switch (raw) {
      case 'yUpFacingPlusX':
        return ObjAxisConvention.yUpFacingPlusX;
      case 'zUpFacingPlusY':
        return ObjAxisConvention.zUpFacingPlusY;
      default:
        return ObjAxisConvention.yUpFacingMinusZ;
    }
  }

  /// The full asset key the bundle knows this file by.
  String get assetKey => 'assets/$file';

  /// One line of credit, in the form the photograph credits already take.
  String get creditLine => '$sourceTitle — $author ($license)';

  /// True when every field the licence needs is actually filled in. A record
  /// that fails this is not loaded: shipping somebody's model without their
  /// name on it is not something a missing string should be allowed to cause.
  bool get isAttributed =>
      MeshFileLoader.isSupported(file) &&
      sourceTitle.trim().isNotEmpty &&
      sourceUrl.trim().isNotEmpty &&
      license.trim().isNotEmpty &&
      author.trim().isNotEmpty;
}
