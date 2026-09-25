import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import '../models/scene3d.dart';
import 'stl_mesh_loader.dart';

/// How a loaded model's own axes map onto this project's world frame.
///
/// Every modelling package disagrees about which way is up and which way is
/// forward: Blender exports z-up, most game engines are y-up, and a model may
/// have been built nose-first along any axis. Rather than guess, the caller
/// states the convention the file was authored in and the loader rotates it
/// once, on load.
enum ObjAxisConvention {
  /// y up, model facing `-z` — the glTF/game-engine default.
  yUpFacingMinusZ,

  /// y up, model already facing `+x`, which is this project's forward.
  yUpFacingPlusX,

  /// z up, model facing `+y` — Blender's default export.
  zUpFacingPlusY,
}

/// Which recorded dimension a loaded mesh is scaled to match.
enum ObjFitAxis {
  /// Across the vehicle at its widest — the default, and the most stable: it
  /// is the tracks or the fenders, which every model has.
  width,

  /// Along the vehicle. Depends on where the gun is trained and on how much
  /// stowage the modeller hung off the rear plate.
  length,

  /// Vertically. Depends on whether the modeller included an aerial or an
  /// anti-aircraft mount above the turret roof.
  height,
}

/// What fitting a loaded mesh to a vehicle's record actually did.
///
/// Reported rather than swallowed. A downloaded mesh is modelled to *look*
/// right, not to *measure* right, and this scene's whole purpose is that load
/// height and overhang are readings off a measured object. So the mesh is
/// scaled to the length the record states, and the residual disagreement in
/// the other two dimensions is handed back — if a model comes out 12 cm too
/// tall for the recorded height, that is something the person who added it
/// has to see, not something the application should quietly render.
class ObjFitReport {
  /// The uniform scale factor applied.
  final double scale;

  /// The model's height after fitting, less the height the record states.
  /// Positive means the mesh is taller than the vehicle is recorded to be.
  final double heightErrorM;

  /// The same for the width over the widest point.
  final double widthErrorM;

  /// The same for the overall length.
  final double lengthErrorM;

  /// Triangles in the fitted mesh.
  final int triangleCount;

  const ObjFitReport({
    required this.scale,
    required this.heightErrorM,
    required this.widthErrorM,
    required this.lengthErrorM,
    required this.triangleCount,
  });

  /// True when every residual is within [toleranceM] of the record.
  ///
  /// The tolerance is generous by default because the axis the mesh was
  /// scaled on is exact by construction and the other two carry the model's
  /// own proportions, which are the modeller's and not the manual's.
  bool isFaithful({double toleranceM = 0.25}) =>
      heightErrorM.abs() <= toleranceM &&
      widthErrorM.abs() <= toleranceM &&
      lengthErrorM.abs() <= toleranceM;
}

/// A model file loaded and fitted, with the report of what fitting it cost.
class LoadedObjModel {
  final Mesh3 mesh;
  final ObjFitReport report;

  const LoadedObjModel({required this.mesh, required this.report});
}

/// Reads Wavefront OBJ geometry.
///
/// OBJ and not glTF on purpose: it is a plain text format that a couple of
/// hundred lines can read completely and correctly, it is what every modelling
/// package can export, and it carries no binary buffers, no shader semantics
/// and no dependency. This renderer needs triangles and a name to hang a
/// material on, which is exactly what OBJ has.
///
/// What is read: `v` vertices, `f` faces (triangles, quads and n-gons, fan
/// triangulated; negative and `v/vt/vn` indices handled), and `o`/`g`/`usemtl`
/// names, which become the face's [Face3.partId] and choose its material.
/// What is ignored: normals and texture coordinates (the renderer computes its
/// own shading from geometry), and materials beyond their names.
class ObjMeshLoader {
  ObjMeshLoader._();

  /// Parses [source] into a mesh in the file's own coordinates.
  ///
  /// [materialFor] maps an OBJ group or material name onto one of this
  /// project's surface materials. It defaults to [materialFromName], which
  /// guesses from the words modellers use; anything unrecognised comes back as
  /// [defaultMaterial], so an unfamiliar model still renders rather than
  /// failing.
  static Mesh3 parse(
    String source, {
    SurfaceMaterial Function(String name)? materialFor,
    SurfaceMaterial defaultMaterial = SurfaceMaterial.hullArmour,
  }) {
    final vertices = <Vector3>[];

    /// Normals as the file lists them, referenced by the third index of a
    /// face corner. A file without them shades flat, which is what every mesh
    /// this project builds from a specification wants.
    final normals = <Vector3>[];
    final faces = <Face3>[];
    var group = 'model';
    var material = defaultMaterial;
    SurfaceMaterial resolve(String name) =>
        (materialFor ?? materialFromName)(name);

    for (final rawLine in source.split('\n')) {
      final line = rawLine.trim();
      if (line.isEmpty || line.startsWith('#')) continue;
      final parts = line.split(RegExp(r'\s+'));
      switch (parts.first) {
        case 'v':
          // A malformed vertex still takes its place in the list. OBJ indices
          // are positional, so skipping one would shift every index after it
          // and scramble the whole file into plausible-looking nonsense —
          // far worse than losing the handful of faces that touch it.
          final x = parts.length > 1 ? double.tryParse(parts[1]) : null;
          final y = parts.length > 2 ? double.tryParse(parts[2]) : null;
          final z = parts.length > 3 ? double.tryParse(parts[3]) : null;
          vertices.add(x == null || y == null || z == null
              ? Vector3.zero
              : Vector3(x, y, z));
        case 'vn':
          final x = parts.length > 1 ? double.tryParse(parts[1]) : null;
          final y = parts.length > 2 ? double.tryParse(parts[2]) : null;
          final z = parts.length > 3 ? double.tryParse(parts[3]) : null;
          // Positional, like the vertices: a malformed one still takes its
          // slot so every index after it keeps pointing at the right normal.
          normals.add(x == null || y == null || z == null
              ? Vector3.zero
              : Vector3(x, y, z).normalized);
        case 'o':
        case 'g':
          if (parts.length > 1) {
            group = parts.sublist(1).join(' ');
            // Many exporters name the part and never write a material at all,
            // so the group name is taken as a hint in exactly the same way.
            material = resolve(group);
          }
        case 'usemtl':
          if (parts.length > 1) {
            final name = parts.sublist(1).join(' ');
            material = resolve(name);
            group = name;
          }
        case 'f':
          final corners = <Vector3>[];
          // Parallel to [corners], and only used when every corner of the
          // face named one: a partly-normalled face is shaded flat rather
          // than half one way and half the other.
          final cornerNormals = <Vector3>[];
          var allNormalled = true;
          for (final token in parts.skip(1)) {
            // "12", "12/4", "12//7", "12/4/7" — the vertex index is first,
            // the normal index third.
            final bits = token.split('/');
            final index = int.tryParse(bits.first);
            if (index == null) continue;
            // OBJ indices are 1-based; a negative index counts back from the
            // most recently defined vertex.
            final resolved = index > 0 ? index - 1 : vertices.length + index;
            if (resolved < 0 || resolved >= vertices.length) continue;
            corners.add(vertices[resolved]);

            final normalIndex =
                bits.length > 2 ? int.tryParse(bits[2]) : null;
            if (normalIndex == null) {
              allNormalled = false;
              continue;
            }
            final n = normalIndex > 0
                ? normalIndex - 1
                : normals.length + normalIndex;
            if (n < 0 || n >= normals.length) {
              allNormalled = false;
              continue;
            }
            cornerNormals.add(normals[n]);
          }
          if (corners.length < 3) continue;
          final smooth = allNormalled && cornerNormals.length == corners.length;
          // Fan triangulation. Correct for convex faces and adequate for the
          // mildly concave ones an exporter emits; every face becomes
          // triangles, which the depth sort handles far better than n-gons.
          for (var i = 1; i + 1 < corners.length; i++) {
            faces.add(Face3(
              [corners[0], corners[i], corners[i + 1]],
              material: material,
              partId: group,
              vertexNormals: smooth
                  ? [cornerNormals[0], cornerNormals[i], cornerNormals[i + 1]]
                  : null,
            ));
          }
      }
    }
    return Mesh3(faces);
  }

  /// Rotates a mesh from the convention it was authored in into this
  /// project's frame: `+x` towards the front of the train, `+y` up, `+z` to
  /// the right.
  static Mesh3 reorient(Mesh3 mesh, ObjAxisConvention convention) {
    switch (convention) {
      case ObjAxisConvention.yUpFacingPlusX:
        return mesh;
      case ObjAxisConvention.yUpFacingMinusZ:
        // The model's -z is our +x. An axis swap turns the corner normals
        // exactly as it turns the corners, so both go through it.
        return mesh
            .mapVertices((v) => Vector3(-v.z, v.y, v.x))
            .mapNormals((n) => Vector3(-n.z, n.y, n.x));
      case ObjAxisConvention.zUpFacingPlusY:
        // The model's +y is our +x and its +z is our +y.
        return mesh
            .mapVertices((v) => Vector3(v.y, v.z, v.x))
            .mapNormals((n) => Vector3(n.y, n.z, n.x));
    }
  }

  /// Scales and seats a mesh so it matches what the vehicle record says.
  ///
  /// The scale is **uniform**, because a model's proportions are the
  /// modeller's and stretching one axis to hit a number would produce a
  /// machine that exists nowhere. [fitOn] chooses which recorded dimension it
  /// is keyed to, and the default is the width for a reason: a tank's widest
  /// point is its tracks or its fenders, which every model has and every
  /// record states, whereas its length depends on where the gun is trained
  /// and on whether the modeller included the stowage hanging off the rear
  /// plate. Scaling this project's own T-72 on length rather than width put
  /// it a quarter of a metre narrow, because the fuel drums are outside the
  /// 9.53 m the record means.
  ///
  /// The mesh is then seated with its lowest point on `y = 0` — the running
  /// surface — and centred on the origin, which is the frame every builder in
  /// this project works in.
  static LoadedObjModel fit(
    Mesh3 mesh, {
    required double targetLengthM,
    required double recordedHeightM,
    required double recordedWidthM,
    ObjFitAxis fitOn = ObjFitAxis.width,
  }) {
    if (mesh.isEmpty) {
      return const LoadedObjModel(
        mesh: Mesh3.empty,
        report: ObjFitReport(
            scale: 1,
            heightErrorM: 0,
            widthErrorM: 0,
            lengthErrorM: 0,
            triangleCount: 0),
      );
    }
    final bounds = mesh.bounds;
    final size = bounds.size;
    final (measured, target) = switch (fitOn) {
      ObjFitAxis.length => (size.x, targetLengthM),
      ObjFitAxis.height => (size.y, recordedHeightM),
      ObjFitAxis.width => (size.z, recordedWidthM),
    };
    final scale = measured.abs() < 1e-9 ? 1.0 : target / measured;
    final scaled = mesh.scaled(scale);
    final b = scaled.bounds;
    // Centre along the wagon and across it; stand it on the running surface.
    final seated = scaled.translated(Vector3(
      -(b.min.x + b.max.x) / 2,
      -b.min.y,
      -(b.min.z + b.max.z) / 2,
    ));
    final finalBounds = seated.bounds;
    return LoadedObjModel(
      mesh: seated,
      report: ObjFitReport(
        scale: scale,
        heightErrorM: finalBounds.size.y - recordedHeightM,
        widthErrorM: finalBounds.size.z - recordedWidthM,
        lengthErrorM: finalBounds.size.x - targetLengthM,
        triangleCount: seated.faces.length,
      ),
    );
  }

  /// Reads, reorients and fits in one step.
  static LoadedObjModel load(
    String source, {
    required double targetLengthM,
    required double recordedHeightM,
    required double recordedWidthM,
    ObjAxisConvention convention = ObjAxisConvention.yUpFacingMinusZ,
    ObjFitAxis fitOn = ObjFitAxis.width,
    SurfaceMaterial Function(String name)? materialFor,
    SurfaceMaterial defaultMaterial = SurfaceMaterial.hullArmour,
  }) =>
      fit(
        reorient(
          parse(source,
              materialFor: materialFor, defaultMaterial: defaultMaterial),
          convention,
        ),
        targetLengthM: targetLengthM,
        recordedHeightM: recordedHeightM,
        recordedWidthM: recordedWidthM,
        fitOn: fitOn,
      );

  /// Guesses which of this project's materials an OBJ group or material name
  /// means, from the words modellers actually use.
  ///
  /// A guess, and named as one: it only chooses a colour. Getting it wrong
  /// paints a hull plate like a track link and nothing else, which is why the
  /// fallback is the hull rather than something conspicuous.
  static SurfaceMaterial materialFromName(String name) {
    final n = name.toLowerCase();
    bool has(List<String> words) => words.any(n.contains);
    if (has(['track', 'tread', 'caterpillar', 'gusenic'])) {
      return SurfaceMaterial.trackLink;
    }
    if (has(['wheel', 'roller', 'sprocket', 'idler'])) {
      return SurfaceMaterial.roadWheel;
    }
    if (has(['barrel', 'gun', 'cannon', 'muzzle'])) return SurfaceMaterial.gunBarrel;
    if (has(['turret', 'tower'])) return SurfaceMaterial.turret;
    if (has(['era', 'kontakt', 'applique', 'reactive'])) {
      return SurfaceMaterial.appliqueArmour;
    }
    if (has(['skirt', 'fender', 'mudguard'])) return SurfaceMaterial.fender;
    if (has(['drum', 'tank', 'box', 'stowage', 'crate'])) {
      return SurfaceMaterial.stowage;
    }
    return SurfaceMaterial.hullArmour;
  }

  /// Writes a mesh out as OBJ text.
  ///
  /// Here so the loader can be tested against real geometry rather than a
  /// hand-written cube: a mesh this project builds itself is exported, read
  /// back and compared, which exercises the parser on thousands of faces with
  /// a known right answer. It is also the way to get one of these models out
  /// to a modelling package.
  static String encode(Mesh3 mesh) {
    final buffer = StringBuffer('# railsim mesh export\n');
    final indexOf = <Vector3, int>{};
    final ordered = <Vector3>[];
    for (final face in mesh.faces) {
      for (final v in face.vertices) {
        if (!indexOf.containsKey(v)) {
          indexOf[v] = ordered.length + 1;
          ordered.add(v);
        }
      }
    }
    for (final v in ordered) {
      buffer.writeln('v ${_num(v.x)} ${_num(v.y)} ${_num(v.z)}');
    }
    String? group;
    for (final face in mesh.faces) {
      final name = face.partId ?? 'model';
      if (name != group) {
        buffer.writeln('g $name');
        group = name;
      }
      buffer.writeln('f ${face.vertices.map((v) => indexOf[v]).join(' ')}');
    }
    return buffer.toString();
  }

  static String _num(double v) {
    final rounded = (v * 1e6).roundToDouble() / 1e6;
    return rounded == rounded.roundToDouble() && rounded.abs() < 1e9
        ? rounded.toStringAsFixed(1)
        : rounded.toString();
  }
}

/// Reads a model file of whichever format it turns out to be.
///
/// The caller has a file and a name, not a format. OBJ is preferred because it
/// carries part names and STL does not, but the sites that publish freely
/// publish STL, so both are read and the difference is handled here rather
/// than by whoever is adding the file.
class MeshFileLoader {
  MeshFileLoader._();

  /// True for a name this loader can read.
  static bool isSupported(String fileName) {
    final n = fileName.toLowerCase();
    return n.endsWith('.obj') || n.endsWith('.stl');
  }

  static Mesh3 parse(
    Uint8List bytes,
    String fileName, {
    SurfaceMaterial Function(String name)? materialFor,
    SurfaceMaterial defaultMaterial = SurfaceMaterial.hullArmour,
  }) {
    if (fileName.toLowerCase().endsWith('.stl')) {
      return StlMeshLoader.parse(bytes, material: defaultMaterial);
    }
    return ObjMeshLoader.parse(
      utf8.decode(bytes, allowMalformed: true),
      materialFor: materialFor,
      defaultMaterial: defaultMaterial,
    );
  }

  /// Reads, reorients and fits, whichever format it is.
  static LoadedObjModel load(
    Uint8List bytes,
    String fileName, {
    required double targetLengthM,
    required double recordedHeightM,
    required double recordedWidthM,
    ObjAxisConvention convention = ObjAxisConvention.yUpFacingMinusZ,
    ObjFitAxis fitOn = ObjFitAxis.width,
    SurfaceMaterial Function(String name)? materialFor,
    SurfaceMaterial defaultMaterial = SurfaceMaterial.hullArmour,
  }) =>
      ObjMeshLoader.fit(
        ObjMeshLoader.reorient(
          parse(bytes, fileName,
              materialFor: materialFor, defaultMaterial: defaultMaterial),
          convention,
        ),
        targetLengthM: targetLengthM,
        recordedHeightM: recordedHeightM,
        recordedWidthM: recordedWidthM,
        fitOn: fitOn,
      );
}

/// The bounding-box aspect of a mesh, for sanity-checking a downloaded model
/// before it is trusted: a file that turns out to be a crate rather than a
/// tank shows up here as proportions nothing like the record's.
({double length, double height, double width}) meshProportions(Mesh3 mesh) {
  final size = mesh.bounds.size;
  final longest = math.max(size.x, math.max(size.y, size.z));
  if (longest <= 0) return (length: 0, height: 0, width: 0);
  return (
    length: size.x / longest,
    height: size.y / longest,
    width: size.z / longest,
  );
}
