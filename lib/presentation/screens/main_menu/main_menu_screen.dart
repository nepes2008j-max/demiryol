import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_field.dart';
import '../../../domain/models/scene3d.dart';
import '../../../domain/models/securing_placement.dart';
import '../../../domain/usecases/flatcar_mesh_builder.dart';
import '../../../domain/usecases/loading_scene_builder.dart';
import '../../../domain/usecases/scene3d_camera.dart';
import '../../../domain/usecases/scene3d_raster.dart';
import '../../../domain/usecases/vehicle_mesh_builder.dart';
import '../../../domain/usecases/vehicle_mesh_catalog.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/common/instrument.dart';
import '../../widgets/common/trainee_dialog.dart';
import '../../widgets/visualization/scene3d_painter.dart';

/// The instrument at rest.
///
/// The opening screen states the thesis of the whole program in one view: a
/// flatcar drawn to scale on the measured field, dimensioned, with the load
/// gauge over it — and the two ways in. Nothing here is decoration; the plate
/// is the same kind of drawing the trainee is about to work on, and the
/// lettering around it is the same lettering the rest of the instrument uses.
class MainMenuScreen extends ConsumerWidget {
  const MainMenuScreen({super.key});

  /// Starting an attempt clears whatever the last one left behind and asks who
  /// is sitting this one. Both, in that order, every time: the trainer is used
  /// as a test, and a test that begins half-finished with the previous
  /// candidate's name on it is not a test.
  Future<void> _begin(BuildContext context, WidgetRef ref) async {
    resetAttempt(ref);
    final named = await showTraineeDialog(context, ref);
    if (!named || !context.mounted) return;
    context.go('/consist');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.ground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1180;
          const plate = _TitlePlate();
          final panel = _EntryPanel(onBegin: () => _begin(context, ref));

          return Padding(
            padding: const EdgeInsets.all(AppSpace.xxl),
            child: wide
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Expanded(flex: 7, child: plate),
                      const SizedBox(width: AppSpace.xxl),
                      SizedBox(width: 420, child: panel),
                    ],
                  )
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 320, child: plate),
                        const SizedBox(height: AppSpace.xxl),
                        panel,
                      ],
                    ),
                  ),
          );
        },
      ),
    );
  }
}

/// The plate: the program's own drawing of a loaded flatcar, on the measured
/// field, with the chrome a loading plate carries.
///
/// The vehicle and the wagon are not illustrations of the subject — they are
/// the subject, built by the same code the placement screen uses, from the
/// same recorded dimensions, and rendered by the same rasteriser. What is
/// drawn over them is the measurement: the graticule, the loading gauge, and
/// the length dimension under the wagon.
class _TitlePlate extends ConsumerWidget {
  const _TitlePlate();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehicles = ref.watch(vehiclesProvider).valueOrNull;
    // The T-72 is the catalogue's fully dimensioned tracked vehicle, and the
    // one the trainee is most likely to meet first.
    final vehicle = vehicles?.where((v) => v.id == 'veh-t72').firstOrNull;
    final spec = vehicle == null ? null : VehicleMeshCatalog.specFor(vehicle);
    final fitted = ref.watch(vehicleMeshProvider('veh-t72')).valueOrNull;

    return Container(
      clipBehavior: Clip.hardEdge,
      decoration: const BoxDecoration(
        color: AppColors.well,
        border: Border.fromBorderSide(BorderSide(color: AppColors.hairline)),
      ),
      child: Stack(
        children: [
          Positioned.fill(child: CustomPaint(painter: _FieldPainter())),
          if (spec != null)
            Positioned.fill(
              bottom: 96,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 48, 40, 0),
                child: _WagonRender(
                  spec: spec,
                  meshOverride: fitted?.model.mesh,
                  designation: vehicle!.handbookDesignation,
                ),
              ),
            ),
          Positioned(
            left: AppSpace.lg,
            top: AppSpace.md,
            child: Text(
              'PLATFORMA — ÝÜKLENEN GÖRNÜŞ',
              style: AppText.legend(size: AppText.tick, color: AppColors.labelDim, tracking: 2.0),
            ),
          ),
          if (vehicle != null)
            Positioned(
              left: AppSpace.lg,
              right: AppSpace.lg,
              bottom: AppSpace.lg,
              // The readings under the drawing are the record's own, or the
              // handbook's "not stated" — never a number this screen made up
              // to have something to show.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(width: 3, height: 13, color: AppColors.instrument),
                      const SizedBox(width: AppSpace.sm),
                      Text(
                        vehicle.handbookDesignation.toUpperCase(),
                        style: AppText.legend(size: AppText.caption, color: AppColors.label, tracking: 1.8),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      _PlateReading(label: AppStrings.lengthLabel, field: vehicle.lengthCm, unit: 'sm'),
                      _PlateReading(label: AppStrings.widthLabel, field: vehicle.widthCm, unit: 'sm'),
                      _PlateReading(label: AppStrings.heightLabel, field: vehicle.heightCm, unit: 'sm'),
                      _PlateReading(label: AppStrings.weightLabel, field: vehicle.bracketWeightT, unit: 't'),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// The scene itself, rasterised once at a fixed size and scaled to the plate.
///
/// Rendering is the same call the placement screen makes; doing it at a fixed
/// size and letting [FittedBox] scale the result keeps the opening screen from
/// re-projecting a hundred thousand triangles on every window resize.
class _WagonRender extends StatelessWidget {
  final VehicleMeshSpec spec;
  final Mesh3? meshOverride;
  final String designation;

  const _WagonRender({
    required this.spec,
    required this.meshOverride,
    required this.designation,
  });

  static const double _w = 1200;
  static const double _h = 500;

  @override
  Widget build(BuildContext context) {
    final scene = buildLoadedWagonScene(
      loads: [
        PlacedLoad(
          placementId: 'menu',
          designation: designation,
          spec: spec,
          positionFraction: 0.5,
          turretTraverse: 0,
          securing: SecuringLayout.empty,
          meshOverride: meshOverride,
        ),
      ],
      flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      // No track bed on the opening plate: the ballast wedge is a long grey
      // mass that carries no measurement, and the wagon reads better standing
      // on the measured field itself.
      includeTrackBed: false,
      includeVehicles: true,
    );
    final camera = Camera3.framing(
      scene.flatcar.mesh.bounds.union(scene.loadBounds),
      yaw: 0.62,
      pitch: 0.26,
      aspectRatio: _w / _h,
    );
    final frame = SceneRaster.render(
      RasterMesh.from(scene.mesh),
      camera: camera,
      width: _w,
      height: _h,
      colorOf: (m) => Scene3Painter.materialColor(m).toARGB32() & 0x00FFFFFF,
    );
    if (frame == null) return const SizedBox.shrink();
    return FittedBox(
      fit: BoxFit.contain,
      child: SizedBox(
        width: _w,
        height: _h,
        child: CustomPaint(painter: RasterScenePainter(frame)),
      ),
    );
  }
}

/// One reading under the opening plate.
class _PlateReading extends StatelessWidget {
  final String label;
  final HandbookField field;
  final String unit;

  const _PlateReading({required this.label, required this.field, required this.unit});

  @override
  Widget build(BuildContext context) {
    final known = field.isAvailable;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpace.xxl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: AppText.legend(
              size: AppText.tick,
              color: AppColors.labelDim,
              weight: FontWeight.w400,
              tracking: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            known ? field.display(unit: unit) : field.displayCompact(),
            style: AppText.value(
              size: AppText.readoutSmall,
              color: known ? AppColors.instrumentGlow : AppColors.offNominal,
            ),
          ),
        ],
      ),
    );
  }
}

/// The graticule: the measured field the drawing is laid on.
class _FieldPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.hairline.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 40) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y < size.height; y += 40) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
  }

  @override
  bool shouldRepaint(_FieldPainter oldDelegate) => false;
}

class _EntryPanel extends StatelessWidget {
  final VoidCallback onBegin;
  const _EntryPanel({required this.onBegin});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldEntrance(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.mainMenuHeading,
              style: AppText.legend(
                size: AppText.display,
                color: AppColors.textPrimary,
                tracking: 1.0,
              ).copyWith(height: 1.18),
            ),
            const SizedBox(height: AppSpace.lg),
            Text(
              AppStrings.mainMenuSubtitle,
              style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary, height: 1.55),
            ),
            const SizedBox(height: AppSpace.xxl),
            // The two ways in are alternatives, not a sequence, so neither
            // carries a number. The stage index numbers its steps because
            // those really do run in order.
            _Entry(
              label: AppStrings.startSimulationButton,
              lit: true,
              onTap: onBegin,
            ),
            _Entry(
              label: AppStrings.referenceBrowserButton,
              lit: false,
              onTap: () => context.push('/reference'),
            ),
            const SizedBox(height: AppSpace.xxl),
            Text(
              AppStrings.mainMenuSource,
              style: AppText.prose(size: AppText.tick, color: AppColors.labelDim, height: 1.5),
            ),
          ],
        ),
      ],
    );
  }
}

/// A way in, lettered as a line on the instrument's face rather than as a
/// button: a number, a rule, a word, and the light arriving on hover.
class _Entry extends StatefulWidget {
  final String label;
  final bool lit;
  final VoidCallback onTap;

  const _Entry({
    required this.label,
    required this.lit,
    required this.onTap,
  });

  @override
  State<_Entry> createState() => _EntryState();
}

class _EntryState extends State<_Entry> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover || widget.lit;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.touch,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
          decoration: BoxDecoration(
            color: _hover ? AppColors.instrument.withValues(alpha: 0.06) : Colors.transparent,
            border: const Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              const SizedBox(width: AppSpace.sm),
              AnimatedContainer(
                duration: AppMotion.touch,
                width: 3,
                height: AppText.label,
                color: active ? AppColors.instrument : AppColors.hairlineBright,
              ),
              const SizedBox(width: AppSpace.lg),
              Expanded(
                child: Text(
                  widget.label,
                  style: AppText.legend(
                    size: AppText.label,
                    color: active ? AppColors.instrumentGlow : AppColors.label,
                    tracking: 1.2,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              AnimatedSlide(
                duration: AppMotion.touch,
                offset: Offset(_hover ? 0.25 : 0, 0),
                child: Icon(
                  Icons.arrow_forward,
                  size: 18,
                  color: active ? AppColors.instrument : AppColors.labelDim,
                ),
              ),
              const SizedBox(width: AppSpace.sm),
            ],
          ),
        ),
      ),
    );
  }
}
