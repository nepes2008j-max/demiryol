import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/schematic_element.dart';

/// Draws a wagon and its load from above, the way the handbook's own plates
/// pair a side elevation with a plan strip (see plate-05, where the top-down
/// band shows wheel footprints, longitudinal and lateral chocks, and the wire
/// lashing runs).
///
/// It paints the SAME [SchematicDiagram] the side view does, reusing each
/// element's horizontal position and only reinterpreting the vertical axis as
/// the wagon's width instead of its elevation. That is what keeps the two
/// views in step: there is one layout, drawn twice, so a vehicle cannot
/// appear in one place side-on and another place from above.
///
/// Like every other schematic in this app, the geometry is illustrative. No
/// vehicle or wagon in the current data has real dimensions, so nothing here
/// may be read as a measured clearance — the caller is expected to show the
/// not-to-scale notice alongside.
class WagonPlanPainter extends CustomPainter {
  final SchematicDiagram diagram;

  /// The placement currently being worked on, drawn highlighted so the user
  /// can tell which vehicle a drag or a securing choice applies to.
  final String? selectedPlacementId;

  WagonPlanPainter(this.diagram, {this.selectedPlacementId});

  // Vertical bands, as fractions of the drawn height. From above, the deck
  // fills the wagon's width and each vehicle sits inside it with its two
  // running edges (tracks, or the two wheel lines) near the vehicle's sides.
  static const _deckTop = 0.12, _deckBottom = 0.88;
  static const _bodyTop = 0.26, _bodyBottom = 0.74;
  static const _runNearTop = 0.34, _runNearBottom = 0.66;

  double _x(double dx, Size size) => dx * size.width;
  double _y(double fraction, Size size) => fraction * size.height;

  @override
  void paint(Canvas canvas, Size size) {
    final deck = diagram
        .elementsOfKind(SchematicElementKind.platformDeck)
        .cast<SchematicElement?>()
        .firstWhere((_) => true, orElse: () => null);
    if (deck != null) _paintDeck(canvas, size, deck);

    for (final element in diagram.elements) {
      switch (element.kind) {
        case SchematicElementKind.vehicleBody:
          _paintVehicle(canvas, size, element);
          break;
        case SchematicElementKind.trackRun:
        case SchematicElementKind.wheelRun:
          _paintRun(canvas, size, element);
          break;
        case SchematicElementKind.ironSpurPair:
        case SchematicElementKind.ironChockBootPair:
        case SchematicElementKind.reusableChockPair:
        case SchematicElementKind.woodChockPair:
        case SchematicElementKind.spacerBoard:
          _paintChock(canvas, size, element);
          break;
        case SchematicElementKind.wireLashing:
          _paintLashing(canvas, size, element);
          break;
        case SchematicElementKind.platformDeck:
        case SchematicElementKind.railDirection:
        case SchematicElementKind.symmetryAxis:
        case SchematicElementKind.attachmentPoint:
          break;
      }
    }

    _paintCentreLine(canvas, size, deck);
  }

  void _paintDeck(Canvas canvas, Size size, SchematicElement deck) {
    final rect = Rect.fromLTRB(
      _x(deck.points.first.dx, size),
      _y(_deckTop, size),
      _x(deck.points.last.dx, size),
      _y(_deckBottom, size),
    );
    canvas.drawRect(rect, Paint()..color = AppColors.panelRaised);
    canvas.drawRect(
      rect,
      Paint()
        ..color = AppColors.label
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  void _paintVehicle(Canvas canvas, Size size, SchematicElement element) {
    final selected =
        selectedPlacementId != null && element.placementId == selectedPlacementId;
    final rect = Rect.fromLTRB(
      _x(element.points.first.dx, size),
      _y(_bodyTop, size),
      _x(element.points.last.dx, size),
      _y(_bodyBottom, size),
    );
    canvas.drawRect(rect, Paint()..color = AppColors.vehicleBody);
    canvas.drawRect(
      rect,
      Paint()
        ..color = selected ? AppColors.instrument : AppColors.vehicleEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = selected ? 2.5 : 1.2,
    );
    _paintLabel(canvas, rect, element.label);
  }

  /// A tracked vehicle's two track bands, or a wheeled vehicle's wheel pairs
  /// — drawn on both sides of the centre line, which is what distinguishes
  /// this view from the side elevation, where the near side hides the far one.
  void _paintRun(Canvas canvas, Size size, SchematicElement element) {
    final paint = Paint()..color = AppColors.ground.withValues(alpha: 0.75);
    if (element.kind == SchematicElementKind.trackRun) {
      final left = _x(element.points.first.dx, size);
      final right = _x(element.points.last.dx, size);
      for (final band in [_runNearTop, _runNearBottom]) {
        final centre = _y(band, size);
        canvas.drawRect(
          Rect.fromLTRB(left, centre - 4, right, centre + 4),
          paint,
        );
      }
      return;
    }
    final x = _x(element.points.first.dx, size);
    for (final band in [_runNearTop, _runNearBottom]) {
      final centre = _y(band, size);
      canvas.drawRect(Rect.fromLTRB(x - 5, centre - 4, x + 5, centre + 4), paint);
    }
  }

  /// Chocks and metal stops, drawn at both running edges. On the plates these
  /// are the yellow blocks seated against the tracks or tyres.
  void _paintChock(Canvas canvas, Size size, SchematicElement element) {
    final paint = Paint()
      ..color = element.isSelectionMismatch ? AppColors.outOfTolerance : AppColors.labelDim;
    for (final point in element.points) {
      final x = _x(point.dx, size);
      for (final band in [_runNearTop, _runNearBottom]) {
        final centre = _y(band, size);
        canvas.drawRect(Rect.fromLTRB(x - 4, centre - 7, x + 4, centre + 7), paint);
      }
    }
  }

  /// Lashings run from the vehicle out to the deck edge, so from above they
  /// read as diagonals towards the wagon's sides.
  void _paintLashing(Canvas canvas, Size size, SchematicElement element) {
    if (element.points.isEmpty) return;
    final paint = Paint()
      ..color = element.isSelectionMismatch ? AppColors.outOfTolerance : AppColors.offNominal
      ..strokeWidth = 1.4;
    for (final point in element.points) {
      final x = _x(point.dx, size);
      canvas.drawLine(
        Offset(x, _y(_runNearTop, size)),
        Offset(x - 14, _y(_deckTop, size)),
        paint,
      );
      canvas.drawLine(
        Offset(x, _y(_runNearBottom, size)),
        Offset(x - 14, _y(_deckBottom, size)),
        paint,
      );
    }
  }

  /// The wagon's longitudinal axis. The handbook requires a vehicle to be
  /// centred on it (para. 34), and from above that is the line the eye
  /// actually checks against.
  void _paintCentreLine(Canvas canvas, Size size, SchematicElement? deck) {
    if (deck == null) return;
    final y = size.height / 2;
    final paint = Paint()
      ..color = AppColors.label.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    const dash = 6.0, gap = 5.0;
    var x = _x(deck.points.first.dx, size);
    final end = _x(deck.points.last.dx, size);
    while (x < end) {
      canvas.drawLine(Offset(x, y), Offset((x + dash).clamp(x, end), y), paint);
      x += dash + gap;
    }
  }

  void _paintLabel(Canvas canvas, Rect rect, String label) {
    if (label.isEmpty || rect.width < 42) return;
    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: rect.width - 6);
    painter.paint(
      canvas,
      Offset(rect.center.dx - painter.width / 2, rect.center.dy - painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant WagonPlanPainter old) =>
      old.diagram != diagram || old.selectedPlacementId != selectedPlacementId;
}
