import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/models/chock_arrangement.dart';
import '../../../domain/usecases/chock_arrangement_catalog.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../common/handbook_reference_chip.dart';
import '../photos/handbook_photo_thumbnail.dart';

/// Lets the trainee choose **how the direg is placed**, not just what size it
/// is: which of the layout cases the plates draw, and — for a tracked vehicle
/// — which of the two lateral restraints the plate offers as alternatives.
///
/// Until now the schematic seated a fixed pair of chocks whatever the
/// handbook said, so the six wheeled cases and the two tracked seating
/// distances existed in the source and nowhere in the app. Choosing here
/// changes how many chocks are drawn and where, and is scored by
/// `EngineeringValidator` against the vehicle's own weight bracket and axle
/// count when those are known.
class ChockArrangementSelector extends ConsumerWidget {
  final String placementId;
  final Vehicle vehicle;

  const ChockArrangementSelector({
    super.key,
    required this.placementId,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final arrangements = ref.watch(placementChockArrangementsProvider(placementId));
    if (arrangements.isEmpty) return const SizedBox.shrink();

    final rules = ref.watch(rulesProvider).valueOrNull;
    final restraints =
        rules == null ? const <LateralRestraintOption>[] : lateralRestraintOptionsFor(vehicle, rules);
    final choice = ref.watch(placementChockChoiceProvider)[placementId] ?? const ChockChoice();

    // The case the handbook itself would pick, when the vehicle's data can
    // decide it. Null today for every vehicle without a combat weight — the
    // list is then offered with the same "unconfirmed" wording the securing
    // method selector uses, never with one silently pre-selected.
    final overCoupling =
        ref.watch(consistProvider).placementById(placementId)?.spansCoupling ?? false;
    final recommended =
        recommendedArrangement(vehicle, arrangements, overCoupling: overCoupling);
    // Say "the weight is missing" only when it actually is. A tracked
    // vehicle never gets a recommended case — its two cases are seating
    // distances, which no weight decides between — so keying the note on a
    // null recommendation put a false explanation on every tracked vehicle,
    // including ones whose weight is recorded.
    final weightMissing = !vehicle.bracketWeightT.isAvailable;

    final linker = ref.watch(referenceLinkerProvider).valueOrNull;
    final figures = <String, HandbookPhoto>{};
    if (linker != null) {
      for (final arrangement in arrangements) {
        final photos = linker.photosFor(arrangement.referenceId);
        if (photos.isNotEmpty) figures[arrangement.id] = photos.first;
      }
    }

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.labelDim),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.chockArrangementSectionHeading,
              style: TextStyle(
                  fontSize: AppText.bodySmall, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          const Text(AppStrings.chockArrangementSelectLabel,
              style: TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold)),
          if (weightMissing)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.offNominal),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(AppStrings.chockArrangementUnconfirmedNote,
                        style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal)),
                  ),
                ],
              ),
            ),
          RadioGroup<String>(
            groupValue: choice.arrangementId,
            onChanged: (value) {
              if (value == null) return;
              ref
                  .read(placementChockChoiceProvider.notifier)
                  .chooseArrangement(placementId, value);
            },
            child: Column(
              children: [
                for (final arrangement in arrangements)
                  RadioListTile<String>(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: arrangement.id,
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(arrangement.label,
                              style: const TextStyle(
                                  fontSize: AppText.bodySmall, fontWeight: FontWeight.bold)),
                        ),
                        if (recommended != null && recommended.id == arrangement.id) ...[
                          const Text(AppStrings.chockArrangementHandbookCase,
                              style: TextStyle(
                                  fontSize: AppText.caption,
                                  color: AppColors.inTolerance,
                                  fontWeight: FontWeight.bold)),
                          const SizedBox(width: 6),
                        ],
                        HandbookReferenceChip(referenceId: arrangement.referenceId),
                      ],
                    ),
                    subtitle: _ArrangementDetail(
                      arrangement: arrangement,
                      figure: figures[arrangement.id],
                    ),
                  ),
              ],
            ),
          ),
          if (restraints.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.hairline),
            const Text(AppStrings.lateralRestraintSelectLabel,
                style: TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold)),
            RadioGroup<String>(
              groupValue: choice.lateralRestraintId,
              onChanged: (value) {
                if (value == null) return;
                ref
                    .read(placementChockChoiceProvider.notifier)
                    .chooseLateralRestraint(placementId, value);
              },
              child: Column(
                children: [
                  for (final option in restraints)
                    RadioListTile<String>(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      value: option.id,
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(option.label,
                                style: const TextStyle(fontSize: AppText.bodySmall)),
                          ),
                          HandbookReferenceChip(referenceId: option.referenceId),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The counts and distances behind one case, so the choice is made on the
/// handbook's numbers rather than on its title alone.
class _ArrangementDetail extends StatelessWidget {
  final ChockArrangement arrangement;
  final HandbookPhoto? figure;

  const _ArrangementDetail({required this.arrangement, required this.figure});

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      AppStrings.chockArrangementCountLabel(
          arrangement.chockCount, arrangement.insertCount),
      if (arrangement.seatingDistance != null)
        '${arrangement.seatingDistance!.minCm}-${arrangement.seatingDistance!.maxCm} sm',
      if (arrangement.lateralGap != null)
        AppStrings.chockArrangementGapLabel(
            arrangement.lateralGap!.minMm, arrangement.lateralGap!.maxMm),
      // The rule's own `doublingReason` is the English evidence line from
      // rules.json; the interface is Turkmen, so it says only that the count
      // is doubled and leaves the wording to the citation behind the chip.
      if (arrangement.doubled) AppStrings.chockArrangementDoubled,
    ];

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lines.join(' · '),
              style: const TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary)),
          if (figure != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: HandbookPhotoThumbnail(photo: figure!, size: 120),
            ),
          ],
        ],
      ),
    );
  }
}
