import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/attachment_type.dart';
import '../../../data/models/handbook_photo.dart';
import '../photos/related_photos_row.dart';
import 'detail_dialog_shell.dart';
import 'handbook_reference_chip.dart';
import 'labeled_row.dart';

void showAttachmentDetailDialog(
  BuildContext context, {
  required AttachmentType attachment,
  required List<HandbookPhoto> relatedPhotos,
}) {
  showDetailDialog(
    context: context,
    title: attachment.name,
    children: [
      LabeledRow(
          label: AppStrings.categoryLabel,
          value: AppStrings.attachmentCategoryLabel(attachment.category)),
      if (attachment.material != null)
        LabeledRow(label: AppStrings.materialLabel, value: attachment.material!),
      if (attachment.diametersAvailableMm != null)
        LabeledRow(
            label: AppStrings.diametersAvailableLabel,
            value: '${attachment.diametersAvailableMm!.join(', ')} mm'),
      if (attachment.minThicknessMm != null)
        LabeledRow(label: AppStrings.minThicknessLabel, value: '${attachment.minThicknessMm} mm'),
      if (attachment.combatWeightRangeT != null)
        LabeledRow(
            label: AppStrings.combatWeightRangeLabel, value: '${attachment.combatWeightRangeT} t'),
      if (attachment.usedFor != null)
        LabeledRow(label: AppStrings.usedForLabel, value: attachment.usedFor!.join(', ')),
      if (attachment.sizingRule != null)
        LabeledRow(label: AppStrings.sizingRuleLabel, value: attachment.sizingRule!),
      if (attachment.displayNotes != null) ...[
        const SizedBox(height: 6),
        Text(attachment.displayNotes!, style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
      ],
      const SizedBox(height: 10),
      HandbookReferenceChip(referenceId: attachment.referenceId),
      if (relatedPhotos.isNotEmpty) ...[
        const SizedBox(height: 16),
        RelatedPhotosRow(photos: relatedPhotos, label: AppStrings.relatedFiguresHeading),
      ],
    ],
  );
}
