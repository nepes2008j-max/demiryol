@Tags(['flutter'])
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:convert';

import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/usecases/generated/compiled_vehicle_models.dart';
import 'package:railsim/domain/usecases/obj_mesh_loader.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/presentation/widgets/visualization/scene3d_painter.dart';

/// How many faces the software renderer can carry before orbiting stops
/// feeling live.
///
/// Not an assertion about the machine it runs on — it prints a table. The
/// question it answers is the only one that matters when choosing a
/// decimation target: at what face count does one frame stop fitting in the
/// budget a dragged camera needs.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frame cost against face count', () {
    final compiled = CompiledVehicleModels.forVehicle('veh-t72');
    expect(compiled, isNotNull);
    final base = ObjMeshLoader.parse(utf8.decode(compiled!.bytes()));
    expect(base.faces, isNotEmpty);

    const size = Size(1100, 620);
    const camera = Camera3(
      target: Vector3(0, 1.6, 0),
      distance: 16,
      yaw: 0.7,
      pitch: 0.28,
    );

    // Fractions of the model's own faces, evenly spaced through it, so the
    // material mix and the depth spread stay honest and only the count
    // changes. Taking a prefix instead would sample one end of the tank.
    String row(int wanted) {
      final total = base.faces.length;
      final step = total / wanted;
      final faces = <Face3>[
        for (var i = 0; i < wanted; i++) base.faces[(i * step).floor().clamp(0, total - 1)],
      ];
      final mesh = Mesh3(faces);

      // One untimed pass, so the JIT has seen the code before the clock starts.
      SceneProjection.render(mesh, camera: camera, width: size.width, height: size.height);

      final watch = Stopwatch()..start();
      const rounds = 3;
      for (var i = 0; i < rounds; i++) {
        final projected = SceneProjection.render(
          mesh, camera: camera, width: size.width, height: size.height);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        Scene3Painter(projected).paint(canvas, size);
        recorder.endRecording().dispose();
      }
      watch.stop();
      final ms = watch.elapsedMicroseconds / 1000 / rounds;
      final drawn = SceneProjection.render(
        mesh, camera: camera, width: size.width, height: size.height).length;
      return '${mesh.faces.length.toString().padLeft(8)} faces  '
          '${drawn.toString().padLeft(8)} drawn  '
          '${ms.toStringAsFixed(1).padLeft(8)} ms/frame  '
          '${(1000 / ms).toStringAsFixed(0).padLeft(4)} fps';
    }

    debugPrint('\n=== software renderer, one frame at 1100x620 ===');
    for (final faces in [8000, 24000, 64000, 180000, base.faces.length]) {
      debugPrint(row(faces));
    }
    debugPrint('(the vehicle is one part of the scene; the wagon, track and '
        'securing gear are drawn on top of these numbers)\n');
  });
}
