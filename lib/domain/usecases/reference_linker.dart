import '../../data/models/attachment_type.dart';
import '../../data/models/handbook_photo.dart';
import '../../data/models/handbook_rule.dart';
import '../../data/models/platform.dart';
import '../../data/models/principle.dart';
import '../../data/models/vehicle.dart';

/// Resolves relationships between handbook entities strictly by matching
/// `referenceId` (or `handbookReferenceId`) fields that are already present
/// in the extracted JSON. This deliberately does not infer relationships
/// from topic/keyword similarity — two entities are "related" here only if
/// the extraction already cites them under the same paragraph/table id.
class ReferenceLinker {
  final List<HandbookPhoto> photos;
  final List<Principle> principles;
  final List<HandbookRule> rules;
  final List<Vehicle> vehicles;
  final List<Platform> platforms;
  final List<AttachmentType> attachments;

  const ReferenceLinker({
    required this.photos,
    required this.principles,
    required this.rules,
    required this.vehicles,
    required this.platforms,
    required this.attachments,
  });

  List<HandbookPhoto> photosFor(String referenceId) =>
      photos.where((p) => p.referenceId == referenceId).toList();

  List<Principle> principlesFor(String referenceId) =>
      principles.where((p) => p.handbookReferenceId == referenceId).toList();

  List<HandbookRule> rulesFor(String referenceId) =>
      rules.where((r) => r.referenceId == referenceId).toList();

  List<Vehicle> vehiclesFor(String referenceId) =>
      vehicles.where((v) => v.referenceId == referenceId).toList();

  List<Platform> platformsFor(String referenceId) =>
      platforms.where((p) => p.referenceId == referenceId).toList();

  List<AttachmentType> attachmentsFor(String referenceId) =>
      attachments.where((a) => a.referenceId == referenceId).toList();

  /// Deduplicated photos related to any of the given reference ids, in the
  /// order those ids were supplied — the caller's order carries meaning (a
  /// hardware id's own citation first, then the extra ones), and this used to
  /// return them in `photos.json` order instead, quietly ignoring it.
  List<HandbookPhoto> photosForAny(Iterable<String> referenceIds) {
    final seenPhotoIds = <String>{};
    final result = <HandbookPhoto>[];
    for (final referenceId in referenceIds) {
      for (final photo in photos) {
        if (photo.referenceId == referenceId && seenPhotoIds.add(photo.id)) {
          result.add(photo);
        }
      }
    }
    return result;
  }
}
