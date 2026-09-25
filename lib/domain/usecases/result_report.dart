import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/localization/app_strings.dart';
import '../../data/models/simulation_result.dart';
import 'iron_spur_rules.dart';
import 'layout_conformance.dart';
import 'securing_measurements.dart';
import '../models/attempt_event.dart';
import 'scoring.dart';

/// How the sheet's verdict reads: passed, incomplete, or failed.
enum ReportTone { pass, warn, fail }

/// The sheet an instructor takes away from an attempt.
///
/// Built as a document rather than a screenshot so it can be filed and read
/// without the app: the mark, every check with its verdict and its handbook
/// citation, and the mistakes. It is the same information the result screen
/// shows, in the same language, and it keeps the same distinction — an
/// undecided check is printed as undecided and stays out of the mark.
///
/// The font must be passed in: the `pdf` package's built-in Helvetica has no
/// ä ň ö ü ý ş ž, and this report is entirely in Turkmen, so a default-font
/// build would print a page of tofu. `assets/fonts/NotoSans-*.ttf` are bundled
/// for exactly this.
pw.Document buildResultReport({
  required pw.Font regular,
  required pw.Font bold,
  /// Who sat the attempt. Empty is accepted so the report can still be built
  /// in a test, but the application asks before an attempt starts and the
  /// sheet says plainly when it is missing rather than leaving a blank line.
  required String traineeName,
  required String platformName,
  required int wagonCount,
  required int vehicleCount,
  required Map<String, String> designationByPlacement,
  required Map<String, SimulationResult> results,
  /// Where each stop block the trainee placed ended up, against the range the
  /// chosen arrangement calls for. Empty when nothing was placed.
  required List<SeatingFinding> seatingFindings,
  required List<AttemptEvent> events,
  /// The checks that belong to the train rather than to one machine — the deck
  /// budget, the guard wagon, the echelon class.
  ///
  /// These count in [score] exactly like the per-vehicle ones, so a report that
  /// left them out printed a failed mark with nothing in it that failed.
  List<ValidationCheck> consistChecks = const [],
  /// The verdicts on what the trainee actually laid on the wagon: the count of
  /// each kind against what the chosen case calls for, and how the stop blocks
  /// are seated. See `layout_conformance.dart`.
  List<ValidationCheck> conformanceChecks = const [],
  /// One row per stated count — what was asked for, what was placed.
  List<PieceCountFinding> pieceCountFindings = const [],
  /// The iron-spur verdicts, decided from the layout rather than by the
  /// validator — see `iron_spur_rules.dart`.
  List<ValidationCheck> spurChecks = const [],
  /// One row per spur station, including the ones nothing reached: an empty
  /// station is the mistake, and a list of only what was placed cannot show it.
  List<SpurFinding> spurFindings = const [],
  required AttemptScore score,
  required DateTime generatedAt,
}) {
  // The same three-way call the screen makes: anything failed is a failure;
  // nothing failed but something undecided is incomplete, not a pass.
  final verdictTone = score.failed > 0 || events.isNotEmpty
      ? ReportTone.fail
      : score.hasUndecided
          ? ReportTone.warn
          : ReportTone.pass;
  final verdictLabel = switch (verdictTone) {
    ReportTone.fail => AppStrings.statusFail,
    ReportTone.warn => AppStrings.statusIncomplete,
    ReportTone.pass => AppStrings.statusPass,
  };

  final theme = pw.ThemeData.withFont(base: regular, bold: bold);
  final document = pw.Document(theme: theme);

  pw.Widget heading(String text) => pw.Padding(
        padding: const pw.EdgeInsets.only(top: 14, bottom: 6),
        child: pw.Text(text,
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
      );

  String statusLabel(CheckStatus status) => switch (status) {
        CheckStatus.pass => AppStrings.reportStatusPass,
        CheckStatus.fail => AppStrings.reportStatusFail,
        CheckStatus.unknown => AppStrings.reportStatusUnknown,
      };

  document.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (context) => [
        pw.Text(AppStrings.reportTitle,
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 4),
        pw.Text(AppStrings.reportGeneratedAt(_formatDate(generatedAt)),
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
        pw.SizedBox(height: 8),
        pw.Text(
          traineeName.trim().isEmpty
              ? AppStrings.traineeUnknown
              : AppStrings.traineeLabel(traineeName),
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 12),
        pw.Text(AppStrings.reportConsistLine(platformName, wagonCount, vehicleCount),
            style: const pw.TextStyle(fontSize: 11)),
        // The verdict leads the sheet. An instructor picking this up wants the
        // call and the mark in the first inch of paper, not after three tables
        // of detail — the detail is the evidence for the verdict and belongs
        // under it.
        pw.SizedBox(height: 14),
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.all(10),
          decoration: pw.BoxDecoration(
            color: verdictTone == ReportTone.fail
                ? PdfColors.red50
                : verdictTone == ReportTone.warn
                    ? PdfColors.amber50
                    : PdfColors.green50,
            border: pw.Border.all(
              color: verdictTone == ReportTone.fail
                  ? PdfColors.red300
                  : verdictTone == ReportTone.warn
                      ? PdfColors.amber300
                      : PdfColors.green300,
            ),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(verdictLabel,
                  style: pw.TextStyle(
                      fontSize: 20, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 4),
              pw.Text(
                score.percent == null
                    ? AppStrings.attemptScoreNothingDecidable
                    : AppStrings.reportVerdictLine(score.percent!, score.passed,
                        score.decidable, score.failed),
                style: const pw.TextStyle(fontSize: 12),
              ),
              if (score.unknown > 0) ...[
                pw.SizedBox(height: 2),
                pw.Text(AppStrings.reportUndecidedLine(score.unknown),
                    style:
                        const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
              if (events.isNotEmpty) ...[
                pw.SizedBox(height: 2),
                pw.Text(AppStrings.attemptScoreMistakes(events.length),
                    style:
                        const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ],
          ),
        ),

        heading(AppStrings.attemptMistakesHeading),
        if (events.isEmpty && score.failed == 0)
          pw.Text(AppStrings.attemptNoMistakes, style: const pw.TextStyle(fontSize: 10))
        else ...[
          for (final event in events)
            pw.Bullet(
              text: '${event.description}  [${event.referenceId}]',
              style: const pw.TextStyle(fontSize: 10),
            ),
          for (final check in [
            ...failedChecks(results.values),
            for (final check in [
              ...conformanceChecks,
              ...consistChecks,
              ...spurChecks,
            ])
              if (check.status == CheckStatus.fail) check,
          ])
            pw.Bullet(
              text: '${check.detail}  [${check.referenceId}]',
              style: const pw.TextStyle(fontSize: 10),
            ),
        ],

        if (conformanceChecks.isNotEmpty) ...[
          heading(AppStrings.conformanceChecksHeading),
          _checkTable(conformanceChecks, statusLabel),
        ],

        if (spurChecks.isNotEmpty) ...[
          heading(AppStrings.spurChecksHeading),
          _checkTable(spurChecks, statusLabel),
        ],

        if (consistChecks.isNotEmpty) ...[
          heading(AppStrings.reportConsistChecksHeading),
          _checkTable(consistChecks, statusLabel),
        ],

        for (final entry in results.entries) ...[
          heading(designationByPlacement[entry.key] ?? entry.key),
          _checkTable(entry.value.checks, statusLabel),
        ],

        if (pieceCountFindings.isNotEmpty) ...[
          heading(AppStrings.pieceCountsHeading),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0),
              1: pw.FlexColumnWidth(2.6),
              2: pw.FlexColumnWidth(1.0),
              3: pw.FlexColumnWidth(1.0),
              4: pw.FlexColumnWidth(4.0),
            },
            children: [
              pw.TableRow(children: [
                _cell(AppStrings.reportSeatingVehicle, bold: true),
                _cell(AppStrings.pieceCountColumnKind, bold: true),
                _cell(AppStrings.pieceCountColumnRequired, bold: true),
                _cell(AppStrings.pieceCountColumnPlaced, bold: true),
                _cell(AppStrings.reportStatusHeader, bold: true),
              ]),
              for (final f in pieceCountFindings)
                pw.TableRow(children: [
                  _cell(f.designation),
                  _cell(AppStrings.pieceKindName(f.kind)),
                  _cell('${f.requiredCount}'),
                  _cell('${f.placedCount}'),
                  _cell(f.detail ?? AppStrings.reportStatusPass),
                ]),
            ],
          ),
        ],

        if (spurFindings.isNotEmpty) ...[
          heading(AppStrings.spurFindingsHeading),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.0),
              1: pw.FlexColumnWidth(2.4),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(5.0),
            },
            children: [
              pw.TableRow(children: [
                _cell(AppStrings.reportSeatingVehicle, bold: true),
                _cell(AppStrings.spurColumnStation, bold: true),
                _cell(AppStrings.spurColumnPlaced, bold: true),
                _cell(AppStrings.spurColumnVerdict, bold: true),
              ]),
              for (final f in spurFindings)
                pw.TableRow(children: [
                  _cell(f.designation),
                  _cell(f.station.label),
                  _cell(f.placedType ?? AppStrings.spurStationEmpty),
                  _cell(f.detail ?? AppStrings.reportStatusPass),
                ]),
            ],
          ),
        ],

        heading(AppStrings.reportSeatingHeading),
        if (seatingFindings.isEmpty)
          pw.Text(AppStrings.reportSeatingNone,
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700))
        else
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: const {
              0: pw.FlexColumnWidth(2.2),
              1: pw.FlexColumnWidth(2.4),
              2: pw.FlexColumnWidth(1.4),
              3: pw.FlexColumnWidth(1.6),
              4: pw.FlexColumnWidth(1.4),
              5: pw.FlexColumnWidth(1.6),
            },
            children: [
              pw.TableRow(children: [
                _cell(AppStrings.reportSeatingVehicle, bold: true),
                _cell(AppStrings.reportSeatingPiece, bold: true),
                _cell(AppStrings.reportSeatingMeasured, bold: true),
                _cell(AppStrings.reportSeatingRequired, bold: true),
                _cell(AppStrings.reportSeatingError, bold: true),
                _cell(AppStrings.reportStatusHeader, bold: true),
              ]),
              for (final finding in seatingFindings)
                pw.TableRow(children: [
                  _cell(finding.designation),
                  _cell(AppStrings.pieceLabel(finding.pieceId)),
                  _cell(finding.measuredCm.toStringAsFixed(1)),
                  _cell(finding.requiredRange == null
                      ? AppStrings.reportSeatingNoRange
                      : AppStrings.reportSeatingRange(
                          finding.requiredRange!.minCm,
                          finding.requiredRange!.maxCm)),
                  _cell(finding.errorCm == null
                      ? '—'
                      : AppStrings.reportSeatingOffBy(finding.errorCm!)),
                  _cell(!finding.underRunningGear
                      ? AppStrings.reportSeatingNotUnderRun
                      : !finding.facesTheRun
                          ? AppStrings.reportSeatingWrongWay
                          : statusLabel(finding.status)),
                ]),
            ],
          ),


        pw.SizedBox(height: 16),
        pw.Text(AppStrings.reportFooterNote,
            style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
      ],
    ),
  );

  return document;
}

/// A verdict table — the same four columns wherever checks are printed, so the
/// train's checks read as the same kind of thing as a machine's.
pw.Widget _checkTable(
  List<ValidationCheck> checks,
  String Function(CheckStatus) statusLabel,
) =>
    pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
      columnWidths: const {
        0: pw.FlexColumnWidth(2.8),
        // Wide enough for "Kesgitlenmedik" on one line — it was breaking
        // mid-word in a 1.1 column, which reads as a typo rather than a verdict.
        1: pw.FlexColumnWidth(1.8),
        2: pw.FlexColumnWidth(4.6),
        3: pw.FlexColumnWidth(1.4),
      },
      children: [
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey300),
          children: [
            _cell(AppStrings.reportColumnCheck, bold: true),
            _cell(AppStrings.reportColumnVerdict, bold: true),
            _cell(AppStrings.reportColumnDetail, bold: true),
            _cell(AppStrings.reportColumnSource, bold: true),
          ],
        ),
        for (final check in checks)
          pw.TableRow(children: [
            _cell(check.label),
            _cell(statusLabel(check.status)),
            _cell(check.detail),
            _cell(check.referenceId),
          ]),
      ],
    );

pw.Widget _cell(String text, {bool bold = false}) => pw.Padding(
      padding: const pw.EdgeInsets.all(4),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: 8.5,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

String _formatDate(DateTime at) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(at.day)}.${two(at.month)}.${at.year} ${two(at.hour)}:${two(at.minute)}';
}
