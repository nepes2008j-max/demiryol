import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/principle.dart';
import '../photos/related_photos_row.dart';
import 'handbook_reference_chip.dart';

/// Full "why" explanation for a single handbook principle: statement,
/// purpose, physics, engineering reason, military requirement, its source
/// citation, and (when the extracted data explicitly links one) the
/// handbook figure(s) illustrating it.
class PrincipleCard extends StatelessWidget {
  final Principle principle;
  final List<HandbookPhoto> relatedPhotos;

  const PrincipleCard({super.key, required this.principle, this.relatedPhotos = const []});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(principle.displayTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.label)),
            const SizedBox(height: 6),
            _row(AppStrings.principleLabel, principle.displayPrinciple),
            _row(AppStrings.purposeLabel, principle.displayPurpose),
            _row(AppStrings.physicsLabel, principle.displayPhysics),
            _row(AppStrings.engineeringReasonLabel, principle.displayEngineeringReason),
            _row(AppStrings.militaryRequirementLabel, principle.displayMilitaryRequirement),
            const SizedBox(height: 6),
            HandbookReferenceChip(referenceId: principle.handbookReferenceId),
            if (relatedPhotos.isNotEmpty) ...[
              const SizedBox(height: 10),
              RelatedPhotosRow(photos: relatedPhotos, label: AppStrings.illustratedIn, thumbnailSize: 80),
            ],
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: RichText(
          text: TextSpan(
            style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textPrimary),
            children: [
              TextSpan(text: '$label: ', style: const TextStyle(color: AppColors.label, fontWeight: FontWeight.bold)),
              TextSpan(text: value),
            ],
          ),
        ),
      );
}
