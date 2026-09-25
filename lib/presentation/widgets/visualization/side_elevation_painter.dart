import 'dart:math' as math;

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/models/schematic_element.dart';

/// Draws the securing arrangement the way the handbook plates draw it: the
/// vehicle standing on the flatcar deck, seen from the side, over rails.
///
/// **What this painter takes from the domain, and what it invents.** Every
/// *horizontal* position comes from the [SchematicDiagram] — where the deck
/// starts and ends, where the vehicle sits after the user has dragged it,
/// and the x of each chock, spur and lashing that `SchematicBuilder`
/// resolved. Those are the positions the handbook's rules produced and this
/// painter never recomputes one.
///
/// Every *vertical* position is a drawing convention chosen here: the deck
/// line, the height of a hull, where a turret sits. That is not a loss of
/// fidelity, because the plan-view diagram it is drawn from has no heights
/// at all — and it could not borrow real ones anyway, since no vehicle or
/// platform in the handbook extract carries a measured length, width or
/// height (every such field is an explicit TODO). The elevation is therefore
/// a *proportioned drawing, not a scale drawing*, and the caller must keep
/// showing the "not to scale" banner over it exactly as the plan view does.
///
/// The vehicle profile is generic to its category rather than specific to a
/// designation: the extract gives no hull, turret or road-wheel geometry for
/// any vehicle, so drawing a recognisable T-34 silhouette would mean
/// inventing measurements the source does not contain. What it does show
/// truthfully is the arrangement — which end the chocks go under, how the
/// lashings run down to the deck, where the vehicle sits along the wagon.
class SideElevationPainter extends CustomPainter {
  final SchematicDiagram diagram;

  /// Whether each piece of securing hardware gets its handbook name printed
  /// under the deck with a leader line. On the tall securing view there is
  /// room and the names are the point of the drawing; on the short strip at
  /// the top of the placement screen they would overlap each other.
  final bool showLabels;

  /// Whether the drawing carries its dimensions: extension lines dropped from
  /// each extent, a dimension line between them, arrowheads, and the called
  /// value in the middle.
  ///
  /// Only *horizontal* extents are ever dimensioned, and that is the whole
  /// rule. Every horizontal position in this drawing comes from the diagram,
  /// so a dimension across one is a measurement of something real; every
  /// vertical position is a drawing convention chosen in this file, so a
  /// height dimension would be a measurement of a decision. The values
  /// themselves come from the caller through [deckLength] and [lengthOf], and
  /// where the caller has none the dimension is lettered with the handbook's
  /// own "not stated" — never with a number this painter worked out.
  final bool showDimensions;

  /// The wagon deck's called length, already formatted with its unit.
  final String? deckLength;

  /// One placement's called length, already formatted with its unit.
  final String? Function(String placementId)? lengthOf;

  SideElevationPainter(
    this.diagram, {
    this.showLabels = true,
    this.showDimensions = false,
    this.deckLength,
    this.lengthOf,
  });

  // ---- Vertical layout of the drawing, as fractions of the canvas height.
  // Chosen for legibility, never measured; see the class doc.
  static const _railHeadY = 0.855;
  static const _sleeperTopY = 0.870;
  static const _groundY = 0.935;
  static const _wheelCentreY = 0.780;
  static const _wheelRadius = 0.075;
  static const _solebarBottomY = 0.665;
  static const _deckTopY = 0.560;
  static const _trackBottomY = _deckTopY;
  static const _trackTopY = 0.435;
  static const _hullTopY = 0.355;
  static const _turretTopY = 0.225;

  @override
  void paint(Canvas canvas, Size size) {
    final deckElement = diagram
        .elementsOfKind(SchematicElementKind.platformDeck)
        .firstOrNull;
    if (deckElement == null) return;

    _paintTrackBed(canvas, size);
    final deck = _xRangeOf(deckElement)!;
    _paintFlatcar(canvas, size, deck);

    // One wagon can carry several vehicles, each with its own hardware; the
    // elements carry the placement they belong to, so nothing here has to
    // guess which chock goes with which machine.
    for (final bodyElement in diagram.elementsOfKind(SchematicElementKind.vehicleBody)) {
      final body = _xRangeOf(bodyElement);
      if (body == null) continue;
      final category = _categoryOf(bodyElement.placementId);
      _paintVehicle(canvas, size, body, category, bodyElement.placementId);
      _paintHardware(canvas, size, body, bodyElement.placementId);
      _paintDesignation(canvas, size, body, bodyElement.label);
    }

    // The measurement, drawn over the drawing. Last, so nothing is drawn on
    // top of the thing that says how big it all is.
    if (showDimensions) {
      for (final bodyElement
          in diagram.elementsOfKind(SchematicElementKind.vehicleBody)) {
        final body = _xRangeOf(bodyElement);
        if (body == null) continue;
        final id = bodyElement.placementId;
        _paintDimension(
          canvas,
          size,
          left: body.left,
          right: body.right,
          y: _dimensionVehicleY,
          label: (id == null ? null : lengthOf?.call(id)) ??
              AppStrings.notAvailableShort,
          known: id != null && lengthOf?.call(id) != null,
          extendFrom: _deckTopY,
        );
      }
      _paintDimension(
        canvas,
        size,
        left: deck.left,
        right: deck.right,
        y: _dimensionDeckY,
        label: deckLength ?? AppStrings.notAvailableShort,
        known: deckLength != null,
        extendFrom: _solebarBottomY,
      );
    }
  }

  // ---- Dimensions ------------------------------------------------------

  /// Where the two dimension lines hang, as fractions of the canvas height.
  static const _dimensionVehicleY = 0.985;
  static const _dimensionDeckY = 0.910;

  /// One called dimension: two extension lines, the line between them, an
  /// arrowhead at each end, and the value lettered on the line.
  ///
  /// A value the source does not state is lettered in the amber the whole
  /// interface uses for "the handbook does not confirm this", so a dimension
  /// nobody can check looks different from one anybody can.
  void _paintDimension(
    Canvas canvas,
    Size size, {
    required double left,
    required double right,
    required double y,
    required String label,
    required bool known,
    required double extendFrom,
  }) {
    final w = size.width;
    final h = size.height;
    final x1 = left * w;
    final x2 = right * w;
    if ((x2 - x1).abs() < 24) return;
    final lineY = y * h;

    final ink = known ? AppColors.label : AppColors.offNominal;
    final thin = _stroke(ink.withValues(alpha: 0.75), 1);

    // Extension lines, standing off the feature they measure the way a plate
    // draws them rather than touching it.
    for (final x in [x1, x2]) {
      canvas.drawLine(Offset(x, extendFrom * h + 3), Offset(x, lineY + 4), thin);
    }
    canvas.drawLine(Offset(x1, lineY), Offset(x2, lineY), thin);

    // Arrowheads, pointing outward at each end.
    for (final (x, dir) in [(x1, 1.0), (x2, -1.0)]) {
      canvas.drawPath(
        Path()
          ..moveTo(x, lineY)
          ..lineTo(x + dir * 7, lineY - 2.6)
          ..lineTo(x + dir * 7, lineY + 2.6)
          ..close(),
        _fill(ink.withValues(alpha: 0.75)),
      );
    }

    final painter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontFamily: AppText.mono,
          fontSize: 9,
          letterSpacing: 0.8,
          color: ink,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final centre = (x1 + x2) / 2;
    // The value sits on the line, with the line cleared behind it.
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centre, lineY),
        width: painter.width + 8,
        height: painter.height,
      ),
      _fill(AppColors.ground),
    );
    painter.paint(canvas, Offset(centre - painter.width / 2, lineY - painter.height / 2));
  }

  /// The horizontal extent of one element, as (left, right) fractions.
  ({double left, double right})? _xRangeOf(SchematicElement element) {
    if (element.points.isEmpty) return null;
    var left = element.points.first.dx;
    var right = left;
    for (final p in element.points) {
      left = math.min(left, p.dx);
      right = math.max(right, p.dx);
    }
    return (left: left, right: right);
  }

  /// Whether a placement runs on tracks or wheels, read off the run-indicator
  /// elements the builder already emitted for it. Taking it from the diagram
  /// rather than from a second parameter keeps the two impossible to
  /// disagree: a vehicle drawn with tracks here is one the domain called
  /// tracked.
  VehicleCategory _categoryOf(String? placementId) {
    for (final element in diagram.elements) {
      if (element.placementId != placementId) continue;
      if (element.kind == SchematicElementKind.wheelRun) return VehicleCategory.wheeled;
      if (element.kind == SchematicElementKind.trackRun) return VehicleCategory.tracked;
    }
    return VehicleCategory.tracked;
  }

  Paint _fill(Color color) => Paint()..color = color;

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width;

  // ---- Track bed -------------------------------------------------------

  void _paintTrackBed(Canvas canvas, Size size) {
    final w = size.width, h = size.height;

    // Ballast shoulder.
    canvas.drawRect(
      Rect.fromLTRB(0, _groundY * h, w, h),
      _fill(AppColors.panel),
    );

    // Sleepers, drawn as evenly spaced ends seen from the side.
    final sleeper = _fill(AppColors.panelRaised);
    for (var x = 0.01; x < 1.0; x += 0.028) {
      canvas.drawRect(
        Rect.fromLTWH(x * w, _sleeperTopY * h, 0.016 * w, (_groundY - _sleeperTopY) * h),
        sleeper,
      );
    }

    // Rail: head plus the thin web line under it.
    canvas.drawRect(
      Rect.fromLTWH(0, _railHeadY * h, w, 0.012 * h),
      _fill(AppColors.hairlineBright),
    );
    canvas.drawLine(
      Offset(0, (_railHeadY + 0.012) * h),
      Offset(w, (_railHeadY + 0.012) * h),
      _stroke(AppColors.hairline, 1),
    );
  }

  // ---- Flatcar ---------------------------------------------------------

  void _paintFlatcar(Canvas canvas, Size size, ({double left, double right}) deck) {
    final w = size.width, h = size.height;
    final left = deck.left * w, right = deck.right * w;

    // Bogies first, so the solebar overlaps their frames the way a real
    // wagon's does.
    final bogieCentres = [left + (right - left) * 0.14, right - (right - left) * 0.14];
    for (final cx in bogieCentres) {
      _paintBogie(canvas, size, cx);
    }

    // Solebar / side frame of the wagon.
    final frame = Rect.fromLTRB(left, _deckTopY * h, right, _solebarBottomY * h);
    canvas.drawRect(frame, _fill(AppColors.panelRaised));
    canvas.drawRect(frame, _stroke(AppColors.labelDim, 1.2));

    // Deck plank line — the surface the vehicle actually stands on.
    canvas.drawLine(
      Offset(left, _deckTopY * h),
      Offset(right, _deckTopY * h),
      _stroke(AppColors.label, 1.6),
    );

    // Stake pockets along the solebar.
    final pocket = _fill(AppColors.hairlineBright);
    final pocketTop = (_deckTopY + 0.012) * h;
    final pocketHeight = (_solebarBottomY - _deckTopY - 0.024) * h;
    for (var i = 1; i < 8; i++) {
      final x = left + (right - left) * i / 8;
      canvas.drawRect(
        Rect.fromLTWH(x - 0.004 * w, pocketTop, 0.008 * w, pocketHeight),
        pocket,
      );
    }

    // End beams with their buffers, one at each end.
    for (final end in [left, right]) {
      final outward = end == left ? -1.0 : 1.0;
      canvas.drawRect(
        Rect.fromLTWH(
          end + (outward < 0 ? -0.018 * w : 0),
          (_deckTopY + 0.018) * h,
          0.018 * w,
          (_solebarBottomY - _deckTopY - 0.036) * h,
        ),
        _fill(AppColors.hairlineBright),
      );
    }
  }

  void _paintBogie(Canvas canvas, Size size, double centreX) {
    final w = size.width, h = size.height;
    // Bolster: the short pillar carrying the wagon's weight onto the bogie.
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(centreX, (_solebarBottomY + 0.03) * h),
        width: 0.022 * w,
        height: 0.06 * h,
      ),
      _fill(AppColors.panelRaised),
    );
    final frame = Rect.fromCenter(
      center: Offset(centreX, (_wheelCentreY - 0.03) * h),
      width: 0.085 * w,
      height: 0.070 * h,
    );
    canvas.drawRect(frame, _fill(AppColors.panelRaised));
    canvas.drawRect(frame, _stroke(AppColors.textSecondary, 1.2));

    for (final dx in [-0.028, 0.028]) {
      final centre = Offset(centreX + dx * w, _wheelCentreY * h);
      canvas.drawCircle(centre, _wheelRadius * h, _fill(AppColors.ground));
      canvas.drawCircle(centre, _wheelRadius * h, _stroke(AppColors.hairlineBright, 1.4));
      canvas.drawCircle(centre, _wheelRadius * h * 0.35, _fill(AppColors.panelRaised));
    }
  }

  // ---- Vehicle ---------------------------------------------------------

  void _paintVehicle(
    Canvas canvas,
    Size size,
    ({double left, double right}) body,
    VehicleCategory category,
    String? placementId,
  ) {
    final w = size.width, h = size.height;
    final left = body.left * w, right = body.right * w;
    final length = right - left;

    if (category != VehicleCategory.tracked) {
      // A lorry is a cab and a cargo body on wheels, not a hull with a
      // turret; drawing it with the tracked profile made the ZIL-131 look
      // like a tank with its gun removed.
      _paintWheeledVehicle(canvas, size, body, placementId);
      return;
    }
    _paintRunningGear(canvas, size, left, right);

    // Hull: a flat deck with a sloped glacis at the front (drawn to the
    // right, the direction the rail-direction arrow points).
    // Hull: a flat deck, a short sloped glacis at the front (to the right,
    // the way the rail-direction arrow points) and a squared-off rear.
    final hull = Path()
      ..moveTo(left, _trackTopY * h)
      ..lineTo(left, (_hullTopY + 0.03) * h)
      ..lineTo(left + length * 0.04, _hullTopY * h)
      ..lineTo(right - length * 0.16, _hullTopY * h)
      ..lineTo(right, (_hullTopY + 0.075) * h)
      ..lineTo(right, _trackTopY * h)
      ..close();
    canvas.drawPath(hull, _fill(AppColors.vehicleBody));
    canvas.drawPath(hull, _stroke(AppColors.vehicleEdge, 1.4));

    // Fender line over the running gear.
    canvas.drawLine(
      Offset(left, _trackTopY * h),
      Offset(right, _trackTopY * h),
      _stroke(AppColors.vehicleEdge, 1.2),
    );

    if (category != VehicleCategory.tracked) return;

    // Turret and gun, set back from the front the way a tank's is.
    final turretLeft = left + length * 0.30;
    final turretRight = left + length * 0.62;
    final turret = Path()
      ..moveTo(turretLeft, _hullTopY * h)
      ..lineTo(turretLeft + length * 0.07, _turretTopY * h)
      ..lineTo(turretRight - length * 0.05, _turretTopY * h)
      ..lineTo(turretRight, _hullTopY * h)
      ..close();
    canvas.drawPath(turret, _fill(AppColors.vehicleAccent));
    canvas.drawPath(turret, _stroke(AppColors.labelDim, 1.2));

    // Mantlet, so the barrel leaves the turret at a joint instead of
    // sprouting from thin air.
    final mantletY = (_turretTopY + _hullTopY) / 2 * h;
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(turretRight, mantletY),
        width: length * 0.05,
        height: (_hullTopY - _turretTopY) * h * 0.55,
      ),
      _fill(AppColors.vehicleBody),
    );

    final muzzleX = right + length * 0.10;
    canvas.drawLine(
      Offset(turretRight, mantletY),
      Offset(muzzleX, mantletY),
      _stroke(AppColors.vehicleAccent, 5),
    );
    canvas.drawLine(
      Offset(muzzleX - length * 0.025, mantletY),
      Offset(muzzleX, mantletY),
      _stroke(AppColors.labelDim, 7),
    );
  }

  /// A cargo lorry in profile: cab, bonnet, cargo body over the rear axles,
  /// and a wheel at each position the diagram's own run indicators give — so
  /// a three-axle vehicle is drawn on three axles rather than on a fixed
  /// number invented here.
  void _paintWheeledVehicle(
    Canvas canvas,
    Size size,
    ({double left, double right}) body,
    String? placementId,
  ) {
    final w = size.width, h = size.height;
    final left = body.left * w, right = body.right * w;
    final length = right - left;
    final chassisY = (_trackBottomY - 0.055) * h;

    // Chassis rail.
    canvas.drawRect(
      Rect.fromLTRB(left, chassisY - 0.02 * h, right, chassisY),
      _fill(AppColors.panel),
    );

    // Cargo body over the rear two thirds.
    final bodyRect = Rect.fromLTRB(
      left + length * 0.34,
      _hullTopY * h,
      right,
      chassisY - 0.02 * h,
    );
    canvas.drawRect(bodyRect, _fill(AppColors.vehicleBody));
    canvas.drawRect(bodyRect, _stroke(AppColors.vehicleEdge, 1.4));
    // Tilt ribs, so a covered load reads as a covered load.
    for (var i = 1; i < 5; i++) {
      final x = bodyRect.left + bodyRect.width * i / 5;
      canvas.drawLine(
        Offset(x, bodyRect.top + 0.01 * h),
        Offset(x, bodyRect.bottom - 0.01 * h),
        _stroke(AppColors.vehicleEdge, 1),
      );
    }

    // Cab and bonnet at the front (drawn to the right, with the rail
    // direction).
    final cab = Path()
      ..moveTo(left, chassisY - 0.02 * h)
      ..lineTo(left, (_hullTopY + 0.05) * h)
      ..lineTo(left + length * 0.10, (_hullTopY + 0.02) * h)
      ..lineTo(left + length * 0.30, (_hullTopY + 0.02) * h)
      ..lineTo(left + length * 0.30, chassisY - 0.02 * h)
      ..close();
    canvas.drawPath(cab, _fill(AppColors.vehicleAccent));
    canvas.drawPath(cab, _stroke(AppColors.labelDim, 1.2));
    // Windscreen.
    canvas.drawRect(
      Rect.fromLTRB(
        left + length * 0.13,
        (_hullTopY + 0.035) * h,
        left + length * 0.27,
        (_hullTopY + 0.085) * h,
      ),
      _fill(AppColors.panel),
    );

    for (final x in _wheelXsFor(placementId)) {
      final centre = Offset(x * w, (_trackBottomY - 0.045) * h);
      final radius = 0.045 * h;
      canvas.drawCircle(centre, radius, _fill(AppColors.ground));
      canvas.drawCircle(centre, radius, _stroke(AppColors.textSecondary, 1.6));
      canvas.drawCircle(centre, radius * 0.35, _fill(AppColors.panelRaised));
    }
  }

  /// The x of each tyre, read off the diagram's wheel-run elements. Falls back
  /// to nothing rather than inventing an axle count.
  List<double> _wheelXsFor(String? placementId) {
    final xs = <double>[];
    for (final element in diagram.elements) {
      if (element.placementId != placementId) continue;
      if (element.kind != SchematicElementKind.wheelRun) continue;
      for (final point in element.points) {
        if (!xs.any((x) => (x - point.dx).abs() < 0.005)) xs.add(point.dx);
      }
    }
    xs.sort();
    return xs;
  }

  /// Track band with a drive sprocket, an idler and the road wheels between
  /// them. The wheel count is a drawing convention — the handbook extract
  /// records no running-gear geometry for any vehicle.
  void _paintRunningGear(Canvas canvas, Size size, double left, double right) {
    final w = size.width, h = size.height;
    final band = RRect.fromRectAndRadius(
      Rect.fromLTRB(left, _trackTopY * h, right, _trackBottomY * h),
      Radius.circular((_trackBottomY - _trackTopY) * h * 0.5),
    );
    canvas.drawRRect(band, _fill(AppColors.panel));
    canvas.drawRRect(band, _stroke(AppColors.textSecondary, 1.8));

    final bandHeight = (_trackBottomY - _trackTopY) * h;
    final radius = bandHeight * 0.30;
    // Road wheels ride on the bottom run, not on the band's centre line —
    // that is what makes a track read as a track rather than as a bar.
    final roadY = _trackBottomY * h - radius - bandHeight * 0.06;
    final hubY = (_trackTopY + _trackBottomY) / 2 * h;

    // Drive sprocket and idler, larger and set at the very ends.
    for (final x in [left + radius * 1.4, right - radius * 1.4]) {
      canvas.drawCircle(Offset(x, hubY), radius * 1.35, _fill(AppColors.panelRaised));
      canvas.drawCircle(Offset(x, hubY), radius * 1.35, _stroke(AppColors.textSecondary, 1.2));
      canvas.drawCircle(Offset(x, hubY), radius * 0.35, _fill(AppColors.panel));
    }

    const roadWheels = 5;
    final firstX = left + (right - left) * 0.22;
    final lastX = right - (right - left) * 0.22;
    for (var i = 0; i < roadWheels; i++) {
      final x = firstX + (lastX - firstX) * i / (roadWheels - 1);
      canvas.drawCircle(Offset(x, roadY), radius, _fill(AppColors.panelRaised));
      canvas.drawCircle(Offset(x, roadY), radius, _stroke(AppColors.textSecondary, 1));
      canvas.drawCircle(Offset(x, roadY), radius * 0.3, _fill(AppColors.panel));
    }

    // Return rollers carrying the upper run.
    for (var i = 0; i < 3; i++) {
      final x = firstX + (lastX - firstX) * (i + 0.5) / 3;
      canvas.drawCircle(
        Offset(x, (_trackTopY + 0.012) * h),
        radius * 0.32,
        _fill(AppColors.panelRaised),
      );
    }
    // Track pins along the bottom run, so the band reads as a track and not
    // as a bar.
    final pin = _stroke(AppColors.textSecondary, 1);
    for (var x = left + 0.004 * w; x < right; x += 0.012 * w) {
      canvas.drawLine(
        Offset(x, _trackBottomY * h),
        Offset(x, (_trackBottomY - 0.012) * h),
        pin,
      );
    }
  }

  // ---- Securing hardware ----------------------------------------------

  /// Each hardware element is drawn at the x the domain gave it, in the shape
  /// the handbook's own figure shows it in — a squared wood stop-block is not
  /// the same object as a KGUUB chock or an iron stop-boot, and drawing all
  /// three as the same triangle taught the trainee that they were
  /// interchangeable. The [SchematicElement.label] each already carries (with
  /// its selected type code and, for the stop-block, its Table 3 dimensions)
  /// is printed beneath the deck when [showLabels] is on.
  void _paintHardware(
    Canvas canvas,
    Size size,
    ({double left, double right}) body,
    String? placementId,
  ) {
    final labelled = <String>{};
    final labels = <({double x, String text, bool mismatch})>[];
    for (final element in diagram.elements) {
      if (element.placementId != placementId) continue;
      final xs = _distinctXs(element);
      if (xs.isEmpty) continue;

      switch (element.kind) {
        case SchematicElementKind.woodChockPair:
          for (final x in xs) {
            _paintWoodChock(canvas, size, x, element.isSelectionMismatch);
          }
          break;
        case SchematicElementKind.spacerBoard:
          for (final x in xs) {
            _paintSpacerBoard(canvas, size, x, element.isSelectionMismatch);
          }
          break;
        case SchematicElementKind.reusableChockPair:
          for (final x in xs) {
            _paintReusableChock(canvas, size, x, element.isSelectionMismatch);
          }
          break;
        case SchematicElementKind.ironSpurPair:
          for (final x in xs) {
            _paintIronSpur(canvas, size, x, element.isSelectionMismatch);
          }
          break;
        case SchematicElementKind.ironChockBootPair:
          for (final x in xs) {
            _paintIronChockBoot(canvas, size, x, element.isSelectionMismatch);
          }
          break;
        case SchematicElementKind.wireLashing:
          _paintLashing(canvas, size, element, body);
          break;
        default:
          continue;
      }

      // One label per kind, at its leftmost item: a pair is the same object
      // twice and naming it twice only crowds the drawing.
      final short = _shortLabelFor(element.kind);
      if (showLabels && short != null && labelled.add(element.kind.name)) {
        labels.add((x: xs.reduce(math.min), text: short, mismatch: element.isSelectionMismatch));
      }
    }
    _paintHardwareLabels(canvas, size, labels);
  }

  /// The short handbook name a piece of hardware is labelled with on the
  /// drawing. The element's own [SchematicElement.label] carries the full
  /// name plus the selected type code and, for a stop-block, its Table 3
  /// dimensions — far too long to letter onto a wagon at this size, and
  /// already available by tapping the item in the plan view.
  static String? _shortLabelFor(SchematicElementKind kind) {
    switch (kind) {
      case SchematicElementKind.woodChockPair:
        return AppStrings.hardwareShortWoodChock;
      case SchematicElementKind.spacerBoard:
        return AppStrings.hardwareShortSpacerBoard;
      case SchematicElementKind.reusableChockPair:
        return AppStrings.hardwareShortReusableChock;
      case SchematicElementKind.ironSpurPair:
        return AppStrings.hardwareShortIronSpur;
      case SchematicElementKind.ironChockBootPair:
        return AppStrings.hardwareShortIronChockBoot;
      case SchematicElementKind.wireLashing:
        return AppStrings.hardwareShortWireLashing;
      default:
        return null;
    }
  }

  /// The x positions of a hardware element, with the pair's two sides
  /// collapsed: in a side view the far-side chock stands exactly behind the
  /// near-side one, so drawing both would only thicken the same wedge.
  List<double> _distinctXs(SchematicElement element) {
    final xs = <double>[];
    for (final p in element.points) {
      if (!xs.any((x) => (x - p.dx).abs() < 0.01)) xs.add(p.dx);
    }
    return xs;
  }

  Color _woodColor(bool mismatch) => mismatch ? AppColors.outOfTolerance : AppColors.label;
  Color _metalColor(bool mismatch) => mismatch ? AppColors.outOfTolerance : AppColors.hairlineBright;

  /// The squared wood stop-block (direg dörtgyraň agaç bölegi): a beam with a
  /// sloped face against the track, its grain drawn along its length and the
  /// nails that hold it to the wagon floor shown on top — para. 21's fixing.
  void _paintWoodChock(Canvas canvas, Size size, double xFraction, bool mismatch) {
    final w = size.width, h = size.height;
    final x = xFraction * w;
    // Deliberately low: a stop-block is a fraction of a tyre's height (150 mm
    // against roughly a metre), and drawing it as tall as the wheel hid the
    // running gear it is supposed to be seated against. Still exaggerated
    // over true proportion, as the plates themselves draw it, or it would be
    // a line.
    final halfBase = 0.016 * w;
    final top = (_deckTopY - 0.038) * h;
    final beam = Path()
      ..moveTo(x - halfBase, _deckTopY * h)
      ..lineTo(x + halfBase, _deckTopY * h)
      ..lineTo(x + halfBase, top + 0.02 * h)
      ..lineTo(x + halfBase * 0.15, top)
      ..lineTo(x - halfBase, top)
      ..close();
    canvas.drawPath(beam, _fill(_woodColor(mismatch)));
    canvas.drawPath(beam, _stroke(AppColors.labelDim, 1.2));

    // Grain, and the two nails into the wagon floor.
    final grain = _stroke(AppColors.labelDim.withValues(alpha: 0.7), 1);
    for (var i = 1; i < 3; i++) {
      final y = _deckTopY * h - (_deckTopY * h - top) * i / 3.0;
      canvas.drawLine(Offset(x - halfBase * 0.85, y), Offset(x + halfBase * 0.7, y), grain);
    }
    final nail = _stroke(AppColors.hairlineBright, 1.6);
    for (final dx in [-halfBase * 0.5, halfBase * 0.4]) {
      canvas.drawLine(
        Offset(x + dx, top + 0.004 * h),
        Offset(x + dx, _deckTopY * h),
        nail,
      );
    }
  }

  /// The half-round packing block (ara goýulýan ýarym tegelek agaç bölegi)
  /// that fills the gap between the stop-block and the track: a dome, the way
  /// figure 15.8 draws it, never another wedge.
  void _paintSpacerBoard(Canvas canvas, Size size, double xFraction, bool mismatch) {
    final w = size.width, h = size.height;
    final x = xFraction * w;
    final halfBase = 0.017 * w;
    final rect = Rect.fromLTRB(
      x - halfBase,
      (_deckTopY - 0.05) * h,
      x + halfBase,
      _deckTopY * h,
    );
    canvas.drawArc(
      Rect.fromLTRB(rect.left, rect.top, rect.right, rect.bottom + rect.height),
      math.pi,
      math.pi,
      true,
      _fill(_woodColor(mismatch).withValues(alpha: 0.9)),
    );
    canvas.drawLine(
      Offset(rect.left, _deckTopY * h),
      Offset(rect.right, _deckTopY * h),
      _stroke(AppColors.labelDim, 1.2),
    );
  }

  /// The reusable universal chock (KGUUB): a base plate on the deck, a comb
  /// rising against the track, and the pins that lock it — figure 15.11's
  /// three labelled parts.
  void _paintReusableChock(Canvas canvas, Size size, double xFraction, bool mismatch) {
    final w = size.width, h = size.height;
    final x = xFraction * w;
    final half = 0.019 * w;
    final base = Rect.fromLTRB(x - half, (_deckTopY - 0.022) * h, x + half, _deckTopY * h);
    canvas.drawRect(base, _fill(_metalColor(mismatch)));
    canvas.drawRect(base, _stroke(AppColors.textSecondary, 1.2));

    // Comb: stepped, rising towards the track.
    final comb = Path()
      ..moveTo(x - half * 0.6, base.top)
      ..lineTo(x - half * 0.6, (_deckTopY - 0.075) * h)
      ..lineTo(x + half * 0.1, (_deckTopY - 0.075) * h)
      ..lineTo(x + half * 0.1, (_deckTopY - 0.045) * h)
      ..lineTo(x + half * 0.8, (_deckTopY - 0.045) * h)
      ..lineTo(x + half * 0.8, base.top)
      ..close();
    canvas.drawPath(comb, _fill(_metalColor(mismatch)));
    canvas.drawPath(comb, _stroke(AppColors.textSecondary, 1.2));

    // Locking pins through the base plate.
    for (final dx in [-half * 0.75, half * 0.75]) {
      canvas.drawCircle(Offset(x + dx, base.center.dy), 0.004 * w, _fill(AppColors.ground));
    }
  }

  /// The iron spur (demir şpor): a toothed triangular stop driven against the
  /// track, its teeth biting the wagon floor.
  void _paintIronSpur(Canvas canvas, Size size, double xFraction, bool mismatch) {
    final w = size.width, h = size.height;
    final x = xFraction * w;
    final half = 0.017 * w;
    final spur = Path()
      ..moveTo(x - half, _deckTopY * h)
      ..lineTo(x + half, _deckTopY * h)
      ..lineTo(x + half * 0.1, (_deckTopY - 0.07) * h)
      ..close();
    canvas.drawPath(spur, _fill(_metalColor(mismatch)));
    canvas.drawPath(spur, _stroke(AppColors.textSecondary, 1.3));
    final tooth = _stroke(AppColors.textSecondary, 1.4);
    for (var i = 0; i < 3; i++) {
      final tx = x - half + (2 * half) * (i + 0.5) / 3;
      canvas.drawLine(
        Offset(tx, _deckTopY * h),
        Offset(tx, (_deckTopY + 0.018) * h),
        tooth,
      );
    }
  }

  /// The iron stop-boot (demir direg başmak): a shoe that wraps the track, a
  /// flat sole on the deck and an upturned toe in front of it.
  void _paintIronChockBoot(Canvas canvas, Size size, double xFraction, bool mismatch) {
    final w = size.width, h = size.height;
    final x = xFraction * w;
    final half = 0.021 * w;
    final boot = Path()
      ..moveTo(x - half, _deckTopY * h)
      ..lineTo(x + half, _deckTopY * h)
      ..lineTo(x + half, (_deckTopY - 0.028) * h)
      ..lineTo(x + half * 0.45, (_deckTopY - 0.028) * h)
      ..lineTo(x + half * 0.45, (_deckTopY - 0.082) * h)
      ..lineTo(x - half * 0.1, (_deckTopY - 0.082) * h)
      ..lineTo(x - half * 0.1, (_deckTopY - 0.028) * h)
      ..lineTo(x - half, (_deckTopY - 0.028) * h)
      ..close();
    canvas.drawPath(boot, _fill(_metalColor(mismatch)));
    canvas.drawPath(boot, _stroke(AppColors.textSecondary, 1.3));
  }

  void _paintLashing(
    Canvas canvas,
    Size size,
    SchematicElement element,
    ({double left, double right}) body,
  ) {
    final w = size.width, h = size.height;
    final xs = _distinctXs(element);
    if (xs.isEmpty) return;
    final color = element.isSelectionMismatch ? AppColors.outOfTolerance : AppColors.offNominal;
    final paint = _stroke(color, 1.6);
    for (final xFraction in xs) {
      // Anchored on the hull side nearest that x and run down to the deck at
      // roughly the 45 degrees figure B-26 caps the angle at.
      final nearFront = xFraction > (body.left + body.right) / 2;
      final hullX = (nearFront ? body.right : body.left) * w;
      final deckX = xFraction * w;
      final from = Offset(hullX, (_trackTopY - 0.03) * h);
      final to = Offset(deckX, _deckTopY * h);
      canvas.drawLine(from, to, paint);

      // Twist marks along the strand, so a wire lashing does not read as a
      // plain rule line.
      final dx = to.dx - from.dx, dy = to.dy - from.dy;
      final length = math.sqrt(dx * dx + dy * dy);
      if (length > 0) {
        final nx = -dy / length, ny = dx / length;
        for (var t = 0.2; t < 0.9; t += 0.22) {
          final px = from.dx + dx * t, py = from.dy + dy * t;
          canvas.drawLine(
            Offset(px - nx * 3, py - ny * 3),
            Offset(px + nx * 3, py + ny * 3),
            _stroke(color, 1),
          );
        }
      }
      // Tensioner at the deck ring.
      canvas.drawCircle(to, 0.008 * w, paint);
    }
  }

  /// Names under the deck with leader lines up to the items, the way the
  /// plates label their parts.
  ///
  /// Two rows, and a label drops to the second row when it would touch the
  /// one before it: the first version lettered every name on one line and the
  /// wire lashing's name ran straight through the stop-block's.
  void _paintHardwareLabels(
    Canvas canvas,
    Size size,
    List<({double x, String text, bool mismatch})> labels,
  ) {
    if (labels.isEmpty) return;
    final w = size.width, h = size.height;
    final sorted = [...labels]..sort((a, b) => a.x.compareTo(b.x));
    final rowEnds = <double>[0, 0];

    for (final label in sorted) {
      final painter = TextPainter(
        text: TextSpan(
          text: label.text,
          style: TextStyle(
            color: label.mismatch ? AppColors.outOfTolerance : AppColors.textSecondary,
            fontSize: 12,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
        ellipsis: '…',
      )..layout(maxWidth: 0.30 * w);

      final anchorX = label.x * w;
      var left = (anchorX - painter.width / 2)
          .clamp(2.0, math.max(2.0, w - painter.width - 2))
          .toDouble();
      var row = 0;
      if (left < rowEnds[0] + 6) {
        row = 1;
        if (left < rowEnds[1] + 6) left = rowEnds[1] + 6;
      }
      if (left + painter.width > w) continue; // no room left; drop it silently
      rowEnds[row] = left + painter.width;

      final labelY = (_solebarBottomY + 0.05 + row * 0.075) * h;
      canvas.drawLine(
        Offset(anchorX, (_deckTopY - 0.01) * h),
        Offset(anchorX, labelY - 0.008 * h),
        _stroke(AppColors.hairline, 1),
      );
      painter.paint(canvas, Offset(left, labelY));
    }
  }

  void _paintDesignation(
    Canvas canvas,
    Size size,
    ({double left, double right}) body,
    String designation,
  ) {
    final painter = TextPainter(
      text: TextSpan(
        text: designation,
        style: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final centreX = (body.left + body.right) / 2 * size.width;
    painter.paint(
      canvas,
      Offset(centreX - painter.width / 2, (_turretTopY - 0.10) * size.height),
    );
  }

  @override
  bool shouldRepaint(covariant SideElevationPainter old) =>
      old.diagram != diagram ||
      old.showLabels != showLabels ||
      old.showDimensions != showDimensions ||
      old.deckLength != deckLength;
}
