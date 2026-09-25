@Tags(['flutter'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/domain/usecases/scene3d_raster.dart';
import 'package:railsim/presentation/widgets/visualization/scene3d_painter.dart';

/// The fast draw path has to put the same colours on the screen as the slow
/// one, and the only way to know is to read the pixels back.
///
/// `drawVertices` blends the vertex colours against the paint, and which of
/// the two survives depends on the blend mode. Get it wrong and the whole
/// scene comes out one flat colour — which looks like a shading bug, not a
/// blend-mode bug, and would be hunted for in the wrong file. So this renders
/// a face of a known material both ways and compares.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  int colorOf(SurfaceMaterial m) =>
      Scene3Painter.materialColor(m).toARGB32() & 0x00FFFFFF;

  /// A single square standing upright across the view, big enough to cover
  /// the middle of the frame from any of these cameras.
  Mesh3 wall(SurfaceMaterial material) => Mesh3([
        Face3(
          const [
            Vector3(0, -4, -4),
            Vector3(0, 4, -4),
            Vector3(0, 4, 4),
            Vector3(0, -4, 4),
          ],
          material: material,
        ),
      ]);

  const size = Size(200, 200);
  const camera = Camera3(
    target: Vector3(0, 0, 0), distance: 10, yaw: 1.5708, pitch: 0.0);

  Future<ui.Image> rasterise(void Function(Canvas) draw) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = const Color(0xFF000000),
    );
    draw(canvas);
    return recorder
        .endRecording()
        .toImage(size.width.toInt(), size.height.toInt());
  }

  Future<int> centrePixel(ui.Image image) async {
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final offset = ((size.height ~/ 2) * size.width.toInt() + size.width ~/ 2) * 4;
    final b = data!.buffer.asUint8List();
    return (0xFF << 24) | (b[offset] << 16) | (b[offset + 1] << 8) | b[offset + 2];
  }

  for (final material in [
    SurfaceMaterial.hullArmour,
    SurfaceMaterial.trackLink,
    SurfaceMaterial.deckPlank,
  ]) {
    test('the raster path paints ${material.name} as the painter does',
        () async {
      final mesh = wall(material);

      final slow = await rasterise((canvas) {
        final faces = SceneProjection.render(mesh,
            camera: camera, width: size.width, height: size.height);
        expect(faces, isNotEmpty, reason: 'the wall should face this camera');
        Scene3Painter(faces, drawEdges: false).paint(canvas, size);
      });

      final frame = SceneRaster.render(
        RasterMesh.from(mesh),
        camera: camera,
        width: size.width,
        height: size.height,
        colorOf: colorOf,
      );
      expect(frame, isNotNull);
      final fast = await rasterise(
          (canvas) => RasterScenePainter(frame!).paint(canvas, size));

      final expected = await centrePixel(slow);
      final actual = await centrePixel(fast);

      // Not black: a wrong blend mode paints the paint's default colour, and
      // the whole point of the check is that the vertex colour survived.
      expect(expected, isNot(0xFF000000),
          reason: 'the reference render is blank; the camera missed the wall');
      // Within one step per channel: the two paths round the shading
      // independently.
      for (var shift in [16, 8, 0]) {
        expect(((actual >> shift) & 0xFF) - ((expected >> shift) & 0xFF),
            inInclusiveRange(-1, 1),
            reason: 'channel at bit $shift: '
                'raster ${actual.toRadixString(16)} vs '
                'painter ${expected.toRadixString(16)}');
      }
    });
  }

  test('a highlight dims what is not part of it', () async {
    const mesh = Mesh3([
      Face3(
        [
          Vector3(0, -4, -4),
          Vector3(0, 4, -4),
          Vector3(0, 4, 4),
          Vector3(0, -4, 4),
        ],
        material: SurfaceMaterial.hullArmour,
        partId: 'securing.block.1',
      ),
    ]);
    final flat = RasterMesh.from(mesh);

    final lit = SceneRaster.render(flat,
        camera: camera, width: size.width, height: size.height,
        colorOf: colorOf, highlightPartPrefix: 'securing.block.1');
    final dim = SceneRaster.render(flat,
        camera: camera, width: size.width, height: size.height,
        colorOf: colorOf, highlightPartPrefix: 'securing.block.9');

    final litPixel = await centrePixel(await rasterise(
        (c) => RasterScenePainter(lit!).paint(c, size)));
    final dimPixel = await centrePixel(await rasterise(
        (c) => RasterScenePainter(dim!).paint(c, size)));

    expect(litPixel, isNot(dimPixel),
        reason: 'the piece not being worked on should be pulled towards grey');
  });

  test('a smooth face is shaded corner by corner, a flat one is not', () async {
    // Corner normals fanned apart, as a curved surface's would be. Each corner
    // then faces the light differently and gets its own colour, which is what
    // the fill interpolates across to turn facets into a curve.
    Mesh3 curved({required bool smooth}) => Mesh3([
          Face3(
            const [
              Vector3(0, -4, -4),
              Vector3(0, 4, -4),
              Vector3(0, 4, 4),
            ],
            material: SurfaceMaterial.hullArmour,
            vertexNormals: smooth
                ? const [
                    Vector3(1, -0.8, -0.8),
                    Vector3(1, 0.8, -0.8),
                    Vector3(1, 0.8, 0.8),
                  ]
                : null,
          ),
        ]);

    /// Every distinct colour the triangle actually put on the screen, with the
    /// background dropped: the sample grid covers the frame, and most of it
    /// falls outside a triangle that fills half of it.
    Future<Set<int>> coloursOf(Mesh3 mesh) async {
      final frame = SceneRaster.render(RasterMesh.from(mesh),
          camera: camera, width: size.width, height: size.height,
          colorOf: colorOf);
      expect(frame, isNotNull);
      final image = await rasterise(
          (c) => RasterScenePainter(frame!).paint(c, size));
      final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      final bytes = data!.buffer.asUint8List();
      final seen = <int>{};
      for (var y = 10; y < size.height - 10; y += 7) {
        for (var x = 10; x < size.width - 10; x += 7) {
          final o = (y * size.width.toInt() + x) * 4;
          final c = (bytes[o] << 16) | (bytes[o + 1] << 8) | bytes[o + 2];
          if (c != 0) seen.add(c);
        }
      }
      return seen;
    }

    final flat = await coloursOf(curved(smooth: false));
    final smooth = await coloursOf(curved(smooth: true));

    expect(flat, isNotEmpty, reason: 'the triangle should be on screen at all');
    expect(flat, hasLength(1),
        reason: 'a face with no corner normals is one flat colour');
    expect(smooth.length, greaterThan(8),
        reason: 'corner normals should give the fill a gradient to interpolate, '
            'not a handful of steps');
  });
}
