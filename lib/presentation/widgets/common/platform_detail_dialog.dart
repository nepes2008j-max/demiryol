import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/platform.dart';
import '../photos/related_photos_row.dart';
import 'detail_dialog_shell.dart';
import 'handbook_reference_chip.dart';
import 'labeled_row.dart';

/// Full platform spec sheet, mirroring [showVehicleDetailDialog]'s honesty
/// rules: every field is either a real handbook value or an explicit
/// "not available" message.
void showPlatformDetailDialog(
  BuildContext context, {
  required Platform platform,
  required List<HandbookPhoto> relatedPhotos,
}) {
  showDetailDialog(
    context: context,
    title: platform.name,
    children: [
      LabeledRow(label: AppStrings.lengthLabel, value: platform.lengthCm.display(unit: 'cm')),
      LabeledRow(label: AppStrings.widthLabel, value: platform.widthCm.display(unit: 'cm')),
      LabeledRow(label: AppStrings.deckHeightLabel, value: platform.deckHeightCm.display(unit: 'cm')),
      LabeledRow(
          label: AppStrings.maxAxleLoadLabel,
          value: platform.maxAxleLoadWheeledT.display(unit: 't')),
            LabeledRow(
          label: AppStrings.specialCaseMaxLabel,
          value: platform.specialCaseMaxTrackedT.display(unit: 't')),
      LabeledRow(label: AppStrings.attachmentRingsLabel, value: platform.attachmentRings.display()),
      LabeledRow(label: AppStrings.tieDownRingsLabel, value: platform.tieDownRings.display()),
      LabeledRow(
          label: AppStrings.woodSupportPositionsLabel, value: platform.woodSupportPositions.display()),
      if (platform.trainMaxWeightT != null)
        LabeledRow(
            label: AppStrings.trainClassMaxWeightLabel,
            value: platform.trainMaxWeightT!.display(unit: 't')),
      if (platform.conditionalWagonCount != null)
        LabeledRow(
            label: AppStrings.conditionalWagonCountLabel,
            value: platform.conditionalWagonCount!.display()),
      LabeledRow(
          label: AppStrings.allowedVehicleTypesLabel,
          value: platform.allowedVehicleTypes.map(AppStrings.appliesToLabelFor).join(', ')),
      if (platform.displayNotes != null) ...[
        const SizedBox(height: 6),
        Text(platform.displayNotes!, style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
      ],
      const SizedBox(height: 10),
      HandbookReferenceChip(referenceId: platform.referenceId),
      if (relatedPhotos.isNotEmpty) ...[
        const SizedBox(height: 16),
        RelatedPhotosRow(photos: relatedPhotos, label: AppStrings.relatedFiguresHeading),
      ],
    ],
  );
}
