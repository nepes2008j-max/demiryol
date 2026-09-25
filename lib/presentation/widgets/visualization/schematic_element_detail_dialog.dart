import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/simulation_result.dart';
import '../../../domain/models/schematic_element.dart';
import '../common/detail_dialog_shell.dart';
import '../common/handbook_reference_chip.dart';
import '../common/labeled_row.dart';
import '../photos/related_photos_row.dart';

/// Compact "what is this?" popup for one tapped schematic component —
/// shared by the vehicle body, the platform deck, every hardware kind, and
/// wire lashings (see `schematic_hit_test.dart`). Shows only what
/// `SchematicBuilder`/`equipment_catalog.dart`/`checkEquipmentSelection`
/// already resolved for this element — its selected type, the real
/// handbook specs for that type, the handbook-mandated type when one
/// exists, and the same PASS/FAIL verdict shown in the Required Equipment
/// panel. This dialog never looks up or computes a NEW verdict — the
/// caller (`SecuringSchematicSection`) passes in values already derived
/// from the same pure functions the equipment panel uses.
void showSchematicElementDetailDialog(
  BuildContext context, {
  required SchematicElement element,
  required List<HandbookPhoto> relatedPhotos,
  String? selectedTypeCode,
  Map<String, String> specs = const {},
  ValidationCheck? check,
}) {
  final referenceIds = element.relatedReferenceIds.toSet();
  final hasStatus =
      check != null || element.isSelectionMismatch || element.isPositionHandbookSupported;
  showDetailDialog(
    context: context,
    title: element.label.isEmpty ? AppStrings.schematicElementDetailFallbackTitle : element.label,
    children: [
      if (hasStatus) ...[
        const Text(AppStrings.schematicElementStatusHeading,
            style: TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        if (check != null)
          _VerdictBanner(check: check)
        else if (element.isSelectionMismatch)
          const _StatusBanner(
            icon: Icons.cancel,
            color: AppColors.outOfTolerance,
            text: AppStrings.schematicElementMismatchNote,
          )
        else if (element.isPositionHandbookSupported)
          const _StatusBanner(
            icon: Icons.menu_book,
            color: AppColors.inTolerance,
            text: AppStrings.schematicElementPlacementSupportedNote,
          ),
      ],
      if (selectedTypeCode != null) ...[
        LabeledRow(label: AppStrings.schematicElementTypeLabel, value: selectedTypeCode),
        if (specs.isNotEmpty) ...[
          const SizedBox(height: 8),
          const Text(AppStrings.schematicElementSpecsHeading,
              style: TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            runSpacing: 6,
            children: specs.entries.map((e) => _SpecValue(label: e.key, value: e.value)).toList(),
          ),
          const SizedBox(height: 8),
        ],
      ],
      if (element.isGeometrySchematic) ...[
        const SizedBox(height: 4),
        const Text(
          AppStrings.schematicNotToScaleBanner,
          style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
      ],
      if (referenceIds.isNotEmpty) ...[
        const Text(AppStrings.schematicElementCitationHeading,
            style: TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: referenceIds.map((id) => HandbookReferenceChip(referenceId: id)).toList(),
        ),
      ],
      if (relatedPhotos.isNotEmpty) ...[
        const SizedBox(height: 16),
        RelatedPhotosRow(photos: relatedPhotos, label: AppStrings.relatedFiguresHeading),
      ],
    ],
  );
}

class _SpecValue extends StatelessWidget {
  final String label;
  final String value;
  const _SpecValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: const TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(fontSize: AppText.label, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
      ],
    );
  }
}

/// "Görnüş / Gollanma talaby / Netije" — the same three-value comparison
/// the Required Equipment panel shows, in a compact popup form.
class _VerdictBanner extends StatelessWidget {
  final ValidationCheck check;
  const _VerdictBanner({required this.check});

  @override
  Widget build(BuildContext context) {
    final pass = check.status == CheckStatus.pass;
    final color = pass ? AppColors.inTolerance : AppColors.outOfTolerance;
    return Container(
      padding: const EdgeInsets.all(10),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(pass ? Icons.check_circle : Icons.cancel, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pass ? AppStrings.equipmentResultCorrectLabel : AppStrings.equipmentResultIncorrectLabel,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.bodySmall, color: color),
                ),
                const SizedBox(height: 4),
                Text(check.detail, style: TextStyle(fontSize: AppText.bodySmall, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _StatusBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(fontSize: AppText.bodySmall, color: color))),
        ],
      ),
    );
  }
}
