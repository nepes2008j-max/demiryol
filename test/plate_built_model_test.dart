import 'dart:io';

import 'package:test/test.dart';

import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/usecases/obj_mesh_loader.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';

/// The models built from the plates by `tools/build_model_from_plate.py`.
///
/// `assets/models/README.md` ends with "run the tests" for a reason: a model
/// file is the one asset in this project that can be wrong in a way nobody
/// sees. A photograph that is of the wrong vehicle is obvious; a mesh that is
/// twelve centimetres too tall renders perfectly and quietly moves the load
/// height the trainee is measuring. So the file is read here through the same
/// loader the application uses, fitted the same way, and held against the
/// vehicle record's own figures.
///
/// These are not tests of the Python tool. They are tests of the artefact it
/// left behind, which is what actually ships.
void main() {
  group('the T-72 built from the three-view plate', () {
    final file = File('assets/models/veh-t72.obj');

    test('the file is in the bundle', () {
      expect(file.existsSync(), isTrue,
          reason: 'run tools/build_model_from_plate.py --spec '
              'tools/plate_specs/veh-t72.json');
    });

    test('it is authored in the frame the manifest claims', () {
      // Written by the tool in this project's own frame, so the manifest says
      // `yUpFacingPlusX` and the loader has nothing to rotate. If that ever
      // stops being true the mesh arrives lying on its side, which is exactly
      // the failure a reader of the JSON cannot see.
      final mesh = ObjMeshLoader.parse(file.readAsStringSync());
      final size = mesh.bounds.size;
      expect(size.x, greaterThan(size.z),
          reason: 'the long axis should already be +x');
      expect(size.z, greaterThan(size.y),
          reason: 'the vehicle should be wider than it is tall');
      expect(mesh.bounds.min.y, closeTo(0, 0.01),
          reason: 'it should stand on the running surface, not straddle it');
    });

    test('it fits the record within the loader\'s tolerance', () {
      const spec = TrackedVehicleMeshSpec.t72;
      final loaded = ObjMeshLoader.load(
        file.readAsStringSync(),
        targetLengthM: spec.lengthOverGunM,
        recordedHeightM: spec.overallHeightM,
        recordedWidthM: spec.overallWidthM,
        convention: ObjAxisConvention.yUpFacingPlusX,
      );
      final report = loaded.report;

      // Fitted on width, so the width is exact by construction and the other
      // two carry whatever the plate and the record disagree about. The
      // height runs over because the side elevation draws the commander's
      // sight above the 2.19 m turret roof the record means; the length runs
      // under because the muzzle is a taper that a threshold trims. Both are
      // the plate's own, both are small, and both are worth failing on if
      // they grow — that is what would say the plate had been re-cropped or
      // the record changed underneath the model.
      expect(report.widthErrorM.abs(), lessThan(0.02));
      expect(report.heightErrorM, inInclusiveRange(0.0, 0.30));
      expect(report.lengthErrorM, inInclusiveRange(-0.30, 0.0));
      expect(report.isFaithful(toleranceM: 0.30), isTrue);
    });

    test('its parts carry names the renderer can colour', () {
      final mesh = ObjMeshLoader.parse(file.readAsStringSync(),
          materialFor: ObjMeshLoader.materialFromName);
      final parts = mesh.faces.map((f) => f.partId).nonNulls.toSet();
      expect(parts, contains('track'));
      expect(parts, contains('turret'));
      expect(parts, contains('hull'));

      final materials = mesh.faces.map((f) => f.material).toSet();
      expect(materials, contains(SurfaceMaterial.trackLink));
      expect(materials, contains(SurfaceMaterial.turret));
      expect(materials, contains(SurfaceMaterial.hullArmour));
    });

    test('it is small enough for a renderer that fills every face by hand',
        () {
      final mesh = ObjMeshLoader.parse(file.readAsStringSync());
      // The README's preferred Sketchfab candidate is 1 488 faces, and says
      // twenty-four thousand "will work but will feel heavy while orbiting".
      // Greedy meshing keeps this well under that; the ceiling is here so a
      // rebuild at a finer grid cannot quietly make the scene crawl.
      expect(mesh.faces.length, lessThan(4000));
      expect(mesh.faces.length, greaterThan(500));
    });

    test('the track stands on the ground along its whole run', () {
      // The plate draws the lower track run sagging between the road wheels.
      // Read literally that gives a tank with a keel, which rocks on a wagon
      // deck instead of standing on it — and every measurement this scene
      // exists to teach is taken from where it stands. The tool closes the
      // running-gear band downwards; this is that, checked on the artefact.
      final mesh = ObjMeshLoader.parse(file.readAsStringSync());
      final onGround = mesh.faces
          .where((f) => f.vertices.every((v) => v.y.abs() < 0.01))
          .expand((f) => f.vertices)
          .toList();
      expect(onGround, isNotEmpty);
      final xs = onGround.map((v) => v.x);
      final contact = xs.reduce((a, b) => a > b ? a : b) -
          xs.reduce((a, b) => a < b ? a : b);
      expect(contact, greaterThan(TrackedVehicleMeshSpec.t72.hullLengthM * 0.7),
          reason: 'the track should bear over most of the hull, not touch '
              'down only in the middle');
    });
  });
}
