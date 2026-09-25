import 'dart:math' as math;

import 'package:test/test.dart';

import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/mesh_primitives.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/securing_layout_builder.dart';
import 'package:railsim/domain/usecases/securing_mesh_builder.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';

/// Every face of a closed solid must face away from the inside of it. The
/// renderer culls back faces, so one reversed winding is not a shading
/// artefact — it is a hole straight through the model, and on a scene made of
/// hundreds of faces it is very hard to spot by eye afterwards. These tests
/// hold each primitive to the contract [Face3] states.
void expectOutwardNormals(Mesh3 mesh, Vector3 inside, {String? reason}) {
  for (var i = 0; i < mesh.faces.length; i++) {
    final face = mesh.faces[i];
    final outward = face.centroid - inside;
    expect(face.normal.dot(outward), greaterThan(0),
        reason: '${reason ?? 'face'} $i is wound inside-out');
  }
}

void main() {
  group('vector algebra', () {
    test('cross product is right-handed', () {
      final z = const Vector3(1, 0, 0).cross(const Vector3(0, 1, 0));
      expect(z.x, closeTo(0, 1e-12));
      expect(z.y, closeTo(0, 1e-12));
      expect(z.z, closeTo(1, 1e-12));
    });

    test('a zero-length vector normalises to zero rather than to NaN', () {
      // A degenerate face must not poison the depth sort with NaNs.
      expect(Vector3.zero.normalized, Vector3.zero);
    });
  });

  group('primitives are wound outwards', () {
    test('box', () {
      final mesh = MeshPrimitives.box(
        corner: const Vector3(-1, -2, -3),
        opposite: const Vector3(4, 5, 6),
        material: SurfaceMaterial.hullArmour,
      );
      expect(mesh.faces, hasLength(6));
      expectOutwardNormals(mesh, const Vector3(1.5, 1.5, 1.5), reason: 'box');
    });

    test('box accepts its corners in either order', () {
      final a = MeshPrimitives.box(
        corner: const Vector3(4, 5, 6),
        opposite: const Vector3(-1, -2, -3),
        material: SurfaceMaterial.hullArmour,
      );
      expectOutwardNormals(a, const Vector3(1.5, 1.5, 1.5), reason: 'reversed box');
    });

    test('extrusion, whichever way round the profile is listed', () {
      final ccw = [p2(-1, -1), p2(1, -1), p2(1, 1), p2(-1, 1)];
      for (final profile in [ccw, ccw.reversed.toList()]) {
        final mesh = MeshPrimitives.extrudeZ(
          profile,
          zMin: -0.5,
          zMax: 0.5,
          material: SurfaceMaterial.hullArmour,
        );
        expect(mesh.faces, hasLength(6));
        expectOutwardNormals(mesh, Vector3.zero, reason: 'extrusion');
      }
    });

    test('a concave profile still extrudes with its sides facing out', () {
      // An L-shape. Concave caps are allowed — Newell's normal handles them —
      // and the side walls must still face away from the material.
      final mesh = MeshPrimitives.extrudeZ(
        [p2(0, 0), p2(2, 0), p2(2, 1), p2(1, 1), p2(1, 2), p2(0, 2)],
        zMin: 0,
        zMax: 1,
        material: SurfaceMaterial.hullArmour,
      );
      // The point (0.5, 0.5) is inside the solid part of the L for every
      // side wall, which is what the side normals are checked against.
      for (final face in mesh.faces.take(6)) {
        expect(face.normal.dot(face.centroid - const Vector3(0.5, 0.5, 0.5)),
            greaterThan(0));
      }
    });

    test('cylinder', () {
      final mesh = MeshPrimitives.cylinderZ(
        center: const Vector3(2, 3, 4),
        radius: 0.5,
        length: 1.2,
        material: SurfaceMaterial.roadWheel,
        segments: 12,
      );
      expectOutwardNormals(mesh, const Vector3(2, 3, 4), reason: 'cylinder');
    });

    test('loft', () {
      final bottom = [
        const Vector3(-1, 0, -1),
        const Vector3(1, 0, -1),
        const Vector3(1, 0, 1),
        const Vector3(-1, 0, 1),
      ];
      final top = [for (final v in bottom) Vector3(v.x * 0.6, 1, v.z * 0.6)];
      final mesh = MeshPrimitives.loft(bottom, top, material: SurfaceMaterial.turret);
      expectOutwardNormals(mesh, const Vector3(0, 0.5, 0), reason: 'loft');
    });

    test('loft normalises rings given clockwise from above', () {
      final bottom = [
        const Vector3(-1, 0, -1),
        const Vector3(1, 0, -1),
        const Vector3(1, 0, 1),
        const Vector3(-1, 0, 1),
      ];
      final mesh = MeshPrimitives.loft(
        bottom.reversed.toList(),
        [for (final v in bottom.reversed) Vector3(v.x * 0.6, 1, v.z * 0.6)],
        material: SurfaceMaterial.turret,
      );
      expectOutwardNormals(mesh, const Vector3(0, 0.5, 0), reason: 'reversed loft');
    });

    test('a rod spans exactly the two points it is given', () {
      final mesh = MeshPrimitives.rod(
        a: const Vector3(0, 0, 0),
        b: const Vector3(3, 4, 0),
        radius: 0.1,
        material: SurfaceMaterial.wireLashing,
      );
      final bounds = mesh.bounds;
      expect(bounds.min.x, closeTo(-0.08, 0.05));
      expect(bounds.max.x, closeTo(3.08, 0.05));
      expect(bounds.max.y, closeTo(4.06, 0.05));
    });

    test('a zero-length rod produces nothing rather than a degenerate solid', () {
      final mesh = MeshPrimitives.rod(
        a: const Vector3(1, 1, 1),
        b: const Vector3(1, 1, 1),
        radius: 0.1,
        material: SurfaceMaterial.wireLashing,
      );
      expect(mesh.isEmpty, isTrue);
    });

    test('mirroring keeps the mirrored half facing outwards', () {
      final right = MeshPrimitives.box(
        corner: const Vector3(-1, 0, 1),
        opposite: const Vector3(1, 1, 2),
        material: SurfaceMaterial.trackLink,
      );
      expectOutwardNormals(right.mirroredZ(), const Vector3(0, 0.5, -1.5),
          reason: 'mirrored box');
    });

    test('rotating about the vertical axis preserves outward normals', () {
      final mesh = MeshPrimitives.box(
        corner: const Vector3(-1, -1, -1),
        opposite: const Vector3(1, 1, 1),
        material: SurfaceMaterial.turret,
      ).rotatedY(math.pi / 3);
      expectOutwardNormals(mesh, Vector3.zero, reason: 'rotated box');
    });

    test('rotationAligning takes one direction onto the other', () {
      for (final target in const [
        Vector3(1, 0, 0),
        Vector3(0, 1, 0),
        Vector3(0, 0, -1), // the exactly-opposed case
        Vector3(0.3, -0.8, 0.5),
      ]) {
        final rotate = MeshPrimitives.rotationAligning(const Vector3(0, 0, 1), target);
        final got = rotate(const Vector3(0, 0, 1));
        final want = target.normalized;
        expect(got.x, closeTo(want.x, 1e-9));
        expect(got.y, closeTo(want.y, 1e-9));
        expect(got.z, closeTo(want.z, 1e-9));
      }
    });
  });

  group('camera', () {
    const camera = Camera3(target: Vector3.zero, yaw: 0, pitch: 0, distance: 10);

    test('the point it is aimed at lands in the middle of the viewport', () {
      final p = SceneProjection.project(Vector3.zero,
          camera: camera, width: 800, height: 400);
      expect(p, isNotNull);
      expect(p!.x, closeTo(400, 1e-6));
      expect(p.y, closeTo(200, 1e-6));
    });

    test('higher in the world is higher on the screen', () {
      final low = SceneProjection.project(const Vector3(0, 0, 0),
          camera: camera, width: 800, height: 400)!;
      final high = SceneProjection.project(const Vector3(0, 1, 0),
          camera: camera, width: 800, height: 400)!;
      expect(high.y, lessThan(low.y));
    });

    test('a point behind the lens is dropped, not flung across the viewport', () {
      final behind = SceneProjection.project(const Vector3(0, 0, 40),
          camera: camera, width: 800, height: 400);
      expect(behind, isNull);
    });

    test('faces come back sorted farthest first', () {
      final near = MeshPrimitives.box(
        corner: const Vector3(-1, -1, 2),
        opposite: const Vector3(1, 1, 3),
        material: SurfaceMaterial.hullArmour,
      );
      final far = MeshPrimitives.box(
        corner: const Vector3(-1, -1, -3),
        opposite: const Vector3(1, 1, -2),
        material: SurfaceMaterial.hullArmour,
      );
      final faces = SceneProjection.render(near + far,
          camera: camera, width: 400, height: 200);
      expect(faces, isNotEmpty);
      for (var i = 1; i < faces.length; i++) {
        expect(faces[i].depth, lessThanOrEqualTo(faces[i - 1].depth));
      }
    });

    test('back faces are culled, halving what is drawn for a closed box', () {
      final box = MeshPrimitives.box(
        corner: const Vector3(-1, -1, -1),
        opposite: const Vector3(1, 1, 1),
        material: SurfaceMaterial.hullArmour,
      );
      final culled = SceneProjection.render(box,
          camera: camera, width: 400, height: 200);
      final all = SceneProjection.render(box,
          camera: camera, width: 400, height: 200, cullBackFaces: false);
      expect(culled.length, lessThan(all.length));
      expect(all, hasLength(6));
    });

    test('framing a body keeps all of it in front of the lens at any angle', () {
      final mesh = MeshPrimitives.box(
        corner: const Vector3(-7, 0, -1.5),
        opposite: const Vector3(7, 3, 1.5),
        material: SurfaceMaterial.deckPlank,
      );
      for (final yaw in [0.0, 0.8, 1.9, 3.0, -1.2]) {
        final cam = Camera3.framing(mesh.bounds, yaw: yaw, aspectRatio: 2.4);
        final faces =
            SceneProjection.render(mesh, camera: cam, width: 960, height: 400);
        expect(faces, isNotEmpty, reason: 'nothing visible at yaw $yaw');
      }
    });
  });

  group('T-90S model', () {
    final model = buildTrackedVehicleModel(TrackedVehicleMeshSpec.t90s);
    final bounds = model.mesh.bounds;

    test('stands on the ground plane', () {
      // y = 0 is the running surface. A vehicle floating above it, or sunk
      // into it, would make every height in the scene wrong.
      expect(bounds.min.y, closeTo(0, 0.02));
    });

    test('is exactly as tall as the specification says', () {
      // 2.23 m to the turret roof. The scene reports this as the load's
      // height above the rail, so the model must not be quietly taller.
      expect(bounds.max.y, closeTo(TrackedVehicleMeshSpec.t90s.overallHeightM, 0.01));
    });

    test('is exactly as wide as the specification says, over the skirts', () {
      expect(bounds.size.z, closeTo(TrackedVehicleMeshSpec.t90s.overallWidthM, 0.01));
    });

    test('the gun reaches the specified overhang past the nose', () {
      // The origin is the centre of the *hull*, so the muzzle stands at half
      // the hull length plus the overhang — 3.43 m + 2.67 m.
      const spec = TrackedVehicleMeshSpec.t90s;
      expect(bounds.max.x, closeTo(spec.halfLength + spec.gunOverhangM, 0.02));
      // And the model is therefore the published 9.53 m long over the gun,
      // measured from the nose rather than from the fuel drums on the rear.
      expect(bounds.max.x + spec.halfLength, closeTo(spec.lengthOverGunM, 0.02));
    });

    test('traversing the turret to the rear takes the gun off the nose', () {
      final reversed = buildTrackedVehicleModel(TrackedVehicleMeshSpec.t90s,
          turretTraverse: math.pi);
      expect(reversed.gunReachX, lessThan(0));
      expect(reversed.mesh.bounds.max.x,
          lessThan(model.mesh.bounds.max.x - 2.0));
      // It has to go somewhere: what leaves the front appears at the rear.
      expect(reversed.mesh.bounds.min.x, lessThan(model.mesh.bounds.min.x));
    });

    test('both tracks are drawn, symmetrically about the centre line', () {
      expect(model.trackCenterZ, greaterThan(0));
      final trackFaces =
          model.mesh.faces.where((f) => f.partId == 'track').toList();
      expect(trackFaces, isNotEmpty);
      final left = trackFaces.where((f) => f.centroid.z < 0).length;
      final right = trackFaces.where((f) => f.centroid.z > 0).length;
      expect(left, right);
    });

    test('has four lashing eyes, at the nose and the rear plate', () {
      expect(model.lashingEyes, hasLength(4));
      expect(model.lashingEyes.where((e) => e.x > 0), hasLength(2));
      expect(model.lashingEyes.where((e) => e.x < 0), hasLength(2));
    });
  });

  group('the flatcar', () {
    test('its deck sits at the stated height above the rail head', () {
      final model = buildFlatcarModel(FlatcarMeshSpec.standardFourAxle);
      expect(model.deckTopY,
          closeTo(FlatcarMeshSpec.standardFourAxle.deckHeightM, 1e-9));
      // The wheels reach down to the rail head and no further.
      expect(model.mesh.bounds.min.y, closeTo(0, 0.02));
    });

    test('a platform record\'s own figures replace the default ones', () {
      final spec = FlatcarMeshSpec.fromPlatformFigures(
          lengthCm: 1400, widthCm: 300, deckHeightCm: 125);
      expect(spec.deckLengthM, closeTo(14.0, 1e-9));
      expect(spec.deckWidthM, closeTo(3.0, 1e-9));
      expect(spec.deckHeightM, closeTo(1.25, 1e-9));
      expect(spec.isDefaultGeometry, isFalse);
    });

    test('with nothing supplied it says so, rather than pretending', () {
      expect(FlatcarMeshSpec.fromPlatformFigures().isDefaultGeometry, isTrue);
    });

    test('its long parts are cut into segments, so the load sorts over them', () {
      // The renderer sorts faces by the distance from the eye to the face
      // centre. As one 13-metre box, a deck plank has its centre over the
      // middle of the wagon, and a bogie standing at the near end sorted in
      // front of it and printed a black bar across the planking. Anyone
      // tempted to collapse these back into single boxes will fail here
      // rather than in a screenshot.
      final model = buildFlatcarModel(FlatcarMeshSpec.standardFourAxle);
      for (final part in ['wagon.deck', 'wagon.sill', 'wagon.bogie']) {
        final centres = model.mesh.faces
            .where((f) => f.partId == part)
            .map((f) => f.centroid.x.toStringAsFixed(2))
            .toSet();
        expect(centres.length, greaterThan(3),
            reason: '$part is not segmented along the wagon');
      }
    });

    test('nothing under the deck shares a plane with the planking', () {
      // Two coplanar surfaces have no stable draw order and flicker against
      // each other along the whole train.
      const spec = FlatcarMeshSpec.standardFourAxle;
      final model = buildFlatcarModel(spec);
      final plankBottom = spec.deckTopY - spec.deckThicknessM;
      for (final face in model.mesh.faces) {
        if (face.partId == 'wagon.deck') continue;
        final ys = face.vertices.map((v) => v.y);
        final top = ys.reduce((a, b) => a > b ? a : b);
        expect((top - plankBottom).abs() > 0.02 || top > spec.deckTopY, isTrue,
            reason: '${face.partId} tops out flush with the underside of the deck');
      }
    });

    test('has rings down both sides to lash to', () {
      final model = buildFlatcarModel(FlatcarMeshSpec.standardFourAxle);
      expect(model.tieDownRings.where((r) => r.z > 0), isNotEmpty);
      expect(model.tieDownRings.where((r) => r.z < 0), isNotEmpty);
      for (final ring in model.tieDownRings) {
        expect(ring.y, closeTo(model.deckTopY, 1e-9));
      }
    });
  });

  group('the loaded wagon', () {
    /// The handbook arrangement for a given block size, which is what the
    /// view starts the trainee off with. A null size means Table 3 resolves
    /// none, and no blocks are laid out.
    SecuringLayout arrangement({
      double position = 0.5,
      double? chockHeightM,
      double? chockWidthM,
      int blocksPerTrackEnd = 1,
      int lashingRuns = 4,
    }) {
      final geometry = resolveLoadingGeometry(
        vehicleSpec: TrackedVehicleMeshSpec.t90s,
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
        positionFraction: position,
      );
      return SecuringLayoutBuilder.handbookArrangement(
        vehicle: geometry.vehicle,
        flatcar: geometry.flatcar,
        vehicleOffsetX: geometry.vehicleOffsetX,
        chockHeightM: chockHeightM,
        chockWidthM: chockWidthM,
        blocksPerTrackEnd: blocksPerTrackEnd,
        lashingRuns: lashingRuns,
      );
    }

    LoadingScene3 scene({
      double position = 0.5,
      double traverse = 0,
      SecuringLayout? securing,
    }) =>
        buildLoadingScene(
          vehicleSpec: TrackedVehicleMeshSpec.t90s,
          flatcarSpec: FlatcarMeshSpec.standardFourAxle,
          positionFraction: position,
          turretTraverse: traverse,
          securing: securing ?? arrangement(position: position),
        );

    test('the vehicle stands on the deck, not through it and not above it', () {
      final s = scene();
      expect(s.loadBounds.min.y, closeTo(s.flatcar.deckTopY, 0.02));
    });

    test('the load height above the rail is the deck plus the vehicle', () {
      final s = scene();
      expect(
        s.clearances.loadTopAboveRailM,
        closeTo(FlatcarMeshSpec.standardFourAxle.deckHeightM +
            TrackedVehicleMeshSpec.t90s.overallHeightM, 0.02),
      );
    });

    test('centred on a 13.3 m deck, a T-90S overhangs neither end', () {
      final s = scene(position: 0.5);
      expect(s.clearances.frontOverhangM, 0);
      expect(s.clearances.rearOverhangM, 0);
      expect(s.clearances.freeDeckLengthM, greaterThan(0));
    });

    test('run hard against one end with the gun forward, it overhangs', () {
      // This is the case the view exists to show: the hull fits, the gun does
      // not, and the trainee can see it happen.
      final s = scene(position: 1.0);
      expect(s.clearances.frontOverhangM, greaterThan(0.5));
      expect(s.clearances.rearOverhangM, 0);
    });

    test('traversing the gun over the rear deck takes the overhang away', () {
      final forward = scene(position: 1.0);
      final reversed = scene(position: 1.0, traverse: math.pi);
      expect(reversed.clearances.frontOverhangM,
          lessThan(forward.clearances.frontOverhangM));
    });

    test('sliding the vehicle moves it along the deck and nowhere else', () {
      final rear = scene(position: 0.0);
      final front = scene(position: 1.0);
      expect(front.vehicleOffsetX, greaterThan(rear.vehicleOffsetX));
      expect(front.loadBounds.min.y, closeTo(rear.loadBounds.min.y, 1e-9));
      expect(front.loadBounds.size.z, closeTo(rear.loadBounds.size.z, 1e-9));
    });

    test('the T-90S is wider than the deck, and the figure is reported', () {
      // 3.78 m over the skirts against a 2.87 m deck: the machine overhangs
      // the wagon sideways, which is a real and visible fact about this load.
      final s = scene();
      expect(s.clearances.lateralOverhangM, greaterThan(0.4));
    });

    test('no chock size supplied means no blocks are laid out', () {
      // The handbook sizes stop blocks; inventing one to make the picture look
      // finished is exactly what this project does not do.
      final s = scene(securing: arrangement());
      expect(s.securing.blockCount, 0);
      expect(s.layout.blocks, isEmpty);
    });

    test('given a size, a block goes at each end of each track', () {
      final s = scene(
          securing: arrangement(chockHeightM: 0.16, chockWidthM: 0.35));
      expect(s.securing.blockCount, 4);
      expect(s.securing.mesh.isEmpty, isFalse);
    });

    test('doubled blocks double the count', () {
      final s = scene(
        securing: arrangement(
            chockHeightM: 0.16, chockWidthM: 0.35, blocksPerTrackEnd: 2),
      );
      expect(s.securing.blockCount, 8);
    });

    test('every lashing run ends on a ring of the wagon it is lashed to', () {
      final s = scene(securing: arrangement());
      expect(s.securing.lashingRunCount, 4);
      for (final wire in s.layout.lashings) {
        expect(wire.ringIndex, isNotNull);
        expect(wire.ringIndex, lessThan(s.flatcar.tieDownRings.length));
      }
      final wireFaces = s.securing.mesh.faces
          .where((f) => pieceOfPart(f.partId)?.startsWith('wireLashing') ?? false);
      expect(wireFaces, isNotEmpty);
      final lowest =
          wireFaces.map((f) => f.centroid.y).reduce((a, b) => a < b ? a : b);
      // Wires reach down to deck level and not below it.
      expect(lowest, greaterThan(s.flatcar.deckTopY - 0.1));
    });

    test('a layout of blocks alone draws no wires', () {
      final full = arrangement(chockHeightM: 0.16, chockWidthM: 0.35);
      final s = scene(securing: SecuringLayout([...full.blocks]));
      expect(s.securing.lashingRunCount, 0);
      expect(s.securing.blockCount, 4);
    });

    test('the whole scene renders to sorted screen polygons', () {
      final s = scene(
          securing: arrangement(chockHeightM: 0.16, chockWidthM: 0.35));
      final camera = Camera3.framing(s.mesh.bounds, aspectRatio: 2.4);
      final faces = SceneProjection.render(s.mesh,
          camera: camera, width: 960, height: 400);
      expect(faces.length, greaterThan(200));
      for (final f in faces) {
        // A multiplier per channel now, so a lit face can read warm and a
        // shaded one cool at the same brightness. Each still has to stay a
        // multiplier: above 1 would blow the material's colour out.
        expect(f.shade.r, inInclusiveRange(0.0, 1.0));
        expect(f.shade.g, inInclusiveRange(0.0, 1.0));
        expect(f.shade.b, inInclusiveRange(0.0, 1.0));
        for (final p in f.points) {
          expect(p.x.isFinite, isTrue);
          expect(p.y.isFinite, isTrue);
        }
      }
    });
  });
}
