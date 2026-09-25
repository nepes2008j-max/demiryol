import 'localized_text.dart';

/// Explains WHY a securing step exists — the educational core of the app.
///
/// The `xTk` fields are Turkmen translations merged in by
/// [HandbookRepository] from `assets/data/localization/principles_tk.json`
/// (see docs/turkmen-content-localization-report.md); they are optional so
/// a principle without a translation yet still renders (in English) rather
/// than breaking. Use the `displayX` getters, never the raw English fields
/// directly, when rendering to the user.
class Principle {
  final String id;
  final String title;
  final String principle;
  final String purpose;
  final String physics;
  final String engineeringReason;
  final String militaryRequirement;
  final String handbookReferenceId;
  final String? titleTk;
  final String? principleTk;
  final String? purposeTk;
  final String? physicsTk;
  final String? engineeringReasonTk;
  final String? militaryRequirementTk;

  const Principle({
    required this.id,
    required this.title,
    required this.principle,
    required this.purpose,
    required this.physics,
    required this.engineeringReason,
    required this.militaryRequirement,
    required this.handbookReferenceId,
    this.titleTk,
    this.principleTk,
    this.purposeTk,
    this.physicsTk,
    this.engineeringReasonTk,
    this.militaryRequirementTk,
  });

  factory Principle.fromJson(Map<String, dynamic> json) => Principle(
        id: json['id'] as String,
        title: json['title'] as String,
        principle: json['principle'] as String,
        purpose: json['purpose'] as String,
        physics: json['physics'] as String,
        engineeringReason: json['engineeringReason'] as String,
        militaryRequirement: json['militaryRequirement'] as String,
        handbookReferenceId: json['handbookReferenceId'] as String,
      );

  Principle withTurkmen(Map<String, dynamic>? tk) {
    if (tk == null) return this;
    return Principle(
      id: id,
      title: title,
      principle: principle,
      purpose: purpose,
      physics: physics,
      engineeringReason: engineeringReason,
      militaryRequirement: militaryRequirement,
      handbookReferenceId: handbookReferenceId,
      titleTk: tk['titleTk'] as String?,
      principleTk: tk['principleTk'] as String?,
      purposeTk: tk['purposeTk'] as String?,
      physicsTk: tk['physicsTk'] as String?,
      engineeringReasonTk: tk['engineeringReasonTk'] as String?,
      militaryRequirementTk: tk['militaryRequirementTk'] as String?,
    );
  }

  String get displayTitle => preferTurkmen(title, titleTk);
  String get displayPrinciple => preferTurkmen(principle, principleTk);
  String get displayPurpose => preferTurkmen(purpose, purposeTk);
  String get displayPhysics => preferTurkmen(physics, physicsTk);
  String get displayEngineeringReason => preferTurkmen(engineeringReason, engineeringReasonTk);
  String get displayMilitaryRequirement => preferTurkmen(militaryRequirement, militaryRequirementTk);
}
