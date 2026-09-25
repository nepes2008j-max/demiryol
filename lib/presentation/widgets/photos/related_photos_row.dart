import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import 'handbook_photo_thumbnail.dart';

/// A horizontal strip of handbook-figure thumbnails, shown only when at
/// least one photo is actually related (by shared reference id) to the
/// surrounding content. Renders nothing when [photos] is empty, rather than
/// claiming "no photos available" — contextual photos are additive, not a
/// promise every entity has one.
class RelatedPhotosRow extends StatelessWidget {
  final List<HandbookPhoto> photos;
  final String? label;
  final double thumbnailSize;

  const RelatedPhotosRow({
    super.key,
    required this.photos,
    this.label,
    this.thumbnailSize = 96,
  });

  @override
  Widget build(BuildContext context) {
    if (photos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              label!,
              style: const TextStyle(
                fontSize: AppText.caption,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        SizedBox(
          height: thumbnailSize,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) =>
                HandbookPhotoThumbnail(photo: photos[i], size: thumbnailSize),
          ),
        ),
      ],
    );
  }
}
