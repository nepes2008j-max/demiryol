import 'dart:typed_data';

import '../models/scene3d.dart';

/// Reads STL geometry, in both the forms the format comes in.
///
/// Added because of where a free model of a real vehicle actually comes from.
/// The sites that publish game-ready OBJ gate the file behind an account; the
/// ones that publish freely are 3D-printing sites, and those are STL. A loader
/// that could only read OBJ would have met most downloads with a shrug.
///
/// STL carries triangles and nothing else — no groups, no material names — so
/// every face comes back as one material. That is a real loss against OBJ (the
/// tracks cannot be told from the hull) and the reason [ObjMeshLoader] stays
/// the preferred format. It is not a reason to refuse the file.
class StlMeshLoader {
  StlMeshLoader._();

  /// Reads either form, deciding which from the bytes themselves.
  static Mesh3 parse(
    Uint8List bytes, {
    SurfaceMaterial material = SurfaceMaterial.hullArmour,
    String partId = 'model',
  }) =>
      isBinary(bytes)
          ? parseBinary(bytes, material: material, partId: partId)
          : parseAscii(String.fromCharCodes(bytes),
              material: material, partId: partId);

  /// True for binary STL.
  ///
  /// The header is not a reliable marker — plenty of binary files begin with
  /// the word `solid`, because exporters copy the ASCII header into it — so
  /// the length is checked instead: a binary file is exactly 84 bytes of
  /// preamble plus 50 per triangle, and nothing else lands on that number by
  /// accident.
  static bool isBinary(Uint8List bytes) {
    if (bytes.length < 84) return false;
    final count = ByteData.sublistView(bytes, 80, 84).getUint32(0, Endian.little);
    return bytes.length == 84 + count * 50;
  }

  static Mesh3 parseBinary(
    Uint8List bytes, {
    SurfaceMaterial material = SurfaceMaterial.hullArmour,
    String partId = 'model',
  }) {
    if (bytes.length < 84) return Mesh3.empty;
    final data = ByteData.sublistView(bytes);
    final count = data.getUint32(80, Endian.little);
    final faces = <Face3>[];
    var offset = 84;
    for (var i = 0; i < count; i++) {
      if (offset + 50 > bytes.length) break;
      // The stored normal is skipped: this renderer computes its own from the
      // winding, and an exporter's normals are not always consistent with it.
      offset += 12;
      final corners = <Vector3>[];
      for (var c = 0; c < 3; c++) {
        corners.add(Vector3(
          data.getFloat32(offset, Endian.little),
          data.getFloat32(offset + 4, Endian.little),
          data.getFloat32(offset + 8, Endian.little),
        ));
        offset += 12;
      }
      offset += 2; // attribute byte count
      faces.add(Face3(corners, material: material, partId: partId));
    }
    return Mesh3(faces);
  }

  static Mesh3 parseAscii(
    String source, {
    SurfaceMaterial material = SurfaceMaterial.hullArmour,
    String partId = 'model',
  }) {
    final faces = <Face3>[];
    var corners = <Vector3>[];
    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (!line.startsWith('vertex')) {
        if (line.startsWith('endfacet')) {
          if (corners.length >= 3) {
            // Fan-triangulate, for the rare exporter that writes more than
            // three vertices to a facet.
            for (var i = 1; i + 1 < corners.length; i++) {
              faces.add(Face3([corners[0], corners[i], corners[i + 1]],
                  material: material, partId: partId));
            }
          }
          corners = <Vector3>[];
        }
        continue;
      }
      final parts = line.split(RegExp(r'\s+'));
      if (parts.length < 4) continue;
      final x = double.tryParse(parts[1]);
      final y = double.tryParse(parts[2]);
      final z = double.tryParse(parts[3]);
      if (x == null || y == null || z == null) continue;
      corners.add(Vector3(x, y, z));
    }
    return Mesh3(faces);
  }
}
