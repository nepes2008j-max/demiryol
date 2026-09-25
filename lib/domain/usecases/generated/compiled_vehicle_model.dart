import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

/// A vehicle model held in source rather than in `assets/`.
///
/// Most bundled models are ordinary asset files, listed in
/// `assets/data/vehicle_models.json` and read through [VehicleModelAsset].
/// That is the better arrangement: the file can be inspected, swapped or
/// deleted without touching code. This class exists for the models whose
/// licence does not allow that.
///
/// The case that produced it: a model bought on CGTrader may be shipped inside
/// an application only as what their terms call an "Incorporated Product" —
/// one that "cannot be extracted from an application ... and used as a
/// stand-alone object without the use of reverse engineering tools or
/// techniques" (§21A.6 and definition 8). A Wavefront file under `assets/`
/// fails that test on sight: a Linux desktop build puts it in
/// `data/flutter_assets/` as plain text anyone can copy out. Compiled into the
/// Dart snapshot it does not.
///
/// So the geometry is gzipped, base64'd and split into source lines by
/// `tools/import_sketchfab_model.py`, and unpacked here into exactly the
/// Wavefront text the ordinary loader already reads. Nothing downstream knows
/// the difference.
///
/// The credit is carried in the same fields an asset-backed model carries, and
/// for the same reason: this project does not draw anybody's work without
/// their name beside it, whether or not the licence compels it.
class CompiledVehicleModel {
  final String vehicleId;

  /// A name ending in the extension the mesh loader dispatches on. There is no
  /// file of this name on disk — the geometry is [packedObj] — but the loader
  /// chooses its parser by extension and this keeps that one code path.
  final String fileName;

  final String sourceTitle;
  final String sourceUrl;
  final String license;
  final String licenseUrl;
  final String author;
  final String? notes;

  /// The Wavefront text, gzipped and base64'd, split so the generated source
  /// stays readable and diffable.
  final List<String> packedObj;

  const CompiledVehicleModel({
    required this.vehicleId,
    required this.fileName,
    required this.sourceTitle,
    required this.sourceUrl,
    required this.license,
    required this.licenseUrl,
    required this.author,
    required this.packedObj,
    this.notes,
  });

  /// One line of credit, in the form the photograph and asset credits take.
  String get creditLine => '$sourceTitle — $author ($license)';

  /// The same completeness gate the asset-backed models pass: a model whose
  /// author, source or terms are blank is not drawn.
  bool get isAttributed =>
      sourceTitle.trim().isNotEmpty &&
      sourceUrl.trim().isNotEmpty &&
      license.trim().isNotEmpty &&
      author.trim().isNotEmpty;

  /// The unpacked Wavefront text.
  Uint8List bytes() =>
      Uint8List.fromList(gzip.decode(base64.decode(packedObj.join())));
}
