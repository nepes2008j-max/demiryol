import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_photo.dart';
import '../../../domain/usecases/securing_method_status.dart';
import '../common/data_completeness_badge.dart';
import '../common/data_source_badge.dart';
import '../common/data_status_row.dart';
import '../common/handbook_reference_chip.dart';
import '../photos/handbook_photo_thumbnail.dart';
import '../photos/vehicle_photo_thumbnail.dart';

/// A large, photo-first vehicle selection card: a picture of the machine (or
/// a category icon when there is none) dominates the top, the designation is
/// shown large, and only the two data-availability lines that matter for
/// securing (method status, weight) are shown — full engineering detail
/// belongs in [showVehicleDetailDialog], not here.
///
/// Two different kinds of picture can fill that slot, and they are never
/// interchangeable: [photo] is a handbook figure of this vehicle, while
/// [illustrativePhoto] is an outside photograph fetched to help a trainee
/// recognise the machine. The handbook figure wins when both exist, and the
/// illustrative one always carries its own badge (see
/// [VehiclePhotoThumbnail]) so neither is mistaken for the other.
class VehicleCard extends StatefulWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;
  final VoidCallback? onInfoTap;

  /// The vehicle's own handbook figure, when one is linked by reference id
  /// — never a placeholder/invented image. Null shows a category icon
  /// instead, exactly as if no photo existed.
  final HandbookPhoto? photo;

  /// An illustrative photograph of the machine from an outside source, shown
  /// only when the handbook has no figure of its own for this vehicle (which
  /// is the case for every vehicle in the current extract). Always rendered
  /// with the "şertli surat" badge, never as a citable figure.
  final VehiclePhoto? illustrativePhoto;

  /// The side of the square picture window at the head of the row.
  final double photoSize;
  final bool selected;

  /// The tallest a single entry may become, at any width.
  ///
  /// The entry used to be a boxed card in a grid — photograph on top, name,
  /// badges, two status lines and a filled button, twenty of them tiling the
  /// page. That is the card grid the design refuses: the border around each
  /// one carried nothing, and the one thing a trainee scans for, the
  /// designation, was a different distance down every tile. It is a ruled row
  /// now, so it takes the height its content needs rather than a fixed cell —
  /// and these are the bounds on that. `test/vehicle_card_layout_test.dart`
  /// pumps every entry at the widths the list is used at and fails if one
  /// overflows sideways, loses its name, or grows past the bound for its
  /// width.
  ///
  /// [maxRowHeight] is the three-column row the list actually renders;
  /// [maxStackedRowHeight] is the fallback below [stackedBelowWidth], where
  /// the citation and the control drop under the details rather than squeezing
  /// the designation.
  static const double maxRowHeight = 270;
  static const double maxStackedRowHeight = 680;
  static const double stackedBelowWidth = 620;

  const VehicleCard({
    super.key,
    required this.vehicle,
    required this.onTap,
    this.onInfoTap,
    this.photo,
    this.illustrativePhoto,
    this.photoSize = 136,
    this.selected = false,
  });

  @override
  State<VehicleCard> createState() => _VehicleCardState();
}

class _VehicleCardState extends State<VehicleCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.vehicle;
    final selected = widget.selected;
    final lit = selected || _hover;

    final citation = HandbookReferenceChip(referenceId: vehicle.referenceId);

    // The control outranks the citation on this row, and by a clear margin:
    // choosing a vehicle is the entire job of this screen, and a select action
    // lettered smaller than a reference chip and sitting under it in the
    // reading order is the screen's primary action hidden in its own footnote.
    // It is a struck control at label size, lit when the row is.
    final control = AnimatedContainer(
      duration: AppMotion.touch,
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.md, vertical: AppSpace.sm),
      decoration: BoxDecoration(
        color: selected
            ? AppColors.instrument.withValues(alpha: 0.16)
            : lit
                ? AppColors.instrument.withValues(alpha: 0.10)
                : Colors.transparent,
        border: Border.all(
          color: lit ? AppColors.instrument : AppColors.hairlineBright,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              (selected ? AppStrings.vehicleSelectedBadge : AppStrings.selectVehicleButton)
                  .toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.legend(
                size: AppText.label,
                color: lit ? AppColors.instrumentGlow : AppColors.label,
                tracking: 1.4,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.sm),
          AnimatedSlide(
            duration: AppMotion.touch,
            offset: Offset(_hover ? 0.3 : 0, 0),
            child: Icon(
              selected ? Icons.check : Icons.add,
              size: 18,
              color: lit ? AppColors.instrumentGlow : AppColors.label,
            ),
          ),
        ],
      ),
    );

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AppMotion.touch,
          clipBehavior: Clip.hardEdge,
          decoration: BoxDecoration(
            color: selected
                ? AppColors.instrument.withValues(alpha: 0.07)
                : _hover
                    ? AppColors.panel
                    : Colors.transparent,
            border: const Border(top: BorderSide(color: AppColors.hairline)),
          ),
          padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Below this the row cannot hold a third column, so the citation
              // and the control move under the details rather than squeezing
              // the designation — the one thing the entry exists to say.
              final wide = constraints.maxWidth >= VehicleCard.stackedBelowWidth;
              final photo = constraints.maxWidth >= 420 ? widget.photoSize : 92.0;

              final details = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          vehicle.handbookDesignation.toUpperCase(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.legend(
                            size: AppText.cardTitle,
                            color: lit ? AppColors.instrumentGlow : AppColors.textPrimary,
                            tracking: 1.4,
                          ),
                        ),
                      ),
                      if (widget.onInfoTap != null)
                        Tooltip(
                          message: AppStrings.vehicleDetailsTooltip,
                          child: GestureDetector(
                            onTap: widget.onInfoTap,
                            child: const Padding(
                              padding: EdgeInsets.only(left: AppSpace.sm),
                              child: Icon(Icons.info_outline, size: 18, color: AppColors.label),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  // The badges wrap rather than sharing the name's row. A
                  // source badge is up to twenty-one characters of Turkmen —
                  // ÖNDÜRIJINIŇ MAGLUMATY on the T-90S and the T-72 — and
                  // beside the designation the two of them squeezed the one
                  // thing this entry exists to say down to nothing.
                  Wrap(
                    spacing: AppSpace.xs,
                    runSpacing: AppSpace.xs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (DataSourceBadge.isVisible(vehicle.dataSource))
                        DataSourceBadge(dataSource: vehicle.dataSource),
                      DataCompletenessBadge(completeness: vehicle.dataCompleteness),
                      Text(
                        AppStrings.vehicleCategoryLabel(vehicle.category),
                        style: AppText.prose(
                          size: AppText.bodySmall,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpace.sm),
                  DataStatusRow(
                    available: true,
                    label: securingMethodStatusLabel(vehicle),
                    fontSize: AppText.caption,
                  ),
                  DataStatusRow(
                    available: vehicle.weightT.isAvailable,
                    label:
                        '${AppStrings.weightLabel}: ${vehicle.weightT.isAvailable ? vehicle.weightT.display(unit: 't') : AppStrings.requiredDataUnavailable}',
                    fontSize: AppText.caption,
                  ),
                  if (!wide) ...[
                    const SizedBox(height: AppSpace.md),
                    Align(alignment: Alignment.centerLeft, child: control),
                    const SizedBox(height: AppSpace.sm),
                    Align(alignment: Alignment.centerLeft, child: citation),
                  ],
                ],
              );

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _PictureWindow(
                    vehicle: vehicle,
                    photo: widget.photo,
                    illustrativePhoto: widget.illustrativePhoto,
                    size: photo,
                  ),
                  const SizedBox(width: AppSpace.lg),
                  Expanded(child: details),
                  if (wide) ...[
                    const SizedBox(width: AppSpace.lg),
                    // The citation and the control, in a column at the end of
                    // the row, so both line up down the whole list.
                    SizedBox(
                      width: 250,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          control,
                          const SizedBox(height: AppSpace.md),
                          citation,
                        ],
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// The picture at the head of a row: a square window on the machine, with the
/// illustrative badge the photograph carries for itself.
class _PictureWindow extends StatelessWidget {
  final Vehicle vehicle;
  final HandbookPhoto? photo;
  final VehiclePhoto? illustrativePhoto;
  final double size;

  const _PictureWindow({
    required this.vehicle,
    required this.photo,
    required this.illustrativePhoto,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    if (photo != null) {
      return HandbookPhotoThumbnail(photo: photo!, width: size, height: size);
    }
    if (illustrativePhoto != null) {
      return VehiclePhotoThumbnail(
        photo: illustrativePhoto!,
        designation: vehicle.handbookDesignation,
        width: size,
        height: size,
      );
    }
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.well,
        border: Border.all(color: AppColors.hairline),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            vehicle.category == VehicleCategory.tracked
                ? Icons.linear_scale
                : Icons.airline_seat_recline_normal,
            size: size * 0.3,
            color: AppColors.instrumentDeep,
          ),
          // The caption only where the window is big enough to hold it. In the
          // stacked layout this square shrinks to 92 px, and three wrapped
          // lines of "no photograph" under the icon overflowed it — an empty
          // window that draws an overflow stripe says less than an empty
          // window that just stays empty.
          if (size >= 120) ...[
            const SizedBox(height: AppSpace.xs),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.xs),
              child: Text(
                AppStrings.vehiclePhotoUnavailable,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppText.prose(size: AppText.tick, color: AppColors.textSecondary),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
