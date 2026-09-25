import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/scene3d.dart';
import '../../../domain/usecases/scene3d_camera.dart';
import '../../../domain/usecases/scene3d_raster.dart';

/// Paints a projected three-dimensional scene.
///
/// The whole of the painter's job is: take the polygons the domain layer has
/// already sorted and shaded, decide what colour each material is, and fill
/// them in order. It performs no geometry and no lighting of its own — the
/// same split the flat schematic painters keep, so that what the trainee sees
/// can always be traced back to a dimension rather than to a drawing choice.
class Scene3Painter extends CustomPainter {
  final List<ProjectedFace> faces;

  /// Draw a hairline along every polygon edge. On a dark interface this is
  /// what separates one track link from the next; without it the running gear
  /// reads as a single dark mass.
  final bool drawEdges;

  /// A part whose faces are drawn at full strength while everything else is
  /// dimmed — used to pick the securing gear out of the machine it holds.
  final String? highlightPartPrefix;

  const Scene3Painter(
    this.faces, {
    this.drawEdges = true,
    this.highlightPartPrefix,
  });

  /// The colour of each kind of surface, before shading.
  ///
  /// The palette follows the handbook's own plates: an oxblood-red wagon on
  /// black bogies, a timber deck, and the vehicle in service green. Keeping
  /// the drawn wagon the colour of the plated one means a trainee moving
  /// between the plate and this view is looking at the same object.
  static Color materialColor(SurfaceMaterial material) {
    switch (material) {
      case SurfaceMaterial.hullArmour:
        return const Color(0xFF56602A);
      case SurfaceMaterial.hullSide:
        return const Color(0xFF464F21);
      case SurfaceMaterial.hullBelly:
        return const Color(0xFF353C1B);
      case SurfaceMaterial.appliqueArmour:
        return const Color(0xFF616B31);
      case SurfaceMaterial.turret:
        return const Color(0xFF4F5824);
      case SurfaceMaterial.gunBarrel:
        return const Color(0xFF3B4029);
      case SurfaceMaterial.trackLink:
        // Worn steel, deliberately lighter than the road wheels behind it:
        // in a side elevation the track band and the wheels overlap almost
        // everywhere, and two dark greys read as one dark mass.
        return const Color(0xFF4E524E);
      case SurfaceMaterial.roadWheel:
        return const Color(0xFF25282A);
      case SurfaceMaterial.driveSprocket:
        return const Color(0xFF343830);
      case SurfaceMaterial.fender:
        return const Color(0xFF424B20);
      case SurfaceMaterial.stowage:
        return const Color(0xFF5A6438);
      case SurfaceMaterial.tyre:
        // Darker than a road wheel's hub, so a lorry's tyres read as rubber
        // rather than as part of the body.
        return const Color(0xFF1E2022);
      case SurfaceMaterial.glazing:
        return const Color(0xFF6E8794);
      case SurfaceMaterial.tilt:
        // Canvas over the cargo bed: paler and flatter than the paintwork it
        // sits on, which is what separates the two at a glance.
        return const Color(0xFF6E7247);
      // The wagon, in the instrument's light rather than in daylight.
      //
      // The handbook's plates print a flatcar in oxblood on a timber deck and
      // that lineage is kept — but the plates are ink on white paper and this
      // is a lit field on near-black. At the plates' own saturation the wagon
      // came out as the brightest thing on the screen, louder than the vehicle
      // standing on it, and its red sat in the same hue as
      // [AppColors.outOfTolerance] — the one red in this interface, which means
      // a reading is outside the handbook's range. A wagon is not a verdict.
      // Same colours, taken down in saturation and value until the machine and
      // the securing gear read first and nothing on the wagon can be mistaken
      // for an alarm.
      case SurfaceMaterial.deckPlank:
        return const Color(0xFF6B563A);
      case SurfaceMaterial.deckEdge:
        return const Color(0xFF4C2721);
      case SurfaceMaterial.wagonFrame:
        return const Color(0xFF5C2F27);
      case SurfaceMaterial.bogie:
        return const Color(0xFF23241F);
      case SurfaceMaterial.wagonWheel:
        return const Color(0xFF2C2D28);
      case SurfaceMaterial.railHead:
        return const Color(0xFF9BA2A8);
      case SurfaceMaterial.sleeper:
        return const Color(0xFF4B3C2B);
      case SurfaceMaterial.ballast:
        return const Color(0xFF4E4F47);
      case SurfaceMaterial.woodChock:
        return AppColors.label;
      case SurfaceMaterial.ironChock:
        return const Color(0xFF8C919A);
      case SurfaceMaterial.wireLashing:
        return const Color(0xFFD3D7DC);
      case SurfaceMaterial.tieDownRing:
        return const Color(0xFFA7ADB4);
      case SurfaceMaterial.selectionMarker:
        // The instrument's own light, which everywhere else in the program
        // means "this is the thing being measured". Bright enough to be found
        // at a glance among a deck of timber and steel, and no longer amber:
        // amber is reserved for a reading the handbook does not confirm, and
        // a held stop block is not an unconfirmed reading.
        return AppColors.instrumentGlow;
      case SurfaceMaterial.guideLine:
        return AppColors.instrumentDeep;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..style = PaintingStyle.fill;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.6
      ..color = const Color(0x33000000);

    for (final face in faces) {
      if (face.points.length < 3) continue;
      final path = Path()..moveTo(face.points.first.x, face.points.first.y);
      for (var i = 1; i < face.points.length; i++) {
        path.lineTo(face.points[i].x, face.points[i].y);
      }
      path.close();

      final flatLit = face.material == SurfaceMaterial.selectionMarker ||
          face.material == SurfaceMaterial.guideLine;
      var color = _shaded(
        materialColor(face.material),
        // Markers are drawn at an even brightness rather than lit: a guide on
        // the deck has to read the same whichever way the scene is turned.
        flatLit ? SceneLighting.flat : face.shade,
      );
      final prefix = highlightPartPrefix;
      if (prefix != null && !(face.partId?.startsWith(prefix) ?? false)) {
        color = Color.lerp(color, AppColors.panel, 0.62)!;
      }
      fill.color = color;
      canvas.drawPath(path, fill);
      if (drawEdges) canvas.drawPath(path, edge);
    }
  }

  /// Multiplies a surface colour by its light level. Done in the painter
  /// rather than the domain layer so the shading term stays a number the
  /// tests can assert on.
  static Color _shaded(Color base, ({double r, double g, double b}) light) =>
      Color.fromARGB(
        255,
        (base.r * 255 * light.r).round().clamp(0, 255),
        (base.g * 255 * light.g).round().clamp(0, 255),
        (base.b * 255 * light.b).round().clamp(0, 255),
      );

  @override
  bool shouldRepaint(covariant Scene3Painter old) =>
      !identical(old.faces, faces) ||
      old.drawEdges != drawEdges ||
      old.highlightPartPrefix != highlightPartPrefix;
}

/// Draws a [RasterFrame]: the whole scene in one `drawVertices` call.
///
/// The counterpart to [Scene3Painter], for meshes too large to fill one face
/// at a time — see [SceneRaster] for the measurements that made it necessary.
/// There is no edge stroke here and no highlight logic: `drawVertices` fills
/// triangles, and the shading and any dimming were already baked into the
/// vertex colours while the frame was projected.
class RasterScenePainter extends CustomPainter {
  final RasterFrame frame;

  const RasterScenePainter(this.frame);

  @override
  void paint(Canvas canvas, Size size) {
    // BlendMode.dst takes the vertex colours and ignores the paint's own,
    // which is what carries the per-face shading. test/scene3d_raster_test.dart
    // pins this down by reading pixels back.
    canvas.drawVertices(frame.vertices, BlendMode.dst, Paint());
  }

  @override
  bool shouldRepaint(covariant RasterScenePainter oldDelegate) =>
      !identical(oldDelegate.frame, frame);
}
