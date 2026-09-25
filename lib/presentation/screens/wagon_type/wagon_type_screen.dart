import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/platform.dart';
import '../../../domain/models/attempt_event.dart';
import '../../../data/models/vehicle.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/cards/platform_card.dart';
import '../../widgets/common/platform_detail_dialog.dart';
import '../../widgets/common/handbook_reference_chip.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/instrument.dart';

/// Which wagon the user tapped that cannot take this load, so the screen can
/// say why. Cleared as soon as an approved wagon is chosen.
final _rejectedWagonProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Step 3 of the loading flow: which wagon type the consist is made of.
///
/// Unlike the old platform screen, which matched one selected vehicle, this
/// has to suit the whole load — a wagon type only qualifies if it is approved
/// for **every** vehicle category the user ordered in step 2. A consist of
/// mixed tracked and wheeled vehicles therefore narrows the list rather than
/// silently matching on whichever vehicle happened to be selected.
///
/// Choosing a type is what actually builds the wagons: the step-1 count and
/// this type together produce the `TrainConsist` the placement screen works
/// on.
class WagonTypeScreen extends ConsumerWidget {
  const WagonTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final platformsAsync = ref.watch(platformsProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final orders = ref.watch(vehicleOrdersProvider);
    final selectedWagonType = ref.watch(selectedWagonTypeProvider);
    final wagonCount = ref.watch(wagonCountProvider);
    final linkerAsync = ref.watch(referenceLinkerProvider);

    return InstrumentScaffold(
      title: AppStrings.wagonTypeTitle,
      step: 2,
      onBack: () => context.go('/vehicles'),
      body: platformsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(AppStrings.failedToLoadPlatforms(e))),
        data: (platforms) {
          final vehicles = vehiclesAsync.valueOrNull ?? const <Vehicle>[];
          final byId = {for (final v in vehicles) v.id: v};

          // Every distinct category in the load. An ordered vehicle the
          // catalogue no longer knows contributes no constraint rather than
          // silently excluding every wagon.
          final orderedCategories = <VehicleCategory>{
            for (final order in orders)
              if (byId[order.vehicleId] != null) byId[order.vehicleId]!.category,
          };

          // Every wagon kind a trainee chooses between is listed, not only the
          // ones that fit: recognising that a covered wagon or a tank wagon
          // cannot take a tracked vehicle is part of the exercise, and a wagon
          // silently missing from the list teaches nothing. The echelon weight
          // classes are still excluded — they are an accounting unit for
          // composing a train, not something a vehicle is loaded onto.
          final selectable = platforms.where((p) => p.isSelectableWagon).toList();
          final categoryNames = orderedCategories.map((c) => c.name).toList();
          final rejectedId = ref.watch(_rejectedWagonProvider);
          final rejected =
              selectable.firstWhereOrNull((p) => p.id == rejectedId);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xxl, AppSpace.xl, AppSpace.xxl, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeading(
                      AppStrings.wagonTypeTitle,
                      note: AppStrings.wagonTypeSubtitle,
                      live: true,
                      trailing: Text(
                        AppStrings.consistWagonCountValue(wagonCount),
                        style: AppText.value(
                          size: AppText.readoutSmall,
                          color: wagonCount <= 0
                              ? AppColors.offNominal
                              : AppColors.instrumentGlow,
                        ),
                      ),
                    ),
                    if (wagonCount <= 0)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.md),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, size: 16, color: AppColors.offNominal),
                            const SizedBox(width: AppSpace.sm),
                            Flexible(
                              child: Text(
                                AppStrings.wagonTypeNeedsWagonCount,
                                style: AppText.prose(
                                    size: AppText.bodySmall, color: AppColors.offNominal),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (rejected != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AppSpace.xxl, 0, AppSpace.xxl, AppSpace.md),
                  child: _WagonRejectedPanel(platform: rejected),
                ),
              Expanded(
                child: selectable.isEmpty
                    ? const EmptyField(
                        legend: AppStrings.wagonTypeTitle,
                        message: AppStrings.wagonTypeNoneAvailable,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                            AppSpace.xxl, AppSpace.md, AppSpace.xxl, AppSpace.xl),
                        itemCount: selectable.length,
                        separatorBuilder: (_, __) => const SizedBox.shrink(),
                        itemBuilder: (context, i) {
                          final p = selectable[i];
                          final approved = p.acceptsAll(categoryNames);
                          return PlatformCard(
                            platform: p,
                            approved: approved,
                            selected: p.id == selectedWagonType,
                            onTap: () {
                              if (wagonCount <= 0) {
                                // Step 1 sets how many wagons the train has.
                                // Reached directly (or with the count reset),
                                // choosing a type here would build a train of
                                // zero wagons and land on a placement screen
                                // with nowhere to put anything.
                                ref.read(_rejectedWagonProvider.notifier).state = null;
                                context.go('/consist');
                                return;
                              }
                              if (!approved) {
                                // Rejecting the wrong wagon is the exercise:
                                // say why, load nothing onto it, and record it
                                // — this never becomes a check, so without the
                                // log it would leave no trace in the result.
                                ref.read(_rejectedWagonProvider.notifier).state = p.id;
                                ref.read(attemptLogProvider.notifier).record(AttemptEvent(
                                      kind: AttemptEventKind.wrongWagonType,
                                      description:
                                          AppStrings.attemptWrongWagonEvent(p.name),
                                      referenceId: p.referenceId,
                                      at: DateTime.now(),
                                    ));
                                return;
                              }
                              ref.read(_rejectedWagonProvider.notifier).state = null;
                              ref.read(selectedWagonTypeProvider.notifier).state = p.id;
                              ref.read(consistProvider.notifier).setWagons(
                                    count: wagonCount,
                                    platformId: p.id,
                                  );
                              context.go('/placement');
                            },
                            onInfoTap: () => showPlatformDetailDialog(
                              context,
                              platform: p,
                              relatedPhotos:
                                  linkerAsync.valueOrNull?.photosFor(p.referenceId) ?? const [],
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}


/// Explains, with the handbook citation behind it, why the wagon the user just
/// tapped cannot be loaded — instead of the tap doing nothing.
class _WagonRejectedPanel extends StatelessWidget {
  final Platform platform;

  const _WagonRejectedPanel({required this.platform});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.outOfTolerance.withValues(alpha: 0.12),
        border: Border.all(color: AppColors.outOfTolerance),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.block, color: AppColors.outOfTolerance, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${AppStrings.wagonRejectedHeading} — ${platform.name}',
                  style: AppText.legend(
                    size: AppText.caption,
                    color: AppColors.outOfTolerance,
                    tracking: 1.2,
                  ),
                ),
              ),
            ],
          ),
          if (platform.displayNotApprovedReason != null) ...[
            const SizedBox(height: 6),
            Text(platform.displayNotApprovedReason!,
                style: const TextStyle(fontSize: AppText.bodySmall, color: AppColors.textPrimary)),
          ],
          const SizedBox(height: 6),
          const Text(AppStrings.wagonChooseCorrectHint,
              style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          HandbookReferenceChip(referenceId: platform.referenceId),
        ],
      ),
    );
  }
}
