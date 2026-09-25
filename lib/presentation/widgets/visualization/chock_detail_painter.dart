import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/usecases/chock_detail_spec.dart';

/// One chock, close up, in the circular frame the plates use for their detail
/// views: the block seated against the running gear, the nails driven through
/// it into the wagon floor, and the staple over it.
///
/// This is the picture a trainee needs when they are about to place a chock,
/// and it is what a 3D view of the whole wagon would have been used for. Every
/// number on it comes from [ChockDetailSpec], which read it from `rules.json`.
class ChockDetailPainter extends CustomPainter {
  final ChockDetailSpec spec;

  /// Six nails for a lateral block, four for a longitudinal one — the plate
  /// gives different counts, so which is drawn has to be said.
  final bool lateral;

  ChockDetailPainter({required this.spec, this.lateral = false});

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final centre = Offset(w * 0.38, h * 0.52);
    final radius = math.min(w * 0.34, h * 0.42);

    // The circular frame, clipped so the drawing sits inside it like the
    // plates' detail bubbles.
    canvas.drawCircle(centre, radius, _fill(AppColors.ground));
    canvas.save();
    canvas.clipPath(Path()..addOval(Rect.fromCircle(center: centre, radius: radius)));

    final deckY = centre.dy + radius * 0.45;
    // Wagon floor planking.
    canvas.drawRect(
      Rect.fromLTRB(centre.dx - radius, deckY, centre.dx + radius, deckY + radius * 0.45),
      _fill(AppColors.panelRaised),
    );
    canvas.drawLine(Offset(centre.dx - radius, deckY), Offset(centre.dx + radius, deckY),
        _stroke(AppColors.label, 1.6));

    // The running gear the chock is seated against, entering from the right.
    final runLeft = centre.dx + radius * 0.30;
    canvas.drawRect(
      Rect.fromLTRB(runLeft, deckY - radius * 0.62, centre.dx + radius, deckY),
      _fill(AppColors.panel),
    );
    canvas.drawRect(
      Rect.fromLTRB(runLeft, deckY - radius * 0.62, centre.dx + radius, deckY),
      _stroke(AppColors.textSecondary, 1.4),
    );

    // The chock itself, with its sloped face towards the running gear.
    final chockRight = runLeft - radius * 0.16;
    final chockLeft = chockRight - radius * 0.62;
    final chockTop = deckY - radius * 0.34;
    final block = Path()
      ..moveTo(chockLeft, deckY)
      ..lineTo(chockRight, deckY)
      ..lineTo(chockRight, chockTop + radius * 0.10)
      ..lineTo(chockLeft + radius * 0.06, chockTop)
      ..close();
    canvas.drawPath(block, _fill(AppColors.label));
    canvas.drawPath(block, _stroke(AppColors.labelDim, 1.4));
    for (var i = 1; i < 3; i++) {
      final y = deckY - (deckY - chockTop) * i / 3;
      canvas.drawLine(Offset(chockLeft + radius * 0.04, y), Offset(chockRight - radius * 0.04, y),
          _stroke(AppColors.labelDim.withValues(alpha: 0.7), 1));
    }

    // Nails through the block into the floor.
    final nails = (lateral ? spec.nailsPerLateralChock : spec.nailsPerLongitudinalChock) ?? 0;
    if (nails > 0) {
      // Half of them are on the far side of the block in reality; drawn here
      // as the row the section shows.
      final drawn = math.max(2, (nails / 2).round());
      for (var i = 0; i < drawn; i++) {
        final x = chockLeft + (chockRight - chockLeft) * (i + 0.5) / drawn;
        canvas.drawLine(Offset(x, chockTop + radius * 0.06),
            Offset(x, deckY + radius * 0.18), _stroke(AppColors.hairlineBright, 1.8));
        canvas.drawCircle(Offset(x, chockTop + radius * 0.06), 2, _fill(AppColors.hairlineBright));
      }
    }

    // The staple arching over the block onto the floor.
    if (spec.stapleMinDiameterMm != null) {
      final staple = Path()
        ..moveTo(chockLeft - radius * 0.06, deckY)
        ..lineTo(chockLeft - radius * 0.06, chockTop - radius * 0.04)
        ..lineTo(chockRight + radius * 0.04, chockTop - radius * 0.04)
        ..lineTo(chockRight + radius * 0.04, deckY);
      canvas.drawPath(staple, _stroke(AppColors.offNominal, 2));
    }

    // The seating distance, dimensioned between the block and the gear.
    final seating = spec.seating;
    if (seating != null) {
      final y = deckY + radius * 0.28;
      canvas.drawLine(Offset(chockRight, y), Offset(runLeft, y), _stroke(AppColors.offNominal, 1.2));
      for (final x in [chockRight, runLeft]) {
        canvas.drawLine(
            Offset(x, y - radius * 0.05), Offset(x, y + radius * 0.05), _stroke(AppColors.offNominal, 1.2));
      }
    }

    canvas.restore();
    canvas.drawCircle(centre, radius, _stroke(AppColors.outOfTolerance, 2));

    // The legend beside the bubble, exactly the plate's own figures.
    final lines = <String>[
      if (spec.seating != null)
        AppStrings.endViewSeatingCallout(spec.seating!.minCm, spec.seating!.maxCm),
      if (nails > 0 && spec.nailDiameterMm != null && spec.nailLengthMm != null)
        AppStrings.chockDetailNails(nails, spec.nailDiameterMm!, spec.nailLengthMm!),
      if (spec.stapleMinDiameterMm != null)
        AppStrings.chockDetailStaple(spec.stapleMinDiameterMm!),
      if (spec.lateralGap != null)
        AppStrings.endViewGapCallout(spec.lateralGap!.minMm, spec.lateralGap!.maxMm),
    ];
    var y = h * 0.24;
    for (final line in lines) {
      final painter = TextPainter(
        text: TextSpan(
          text: '— $line',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 2,
        ellipsis: '…',
      )..layout(maxWidth: w * 0.30);
      painter.paint(canvas, Offset(w * 0.68, y));
      y += painter.height + 6;
    }
  }

  @override
  bool shouldRepaint(covariant ChockDetailPainter old) =>
      old.lateral != lateral ||
      old.spec.seating != spec.seating ||
      old.spec.lateralGap != spec.lateralGap ||
      old.spec.nailsPerLongitudinalChock != spec.nailsPerLongitudinalChock;
}
