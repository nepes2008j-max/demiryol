import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import 'handbook_photo_dialog.dart';

/// Small tappable thumbnail of a handbook figure. Tapping opens the
/// enlarged, zoomable [showHandbookPhotoDialog] view. Falls back to a
/// professional placeholder — never a crash — if the source image is
/// missing or fails to decode.
class HandbookPhotoThumbnail extends StatelessWidget {
  final HandbookPhoto photo;
  final double size;

  /// A rectangular window instead of a square one — a specimen plate wants the
  /// photograph across its whole width, not a stamp in the middle of it.
  final double? width;
  final double? height;

  const HandbookPhotoThumbnail({
    super.key,
    required this.photo,
    this.size = 96,
    this.width,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '${photo.figureNumber} — ${photo.displayCaption}',
      child: InkWell(
        onTap: () => showHandbookPhotoDialog(context, photo),
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
                  child: Text(
                    photo.figureNumber,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: AppText.caption,
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
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
