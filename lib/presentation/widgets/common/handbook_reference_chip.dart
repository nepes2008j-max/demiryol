import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/handbook_providers.dart';
import 'handbook_reference_detail_dialog.dart';

/// Renders a "Para. 51" / "Table 7" style citation chip. Hovering shows the
/// source summary as a tooltip; clicking opens the full detail dialog with
/// the summary plus any related figures/principles/rules.
class HandbookReferenceChip extends ConsumerWidget {
  final String referenceId;

  const HandbookReferenceChip({super.key, required this.referenceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refsAsync = ref.watch(referencesProvider);
    return refsAsync.when(
      data: (refs) {
        final ref = refs.where((r) => r.id == referenceId).cast<dynamic>().firstOrNull;
        final label = ref?.citationLabel ?? referenceId;
        final summary = ref?.displaySummary ?? AppStrings.noSummaryAvailableFor(referenceId);
        return Tooltip(
          message: summary,
          child: InkWell(
            onTap: () => showHandbookReferenceDetailDialog(context, referenceId),
            borderRadius: BorderRadius.zero,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.panel,
                border: Border.all(color: AppColors.labelDim, width: 1),
                borderRadius: BorderRadius.zero,
              ),
              // The label can be as long as "Madda 31 / Tablisa 11,13", which
              // at the interface's type scale is wider than a grid tile. It
              // shrinks and ellipsises rather than overflowing its card; the
              // full citation is in the tooltip and the detail dialog either
              // way.
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.menu_book, size: 14, color: AppColors.label),
                  const SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.label),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const SizedBox(height: 26, width: 70),
      error: (e, st) => const SizedBox.shrink(),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
