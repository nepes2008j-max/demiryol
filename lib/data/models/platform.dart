import 'handbook_field.dart';
import 'localized_text.dart';

/// `notesTk` is a Turkmen translation of [notes] merged in by
/// [HandbookRepository] from `assets/data/localization/platforms_tk.json`.
/// `name` is never translated — see docs/turkmen-content-localization-report.md.
/// What sort of rolling stock an entry is.
///
/// Only [openFlatcar] can be loaded. The other two wagon kinds exist so the
/// wagon-type step can *offer* them and be told why they are wrong — the
/// handbook places and secures vehicles on open wagons, and none of its
/// securing methods can be applied inside a closed body or on a tank barrel.
/// [echelonClass] is not rolling stock at all but a train-composition weight
/// class, which is why it never appears on that step.
enum PlatformKind { openFlatcar, coveredWagon, tankWagon, echelonClass }

class Platform {
  final String id;
  final PlatformKind kind;
  final String name;
  final HandbookField lengthCm;
  final HandbookField widthCm;
  final HandbookField deckHeightCm;
  final HandbookField maxAxleLoadWheeledT;
  final HandbookField maxGroundPressureTrackedKgCm2;
  final HandbookField specialCaseMaxTrackedT;
  final HandbookField attachmentRings;
  final HandbookField tieDownRings;
  final HandbookField woodSupportPositions;
  final List<String> allowedVehicleTypes;
  final String referenceId;
  final String? notes;
  final HandbookField? trainMaxWeightT;
  final HandbookField? conditionalWagonCount;
  final String? notesTk;

  /// Why this wagon may not be loaded with military vehicles, for the kinds
  /// that may not. Null for the open flatcar. `notApprovedReasonTk` is its
  /// Turkmen translation, merged in the same way as [notes].
  final String? notApprovedReason;
  final String? notApprovedReasonTk;

  const Platform({
    required this.id,
    this.kind = PlatformKind.openFlatcar,
    required this.name,
    required this.lengthCm,
    required this.widthCm,
    required this.deckHeightCm,
    required this.maxAxleLoadWheeledT,
    required this.maxGroundPressureTrackedKgCm2,
    required this.specialCaseMaxTrackedT,
    required this.attachmentRings,
    required this.tieDownRings,
    required this.woodSupportPositions,
    required this.allowedVehicleTypes,
    required this.referenceId,
    this.notes,
    this.trainMaxWeightT,
    this.conditionalWagonCount,
    this.notesTk,
    this.notApprovedReason,
    this.notApprovedReasonTk,
  });

  static PlatformKind _kindFromJson(Object? raw) {
    switch (raw) {
      case 'coveredWagon':
        return PlatformKind.coveredWagon;
      case 'tankWagon':
        return PlatformKind.tankWagon;
      case 'echelonClass':
        return PlatformKind.echelonClass;
      default:
        return PlatformKind.openFlatcar;
    }
  }

  factory Platform.fromJson(Map<String, dynamic> json) => Platform(
        id: json['id'] as String,
        kind: _kindFromJson(json['kind']),
        name: json['name'] as String,
        lengthCm: HandbookField.fromJson(json['lengthCm']),
        widthCm: HandbookField.fromJson(json['widthCm']),
        deckHeightCm: HandbookField.fromJson(json['deckHeightCm']),
        maxAxleLoadWheeledT: HandbookField.fromJson(json['maxAxleLoadWheeledT']),
        maxGroundPressureTrackedKgCm2:
            HandbookField.fromJson(json['maxGroundPressureTrackedKgCm2']),
        specialCaseMaxTrackedT: HandbookField.fromJson(json['specialCaseMaxTrackedT']),
        attachmentRings: HandbookField.fromJson(json['attachmentRings']),
        tieDownRings: HandbookField.fromJson(json['tieDownRings']),
        woodSupportPositions: HandbookField.fromJson(json['woodSupportPositions']),
        allowedVehicleTypes: ((json['allowedVehicleTypes'] as List?) ?? []).cast<String>(),
        referenceId: (json['referenceId'] as String?) ?? '',
        notes: json['notes'] as String?,
        notApprovedReason: json['notApprovedReason'] as String?,
        trainMaxWeightT: json['trainMaxWeightT'] != null
            ? HandbookField.fromJson(json['trainMaxWeightT'])
            : null,
        conditionalWagonCount: json['conditionalWagonCount'] != null
            ? HandbookField.fromJson(json['conditionalWagonCount'])
            : null,
      );

  Platform withTurkmen(Map<String, dynamic>? tk) {
    if (tk == null) return this;
    return Platform(
      id: id,
      kind: kind,
      name: name,
      lengthCm: lengthCm,
      widthCm: widthCm,
      deckHeightCm: deckHeightCm,
      maxAxleLoadWheeledT: maxAxleLoadWheeledT,
      maxGroundPressureTrackedKgCm2: maxGroundPressureTrackedKgCm2,
      specialCaseMaxTrackedT: specialCaseMaxTrackedT,
      attachmentRings: attachmentRings,
      tieDownRings: tieDownRings,
      woodSupportPositions: woodSupportPositions,
      allowedVehicleTypes: allowedVehicleTypes,
      referenceId: referenceId,
      notes: notes,
      trainMaxWeightT: trainMaxWeightT,
      conditionalWagonCount: conditionalWagonCount,
      notesTk: tk['notesTk'] as String?,
      notApprovedReason: notApprovedReason,
      notApprovedReasonTk: tk['notApprovedReasonTk'] as String?,
    );
  }

  bool get isFlatcar => allowedVehicleTypes.isNotEmpty;

  /// True for the three wagon kinds a trainee chooses between on the
  /// wagon-type step. The echelon weight classes are excluded: they are an
  /// accounting unit for composing a train, not something a vehicle is loaded
  /// onto.
  bool get isSelectableWagon => kind != PlatformKind.echelonClass;

  /// True when this wagon may actually be loaded with the given vehicle
  /// categories. A wagon with no approved category at all (the covered and
  /// tank wagons) is never approved, whatever the load.
  bool acceptsAll(Iterable<String> categoryNames) =>
      allowedVehicleTypes.isNotEmpty &&
      categoryNames.every(allowedVehicleTypes.contains);

  String? get displayNotes => notes == null ? null : preferTurkmen(notes!, notesTk);

  String? get displayNotApprovedReason =>
      notApprovedReason == null ? null : preferTurkmen(notApprovedReason!, notApprovedReasonTk);
}
