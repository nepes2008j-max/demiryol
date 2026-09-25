import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/simulation_result.dart';
import '../../providers/consist_providers.dart';
import '../../../domain/usecases/iron_spur_rules.dart';
import '../../../domain/usecases/layout_conformance.dart';
import '../../widgets/common/export_result_report.dart';
import '../../widgets/common/handbook_reference_chip.dart';
import '../../../domain/usecases/scoring.dart';
import '../../../domain/usecases/securing_measurements.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/common/trainee_dialog.dart';
import '../../widgets/photos/related_photos_row.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/instrument.dart';

/// The verdict for the whole train.
///
/// Every placed vehicle is checked separately, and the counts here are the
/// sums across all of them, so a single vehicle failing its checks fails the
/// echelon. Vehicles whose checks came back `unknown` for want of source data
/// are counted as pending, never quietly folded into the passes.
/// Ends the attempt and starts a fresh one.
///
/// Confirmed first, because it throws away everything the trainee did — and
/// then it really does throw all of it away. Nothing used to be cleared at
/// all: a second attempt began on top of the first one's train, equipment,
/// securing layout and wrong-action log, and was scored on both.
Future<void> _finishAndRestart(BuildContext context, WidgetRef ref) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text(AppStrings.finishAttemptDialogTitle,
          style: TextStyle(fontSize: AppText.sectionTitle)),
      content: const SizedBox(
        width: 460,
        child: Text(AppStrings.finishAttemptDialogBody,
            style: TextStyle(fontSize: AppText.bodySmall)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.traineeCancelButton),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text(AppStrings.finishAttemptConfirm),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  resetAttempt(ref);
  // Straight into the next attempt, which begins by asking who is sitting it.
  final named = await showTraineeDialog(context, ref);
  if (!context.mounted) return;
  context.go(named ? '/consist' : '/');
}

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final consist = ref.watch(consistProvider);
    final resultsAsync = ref.watch(placementResultsProvider);
    final platformAsync = ref.watch(consistPlatformProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final attachmentsAsync = ref.watch(attachmentTypesProvider);
    final linkerAsync = ref.watch(referenceLinkerProvider);

    final trainee = ref.watch(traineeProvider);

    return InstrumentScaffold(
      title: AppStrings.resultTitle,
      // Whose sheet this is, on screen as well as in the exported file.
      subtitle: trainee.isComplete
          ? AppStrings.traineeLabel(trainee.displayName)
          : AppStrings.traineeUnknown,
      // Past the last stage: the operation is over and the trainee is reading
      // its sheet. Pointing the rail at BERKITME here said they were still
      // seating gear while the title said NETIJE.
      step: kStages.length,
      onBack: () => context.go('/securing'),
      body: resultsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text(AppStrings.errorPrefix(e))),
        data: (results) {
          if (results.isEmpty) {
            return EmptyField(
              legend: AppStrings.resultTitle,
              message: AppStrings.noSimulationRunYet,
              actionLabel: AppStrings.breadcrumbWagons,
              onAction: () => context.go('/consist'),
            );
          }
          final platform = platformAsync.valueOrNull;
          final vehicles = vehiclesAsync.valueOrNull ?? const [];
          final all = results.values.toList();

          // Counted from the same universe the mark is counted from — the
          // per-vehicle checks *and* the checks that belong to the train.
          //
          // These four figures used to sum the per-vehicle results alone while
          // the score panel below them summed those plus the consist checks,
          // so one sheet printed "1/6 satisfied" above "3/3 decided, 100%".
          // Both were arithmetically right and the pair was unreadable.
          final score = ref.watch(attemptScoreProvider);
          final passCount = score.passed;
          final failCount = score.failed;
          final unknownCount = score.unknown;
          final checkCount = passCount + failCount + unknownCount;
          final hardwareCount = all.fold<int>(0, (n, r) => n + r.requiredHardwareIds.length);

          final hasFail = failCount > 0;
          final statusLabel = hasFail
              ? AppStrings.statusFail
              : (unknownCount > 0 ? AppStrings.statusIncomplete : AppStrings.statusPass);

          // Scrollable: the sheet grew a score panel and a mistake list, and a
          // fixed Column simply ran off the bottom of the window.
          final tone = hasFail
              ? AppTone.fail
              : (unknownCount > 0 ? AppTone.warn : AppTone.pass);

          return SingleChildScrollView(
            padding: AppSpace.screen,
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                  // The verdict as the head of a report sheet, not a badge in
                  // the middle of the screen: the call, then what it was made
                  // about, then the readings it was made from.
                  _VerdictBanner(
                    tone: tone,
                    label: statusLabel,
                    subject: platform?.name,
                    detail: AppStrings.resultConsistSummary(
                      consist.wagons.length,
                      consist.placements.length,
                    ),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  // One table: the four figures on a result sheet share a
                  // right edge, which is the first thing that makes it read as
                  // a sheet rather than as four sentences.
                  ReadoutTable(rows: [
                    ReadoutRow(
                      label: AppStrings.checksPassedLabel,
                      value: '$passCount/$checkCount',
                      valueColor: AppColors.instrumentGlow,
                    ),
                    ReadoutRow(
                      label: AppStrings.checksFailedLabel,
                      value: '$failCount',
                      valueColor: failCount > 0
                          ? AppColors.outOfTolerance
                          : AppColors.textPrimary,
                    ),
                    ReadoutRow(
                      label: AppStrings.pendingDataLabel,
                      value: '$unknownCount',
                      valueColor: unknownCount > 0
                          ? AppColors.offNominal
                          : AppColors.textPrimary,
                    ),
                    ReadoutRow(
                      label: AppStrings.hardwareResolvedLabel,
                      value: '$hardwareCount',
                    ),
                  ]),
                  Builder(builder: (context) {
                    final linker = linkerAsync.valueOrNull;
                    if (linker == null) return const SizedBox.shrink();
                    final attachments = attachmentsAsync.valueOrNull ?? const [];
                    final placedVehicleIds =
                        consist.placements.map((p) => p.vehicleId).toSet();
                    final referenceIds = <String>{
                      for (final v in vehicles)
                        if (placedVehicleIds.contains(v.id)) v.referenceId,
                      if (platform != null) platform.referenceId,
                      for (final r in all) ...r.checks.map((c) => c.referenceId),
                      for (final r in all)
                        for (final hardwareId in r.requiredHardwareIds)
                          ...attachments
                              .where((a) => a.id == hardwareId)
                              .map((a) => a.referenceId),
                    };
                    final photos = linker.photosForAny(referenceIds);
                    if (photos.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SectionHeading(AppStrings.referencedFiguresHeading),
                          RelatedPhotosRow(photos: photos),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  const _ConformanceChecksSection(),
                  const _SpurChecksSection(),
                  const _ConsistChecksSection(),
                  _ScorePanel(),
                  const SizedBox(height: 32),
                  _PieceCountSection(
                      findings: ref.watch(attemptPieceCountFindingsProvider)),
                  const SizedBox(height: 16),
                  _SpurSection(findings: ref.watch(attemptSpurFindingsProvider)),
                  const SizedBox(height: 16),
                  _SeatingSection(findings: ref.watch(attemptSeatingFindingsProvider)),
                  const SizedBox(height: 16),
                  // Wrap rather than a Row of Expandeds. Three buttons with
                  // Turkmen labels — "Synagy tamamla we täzeden başla" among
                  // them — do not fit a row at any width this application is
                  // used at, and every attempt ends on this screen, so the
                  // overflow stripe was the last thing every trainee saw.
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      SizedBox(
                        width: 300,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text(AppStrings.exportPdfButton),
                          onPressed: () async {
                            final messenger = ScaffoldMessenger.of(context);
                            try {
                              final path = await exportResultReport(ref);
                              messenger.showSnackBar(SnackBar(
                                  content: Text(AppStrings.reportSavedTo(path))));
                            } catch (error) {
                              messenger.showSnackBar(SnackBar(
                                  content: Text('${AppStrings.reportFailed} $error')));
                            }
                          },
                        ),
                      ),
                      SizedBox(
                        width: 240,
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.home),
                          label: const Text(AppStrings.mainMenuButton),
                          onPressed: () => context.go('/'),
                        ),
                      ),
                      SizedBox(
                        width: 380,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.restart_alt),
                          label: const Text(AppStrings.finishAttemptButton),
                          onPressed: () => _finishAndRestart(context, ref),
                        ),
                      ),
                    ],
                  ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// The iron spurs, station by station.
///
/// Four spurs to a set and four places they go — each end of each track. The
/// sheet prints all four rows whether or not a spur reached them, because an
/// empty row is the mistake: a trainee who bolted three spurs down and stopped
/// needs to see which end of which track is bare, and a list of only what they
/// placed can never show that.
class _SpurSection extends StatelessWidget {
  final List<SpurFinding> findings;

  const _SpurSection({required this.findings});

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.spurFindingsHeading,
              style: TextStyle(
                fontSize: AppText.sectionTitle,
                fontWeight: FontWeight.bold,
                color: AppColors.label,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: AppColors.hairline),
              columnWidths: const {
                0: FlexColumnWidth(2.0),
                1: FlexColumnWidth(2.4),
                2: FlexColumnWidth(1.4),
                3: FlexColumnWidth(5.0),
              },
              children: [
                const TableRow(children: [
                  _HeadCell(AppStrings.reportSeatingVehicle),
                  _HeadCell(AppStrings.spurColumnStation),
                  _HeadCell(AppStrings.spurColumnPlaced),
                  _HeadCell(AppStrings.spurColumnVerdict),
                ]),
                for (final f in findings)
                  TableRow(children: [
                    _BodyCell(f.designation),
                    _BodyCell(f.station.label),
                    _BodyCell(f.placedType ?? AppStrings.spurStationEmpty),
                    _BodyCell(
                      f.detail ?? AppStrings.reportStatusPass,
                      color: f.status == CheckStatus.pass
                          ? AppColors.inTolerance
                          : AppColors.outOfTolerance,
                    ),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The spur verdicts, in the same ruled rows the train's checks get.
/// What the handbook asked for against what was laid down, kind by kind.
///
/// Every row is printed, the correct ones included, because the trainee needs
/// to see the whole issue against the whole requirement — a sheet listing only
/// the shortfalls does not show that the eight chocks they did put out were
/// the right eight.
class _PieceCountSection extends StatelessWidget {
  final List<PieceCountFinding> findings;

  const _PieceCountSection({required this.findings});

  @override
  Widget build(BuildContext context) {
    if (findings.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.pieceCountsHeading,
              style: TextStyle(
                fontSize: AppText.sectionTitle,
                fontWeight: FontWeight.bold,
                color: AppColors.label,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Table(
              border: TableBorder.all(color: AppColors.hairline),
              columnWidths: const {
                0: FlexColumnWidth(2.0),
                1: FlexColumnWidth(2.6),
                2: FlexColumnWidth(1.0),
                3: FlexColumnWidth(1.0),
                4: FlexColumnWidth(4.0),
              },
              children: [
                const TableRow(children: [
                  _HeadCell(AppStrings.reportSeatingVehicle),
                  _HeadCell(AppStrings.pieceCountColumnKind),
                  _HeadCell(AppStrings.pieceCountColumnRequired),
                  _HeadCell(AppStrings.pieceCountColumnPlaced),
                  _HeadCell(AppStrings.reportStatusHeader),
                ]),
                for (final f in findings)
                  TableRow(children: [
                    _BodyCell(f.designation),
                    _BodyCell(AppStrings.pieceKindName(f.kind)),
                    _BodyCell('${f.requiredCount}'),
                    _BodyCell('${f.placedCount}',
                        color: f.isCorrect
                            ? AppColors.textPrimary
                            : AppColors.outOfTolerance),
                    _BodyCell(
                      f.detail ?? AppStrings.reportStatusPass,
                      color: f.isCorrect
                          ? AppColors.inTolerance
                          : AppColors.outOfTolerance,
                    ),
                  ]),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The verdicts on what was laid down — the counts, and how the blocks sit.
class _ConformanceChecksSection extends ConsumerWidget {
  const _ConformanceChecksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = ref.watch(layoutConformanceChecksProvider);
    if (checks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(AppStrings.conformanceChecksHeading),
        const SizedBox(height: 8),
        for (final check in checks) _ConsistCheckRow(check: check),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _SpurChecksSection extends ConsumerWidget {
  const _SpurChecksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = ref.watch(spurChecksProvider);
    if (checks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(AppStrings.spurChecksHeading),
        const SizedBox(height: 8),
        for (final check in checks) _ConsistCheckRow(check: check),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Where each stop block ended up, against where the plate says it should be.
///
/// The trainer's whole point is that the seating distance is a real dimension
/// the trainee can get right or wrong; this is where they are told which.
class _SeatingSection extends StatelessWidget {
  final List<SeatingFinding> findings;

  const _SeatingSection({required this.findings});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.reportSeatingHeading,
              style: TextStyle(
                fontSize: AppText.sectionTitle,
                fontWeight: FontWeight.bold,
                color: AppColors.label,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            if (findings.isEmpty)
              const Text(
                AppStrings.reportSeatingNone,
                style: TextStyle(
                    fontSize: AppText.bodySmall, color: AppColors.textSecondary),
              )
            else
              Table(
                border: TableBorder.all(color: AppColors.hairline),
                columnWidths: const {
                  0: FlexColumnWidth(2.2),
                  1: FlexColumnWidth(2.4),
                  2: FlexColumnWidth(1.4),
                  3: FlexColumnWidth(1.6),
                  4: FlexColumnWidth(1.4),
                  5: FlexColumnWidth(2.0),
                },
                children: [
                  const TableRow(children: [
                    _HeadCell(AppStrings.reportSeatingVehicle),
                    _HeadCell(AppStrings.reportSeatingPiece),
                    _HeadCell(AppStrings.reportSeatingMeasured),
                    _HeadCell(AppStrings.reportSeatingRequired),
                    _HeadCell(AppStrings.reportSeatingError),
                    _HeadCell(AppStrings.reportStatusHeader),
                  ]),
                  for (final f in findings)
                    TableRow(children: [
                      _BodyCell(f.designation),
                      _BodyCell(AppStrings.pieceLabel(f.pieceId)),
                      _BodyCell(f.measuredCm.toStringAsFixed(1)),
                      _BodyCell(f.requiredRange == null
                          ? AppStrings.reportSeatingNoRange
                          : AppStrings.reportSeatingRange(
                              f.requiredRange!.minCm, f.requiredRange!.maxCm)),
                      _BodyCell(f.errorCm == null
                          ? '—'
                          : AppStrings.reportSeatingOffBy(f.errorCm!)),
                      _BodyCell(
                        !f.underRunningGear
                            ? AppStrings.reportSeatingNotUnderRun
                            : !f.facesTheRun
                                ? AppStrings.reportSeatingWrongWay
                                : switch (f.status) {
                                    CheckStatus.pass => AppStrings.reportStatusPass,
                                    CheckStatus.fail => AppStrings.reportStatusFail,
                                    _ => AppStrings.reportStatusUnknown,
                                  },
                        color: !f.underRunningGear || !f.facesTheRun
                            ? AppColors.outOfTolerance
                            : switch (f.status) {
                                CheckStatus.pass => AppColors.inTolerance,
                                CheckStatus.fail => AppColors.outOfTolerance,
                                _ => AppColors.textSecondary,
                              },
                      ),
                    ]),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HeadCell extends StatelessWidget {
  final String text;
  const _HeadCell(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text,
            style: const TextStyle(
                fontSize: AppText.caption,
                fontWeight: FontWeight.bold,
                color: AppColors.textSecondary)),
      );
}

class _BodyCell extends StatelessWidget {
  final String text;
  final Color? color;
  const _BodyCell(this.text, {this.color});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(6),
        child: Text(text,
            style: TextStyle(
                fontSize: AppText.bodySmall,
                fontFamily: AppText.mono,
                color: color ?? AppColors.textPrimary)),
      );
}

class _ScorePanel extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final score = ref.watch(attemptScoreProvider);
    final results = ref.watch(placementResultsProvider).valueOrNull ?? const {};
    final events = ref.watch(attemptLogProvider);
    final consistChecks = ref.watch(consistChecksProvider);
    final failures = [
      ...failedChecks(results.values),
      for (final check in consistChecks)
        if (check.status == CheckStatus.fail) check,
    ];

    // The mark is lit as confirmed only when it rests on confirmed ground.
    //
    // `isClean` asks whether anything went wrong, which is not the same
    // question as whether the attempt was actually assessed: a trainee who
    // placed a vehicle and stopped could reach 100% off three decidable
    // checks while six others could not be decided at all, and the sheet
    // printed that in the instrument's confirmed colour beside a banner
    // reading DOLY DÄL. Two headline verdicts contradicting each other, and
    // the louder one wrong. An attempt with undecided checks is amber —
    // unconfirmed — whatever the ratio says.
    final color = score.failed > 0 || score.mistakes > 0
        ? AppColors.outOfTolerance
        : score.isClean && !score.hasUndecided
            ? AppColors.inTolerance
            : AppColors.offNominal;

    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The mark is a reading in the column with the figures it was made
          // from, not a display-size number with three small lines propping it
          // up. The trainee needs to see what the mark is *of* — and a score
          // computed from five decidable checks out of eight is a different
          // fact from the same percentage computed from all eight.
          ReadoutTable(rows: [
            ReadoutRow(
              label: AppStrings.attemptScoreHeading,
              value: score.percent == null
                  ? '—'
                  : AppStrings.attemptScorePercent(score.percent!),
              valueColor: color,
            ),
            ReadoutRow(
              label: AppStrings.attemptScoreDecidableLabel,
              value: '${score.passed}/${score.decidable}',
            ),
            if (score.hasUndecided)
              ReadoutRow(
                label: AppStrings.attemptScoreUnknownLabel,
                value: '${score.unknown}',
                valueColor: AppColors.offNominal,
              ),
            ReadoutRow(
              label: AppStrings.attemptScoreMistakesLabel,
              value: '${score.mistakes + score.failed}',
              valueColor: (score.mistakes + score.failed) > 0
                  ? AppColors.outOfTolerance
                  : AppColors.textPrimary,
            ),
          ]),
          if (score.percent == null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(AppStrings.attemptScoreNothingDecidable,
                style: AppText.prose(size: AppText.bodySmall, color: AppColors.offNominal)),
          ],
          const SizedBox(height: AppSpace.lg),
          Text(AppStrings.attemptMistakesHeading.toUpperCase(),
              style: AppText.legend(size: AppText.caption, color: AppColors.labelDim, tracking: 1.8)),
          const SizedBox(height: 6),
          if (failures.isEmpty && events.isEmpty)
            const Text(AppStrings.attemptNoMistakes,
                style: TextStyle(fontSize: AppText.bodySmall, color: AppColors.textSecondary))
          else ...[
            for (final event in events)
              _MistakeRow(text: event.description, referenceId: event.referenceId),
            for (final check in failures)
              _MistakeRow(text: check.detail, referenceId: check.referenceId),
          ],
        ],
      ),
    );
  }
}

/// The checks that belong to the train rather than to one machine.
///
/// The per-vehicle checks each get a row on the analysis screen, which is
/// written for one placement at a time. The deck budget, the guard wagon and
/// the echelon class have no such screen — they were counted in the mark and
/// bulleted in the mistake list when they failed, which meant a trainee who
/// passed them never saw what they said, and one who failed them read the
/// complaint without the reading behind it.
class _ConsistChecksSection extends ConsumerWidget {
  const _ConsistChecksSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final checks = ref.watch(consistChecksProvider);
    if (checks.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(AppStrings.consistChecksHeading),
        const SizedBox(height: 8),
        for (final check in checks) _ConsistCheckRow(check: check),
        const SizedBox(height: 24),
      ],
    );
  }
}

class _ConsistCheckRow extends StatelessWidget {
  final ValidationCheck check;

  const _ConsistCheckRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (check.status) {
      CheckStatus.pass => (Icons.check_circle_outline, AppColors.inTolerance),
      CheckStatus.fail => (Icons.close, AppColors.outOfTolerance),
      CheckStatus.unknown => (Icons.help_outline, AppColors.offNominal),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.label.toUpperCase(),
                    style: AppText.legend(
                        size: AppText.bodySmall, color: color, tracking: 1.0)),
                const SizedBox(height: 2),
                Text(check.detail,
                    style: AppText.prose(
                        size: AppText.bodySmall,
                        color: AppColors.textSecondary,
                        height: 1.4)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          HandbookReferenceChip(referenceId: check.referenceId),
        ],
      ),
    );
  }
}

class _MistakeRow extends StatelessWidget {
  final String text;
  final String referenceId;

  const _MistakeRow({required this.text, required this.referenceId});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 2),
              child: Icon(Icons.close, size: 16, color: AppColors.outOfTolerance),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(text, style: const TextStyle(fontSize: AppText.bodySmall)),
            ),
            const SizedBox(width: 8),
            HandbookReferenceChip(referenceId: referenceId),
          ],
        ),
      );
}


/// The verdict, at the head of the report sheet.
///
/// A struck frame in the verdict's own tone, the mark and the word in mono,
/// and under them the two facts the call was made about. It is a strip across
/// the sheet rather than a badge in the middle of the field, because a result
/// is read as the top line of a document, not as a trophy.
class _VerdictBanner extends StatelessWidget {
  final AppTone tone;
  final String label;
  final String? subject;
  final String detail;

  const _VerdictBanner({
    required this.tone,
    required this.label,
    required this.subject,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final accent = tone.accent;
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.07),
        border: Border.all(color: accent.withValues(alpha: 0.55)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(tone.icon, color: accent, size: 40),
          const SizedBox(width: AppSpace.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.toUpperCase(),
                  style: AppText.legend(
                    size: AppText.screenTitle,
                    color: accent,
                    tracking: AppText.trackTitle,
                  ),
                ),
                if (subject != null) ...[
                  const SizedBox(height: AppSpace.sm),
                  Text(subject!, style: AppText.prose(size: AppText.bodySmall, color: AppColors.textSecondary)),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpace.lg),
          Flexible(
            child: Text(
              detail,
              textAlign: TextAlign.right,
              style: AppText.legend(size: AppText.caption, color: AppColors.label, tracking: 1.2),
            ),
          ),
        ],
      ),
    );
  }
}
