import '../../core/localization/app_strings.dart';
import '../../data/models/attachment_type.dart';
import '../../data/models/platform.dart';
import '../../data/models/vehicle.dart';
import '../models/chock_arrangement.dart';
import '../models/schematic_element.dart';
import 'chock_layout.dart';
import 'equipment_selection.dart';
import 'wire_lashing_rule.dart';
import 'wood_chock_sizing.dart';

/// Normalized (0.0–1.0) layout constants for the securing schematic. These
/// are illustrative layout choices for legibility only — never derived
/// from, or claiming to be, real handbook measurements. Every element built
/// from them carries `isGeometrySchematic: true` for exactly that reason.
/// Where a wheeled vehicle's tyres are drawn when the record does not say how
/// many axles it has. Shared by the run indicator and the chock layout, so a
/// chock is always seated against a wheel that is actually on the drawing.
const _wheelXs = [0.36, 0.46, 0.56, 0.66];

class _Layout {
  static const platformLeft = 0.06, platformTop = 0.30, platformRight = 0.94, platformBottom = 0.70;
  static const vehicleLeft = 0.30, vehicleTop = 0.40, vehicleRight = 0.70, vehicleBottom = 0.60;
  static const railTopY = 0.34, railBottomY = 0.66;
  static const symmetryY = 0.5;

  // How far the vehicle body may move (schematically) from its centered
  // position before it would leave the platform deck's drawn bounds.
  static const maxOffsetDx = vehicleLeft - platformLeft; // == platformRight - vehicleRight
  static const maxOffsetDy = vehicleTop - platformTop; // == platformBottom - vehicleBottom
}

/// One vehicle's worth of input to [SchematicBuilder.buildConsist]: which
/// vehicle, which placement it is, where the user dragged it, and the
/// hardware resolved and selected for that placement specifically.
///
/// Everything here is per placement rather than per vehicle designation,
/// because two copies of the same vehicle on one wagon are secured
/// independently and may have different equipment selections applied.
class ConsistPlacement {
  final String placementId;
  final Vehicle vehicle;
  final List<String> requiredHardwareIds;
  final Map<String, String> selectedHardwareTypes;
  final SchematicPoint offset;

  /// The chock layout case the trainee chose for this placement, or null
  /// while nothing has been chosen. Per placement for the same reason the
  /// equipment picks are: two copies of one designation on a wagon are
  /// secured independently.
  final ChockArrangement? chockArrangement;

  const ConsistPlacement({
    required this.placementId,
    required this.vehicle,
    this.requiredHardwareIds = const [],
    this.selectedHardwareTypes = const {},
    this.offset = const SchematicPoint(0, 0),
    this.chockArrangement,
  });
}

/// Builds a [SchematicDiagram] for one vehicle+platform+resolved-hardware
/// combination, using only relationships already present in the extracted
/// handbook data (vehicle/platform/attachment records and their reference
/// ids). This is the ONLY place that decides what the schematic shows —
/// [SecuringSchematicPainter] just draws whatever elements come out of here.
class SchematicBuilder {
  const SchematicBuilder._();

  /// Builds the diagram. [vehicleOffset] is a purely schematic drag offset
  /// (normalized, clamped via [clampVehicleOffset]) applied to the vehicle
  /// body and everything mounted on it (track/wheel run, hardware pairs,
  /// the vehicle-side end of wire lashings). The platform deck, rails, and
  /// symmetry axis never move — they represent the platform, not the
  /// vehicle. This offset is a rendering concern only: it is never passed
  /// to, or derived from, EngineeringValidator.
  /// [selectedHardwareTypes] is an optional user-selected type/size override
  /// per hardware id (e.g. `{'att-iron-spur': 'Ş-303'}`), set via the
  /// Required Equipment panel. When present for a hardware id, it replaces
  /// that hardware's label on the drawing — including when it does NOT
  /// match the vehicle's handbook-mandated type, so the user can see
  /// exactly what they picked. It never changes engineering validation:
  /// whether the selection is correct is decided separately by
  /// `equipment_selection.dart`, never inferred here.
  /// [measurements] (`measurements.json`, raw) and [rules] (`rules.json`,
  /// raw) are optional — when supplied they let the wood-chock element show
  /// its real Table 3 dimensions and the wire-lashing element draw the
  /// actual required number of connections (Table/para. 55) instead of a
  /// fixed default. Omitting them only reduces detail; it never causes a
  /// fabricated value to appear.
  static SchematicDiagram build({
    required Vehicle vehicle,
    required Platform platform,
    required List<String> requiredHardwareIds,
    required List<AttachmentType> attachments,
    SchematicPoint vehicleOffset = const SchematicPoint(0, 0),
    Map<String, String> selectedHardwareTypes = const {},
    Map<String, dynamic>? measurements,
    Map<String, dynamic>? rules,
    ChockArrangement? chockArrangement,
  }) {
    final offset = clampVehicleOffset(vehicleOffset);
    final elements = <SchematicElement>[
      _platformDeck(platform),
      _vehicleBody(vehicle, offset),
      ..._railDirection(),
      _symmetryAxis(),
      ..._runIndicator(vehicle, offset),
      ..._hardwareElements(
        vehicle,
        requiredHardwareIds,
        attachments,
        offset,
        selectedHardwareTypes,
        measurements,
        rules,
        chockArrangement,
      ),
    ];
    return SchematicDiagram(elements: elements);
  }

  /// Builds one wagon carrying several vehicles — the step-4 case where the
  /// user puts, say, two vehicles on one flatcar.
  ///
  /// Each vehicle's elements are constructed by exactly the same code
  /// [build] uses, then mapped into a horizontal slot on the deck by
  /// [slotMapper]. Nothing about what a vehicle's securing hardware IS
  /// changes with how many vehicles share the wagon — only where it is
  /// drawn — so there is deliberately no second copy of the element-building
  /// logic here to drift out of step with the single-vehicle one.
  ///
  /// The wagon's own elements (deck, rails, symmetry axis) are emitted once
  /// and carry no `placementId`: they belong to the platform, not to any
  /// vehicle on it.
  ///
  /// As in [build], every offset remains a rendering concern. Which vehicles
  /// share a wagon, and whether one spans a coupling, is carried by
  /// `TrainConsist`; it is never inferred from these coordinates.
  static SchematicDiagram buildConsist({
    required Platform platform,
    required List<ConsistPlacement> placements,
    required List<AttachmentType> attachments,
    Map<String, dynamic>? measurements,
    Map<String, dynamic>? rules,
  }) {
    final elements = <SchematicElement>[
      _platformDeck(platform),
      ..._railDirection(),
      _symmetryAxis(),
    ];

    final count = placements.length;
    for (var i = 0; i < count; i++) {
      final placement = placements[i];
      final offset = clampVehicleOffset(placement.offset);
      final mapPoint = slotMapper(slotIndex: i, slotCount: count);
      final vehicleElements = <SchematicElement>[
        _vehicleBody(placement.vehicle, offset),
        ..._runIndicator(placement.vehicle, offset),
        ..._hardwareElements(
          placement.vehicle,
          placement.requiredHardwareIds,
          attachments,
          offset,
          placement.selectedHardwareTypes,
          measurements,
          rules,
          placement.chockArrangement,
        ),
      ];
      for (final element in vehicleElements) {
        elements.add(element.mappedInto(placement.placementId, mapPoint));
      }
    }

    return SchematicDiagram(elements: elements);
  }

  /// Maps a point from the canonical single-vehicle layout into slot
  /// [slotIndex] of [slotCount] across the platform deck.
  ///
  /// The deck spans `platformLeft..platformRight`. A point's position is
  /// taken as a fraction of that span and re-placed into the slot's share of
  /// it, so one vehicle is the identity mapping and two vehicles sit side by
  /// side at half width. Only x is affected — vertical placement on the deck
  /// does not depend on how many vehicles share the wagon.
  static SchematicPoint Function(SchematicPoint) slotMapper({
    required int slotIndex,
    required int slotCount,
  }) {
    if (slotCount <= 1) return (p) => p;
    const left = _Layout.platformLeft;
    const span = _Layout.platformRight - _Layout.platformLeft;
    return (p) {
      final fraction = (p.dx - left) / span;
      final inSlot = (slotIndex + fraction) / slotCount;
      return SchematicPoint(left + inSlot * span, p.dy);
    };
  }

  /// Clamps a proposed vehicle drag offset so the vehicle body stays fully
  /// within the platform deck's schematic bounds. This is a layout
  /// constraint on the drawing only — it has no relationship to any real
  /// physical clearance, and is never presented as one.
  static SchematicPoint clampVehicleOffset(SchematicPoint proposed) {
    final dx = proposed.dx.clamp(-_Layout.maxOffsetDx, _Layout.maxOffsetDx);
    final dy = proposed.dy.clamp(-_Layout.maxOffsetDy, _Layout.maxOffsetDy);
    return SchematicPoint(dx, dy);
  }

  static SchematicElement _platformDeck(Platform platform) => SchematicElement(
        kind: SchematicElementKind.platformDeck,
        label: platform.name,
        sourceEntityId: platform.id,
        points: const [
          SchematicPoint(_Layout.platformLeft, _Layout.platformTop),
          SchematicPoint(_Layout.platformRight, _Layout.platformBottom),
        ],
        isPositionHandbookSupported: false,
        isGeometrySchematic: true,
        relatedReferenceIds: [platform.referenceId],
      );

  static SchematicElement _vehicleBody(Vehicle vehicle, SchematicPoint offset) => SchematicElement(
        kind: SchematicElementKind.vehicleBody,
        label: vehicle.handbookDesignation,
        sourceEntityId: vehicle.id,
        points: [
          const SchematicPoint(_Layout.vehicleLeft, _Layout.vehicleTop) + offset,
          const SchematicPoint(_Layout.vehicleRight, _Layout.vehicleBottom) + offset,
        ],
        // The vehicle's CENTERING is explicitly required by the handbook
        // (principle-symmetry, para. 34) — only the exact box drawn is
        // schematic, not the "centered on the axis" relationship itself.
        // Dragging the vehicle away from center in this view does not
        // change that requirement; it only changes what's drawn.
        isPositionHandbookSupported: true,
        isGeometrySchematic: true,
        relatedReferenceIds: const ['para-34'],
      );

  static List<SchematicElement> _railDirection() => const [
        SchematicElement(
          kind: SchematicElementKind.railDirection,
          label: '',
          sourceEntityId: 'schematic-convention',
          points: [SchematicPoint(0.0, _Layout.railTopY), SchematicPoint(1.0, _Layout.railTopY)],
          isPositionHandbookSupported: false,
          isGeometrySchematic: true,
        ),
        SchematicElement(
          kind: SchematicElementKind.railDirection,
          label: '',
          sourceEntityId: 'schematic-convention',
          points: [SchematicPoint(0.0, _Layout.railBottomY), SchematicPoint(1.0, _Layout.railBottomY)],
          isPositionHandbookSupported: false,
          isGeometrySchematic: true,
        ),
      ];

  static SchematicElement _symmetryAxis() => const SchematicElement(
        kind: SchematicElementKind.symmetryAxis,
        label: AppStrings.schematicSymmetryAxisLabel,
        sourceEntityId: 'principle-symmetry',
        points: [
          SchematicPoint(_Layout.platformLeft, _Layout.symmetryY),
          SchematicPoint(_Layout.platformRight, _Layout.symmetryY),
        ],
        isPositionHandbookSupported: true,
        isGeometrySchematic: true,
        relatedReferenceIds: ['para-34'],
      );

  /// Where the vehicle's running gear meets the deck, in the same normalized
  /// x space [_runIndicator] uses — the tyres of a wheeled vehicle, the two
  /// ends of a tracked one's track. The chocks are seated against these.
  static List<double> _runPositionsFor(Vehicle vehicle) {
    if (vehicle.category == VehicleCategory.wheeled) return _wheelXsFor(vehicle);
    return const [_Layout.vehicleLeft, _Layout.vehicleRight];
  }

  /// One x per axle when the record states an axle count, so a three-axle
  /// lorry is drawn on three axles — the layout case the trainee picked says
  /// "3 okly", and a drawing showing four wheels would contradict it. Falls
  /// back to the generic four positions when the count is unknown, which it is
  /// for every handbook-extracted vehicle.
  static List<double> _wheelXsFor(Vehicle vehicle) {
    final axles = vehicle.axleCount;
    if (axles == null || axles < 1) return _wheelXs;
    const left = _Layout.vehicleLeft + 0.06;
    const right = _Layout.vehicleRight - 0.04;
    if (axles == 1) return const [(left + right) / 2];
    final step = (right - left) / (axles - 1);
    return [for (var i = 0; i < axles; i++) left + step * i];
  }

  /// Track-contact strips for tracked vehicles, or wheel markers for
  /// wheeled ones — generic run indicators, not measured contact patches.
  static List<SchematicElement> _runIndicator(Vehicle vehicle, SchematicPoint offset) {
    if (vehicle.category == VehicleCategory.tracked) {
      return [
        SchematicElement(
          kind: SchematicElementKind.trackRun,
          label: AppStrings.schematicTrackRunLabel,
          sourceEntityId: vehicle.id,
          points: [
            const SchematicPoint(_Layout.vehicleLeft, _Layout.vehicleTop + 0.02) + offset,
            const SchematicPoint(_Layout.vehicleRight, _Layout.vehicleTop + 0.02) + offset,
          ],
          isPositionHandbookSupported: false,
          isGeometrySchematic: true,
        ),
        SchematicElement(
          kind: SchematicElementKind.trackRun,
          label: AppStrings.schematicTrackRunLabel,
          sourceEntityId: vehicle.id,
          points: [
            const SchematicPoint(_Layout.vehicleLeft, _Layout.vehicleBottom - 0.02) + offset,
            const SchematicPoint(_Layout.vehicleRight, _Layout.vehicleBottom - 0.02) + offset,
          ],
          isPositionHandbookSupported: false,
          isGeometrySchematic: true,
        ),
      ];
    }
    if (vehicle.category == VehicleCategory.wheeled) {
      final xs = _wheelXsFor(vehicle);
      return xs
          .map((x) => SchematicElement(
                kind: SchematicElementKind.wheelRun,
                label: AppStrings.schematicWheelRunLabel,
                sourceEntityId: vehicle.id,
                points: [SchematicPoint(x, _Layout.vehicleBottom) + offset],
                isPositionHandbookSupported: false,
                isGeometrySchematic: true,
              ))
          .toList();
    }
    return const [];
  }

  static List<SchematicElement> _hardwareElements(
    Vehicle vehicle,
    List<String> requiredHardwareIds,
    List<AttachmentType> attachments,
    SchematicPoint offset,
    Map<String, String> selectedHardwareTypes,
    Map<String, dynamic>? measurements,
    Map<String, dynamic>? rules,
    ChockArrangement? chockArrangement,
  ) {
    final elements = <SchematicElement>[];

    if (requiredHardwareIds.contains('att-iron-spur')) {
      const id = 'att-iron-spur';
      final selected = selectedHardwareTypes[id];
      final required = requiredTypeCodeFor(id, vehicle);
      final typeCode = selected ?? vehicle.ironSpurType;
      elements.addAll(_pairElements(
        kind: SchematicElementKind.ironSpurPair,
        sourceEntityId: id,
        baseLabel: _hardwareLabel(attachments, id, typeCode),
        referenceIds: const ['para-31'],
        xFractions: const [0.40, 0.60],
        isPositionHandbookSupported: false,
        offset: offset,
        isSelectionMismatch: selected != null && required != null && selected != required,
      ));
    }

    if (requiredHardwareIds.contains('att-iron-chock-boot')) {
      const id = 'att-iron-chock-boot';
      final selected = selectedHardwareTypes[id];
      final required = requiredTypeCodeFor(id, vehicle);
      final typeCode = selected ?? vehicle.ironChockBootType;
      elements.addAll(_pairElements(
        kind: SchematicElementKind.ironChockBootPair,
        sourceEntityId: id,
        baseLabel: _hardwareLabel(attachments, id, typeCode),
        referenceIds: const ['para-32'],
        xFractions: const [0.40, 0.60],
        isPositionHandbookSupported: false,
        offset: offset,
        isSelectionMismatch: selected != null && required != null && selected != required,
      ));
    }

    final kguubId = requiredHardwareIds.contains('att-kguub-1g')
        ? 'att-kguub-1g'
        : (requiredHardwareIds.contains('att-kguub-2g') ? 'att-kguub-2g' : null);
    if (kguubId != null) {
      final selected = selectedHardwareTypes[kguubId];
      final required = requiredTypeCodeFor(kguubId, vehicle);
      elements.addAll(_pairElements(
        kind: SchematicElementKind.reusableChockPair,
        sourceEntityId: kguubId,
        baseLabel: _hardwareLabel(attachments, kguubId, selected),
        // Placement (near the last road wheel, two pairs with a minimum
        // separation) is explicit handbook text — principle-chock-placement
        // (para. 36) and the minimum-spacing rule (para. 38).
        referenceIds: const ['para-29', 'para-36'],
        xFractions: const [0.58, 0.66],
        isPositionHandbookSupported: true,
        offset: offset,
        isSelectionMismatch: selected != null && required != null && selected != required,
      ));
    }

    // Wood stop-block (Table 3, para. 21). Every weight bracket is a real
    // selectable option in the Required Equipment panel (like iron
    // spurs/chock-boots/KGUUB); the selected bracket's own dimensions are
    // drawn even when it doesn't match the vehicle's own weight, so a
    // wrong pick is still visible, not silently corrected. Para. 21's own
    // text ("long edge... against the wheel/track") is an explicit
    // positional relationship, so this element is marked
    // handbook-supported even though its drawn size is schematic when no
    // dimension can be resolved at all.
    if (requiredHardwareIds.contains('att-wood-chock')) {
      final selected = selectedHardwareTypes['att-wood-chock'];
      final required =
          measurements == null ? null : requiredTypeCodeFor('att-wood-chock', vehicle, measurements: measurements);
      ({int heightMm, int widthMm})? dims;
      if (measurements != null) {
        if (selected != null) {
          final range = selected.endsWith(' t') ? selected.substring(0, selected.length - 2) : selected;
          dims = woodChockDimensionsForRange(range, measurements);
        } else if (vehicle.bracketWeightT.isAvailable) {
          dims = resolveWoodChockDimensions(vehicle.bracketWeightT.asDouble!, measurements);
        }
      }
      final label = dims == null
          ? _hardwareLabel(attachments, 'att-wood-chock', null)
          : '${_hardwareLabel(attachments, 'att-wood-chock', null)} — ${dims.heightMm}×${dims.widthMm} mm';
      // How many chocks and where they sit comes from the arrangement the
      // trainee chose (plate-02 for tracked, plate-06 for wheeled). With no
      // arrangement chosen yet the drawing falls back to one pair at each end
      // of the vehicle, which is what it always drew.
      // Seat them against the vehicle's own run indicators — the tyres of a
      // wheeled vehicle, the ends of a tracked one's track — which the
      // diagram has already placed.
      final runXs = _runPositionsFor(vehicle);
      final chockXs = chockArrangement == null
          ? const [_Layout.vehicleLeft + 0.06, _Layout.vehicleRight - 0.06]
          : ChockLayout.chockPairPositions(
              chockArrangement,
              vehicleLeft: _Layout.vehicleLeft,
              vehicleRight: _Layout.vehicleRight,
              runPositions: runXs,
            );
      elements.addAll(_pairElements(
        kind: SchematicElementKind.woodChockPair,
        sourceEntityId: 'att-wood-chock',
        baseLabel: chockArrangement == null
            ? label
            : '$label — ${AppStrings.chockArrangementCountLabel(chockArrangement.chockCount, 0)}',
        referenceIds: chockArrangement == null
            ? const ['para-21']
            : ['para-21', chockArrangement.referenceId],
        xFractions: chockXs,
        isPositionHandbookSupported: true,
        offset: offset,
        isSelectionMismatch: selected != null && required != null && selected != required,
      ));

      // The transverse half-round insert blocks the tracked plate pairs with
      // those chocks — four per vehicle, two per side, the first pair
      // blocking forward movement and the second rearward.
      if (chockArrangement != null && chockArrangement.insertCount > 0) {
        final insertXs = ChockLayout.insertPairPositions(
          chockArrangement,
          vehicleLeft: _Layout.vehicleLeft,
          vehicleRight: _Layout.vehicleRight,
        );
        elements.addAll(_pairElements(
          kind: SchematicElementKind.spacerBoard,
          sourceEntityId: 'att-wood-packing',
          baseLabel: _hardwareLabel(attachments, 'att-wood-packing', null),
          referenceIds: ['para-24', chockArrangement.referenceId],
          xFractions: insertXs,
          isPositionHandbookSupported: true,
          offset: offset,
        ));
      }
    }

    // Spacer/packing board (para. 24) — cumulative with wood chocks under
    // method 5. The handbook gives no positional relationship beyond "runs
    // the width of the cargo," so this stays purely schematic.
    if (requiredHardwareIds.contains('att-wood-packing')) {
      elements.add(SchematicElement(
        kind: SchematicElementKind.spacerBoard,
        label: _hardwareLabel(attachments, 'att-wood-packing', null) ?? 'att-wood-packing',
        sourceEntityId: 'att-wood-packing',
        points: [
          const SchematicPoint(0.38, _Layout.vehicleBottom + 0.03) + offset,
          const SchematicPoint(0.62, _Layout.vehicleBottom + 0.07) + offset,
        ],
        isPositionHandbookSupported: false,
        isGeometrySchematic: true,
        relatedReferenceIds: const ['para-24'],
      ));
    }

    if (requiredHardwareIds.contains('att-wire-lashing')) {
      final count = (vehicle.bracketWeightT.isAvailable && rules != null)
          // `rule-wheeled-lashing-count` (para. 55) is documented as
          // wheeled-only — a tracked vehicle's method 3 also uses wire
          // lashings, but the extract has no tracked-specific count rule,
          // so that case always falls back to the illustrative default
          // rather than reusing an inapplicable wheeled figure.
          ? (vehicle.category == VehicleCategory.wheeled
              ? (requiredWireLashingCount(vehicle.bracketWeightT.asDouble!, rules) ?? 4)
              : 4)
          : 4;
      elements.addAll(_wireLashings(
        attachments,
        offset,
        count,
        selectedHardwareTypes['att-wire-lashing'],
      ));
    }

    return elements;
  }

  static String? _hardwareLabel(List<AttachmentType> attachments, String id, String? typeCode) {
    final matches = attachments.where((a) => a.id == id);
    final name = matches.isEmpty ? null : matches.first.name;
    if (name == null) return typeCode;
    return typeCode == null ? name : '$name — $typeCode';
  }

  static List<SchematicElement> _pairElements({
    required SchematicElementKind kind,
    required String sourceEntityId,
    required String? baseLabel,
    required List<String> referenceIds,
    required List<double> xFractions,
    required bool isPositionHandbookSupported,
    required SchematicPoint offset,
    bool isSelectionMismatch = false,
  }) {
    final elements = <SchematicElement>[];
    for (var i = 0; i < xFractions.length; i++) {
      final x = xFractions[i];
      final pairLabel = AppStrings.schematicPairLabel(i + 1, baseLabel ?? sourceEntityId);
      elements.add(SchematicElement(
        kind: kind,
        label: pairLabel,
        sourceEntityId: sourceEntityId,
        points: [
          SchematicPoint(x, _Layout.vehicleTop) + offset,
          SchematicPoint(x, _Layout.vehicleBottom) + offset,
        ],
        isPositionHandbookSupported: isPositionHandbookSupported,
        isGeometrySchematic: true,
        relatedReferenceIds: referenceIds,
        isSelectionMismatch: isSelectionMismatch,
      ));
    }
    return elements;
  }

  /// Draws [count] vehicle-to-platform connection lines (never a fixed
  /// number regardless of what the rule actually requires) plus one
  /// attachment-point marker per line, spread evenly across the vehicle's
  /// top/bottom edges and the platform's corresponding anchor band. Vehicle
  /// ends move with the vehicle; platform ends are fixed to the deck.
  static List<SchematicElement> _wireLashings(
    List<AttachmentType> attachments,
    SchematicPoint offset,
    int count,
    String? selectedDiameter,
  ) {
    final label = _hardwareLabel(attachments, 'att-wire-lashing', selectedDiameter) ?? 'att-wire-lashing';
    final elements = <SchematicElement>[];
    final topCount = (count / 2).ceil();
    final bottomCount = count - topCount;
    for (var i = 0; i < count; i++) {
      final onTop = i < topCount;
      final rowCount = onTop ? topCount : bottomCount;
      final indexInRow = onTop ? i : i - topCount;
      final t = rowCount <= 1 ? 0.5 : indexInRow / (rowCount - 1);
      final vehicleX = _Layout.vehicleLeft + t * (_Layout.vehicleRight - _Layout.vehicleLeft);
      final platformX = rowCount <= 1 ? 0.5 : 0.16 + t * (0.84 - 0.16);
      final vehiclePoint = SchematicPoint(
            vehicleX,
            onTop ? _Layout.vehicleTop : _Layout.vehicleBottom,
          ) +
          offset;
      final anchor = SchematicPoint(
        platformX,
        onTop ? _Layout.platformTop + 0.02 : _Layout.platformBottom - 0.02,
      );
      elements.add(SchematicElement(
        kind: SchematicElementKind.wireLashing,
        label: label,
        sourceEntityId: 'att-wire-lashing',
        points: [vehiclePoint, anchor],
        isPositionHandbookSupported: false,
        isGeometrySchematic: true,
        relatedReferenceIds: const ['table-7', 'para-55'],
      ));
      elements.add(SchematicElement(
        kind: SchematicElementKind.attachmentPoint,
        label: AppStrings.schematicAttachmentPointLabel,
        sourceEntityId: 'att-wire-lashing',
        points: [anchor],
        isPositionHandbookSupported: false,
        isGeometrySchematic: true,
        relatedReferenceIds: const ['para-55'],
      ));
    }
    return elements;
  }
}
