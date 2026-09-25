import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_photo.dart';
import '../../../domain/models/train_consist.dart';
import '../../../domain/usecases/handbook_photo_resolution.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/cards/vehicle_card.dart';
import '../../widgets/common/vehicle_detail_dialog.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/instrument.dart';

/// Step 2 of the loading flow: which vehicles are being loaded, and how many
/// of each.
///
/// Tapping a card adds one more of that designation rather than selecting a
/// single vehicle and moving on — the interaction the customer brief asks for
/// on slide 3 ("näçe gezek bassa şonçada ... awtomat köpelmeli"), with a
/// running per-type total beside it.
///
/// Only vehicles in the category chosen on `VehicleCategoryScreen` are shown,
/// falling back to every vehicle if the user somehow lands here without a
/// category — never an empty dead end.
class VehicleSelectionScreen extends ConsumerStatefulWidget {
  const VehicleSelectionScreen({super.key});

  @override
  ConsumerState<VehicleSelectionScreen> createState() => _VehicleSelectionScreenState();
}

class _VehicleSelectionScreenState extends ConsumerState<VehicleSelectionScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final attachmentsAsync = ref.watch(attachmentTypesProvider);
    final linkerAsync = ref.watch(referenceLinkerProvider);
    final vehiclePhotosAsync = ref.watch(vehiclePhotosProvider);
    final categoryFilter = ref.watch(selectedVehicleCategoryProvider);
    final orders = ref.watch(vehicleOrdersProvider);

    return InstrumentScaffold(
      title: categoryFilter == null
          ? AppStrings.vehicleOrderTitle
          : AppStrings.vehicleSelectionTitleForCategory(
              AppStrings.vehicleCategoryLabel(categoryFilter)),
      step: 1,
      onBack: () => context.go('/vehicle-categories'),
      footer: AdvanceButton(
        label: AppStrings.vehicleOrderNextButton,
        onPressed: orders.isEmpty ? null : () => context.go('/wagon-type'),
        blockedReason: orders.isEmpty ? AppStrings.vehicleOrderEmpty : null,
      ),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(AppStrings.failedToLoadVehicles(e))),
        data: (vehicles) {
          final byId = {for (final v in vehicles) v.id: v};
          final filtered = vehicles.where((v) {
            final matchesQuery = _query.isEmpty ||
                v.handbookDesignation.toLowerCase().contains(_query.toLowerCase());
            final matchesCategory = categoryFilter == null || v.category == categoryFilter;
            return matchesQuery && matchesCategory;
          }).toList();

          final grid = _VehicleGrid(
            vehicles: filtered,
            quantityOf: (id) => ref.read(vehicleOrdersProvider.notifier).quantityOf(id),
            onAdd: (v) => ref.read(vehicleOrdersProvider.notifier).add(v.id),
            onInfo: (v) => showVehicleDetailDialog(
              context,
              vehicle: v,
              allAttachments: attachmentsAsync.valueOrNull ?? const [],
              relatedPhotos: linkerAsync.valueOrNull?.photosFor(v.referenceId) ?? const [],
              identificationPhoto: linkerAsync.valueOrNull == null
                  ? null
                  : vehicleIdentificationPhotoFor(v, linkerAsync.value!),
              illustrativePhoto: vehiclePhotosAsync.valueOrNull?[v.id],
              ownPhotos: ref.watch(vehicleAdminPhotosProvider)[v.id] ?? const {},
            ),
            identificationPhotoFor: (v) => linkerAsync.valueOrNull == null
                ? null
                : vehicleIdentificationPhotoFor(v, linkerAsync.value!),
            illustrativePhotoFor: (v) => vehiclePhotosAsync.valueOrNull?[v.id],
          );

          final summary = _OrderSummary(
            orders: orders,
            vehiclesById: byId,
            onAdd: (id) => ref.read(vehicleOrdersProvider.notifier).add(id),
            onRemove: (id) => ref.read(vehicleOrdersProvider.notifier).removeOne(id),
          );

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.lg, AppSpace.xxl, AppSpace.md),
                child: TextField(
                  style: AppText.prose(),
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search, size: 20, color: AppColors.labelDim),
                    hintText: AppStrings.searchByDesignationHint,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth < 900) {
                      return Column(
                        children: [
                          Expanded(child: grid),
                          SizedBox(height: 220, child: summary),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(child: grid),
                        SizedBox(width: 320, child: summary),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _VehicleGrid extends StatelessWidget {
  final List<Vehicle> vehicles;
  final int Function(String vehicleId) quantityOf;
  final void Function(Vehicle) onAdd;
  final void Function(Vehicle) onInfo;
  final HandbookPhoto? Function(Vehicle) identificationPhotoFor;
  final VehiclePhoto? Function(Vehicle) illustrativePhotoFor;

  const _VehicleGrid({
    required this.vehicles,
    required this.quantityOf,
    required this.onAdd,
    required this.onInfo,
    required this.identificationPhotoFor,
    required this.illustrativePhotoFor,
  });

  @override
  Widget build(BuildContext context) {
    if (vehicles.isEmpty) {
      return const EmptyField(
        legend: AppStrings.vehicleSelectionTitle,
        message: AppStrings.noVehiclesMatchFilter,
      );
    }
    // A ruled list, not a grid of tiles. The catalogue is thirty-two machines
    // read by name, and a name that starts at a different height in every tile
    // cannot be scanned down a column.
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(AppSpace.xxl, 0, AppSpace.xxl, AppSpace.xl),
      itemCount: vehicles.length,
      itemBuilder: (context, i) {
        final v = vehicles[i];
        final quantity = quantityOf(v.id);
        return Stack(
          children: [
            VehicleCard(
              vehicle: v,
              photo: identificationPhotoFor(v),
              illustrativePhoto: illustrativePhotoFor(v),
              selected: quantity > 0,
              onTap: () => onAdd(v),
              onInfoTap: () => onInfo(v),
            ),
            if (quantity > 0)
              Positioned(
                top: AppSpace.md,
                left: AppSpace.sm,
                child: _QuantityBadge(quantity: quantity),
              ),
          ],
        );
      },
    );
  }
}

class _QuantityBadge extends StatelessWidget {
  final int quantity;
  const _QuantityBadge({required this.quantity});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: 3),
      color: AppColors.instrument,
      child: Text(
        '×$quantity',
        style: AppText.value(size: AppText.readoutSmall, color: AppColors.ground),
      ),
    );
  }
}

class _OrderSummary extends StatelessWidget {
  final List<VehicleOrder> orders;
  final Map<String, Vehicle> vehiclesById;
  final void Function(String vehicleId) onAdd;
  final void Function(String vehicleId) onRemove;

  const _OrderSummary({
    required this.orders,
    required this.vehiclesById,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final total = orders.fold<int>(0, (sum, o) => sum + o.quantity);
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
            AppStrings.vehicleOrderSummaryTitle,
            note: AppStrings.vehicleOrderSubtitle,
            live: orders.isNotEmpty,
          ),
          Expanded(
            child: orders.isEmpty
                ? Align(
                    alignment: Alignment.topLeft,
                    child: Text(
                      AppStrings.vehicleOrderEmpty,
                      style: AppText.prose(size: AppText.bodySmall, color: AppColors.labelDim),
                    ),
                  )
                : ListView.builder(
                    itemCount: orders.length,
                    itemBuilder: (context, i) {
                      final order = orders[i];
                      final vehicleId = order.vehicleId;
                      // A designation the catalogue no longer knows is shown
                      // by its id rather than dropped silently.
                      final designation =
                          vehiclesById[vehicleId]?.handbookDesignation ?? vehicleId;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppSpace.xs),
                        child: Row(
                          children: [
                            Expanded(
                              child: Readout(
                                label: designation,
                                value: order.quantity.toString().padLeft(2, '0'),
                                valueColor: AppColors.instrumentGlow,
                                dense: true,
                              ),
                            ),
                            const SizedBox(width: AppSpace.sm),
                            _TallyKey(
                              icon: Icons.remove,
                              tooltip: AppStrings.vehicleOrderRemove,
                              onTap: () => onRemove(vehicleId),
                            ),
                            const SizedBox(width: AppSpace.xs),
                            _TallyKey(
                              icon: Icons.add,
                              tooltip: AppStrings.vehicleOrderAdd,
                              onTap: () => onAdd(vehicleId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          const Divider(),
          Readout(
            label: AppStrings.vehicleOrderTotalLabel,
            value: total.toString().padLeft(2, '0'),
            valueColor: total > 0 ? AppColors.instrumentGlow : AppColors.labelDim,
          ),
        ],
      ),
    );
  }
}

/// A small square key beside a tally line.
class _TallyKey extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _TallyKey({required this.icon, required this.tooltip, required this.onTap});

  @override
  State<_TallyKey> createState() => _TallyKeyState();
}

class _TallyKeyState extends State<_TallyKey> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AppMotion.touch,
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hover ? AppColors.instrument.withValues(alpha: 0.12) : Colors.transparent,
              border: Border.all(
                color: _hover ? AppColors.instrument : AppColors.hairlineBright,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 15,
              color: _hover ? AppColors.instrument : AppColors.label,
            ),
          ),
        ),
      ),
    );
  }
}
