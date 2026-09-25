import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_photo.dart';
import '../../../domain/usecases/handbook_photo_resolution.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/common/instrument.dart';
import '../../widgets/photos/handbook_photo_thumbnail.dart';
import '../../widgets/photos/vehicle_photo_thumbnail.dart';

/// The new first step of vehicle selection: large category cards, one per
/// `Vehicle.category` value actually present in the loaded handbook data
/// — never a fabricated category, and never more than the extract
/// actually contains (today that is exactly one: tracked).
class VehicleCategoryScreen extends ConsumerWidget {
  const VehicleCategoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final linkerAsync = ref.watch(referenceLinkerProvider);
    final vehiclePhotosAsync = ref.watch(vehiclePhotosProvider);

    return InstrumentScaffold(
      title: AppStrings.vehicleCategoryScreenTitle,
      step: 1,
      onBack: () => context.go('/consist'),
      body: vehiclesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(AppStrings.failedToLoadVehicles(e))),
        data: (vehicles) {
          final categories = <VehicleCategory>[];
          for (final v in vehicles) {
            if (!categories.contains(v.category)) categories.add(v.category);
          }
          categories.sort((a, b) => a.index.compareTo(b.index));
          final linker = linkerAsync.valueOrNull;

          return SingleChildScrollView(
            padding: AppSpace.screen,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: categories.map((category) {
                  final inCategory = vehicles.where((v) => v.category == category).toList();
                  // Only a genuine vehicle identification photo may
                  // represent the category — never a securing-equipment or
                  // procedure figure that merely shares one vehicle's
                  // citation (see handbook_photo_resolution.dart). None
                  // exist in the current extract, so this is null today.
                  HandbookPhoto? photo;
                  if (linker != null) {
                    for (final v in inCategory) {
                      final candidate = vehicleIdentificationPhotoFor(v, linker);
                      if (candidate != null) {
                        photo = candidate;
                        break;
                      }
                    }
                  }
                  // With no handbook figure available, the category is shown
                  // by an illustrative photograph of the first vehicle in it
                  // that has one — badged as illustrative, and paired with
                  // that vehicle's designation so the picture is never read
                  // as "what every vehicle in this category looks like".
                  VehiclePhoto? illustrative;
                  String illustrativeDesignation = '';
                  final photosById = vehiclePhotosAsync.valueOrNull;
                  if (photo == null && photosById != null) {
                    for (final v in inCategory) {
                      final candidate = photosById[v.id];
                      if (candidate != null) {
                        illustrative = candidate;
                        illustrativeDesignation = v.handbookDesignation;
                        break;
                      }
                    }
                  }
                    return _CategoryPlate(
                      category: category,
                      count: inCategory.length,
                      photo: photo,
                      illustrativePhoto: illustrative,
                      illustrativeDesignation: illustrativeDesignation,
                      onTap: () {
                        ref.read(selectedVehicleCategoryProvider.notifier).state = category;
                        context.go('/vehicles');
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// One category, as a specimen plate.
///
/// The photograph across the full width of the plate, the name lettered under
/// it, the count as a reading, and the whole plate as the control — a filled
/// button inside a plate that is itself clickable is two controls for one
/// action, and the lit fill would spend the instrument's colour on something
/// that has not been measured.
class _CategoryPlate extends StatefulWidget {
  final VehicleCategory category;
  final int count;
  final HandbookPhoto? photo;
  final VehiclePhoto? illustrativePhoto;
  final String illustrativeDesignation;
  final VoidCallback onTap;

  const _CategoryPlate({
    required this.category,
    required this.count,
    required this.photo,
    required this.illustrativePhoto,
    required this.illustrativeDesignation,
    required this.onTap,
  });

  @override
  State<_CategoryPlate> createState() => _CategoryPlateState();
}

class _CategoryPlateState extends State<_CategoryPlate> {
  bool _hover = false;

  static const double _photoWidth = 300;
  static const double _photoHeight = 170;

  @override
  Widget build(BuildContext context) {
    final lit = _hover;
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
            color: lit ? AppColors.panel : Colors.transparent,
            border: const Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(
                width: _photoWidth,
                height: _photoHeight,
                child: widget.photo != null
                    ? HandbookPhotoThumbnail(
                        photo: widget.photo!,
                        width: _photoWidth,
                        height: _photoHeight,
                      )
                    : widget.illustrativePhoto != null
                        ? VehiclePhotoThumbnail(
                            photo: widget.illustrativePhoto!,
                            designation: widget.illustrativeDesignation,
                            width: _photoWidth,
                            height: _photoHeight,
                          )
                        : ColoredBox(
                            color: AppColors.well,
                            child: Center(
                              child: Icon(
                                widget.category == VehicleCategory.tracked
                                    ? Icons.linear_scale
                                    : Icons.airline_seat_recline_normal,
                                size: 60,
                                color: AppColors.instrumentDeep,
                              ),
                            ),
                          ),
              ),
              const SizedBox(width: AppSpace.xl),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      AppStrings.vehicleCategoryLabel(widget.category).toUpperCase(),
                      style: AppText.legend(
                        size: AppText.cardTitle,
                        color: lit ? AppColors.instrumentGlow : AppColors.textPrimary,
                        tracking: AppText.trackTitle,
                      ),
                    ),
                    AppSpace.gapMd,
                    Readout(
                      label: AppStrings.breadcrumbTehnika,
                      value: widget.count.toString().padLeft(2, '0'),
                      valueColor: lit ? AppColors.instrumentGlow : AppColors.textPrimary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpace.xl),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    AppStrings.vehicleCategorySelectButton.toUpperCase(),
                    style: AppText.legend(
                      size: AppText.caption,
                      color: lit ? AppColors.instrument : AppColors.labelDim,
                      tracking: 1.6,
                    ),
                  ),
                  const SizedBox(width: AppSpace.sm),
                  AnimatedSlide(
                    duration: AppMotion.touch,
                    offset: Offset(lit ? 0.3 : 0, 0),
                    child: Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: lit ? AppColors.instrument : AppColors.labelDim,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: AppSpace.sm),
            ],
          ),
        ),
      ),
    );
  }
}
