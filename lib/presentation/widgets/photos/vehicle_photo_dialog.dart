import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle_photo.dart';

/// Enlarged view of a vehicle's illustrative photograph, with the full
/// attribution the photograph's licence requires: author, licence short name
/// and the Commons file page it came from.
///
/// This deliberately does not reuse the handbook figure dialog: that dialog
/// prints a figure number and a "taken from the handbook's own document"
/// source line, both of which would be false here. The notice at the top of
/// this dialog says the opposite in as many words — the photograph is an
/// outside illustration, not a cited figure.
Future<void> showVehiclePhotoDialog(
  BuildContext context, {
  required VehiclePhoto photo,
  required String designation,
}) {
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
                      AppStrings.illustrativePhotoDialogTitle(designation),
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
                      errorBuilder: (context, error, stackTrace) => const SizedBox(
                        height: 220,
                        child: Center(
                          child: Icon(Icons.image_not_supported,
                              color: AppColors.offNominal, size: 40),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                AppStrings.illustrativePhotoNotice,
                style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.offNominal),
              ),
              const SizedBox(height: 10),
              const Text(
                AppStrings.illustrativePhotoSourceHeading,
                style: TextStyle(
                    fontSize: AppText.caption, fontWeight: FontWeight.bold, letterSpacing: 0.5),
              ),
              const SizedBox(height: 4),
              _AttributionRow(
                label: AppStrings.photoAuthorLabel,
                value: photo.author.trim().isEmpty
                    ? AppStrings.photoAuthorUnknown
                    : photo.author.trim(),
              ),
              _AttributionRow(label: AppStrings.photoLicenseLabel, value: photo.license),
              if (photo.sourceUrl.isNotEmpty)
                // Selectable, not a link: the app has no URL launcher and a
                // dead-looking link is worse than a copyable address.
                _AttributionRow(
                  label: AppStrings.photoSourceLabel,
                  value: photo.sourceUrl,
                  selectable: true,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _AttributionRow extends StatelessWidget {
  final String label;
  final String value;
  final bool selectable;

  const _AttributionRow({
    required this.label,
    required this.value,
    this.selectable = false,
  });

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 90, child: Text('$label:', style: style)),
          Expanded(
            child: selectable
                ? SelectableText(value, style: style)
                : Text(value, style: style),
          ),
        ],
      ),
    );
  }
}
