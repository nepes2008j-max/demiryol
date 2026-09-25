import '../../data/models/handbook_photo.dart';
import '../../data/models/vehicle.dart';
import 'reference_linker.dart';

/// What a handbook figure actually shows, classified from its own caption
/// text in `photos.json` — never guessed from unrelated context. See
/// `docs/handbook-photo-mapping-report.md` for the caption-by-caption
/// evidence behind every entry below.
enum HandbookPhotoKind { equipment, procedure }

const Map<String, HandbookPhotoKind> _photoKinds = {
  'fig-15.8': HandbookPhotoKind.equipment,
  'fig-15.10': HandbookPhotoKind.equipment,
  'fig-15.11': HandbookPhotoKind.equipment,
  'fig-15.12': HandbookPhotoKind.equipment,
  'fig-15.13a': HandbookPhotoKind.equipment,
  'fig-15.13b': HandbookPhotoKind.equipment,
  'fig-15.14': HandbookPhotoKind.equipment,
  'fig-15.15': HandbookPhotoKind.equipment,
  'fig-15.16ab': HandbookPhotoKind.procedure,
  'fig-15.16cde': HandbookPhotoKind.procedure,
  'fig-15.16ae': HandbookPhotoKind.procedure,
  'fig-15.17ab': HandbookPhotoKind.procedure,
  'fig-15.17cd': HandbookPhotoKind.procedure,
  'fig-15.18': HandbookPhotoKind.procedure,
  'fig-15.26': HandbookPhotoKind.procedure,
  'fig-15.27': HandbookPhotoKind.procedure,
  'fig-15.28': HandbookPhotoKind.procedure,
  'fig-15.29': HandbookPhotoKind.procedure,
  'fig-15.30': HandbookPhotoKind.procedure,
  'fig-15.31': HandbookPhotoKind.procedure,
  // Figures published on the training plates issued with the handbook and
  // republished as panels in Programma uchin.docx.
  'fig-tracked-methods-overview': HandbookPhotoKind.procedure,
  'fig-tracked-method-1': HandbookPhotoKind.procedure,
  'fig-tracked-method-2': HandbookPhotoKind.procedure,
  'fig-tracked-method-3': HandbookPhotoKind.procedure,
  'fig-tracked-method-4': HandbookPhotoKind.procedure,
  'fig-tracked-method-5': HandbookPhotoKind.procedure,
  'fig-tracked-method-6': HandbookPhotoKind.procedure,
  'fig-wheeled-methods-overview': HandbookPhotoKind.procedure,
  'fig-wheeled-method-1': HandbookPhotoKind.procedure,
  'fig-wheeled-method-2': HandbookPhotoKind.procedure,
  'fig-wheeled-method-3': HandbookPhotoKind.procedure,
  'fig-kguub-1g-2g': HandbookPhotoKind.equipment,
  'fig-kguub-1k': HandbookPhotoKind.equipment,
  'fig-kguub-2k': HandbookPhotoKind.equipment,
  'fig-kguub-wheeled-under-tyre': HandbookPhotoKind.equipment,
  'fig-iron-spur-types': HandbookPhotoKind.equipment,
  'fig-iron-chock-boot-ktp-ktt': HandbookPhotoKind.equipment,
  'fig-wood-chock-shapes': HandbookPhotoKind.equipment,
  'fig-wheeled-chock-shapes-and-sizes': HandbookPhotoKind.equipment,
  'fig-wire-lashings-and-consumables': HandbookPhotoKind.equipment,
  'fig-tracked-consumables-tables': HandbookPhotoKind.equipment,
  'fig-clamp-s765': HandbookPhotoKind.equipment,
  'fig-clamp-mk765': HandbookPhotoKind.equipment,
  'fig-tracked-chock-boot-securing': HandbookPhotoKind.procedure,
  'fig-wheeled-chock-securing': HandbookPhotoKind.procedure,
  'fig-wheeled-chock-layout-cases': HandbookPhotoKind.procedure,
  'fig-wagon-plan-chock-layout': HandbookPhotoKind.procedure,
  'fig-lashing-angle-45': HandbookPhotoKind.procedure,
};

/// Defaults to [HandbookPhotoKind.equipment] for any id not in the table
/// above (there is none today — every photo in the extract is classified —
/// but a future re-extraction should never crash on an unrecognized id).
HandbookPhotoKind photoKindOf(String photoId) => _photoKinds[photoId] ?? HandbookPhotoKind.equipment;

/// True only for a figure whose caption explicitly names a specific real
/// vehicle (its own handbook designation, e.g. "T-54") as the subject of
/// the photograph itself. This is false for every figure in the current
/// extract: every figure depicts generic securing equipment or a securing
/// procedure — none is an identification photo of a named vehicle. The
/// plates added from `Berl/` do not change this: they draw generic tracked
/// and wheeled vehicles to illustrate an arrangement, never a designated
/// vehicle as the subject. A vehicle card must never show an
/// equipment/procedure figure as if it were "the vehicle's own photo" — see
/// the mapping report.
bool isVehicleIdentificationPhoto(String photoId) => false;

/// The vehicle's own identification photograph, if the extract actually
/// has one (per [isVehicleIdentificationPhoto]) — never a securing-related
/// figure standing in for it. Returns null today for every vehicle; the
/// UI must show "Surat: çeşmede ýok" rather than substituting an
/// equipment/procedure figure that merely shares the vehicle's citation.
HandbookPhoto? vehicleIdentificationPhotoFor(Vehicle vehicle, ReferenceLinker linker) {
  final matches = linker.photosFor(vehicle.referenceId).where((p) => isVehicleIdentificationPhoto(p.id));
  return matches.isEmpty ? null : matches.first;
}

/// Extra figure ids explicitly relevant to one hardware id even though
/// `attachments.json`'s own `referenceId` citation doesn't reach them —
/// each entry here is backed by the figure's own caption naming that
/// exact hardware id's designation. `att-wire-lashing` cites `table-7`
/// (its sizing rule) but the wire/chain lashing photograph itself is filed
/// under `para-19`; `att-kguub-2g` shares `para-29` with the 1G variant,
/// but its own securing-sequence figures (captioned "KGUUB-2G...") are
/// filed under para-36/38.
const Map<String, List<String>> _extraPhotoIdsByHardwareId = {
  'att-wire-lashing': [
    'fig-15.10',
    // Filed under para-19 (the wire tables) rather than table-7, but the
    // figure itself is captioned as the single-use lashings.
    'fig-wire-lashings-and-consumables',
  ],
  'att-kguub-2g': ['fig-15.16ab', 'fig-15.16cde', 'fig-15.16ae'],
  // The wheeled chock layout figures are filed under the plate they were
  // published on, so the para-21 citation on the chock itself never reaches
  // them; both are captioned as showing where the chocks go.
  'att-wood-chock': [
    'fig-wheeled-chock-layout-cases',
    'fig-wheeled-chock-securing',
  ],
};

/// Figure ids that must NOT be shown for a hardware id even though they
/// share its `referenceId` citation, because the figure's own caption
/// names a *different* specific variant. `fig-15.11` is captioned
/// "KGUUB-1G reusable universal chock" — showing it for `att-kguub-2g`
/// (which cites the same para-29 as 1G) would present the wrong variant's
/// photograph as if it depicted the 2G equipment.
const Map<String, List<String>> _excludedPhotoIdsByHardwareId = {
  'att-kguub-2g': ['fig-15.11'],
  // KGUUB-1K and KGUUB-2K share the para-30 citation, and each of these
  // figures is captioned with one variant's designation. Showing either for
  // the other variant would present the wrong equipment's picture — the same
  // mistake fig-15.11 guards against for the tracked pair above.
  'att-kguub-1k': ['fig-kguub-2k'],
  'att-kguub-2k': ['fig-kguub-1k'],
  // Same again for the clamp pair: both are published under para-33, and each
  // figure is captioned with one designation. (fig-15.15 shows both together
  // and is correct for either, so it is not excluded.)
  'att-clamp-tensioner': ['fig-clamp-s765'],
  'att-clamp': ['fig-clamp-mk765'],
};

/// The handbook's own banner figure for each of the six approved tracked
/// securing methods (Annex 14 §4), so the method selector shows the plate the
/// trainee will recognise rather than text alone. Keyed by the method number
/// `sixApprovedTrackedMethods` uses.
///
/// Each banner is the numbered panel from the source itself, and its wording
/// is the method's own: method 3's banner reads "direg dörtgyraň agaç
/// bölekleri we sim (bir nusgaly) çekmeler arkaly (üçünji usul)". The
/// numbering therefore comes from the plate, not from this table's order.
const Map<int, String> _trackedMethodFigureIds = {
  1: 'fig-tracked-method-1',
  2: 'fig-tracked-method-2',
  3: 'fig-tracked-method-3',
  4: 'fig-tracked-method-4',
  5: 'fig-tracked-method-5',
  6: 'fig-tracked-method-6',
};

/// The banner figure for one approved tracked securing method, or null when
/// the source has no panel for that number. Never falls back to another
/// method's banner — showing method 5's picture beside method 3's title would
/// teach the wrong arrangement.
HandbookPhoto? trackedMethodFigure(int methodNumber, ReferenceLinker linker) {
  final id = _trackedMethodFigureIds[methodNumber];
  if (id == null) return null;
  for (final photo in linker.photos) {
    if (photo.id == id) return photo;
  }
  return null;
}

/// The correct set of figures for one required-equipment slot: the
/// generic `referenceId` match, minus any figure known to depict a
/// different specific variant, plus any figure known (by its own caption)
/// to depict this exact hardware id even though the shared citation
/// doesn't reach it. Every adjustment here is evidence-backed (see the
/// mapping report) — this never adds a figure without a caption match.
List<HandbookPhoto> equipmentPhotosFor(String hardwareId, String referenceId, ReferenceLinker linker) {
  final excluded = _excludedPhotoIdsByHardwareId[hardwareId]?.toSet() ?? const {};
  final base = linker.photosFor(referenceId).where((p) => !excluded.contains(p.id));
  final extraIds = _extraPhotoIdsByHardwareId[hardwareId] ?? const [];
  final extra = linker.photos.where((p) => extraIds.contains(p.id));

  final seen = <String>{};
  final result = <HandbookPhoto>[];
  for (final photo in [...base, ...extra]) {
    if (seen.add(photo.id)) result.add(photo);
  }
  return result;
}
