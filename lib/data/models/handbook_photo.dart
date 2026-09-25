import 'localized_text.dart';

/// A figure/diagram bundled directly from the handbook docx's embedded
/// media, referenced by its original figure number ("Surat 15.x").
///
/// `captionTk` is a Turkmen translation of [caption] merged in by
/// [HandbookRepository] from `assets/data/localization/photos_tk.json`.
class HandbookPhoto {
  final String id;
  final String assetPath; // relative to assets/, e.g. "images/image34.png"
  final String figureNumber;
  final String caption;
  final String referenceId;
  final String? captionTk;

  const HandbookPhoto({
    required this.id,
    required this.assetPath,
    required this.figureNumber,
    required this.caption,
    required this.referenceId,
    this.captionTk,
  });

  factory HandbookPhoto.fromJson(Map<String, dynamic> json) => HandbookPhoto(
        id: json['id'] as String,
        assetPath: json['file'] as String,
        figureNumber: json['figureNumber'] as String,
        caption: json['caption'] as String,
        referenceId: json['referenceId'] as String,
      );

  HandbookPhoto withTurkmen(Map<String, dynamic>? tk) {
    if (tk == null) return this;
    return HandbookPhoto(
      id: id,
      assetPath: assetPath,
      figureNumber: figureNumber,
      caption: caption,
      referenceId: referenceId,
      captionTk: tk['captionTk'] as String?,
    );
  }

  String get fullAssetPath => 'assets/$assetPath';

  String get displayCaption => preferTurkmen(caption, captionTk);
}
