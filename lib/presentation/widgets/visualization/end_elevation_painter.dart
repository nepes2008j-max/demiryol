import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/usecases/chock_detail_spec.dart';

/// The vehicle seen from the end of the wagon — the handbook's third view, and
/// the one that answers what a side view cannot.
///
/// Everything this drawing carries is a *lateral* fact: the two tracks or
/// tyres side by side, a chock outboard of each with the 20-30 mm gap the
/// plate dimensions from the tyre's outer face (15-20 mm where the vehicle
/// spans a coupling), and how far the load may hang past the wagon's edge
/// before a guard wagon is required. None of that is visible in profile, which
/// is why the app was missing it and why this is the honest alternative to a
/// 3D scene: the same information, drawn the way the source draws it, with
/// every number citable.
///
/// Like the side elevation it is a **proportioned drawing, not a scale
/// drawing** — no vehicle in the extract has a measured width and no wagon has
/// one either, so the millimetres are lettered on as callouts rather than
/// being distances on screen.
class EndElevationPainter extends CustomPainter {
  final VehicleCategory category;
  final ChockDetailSpec spec;
  final String designation;

  EndElevationPainter({
    required this.category,
    required this.spec,
    required this.designation,
  });

  // Vertical layout, as fractions of the canvas — drawing conventions.
  static const _railY = 0.86;
  static const _sleeperY = 0.90;
  static const _groundY = 0.95;
  static const _wagonBottomY = 0.72;
  static const _deckY = 0.62;
  static const _runBottomY = _deckY;
  static const _runTopY = 0.48;
  static const _bodyTopY = 0.28;

  // Horizontal layout: the wagon's half-width, then the vehicle inside it.
  static const _wagonHalf = 0.30;
  static const _runOuterHalf = 0.20;
  static const _runInnerHalf = 0.12;
  static const _bodyHalf = 0.235;

  Paint _fill(Color c) => Paint()..color = c;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = w / 2;

    _paintTrackBed(canvas, size, cx);
    _paintWagonSection(canvas, size, cx);
    _paintVehicleSection(canvas, size, cx);
    _paintChocks(canvas, size, cx);
    _paintCallouts(canvas, size, cx);

    // Designation over the load, as on the side view.
    _text(canvas, designation, Offset(cx, (_bodyTopY - 0.10) * h),
        centered: true, bold: true, size: 11, color: AppColors.textPrimary);
  }

  void _paintTrackBed(Canvas canvas, Size size, double cx) {
    final w = size.width, h = size.height;
    canvas.drawRect(Rect.fromLTRB(0, _groundY * h, w, h), _fill(AppColors.panel));
    // One sleeper, seen end-on across the gauge.
    canvas.drawRect(
      Rect.fromLTRB(cx - 0.26 * w, _sleeperY * h, cx + 0.26 * w, _groundY * h),
      _fill(AppColors.panelRaised),
    );
    // The two rails at the gauge.
    for (final side in [-1.0, 1.0]) {
      final x = cx + side * 0.155 * w;
      canvas.drawRect(
        Rect.fromCenter(center: Offset(x, _railY * h), width: 0.022 * w, height: 0.045 * h),
        _fill(AppColors.hairlineBright),
      );
    }
  }

  void _paintWagonSection(Canvas canvas, Size size, double cx) {
    final w = size.width, h = size.height;

    // Deck slab with the solebars at each edge.
    final deck = Rect.fromLTRB(
      cx - _wagonHalf * w,
      _deckY * h,
      cx + _wagonHalf * w,
      _wagonBottomY * h,
    );
    canvas.drawRect(deck, _fill(AppColors.panelRaised));
    canvas.drawRect(deck, _stroke(AppColors.labelDim, 1.2));
    canvas.drawLine(
      Offset(deck.left, deck.top),
      Offset(deck.right, deck.top),
      _stroke(AppColors.label, 1.6),
    );

    // Side stakes folded down, as an open wagon carries them.
    for (final side in [-1.0, 1.0]) {
      final x = cx + side * _wagonHalf * w;
      canvas.drawRect(
        Rect.fromLTWH(side < 0 ? x : x - 0.012 * w, (_deckY - 0.045) * h, 0.012 * w, 0.045 * h),
        _fill(AppColors.hairlineBright),
      );
    }

    // Wheelset under the deck.
    for (final side in [-1.0, 1.0]) {
      final x = cx + side * 0.155 * w;
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(x, (_wagonBottomY + _railY) / 2 * h),
          width: 0.03 * w,
          height: (_railY - _wagonBottomY) * h,
        ),
        _fill(AppColors.ground),
      );
    }
    canvas.drawRect(
      Rect.fromLTRB(cx - 0.155 * w, (_wagonBottomY + 0.03) * h, cx + 0.155 * w,
          (_wagonBottomY + 0.05) * h),
      _fill(AppColors.panel),
    );
  }

  void _paintVehicleSection(Canvas canvas, Size size, double cx) {
    final w = size.width, h = size.height;

    // The two runs — tracks or tyres — standing on the deck.
    for (final side in [-1.0, 1.0]) {
      final outer = cx + side * _runOuterHalf * w;
      final inner = cx + side * _runInnerHalf * w;
      final rect = Rect.fromLTRB(
        side < 0 ? outer : inner,
        _runTopY * h,
        side < 0 ? inner : outer,
        _runBottomY * h,
      );
      if (category == VehicleCategory.tracked) {
        canvas.drawRect(rect, _fill(AppColors.panel));
        canvas.drawRect(rect, _stroke(AppColors.textSecondary, 1.6));
        // Track links across the face.
        for (var y = rect.top + 0.02 * h; y < rect.bottom; y += 0.03 * h) {
          canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y),
              _stroke(AppColors.textSecondary, 1));
        }
      } else {
        final centre = Offset(rect.center.dx, rect.center.dy);
        canvas.drawOval(rect, _fill(AppColors.ground));
        canvas.drawOval(rect, _stroke(AppColors.textSecondary, 1.6));
        canvas.drawCircle(centre, rect.width * 0.22, _fill(AppColors.panelRaised));
      }
    }

    // Hull or cargo body spanning the runs.
    final body = Rect.fromLTRB(
      cx - _bodyHalf * w,
      _bodyTopY * h,
      cx + _bodyHalf * w,
      _runTopY * h + 0.02 * h,
    );
    canvas.drawRect(body, _fill(AppColors.vehicleBody));
    canvas.drawRect(body, _stroke(AppColors.vehicleEdge, 1.4));
    if (category == VehicleCategory.tracked) {
      // Turret, centred.
      final turret = Rect.fromCenter(
        center: Offset(cx, (_bodyTopY - 0.055) * h),
        width: 0.20 * w,
        height: 0.11 * h,
      );
      canvas.drawRect(turret, _fill(AppColors.vehicleAccent));
      canvas.drawRect(turret, _stroke(AppColors.labelDim, 1.2));
    }
  }

  /// A chock outboard of each run, which is the only place this view can show
  /// them and the only view that can show the gap.
  void _paintChocks(Canvas canvas, Size size, double cx) {
    final w = size.width, h = size.height;
    for (final side in [-1.0, 1.0]) {
      final outer = cx + side * _runOuterHalf * w;
      final x = outer + side * 0.035 * w;
      final halfBase = 0.022 * w;
      final wedge = Path()
        ..moveTo(x - halfBase, _deckY * h)
        ..lineTo(x + halfBase, _deckY * h)
        ..lineTo(x - side * halfBase * 0.2, (_deckY - 0.05) * h)
        ..close();
      canvas.drawPath(wedge, _fill(AppColors.label.withValues(alpha: 0.9)));
      canvas.drawPath(wedge, _stroke(AppColors.labelDim, 1.2));
    }
  }

  /// The lettered dimensions: the lateral gap, and the overhang limit past the
  /// wagon's edge. Anything the data does not carry is simply not drawn.
  void _paintCallouts(Canvas canvas, Size size, double cx) {
    final w = size.width, h = size.height;
    final gap = spec.lateralGap;
    if (gap != null) {
      final outer = cx + _runOuterHalf * w;
      final chock = outer + 0.035 * w - 0.022 * w;
      final y = (_deckY + 0.055) * h;
      canvas.drawLine(Offset(outer, y), Offset(chock, y), _stroke(AppColors.offNominal, 1.2));
      for (final x in [outer, chock]) {
        canvas.drawLine(Offset(x, y - 0.015 * h), Offset(x, y + 0.015 * h),
            _stroke(AppColors.offNominal, 1.2));
      }
      _text(
        canvas,
        AppStrings.endViewGapCallout(gap.minMm, gap.maxMm),
        Offset(chock + 0.005 * w, y + 0.02 * h),
        size: 9,
        color: AppColors.offNominal,
      );
    }

    final seating = spec.seating;
    if (seating != null) {
      _text(
        canvas,
        AppStrings.endViewSeatingCallout(seating.minCm, seating.maxCm),
        Offset(0.02 * w, (_deckY + 0.10) * h),
        size: 9,
        color: AppColors.offNominal,
      );
    }

    final overhang = spec.maxOverhangMm;
    if (overhang != null) {
      // The wagon edge, and the limit the load may not pass beyond it.
      final edge = cx + _wagonHalf * w;
      canvas.drawLine(
        Offset(edge, (_bodyTopY - 0.02) * h),
        Offset(edge, (_deckY - 0.01) * h),
        _stroke(AppColors.hairline, 1),
      );
      // Keep the label inside the panel: at the widths this view is drawn at
      // it would otherwise run off the right edge and lose its own number.
      _text(
        canvas,
        AppStrings.endViewOverhangCallout(overhang),
        Offset(edge + 0.008 * w, (_bodyTopY + 0.02) * h),
        size: 9,
        color: AppColors.textSecondary,
        maxWidth: w - edge - 0.012 * w,
        fallbackLeft: edge - 0.008 * w,
      );
    }
  }

  /// Letters a callout onto the drawing.
  ///
  /// [maxWidth] and [fallbackLeft] exist for the labels that sit beside a
  /// dimension line near the frame: when the room to the right of the anchor
  /// is too narrow for the text, it is drawn to the left of [fallbackLeft]
  /// instead of being clipped in half.
  void _text(
    Canvas canvas,
    String text,
    Offset at, {
    bool centered = false,
    bool bold = false,
    double size = 10,
    Color color = AppColors.textSecondary,
    double? maxWidth,
    double? fallbackLeft,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: size,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth != null && maxWidth > 40 ? maxWidth : 220);

    var dx = centered ? at.dx - painter.width / 2 : at.dx;
    if (fallbackLeft != null && maxWidth != null && maxWidth < painter.width) {
      dx = fallbackLeft - painter.width;
    }
    painter.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant EndElevationPainter old) =>
      old.category != category ||
      old.designation != designation ||
      old.spec.lateralGap != spec.lateralGap ||
      old.spec.seating != spec.seating ||
      old.spec.maxOverhangMm != spec.maxOverhangMm;
}
