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
import 'package:railsim/domain/usecases/vehicle_mesh_catalog.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';
import 'package:railsim/presentation/widgets/visualization/scene3d_painter.dart';

/// Renders any catalogued vehicle (RAILSIM_VEH) on a standard flatcar, exactly
/// the way the placement screen does, to a PNG (RAILSIM_RENDER_OUT).
void main() {
  testWidgets('render a vehicle on the wagon', (tester) async {
    final id = Platform.environment['RAILSIM_VEH'];
    if (id == null) {
      markTestSkipped('set RAILSIM_VEH to render a vehicle on the wagon');
      return;
    }
    final c = ProviderContainer();
    addTearDown(c.dispose);

    final vehicles = await c.read(vehiclesProvider.future);
    final vehicle = vehicles.firstWhere((v) => v.id == id);
    final spec = VehicleMeshCatalog.specFor(vehicle)!;
    final fitted = await c.read(vehicleMeshProvider(id).future);

    final scene = buildLoadedWagonScene(
      loads: [
        PlacedLoad(
          placementId: 'p0',
          designation: vehicle.handbookDesignation,
          spec: spec,
          positionFraction: 0.5,
          turretTraverse: 0,
          securing: SecuringLayout.empty,
          meshOverride: fitted?.model.mesh,
        ),
      ],
      flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      includeTrackBed: true,
      includeVehicles: true,
    );

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

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, const Rect.fromLTWH(0, 0, width, height));
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, width, height),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF262B30), Color(0xFF15181B)],
        ).createShader(const Rect.fromLTWH(0, 0, width, height)),
    );
    canvas.drawVertices(frame!.vertices, BlendMode.dst, Paint());
    final img =
        await recorder.endRecording().toImage(width.toInt(), height.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File(Platform.environment['RAILSIM_RENDER_OUT']!)
        .writeAsBytesSync(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE ${Platform.environment['RAILSIM_RENDER_OUT']} for $id');
  });
}
