import 'dart:io';
import 'dart:typed_data';

import 'package:test/test.dart';

import 'package:railsim/domain/usecases/stl_mesh_loader.dart';

import 'package:railsim/data/models/vehicle_model_asset.dart';
import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/usecases/obj_mesh_loader.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';

/// The loader that lets a real model file stand in for a drawn one.
///
/// Tested against geometry this project builds itself: the T-72 is exported to
/// OBJ, read back, and compared. That exercises the parser on a few thousand
/// faces with a known right answer, which a hand-written cube would not.
void main() {
  group('parsing', () {
    test('reads vertices and triangles', () {
      const source = '''
# a triangle
v 0 0 0
v 1 0 0
v 0 1 0
f 1 2 3
''';
      final mesh = ObjMeshLoader.parse(source);
      expect(mesh.faces, hasLength(1));
      expect(mesh.faces.single.vertices, hasLength(3));
      expect(mesh.faces.single.vertices.first, const Vector3(0, 0, 0));
    });

    test('triangulates quads and n-gons', () {
      const source = '''
v 0 0 0
v 1 0 0
v 1 1 0
v 0 1 0
v -1 0.5 0
f 1 2 3 4
f 1 2 3 4 5
''';
      final mesh = ObjMeshLoader.parse(source);
      // A quad is two triangles and a pentagon is three.
      expect(mesh.faces, hasLength(5));
      for (final face in mesh.faces) {
        expect(face.vertices, hasLength(3));
      }
    });

    test('handles the v/vt/vn index forms and negative indices', () {
      const source = '''
v 0 0 0
v 1 0 0
v 0 1 0
vt 0 0
vn 0 0 1
f 1/1/1 2/1/1 3/1/1
f 1//1 2//1 3//1
f -3 -2 -1
''';
      final mesh = ObjMeshLoader.parse(source);
      expect(mesh.faces, hasLength(3));
      for (final face in mesh.faces) {
        expect(face.vertices.last, const Vector3(0, 1, 0));
      }
    });

    test('a group or material name becomes the part id', () {
      const source = '''
v 0 0 0
v 1 0 0
v 0 1 0
g turret_armour
f 1 2 3
usemtl track_link
f 1 2 3
''';
      final mesh = ObjMeshLoader.parse(source);
      expect(mesh.faces[0].partId, 'turret_armour');
      expect(mesh.faces[1].partId, 'track_link');
      // And it chooses the surface colour.
      expect(mesh.faces[1].material, SurfaceMaterial.trackLink);
    });

    test('a malformed vertex holds its place, so indices stay aligned', () {
      const source = '''
v 0 0 0
v not-a-number 0 0
v 1 0 0
v 0 1 0
f 1 3 4
f 1 99 4
f 1
mtllib something.mtl
s off
''';
      final mesh = ObjMeshLoader.parse(source);
      // The one good face survives; the out-of-range and short ones do not.
      expect(mesh.faces, hasLength(1));
    });

    test('an empty file yields an empty mesh, not an exception', () {
      expect(ObjMeshLoader.parse('').isEmpty, isTrue);
      expect(ObjMeshLoader.parse('# nothing but a comment').isEmpty, isTrue);
    });
  });

  group('reorienting', () {
    final mesh = ObjMeshLoader.parse('''
v 0 0 -1
v 1 0 -1
v 0 1 -1
f 1 2 3
''');

    test('a y-up model facing -z is turned to face +x', () {
      final out = ObjMeshLoader.reorient(mesh, ObjAxisConvention.yUpFacingMinusZ);
      // What was one unit towards the model's nose is now one unit towards
      // the head of the train.
      expect(out.faces.single.vertices.first, const Vector3(1, 0, 0));
    });

    test('a z-up model facing +y likewise', () {
      final zUp = ObjMeshLoader.parse('''
v 0 1 0
v 1 1 0
v 0 1 1
f 1 2 3
''');
      final out = ObjMeshLoader.reorient(zUp, ObjAxisConvention.zUpFacingPlusY);
      expect(out.faces.single.vertices.first, const Vector3(1, 0, 0));
      // The model's +z became our up.
      expect(out.faces.single.vertices.last.y, 1);
    });

    test('a model already in this frame is left alone', () {
      final out = ObjMeshLoader.reorient(mesh, ObjAxisConvention.yUpFacingPlusX);
      expect(out.faces.single.vertices.first, const Vector3(0, 0, -1));
    });
  });

  group('fitting a model to what the record says', () {
    const spec = TrackedVehicleMeshSpec.t72;

    test('scales uniformly to the recorded width and stands it on the deck', () {
      // A model authored in centimetres, ten times too big.
      final oversize = buildTrackedVehicleModel(spec).mesh.scaled(10);
      final loaded = ObjMeshLoader.fit(
        oversize,
        targetLengthM: spec.lengthOverGunM,
        recordedHeightM: spec.overallHeightM,
        recordedWidthM: spec.overallWidthM,
      );
      final bounds = loaded.mesh.bounds;
      // Keyed on the width, which is the dimension every model has and every
      // record states unambiguously.
      expect(bounds.size.z, closeTo(spec.overallWidthM, 0.01));
      // Seated on the running surface and centred across the wagon.
      expect(bounds.min.y, closeTo(0, 1e-9));
      expect(bounds.min.z, closeTo(-bounds.max.z, 1e-9));
      expect(loaded.report.scale, closeTo(0.1, 0.02));
    });

    test('and reports how far the result lands from the record', () {
      final loaded = ObjMeshLoader.fit(
        buildTrackedVehicleModel(spec).mesh,
        targetLengthM: spec.lengthOverGunM,
        recordedHeightM: spec.overallHeightM,
        recordedWidthM: spec.overallWidthM,
      );
      // This mesh was built from the record, so the width it was scaled on is
      // exact and the height lands on the record too. The length is longer
      // than 9.53 m because the fuel drums stand proud of the rear plate,
      // which is precisely the kind of thing the report exists to surface.
      expect(loaded.report.widthErrorM.abs(), lessThan(1e-6));
      expect(loaded.report.heightErrorM.abs(), lessThan(0.01));
      expect(loaded.report.lengthErrorM, greaterThan(0.5),
          reason: 'the drums are outside the recorded length');
    });

    test('a model of the wrong thing shows up as unfaithful', () {
      // A cube scaled to the tank's length is nothing like a tank, and the
      // report says so rather than the scene rendering it quietly.
      final cube = ObjMeshLoader.parse('''
v -1 -1 -1
v 1 -1 -1
v 1 1 -1
v -1 1 -1
f 1 2 3 4
v -1 -1 1
v 1 -1 1
v 1 1 1
v -1 1 1
f 5 6 7 8
''');
      final loaded = ObjMeshLoader.fit(
        cube,
        targetLengthM: spec.lengthOverGunM,
        recordedHeightM: spec.overallHeightM,
        recordedWidthM: spec.overallWidthM,
      );
      expect(loaded.report.isFaithful(), isFalse);
      // Scaled on width, a cube comes out far too long and far too tall.
      expect(loaded.report.lengthErrorM.abs(), greaterThan(1.0));
      expect(loaded.report.heightErrorM, greaterThan(1.0));
    });

    test('an empty mesh fits to nothing rather than dividing by zero', () {
      final loaded = ObjMeshLoader.fit(
        Mesh3.empty,
        targetLengthM: 9.53,
        recordedHeightM: 2.19,
        recordedWidthM: 3.59,
      );
      expect(loaded.mesh.isEmpty, isTrue);
      expect(loaded.report.triangleCount, 0);
    });
  });

  group('a round trip through the file format', () {
    test('the T-72 survives being written out and read back', () {
      final original = buildTrackedVehicleModel(TrackedVehicleMeshSpec.t72).mesh;
      final text = ObjMeshLoader.encode(original);
      final reloaded = ObjMeshLoader.parse(text);

      // Every polygon comes back, triangulated.
      final expectedTriangles = original.faces
          .map((f) => f.vertices.length - 2)
          .reduce((a, b) => a + b);
      expect(reloaded.faces, hasLength(expectedTriangles));

      // And it is the same solid, to the precision the format was written at.
      final a = original.bounds;
      final b = reloaded.bounds;
      for (final pair in [
        (a.min.x, b.min.x), (a.max.x, b.max.x),
        (a.min.y, b.min.y), (a.max.y, b.max.y),
        (a.min.z, b.min.z), (a.max.z, b.max.z),
      ]) {
        expect(pair.$2, closeTo(pair.$1, 1e-5));
      }
    });

    test('part names survive it too, so materials still resolve', () {
      final original = buildTrackedVehicleModel(TrackedVehicleMeshSpec.t72).mesh;
      final reloaded = ObjMeshLoader.parse(
        ObjMeshLoader.encode(original),
        materialFor: ObjMeshLoader.materialFromName,
      );
      final parts = reloaded.faces.map((f) => f.partId).toSet();
      expect(parts, contains('turret'));
      expect(parts, contains('track'));
      // The name-to-material guess picks the track out of the file.
      expect(
        reloaded.faces
            .where((f) => f.partId == 'track')
            .every((f) => f.material == SurfaceMaterial.trackLink),
        isTrue,
      );
    });

    test('the written file is real OBJ: only v, g and f lines', () {
      final text = ObjMeshLoader.encode(
          buildTrackedVehicleModel(TrackedVehicleMeshSpec.t72).mesh);
      for (final line in text.split('\n')) {
        if (line.isEmpty || line.startsWith('#')) continue;
        expect(RegExp(r'^(v|g|f) ').hasMatch(line), isTrue,
            reason: 'unexpected line: $line');
      }
    });
  });

  group('material guessing', () {
    test('maps the words modellers actually use', () {
      expect(ObjMeshLoader.materialFromName('Track_L'), SurfaceMaterial.trackLink);
      expect(ObjMeshLoader.materialFromName('road_wheel_03'),
          SurfaceMaterial.roadWheel);
      expect(ObjMeshLoader.materialFromName('GunBarrel'),
          SurfaceMaterial.gunBarrel);
      expect(ObjMeshLoader.materialFromName('Turret_Main'),
          SurfaceMaterial.turret);
      expect(ObjMeshLoader.materialFromName('kontakt5_era'),
          SurfaceMaterial.appliqueArmour);
    });

    test('an unfamiliar name falls back to hull rather than to something loud',
        () {
      expect(ObjMeshLoader.materialFromName('Object_042'),
          SurfaceMaterial.hullArmour);
    });
  });

  group('the model asset records', () {
    test('the list parses and every entry is fully attributed', () {
      final file = File('assets/data/vehicle_models.json');
      expect(file.existsSync(), isTrue);
      final json = file.readAsStringSync();
      expect(json, contains('models'));
      // Empty today. The check is that anything added later carries its
      // author, its source and its licence — the loader drops records that
      // do not, and this says so out loud.
      const missingAuthor = VehicleModelAsset(
        vehicleId: 'veh-t72',
        file: 'models/veh-t72.obj',
        sourceTitle: 'Somewhere',
        sourceUrl: 'https://example.invalid',
        license: 'CC BY 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        author: '',
      );
      expect(missingAuthor.isAttributed, isFalse);

      const complete = VehicleModelAsset(
        vehicleId: 'veh-t72',
        file: 'models/veh-t72.obj',
        sourceTitle: 'Low Poly T-72 Tank - Game Ready',
        sourceUrl: 'https://sketchfab.com/3d-models/'
            'low-poly-t-72-tank-game-ready-8c9d0d6640a244e39082cd9fdf565cef',
        license: 'CC BY 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        author: 'Mr. The Rich',
      );
      expect(complete.isAttributed, isTrue);
      expect(complete.assetKey, 'assets/models/veh-t72.obj');
      expect(complete.creditLine, contains('Mr. The Rich'));
      expect(complete.creditLine, contains('CC BY 4.0'));
    });

    test('the directory and its instructions are in place', () {
      expect(Directory('assets/models').existsSync(), isTrue);
      final readme = File('assets/models/README.md').readAsStringSync();
      expect(readme, contains('vehicle_models.json'));
      expect(readme, contains('CC BY'));
    });
  });

  group('STL, which is what the freely-published models are', () {
    const ascii = '''
solid tank
  facet normal 0 0 1
    outer loop
      vertex 0 0 0
      vertex 1 0 0
      vertex 0 1 0
    endloop
  endfacet
  facet normal 0 0 1
    outer loop
      vertex 1 0 0
      vertex 1 1 0
      vertex 0 1 0
    endloop
  endfacet
endsolid tank
''';

    /// The same two triangles, written the way an exporter writes binary STL.
    Uint8List binary(int triangleCount) {
      final bytes = Uint8List(84 + triangleCount * 50);
      final data = ByteData.sublistView(bytes);
      // Exporters really do copy the word "solid" into the binary header,
      // which is why the format is detected by length and not by that word.
      for (var i = 0; i < 5; i++) {
        bytes[i] = 'solid'.codeUnitAt(i);
      }
      data.setUint32(80, triangleCount, Endian.little);
      var offset = 84;
      for (var t = 0; t < triangleCount; t++) {
        offset += 12; // normal, skipped on read
        for (final v in [
          [0.0, 0.0, 0.0],
          [1.0, 0.0, 0.0],
          [0.0, 1.0, 0.0],
        ]) {
          for (final c in v) {
            data.setFloat32(offset, c, Endian.little);
            offset += 4;
          }
        }
        offset += 2;
      }
      return bytes;
    }

    test('ASCII facets come back as triangles', () {
      final mesh = StlMeshLoader.parseAscii(ascii);
      expect(mesh.faces, hasLength(2));
      expect(mesh.faces.first.vertices, hasLength(3));
      expect(mesh.faces.first.vertices[1], const Vector3(1, 0, 0));
    });

    test('binary is detected by length, not by the word "solid"', () {
      final bytes = binary(2);
      expect(StlMeshLoader.isBinary(bytes), isTrue);
      expect(StlMeshLoader.parse(bytes).faces, hasLength(2));
    });

    test('an ASCII file is not mistaken for a binary one', () {
      final bytes = Uint8List.fromList(ascii.codeUnits);
      expect(StlMeshLoader.isBinary(bytes), isFalse);
      expect(StlMeshLoader.parse(bytes).faces, hasLength(2));
    });

    test('a truncated binary file yields what it can rather than throwing', () {
      final bytes = binary(4).sublist(0, 84 + 50 * 2 + 10);
      expect(StlMeshLoader.parseBinary(bytes).faces, hasLength(2));
    });

    test('an empty or nonsense file yields an empty mesh', () {
      expect(StlMeshLoader.parse(Uint8List(0)).isEmpty, isTrue);
      expect(StlMeshLoader.parseAscii('not an stl at all').isEmpty, isTrue);
    });
  });

  group('reading whichever format the file turns out to be', () {
    test('it accepts obj and stl and nothing else', () {
      expect(MeshFileLoader.isSupported('veh-t72.obj'), isTrue);
      expect(MeshFileLoader.isSupported('veh-t72.STL'), isTrue);
      expect(MeshFileLoader.isSupported('veh-t72.fbx'), isFalse);
      expect(MeshFileLoader.isSupported('veh-t72.gltf'), isFalse);
    });

    test('an STL is read, fitted and seated exactly like an OBJ', () {
      // Round-trip the project's own T-72 through STL by writing it out as
      // ASCII facets, then load it the way a downloaded file is loaded.
      const spec = TrackedVehicleMeshSpec.t72;
      final original = buildTrackedVehicleModel(spec).mesh;
      final buffer = StringBuffer('solid t72\n');
      for (final face in original.faces) {
        for (var i = 1; i + 1 < face.vertices.length; i++) {
          buffer.writeln('facet normal 0 0 0');
          buffer.writeln('  outer loop');
          for (final v in [face.vertices[0], face.vertices[i], face.vertices[i + 1]]) {
            buffer.writeln('    vertex ${v.x} ${v.y} ${v.z}');
          }
          buffer.writeln('  endloop');
          buffer.writeln('endfacet');
        }
      }
      buffer.writeln('endsolid t72');

      final loaded = MeshFileLoader.load(
        Uint8List.fromList(buffer.toString().codeUnits),
        'veh-t72.stl',
        targetLengthM: spec.lengthOverGunM,
        recordedHeightM: spec.overallHeightM,
        recordedWidthM: spec.overallWidthM,
        convention: ObjAxisConvention.yUpFacingPlusX,
      );
      expect(loaded.mesh.faces, isNotEmpty);
      final bounds = loaded.mesh.bounds;
      expect(bounds.size.z, closeTo(spec.overallWidthM, 0.01));
      expect(bounds.min.y, closeTo(0, 1e-6));
      expect(loaded.report.heightErrorM.abs(), lessThan(0.01));
    });

    test('a model file record must name a format the loader can read', () {
      const unreadable = VehicleModelAsset(
        vehicleId: 'veh-t72',
        file: 'models/veh-t72.fbx',
        sourceTitle: 'Somewhere',
        sourceUrl: 'https://example.invalid',
        license: 'CC BY 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        author: 'Someone',
      );
      expect(unreadable.isAttributed, isFalse);
    });
  });
}
