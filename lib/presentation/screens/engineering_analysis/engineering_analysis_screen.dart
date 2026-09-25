import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/simulation_result.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/handbook_reference_chip.dart';
import '../../widgets/common/principle_card.dart';
import '../../widgets/equipment/required_equipment_panel.dart';
import '../../widgets/equipment/securing_method_selector.dart';
import '../../widgets/photos/related_photos_row.dart';
import '../../widgets/visualization/securing_schematic.dart';
import '../../widgets/common/instrument.dart';

/// The engineering review for one placed vehicle — whichever the user was
/// last working on in the securing step.
///
/// The train as a whole is reviewed on the result screen; this screen stays
/// focused on a single vehicle's checks, hardware and schematic, because that
/// is the level at which the handbook's rules are stated.
class EngineeringAnalysisScreen extends ConsumerWidget {
  const EngineeringAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consist = ref.watch(consistProvider);
    final resultsAsync = ref.watch(placementResultsProvider);
    final principlesAsync = ref.watch(principlesProvider);
    final platformAsync = ref.watch(consistPlatformProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final selectedId = ref.watch(selectedPlacementIdProvider);
    final linkerAsync = ref.watch(referenceLinkerProvider);
    final linker = linkerAsync.valueOrNull;

    final placement =
        consist.placementById(selectedId ?? '') ?? consist.placements.firstOrNull;
    final diagram = placement == null
        ? null
        : ref.watch(wagonSchematicProvider(placement.primaryWagonId));

    return InstrumentScaffold(
      title: AppStrings.engineeringAnalysisTitle,
      // Past the last stage — see [InstrumentScaffold.step].
      step: kStages.length,
      onBack: () => context.go('/securing'),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(AppStrings.errorPrefix(e))),
        data: (results) {
          final result = placement == null ? null : results[placement.id];
          if (placement == null || result == null) {
            return EmptyField(
              legend: AppStrings.engineeringAnalysisTitle,
              message: AppStrings.completeSelectionFirst,
              actionLabel: AppStrings.breadcrumbPlacement,
              onAction: () => context.go('/placement'),
            );
          }
          final vehicle = (vehiclesAsync.valueOrNull ?? const [])
              .where((v) => v.id == placement.vehicleId)
              .firstOrNull;
          final platform = platformAsync.valueOrNull;
          if (vehicle == null) {
            return EmptyField(
              legend: AppStrings.engineeringAnalysisTitle,
              message: AppStrings.completeSelectionFirst,
              actionLabel: AppStrings.breadcrumbPlacement,
              onAction: () => context.go('/placement'),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (platform != null)
                  Text(
                    '${vehicle.handbookDesignation} — ${platform.name}',
                    style: AppText.legend(size: AppText.cardTitle, color: AppColors.textPrimary, tracking: 1.4),
                  ),
                const SizedBox(height: 4),
                _SummaryBanner(result: result),
                const SizedBox(height: 24),
                const SectionHeading(AppStrings.validationChecksHeading),
                const SizedBox(height: 8),
                ...result.checks.map((c) => _CheckRow(
                      check: c,
                      relatedPhotos: linker?.photosFor(c.referenceId) ?? const [],
                    )),
                // The spur verdicts sit with the vehicle's own checks because
                // that is what they are — they are computed from the layout
                // rather than by the validator, which is why they arrive from
                // their own provider.
                Builder(builder: (context) {
                  final spurChecks = ref
                      .watch(placementSpurChecksProvider(placement.id));
                  if (spurChecks.isEmpty) return const SizedBox.shrink();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      const SectionHeading(AppStrings.spurChecksHeading),
                      const SizedBox(height: 8),
                      ...spurChecks.map((c) => _CheckRow(
                            check: c,
                            relatedPhotos:
                                linker?.photosFor(c.referenceId) ?? const [],
                          )),
                    ],
                  );
                }),
                const SizedBox(height: 24),
                const SectionHeading(AppStrings.requiredHardwareHeading),
                const SizedBox(height: 8),
                SecuringMethodSelector(
                  result: result,
                  placementId: placement.id,
                  vehicle: vehicle,
                ),
                RequiredEquipmentPanel(
                  result: result,
                  placementId: placement.id,
                  vehicle: vehicle,
                ),
                const SizedBox(height: 24),
                if (diagram != null)
                  SecuringSchematicSection(
                    diagram: diagram,
                    placementId: placement.id,
                    vehicle: vehicle,
                    result: result,
                  ),
                const SizedBox(height: 24),
                const SectionHeading(AppStrings.appliedPrinciplesHeading),
                const SizedBox(height: 8),
                principlesAsync.when(
                  loading: () => const CircularProgressIndicator(),
                  error: (e, st) => Text(AppStrings.errorPrefix(e)),
                  data: (allPrinciples) {
                    final applied = allPrinciples
                        .where((p) => result.appliedPrincipleIds.contains(p.id))
                        .toList();
                    if (applied.isEmpty) {
                      return const Text(AppStrings.noPrinciplesResolvedYet,
                          style: TextStyle(color: AppColors.textSecondary, fontSize: AppText.bodySmall));
                    }
                    return Column(
                      children: applied
                          .map((p) => PrincipleCard(
                                principle: p,
                                relatedPhotos: linker?.photosFor(p.handbookReferenceId) ?? const [],
                              ))
                          .toList(),
                    );
                  },
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.check_circle),
                    label: const Text(AppStrings.viewResultButton),
                    onPressed: () => context.go('/result'),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final SimulationResult result;
  const _SummaryBanner({required this.result});

  @override
  Widget build(BuildContext context) {
    final hasFail = result.failCount > 0;
    final hasUnknown = result.unknownCount > 0;
    final color = hasFail
        ? AppColors.outOfTolerance
        : hasUnknown
            ? AppColors.offNominal
            : AppColors.inTolerance;
    final label = hasFail
        ? AppStrings.summaryFail(result.failCount)
        : hasUnknown
            ? AppStrings.summaryIncomplete(result.unknownCount)
            : AppStrings.summaryPass;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        children: [
          Icon(hasFail ? Icons.cancel : (hasUnknown ? Icons.help : Icons.check_circle), color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label.toUpperCase(),
              style: AppText.legend(size: AppText.label, color: color, tracking: 1.2),
            ),
          ),
          Text(AppStrings.passCountLabel(result.passCount, result.checks.length),
              style: const TextStyle(fontSize: AppText.bodySmall)),
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final ValidationCheck check;
  final List<HandbookPhoto> relatedPhotos;
  const _CheckRow({required this.check, this.relatedPhotos = const []});

  @override
  Widget build(BuildContext context) {
    final color = check.status == CheckStatus.pass
        ? AppColors.inTolerance
        : check.status == CheckStatus.fail
            ? AppColors.outOfTolerance
            : AppColors.offNominal;
    final icon = check.status == CheckStatus.pass
        ? Icons.check_circle
        : check.status == CheckStatus.fail
            ? Icons.cancel
            : Icons.help;

    // A ruled row, not a box. Six identical bordered cards down a page is a
    // card grid wearing a report's clothes: the border around each finding
    // carries no information, and nesting a citation chip and a strip of
    // figures inside it puts a container inside a container. The rule above
    // the row and the tone of its mark do the same work with nothing drawn.
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  check.label.toUpperCase(),
                  style: AppText.legend(size: AppText.label, color: AppColors.textPrimary, tracking: 1.0),
                ),
                const SizedBox(height: AppSpace.xs),
                Text(
                  check.detail,
                  style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpace.sm),
                HandbookReferenceChip(referenceId: check.referenceId),
                if (relatedPhotos.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  RelatedPhotosRow(photos: relatedPhotos, thumbnailSize: 72),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
