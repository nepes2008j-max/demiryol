import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../providers/handbook_providers.dart';
import '../photos/related_photos_row.dart';

/// Full detail view for a single paragraph/table/figure citation: its
/// source summary, plus anything else in the extracted data that cites the
/// same reference id (figures, principles, rules).
Future<void> showHandbookReferenceDetailDialog(BuildContext context, String referenceId) {
  return showDialog(
    context: context,
    builder: (context) => Consumer(
      builder: (context, ref, _) {
        final refsAsync = ref.watch(referencesProvider);
        final linkerAsync = ref.watch(referenceLinkerProvider);

        if (refsAsync.isLoading || linkerAsync.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (refsAsync.hasError) {
          return AlertDialog(content: Text(AppStrings.errorPrefix(refsAsync.error!)));
        }
        if (linkerAsync.hasError) {
          return AlertDialog(content: Text(AppStrings.errorPrefix(linkerAsync.error!)));
        }

        final refs = refsAsync.requireValue;
        final linker = linkerAsync.requireValue;

        String? summary;
        String label = referenceId;
        for (final r in refs) {
          if (r.id == referenceId) {
            summary = r.displaySummary;
            label = r.citationLabel;
            break;
          }
        }

        final relatedPhotos = linker.photosFor(referenceId);
        final relatedPrincipleTitles = linker.principlesFor(referenceId).map((p) => p.title);
        final relatedRuleTitles = linker.rulesFor(referenceId).map((r) => r.displayTitle);

        return _ReferenceDetailDialog(
          title: label,
          summary: summary,
          relatedPhotos: relatedPhotos,
          relatedPrincipleTitles: relatedPrincipleTitles.toList(),
          relatedRuleTitles: relatedRuleTitles.toList(),
        );
      },
    ),
  );
}

class _ReferenceDetailDialog extends StatelessWidget {
  final String title;
  final String? summary;
  final List<HandbookPhoto> relatedPhotos;
  final List<String> relatedPrincipleTitles;
  final List<String> relatedRuleTitles;

  const _ReferenceDetailDialog({
    required this.title,
    required this.summary,
    required this.relatedPhotos,
    required this.relatedPrincipleTitles,
    required this.relatedRuleTitles,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.sectionTitle)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  summary ?? AppStrings.noSummaryPresent,
                  style: const TextStyle(fontSize: AppText.label),
                ),
                if (relatedPhotos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  RelatedPhotosRow(photos: relatedPhotos, label: AppStrings.relatedFiguresHeading),
                ],
                if (relatedPrincipleTitles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(AppStrings.relatedPrincipleHeading,
                      style: TextStyle(
                          fontSize: AppText.caption,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary)),
                  ...relatedPrincipleTitles.map((t) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $t', style: const TextStyle(fontSize: AppText.bodySmall)),
                      )),
                ],
                if (relatedRuleTitles.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(AppStrings.relatedRuleHeading,
                      style: TextStyle(
                          fontSize: AppText.caption,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                          color: AppColors.textSecondary)),
                  ...relatedRuleTitles.map((t) => Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text('• $t', style: const TextStyle(fontSize: AppText.bodySmall)),
                      )),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
