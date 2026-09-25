import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/platform.dart';
import '../../../data/models/simulation_result.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/models/securing_method.dart';
import '../../../domain/models/train_consist.dart';
import '../../../domain/usecases/layout_derived_securing.dart';
import '../../../domain/usecases/securing_method_resolution.dart';
import '../../../domain/usecases/vehicle_mesh_catalog.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/configuration_status_panel.dart';
import '../../widgets/common/configuration_summary_panel.dart';
import '../../widgets/equipment/chock_arrangement_selector.dart';
import '../../widgets/equipment/consumables_panel.dart';
import '../../widgets/equipment/equipment_configuration_wizard.dart';
import '../../widgets/equipment/lashing_angle_entry.dart';
import '../../widgets/equipment/securing_method_selector.dart';
import '../../widgets/visualization/securing_schematic.dart';
import '../../widgets/common/instrument.dart';
import '../../widgets/common/measured_strip.dart';

/// Step 5 of the loading flow: securing each placed vehicle so it cannot
/// move.
///
/// Every vehicle on the train is secured on its own — a wagon carrying two
/// vehicles has two independent securing arrangements, each with its own
/// method and its own equipment. The user picks a placement from the list and
/// works through method → equipment → summary for it, then moves to the next.
///
/// The engineering verdict shown is the existing per-vehicle one, unchanged.
/// Rules that span vehicles — the clearances between them, and the
/// over-the-coupling case — are not decided here.
class SecuringScreen extends ConsumerWidget {
  const SecuringScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consist = ref.watch(consistProvider);
    final platformAsync = ref.watch(consistPlatformProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final resultsAsync = ref.watch(placementResultsProvider);
    final selectedId = ref.watch(selectedPlacementIdProvider);

    return InstrumentScaffold(
      title: AppStrings.securingTitle,
      step: 5,
      onBack: () => context.go('/equipment'),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(AppStrings.errorPrefix(e))),
        data: (vehicles) => platformAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, st) => Center(child: Text(AppStrings.errorPrefix(e))),
          data: (platform) {
            if (platform == null || consist.placements.isEmpty) {
              return EmptyField(
                legend: AppStrings.securingTitle,
                message: AppStrings.placementNothingPlaced,
                actionLabel: AppStrings.breadcrumbPlacement,
                onAction: () => context.go('/placement'),
              );
            }
            final byId = {for (final v in vehicles) v.id: v};

            // Fall back to the first placement so the screen is never a blank
            // "nothing selected" panel after arriving from step 4.
            final placement = consist.placementById(selectedId ?? '') ??
                consist.placements.first;
            final vehicle = byId[placement.vehicleId];
            if (vehicle == null) {
              return const EmptyField(
                legend: AppStrings.securingTitle,
                message: AppStrings.securingSelectPlacement,
              );
            }

            final picker = _PlacementPicker(
              consist: consist,
              vehiclesById: byId,
              selectedId: placement.id,
              results: resultsAsync.valueOrNull ?? const {},
            );
            final workspace = _SecuringWorkspace(
              placement: placement,
              vehicle: vehicle,
              platform: platform,
              result: resultsAsync.valueOrNull?[placement.id],
            );

            return LayoutBuilder(
              builder: (context, constraints) {
                if (constraints.maxWidth < 900) {
                  return SingleChildScrollView(
                    padding: AppSpace.screen,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [picker, AppSpace.gapXl, workspace],
                    ),
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(width: 320, child: SingleChildScrollView(child: picker)),
                    const VerticalDivider(width: 1, color: AppColors.hairline),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: AppSpace.screen,
                        child: workspace,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// The vehicle, the wagon it stands on, and where its check stands — the
/// three things the trainee needs before reading anything else on the screen.
///
/// The verdict was a bare coloured dot in the picker and nowhere else here, so
/// the working area gave no answer to "am I done with this one". It is stated
/// in words as well as colour: the pass and unconfirmed states are the pair
/// most easily confused, and one of them is the whole point of the exercise.
class _TitleBlock extends StatelessWidget {
  final String designation;
  final String platformName;
  final SimulationResult? result;

  const _TitleBlock({
    required this.designation,
    required this.platformName,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final r = result;
    // Exactly the verdict `overallPass` already states — no check is re-decided
    // here. What is added is the undecided count beside it, which the screen
    // held but never showed.
    final tone = r == null || r.checks.isEmpty
        ? AppTone.neutral
        : r.failCount > 0
            ? AppTone.fail
            : AppTone.pass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          designation.toUpperCase(),
          style: AppText.legend(
            size: AppText.cardTitle,
            color: AppColors.textPrimary,
            tracking: 1.4,
          ),
        ),
        AppSpace.gapXs,
        Text(
          platformName,
          style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary),
        ),
        AppSpace.gapMd,
        Wrap(
          spacing: AppSpace.sm,
          runSpacing: AppSpace.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            VerdictChip(
              tone: tone,
              label: tone == AppTone.pass
                  ? AppStrings.statusPass
                  : tone == AppTone.fail
                      ? AppStrings.statusFail
                      : AppStrings.securingSelectPlacement,
            ),
            if (r != null && r.unknownCount > 0)
              VerdictChip(
                tone: AppTone.warn,
                dense: true,
                label: AppStrings.securingUnconfirmedCount(r.unknownCount),
              ),
          ],
        ),
        AppSpace.gapMd,
        const Text(
          AppStrings.simulationPositioningRule,
          style: TextStyle(
            fontSize: AppText.bodySmall,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

/// Lists every placed vehicle, grouped by the wagon it stands on, with the
/// engineering verdict for each so the user can see at a glance which ones
/// still need work.
class _PlacementPicker extends ConsumerWidget {
  final TrainConsist consist;
  final Map<String, Vehicle> vehiclesById;
  final String selectedId;
  final Map<String, SimulationResult> results;

  const _PlacementPicker({
    required this.consist,
    required this.vehiclesById,
    required this.selectedId,
    required this.results,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            AppStrings.securingSelectPlacement,
            style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary),
          ),
        ),
        for (var i = 0; i < consist.wagons.length; i++) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
            child: Text(
              AppStrings.placementWagonLabel(i + 1).toUpperCase(),
              style: AppText.legend(size: AppText.caption, color: AppColors.labelDim, tracking: 1.6),
            ),
          ),
          if (consist.placementsOn(consist.wagons[i].id).isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Text(
                AppStrings.placementEmptyWagon,
                style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary),
              ),
            ),
          for (final placement in consist.placementsOn(consist.wagons[i].id))
            // A vehicle spanning a coupling belongs to two wagons; list it
            // under the first so it is offered exactly once.
            if (placement.primaryWagonId == consist.wagons[i].id)
              ListTile(
                dense: true,
                selected: placement.id == selectedId,
                selectedTileColor: AppColors.instrumentDeep.withValues(alpha: 0.3),
                leading: _VerdictDot(result: results[placement.id]),
                title: Text(
                  vehiclesById[placement.vehicleId]?.handbookDesignation ??
                      placement.vehicleId,
                  style: const TextStyle(fontSize: AppText.label),
                ),
                subtitle: placement.spansCoupling
                    ? const Text(
                        AppStrings.placementSpansCouplingLabel,
                        style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal),
                      )
                    : null,
                onTap: () =>
                    ref.read(selectedPlacementIdProvider.notifier).state = placement.id,
              ),
        ],
      ],
    );
  }
}

class _VerdictDot extends StatelessWidget {
  final SimulationResult? result;
  const _VerdictDot({required this.result});

  @override
  Widget build(BuildContext context) {
    final r = result;
    // No verdict yet is its own state — never drawn as a pass.
    final color = r == null
        ? AppColors.textSecondary
        : r.overallPass
            ? AppColors.inTolerance
            : AppColors.offNominal;
    return Icon(Icons.circle, size: 12, color: color);
  }
}

/// Method → equipment → summary for the one selected placement, with the
/// schematic beside it. Only one stage is shown at a time, so the user is
/// never faced with every control at once.
class _SecuringWorkspace extends ConsumerStatefulWidget {
  final PlacedVehicle placement;
  final Vehicle vehicle;
  final Platform platform;
  final SimulationResult? result;

  const _SecuringWorkspace({
    required this.placement,
    required this.vehicle,
    required this.platform,
    required this.result,
  });

  @override
  ConsumerState<_SecuringWorkspace> createState() => _SecuringWorkspaceState();
}

class _SecuringWorkspaceState extends ConsumerState<_SecuringWorkspace> {
  int _stage = 0;

  /// Set when the trainee asks to revise answers their placement already gave,
  /// which puts the method and equipment stages back on the screen for this
  /// vehicle. Cleared when the selection moves to another vehicle.
  bool _revising = false;

  @override
  void didUpdateWidget(_SecuringWorkspace old) {
    super.didUpdateWidget(old);
    // Moving to a different vehicle starts that vehicle's own sequence from
    // the beginning rather than dropping the user into a stage they have not
    // reached for it.
    if (old.placement.id != widget.placement.id) {
      _stage = 0;
      _revising = false;
    }
  }

  /// The stages this vehicle still has something to ask about, in order.
  ///
  /// A vehicle the catalogue can model in three dimensions is secured by hand
  /// in the 3D scene at step 4: the trainee seats the stop blocks themselves,
  /// chooses their arrangement by where they put them, and picks each piece off
  /// a sized palette. For that vehicle this screen asks nothing — putting the
  /// same decisions back to them as a written test after they have already
  /// done the work is what it used to get wrong. It shows the summary, which
  /// reports rather than asks.
  ///
  /// A vehicle with no 3D model has no such scene — the flat views cannot be
  /// worked on — so nothing has been answered and every stage stays.
  List<int> _openStages(SimulationResult r) {
    if (_revising) return const [0, 1, 2];
    if (VehicleMeshCatalog.specFor(widget.vehicle) != null) return const [2];

    final id = widget.placement.id;
    final answered = ref.watch(effectivePlacementEquipmentProvider(id));
    final methodOpen = ref.watch(effectiveSecuringMethodProvider(id)) == null &&
        resolveSecuringMethodOptions(widget.vehicle) is AlternativeSecuringMethods;
    // The chock arrangement is chosen in the method stage and the placement is
    // measured against it, so an unmade choice keeps that stage open too.
    final arrangementOpen =
        ref.watch(placementSelectedArrangementProvider(id)) == null &&
            ref.watch(placementChockArrangementsProvider(id)).isNotEmpty;
    final equipmentOpen = equipmentStillUnanswered(
      requiredHardwareIds: r.requiredHardwareIds,
      answered: answered,
    ).isNotEmpty;
    return [
      if (methodOpen || arrangementOpen) 0,
      if (equipmentOpen) 1,
      2,
    ];
  }

  /// Moves to the stage [delta] steps along the open ones.
  void _step(List<int> open, int delta) {
    final at = open.indexOf(_stage);
    final next = (at < 0 ? 0 : at) + delta;
    if (next < 0 || next >= open.length) return;
    setState(() => _stage = open[next]);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.result;
    final diagram = ref.watch(wagonSchematicProvider(widget.placement.primaryWagonId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _TitleBlock(
          designation: widget.vehicle.handbookDesignation,
          platformName: widget.platform.name,
          result: r,
        ),
        AppSpace.gapXl,
        // The readings for this placement, each against the range the handbook
        // states for it. On this screen the trainee is choosing and seating
        // gear, so what the gear measures is the screen's own subject.
        MeasuredStrip(
          budget: ref.watch(wagonBudgetProvider(widget.placement.primaryWagonId)),
          overhangMm: ref.watch(wagonOverhangProvider(widget.placement.primaryWagonId)),
          findings: ref
              .watch(attemptSeatingFindingsProvider)
              .where((f) => f.placementId == widget.placement.id)
              .toList(),
        ),
        AppSpace.gapXl,
        if (diagram != null)
          SecuringSchematicSection(
            diagram: diagram,
            placementId: widget.placement.id,
            vehicle: widget.vehicle,
            result: r,
          ),
        AppSpace.gapXl,
        if (r == null)
          const Text(
            AppStrings.completeSelectionFirst,
            style: TextStyle(color: AppColors.textSecondary, fontSize: AppText.bodySmall),
          )
        else ...[
          ConfigurationStatusPanel(
            vehicle: widget.vehicle,
            platform: widget.platform,
            result: r,
            placementId: widget.placement.id,
          ),
          AppSpace.gapLg,
          () {
            final open = _openStages(r);
            // A stage that closed while the trainee was standing on it — they
            // placed the last missing piece — must not leave the screen blank.
            final stage = open.contains(_stage) ? _stage : open.first;
            return switch (stage) {
              0 => _methodStage(r, open),
              1 => _equipmentStage(r, open),
              _ => _summaryStage(r, open),
            };
          }(),
        ],
      ],
    );
  }

  Widget _methodStage(SimulationResult r, List<int> open) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeading(AppStrings.securingMethodStageTitle),
          SecuringMethodSelector(
            result: r,
            placementId: widget.placement.id,
            vehicle: widget.vehicle,
          ),
          // How the chocks are laid out is a separate decision from which
          // method is used — the plates draw several arrangements for the
          // same method — so it is chosen here, in the same stage.
          ChockArrangementSelector(
            placementId: widget.placement.id,
            vehicle: widget.vehicle,
          ),
          AppSpace.gapLg,
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed:
                  r.requiredHardwareIds.isNotEmpty ? () => _step(open, 1) : null,
              child: const Text(AppStrings.proceedToEquipmentButton),
            ),
          ),
        ],
      );

  Widget _equipmentStage(SimulationResult r, List<int> open) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (open.first != 1)
            TextButton(
              onPressed: () => _step(open, -1),
              child: const Text(AppStrings.backToMethodStage, style: TextStyle(fontSize: AppText.bodySmall)),
            ),
          const SectionHeading(AppStrings.equipmentStageTitle),
          EquipmentConfigurationWizard(
            result: r,
            placementId: widget.placement.id,
            vehicle: widget.vehicle,
          ),
          // Only where the configuration uses wire: a vehicle secured with
          // clamps has no lashing whose angles could be measured.
          if (r.requiredHardwareIds.contains('att-wire-lashing'))
            LashingAngleEntry(placementId: widget.placement.id),
          AppSpace.gapLg,
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: () => _step(open, 1),
              child: const Text(AppStrings.proceedToVisualButton),
            ),
          ),
        ],
      );

  Widget _summaryStage(SimulationResult r, List<int> open) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (open.length > 1)
            TextButton(
              onPressed: () => _step(open, -1),
              child: const Text(AppStrings.backToEquipmentStage, style: TextStyle(fontSize: AppText.bodySmall)),
            )
          else ...[
            // Nothing was asked because the placement already answered it.
            // Say so plainly, and leave a way back in: a derived answer is
            // still the trainee's to change.
            const Text(
              AppStrings.securingAnsweredByPlacement,
              style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () => setState(() {
                  _revising = true;
                  _stage = 0;
                }),
                child: const Text(AppStrings.securingReviseAnswers,
                    style: TextStyle(fontSize: AppText.bodySmall)),
              ),
            ),
          ],
          const SectionHeading(AppStrings.visualStageTitle),
          ConfigurationSummaryPanel(
            vehicle: widget.vehicle,
            platform: widget.platform,
            result: r,
            placementId: widget.placement.id,
          ),
          AppSpace.gapLg,
          // What to draw from stores, worked out from the method and the
          // layout case: the arithmetic the handbook's tables exist for.
          ConsumablesPanel(
            placementId: widget.placement.id,
            vehicle: widget.vehicle,
            requiredHardwareIds: r.requiredHardwareIds,
          ),
          AppSpace.gapXl,
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(
              onPressed: () => context.go('/analysis'),
              child: const Text(AppStrings.securingToAnalysisButton),
            ),
          ),
        ],
      );
}
