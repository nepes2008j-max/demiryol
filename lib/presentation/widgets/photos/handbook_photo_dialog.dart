import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../domain/usecases/photo_presentation.dart';
import '../common/handbook_reference_chip.dart';

/// Enlarged, zoomable view of a single handbook figure — fit-to-window by
/// default, pinch/scroll-to-zoom via [InteractiveViewer]. Always shows the
/// figure metadata and source attribution, even if the image itself fails
/// to load.
Future<void> showHandbookPhotoDialog(BuildContext context, HandbookPhoto photo) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 860, maxHeight: 760),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      AppStrings.figureLabel(photo.figureNumber),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.sectionTitle),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Flexible(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppColors.ground,
                    border: Border.all(color: AppColors.hairline),
                  ),
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.asset(
                      photo.fullAssetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => _imageErrorPlaceholder(photo),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(photo.displayCaption, style: const TextStyle(fontSize: AppText.label)),
              const SizedBox(height: 8),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  HandbookReferenceChip(referenceId: photo.referenceId),
                  const Text(
                    AppStrings.photoSourceAttribution,
                    style: TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

Widget _imageErrorPlaceholder(HandbookPhoto photo) {
  return SizedBox(
    height: 260,
    child: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported, color: AppColors.offNominal, size: 40),
            const SizedBox(height: 8),
            Text(
              imageUnavailableCaption(photo),
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: AppText.bodySmall),
            ),
          ],
        ),
      ),
    ),
  );
}
