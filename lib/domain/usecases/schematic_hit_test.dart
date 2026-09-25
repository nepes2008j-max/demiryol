import '../models/schematic_element.dart';

/// Component kinds a user can tap on the schematic to inspect. Pure
/// drawing conventions (rail direction lines, the symmetry axis,
/// track/wheel run markers, wire-lashing attachment-point dots) are
/// excluded — they annotate the drawing but are not a configurable
/// component the way a vehicle, hardware pair, or lashing line is.
const inspectableSchematicKinds = {
  SchematicElementKind.platformDeck,
  SchematicElementKind.vehicleBody,
  SchematicElementKind.ironSpurPair,
  SchematicElementKind.ironChockBootPair,
  SchematicElementKind.reusableChockPair,
  SchematicElementKind.woodChockPair,
  SchematicElementKind.spacerBoard,
  SchematicElementKind.wireLashing,
};

/// Kinds whose two points really are opposite corners of a rectangle.
///
/// A hardware pair is NOT one of them: `_pairElements` gives it two points at
/// the same x (the near and far side of the vehicle), so treating those as a
/// rectangle produces a zero-width hit box that a tap can never land in.
/// `spacerBoard` was in this set and was therefore the one hardware kind that
/// could not be inspected at all.
const _rectKinds = {
  SchematicElementKind.platformDeck,
  SchematicElementKind.vehicleBody,
};

double _squaredDistanceToSegment(
  double px,
  double py,
  double ax,
  double ay,
  double bx,
  double by,
) {
  final dx = bx - ax;
  final dy = by - ay;
  final lengthSquared = dx * dx + dy * dy;
  final t = lengthSquared == 0
      ? 0.0
      : (((px - ax) * dx + (py - ay) * dy) / lengthSquared).clamp(0.0, 1.0);
  final closestX = ax + t * dx;
  final closestY = ay + t * dy;
  final ddx = px - closestX;
  final ddy = py - closestY;
  return ddx * ddx + ddy * ddy;
}

/// Finds the topmost (last-drawn, so hardware over the vehicle body over
/// the platform deck) inspectable element whose drawn geometry is under
/// the tap point — in the same normalized 0.0-1.0 layout space
/// `SchematicBuilder`/`SecuringSchematicPainter` already use, never a real
/// coordinate. [hitRadius] is normalized too, so the hit area scales with
/// the canvas exactly like the drawing itself. Returns null when nothing
/// inspectable is under the tap.
SchematicElement? hitTestSchematicElement(
  List<SchematicElement> elements,
  double tapDx,
  double tapDy, {
  double hitRadius = 0.035,
}) {
  for (final e in elements.reversed) {
    if (!inspectableSchematicKinds.contains(e.kind) || e.points.isEmpty) continue;

    if (_rectKinds.contains(e.kind) && e.points.length >= 2) {
      final left = e.points[0].dx < e.points[1].dx ? e.points[0].dx : e.points[1].dx;
      final right = e.points[0].dx > e.points[1].dx ? e.points[0].dx : e.points[1].dx;
      final top = e.points[0].dy < e.points[1].dy ? e.points[0].dy : e.points[1].dy;
      final bottom = e.points[0].dy > e.points[1].dy ? e.points[0].dy : e.points[1].dy;
      if (tapDx >= left && tapDx <= right && tapDy >= top && tapDy <= bottom) return e;
      continue;
    }

    final a = e.points.first;
    final b = e.points.length > 1 ? e.points[1] : a;
    final distanceSquared = _squaredDistanceToSegment(tapDx, tapDy, a.dx, a.dy, b.dx, b.dy);
    if (distanceSquared <= hitRadius * hitRadius) return e;
  }
  return null;
}
