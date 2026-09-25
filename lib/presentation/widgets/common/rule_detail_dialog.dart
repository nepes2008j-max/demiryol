import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/handbook_rule.dart';
import '../photos/related_photos_row.dart';
import 'detail_dialog_shell.dart';
import 'handbook_reference_chip.dart';
import 'labeled_row.dart';

void showRuleDetailDialog(
  BuildContext context, {
  required HandbookRule rule,
  required List<HandbookPhoto> relatedPhotos,
}) {
  showDetailDialog(
    context: context,
    title: rule.displayTitle,
    children: [
      if (rule.appliesTo != null)
        LabeledRow(label: AppStrings.appliesToLabel, value: AppStrings.appliesToLabelFor(rule.appliesTo!)),
      if (!rule.isMethod && rule.description.isNotEmpty)
        LabeledRow(label: AppStrings.descriptionLabel, value: rule.displayDescription),
      if (rule.condition != null) LabeledRow(label: AppStrings.conditionLabel, value: rule.condition!),
      if (rule.displayFailMessage != null)
        LabeledRow(label: AppStrings.failMessageLabel, value: rule.displayFailMessage!),
      if (rule.hasLookup)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Text(
            AppStrings.lookupTableNote,
            style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary),
          ),
        ),
      const SizedBox(height: 10),
      HandbookReferenceChip(referenceId: rule.referenceId),
      if (relatedPhotos.isNotEmpty) ...[
        const SizedBox(height: 16),
        RelatedPhotosRow(photos: relatedPhotos, label: AppStrings.relatedFiguresHeading),
      ],
    ],
  );
}
