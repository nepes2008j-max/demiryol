/// An illustrative photograph of a vehicle, fetched from Wikimedia Commons
/// by `tools/fetch_vehicle_photos.py` and catalogued in
/// `assets/data/vehicle_photos.json`.
///
/// This is deliberately a **separate type from [HandbookPhoto]**, not a
/// variant of it. The handbook extract contains no identification photograph
/// of any vehicle — every figure in it shows generic securing equipment or a
/// procedure (see `docs/handbook-photo-mapping-report.md`) — so a vehicle
/// card would otherwise show nothing at all. These photographs fill that gap
/// so a trainee can see what they are loading, but they are *not* handbook
/// figures: they carry no figure number, no `referenceId`, and they may never
/// be cited as a source. Keeping them in their own type makes it impossible
/// for one to reach a widget that presents cited figures.
///
/// Every entry carries the licence, author and Commons file page of the
/// photograph so the UI can display attribution, which the CC BY / CC BY-SA
/// licences the fetcher accepts require.
class VehiclePhoto {
  /// The `id` of the vehicle in `vehicles.json` this photograph depicts.
  final String vehicleId;

  /// Path relative to `assets/`, e.g. "images/vehicles/veh-t34.jpg".
  final String assetPath;

  /// The same photograph with everything but the machine cut away, relative
  /// to `assets/` — or null when no clean cut-out could be produced from it.
  ///
  /// Null is a normal state, not a defect: `tools/cutout_vehicle_photos.py`
  /// only records a cut-out that passed review by eye, so a vehicle
  /// photographed against a museum wall that the separation could not part
  /// from its camouflage simply has none, and the app draws that vehicle's
  /// side elevation instead of standing a ragged photograph on the wagon.
  final String? cutoutPath;

  /// Extra views of the same machine, by view name ("front", "side", "rear"),
  /// each a path relative to `assets/`.
  ///
  /// The primary [assetPath] stays whatever the fetcher judged the best single
  /// picture; these are the other angles, when Commons had them under a clear
  /// enough title to tell which is which. Empty is the normal state.
  final Map<String, String> views;

  /// The Commons file title, e.g. "File:T-34-85 (Kubinka).jpg".
  final String sourceTitle;

  /// The Commons file description page — the canonical place the licence
  /// and full authorship of the photograph can be verified.
  final String sourceUrl;

  /// Licence short name exactly as Commons states it ("CC BY-SA 4.0",
  /// "Public domain", …). Never re-worded: attribution has to match.
  final String license;
  final String licenseUrl;

  /// Author as Commons states it, with markup stripped. May be empty for an
  /// old public-domain photograph whose author is genuinely unrecorded.
  final String author;

  const VehiclePhoto({
    required this.vehicleId,
    required this.assetPath,
    this.cutoutPath,
    this.views = const {},
    required this.sourceTitle,
    required this.sourceUrl,
    required this.license,
    required this.licenseUrl,
    required this.author,
  });

  factory VehiclePhoto.fromJson(Map<String, dynamic> json) => VehiclePhoto(
        vehicleId: json['vehicleId'] as String,
        assetPath: json['file'] as String,
        cutoutPath: json['cutout'] as String?,
        views: {
          for (final e in ((json['views'] as Map?) ?? const {}).entries)
            e.key as String: e.value as String,
        },
        sourceTitle: (json['sourceTitle'] as String?) ?? '',
        sourceUrl: (json['sourceUrl'] as String?) ?? '',
        license: (json['license'] as String?) ?? '',
        licenseUrl: (json['licenseUrl'] as String?) ?? '',
        author: (json['author'] as String?) ?? '',
      );

  String get fullAssetPath => 'assets/$assetPath';

  /// A named view's full asset key, or null when that angle was not found.
  String? fullViewPath(String view) =>
      views[view] == null ? null : 'assets/${views[view]}';

  /// The cut-out's full asset key, or null when this photograph has none.
  String? get fullCutoutPath => cutoutPath == null ? null : 'assets/$cutoutPath';

  /// True when this vehicle can be shown standing on the flatcar photograph.
  bool get hasCutout => cutoutPath != null;

  /// One-line credit: author and licence, skipping either part when Commons
  /// does not record it, so an unknown author never prints as "Unknown" or an
  /// empty dash. Returns an empty string only if neither is recorded, which
  /// the fetcher's licence allow-list makes impossible for the licence half.
  String get creditLine {
    final parts = <String>[
      if (author.trim().isNotEmpty) author.trim(),
      if (license.trim().isNotEmpty) license.trim(),
    ];
    return parts.join(' · ');
  }
}
