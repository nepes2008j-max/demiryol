import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../domain/usecases/result_report.dart';
import '../../providers/consist_providers.dart';

/// Writes the attempt's result sheet to a PDF file and returns its path.
///
/// Saving rather than printing: this runs on desktop machines that may have no
/// printer configured at all, and an instructor wants the file to keep. The
/// path is handed back so the caller can tell the user exactly where it went.
///
/// The Turkmen letters are why the fonts are bundled — the `pdf` package's
/// built-in Helvetica has none of ä ň ö ü ý ş ž, so the sheet would print as
/// tofu without them.
Future<String> exportResultReport(WidgetRef ref) async {
  final regular = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Regular.ttf'));
  final bold = pw.Font.ttf(await rootBundle.load('assets/fonts/NotoSans-Bold.ttf'));

  final consist = ref.read(consistProvider);
  final platform = ref.read(consistPlatformProvider).valueOrNull;
  final vehicles = ref.read(effectiveVehiclesProvider);
  final results = ref.read(placementResultsProvider).valueOrNull ?? const {};
  final byId = {for (final vehicle in vehicles) vehicle.id: vehicle};

  final document = buildResultReport(
    regular: regular,
    bold: bold,
    traineeName: ref.read(traineeProvider).displayName,
    platformName: platform?.name ?? '—',
    wagonCount: consist.wagons.length,
    vehicleCount: consist.placements.length,
    designationByPlacement: {
      for (final placement in consist.placements)
        placement.id: byId[placement.vehicleId]?.handbookDesignation ?? placement.vehicleId,
    },
    results: results,
    seatingFindings: ref.read(attemptSeatingFindingsProvider),
    events: ref.read(attemptLogProvider),
    consistChecks: ref.read(consistChecksProvider),
    conformanceChecks: ref.read(layoutConformanceChecksProvider),
    pieceCountFindings: ref.read(attemptPieceCountFindingsProvider),
    spurChecks: ref.read(spurChecksProvider),
    spurFindings: ref.read(attemptSpurFindingsProvider),
    score: ref.read(attemptScoreProvider),
    generatedAt: DateTime.now(),
  );

  final directory = await getApplicationDocumentsDirectory();
  final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  final file = File('${directory.path}/railsim-hasabat-$stamp.pdf');
  await file.writeAsBytes(await document.save());
  return file.path;
}
