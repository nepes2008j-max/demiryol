@Tags(['flutter'])
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/usecases/generated/compiled_vehicle_models.dart';
import 'package:railsim/domain/usecases/obj_mesh_loader.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/presentation/widgets/visualization/scene3d_painter.dart';

/// Where a frame actually goes, stage by stage.
///
/// The face budget was chosen against a single total. That total hides which
/// stage is the wall: if it is the per-face `drawPath`, one `drawVertices`
/// call per material replaces it and the budget moves a long way; if it is the
/// projection or the depth sort, no change to the draw path helps and the
/// ceiling is where it is. This prints the split so the answer is measured.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('frame cost, stage by stage', () async {
    final compiled = CompiledVehicleModels.forVehicle('veh-t72')!;
    final base = ObjMeshLoader.parse(utf8.decode(compiled.bytes()),
        materialFor: ObjMeshLoader.materialFromName);

    const size = Size(1100, 620);
    const camera = Camera3(
      target: Vector3(0, 1.6, 0), distance: 16, yaw: 0.7, pitch: 0.28);

    double timed(int rounds, void Function() body) {
      body();
      final w = Stopwatch()..start();
      for (var i = 0; i < rounds; i++) {
        body();
      }
      w.stop();
      return w.elapsedMicroseconds / 1000 / rounds;
    }

    debugPrint('\n=== one frame at 1100x620, by stage (ms) ===');
    debugPrint('   faces   project+sort   drawPath   drawVertices   build verts');

    for (final wanted in [24000, 180000, base.faces.length]) {
      final total = base.faces.length;
      final step = total / wanted;
      final faces = <Face3>[
        for (var i = 0; i < wanted; i++) base.faces[(i * step).floor().clamp(0, total - 1)],
      ];
      final mesh = Mesh3(faces);

      final projectMs = timed(3, () {
        SceneProjection.render(mesh,
            camera: camera, width: size.width, height: size.height);
      });

      final projected = SceneProjection.render(mesh,
          camera: camera, width: size.width, height: size.height);

      final pathMs = timed(3, () {
        final r = ui.PictureRecorder();
        Scene3Painter(projected, drawEdges: false).paint(Canvas(r), size);
        r.endRecording().dispose();
      });

      // The same polygons as one triangle soup with a colour per vertex:
      // what a single drawVertices call per material would be handed.
      late Float32List positions;
      late Int32List colors;
      final buildMs = timed(3, () {
        final pts = <double>[];
        final cols = <int>[];
        for (final f in projected) {
          final shaded = Scene3Painter.materialColor(f.material);
          final c = Color.fromARGB(
            255,
            (shaded.r * 255 * f.shade.r).round().clamp(0, 255),
            (shaded.g * 255 * f.shade.g).round().clamp(0, 255),
            (shaded.b * 255 * f.shade.b).round().clamp(0, 255),
          ).toARGB32();
          for (var i = 2; i < f.points.length; i++) {
            for (final p in [f.points[0], f.points[i - 1], f.points[i]]) {
              pts..add(p.x)..add(p.y);
              cols.add(c);
            }
          }
        }
        positions = Float32List.fromList(pts);
        colors = Int32List.fromList(cols);
      });

      final vertsMs = timed(3, () {
        final v = ui.Vertices.raw(ui.VertexMode.triangles, positions,
            colors: colors);
        final r = ui.PictureRecorder();
        Canvas(r).drawVertices(v, BlendMode.dst, Paint());
        r.endRecording().dispose();
        v.dispose();
      });

      debugPrint('${mesh.faces.length.toString().padLeft(8)}'
          '${projectMs.toStringAsFixed(1).padLeft(15)}'
          '${pathMs.toStringAsFixed(1).padLeft(11)}'
          '${vertsMs.toStringAsFixed(1).padLeft(15)}'
          '${buildMs.toStringAsFixed(1).padLeft(14)}');
    }
    debugPrint('');
  });
}
