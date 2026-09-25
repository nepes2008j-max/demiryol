import '../../data/models/vehicle.dart';
import '../models/securing_placement.dart';
import 'securing_method_resolution.dart';

/// Reads the securing decisions back out of what the trainee actually put on
/// the wagon.
///
/// Step 4 is a placement exercise: the trainee seats stop blocks against the
/// running gear, runs wire lashings to the deck rings, bolts spurs down. Every
/// one of those acts states something the securing step used to ask about
/// again in words — which hardware, at which size, under which approved
/// method. Asking twice made one decision produce two records that could
/// disagree, and it read as the application not having noticed what the
/// trainee had just done.
///
/// Nothing here decides anything on the trainee's behalf. A piece that was
/// never placed produces no answer, and an empty layout produces none at all;
/// the securing screen still asks about whatever the layout leaves open.

/// The attachment id a placed piece counts as, or null for a piece the
/// equipment list has no slot for.
///
/// [SecuringPieceKind.woodInsert] and [SecuringPieceKind.woodSideBlock] are
/// deliberately absent: the plates draw them as part of an arrangement rather
/// than as separately issued hardware, and `attachments.json` has no record
/// for either, so neither can answer an equipment slot.
String? attachmentIdForPieceKind(SecuringPieceKind kind, Vehicle vehicle) {
  switch (kind) {
    case SecuringPieceKind.woodChock:
      return 'att-wood-chock';
    case SecuringPieceKind.woodPacking:
      return 'att-wood-packing';
    case SecuringPieceKind.staple:
      return 'att-staple';
    case SecuringPieceKind.ironSpur:
      return 'att-iron-spur';
    case SecuringPieceKind.ironChockBoot:
      return 'att-iron-chock-boot';
    case SecuringPieceKind.wireLashing:
      return 'att-wire-lashing';
    case SecuringPieceKind.ironChock:
      // Which KGUUB variant a placed reusable chock is depends on the weight
      // bracket, exactly as method 1 resolves it. With no recorded weight the
      // bracket cannot be named, and naming one anyway would be inventing the
      // figure the whole method turns on.
      final weight = vehicle.bracketWeightT.asDouble;
      if (weight == null) return null;
      if (weight >= 7.0 && weight <= 25.0) return 'att-kguub-1g';
      if (weight > 25.0 && weight <= 42.0) return 'att-kguub-2g';
      return null;
    case SecuringPieceKind.woodInsert:
    case SecuringPieceKind.woodSideBlock:
      return null;
  }
}

/// The equipment selections the layout already answers: attachment id to the
/// handbook row the trainee picked the piece from.
///
/// A piece carrying no [SecuringPiece.sizeTypeCode] answers nothing — it was
/// placed without a stated size, and reporting a size for it would be a figure
/// about nothing. Where two pieces of one kind disagree, the first placed
/// wins; the trainee is still free to change the answer on the securing
/// screen.
Map<String, String> equipmentAnsweredByLayout(
  SecuringLayout layout,
  Vehicle vehicle,
) {
  final answers = <String, String>{};
  for (final piece in layout.pieces) {
    final code = piece.sizeTypeCode;
    if (code == null) continue;
    final id = attachmentIdForPieceKind(piece.kind, vehicle);
    if (id == null) continue;
    answers.putIfAbsent(id, () => code);
  }
  return answers;
}

/// The approved securing method the placed pieces amount to, or null when they
/// do not amount to exactly one.
///
/// A method is answered only when the layout carries every hardware id that
/// method calls for and no hardware belonging to a different method. Placing
/// wood stop-blocks alone matches both method 3 and method 5 — the trainee has
/// not yet said which, so this returns null and the securing screen still
/// asks. Placing blocks *and* lashings says method 3 and nothing else.
int? methodAnsweredByLayout(SecuringLayout layout, Vehicle vehicle) {
  if (layout.isEmpty) return null;

  final placed = <String>{};
  for (final piece in layout.pieces) {
    final id = attachmentIdForPieceKind(piece.kind, vehicle);
    if (id != null) placed.add(id);
  }
  if (placed.isEmpty) return null;

  // Staples and nails fix other pieces down rather than standing for a method
  // of their own, so they neither satisfy nor contradict one.
  const incidental = {'att-staple', 'att-nail'};
  final significant = placed.difference(incidental);
  if (significant.isEmpty) return null;

  final matches = <int>[];
  for (var method = 1; method <= 6; method++) {
    final required = hardwareIdsForSecuringMethod(method, vehicle).toSet();
    if (required.isEmpty) continue;
    if (required.containsAll(significant) && significant.containsAll(required)) {
      matches.add(method);
    }
  }
  return matches.length == 1 ? matches.first : null;
}

/// Which of [requiredHardwareIds] the layout has not answered — what the
/// securing screen still has to ask about.
List<String> equipmentStillUnanswered({
  required List<String> requiredHardwareIds,
  required Map<String, String> answered,
}) =>
    [
      for (final id in requiredHardwareIds)
        if (!answered.containsKey(id)) id,
    ];
