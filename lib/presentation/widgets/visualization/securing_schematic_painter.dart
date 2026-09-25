import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/schematic_element.dart';
import 'dashed_line_painter.dart';

/// Which symbol a hardware pair is drawn as — the only thing that makes
/// iron spurs, iron chock-boots, KGUUB chocks, and wood chocks visually
/// distinguishable at a glance instead of identical dots with different
/// text labels.
enum _MarkerShape { diamond, roundedSquare, ringedCircle, wedge }

/// Draws a [SchematicDiagram] exactly as given. This painter makes no
/// engineering decisions — it only maps each [SchematicElement]'s kind and
/// normalized points to pixels and a visual style. All the "what does this
/// vehicle actually need" logic lives in `SchematicBuilder`
/// (domain/usecases), not here.
class SecuringSchematicPainter extends CustomPainter {
  final SchematicDiagram diagram;

  SecuringSchematicPainter(this.diagram);

  Offset _px(SchematicPoint p, Size size) => Offset(p.dx * size.width, p.dy * size.height);

  @override
  void paint(Canvas canvas, Size size) {
    for (final element in diagram.elements) {
      switch (element.kind) {
        case SchematicElementKind.platformDeck:
          _paintRect(canvas, size, element, AppColors.panelRaised, AppColors.label);
          break;
        case SchematicElementKind.vehicleBody:
          _paintRect(canvas, size, element, AppColors.vehicleBody, AppColors.vehicleEdge);
          _paintCenteredLabel(canvas, size, element, above: true);
          break;
        case SchematicElementKind.railDirection:
          _paintLine(canvas, size, element, AppColors.hairline, width: 1.5);
          break;
        case SchematicElementKind.symmetryAxis:
          _paintDashedLine(canvas, size, element, AppColors.labelDim);
          break;
        case SchematicElementKind.trackRun:
          _paintLine(canvas, size, element, AppColors.textSecondary, width: 3);
          break;
        case SchematicElementKind.wheelRun:
          _paintDot(canvas, size, element, AppColors.textSecondary, radius: 4);
          break;
        case SchematicElementKind.ironSpurPair:
          _paintHardwarePair(canvas, size, element, _MarkerShape.diamond);
          break;
        case SchematicElementKind.ironChockBootPair:
          _paintHardwarePair(canvas, size, element, _MarkerShape.roundedSquare);
          break;
        case SchematicElementKind.reusableChockPair:
          _paintHardwarePair(canvas, size, element, _MarkerShape.ringedCircle);
          break;
        case SchematicElementKind.woodChockPair:
          _paintHardwarePair(canvas, size, element, _MarkerShape.wedge);
          break;
        case SchematicElementKind.spacerBoard:
          _paintRect(canvas, size, element, AppColors.labelDim, AppColors.label);
          _paintCenteredLabel(canvas, size, element, above: true);
          break;
        case SchematicElementKind.wireLashing:
          _paintDashedLine(canvas, size, element, AppColors.offNominal, dashWidth: 4, dashSpace: 3);
          break;
        case SchematicElementKind.attachmentPoint:
          _paintDot(canvas, size, element, AppColors.offNominal, radius: 3.5, filled: false);
          break;
      }
    }
  }

  void _paintRect(Canvas canvas, Size size, SchematicElement e, Color fill, Color border) {
    final rect = Rect.fromPoints(_px(e.points[0], size), _px(e.points[1], size));
    canvas.drawRect(rect, Paint()..color = fill);
    canvas.drawRect(rect, Paint()..color = border..style = PaintingStyle.stroke..strokeWidth = 1.5);
  }

  void _paintLine(Canvas canvas, Size size, SchematicElement e, Color color, {double width = 1}) {
    canvas.drawLine(
      _px(e.points[0], size),
      _px(e.points[1], size),
      Paint()
        ..color = color
        ..strokeWidth = width,
    );
  }

  void _paintDashedLine(Canvas canvas, Size size, SchematicElement e, Color color,
      {double dashWidth = 5, double dashSpace = 4}) {
    drawDashedLine(
      canvas,
      _px(e.points[0], size),
      _px(e.points[1], size),
      Paint()..color = color..strokeWidth = 1.2,
      dashWidth: dashWidth,
      dashSpace: dashSpace,
    );
  }

  void _paintDot(Canvas canvas, Size size, SchematicElement e, Color color,
      {double radius = 4, bool filled = true}) {
    final paint = Paint()..color = color;
    if (!filled) {
      paint
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
    }
    canvas.drawCircle(_px(e.points[0], size), radius, paint);
  }

  /// Hardware pairs are drawn as two shaped markers (one per side, the
  /// shape identifying the equipment kind) joined by a connector, with a
  /// label above the pair. A [SchematicElement.isSelectionMismatch] element
  /// switches to a warning color, a dashed connector, and a "✕" badge —
  /// still drawn at the user's actual selection, just clearly flagged as
  /// not matching the handbook-mandated type. This function only chooses
  /// how to draw that verdict; it never decides it.
  void _paintHardwarePair(Canvas canvas, Size size, SchematicElement e, _MarkerShape shape) {
    final a = _px(e.points[0], size);
    final b = _px(e.points[1], size);
    final color = e.isSelectionMismatch ? AppColors.offNominal : AppColors.outOfTolerance;
    final markerPaint = Paint()..color = color;
    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.2;

    if (e.isSelectionMismatch) {
      drawDashedLine(canvas, a, b, linePaint, dashWidth: 4, dashSpace: 3);
    } else {
      canvas.drawLine(a, b, linePaint);
    }
    _drawMarker(canvas, a, shape, markerPaint, color);
    _drawMarker(canvas, b, shape, markerPaint, color);

    final mid = Offset((a.dx + b.dx) / 2, a.dy);
    final label = e.isSelectionMismatch ? '✕ ${e.label}' : e.label;
    _drawLabel(canvas, label, Offset(mid.dx, a.dy - 12), color: e.isSelectionMismatch ? color : null);
  }

  void _drawMarker(Canvas canvas, Offset center, _MarkerShape shape, Paint fillPaint, Color strokeColor) {
    const r = 5.0;
    switch (shape) {
      case _MarkerShape.diamond:
        final path = Path()
          ..moveTo(center.dx, center.dy - r)
          ..lineTo(center.dx + r, center.dy)
          ..lineTo(center.dx, center.dy + r)
          ..lineTo(center.dx - r, center.dy)
          ..close();
        canvas.drawPath(path, fillPaint);
        break;
      case _MarkerShape.roundedSquare:
        final rect = RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: r * 1.8, height: r * 1.8),
          const Radius.circular(2),
        );
        canvas.drawRRect(rect, fillPaint);
        break;
      case _MarkerShape.ringedCircle:
        canvas.drawCircle(center, r, fillPaint);
        canvas.drawCircle(
          center,
          r + 2.5,
          Paint()
            ..color = strokeColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        break;
      case _MarkerShape.wedge:
        final path = Path()
          ..moveTo(center.dx - r, center.dy + r * 0.7)
          ..lineTo(center.dx + r, center.dy + r * 0.7)
          ..lineTo(center.dx, center.dy - r * 0.7)
          ..close();
        canvas.drawPath(path, fillPaint);
        break;
    }
  }

  void _paintCenteredLabel(Canvas canvas, Size size, SchematicElement e, {bool above = false}) {
    final rect = Rect.fromPoints(_px(e.points[0], size), _px(e.points[1], size));
    _drawLabel(canvas, e.label, Offset(rect.center.dx, above ? rect.top - 12 : rect.center.dy));
  }

  void _drawLabel(Canvas canvas, String text, Offset center, {Color? color}) {
    if (text.isEmpty) return;
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(color: color ?? AppColors.textPrimary, fontSize: 12, fontWeight: color != null ? FontWeight.bold : null),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout(maxWidth: 160);
    painter.paint(canvas, center - Offset(painter.width / 2, painter.height / 2));
  }

  @override
  bool shouldRepaint(covariant SecuringSchematicPainter oldDelegate) =>
      oldDelegate.diagram != diagram;
}
