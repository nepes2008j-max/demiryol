import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/usecases/generated/compiled_vehicle_models.dart';
import 'package:railsim/domain/usecases/obj_mesh_loader.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';

/// The models compiled into the binary rather than shipped under `assets/`.
///
/// One of them exists so far — the T-72 — and it is there because its licence
/// permits shipping it inside an application only where it cannot be lifted
/// back out of it. These checks are about the two things that could quietly
/// go wrong with that arrangement: the packed geometry failing to unpack, and
/// the credit going missing.
void main() {
  group('the compiled T-72', () {
    final model = CompiledVehicleModels.forVehicle('veh-t72');

    test('is registered and credited', () {
      expect(model, isNotNull);
      expect(model!.isAttributed, isTrue);
      expect(model.author, isNotEmpty);
      expect(model.sourceUrl, startsWith('http'));
      expect(model.license, isNotEmpty);
      // The credit line is what the screen shows beside the drawing. A model
      // is not drawn without it.
      expect(model.creditLine, contains(model.author));
      expect(model.creditLine, contains(model.license));
    });

    // The published mesh, whole. Nothing is decimated away any more.
    //
    // It used to be 7,999, then 23,999, both chosen against what the per-face
    // draw path could fill in a frame. That ceiling is gone: the scene is
    // drawn by SceneRaster in a single drawVertices call, which took the frame
    // from 535 ms to 29 ms (test/draw_path_benchmark_test.dart). The number
    // below is now simply what the file contains — 549,035 triangles as
    // published, less the handful the weld merges.
    const compiledFaceBudget = 548889;

    test('unpacks to the geometry it was built from', () {
      final bytes = model!.bytes();
      expect(bytes, isNotEmpty);
      final parsed = ObjMeshLoader.parse(String.fromCharCodes(bytes),
          materialFor: ObjMeshLoader.materialFromName);
      expect(parsed.faces, hasLength(compiledFaceBudget));
    });

    test('fits the T-72 record and stands on its running gear', () {
      const spec = TrackedVehicleMeshSpec.t72;
      final loaded = ObjMeshLoader.load(
        String.fromCharCodes(model!.bytes()),
        targetLengthM: spec.lengthOverGunM,
        recordedHeightM: spec.overallHeightM,
        recordedWidthM: spec.overallWidthM,
        materialFor: ObjMeshLoader.materialFromName,
      );
      final bounds = loaded.mesh.bounds;

      // Fitted on width, which is the dimension every model has and the one
      // the loader scales to.
      expect(bounds.max.z - bounds.min.z, closeTo(spec.overallWidthM, 0.01));
      // Seated: the mesh's lowest point is the deck it will be put on, not
      // some arbitrary offset the modeller left in.
      expect(bounds.min.y, closeTo(0.0, 1e-6));
      // Long enough to be this vehicle and not another: the gun is trained
      // forward, so the length lands near the record's length over the gun.
      expect(bounds.max.x - bounds.min.x, closeTo(spec.lengthOverGunM, 0.5));
    });

    testWidgets('reaches the screens through the provider they read',
        (tester) async {
      // The geometry being right is worth nothing if nothing asks for it,
      // which was the state of things until the provider learned to look past
      // the asset manifest to the compiled-in models.
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Inside runAsync: the provider reads the catalogue off the asset bundle,
      // which is real I/O, and a widget test's fake clock never gives it a turn.
      FittedVehicleMesh? fitted;
      Object? noModel = 'unset';
      await tester.runAsync(() async {
        fitted = await container.read(vehicleMeshProvider('veh-t72').future);
        // And a vehicle with no model still gets none, which is the normal
        // case. The T-90S is in the catalogue with real dimensions and has no
        // model file behind it.
        noModel = await container.read(vehicleMeshProvider('veh-t90s').future);
      });

      expect(fitted, isNotNull);
      expect(fitted!.model.mesh.faces, hasLength(compiledFaceBudget));
      expect(fitted!.asset, isNull, reason: 'this one is compiled in, not a file');
      expect(fitted!.creditLine, contains('18095010881'));
      expect(noModel, isNull);
    });

    test('keeps the running gear a separate surface from the hull', () {
      // The part names in the file are Chinese; the import translates them so
      // the renderer can colour the tracks apart from the hull. If that
      // mapping is lost the tank is drawn as one flat green mass.
      final parsed = ObjMeshLoader.parse(
          String.fromCharCodes(model!.bytes()),
          materialFor: ObjMeshLoader.materialFromName);
      final materials = parsed.faces.map((f) => f.material).toSet();
      expect(materials, contains(SurfaceMaterial.trackLink));
      expect(materials, contains(SurfaceMaterial.roadWheel));
      expect(materials, contains(SurfaceMaterial.hullArmour));
    });
  });
}
