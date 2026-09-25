import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/usecases/securing_hardware_catalog.dart';
import '../../../domain/usecases/vehicle_mesh_builder.dart';
import '../../../domain/usecases/vehicle_mesh_catalog.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/handbook_reference_chip.dart';
import '../../widgets/common/instrument.dart';
import '../../widgets/photos/handbook_photo_thumbnail.dart';

/// Step 5: the gear, ordered the way the vehicles were.
///
/// Until now the only way to reach a piece of securing gear was a dropdown
/// inside the three-dimensional view, one at a time, while looking at the
/// wagon. That is the right place to *seat* a piece and the wrong place to
/// decide what is needed: a trainee had no page on which to look at the
/// handbook's gear, see what each piece is, and say how many of it the load
/// takes.
///
/// This is that page, and it is deliberately the same shape as the vehicle
/// step — a ruled list, a picture of each item, a count against it, a tally
/// down the right — because it is the same act one step later in the
/// operation.
///
/// What it does not do is decide anything. The handbook's own tables fix the
/// sizes, the figures show what each piece looks like, and the count is the
/// trainee's answer. Nothing here is pre-filled and nothing is withheld: every
/// row the tables state a size for is offered, with the row this vehicle's
/// record resolves marked, so a trainee can compare the real alternatives
/// rather than being handed one.
class EquipmentSelectionScreen extends ConsumerWidget {
  const EquipmentSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consist = ref.watch(consistProvider);
    final orders = ref.watch(equipmentOrdersProvider);
    final vehicles = ref.watch(effectiveVehiclesProvider);
    final measurements = ref.watch(measurementsProvider).valueOrNull;
    final rules = ref.watch(rulesProvider).valueOrNull;
    final attachments = ref.watch(attachmentTypesProvider).valueOrNull ?? const [];
    final linker = ref.watch(referenceLinkerProvider).valueOrNull;

    // Everything the vehicles actually on the wagons can be secured with. A
    // wheeled load and a tracked one do not take the same gear, so the list is
    // the union of what each placed vehicle's own tables offer.
    final byId = {for (final v in vehicles) v.id: v};
    final placed = <Vehicle>[];
    for (final placement in consist.placements) {
      final vehicle = byId[placement.vehicleId];
      if (vehicle != null && !placed.any((v) => v.id == vehicle.id)) {
        placed.add(vehicle);
      }
    }

    final hardware = <PlaceableHardware>[];
    final seen = <String>{};
    if (measurements != null && rules != null) {
      for (final vehicle in placed) {
        final spec = VehicleMeshCatalog.specFor(vehicle);
        for (final piece in placeableHardwareFor(
          vehicle: vehicle,
          measurements: measurements,
          rules: rules,
          attachments: attachments,
          trackShoeWidthM: spec is TrackedVehicleMeshSpec ? spec.trackShoeWidthM : 0.58,
        )) {
          if (seen.add(EquipmentOrdersNotifier.keyFor(piece.kind, piece.typeCode))) {
            hardware.add(piece);
          }
        }
      }
    }

    final total = orders.values.fold<int>(0, (sum, n) => sum + n);

    return InstrumentScaffold(
      title: AppStrings.equipmentSelectionTitle,
      subtitle: AppStrings.equipmentSelectionSubtitle,
      step: 4,
      onBack: () => context.go('/placement'),
      footer: AdvanceButton(
        label: AppStrings.equipmentNextButton,
        // Dark while there is nothing on a wagon, for the same reason every
        // other step's control is: the securing step has nothing to work on
        // either, and a lit control on a screen that has just said "place a
        // vehicle first" invites the trainee to walk into an empty room.
        onPressed: placed.isEmpty ? null : () => context.go('/securing'),
        blockedReason: placed.isEmpty ? AppStrings.placementNothingPlaced : null,
      ),
      body: placed.isEmpty
          ? EmptyField(
              legend: AppStrings.equipmentSelectionTitle,
              message: AppStrings.placementNothingPlaced,
              actionLabel: AppStrings.breadcrumbPlacement,
              onAction: () => context.go('/placement'),
            )
          : hardware.isEmpty
              ? const EmptyField(
                  legend: AppStrings.equipmentSelectionTitle,
                  message: AppStrings.scene3dHardwareEmpty,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final ownPhotos = ref.watch(gearPhotosProvider);
                    final list = ListView.builder(
                      padding: const EdgeInsets.fromLTRB(
                          AppSpace.xxl, AppSpace.md, AppSpace.xxl, AppSpace.xl),
                      itemCount: hardware.length,
                      itemBuilder: (context, i) {
                        final piece = hardware[i];
                        final key = EquipmentOrdersNotifier.keyFor(
                            piece.kind, piece.typeCode);
                        return _EquipmentRow(
                          piece: piece,
                          count: orders[key] ?? 0,
                          figures: _figuresFor(piece, linker),
                          ownPhoto: ownPhotos[piece.kind],
                          onAdd: () =>
                              ref.read(equipmentOrdersProvider.notifier).add(key),
                          onRemove: () => ref
                              .read(equipmentOrdersProvider.notifier)
                              .removeOne(key),
                        );
                      },
                    );

                    if (constraints.maxWidth < 1000) return list;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: list),
                        SizedBox(
                          width: 340,
                          child: _EquipmentTally(
                            orders: orders,
                            hardware: hardware,
                            total: total,
                          ),
                        ),
                      ],
                    );
                  },
                ),
    );
  }

  /// The handbook's figures for a piece, in the order the piece names them.
  static List<HandbookPhoto> _figuresFor(PlaceableHardware piece, dynamic linker) {
    if (linker == null) return const [];
    final out = <HandbookPhoto>[];
    final seen = <String>{};
    for (final referenceId in piece.figureReferenceIds) {
      for (final photo in linker.photosFor(referenceId) as List<HandbookPhoto>) {
        if (seen.add(photo.id)) out.add(photo);
      }
    }
    return out;
  }
}

/// One piece of gear: what it looks like, what the table says it is, and how
/// many of it the trainee wants.
class _EquipmentRow extends StatefulWidget {
  final PlaceableHardware piece;
  final int count;
  final List<HandbookPhoto> figures;

  /// The instructor's own photograph of this kind of gear, when they added
  /// one. Drawn instead of the handbook figure.
  final String? ownPhoto;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _EquipmentRow({
    required this.piece,
    required this.count,
    required this.figures,
    required this.onAdd,
    required this.onRemove,
    this.ownPhoto,
  });

  @override
  State<_EquipmentRow> createState() => _EquipmentRowState();
}

class _EquipmentRowState extends State<_EquipmentRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final piece = widget.piece;
    final chosen = widget.count > 0;
    final lit = chosen || _hover;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: AnimatedContainer(
        duration: AppMotion.touch,
        padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
        decoration: BoxDecoration(
          color: chosen
              ? AppColors.instrument.withValues(alpha: 0.07)
              : _hover
                  ? AppColors.panel
                  : Colors.transparent,
          border: const Border(top: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The handbook's own picture of the piece, first, because it is
            // what tells a trainee which thing this row is.
            SizedBox(
              width: 132,
              child: widget.ownPhoto != null
                  ? Image.file(File(widget.ownPhoto!),
                      width: 132,
                      height: 84,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 132))
                  : widget.figures.isEmpty
                  ? Container(
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.well,
                        border: Border.all(color: AppColors.hairline),
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.image_not_supported_outlined,
                          size: 20, color: AppColors.labelDim),
                    )
                  : HandbookPhotoThumbnail(
                      photo: widget.figures.first, width: 132, height: 84),
            ),
            const SizedBox(width: AppSpace.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.scene3dPieceKindLabel(piece.kind.name).toUpperCase(),
                    style: AppText.legend(
                      size: AppText.cardTitle,
                      color: lit ? AppColors.instrumentGlow : AppColors.textPrimary,
                      tracking: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xs),
                  Wrap(
                    spacing: AppSpace.sm,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        piece.typeCode,
                        style: AppText.value(
                          size: AppText.readoutSmall,
                          color: AppColors.label,
                        ),
                      ),
                      if (piece.matchesVehicle)
                        const VerdictChip(
                          tone: AppTone.pass,
                          label: AppStrings.equipmentMatchesVehicle,
                          dense: true,
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  Text(
                    AppStrings.scene3dHardwareSize(
                      (piece.heightM * 1000).round(),
                      (piece.widthM * 1000).round(),
                      (piece.lengthM * 1000).round(),
                    ),
                    style: AppText.value(
                        size: AppText.caption, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: AppSpace.sm),
                  HandbookReferenceChip(referenceId: piece.referenceId),
                ],
              ),
            ),
            const SizedBox(width: AppSpace.lg),
            _CountKeys(
              count: widget.count,
              onAdd: widget.onAdd,
              onRemove: widget.onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

/// The − n + control, squared like every other key on this instrument.
class _CountKeys extends StatelessWidget {
  final int count;
  final VoidCallback onAdd;
  final VoidCallback onRemove;

  const _CountKeys({
    required this.count,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _Key(
          icon: Icons.remove,
          tooltip: AppStrings.equipmentRemoveOne,
          onTap: count > 0 ? onRemove : null,
        ),
        SizedBox(
          width: 58,
          child: Text(
            count.toString().padLeft(2, '0'),
            textAlign: TextAlign.center,
            style: AppText.value(
              size: AppText.readout,
              color: count > 0 ? AppColors.instrumentGlow : AppColors.labelDim,
            ),
          ),
        ),
        _Key(icon: Icons.add, tooltip: AppStrings.equipmentAddOne, onTap: onAdd),
      ],
    );
  }
}

class _Key extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  const _Key({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : SystemMouseCursors.basic,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.touch,
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: enabled && _hover
                  ? AppColors.instrument.withValues(alpha: 0.10)
                  : AppColors.well,
              border: Border.all(
                color: enabled && _hover
                    ? AppColors.instrument
                    : AppColors.hairlineBright,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 20,
              color: !enabled
                  ? AppColors.labelDim
                  : _hover
                      ? AppColors.instrumentGlow
                      : AppColors.label,
            ),
          ),
        ),
      ),
    );
  }
}

/// What has been ordered so far, down the right edge.
class _EquipmentTally extends StatelessWidget {
  final Map<String, int> orders;
  final List<PlaceableHardware> hardware;
  final int total;

  const _EquipmentTally({
    required this.orders,
    required this.hardware,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final rows = <ReadoutRow>[];
    for (final piece in hardware) {
      final key = EquipmentOrdersNotifier.keyFor(piece.kind, piece.typeCode);
      final count = orders[key] ?? 0;
      if (count == 0) continue;
      rows.add(ReadoutRow(
        label:
            '${AppStrings.scene3dPieceKindLabel(piece.kind.name)} ${piece.typeCode}',
        value: count.toString().padLeft(2, '0'),
        valueColor: AppColors.instrumentGlow,
      ));
    }

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
            AppStrings.equipmentTallyHeading,
            note: AppStrings.equipmentTallyNote,
            live: rows.isNotEmpty,
          ),
          Expanded(
            child: rows.isEmpty
                ? Text(
                    AppStrings.equipmentTallyEmpty,
                    style: AppText.prose(
                        size: AppText.bodySmall, color: AppColors.labelDim),
                  )
                : SingleChildScrollView(
                    child: ReadoutTable(dense: true, rows: rows),
                  ),
          ),
          const Divider(),
          ReadoutTable(rows: [
            ReadoutRow(
              label: AppStrings.equipmentTallyTotal,
              value: total.toString().padLeft(2, '0'),
              valueColor:
                  total > 0 ? AppColors.instrumentGlow : AppColors.labelDim,
            ),
          ]),
        ],
      ),
    );
  }
}
