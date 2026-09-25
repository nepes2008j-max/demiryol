import '../../core/localization/app_strings.dart';
import 'localized_text.dart';

class HandbookSection {
  final String id;
  final String number;
  final String title;

  const HandbookSection({required this.id, required this.number, required this.title});

  factory HandbookSection.fromJson(Map<String, dynamic> json) => HandbookSection(
        id: json['id'] as String,
        number: json['number'] as String,
        title: json['title'] as String,
      );
}

class HandbookChapter {
  final String id;
  final String number;
  final String title;
  final List<HandbookSection> sections;

  const HandbookChapter({
    required this.id,
    required this.number,
    required this.title,
    required this.sections,
  });

  factory HandbookChapter.fromJson(Map<String, dynamic> json) => HandbookChapter(
        id: json['id'] as String,
        number: json['number'] as String,
        title: json['title'] as String,
        sections: ((json['sections'] as List?) ?? [])
            .map((e) => HandbookSection.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// A single citable point in the handbook: a paragraph, table, or figure.
/// Every engineering value, rule, or principle in the app links back to one
/// of these so the user can always trace "why" to a specific source line.
class HandbookReference {
  final String id;
  final String? chapterId;
  final String? sectionId;
  final String? paragraph;
  final String? table;

  /// A training plate's number, when the citation is a plate rather than a
  /// paragraph. Kept apart from [paragraph] because the two are lettered
  /// differently: a plate cited as a paragraph printed "Madda Plate 05" —
  /// "paragraph plate 05", in English, in a Turkmen interface.
  final String? plate;
  final String summary;
  final String? summaryTk;

  const HandbookReference({
    required this.id,
    this.chapterId,
    this.sectionId,
    this.paragraph,
    this.table,
    this.plate,
    required this.summary,
    this.summaryTk,
  });

  factory HandbookReference.fromJson(Map<String, dynamic> json) => HandbookReference(
        id: json['id'] as String,
        chapterId: json['chapterId'] as String?,
        sectionId: json['sectionId'] as String?,
        paragraph: json['paragraph'] as String?,
        table: json['table'] as String?,
        plate: json['plate'] as String?,
        summary: json['summary'] as String,
      );

  HandbookReference withTurkmen(Map<String, dynamic>? tk) {
    if (tk == null) return this;
    return HandbookReference(
      id: id,
      chapterId: chapterId,
      sectionId: sectionId,
      paragraph: paragraph,
      table: table,
      plate: plate,
      summary: summary,
      summaryTk: tk['summaryTk'] as String?,
    );
  }

  /// Short citation label, e.g. "Madda 51", "Tablisa 7" or "Surat 05".
  String get citationLabel {
    final parts = <String>[];
    if (paragraph != null) parts.add('${AppStrings.paragraphCitationPrefix} $paragraph');
    if (table != null) parts.add('${AppStrings.tableCitationPrefix} $table');
    if (plate != null) parts.add('${AppStrings.plateCitationPrefix} $plate');
    return parts.isEmpty ? id : parts.join(' / ');
  }

  /// The Turkmen translation of [summary] from
  /// `assets/data/localization/references_tk.json`, falling back to the
  /// English extraction text if no translation exists yet.
  String get displaySummary => preferTurkmen(summary, summaryTk);
}
