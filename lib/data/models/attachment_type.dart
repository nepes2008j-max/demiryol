import 'localized_text.dart';

enum AttachmentCategory {
  rope,
  chain,
  cable,
  woodBlock,
  metalStop,
  wheelStop,
  trackStop,
  woodWedge,
  clamp,
  bolt,
  specialLock,
  unknown,
}

AttachmentCategory _parseCategory(String? raw) {
  for (final c in AttachmentCategory.values) {
    if (c.name == raw) return c;
  }
  return AttachmentCategory.unknown;
}

/// A physical fastening hardware type from Annex 14 §3 of the handbook.
/// The Securing module only ever offers items from this catalog — the
/// simulator never invents a rope/chain/block type that isn't here.
///
/// `notesTk` is a Turkmen translation of [notes] merged in by
/// [HandbookRepository] from `assets/data/localization/attachments_tk.json`.
/// `name`/`category`/`material`/sizing fields are never translated — see
/// docs/turkmen-content-localization-report.md.
class AttachmentType {
  final String id;
  final AttachmentCategory category;
  final String name;
  final String? material;
  final List<int>? diametersAvailableMm;
  final List<String>? usedFor;
  final String? sizingRule;
  final String referenceId;
  final String? notes;
  final String? combatWeightRangeT;
  final int? minThicknessMm;
  final String? notesTk;

  const AttachmentType({
    required this.id,
    required this.category,
    required this.name,
    this.material,
    this.diametersAvailableMm,
    this.usedFor,
    this.sizingRule,
    required this.referenceId,
    this.notes,
    this.combatWeightRangeT,
    this.minThicknessMm,
    this.notesTk,
  });

  factory AttachmentType.fromJson(Map<String, dynamic> json) => AttachmentType(
        id: json['id'] as String,
        category: _parseCategory(json['category'] as String?),
        name: json['name'] as String,
        material: json['material'] as String?,
        diametersAvailableMm: (json['diametersAvailableMm'] as List?)?.cast<int>(),
        usedFor: (json['usedFor'] as List?)?.cast<String>(),
        sizingRule: json['sizingRule'] as String?,
        referenceId: json['referenceId'] as String,
        notes: json['notes'] as String?,
        combatWeightRangeT: json['combatWeightRangeT'] as String?,
        minThicknessMm: json['minThicknessMm'] as int?,
      );

  AttachmentType withTurkmen(Map<String, dynamic>? tk) {
    if (tk == null) return this;
    return AttachmentType(
      id: id,
      category: category,
      name: name,
      material: material,
      diametersAvailableMm: diametersAvailableMm,
      usedFor: usedFor,
      sizingRule: sizingRule,
      referenceId: referenceId,
      notes: notes,
      combatWeightRangeT: combatWeightRangeT,
      minThicknessMm: minThicknessMm,
      notesTk: tk['notesTk'] as String?,
    );
  }

  String? get displayNotes => notes == null ? null : preferTurkmen(notes!, notesTk);
}
