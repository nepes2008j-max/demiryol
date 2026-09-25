import '../../data/models/attachment_type.dart';
import '../../data/models/handbook_photo.dart';
import '../../data/models/handbook_reference.dart';
import '../../data/models/handbook_rule.dart';
import '../../data/models/platform.dart';
import '../../data/models/principle.dart';
import '../../data/models/vehicle.dart';

/// Plain case-insensitive substring match across the given fields — no
/// fuzzy/approximate matching, so a search hit always corresponds to text
/// that is literally present in the extracted data.
bool matchesSearch(String query, Iterable<String?> fields) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return true;
  return fields.any((f) => f != null && f.toLowerCase().contains(q));
}

List<HandbookPhoto> filterPhotos(List<HandbookPhoto> items, String query) => items
    .where((p) => matchesSearch(query, [p.figureNumber, p.caption, p.captionTk, p.id]))
    .toList();

List<Vehicle> filterVehicles(List<Vehicle> items, String query) => items
    // classDisplayTk is included for the same reason the principle and rule
    // filters include their Turkmen fields: the interface is in Turkmen, so a
    // Turkmen search term has to match what the user can actually read.
    .where((v) => matchesSearch(
        query, [v.handbookDesignation, v.id, v.vehicleClass, v.classDisplayTk, v.notes, v.notesTk]))
    .toList();

List<Platform> filterPlatforms(List<Platform> items, String query) => items
    .where((p) => matchesSearch(query, [p.name, p.id, p.notes, p.notesTk]))
    .toList();

List<AttachmentType> filterAttachments(List<AttachmentType> items, String query) =>
    items.where((a) => matchesSearch(query, [a.name, a.id])).toList();

List<Principle> filterPrinciples(List<Principle> items, String query) =>
    items.where((p) => matchesSearch(query, [p.title, p.titleTk, p.id])).toList();

List<HandbookRule> filterRules(List<HandbookRule> items, String query) => items
    .where((r) =>
        matchesSearch(query, [r.displayTitle, r.description, r.descriptionTk, r.id]))
    .toList();

List<HandbookReference> filterReferences(List<HandbookReference> items, String query) => items
    .where((r) =>
        matchesSearch(query, [r.id, r.paragraph, r.table, r.plate, r.summary, r.summaryTk]))
    .toList();
