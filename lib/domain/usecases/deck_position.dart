import '../models/schematic_element.dart';

/// Where along the deck a placement stands, read straight off the diagram the
/// drawn views use.
///
/// Every view of the same wagon — the elevation, the plan, the photographic
/// scene and the three-dimensional one — takes its position from here, so
/// they cannot disagree about where the trainee put the machine. `fraction`
/// is 0.0 hard against the left end of the deck and 1.0 hard against the
/// right; `travel` is the span that fraction is measured over, in the
/// diagram's own units, which is what a view has to multiply by to move the
/// vehicle by a given fraction.
({double fraction, double travel}) deckPositionOf(
  SchematicDiagram diagram,
  String placementId,
) {
  double? left, right, deckLeft, deckRight;
  for (final element in diagram.elements) {
    if (element.points.isEmpty) continue;
    final xs = element.points.map((p) => p.dx);
    if (element.kind == SchematicElementKind.platformDeck) {
      deckLeft = xs.reduce((a, b) => a < b ? a : b);
      deckRight = xs.reduce((a, b) => a > b ? a : b);
    } else if (element.kind == SchematicElementKind.vehicleBody &&
        element.placementId == placementId) {
      left = xs.reduce((a, b) => a < b ? a : b);
      right = xs.reduce((a, b) => a > b ? a : b);
    }
  }
  if (left == null || right == null || deckLeft == null || deckRight == null) {
    return (fraction: 0.5, travel: 0);
  }
  final travel = (deckRight - deckLeft) - (right - left);
  if (travel <= 0) return (fraction: 0.5, travel: 0);
  return (fraction: ((left - deckLeft) / travel).clamp(0.0, 1.0), travel: travel);
}
