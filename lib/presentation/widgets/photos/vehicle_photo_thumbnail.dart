import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle_photo.dart';
import 'vehicle_photo_dialog.dart';

/// Tappable thumbnail of a vehicle's illustrative photograph.
///
/// It looks deliberately different from the handbook figure thumbnail: the caption
/// strip carries the amber "ŞERTLI SURAT" badge instead of a figure number,
/// so a trainee can tell at a glance that this picture is an outside
/// illustration of the machine and not a figure they can cite. Tapping opens
/// [showVehiclePhotoDialog], which spells that out and gives the photograph's
/// author, licence and source page.
///
/// Falls back to a placeholder rather than crashing when the image file is
/// missing — the manifest can list a vehicle whose file was never fetched.
class VehiclePhotoThumbnail extends StatelessWidget {
  final VehiclePhoto photo;
  final String designation;
  final double size;

  /// A rectangular window instead of a square one — a specimen plate wants the
  /// photograph across its whole width, not a stamp in the middle of it.
  final double? width;
  final double? height;

  const VehiclePhotoThumbnail({
    super.key,
    required this.photo,
    required this.designation,
    this.size = 96,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '$designation — ${AppStrings.illustrativePhotoNotice}',
      child: InkWell(
        onTap: () => showVehiclePhotoDialog(context, photo: photo, designation: designation),
        child: Container(
          width: width ?? size,
          height: height ?? size,
          decoration: BoxDecoration(
            color: AppColors.panel,
            border: Border.all(color: AppColors.hairline),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                photo.fullAssetPath,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const ColoredBox(
                  color: AppColors.panelRaised,
                  child: Center(
                    child: Icon(Icons.image_not_supported, color: AppColors.offNominal, size: 22),
                  ),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: const Text(
                    AppStrings.illustrativePhotoBadge,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppText.caption,
                      color: AppColors.offNominal,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
