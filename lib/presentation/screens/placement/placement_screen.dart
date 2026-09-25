import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/models/schematic_element.dart';
import '../../../domain/models/train_consist.dart';
import '../../../domain/models/securing_placement.dart';
import '../../../domain/usecases/consumables.dart';
import '../../../domain/usecases/securing_hardware_catalog.dart';
import '../../../domain/usecases/securing_measurements.dart';
import '../../../domain/usecases/wagon_capacity.dart';
import '../../../domain/usecases/deck_position.dart';
import '../../../domain/usecases/flatcar_mesh_builder.dart';
import '../../../domain/usecases/schematic_hit_test.dart';
import '../../../domain/usecases/vehicle_mesh_catalog.dart';
import '../../../domain/usecases/wire_lashing_rule.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/common/wagon_budget_panel.dart';
import '../../widgets/visualization/loading_scene_3d_view.dart';
import '../../widgets/visualization/side_elevation_painter.dart';
import '../../widgets/visualization/wagon_plan_painter.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/instrument.dart';
import '../../widgets/common/measured_strip.dart';

/// Step 4 of the loading flow: putting the ordered vehicles onto the wagons.
///
/// Each wagon is drawn twice — side elevation and plan — from the same
/// diagram, the way the handbook's plates present a loaded flatcar. Several
/// vehicles can share one wagon, and a vehicle can be set over the coupling
/// between two, which is a distinct case on plate-06 and carries its own
/// chock rules.
///
/// Dragging moves a vehicle within the drawing only. The drawing is not to
/// scale — no vehicle or wagon in the current data has real dimensions — so
/// where a vehicle is dropped is never treated as a measurement. Whether a
/// load is correct is decided from the case it represents, not from pixels.
class PlacementScreen extends ConsumerWidget {
  const PlacementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consist = ref.watch(consistProvider);
    final orders = ref.watch(vehicleOrdersProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);

    // The readings for the value strip, taken here rather than in the panel
    // that shows them: these providers are shared with the wagon list below,
    // and a widget subscribing to them from inside the right-hand rail is
    // marked dirty in the middle of the list's build.
    final selectedId = ref.watch(selectedPlacementIdProvider);
    final selectedPlacement =
        consist.placements.where((p) => p.id == selectedId).firstOrNull ??
            consist.placements.firstOrNull;
    final measuredWagonId = selectedPlacement?.wagonIds.first ??
        (consist.wagons.isEmpty ? null : consist.wagons.first.id);
    final budget = measuredWagonId == null
        ? null
        : ref.watch(wagonBudgetProvider(measuredWagonId));
    final overhangMm = measuredWagonId == null
        ? null
        : ref.watch(wagonOverhangProvider(measuredWagonId));
    final seating = ref
        .watch(attemptSeatingFindingsProvider)
        .where((f) => selectedPlacement == null || f.placementId == selectedPlacement.id)
        .toList();

    return InstrumentScaffold(
      title: AppStrings.placementTitle,
      step: 3,
      onBack: () => context.go('/wagon-type'),
      footer: AdvanceButton(
        label: AppStrings.placementNextButton,
        onPressed:
            consist.placements.isEmpty ? null : () => context.go('/equipment'),
        blockedReason:
            consist.placements.isEmpty ? AppStrings.placementNothingPlaced : null,
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(AppStrings.failedToLoadVehicles(e))),
        data: (vehicles) {
          final byId = {for (final v in vehicles) v.id: v};
          final wagons = _WagonList(consist: consist, vehiclesById: byId);
          final panel = _PendingPanel(
            consist: consist,
            orders: orders,
            vehiclesById: byId,
            budget: budget,
            overhangMm: overhangMm,
            seating: seating,
          );

          return LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 900) {
                return Column(
                  children: [
                    Expanded(child: wagons),
                    SizedBox(height: 260, child: panel),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(child: wagons),
                  SizedBox(width: 380, child: panel),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The vehicle the user has picked up and is about to put on a wagon.
final _pendingVehicleIdProvider = StateProvider<String?>((ref) => null);

class _WagonList extends ConsumerWidget {
  final TrainConsist consist;
  final Map<String, Vehicle> vehiclesById;

  const _WagonList({required this.consist, required this.vehiclesById});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (consist.wagons.isEmpty) {
      return EmptyField(
        legend: AppStrings.breadcrumbWagons,
        message: AppStrings.consistNoWagonsYet,
        actionLabel: AppStrings.breadcrumbWagons,
        onAction: () => context.go('/consist'),
      );
    }
    return ListView.separated(
      padding: AppSpace.screen,
      itemCount: consist.wagons.length,
      separatorBuilder: (_, __) => const SizedBox(height: AppSpace.xl),
      itemBuilder: (context, i) => _WagonCard(
        wagon: consist.wagons[i],
        index: i + 1,
        // Offered only when there is a following wagon to span onto.
        nextWagonId: i + 1 < consist.wagons.length ? consist.wagons[i + 1].id : null,
        consist: consist,
        vehiclesById: vehiclesById,
      ),
    );
  }
}

class _WagonCard extends ConsumerWidget {
  final WagonInstance wagon;
  final int index;
  final String? nextWagonId;
  final TrainConsist consist;
  final Map<String, Vehicle> vehiclesById;

  const _WagonCard({
    required this.wagon,
    required this.index,
    required this.nextWagonId,
    required this.consist,
    required this.vehiclesById,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final diagram = ref.watch(wagonSchematicProvider(wagon.id));

    // The called values for the elevation's dimension lines. Both are the
    // records' own; a record that does not state one gets a dimension
    // lettered "not stated" rather than a number invented to fill the gap.
    final platform = ref.watch(consistPlatformProvider).valueOrNull;
    final platformLength = platform != null && platform.lengthCm.isAvailable
        ? platform.lengthCm.display(unit: 'sm')
        : null;
    String? lengthOfPlacement(String placementId) {
      final placed = consist.placements.where((p) => p.id == placementId).firstOrNull;
      final vehicle = placed == null ? null : vehiclesById[placed.vehicleId];
      if (vehicle == null || !vehicle.lengthCm.isAvailable) return null;
      return vehicle.lengthCm.display(unit: 'sm');
    }
    final selectedPlacementId = ref.watch(selectedPlacementIdProvider);
    final pendingVehicleId = ref.watch(_pendingVehicleIdProvider);
    final onboard = consist.placementsOn(wagon.id);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  AppStrings.placementWagonLabel(index).toUpperCase(),
                  style: AppText.legend(size: AppText.sectionTitle, color: AppColors.textPrimary),
                ),
                const SizedBox(width: 12),
                // Flexible with an ellipsis, not a bare Text: one entry in the
                // catalogue is the grouped record whose designation lists
                // fourteen object numbers, and on that vehicle the header
                // overflowed the card.
                Flexible(
                  child: Text(
                    onboard.isEmpty
                        ? AppStrings.placementEmptyWagon
                        : onboard
                            .map((p) =>
                                vehiclesById[p.vehicleId]?.handbookDesignation ??
                                p.vehicleId)
                            .join(', '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: AppText.bodySmall, color: AppColors.textSecondary),
                  ),
                ),
                const Spacer(),
                if (pendingVehicleId != null) ...[
                  TextButton.icon(
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text(AppStrings.placementPlaceHere),
                    onPressed: () => _place(ref, [wagon.id], pendingVehicleId),
                  ),
                  if (nextWagonId != null)
                    TextButton.icon(
                      icon: const Icon(Icons.link, size: 16),
                      label: const Text(AppStrings.placementSpanCoupling),
                      onPressed: () =>
                          _place(ref, [wagon.id, nextWagonId!], pendingVehicleId),
                    ),
                ],
              ],
            ),
            // What is on this wagon, listed directly under the wagon's own
            // heading and above every diagram.
            //
            // This list used to sit at the *bottom* of the card, below the
            // side elevation, the photograph, the three-dimensional scene,
            // the plan view and the budget panel — about 2,600 pixels down on
            // a vehicle that has a model. The delete button on each row was
            // the only way to take a vehicle off the wagon, and at that depth
            // a trainee never found it: scrolling to the end of the list
            // stopped short of it, because a lazy list under-estimates its
            // own extent until the tall child has been laid out once, so the
            // first scroll to the bottom left the row still off-screen. The
            // control that removes a vehicle belongs beside the vehicle's
            // name, not behind five diagrams of it.
            for (final placement in onboard)
              _PlacementRow(
                placement: placement,
                designation: vehiclesById[placement.vehicleId]?.handbookDesignation ??
                    placement.vehicleId,
                selected: placement.id == selectedPlacementId,
              ),
            const SizedBox(height: 8),
            if (diagram == null)
              const SizedBox(
                height: 80,
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              // The three views of one wagon, each labelled and spaced the
              // same. Before this the side and plan views carried a quiet
              // caption, the 3D scene carried none at all, and the gaps
              // between them were 8 and 6 — so the stack read as one
              // undifferentiated column of drawings rather than three views
              // of the same thing.
              const _ViewLabel(AppStrings.placementSideViewLabel),
              _SchematicSurface(
                diagram: diagram,
                selectedPlacementId: selectedPlacementId,
                aspectRatio: 3.6,
                // The side slot draws the elevation the handbook plates
                // draw — vehicle on the deck, over rails — not the plan
                // painter it used to borrow, which rendered the same
                // rectangles as the view directly below it.
                painterBuilder: (d, _) => SideElevationPainter(
                  d,
                  showLabels: false,
                  showDimensions: true,
                  deckLength: platformLength,
                  lengthOf: (id) => lengthOfPlacement(id),
                ),
                geometry: _SurfaceGeometry.elevation,
              ),
              AppSpace.gapLg,
              _LoadingScene3DSection(
                wagon: wagon,
                diagram: diagram,
                onboard: onboard,
                vehiclesById: vehiclesById,
                selectedPlacementId: selectedPlacementId,
              ),
              AppSpace.gapLg,
              const _ViewLabel(AppStrings.placementPlanViewLabel),
              _SchematicSurface(
                diagram: diagram,
                selectedPlacementId: selectedPlacementId,
                aspectRatio: 5.0,
                painterBuilder: (d, sel) => WagonPlanPainter(d, selectedPlacementId: sel),
              ),
              AppSpace.gapSm,
              const Text(
                AppStrings.schematicNotToScaleBanner,
                style: TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary),
              ),
            ],
            // What the load takes and what is left — the answer to "can a
            // second vehicle go on this wagon", which the screen previously
            // could not give at all.
            WagonBudgetPanel(wagonId: wagon.id),
          ],
        ),
      ),
    );
  }

  void _place(WidgetRef ref, List<String> wagonIds, String vehicleId) {
    final id = ref.read(consistProvider.notifier).place(
          vehicleId: vehicleId,
          wagonIds: wagonIds,
        );
    ref.read(selectedPlacementIdProvider.notifier).state = id;
    ref.read(_pendingVehicleIdProvider.notifier).state = null;
  }
}

/// One vehicle still to be placed. Selected, it is the piece the trainee is
/// holding, so it carries the instrument's light and a lit frame — the same
/// vocabulary a held stop block gets on the deck.
class _PendingRow extends StatefulWidget {
  final String designation;
  final int remaining;
  final bool held;
  final VoidCallback onTap;

  const _PendingRow({
    required this.designation,
    required this.remaining,
    required this.held,
    required this.onTap,
  });

  @override
  State<_PendingRow> createState() => _PendingRowState();
}

class _PendingRowState extends State<_PendingRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final lit = widget.held || _hover;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.touch,
          margin: const EdgeInsets.only(bottom: AppSpace.sm),
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.sm),
          decoration: BoxDecoration(
            color: widget.held ? AppColors.instrument.withValues(alpha: 0.10) : Colors.transparent,
            border: Border.all(
              color: widget.held
                  ? AppColors.instrument
                  : _hover
                      ? AppColors.hairlineBright
                      : AppColors.hairline,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.designation.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.legend(
                    size: AppText.caption,
                    color: lit ? AppColors.instrumentGlow : AppColors.label,
                    tracking: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.sm),
              Text(
                '×${widget.remaining}',
                style: AppText.value(
                  size: AppText.readoutSmall,
                  color: lit ? AppColors.instrumentGlow : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The photographic version of the same wagon: the vehicle cut out of its own
/// photograph, standing on the flatcar picture from the design mockup, at the
/// position the user has dragged it to.
///
/// It is shown for one placement at a time — the selected one, or the only one
/// aboard — because a photograph of a wagon cannot honestly show two machines
/// at arbitrary positions without measured lengths for either. When the
/// vehicle has no clean cut-out, the drawn elevation above stands alone and a
/// single line says why.
/// The three-dimensional view of this wagon and what is standing on it.
///
/// Shown only for a vehicle the catalogue can honestly model — which today
/// means one whose record carries real dimensions. For every other vehicle in
/// the extract the length, width and height are "not available", and a solid
/// built from nothing would be the most convincing wrong drawing in the whole
/// application. Those keep the flat views, which say what they are.
class _LoadingScene3DSection extends ConsumerWidget {
  final WagonInstance wagon;
  final SchematicDiagram diagram;
  final List<PlacedVehicle> onboard;
  final Map<String, Vehicle> vehiclesById;
  final String? selectedPlacementId;

  const _LoadingScene3DSection({
    required this.wagon,
    required this.diagram,
    required this.onboard,
    required this.vehiclesById,
    required this.selectedPlacementId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (onboard.isEmpty) return const SizedBox.shrink();
    final placement = onboard.firstWhere(
      (p) => p.id == selectedPlacementId,
      orElse: () => onboard.first,
    );
    final vehicle = vehiclesById[placement.vehicleId];
    if (vehicle == null) return const SizedBox.shrink();
    final spec = VehicleMeshCatalog.specFor(vehicle);
    if (spec == null) return const SizedBox.shrink();

    final platform = ref
        .watch(platformsProvider)
        .valueOrNull
        ?.where((p) => p.id == wagon.platformId)
        .firstOrNull;
    final flatcarSpec = FlatcarMeshSpec.fromPlatformFigures(
      lengthCm: platform?.lengthCm.asDouble,
      widthCm: platform?.widthCm.asDouble,
      deckHeightCm: platform?.deckHeightCm.asDouble,
      tieDownRings: platform?.tieDownRings.numericValue?.toInt(),
    );

    // Everything the handbook states a size for, in one list: every stop-block
    // weight bracket, the half-round insert, plate-02's side block and staple,
    // the packing board, both KGUUB variants, all eleven iron spurs and all
    // four stop-boots. A piece with no stated size is not in it.
    final measurements = ref.watch(measurementsProvider).valueOrNull;
    final rules = ref.watch(rulesProvider).valueOrNull;
    final attachments = ref.watch(attachmentTypesProvider).valueOrNull ?? const [];
    final hardware = (measurements != null && rules != null)
        ? placeableHardwareFor(
            vehicle: vehicle,
            measurements: measurements,
            rules: rules,
            attachments: attachments,
            trackShoeWidthM: spec.runningGearWidthM,
          )
        : const <PlaceableHardware>[];

    final weight = vehicle.bracketWeightT.asDouble;
    // `rule-wheeled-lashing-count` is the wheeled rule (method 2, para. 55).
    // Asking it about a tracked vehicle would answer from the wrong page, so
    // it is only consulted for the category it is written for; the extract
    // fixes no lashing count for a tracked vehicle, and the view says so.
    final lashings = (rules != null &&
            weight != null &&
            vehicle.category == VehicleCategory.wheeled)
        ? requiredWireLashingCount(weight, rules)
        : null;
    // The strand count, though, the tracked table does give by weight.
    final threads = (measurements != null &&
            weight != null &&
            vehicle.category == VehicleCategory.tracked)
        ? trackedWireStrandsPerLashing(weight, measurements)
        : null;

    // A model file for this vehicle, if one has been added and credited.
    // Null is the normal case: the vehicle is then drawn from its dimensions.
    final fitted = ref.watch(vehicleMeshProvider(vehicle.id)).valueOrNull;

    final position = deckPositionOf(diagram, placement.id);
    final layouts = ref.watch(placementSecuringLayoutProvider);
    final layout = layouts[placement.id] ?? SecuringLayout.empty;

    // The other machines on this wagon. They are drawn where they stand and
    // the space between them is measured; to work on one, select it — the
    // view edits whichever placement the screen has selected.
    final companions = <SceneCompanion>[];
    for (final other in onboard) {
      if (other.id == placement.id) continue;
      final otherVehicle = vehiclesById[other.vehicleId];
      if (otherVehicle == null) continue;
      final otherSpec = VehicleMeshCatalog.specFor(otherVehicle);
      if (otherSpec == null) continue;
      companions.add(SceneCompanion(
        placementId: other.id,
        designation: otherVehicle.handbookDesignation,
        spec: otherSpec,
        positionFraction: deckPositionOf(diagram, other.id).fraction,
        layout: layouts[other.id] ?? SecuringLayout.empty,
        meshOverride:
            ref.watch(vehicleMeshProvider(otherVehicle.id)).valueOrNull?.model.mesh,
      ));
    }

    // What the plates require between this vehicle and the one beside it.
    final neighbour = companions.isEmpty
        ? null
        : vehiclesById[onboard
            .firstWhere((p) => p.id == companions.first.placementId)
            .vehicleId];
    final requiredClearance = (rules != null && neighbour != null)
        ? clearanceBetween(vehicle.category, neighbour.category, rules)?.mm
        : null;

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: LoadingScene3DView(
        // The handbook's own figure for whatever piece is selected in the
        // picker: 15.13 for the iron spurs, 15.14 for the stop-boots, 15.11
        // and 15.12 for the reusable chocks. A name and a size do not tell a
        // trainee who has never held one what they are putting on the wagon.
        figuresFor: (referenceId) =>
            ref.watch(referenceLinkerProvider).valueOrNull?.photosFor(referenceId) ??
            const [],
        vehicleSpec: spec,
        flatcarSpec: flatcarSpec,
        placementId: placement.id,
        designation: vehicle.handbookDesignation,
        companions: companions,
        requiredClearanceMm: requiredClearance,
        vehicleMesh: fitted?.model.mesh,
        vehicleMeshCredit: fitted?.creditLine,
        layout: layout,
        onLayoutChanged: (next) => ref
            .read(placementSecuringLayoutProvider.notifier)
            .put(placement.id, next),
        hardware: hardware,
        arrangement: ref.watch(placementSelectedArrangementProvider(placement.id)),
        snapSeatingDistanceM:
            ref.watch(placementSnapSeatingDistanceProvider(placement.id)),
        lashingRunCount: lashings,
        lashingThreads: threads,
        initialPositionFraction: position.fraction,
        onPositionChanged: (value) {
          // Written back as a drag on the same diagram the flat views move,
          // so sliding the vehicle in three dimensions moves it in all four
          // views at once instead of forking the position into two states.
          if (position.travel <= 0) return;
          final current = deckPositionOf(diagram, placement.id).fraction;
          ref.read(consistProvider.notifier).dragBy(
                placement.id,
                SchematicPoint((value - current) * position.travel, 0),
              );
        },
      ),
    );
  }
}

class _ViewLabel extends StatelessWidget {
  final String label;
  const _ViewLabel(this.label);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.sm),
        child: SectionHeading(label, rule: true),
      );
}

/// A drawn view of one wagon that can be tapped to select a vehicle and
/// dragged to move the selected one.
///
/// Both views share this, so selecting in the plan view and dragging in the
/// side view act on the same placement — there is one interaction model, not
/// one per drawing.
/// How a surface turns a tap or a drag into a selection or a move.
///
/// The plan view and the side elevation are drawn from the same diagram but
/// not with the same geometry: the elevation keeps every x and invents every
/// y (see [SideElevationPainter]). Hit-testing it with the plan's coordinates
/// would select whatever the plan happens to have at that height — tapping the
/// drawn wagon deck could pick the vehicle — so each surface says which rule
/// applies to it.
enum _SurfaceGeometry {
  /// The diagram's own coordinates, in both axes.
  plan,

  /// x from the diagram, y meaningless: a tap selects the vehicle whose
  /// horizontal span it falls in, and a drag only moves along the deck.
  /// Dragging a vehicle upwards in a side view would mean lifting it off the
  /// wagon, which is not something the trainee can do.
  elevation,
}

class _SchematicSurface extends ConsumerWidget {
  final SchematicDiagram diagram;
  final String? selectedPlacementId;
  final double aspectRatio;
  final CustomPainter Function(SchematicDiagram, String?) painterBuilder;
  final _SurfaceGeometry geometry;

  const _SchematicSurface({
    required this.diagram,
    required this.selectedPlacementId,
    required this.aspectRatio,
    required this.painterBuilder,
    this.geometry = _SurfaceGeometry.plan,
  });

  /// The placement whose drawn body spans [x], or null when the tap missed
  /// every vehicle.
  String? _placementAtX(double x) {
    for (final element in diagram.elements) {
      if (element.kind != SchematicElementKind.vehicleBody) continue;
      if (element.points.isEmpty) continue;
      final xs = element.points.map((p) => p.dx);
      final left = xs.reduce((a, b) => a < b ? a : b);
      final right = xs.reduce((a, b) => a > b ? a : b);
      if (x >= left && x <= right) return element.placementId;
    }
    return null;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapUp: (details) {
              final x = details.localPosition.dx / constraints.maxWidth;
              final String? placementId;
              if (geometry == _SurfaceGeometry.elevation) {
                placementId = _placementAtX(x);
              } else {
                final hit = hitTestSchematicElement(
                  diagram.elements,
                  x,
                  details.localPosition.dy / constraints.maxHeight,
                );
                placementId = hit?.placementId;
              }
              // Tapping the deck or a rail clears the selection rather than
              // leaving a stale vehicle selected.
              ref.read(selectedPlacementIdProvider.notifier).state = placementId;
            },
            onPanUpdate: (details) {
              final id = selectedPlacementId;
              if (id == null) return;
              ref.read(consistProvider.notifier).dragBy(
                    id,
                    SchematicPoint(
                      details.delta.dx / constraints.maxWidth,
                      geometry == _SurfaceGeometry.elevation
                          ? 0
                          : details.delta.dy / constraints.maxHeight,
                    ),
                  );
            },
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.ground,
                border: Border.all(color: AppColors.hairline),
              ),
              child: CustomPaint(
                painter: painterBuilder(diagram, selectedPlacementId),
                size: Size.infinite,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PlacementRow extends ConsumerWidget {
  final PlacedVehicle placement;
  final String designation;
  final bool selected;

  const _PlacementRow({
    required this.placement,
    required this.designation,
    required this.selected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => ref.read(selectedPlacementIdProvider.notifier).state = placement.id,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
              size: 14,
              color: selected ? AppColors.label : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            // Designations run from "T-72" to the full "Objekt 137" family
            // string, so the name takes the slack instead of a Spacer and
            // gives way before the coupling warning does.
            Expanded(
              child: Text(
                designation,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: AppText.bodySmall),
              ),
            ),
            if (placement.spansCoupling) ...[
              const SizedBox(width: 8),
              const Flexible(
                child: Text(
                  AppStrings.placementSpansCouplingLabel,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.offNominal),
                ),
              ),
            ],
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: AppStrings.placementRemove,
              icon: const Icon(Icons.delete_outline, size: 16),
              onPressed: () {
                ref.read(consistProvider.notifier).remove(placement.id);
                ref.read(placementEquipmentProvider.notifier).clearPlacement(placement.id);
                ref.read(placementSecuringMethodProvider.notifier).clearPlacement(placement.id);
                // The chock choice is per placement too and was being left
                // behind when the vehicle it belonged to was removed.
                ref.read(placementChockChoiceProvider.notifier).clearPlacement(placement.id);
                if (selected) {
                  ref.read(selectedPlacementIdProvider.notifier).state = null;
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPanel extends ConsumerWidget {
  final TrainConsist consist;
  final List<VehicleOrder> orders;
  final Map<String, Vehicle> vehiclesById;
  final WagonLengthBudget? budget;
  final double? overhangMm;
  final List<SeatingFinding> seating;

  const _PendingPanel({
    required this.consist,
    required this.orders,
    required this.vehiclesById,
    required this.budget,
    required this.overhangMm,
    required this.seating,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = ref.watch(_pendingVehicleIdProvider);
    final remaining = <String, int>{
      for (final order in orders)
        if (order.quantity - consist.placedCountOf(order.vehicleId) > 0)
          order.vehicleId: order.quantity - consist.placedCountOf(order.vehicleId),
    };

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.well,
        border: Border(left: BorderSide(color: AppColors.hairline)),
      ),
      padding: const EdgeInsets.all(AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeading(
            AppStrings.placementRemaining,
            note: AppStrings.placementSubtitle,
            live: remaining.isNotEmpty,
          ),
          if (remaining.isEmpty)
            // Nothing left to place and nothing ever ordered are two different
            // states, and calling the second one "all placed" told the trainee
            // they had finished a step they had not started.
            Align(
              alignment: Alignment.topLeft,
              child: orders.isEmpty
                  ? Text(
                      AppStrings.vehicleOrderEmpty,
                      style: AppText.prose(
                          size: AppText.bodySmall, color: AppColors.labelDim),
                    )
                  : const VerdictChip(
                      tone: AppTone.pass,
                      label: AppStrings.placementAllPlaced,
                      dense: true,
                    ),
            )
          else
            for (final entry in remaining.entries)
              _PendingRow(
                designation:
                    vehiclesById[entry.key]?.handbookDesignation ?? entry.key,
                remaining: entry.value,
                held: entry.key == pending,
                onTap: () => ref.read(_pendingVehicleIdProvider.notifier).state =
                    entry.key == pending ? null : entry.key,
              ),
          const SizedBox(height: AppSpace.xl),
          // The value strip: every reading this wagon has produced, each drawn
          // against the range the handbook states for it. It is the reason the
          // trainee can tell a block that is merely placed from one that is
          // placed correctly.
          Expanded(
            child: SingleChildScrollView(
              child: MeasuredStrip(
                budget: budget,
                overhangMm: overhangMm,
                findings: seating,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
