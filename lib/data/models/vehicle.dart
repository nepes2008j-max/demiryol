import 'handbook_field.dart';
import 'localized_text.dart';

enum VehicleCategory { tracked, wheeled, unknown }

/// Where a vehicle record's figures came from.
///
/// Everything in this project is meant to be traceable to the source
/// handbook, and most of it is. The three wheeled trucks are not: they come
/// from the project's own design mockup, and they exist because the wheeled
/// half of the handbook — plates 05 and 06, the chock count, the lateral gap,
/// the three-axle doubling, KGUUB-1K/2K — could not be reached at all with a
/// catalogue of tracked vehicles only. Marking the record is what keeps that
/// borrowing visible: a mockup figure must never be read as an extracted one.
enum VehicleDataSource {
  /// Extracted from the handbook or its plates.
  handbook,

  /// Supplied by the project's design mockup
  /// (`Berl/harby_yukleme_simulyator.html`), not by the handbook.
  designMockup,

  /// Taken from the vehicle manufacturer's published specification.
  ///
  /// The T-90S is here. The handbook's Annex 14 catalogue stops at the
  /// Soviet-era types, so a modern tank that units actually move by rail
  /// cannot be studied at all from handbook data alone — but it also cannot
  /// be quietly filed among the extracted records, because no securing method
  /// is assigned to it by name and none may be inferred from the tables that
  /// are. A record marked this way carries real, citable dimensions and no
  /// implied handbook authority; every screen that shows one must say so.
  manufacturerSpec,

  /// Taken from the ministry's vehicle transport-characteristics table
  /// ("Harby tehnikalaryň ulag häsiýetnamalary").
  ///
  /// That document is the unit's own list of what it actually moves, and it is
  /// the only source in this project that states a length, width, height and
  /// weight for the vehicles in it — Annex 14 of the loading handbook names
  /// vehicles and assigns them hardware but carries no dimension table at all.
  /// It decides which vehicles the trainer offers.
  ///
  /// It is kept apart from [handbook] for the same reason [manufacturerSpec]
  /// is: its figures are real and citable, but no securing method follows from
  /// them. A vehicle is only ever assigned hardware by Annex 14's own tables,
  /// and a record here that carries none is reported unconfirmed rather than
  /// being given a method the source never gave it.
  transportTable,
}

VehicleDataSource _parseDataSource(String? raw) {
  switch (raw) {
    case 'designMockup':
      return VehicleDataSource.designMockup;
    case 'manufacturerSpec':
      return VehicleDataSource.manufacturerSpec;
    case 'transportTable':
      return VehicleDataSource.transportTable;
    default:
      return VehicleDataSource.handbook;
  }
}

VehicleCategory _parseCategory(String? raw) {
  switch (raw) {
    case 'tracked':
      return VehicleCategory.tracked;
    case 'wheeled':
      return VehicleCategory.wheeled;
    default:
      return VehicleCategory.unknown;
  }
}

/// A vehicle exactly as named in the handbook. Every dimension is a
/// [HandbookField] — see that class's doc comment for why.
///
/// `classDisplayTk`/`notesTk` are Turkmen localization merged in by
/// [HandbookRepository] from `assets/data/localization/vehicles_tk.json`
/// (see docs/turkmen-content-localization-report.md). `classDisplayTk` is
/// the full replacement sentence for the (rare) case where [vehicleClass]
/// is an unavailable-data marker with an English explanatory annotation in
/// parentheses — use [displayClass] rather than reading [vehicleClass]
/// directly when rendering to the user.
class Vehicle {
  final String id;
  final String handbookDesignation;
  final VehicleCategory category;
  final VehicleDataSource dataSource;
  final String vehicleClass;
  final HandbookField lengthCm;
  final HandbookField widthCm;
  final HandbookField heightCm;
  /// What the vehicle weighs, in tonnes.
  ///
  /// One weight, not two. The record used to carry a combat weight and a
  /// transport weight side by side, and the pair caused more harm than the
  /// distinction was worth: for the two tanks whose figures are published
  /// they held the same number twice, for twenty-three handbook vehicles both
  /// were the extract's "not available" marker, and for the three lorries the
  /// only weight anyone had recorded sat in the transport field — which not
  /// one rule read. Every weight-bracket lookup in the application went to
  /// the combat field, so those lorries resolved nothing at all despite their
  /// weight being right there in the data.
  ///
  /// The handbook's own tables are still headed "combat weight range", and
  /// their column names are left as the handbook writes them; what changed is
  /// that the vehicle brings one weight of its own to those tables instead of
  /// the application having to choose between two fields that were never
  /// independently sourced.
  final HandbookField weightT;

  final HandbookField groundClearanceCm;
  final HandbookField trackWidthMm;
  final HandbookField wheelBaseCm;

  /// Length of track actually bearing on the ground, in centimetres.
  ///
  /// Kept separate from [wheelBaseCm] on purpose. For a tracked vehicle
  /// "wheelbase" is ambiguous — it can mean the distance between the first
  /// and last road-wheel centres, which is not the same as the bearing
  /// length — and this figure is multiplied by [trackWidthMm] to get the
  /// contact area the handbook's ground-pressure limit (para. 51) is judged
  /// on. A limit that decides whether a vehicle may cross a wagon's side
  /// edges at all must not rest on a field whose meaning is a matter of
  /// interpretation.
  ///
  /// Not counted in [dataCompleteness]: it is a later addition, and folding
  /// it in would silently move every legacy vehicle's badge.
  final HandbookField trackContactLengthCm;

  /// Figures the instructor supplied for this vehicle because the handbook
  /// extract has none — recorded so nothing can present them as extracted
  /// data. The values themselves live in the matching [HandbookField]s; this
  /// only says where they came from.
  final Set<String> userSuppliedFields;

  /// Axles the vehicle runs on, when the record states it.
  ///
  /// The wheeled chock layout cases are drawn per axle count — a three-axle
  /// vehicle has its middle and rear tyres doubled — so the arrangement
  /// catalogue needs it. Null wherever the source does not give one, which is
  /// every handbook-extracted vehicle: the extract records no axle counts.
  final int? axleCount;
  final String manufacturer;
  final String country;
  final List<String> approvedSecuringHardwareIds;
  final String? ironSpurType;
  final String? ironChockBootType;
  final String referenceId;
  final String? notes;
  final String? classDisplayTk;
  final String? notesTk;

  const Vehicle({
    required this.id,
    required this.handbookDesignation,
    required this.category,
    this.dataSource = VehicleDataSource.handbook,
    required this.vehicleClass,
    required this.lengthCm,
    required this.widthCm,
    required this.heightCm,
    required this.weightT,
    required this.groundClearanceCm,
    required this.trackWidthMm,
    required this.wheelBaseCm,
    this.trackContactLengthCm = const HandbookField(null),
    this.axleCount,
    this.userSuppliedFields = const {},
    required this.manufacturer,
    required this.country,
    required this.approvedSecuringHardwareIds,
    this.ironSpurType,
    this.ironChockBootType,
    required this.referenceId,
    this.notes,
    this.classDisplayTk,
    this.notesTk,
  });

  factory Vehicle.fromJson(Map<String, dynamic> json) => Vehicle(
        id: json['id'] as String,
        handbookDesignation: json['handbookDesignation'] as String,
        dataSource: _parseDataSource(json['dataSource'] as String?),
        category: _parseCategory(json['category'] as String?),
        vehicleClass: (json['class'] as String?) ?? 'TODO: Fill from Handbook Page XX',
        lengthCm: HandbookField.fromJson(json['lengthCm']),
        widthCm: HandbookField.fromJson(json['widthCm']),
        heightCm: HandbookField.fromJson(json['heightCm']),
        // `weightT` is the record's own field. `weightT` and
        // `transportWeightT` are read as fallbacks so a record written before
        // the two were merged still loads, preferring whichever of them
        // actually carries a figure.
        weightT: _weightFrom(json),
        groundClearanceCm: HandbookField.fromJson(json['groundClearanceCm']),
        trackWidthMm: HandbookField.fromJson(json['trackWidthMm']),
        wheelBaseCm: HandbookField.fromJson(json['wheelBaseCm']),
        trackContactLengthCm: HandbookField.fromJson(json['trackContactLengthCm']),
        axleCount: (json['axleCount'] as num?)?.toInt(),
        manufacturer: (json['manufacturer'] as String?) ?? 'TODO: Fill from Handbook Page XX',
        country: (json['country'] as String?) ?? 'TODO: Fill from Handbook Page XX',
        approvedSecuringHardwareIds:
            ((json['approvedSecuringHardware'] as List?) ?? []).cast<String>(),
        ironSpurType: json['ironSpurType'] as String?,
        ironChockBootType: json['ironChockBootType'] as String?,
        referenceId: json['referenceId'] as String,
        notes: json['notes'] as String?,
      );

  /// A copy of this vehicle carrying figures the instructor typed in, for the
  /// fields the handbook extract leaves empty.
  ///
  /// This is the mechanism that lets the engine actually decide something:
  /// the KGUUB weight bracket, the chock size, the wheeled chock count and
  /// the lashing count are all keyed on a combat weight that no record in the
  /// extract carries, so every one of them reported "cannot be decided" for
  /// every vehicle. A typed weight resolves them — and [userSuppliedFields]
  /// keeps that fact attached to the value, so a verdict reached from an
  /// instructor's figure can never be shown as one reached from the handbook.
  ///
  /// A field already present in the extract is never overwritten: the
  /// handbook's own number always wins.

  /// The weight a record states, tolerating the two field names the data used
  /// before they were merged into one. A record that carried both only ever
  /// carried the same number twice, or carried it in exactly one of them.
  static HandbookField _weightFrom(Map<String, dynamic> json) {
    for (final key in const ['weightT', 'combatWeightT', 'transportWeightT']) {
      if (!json.containsKey(key)) continue;
      final field = HandbookField.fromJson(json[key]);
      if (field.isAvailable) return field;
    }
    return HandbookField.fromJson(
        json['weightT'] ??
            json['combatWeightT'] ??
            json['transportWeightT']);
  }

  /// The weight the handbook's weight-keyed tables are asked with.
  ///
  /// It is simply [weightT]. This getter used to withhold the figure unless
  /// the record stated it was a *combat* weight: Table 8's KGUUB brackets, the
  /// chock sizing, the wire-lashing count and the ground pressure of para. 51
  /// are all written about a combat weight, and the ministry's transport table
  /// gives a column headed only "Agramy" without saying which weight it is.
  ///
  /// Withholding it was the wrong call. It meant that across a catalogue of a
  /// hundred and thirty-eight vehicles not one of those five rules could ever
  /// be decided — twenty-six of the thirty-two tracked vehicles came out of
  /// the engine with no required hardware and not a single decidable check,
  /// and the trainer graded six machines properly and guessed at the rest. A
  /// recorded mass is a mass; using it answers the question approximately
  /// right, and refusing to answer at all was not more honest, only less
  /// useful.
  ///
  /// Kept as a named getter rather than folded into [weightT] because the
  /// callers read better for saying which figure they are asking for, and
  /// because it is the one place to look should the source ever start stating
  /// a basis.
  HandbookField get bracketWeightT => weightT;

  Vehicle withUserSuppliedFigures({double? weightT, double? lengthCm}) {
    final supplied = <String>{...userSuppliedFields};
    var weight = this.weightT;
    // The door is for a vehicle whose record carries no weight at all — four
    // of them in the current catalogue. A vehicle that has one keeps it.
    if (weightT != null && !this.weightT.isAvailable) {
      weight = HandbookField(weightT);
      supplied.add('weightT');
    }
    var length = this.lengthCm;
    if (lengthCm != null && !length.isAvailable) {
      length = HandbookField(lengthCm);
      supplied.add('lengthCm');
    }
    if (supplied.length == userSuppliedFields.length) return this;
    return Vehicle(
      id: id,
      handbookDesignation: handbookDesignation,
      category: category,
      dataSource: dataSource,
      vehicleClass: vehicleClass,
      lengthCm: length,
      widthCm: widthCm,
      heightCm: heightCm,
      weightT: weight,
      groundClearanceCm: groundClearanceCm,
      trackWidthMm: trackWidthMm,
      wheelBaseCm: wheelBaseCm,
      trackContactLengthCm: trackContactLengthCm,
      axleCount: axleCount,
      userSuppliedFields: supplied,
      manufacturer: manufacturer,
      country: country,
      approvedSecuringHardwareIds: approvedSecuringHardwareIds,
      ironSpurType: ironSpurType,
      ironChockBootType: ironChockBootType,
      referenceId: referenceId,
      notes: notes,
      classDisplayTk: classDisplayTk,
      notesTk: notesTk,
    );
  }

  /// True when this vehicle is carrying at least one instructor-supplied
  /// figure, so the UI can mark it.
  bool get hasUserSuppliedFigures => userSuppliedFields.isNotEmpty;

  Vehicle withTurkmen(Map<String, dynamic>? tk) {
    if (tk == null) return this;
    return Vehicle(
      id: id,
      handbookDesignation: handbookDesignation,
      category: category,
      dataSource: dataSource,
      vehicleClass: vehicleClass,
      lengthCm: lengthCm,
      widthCm: widthCm,
      heightCm: heightCm,
      weightT: weightT,
      groundClearanceCm: groundClearanceCm,
      trackWidthMm: trackWidthMm,
      wheelBaseCm: wheelBaseCm,
      trackContactLengthCm: trackContactLengthCm,
      axleCount: axleCount,
      userSuppliedFields: userSuppliedFields,
      manufacturer: manufacturer,
      country: country,
      approvedSecuringHardwareIds: approvedSecuringHardwareIds,
      ironSpurType: ironSpurType,
      ironChockBootType: ironChockBootType,
      referenceId: referenceId,
      notes: notes,
      classDisplayTk: tk['classDisplayTk'] as String?,
      notesTk: tk['notesTk'] as String?,
    );
  }

  /// Fraction of the core spec fields (dimensions and weights) that are
  /// actually populated from the handbook rather than TODO.
  ///
  /// The centre-of-gravity height and the tie-down point count used to be
  /// counted here. They were removed from the model outright: no source —
  /// not the handbook, not a manufacturer's specification — publishes either
  /// figure for any vehicle, so they were two permanently empty cells
  /// dragging every vehicle's percentage down and telling the trainee
  /// nothing. Para. 34's centre-of-gravity limit is still in `rules.json`
  /// and still readable in the reference browser; what went is the pretence
  /// that this catalogue could ever check it. Surfaced in the
  /// UI so the user always sees how "real" a vehicle's data currently is.
  double get dataCompleteness {
    final fields = [
      lengthCm,
      widthCm,
      heightCm,
      weightT,
      groundClearanceCm,
      trackWidthMm,
      wheelBaseCm,
    ];
    final available = fields.where((f) => f.isAvailable).length;
    return available / fields.length;
  }

  /// The vehicle's class/type for display: the curated full Turkmen
  /// replacement sentence when one exists (see [classDisplayTk]'s doc),
  /// otherwise [vehicleClass] run through [presentHandbookText] as before.
  String get displayClass => classDisplayTk ?? presentHandbookText(vehicleClass);

  String? get displayNotes => notes == null ? null : preferTurkmen(notes!, notesTk);
}
