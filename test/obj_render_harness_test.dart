@Tags(['flutter'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/domain/usecases/obj_mesh_loader.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/domain/usecases/scene3d_raster.dart';
import 'package:railsim/presentation/widgets/visualization/scene3d_painter.dart';

/// Renders an arbitrary OBJ (RAILSIM_OBJ) fitted to L/W/H (RAILSIM_LWH="l,w,h")
/// to a PNG (RAILSIM_RENDER_OUT), the same way the scene draws a vehicle.
void main() {
  testWidgets('render an OBJ to a PNG', (tester) async {
    final objPath = Platform.environment['RAILSIM_OBJ'];
    if (objPath == null) {
      markTestSkipped('set RAILSIM_OBJ to render an OBJ');
      return;
    }
    final lwh = (Platform.environment['RAILSIM_LWH'] ?? '7.65,2.90,2.41')
        .split(',')
        .map(double.parse)
        .toList();

    final loaded = ObjMeshLoader.load(
      File(objPath).readAsStringSync(),
      targetLengthM: lwh[0],
      recordedWidthM: lwh[1],
      recordedHeightM: lwh[2],
      convention: ObjAxisConvention.yUpFacingPlusX,
      materialFor: ObjMeshLoader.materialFromName,
    );
    expect(loaded.mesh.isEmpty, isFalse);

    const width = 1500.0;
    const height = width / 1.9;
    final camera = Camera3.framing(
      loaded.mesh.bounds,
      yaw: double.parse(Platform.environment['RAILSIM_YAW'] ?? '0.7'),
      pitch: double.parse(Platform.environment['RAILSIM_PITCH'] ?? '0.30'),
      aspectRatio: width / height,
    );
    final frame = SceneRaster.render(
      RasterMesh.from(loaded.mesh),
      camera: camera,
      width: width,
      height: height,
      colorOf: (m) => Scene3Painter.materialColor(m).toARGB32() & 0x00FFFFFF,
    );
    expect(frame, isNotNull);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF262B30), Color(0xFF15181B)],
      ).createShader(const Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bg);
    canvas.drawVertices(frame!.vertices, BlendMode.dst, Paint());

    final img = await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    final out = Platform.environment['RAILSIM_RENDER_OUT']!;
    File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE $out (${frame.triangleCount} tris, ${loaded.mesh.faces.length} faces)');
  });
}
