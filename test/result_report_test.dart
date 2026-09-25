import 'dart:io';

import 'package:pdf/widgets.dart' as pw;
import 'package:test/test.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/domain/models/attempt_event.dart';
import 'package:railsim/domain/usecases/result_report.dart';
import 'package:railsim/domain/usecases/scoring.dart';

pw.Font _font(String path) =>
    pw.Font.ttf(File(path).readAsBytesSync().buffer.asByteData());

ValidationCheck _check(CheckStatus status, String detail) => ValidationCheck(
      ruleId: 'r',
      label: 'Ýer basyşy',
      status: status,
      detail: detail,
      referenceId: 'para-51',
    );

void main() {
  final regular = _font('assets/fonts/NotoSans-Regular.ttf');
  final bold = _font('assets/fonts/NotoSans-Bold.ttf');

  pw.Document build({List<AttemptEvent> events = const []}) {
    final results = {
      'placement-0': SimulationResult(
        vehicleId: 'veh-t34',
        platformId: 'plat-generic-open-flatcar',
        checks: [
          _check(CheckStatus.pass, 'Söweş agramy belli: 26 t'),
          _check(CheckStatus.fail, 'Ýük wagonyň poluna sygmaýar'),
          _check(CheckStatus.unknown, 'Çykarylan maglumatlarda ýok'),
        ],
        requiredHardwareIds: const ['att-wood-chock'],
        appliedPrincipleIds: const [],
      ),
    };
    return buildResultReport(
      regular: regular,
      bold: bold,
      traineeName: 'Amanow Aman',
      platformName: 'Generic open flatcar (açyk wagon)',
      wagonCount: 1,
      vehicleCount: 2,
      designationByPlacement: const {'placement-0': 'T-34'},
      results: results,
      seatingFindings: const [],
      events: events,
      score: scoreAttempt(results: results.values, events: events),
      generatedAt: DateTime(2026, 8, 30, 14, 5),
    );
  }

  group('result report', () {
    test('builds a non-trivial PDF', () async {
      final bytes = await build().save();
      expect(bytes.length, greaterThan(5000));
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('embeds the bundled font, which is what makes Turkmen readable', () async {
      // The pdf package's built-in Helvetica has no ä ň ö ü ý ş ž; without an
      // embedded font this whole sheet would print as tofu.
      final bytes = await build().save();
      final raw = String.fromCharCodes(bytes);
      expect(raw, contains('FontFile2'), reason: 'a TrueType font must be embedded');
      expect(raw, contains('NotoSans'));
    });

    test('a logged mistake reaches the sheet', () async {
      final withEvent = build(events: [
        AttemptEvent(
          kind: AttemptEventKind.wrongWagonType,
          description: 'Ýaramaýan wagon görnüşi',
          referenceId: 'para-51',
          at: DateTime(2026),
        )
      ]);
      final plain = await build().save();
      final marked = await withEvent.save();
      expect(marked.length, greaterThan(plain.length));
    });

    test('the score printed keeps undecided checks out of the percentage', () {
      final results = [
        SimulationResult(
          vehicleId: 'v',
          platformId: 'p',
          checks: [
            _check(CheckStatus.pass, 'a'),
            _check(CheckStatus.unknown, 'b'),
            _check(CheckStatus.unknown, 'c'),
          ],
          requiredHardwareIds: const [],
          appliedPrincipleIds: const [],
        )
      ];
      final score = scoreAttempt(results: results, events: const []);
      expect(score.percent, 100, reason: 'one decidable check, and it passed');
      expect(score.unknown, 2, reason: 'reported, never scored');
    });
  });
}
