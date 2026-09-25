import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../common/app_surfaces.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/simulation_result.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/models/schematic_element.dart';
import '../../../domain/usecases/equipment_catalog.dart';
import '../../../domain/usecases/equipment_selection.dart';
import '../../../domain/usecases/handbook_photo_resolution.dart';
import '../../../domain/usecases/schematic_hit_test.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../photos/related_photos_row.dart';
import 'schematic_element_detail_dialog.dart';
import 'securing_schematic_painter.dart';
import '../../../domain/usecases/chock_detail_spec.dart';
import 'chock_detail_painter.dart';
import 'end_elevation_painter.dart';
import 'side_elevation_painter.dart';

const _equipmentHardwareIds = {
  'att-iron-spur',
  'att-iron-chock-boot',
  'att-kguub-1g',
  'att-kguub-2g',
  'att-wood-chock',
  'att-wire-lashing',
};

List<HandbookPhoto> _dedupPhotos(List<HandbookPhoto> photos) {
  final seen = <String>{};
  return [for (final p in photos) if (seen.add(p.id)) p];
}

/// Derives the same selected/required/specs/verdict values the Required
/// Equipment panel shows for one hardware id, so the tap-to-inspect popup
/// can display them too — reusing `requiredTypeCodeFor`,
/// `equipmentOptionsFor`, and `checkEquipmentSelection` directly rather
/// than recomputing anything.
({String? selected, Map<String, String> specs, ValidationCheck? check})? _equipmentDisplayInfo(
  WidgetRef ref,
  SchematicElement element,
  Vehicle vehicle,
  String placementId,
) {
  final hardwareId = element.sourceEntityId;
  if (!_equipmentHardwareIds.contains(hardwareId)) return null;

  final selections = ref.read(effectivePlacementEquipmentProvider(placementId));
  String? selected = selections[hardwareId];
  selected ??= switch (hardwareId) {
    'att-iron-spur' => vehicle.ironSpurType,
    'att-iron-chock-boot' => vehicle.ironChockBootType,
    _ => null,
  };
  if (selected == null) return (selected: null, specs: const {}, check: null);

  final measurements = ref.read(measurementsProvider).valueOrNull ?? const {};
  final attachments = ref.read(attachmentTypesProvider).valueOrNull ?? const [];
  final required = requiredTypeCodeFor(hardwareId, vehicle, measurements: measurements);
  final options =
      equipmentOptionsFor(hardwareId, measurements, attachments, category: vehicle.category);
  final matches = options.where((o) => o.typeCode == selected);
  final specs = matches.isEmpty ? const <String, String>{} : matches.first.specs;
  final referenceId = element.relatedReferenceIds.isEmpty ? '' : element.relatedReferenceIds.first;
  final check = checkEquipmentSelection(
    referenceId: referenceId,
    requiredTypeCode: required,
    selectedTypeCode: selected,
  );
  return (selected: selected, specs: specs, check: check);
}

/// Full securing schematic section: "not to scale" banner, the interactive
/// diagram (vehicle draggable within the platform bounds), a legend, a
/// three-way position/validation status panel, and (reusing the existing
/// photo/reference infrastructure) any handbook figures tied to what's
/// shown.
class SecuringSchematicSection extends ConsumerWidget {
  final SchematicDiagram diagram;

  /// The placed vehicle this section drags and inspects. Offsets and
  /// equipment selections are held per placement, so a drag here cannot
  /// disturb another vehicle sharing the same wagon and no reset is needed
  /// when the selection moves.
  final String placementId;
  final Vehicle vehicle;
  final SimulationResult? result;

  const SecuringSchematicSection({
    super.key,
    required this.diagram,
    required this.placementId,
    required this.vehicle,
    required this.result,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (diagram.elements.isEmpty) {
      return const Text(AppStrings.schematicNoHardwareYet,
          style: TextStyle(color: AppColors.textSecondary, fontSize: AppText.bodySmall));
    }

    final linker = ref.watch(referenceLinkerProvider).valueOrNull;
    final relatedReferenceIds = <String>{
      for (final e in diagram.elements) ...e.relatedReferenceIds,
    };
    final relatedPhotos = linker?.photosForAny(relatedReferenceIds) ?? const [];
    const hardwareKinds = {
      SchematicElementKind.ironSpurPair,
      SchematicElementKind.ironChockBootPair,
      SchematicElementKind.reusableChockPair,
      SchematicElementKind.woodChockPair,
      SchematicElementKind.spacerBoard,
      SchematicElementKind.wireLashing,
    };
    final hasHardware = diagram.elements.any((e) => hardwareKinds.contains(e.kind));
    final offset = ref.watch(consistProvider).placementById(placementId)?.offset ??
        const SchematicPoint(0, 0);
    final symmetryCheck =
        result?.checks.firstWhereOrNull((c) => c.ruleId == 'rule-symmetry-tolerance');

    // The called values for the dimension lines. Both come off the records;
    // where a record does not state one, the dimension is drawn and lettered
    // as not stated rather than being left off or made up.
    final platform = ref.watch(consistPlatformProvider).valueOrNull;
    final deckLength = platform != null && platform.lengthCm.isAvailable
        ? platform.lengthCm.display(unit: 'sm')
        : null;
    final vehicleLength =
        vehicle.lengthCm.isAvailable ? vehicle.lengthCm.display(unit: 'sm') : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(AppStrings.schematicSectionTitle),
        if (!diagram.isFullyToScale) const _NotToScaleBanner(),
        const SizedBox(height: 8),
        // The elevation first, because it is the view a trainee recognises
        // from the plates: the machine standing on the deck with its chocks
        // and lashings in place. The plan view below it is the one they drag
        // and tap; the two are built from the same diagram, so what moves in
        // one moves in the other.
        Text(AppStrings.sideElevationTitle.toUpperCase(),
            style: AppText.legend(size: AppText.caption, color: AppColors.labelDim, tracking: 1.6)),
        const SizedBox(height: AppSpace.sm),
        AspectRatio(
          aspectRatio: 2.6,
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.ground,
              border: Border.all(color: AppColors.hairline),
            ),
            child: CustomPaint(
              painter: SideElevationPainter(
                diagram,
                showDimensions: true,
                deckLength: deckLength,
                lengthOf: (_) => vehicleLength,
              ),
              size: Size.infinite,
            ),
          ),
        ),
        const SizedBox(height: 10),
        // The end view and the chock close-up: the lateral gap, the seating
        // distance, the nails and the overhang limit are all facts a profile
        // cannot show, and they are the reason this app does not need a 3D
        // scene to teach the arrangement.
        _EndViewAndDetail(placementId: placementId, vehicle: vehicle),
        const SizedBox(height: 10),
        Text(AppStrings.planViewTitle.toUpperCase(),
            style: AppText.legend(size: AppText.caption, color: AppColors.labelDim, tracking: 1.6)),
        const SizedBox(height: AppSpace.sm),
        AspectRatio(
          aspectRatio: 2.1,
          child: Container(
            decoration: BoxDecoration(color: AppColors.ground, border: Border.all(color: AppColors.hairline)),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = constraints.biggest;
                return GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: (details) {
                    if (size.width == 0 || size.height == 0) return;
                    ref.read(consistProvider.notifier).dragBy(
                          placementId,
                          SchematicPoint(
                            details.delta.dx / size.width,
                            details.delta.dy / size.height,
                          ),
                        );
                  },
                  onTapUp: (details) {
                    if (size.width == 0 || size.height == 0) return;
                    final hit = hitTestSchematicElement(
                      diagram.elements,
                      details.localPosition.dx / size.width,
                      details.localPosition.dy / size.height,
                    );
                    if (hit == null) return;
                    final photos = linker == null
                        ? const <HandbookPhoto>[]
                        : _equipmentHardwareIds.contains(hit.sourceEntityId)
                            // The evidence-checked mapping (e.g. excluding
                            // KGUUB-1G's figure from a KGUUB-2G element,
                            // including the wire-lashing photo despite its
                            // table-7 sizing citation) — see
                            // handbook_photo_resolution.dart.
                            ? _dedupPhotos([
                                for (final refId in hit.relatedReferenceIds)
                                  ...equipmentPhotosFor(hit.sourceEntityId, refId, linker),
                              ])
                            : linker.photosForAny(hit.relatedReferenceIds.toSet());
                    final info = _equipmentDisplayInfo(ref, hit, vehicle, placementId);
                    showSchematicElementDetailDialog(
                      context,
                      element: hit,
                      relatedPhotos: photos,
                      selectedTypeCode: info?.selected,
                      specs: info?.specs ?? const {},
                      check: info?.check,
                    );
                  },
                  child: CustomPaint(painter: SecuringSchematicPainter(diagram), size: size),
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Text(AppStrings.schematicTapHint,
            style: TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary)),
        Row(
          children: [
            const Expanded(
              child: Text(AppStrings.schematicDragHint,
                  style: TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary)),
            ),
            TextButton.icon(
              onPressed: () =>
                  ref.read(consistProvider.notifier).resetOffset(placementId),
              icon: const Icon(Icons.restart_alt, size: 16),
              label: const Text(AppStrings.schematicResetButton, style: TextStyle(fontSize: AppText.bodySmall)),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _Legend(diagram: diagram),
        if (!hasHardware) ...[
          const SizedBox(height: 10),
          const Text(AppStrings.schematicNoHardwareYet,
              style: TextStyle(color: AppColors.textSecondary, fontSize: AppText.bodySmall)),
        ],
        const SizedBox(height: 16),
        _PositionStatusPanel(offset: offset, symmetryCheck: symmetryCheck),
        if (relatedPhotos.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text(AppStrings.relatedFiguresHeading.toUpperCase(),
              style: AppText.legend(size: AppText.caption, color: AppColors.labelDim, tracking: 1.6)),
          const SizedBox(height: AppSpace.sm),
          RelatedPhotosRow(photos: relatedPhotos),
        ],
      ],
    );
  }
}

/// Makes the three-way distinction explicit: what the user did on screen
/// (schematic), what the handbook requires (a textual relationship, always
/// true regardless of the drawing), and what the engineering validator
/// actually determined (which never changes because of a drag — it only
/// ever reads real vehicle/platform data).
class _PositionStatusPanel extends StatelessWidget {
  final SchematicPoint offset;
  final ValidationCheck? symmetryCheck;

  const _PositionStatusPanel({required this.offset, required this.symmetryCheck});

  bool get _isAtInitialPosition => offset.dx == 0 && offset.dy == 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(AppStrings.schematicStatusSectionTitle.toUpperCase(),
              style: AppText.legend(size: AppText.caption, color: AppColors.label, tracking: 1.6)),
          const SizedBox(height: AppSpace.md),
          _StatusRow(
            icon: Icons.pan_tool_alt,
            iconColor: AppColors.label,
            label: AppStrings.schematicStatusPositionLabel,
            detail: _isAtInitialPosition
                ? AppStrings.schematicPositionInitial
                : AppStrings.schematicPositionAdjusted,
          ),
          const SizedBox(height: 8),
          const _StatusRow(
            icon: Icons.menu_book,
            iconColor: AppColors.labelDim,
            label: AppStrings.schematicStatusHandbookLabel,
            detail: AppStrings.schematicStatusHandbookText,
          ),
          const SizedBox(height: 8),
          _StatusRow(
            icon: symmetryCheck?.status == CheckStatus.pass
                ? Icons.check_circle
                : symmetryCheck?.status == CheckStatus.fail
                    ? Icons.cancel
                    : Icons.help,
            iconColor: symmetryCheck?.status == CheckStatus.pass
                ? AppColors.inTolerance
                : symmetryCheck?.status == CheckStatus.fail
                    ? AppColors.outOfTolerance
                    : AppColors.offNominal,
            label: AppStrings.schematicStatusEngineeringLabel,
            detail: symmetryCheck?.detail ?? AppStrings.symmetryUnknownDetail,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String detail;

  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: AppText.legend(size: AppText.caption, color: AppColors.label, tracking: 1.2)),
              const SizedBox(height: 2),
              Text(detail, style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _NotToScaleBanner extends StatelessWidget {
  const _NotToScaleBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.offNominal.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.offNominal),
        borderRadius: BorderRadius.zero,
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber, color: AppColors.offNominal, size: 18),
          SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppStrings.schematicNotToScaleBanner,
                    style: TextStyle(
                        color: AppColors.offNominal, fontWeight: FontWeight.bold, fontSize: AppText.bodySmall)),
                SizedBox(height: 2),
                Text(AppStrings.schematicNotToScaleExplanation,
                    style: TextStyle(color: AppColors.textSecondary, fontSize: AppText.bodySmall)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final SchematicDiagram diagram;
  const _Legend({required this.diagram});

  @override
  Widget build(BuildContext context) {
    final kinds = diagram.elements.map((e) => e.kind).toSet();
    const hardwareKinds = {
      SchematicElementKind.ironSpurPair,
      SchematicElementKind.ironChockBootPair,
      SchematicElementKind.reusableChockPair,
      SchematicElementKind.woodChockPair,
    };
    const runKinds = {SchematicElementKind.trackRun, SchematicElementKind.wheelRun};
    final hasMismatch = diagram.elements.any((e) => e.isSelectionMismatch);

    final entries = <(Color, String)>[
      (AppColors.vehicleEdge, AppStrings.schematicLegendVehicle),
      (AppColors.label, AppStrings.schematicLegendPlatform),
      if (kinds.contains(SchematicElementKind.railDirection))
        (AppColors.hairline, AppStrings.schematicLegendRailDirection),
      if (kinds.contains(SchematicElementKind.symmetryAxis))
        (AppColors.labelDim, AppStrings.schematicLegendSymmetryAxis),
      if (kinds.any(runKinds.contains))
        (AppColors.textSecondary, AppStrings.schematicLegendTrackWheelRun),
      if (kinds.any(hardwareKinds.contains))
        (AppColors.outOfTolerance, AppStrings.schematicLegendHardware),
      if (kinds.contains(SchematicElementKind.spacerBoard))
        (AppColors.labelDim, AppStrings.schematicLegendSpacerBoard),
      if (kinds.contains(SchematicElementKind.wireLashing))
        (AppColors.offNominal, AppStrings.schematicLegendAttachmentPoint),
      if (hasMismatch) (AppColors.offNominal, AppStrings.schematicLegendMismatch),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: entries
          .map((entry) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 10, height: 10, color: entry.$1),
                  const SizedBox(width: 6),
                  Text(entry.$2, style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
                ],
              ))
          .toList(),
    );
  }
}


/// The end elevation and the chock detail, side by side, drawn from the rules
/// and from whichever layout case the trainee chose for this placement.
class _EndViewAndDetail extends ConsumerWidget {
  final String placementId;
  final Vehicle vehicle;

  const _EndViewAndDetail({required this.placementId, required this.vehicle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rules = ref.watch(rulesProvider).valueOrNull;
    if (rules == null) return const SizedBox.shrink();
    final spec = chockDetailSpec(
      rules: rules,
      arrangement: ref.watch(placementSelectedArrangementProvider(placementId)),
    );
    if (spec.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(AppStrings.endViewTitle,
            style: TextStyle(
                fontSize: AppText.caption,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: AppColors.textSecondary)),
        const SizedBox(height: 2),
        const Text(AppStrings.endViewSubtitle,
            style: TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AspectRatio(
                aspectRatio: 1.35,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.ground,
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: CustomPaint(
                    painter: EndElevationPainter(
                      category: vehicle.category,
                      spec: spec,
                      designation: vehicle.handbookDesignation,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(AppStrings.chockDetailTitle,
                      style: TextStyle(
                          fontSize: AppText.caption,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 4),
                  AspectRatio(
                    aspectRatio: 1.5,
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.ground,
                        border: Border.all(color: AppColors.hairline),
                      ),
                      child: CustomPaint(
                        painter: ChockDetailPainter(spec: spec),
                        size: Size.infinite,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
