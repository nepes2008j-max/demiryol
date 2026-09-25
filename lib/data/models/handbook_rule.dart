import '../../core/localization/app_strings.dart';
import 'localized_text.dart';

/// A single entry from `rules.json` — either a validation rule ("rules")
/// or one of the six handbook-approved tracked-vehicle securing methods
/// ("sixApprovedTrackedMethods"). Kept as one typed model since both are
/// "rules" from the Reference Browser's point of view: named, cited,
/// browsable handbook procedures.
///
/// `descriptionTk`/`failMessageTk` are Turkmen translations merged in by
/// [HandbookRepository] from `assets/data/localization/rules_tk.json` (see
/// docs/turkmen-content-localization-report.md). For a method entry,
/// `descriptionTk` holds the translated method name (methods store their
/// name in the `description` field — see [fromMethodJson]). `condition`,
/// `lookupTable`, and `appliesTo` are engineering logic/enum values, never
/// translated.
class HandbookRule {
  final String id;
  final String? appliesTo;
  final String description;
  final String? condition;
  final String? failMessage;
  final String? lookupTable;
  final bool hasLookup;
  final String referenceId;
  final bool isMethod;
  final int? methodNumber;
  final String? descriptionTk;
  final String? failMessageTk;

  const HandbookRule({
    required this.id,
    this.appliesTo,
    required this.description,
    this.condition,
    this.failMessage,
    this.lookupTable,
    this.hasLookup = false,
    required this.referenceId,
    this.isMethod = false,
    this.methodNumber,
    this.descriptionTk,
    this.failMessageTk,
  });

  factory HandbookRule.fromRuleJson(Map<String, dynamic> json) => HandbookRule(
        id: json['id'] as String,
        appliesTo: json['appliesTo'] as String?,
        description: (json['description'] as String?) ?? '',
        condition: json['condition'] as String?,
        failMessage: json['failMessage'] as String?,
        lookupTable: json['lookupTable'] as String?,
        hasLookup: json['lookup'] != null || json['lookupTable'] != null,
        referenceId: (json['referenceId'] as String?) ?? '',
      );

  factory HandbookRule.fromMethodJson(Map<String, dynamic> json) => HandbookRule(
        id: 'method-${json['method']}',
        appliesTo: 'tracked',
        description: json['name'] as String,
        referenceId: json['referenceId'] as String,
        isMethod: true,
        methodNumber: json['method'] as int?,
      );

  HandbookRule withTurkmen(Map<String, dynamic>? tk) {
    if (tk == null) return this;
    return HandbookRule(
      id: id,
      appliesTo: appliesTo,
      description: description,
      condition: condition,
      failMessage: failMessage,
      lookupTable: lookupTable,
      hasLookup: hasLookup,
      referenceId: referenceId,
      isMethod: isMethod,
      methodNumber: methodNumber,
      descriptionTk: tk['descriptionTk'] as String?,
      failMessageTk: tk['failMessageTk'] as String?,
    );
  }

  String get displayDescription => preferTurkmen(description, descriptionTk);

  String? get displayFailMessage =>
      failMessage == null ? null : preferTurkmen(failMessage!, failMessageTk);

  /// Title shown in list/browser contexts.
  String get displayTitle => isMethod
      ? AppStrings.approvedMethodTitle(methodNumber, displayDescription)
      : displayDescription;
}
