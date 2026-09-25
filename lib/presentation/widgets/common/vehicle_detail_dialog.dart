import 'dart:io';
import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/attachment_type.dart';
import '../../../data/models/handbook_field.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/vehicle.dart';
import '../../../data/models/vehicle_photo.dart';
import '../../../domain/usecases/securing_method_status.dart';
import '../photos/handbook_photo_thumbnail.dart';
import '../photos/related_photos_row.dart';
import '../photos/vehicle_photo_thumbnail.dart';
import 'data_completeness_badge.dart';
import 'data_source_badge.dart';
import 'data_status_row.dart';
import 'detail_dialog_shell.dart';
import 'handbook_reference_chip.dart';
import 'labeled_row.dart';

/// Full vehicle spec sheet: every field the handbook extract carries for
/// this vehicle (real value or an explicit "not available" message — never
/// a guess), its assigned securing hardware, and any figures the extracted
/// data explicitly ties to the same reference id. [identificationPhoto] is
/// the vehicle's own photograph, only if the extract genuinely has one
/// (see `handbook_photo_resolution.dart`) — never a securing-equipment or
/// procedure figure standing in for it; those go in [relatedPhotos]
/// instead, clearly labeled as securing-related, not as the vehicle photo.
///
/// [illustrativePhoto] is the fallback for the (currently universal) case
/// where the extract has no identification photograph: an outside photograph
/// of the machine, shown under its own "şertli surat" badge with the author,
/// licence and source page one tap away. It is never treated as handbook
/// evidence — it carries no figure number and no citation chip.
void showVehicleDetailDialog(
  BuildContext context, {
  required Vehicle vehicle,
  required List<AttachmentType> allAttachments,
  required List<HandbookPhoto> relatedPhotos,
  HandbookPhoto? identificationPhoto,
  VehiclePhoto? illustrativePhoto,
  /// The instructor's own photographs of this vehicle, by view. When present
  /// they replace whatever the app shipped: an instructor with a picture of
  /// the actual machine in their unit outranks one fetched off the internet.
  Map<String, String> ownPhotos = const {},
}) {
  final hardwareNames = vehicle.approvedSecuringHardwareIds.map((id) {
    final matches = allAttachments.where((a) => a.id == id);
    return matches.isEmpty ? id : matches.first.name;
  }).toList();

  showDetailDialog(
    context: context,
    title: vehicle.handbookDesignation,
    children: [
      if (ownPhotos.isNotEmpty)
        Center(child: _OwnPhotos(photos: ownPhotos))
      else
      Center(
        child: identificationPhoto != null
            ? HandbookPhotoThumbnail(photo: identificationPhoto, size: 160)
            : illustrativePhoto != null
                ? Column(
                    children: [
                      VehiclePhotoThumbnail(
                        photo: illustrativePhoto,
                        designation: vehicle.handbookDesignation,
                        size: 160,
                      ),
                      const SizedBox(height: 6),
                      // The credit is printed here, not only inside the
                      // enlarged view, so a CC BY / CC BY-SA photograph
                      // carries its attribution wherever it is shown.
                      Text(
                        illustrativePhoto.creditLine,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        AppStrings.illustrativePhotoNotice,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal),
                      ),
                      // The other angles, when the source had them. A trainee
                      // about to judge overhang and clearance is helped more by
                      // the back and the front of a machine than by one
                      // three-quarter view of it.
                      if (illustrativePhoto.views.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            for (final view in const ['front', 'side', 'rear'])
                              if (illustrativePhoto.fullViewPath(view) != null)
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      illustrativePhoto.fullViewPath(view)!,
                                      width: 104,
                                      height: 70,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const SizedBox.shrink(),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      AppStrings.adminPhotoView(view),
                                      style: const TextStyle(
                                          fontSize: AppText.caption,
                                          color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                          ],
                        ),
                      ],
                    ],
                  )
                : const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Text(AppStrings.vehiclePhotoUnavailable,
                        style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
                  ),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Text(AppStrings.vehicleCategoryLabel(vehicle.category).toUpperCase(),
              style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
          const Spacer(),
          DataSourceBadge(
              dataSource: vehicle.dataSource,
              hasUserFigures: vehicle.hasUserSuppliedFigures),
          const SizedBox(width: 4),
          DataCompletenessBadge(completeness: vehicle.dataCompleteness),
        ],
      ),
      if (vehicle.dataSource != VehicleDataSource.handbook) ...[
        const SizedBox(height: 6),
        const Text(AppStrings.dataSourceMockupDetail,
            style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal)),
      ],
      const SizedBox(height: 10),
      LabeledRow(label: AppStrings.classLabel, value: vehicle.displayClass),
      LabeledRow(label: AppStrings.manufacturerLabel, value: presentHandbookText(vehicle.manufacturer)),
      LabeledRow(label: AppStrings.countryLabel, value: presentHandbookText(vehicle.country)),
      const Divider(height: 20, color: AppColors.hairline),
      LabeledRow(label: AppStrings.lengthLabel, value: vehicle.lengthCm.display(unit: 'cm')),
      LabeledRow(label: AppStrings.widthLabel, value: vehicle.widthCm.display(unit: 'cm')),
      LabeledRow(label: AppStrings.heightLabel, value: vehicle.heightCm.display(unit: 'cm')),
      LabeledRow(label: AppStrings.weightLabel, value: vehicle.weightT.display(unit: 't')),
      LabeledRow(
          label: AppStrings.groundClearanceLabel, value: vehicle.groundClearanceCm.display(unit: 'cm')),
      LabeledRow(label: AppStrings.trackWidthLabel, value: vehicle.trackWidthMm.display(unit: 'mm')),
      LabeledRow(label: AppStrings.wheelbaseLabel, value: vehicle.wheelBaseCm.display(unit: 'cm')),
      // Shown only where it exists: it is a later addition, and a row reading
      // "not available" on every legacy record would say nothing useful.
      if (vehicle.trackContactLengthCm.isAvailable)
        LabeledRow(
            label: AppStrings.trackContactLengthLabel,
            value: vehicle.trackContactLengthCm.display(unit: 'cm')),
      const Divider(height: 20, color: AppColors.hairline),
      if (hardwareNames.isNotEmpty)
        LabeledRow(label: AppStrings.approvedHardwareLabel, value: hardwareNames.join(', ')),
      if (vehicle.ironSpurType != null)
        LabeledRow(label: AppStrings.ironSpurTypeLabel, value: vehicle.ironSpurType!),
      if (vehicle.ironChockBootType != null)
        LabeledRow(label: AppStrings.ironChockBootTypeLabel, value: vehicle.ironChockBootType!),
      if (vehicle.displayNotes != null) ...[
        const SizedBox(height: 6),
        Text(vehicle.displayNotes!, style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
      ],
      const SizedBox(height: 10),
      HandbookReferenceChip(referenceId: vehicle.referenceId),
      const Divider(height: 20, color: AppColors.hairline),
      const Text(AppStrings.requiredDataForSecuringHeading,
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.bodySmall, letterSpacing: 0.5)),
      const SizedBox(height: 8),
      DataStatusRow(
        available: true,
        label: '${AppStrings.requiredDataSecuringMethodLabel}: ${securingMethodStatusLabel(vehicle)}',
      ),
      DataStatusRow(
        available: vehicle.weightT.isAvailable,
        label:
            '${AppStrings.requiredDataWeightLabel} — ${vehicle.weightT.isAvailable ? AppStrings.requiredDataAvailable : AppStrings.requiredDataUnavailable}',
      ),
      DataStatusRow(
        available: vehicle.lengthCm.isAvailable && vehicle.widthCm.isAvailable && vehicle.heightCm.isAvailable,
        label:
            '${AppStrings.requiredDataDimensionsLabel} — ${vehicle.lengthCm.isAvailable && vehicle.widthCm.isAvailable && vehicle.heightCm.isAvailable ? AppStrings.requiredDataAvailable : AppStrings.requiredDataUnavailable}',
      ),
      if (relatedPhotos.isNotEmpty) ...[
        const SizedBox(height: 16),
        RelatedPhotosRow(photos: relatedPhotos, label: AppStrings.securingRelatedFiguresHeading),
      ],
    ],
  );
}


/// The instructor's own photographs of a machine, in plate order.
class _OwnPhotos extends StatelessWidget {
  final Map<String, String> photos;

  const _OwnPhotos({required this.photos});

  @override
  Widget build(BuildContext context) {
    final ordered = [
      for (final view in const ['side', 'front', 'rear'])
        if (photos[view] != null) (view, photos[view]!),
      for (final e in photos.entries)
        if (!const ['side', 'front', 'rear'].contains(e.key)) (e.key, e.value),
    ];
    if (ordered.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: [
        for (final (view, path) in ordered)
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.file(
                File(path),
                width: 150,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 2),
              Text(
                AppStrings.adminPhotoView(view),
                style: const TextStyle(
                    fontSize: AppText.caption, color: AppColors.textSecondary),
              ),
            ],
          ),
      ],
    );
  }
}
