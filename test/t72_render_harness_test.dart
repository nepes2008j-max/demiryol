@Tags(['flutter'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/domain/usecases/scene3d_raster.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';
import 'package:railsim/presentation/widgets/visualization/scene3d_painter.dart';

/// Not a check — a picture. It renders the T-72 on a wagon exactly the way the
/// placement screen does (the same fitted mesh through the same provider, the
/// same scene builder, the same camera and the same drawVertices/BlendMode.dst
/// paint) and writes it to a PNG, so the imported model can be looked at
/// without driving the desktop GUI. Set RAILSIM_RENDER_OUT to choose the path.
void main() {
  testWidgets('render the T-72 on a wagon to a PNG', (tester) async {
    if (Platform.environment['RAILSIM_RENDER_OUT'] == null) {
      markTestSkipped('set RAILSIM_RENDER_OUT to render the T-72');
      return;
    }
    // The exact mesh the placement screen draws.
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final fitted = await container.read(vehicleMeshProvider('veh-t72').future);
    expect(fitted, isNotNull, reason: 'the compiled T-72 must load');

    // The same scene the view assembles for one vehicle on a standard wagon.
    final scene = buildLoadedWagonScene(
      loads: [
        PlacedLoad(
          placementId: 'placement-0',
          designation: 'T-72',
          spec: TrackedVehicleMeshSpec.t72,
          positionFraction: 0.5,
          turretTraverse: 0,
          securing: SecuringLayout.empty,
          meshOverride: fitted!.model.mesh,
        ),
      ],
      flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      includeTrackBed: true,
      includeVehicles: true,
    );

    // The view is a 2.35 aspect box; frame on the wagon and its load.
    const width = 1600.0;
    const height = width / 2.35;
    final camera = Camera3.framing(
      scene.flatcar.mesh.bounds.union(scene.loadBounds),
      yaw: 0.62,
      pitch: 0.28,
      aspectRatio: width / height,
    );

    final frame = SceneRaster.render(
      RasterMesh.from(scene.mesh),
      camera: camera,
      width: width,
      height: height,
      colorOf: (m) => Scene3Painter.materialColor(m).toARGB32() & 0x00FFFFFF,
    );
    expect(frame, isNotNull, reason: 'the scene rasterised to nothing');

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder,
        const Rect.fromLTWH(0, 0, width, height));
    // The same vertical gradient the DecoratedBox paints behind the scene.
    final bg = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF262B30), Color(0xFF15181B)],
      ).createShader(const Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(const Rect.fromLTWH(0, 0, width, height), bg);
    // Exactly the painter's call.
    canvas.drawVertices(frame!.vertices, BlendMode.dst, Paint());

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    expect(bytes, isNotNull);

    final out = Platform.environment['RAILSIM_RENDER_OUT'] ??
        '${Platform.environment['HOME']}/Desktop/railsim_t72_render.png';
    File(out).writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE $out  (${frame.triangleCount} triangles)');
  });
}
