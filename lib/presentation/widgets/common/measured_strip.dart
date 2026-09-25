import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/usecases/securing_measurements.dart';
import '../../../domain/usecases/wagon_capacity.dart';
import 'app_surfaces.dart';
import 'handbook_reference_chip.dart';
import 'instrument.dart';

/// The value strip: every reading the app has actually taken on one wagon,
/// each against the limit the handbook states for it.
///
/// This is the point of the whole interface. The trainee drags a stop block
/// along the deck and a number moves; what makes that a lesson rather than a
/// game is the band drawn beside the number — where the handbook says the
/// block belongs — and the citation under it saying which plate said so.
///
/// Every entry here is a real measurement of something the trainee placed,
/// compared against a real stated range. Nothing is shown that the extract
/// cannot supply: a wagon whose deck length is missing reports no budget
/// rather than a plausible one, and a block placed under an arrangement that
/// states no distance is listed as measured but unjudged.
/// The strip takes its readings as data rather than reading them itself.
///
/// Its numbers come from providers that several widgets on the placement
/// screen share, and the panel it lives in is built after the wagon list. A
/// widget that subscribes to those providers from down there is marked dirty
/// in the middle of a sibling's build; read once at the top of the screen,
/// where the rebuild is a parent's to schedule, the ordering hazard does not
/// exist. It also makes the strip a plain widget to test.
class MeasuredStrip extends StatelessWidget {
  /// What the load takes of the deck, when every length it needs is known.
  final WagonLengthBudget? budget;

  /// How far the load stands past the end of the wagon, in millimetres.
  final double? overhangMm;

  /// Every stop block seated on this wagon, measured.
  final List<SeatingFinding> findings;

  const MeasuredStrip({
    super.key,
    required this.budget,
    required this.overhangMm,
    required this.findings,
  });

  @override
  Widget build(BuildContext context) {
    final budget = this.budget;
    final overhangMm = this.overhangMm;
    final rows = <Widget>[];

    // The deck, as a quantity: what the load takes and what is left. The
    // handbook's limit here is the deck itself, so the band is the whole deck
    // and the needle is what has been spent of it.
    if (budget != null && budget.isComputable) {
      final deck = budget.deckLengthCm!;
      rows.add(_Reading(
        label: AppStrings.wagonBudgetUsedLabel,
        scale: ToleranceScale(
          value: budget.usedCm,
          min: 0,
          max: deck,
          spanMin: 0,
          spanMax: deck * 1.08,
          format: (v) => v.toStringAsFixed(0),
          unit: 'sm',
        ),
        referenceId: budget.referenceId,
      ));
    }

    // The plain figures go in one table so they share a right edge with each
    // other, rather than each sizing to its own value.
    final figures = <ReadoutRow>[
      if (budget != null && budget.isComputable)
        ReadoutRow(
          label: AppStrings.wagonBudgetRemainingLabel,
          value: budget.remainingCm!.toStringAsFixed(0),
          unit: 'sm',
          valueColor:
              budget.isOverloaded ? AppColors.outOfTolerance : AppColors.instrumentGlow,
        ),
      if (overhangMm != null)
        ReadoutRow(
          label: AppStrings.wagonOverhangLabel,
          value: overhangMm.toStringAsFixed(0),
          unit: 'mm',
        ),
    ];
    if (figures.isNotEmpty) {
      rows.add(Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.lg),
        child: ReadoutTable(dense: true, rows: figures),
      ));
    }

    // Every stop block the trainee has seated, measured off the running gear
    // against the range its arrangement states.
    for (final finding in findings) {
      final range = finding.requiredRange;
      rows.add(_Reading(
        label: AppStrings.seatingDistanceLabel,
        subject: finding.designation,
        scale: range == null
            ? null
            : ToleranceScale(
                value: finding.measuredCm,
                min: range.minCm.toDouble(),
                max: range.maxCm.toDouble(),
                format: (v) => v.toStringAsFixed(1),
                unit: 'sm',
              ),
        fallback: range == null
            ? ReadoutTable(dense: true, rows: [
                ReadoutRow(
                  label: AppStrings.seatingDistanceLabel,
                  value: finding.measuredCm.toStringAsFixed(1),
                  unit: 'sm',
                  valueColor: AppColors.offNominal,
                ),
              ])
            : null,
        referenceId: finding.referenceId,
      ));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SectionHeading(AppStrings.measuredStripHeading, live: rows.isNotEmpty),
        if (rows.isEmpty)
          Text(
            AppStrings.measuredStripEmpty,
            style: AppText.prose(size: AppText.bodySmall, color: AppColors.labelDim),
          )
        else
          ...rows,
      ],
    );
  }
}

/// One reading: what was measured, the scale it was measured against, and the
/// plate the scale came from.
class _Reading extends StatelessWidget {
  final String label;
  final String? subject;
  final ToleranceScale? scale;
  final Widget? fallback;
  final String referenceId;

  const _Reading({
    required this.label,
    required this.referenceId,
    this.subject,
    this.scale,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The name of the reading gets its own line. Sharing the line with
          // the thing measured truncated both of them in a 380-pixel rail, and
          // a reading whose name is cut in half is not a reading.
          Text(
            label.toUpperCase(),
            style: AppText.legend(
              size: AppText.caption,
              color: AppColors.label,
              weight: FontWeight.w400,
              tracking: 1.2,
            ),
          ),
          if (subject != null)
            Text(
              subject!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.prose(size: AppText.tick, color: AppColors.labelDim),
            ),
          const SizedBox(height: AppSpace.xs),
          if (scale != null) scale! else if (fallback != null) fallback!,
          const SizedBox(height: AppSpace.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: HandbookReferenceChip(referenceId: referenceId),
          ),
        ],
      ),
    );
  }
}
