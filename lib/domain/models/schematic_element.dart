/// What a [SchematicElement] represents on the securing schematic.
///
/// Kept as a closed enum (rather than a free-text "type" string) so the
/// presentation-layer painter can switch on it exhaustively without any
/// engineering interpretation of its own — see [SchematicElement]'s
/// class doc for the data → domain → presentation split this enforces.
enum SchematicElementKind {
  platformDeck,
  vehicleBody,
  trackRun,
  wheelRun,
  railDirection,
  symmetryAxis,
  ironSpurPair,
  ironChockBootPair,
  reusableChockPair,
  woodChockPair,
  spacerBoard,
  wireLashing,
  attachmentPoint,
}

/// A point in the schematic's normalized 0.0–1.0 layout space. This is
/// NEVER a centimeter coordinate — it exists purely so the diagram reads
/// clearly, and callers must not treat it as measured geometry.
class SchematicPoint {
  final double dx;
  final double dy;

  const SchematicPoint(this.dx, this.dy);

  SchematicPoint operator +(SchematicPoint other) => SchematicPoint(dx + other.dx, dy + other.dy);

  @override
  bool operator ==(Object other) =>
      other is SchematicPoint && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);
}

/// One drawable element of the securing schematic, produced by
/// [SchematicBuilder] (domain/usecases) from already-loaded handbook data.
/// [SecuringSchematicPainter] (presentation) only ever reads these fields —
/// it performs no lookups, no data interpretation, and no engineering
/// decisions of its own.
///
/// The two booleans are independent and both matter:
/// - [isPositionHandbookSupported]: the *qualitative relationship* this
///   element depicts (e.g. "centered on the platform's axis", "a chock
///   pair sits ahead of the second-from-last road wheel") is explicitly
///   stated in the extracted handbook text. This is about the RELATIONSHIP,
///   not the pixel.
/// - [isGeometrySchematic]: the actual shape/size/coordinates drawn are
///   illustrative only, because the handbook extract has no numeric
///   dimensions for this vehicle/platform. This is true for essentially
///   every element today, since no vehicle or platform in the current
///   dataset has real length/width — see [SchematicDiagram.isFullyToScale].
class SchematicElement {
  final SchematicElementKind kind;
  final String label;
  final String sourceEntityId;
  final List<SchematicPoint> points;
  final bool isPositionHandbookSupported;
  final bool isGeometrySchematic;
  final List<String> relatedReferenceIds;

  /// True when this element depicts a user-applied equipment selection that
  /// `equipment_selection.dart`'s `checkEquipmentSelection` has determined
  /// does NOT match the handbook-mandated type for this vehicle. Computed
  /// by [SchematicBuilder] from that same pure comparison — never decided
  /// by the painter, which only changes how a mismatched element is drawn
  /// (e.g. a warning treatment), not whether it counts as one.
  final bool isSelectionMismatch;

  /// Which placed vehicle this element belongs to, when the diagram shows a
  /// whole consist. Null for the single-vehicle diagram, and null for the
  /// wagon itself (deck, rails, symmetry axis) even in a consist — those
  /// belong to the platform, not to any one vehicle.
  ///
  /// [sourceEntityId] cannot serve this purpose: two copies of the same
  /// designation on one wagon share a vehicle id, so tapping one would be
  /// indistinguishable from tapping the other.
  final String? placementId;

  const SchematicElement({
    required this.kind,
    required this.label,
    required this.sourceEntityId,
    required this.points,
    required this.isPositionHandbookSupported,
    required this.isGeometrySchematic,
    this.relatedReferenceIds = const [],
    this.isSelectionMismatch = false,
    this.placementId,
  });

  /// A copy of this element with every point mapped through [mapPoint] and
  /// tagged as belonging to [placementId]. Used to lay one vehicle's
  /// elements into its slot on a multi-vehicle wagon without duplicating any
  /// of the construction logic.
  SchematicElement mappedInto(
    String placementId,
    SchematicPoint Function(SchematicPoint) mapPoint,
  ) =>
      SchematicElement(
        kind: kind,
        label: label,
        sourceEntityId: sourceEntityId,
        points: points.map(mapPoint).toList(),
        isPositionHandbookSupported: isPositionHandbookSupported,
        isGeometrySchematic: isGeometrySchematic,
        relatedReferenceIds: relatedReferenceIds,
        isSelectionMismatch: isSelectionMismatch,
        placementId: placementId,
      );
}

/// The full set of elements for one vehicle+platform securing schematic.
class SchematicDiagram {
  final List<SchematicElement> elements;

  const SchematicDiagram({required this.elements});

  /// True only if every element's geometry is drawn from real handbook
  /// measurements. With the current handbook extract (no vehicle or
  /// platform has real length/width), this is always false — the UI must
  /// show the "SCHEMATIC — NOT TO SCALE" banner whenever this is false.
  bool get isFullyToScale => elements.isNotEmpty && elements.every((e) => !e.isGeometrySchematic);

  List<SchematicElement> elementsOfKind(SchematicElementKind kind) =>
      elements.where((e) => e.kind == kind).toList();

  /// Everything belonging to one placed vehicle — its body, run indicator and
  /// securing hardware — excluding the wagon it stands on.
  List<SchematicElement> elementsForPlacement(String placementId) =>
      elements.where((e) => e.placementId == placementId).toList();

  /// The distinct placements drawn, in the order they first appear.
  List<String> get placementIds {
    final seen = <String>[];
    for (final e in elements) {
      final id = e.placementId;
      if (id != null && !seen.contains(id)) seen.add(id);
    }
    return seen;
  }
}
