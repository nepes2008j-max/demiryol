import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import '../models/scene3d.dart';
import 'scene3d_camera.dart';

/// The same scene as [SceneProjection], drawn a way that survives a real model.
///
/// Why there are two paths
/// -----------------------
/// [SceneProjection] projects a [Mesh3] into a list of [ProjectedFace] objects
/// and [Scene3Painter] fills each one with its own `drawPath`. That is exactly
/// right for the meshes this project builds from a specification — a few
/// thousand faces, each one a panel worth its own outline — and it is what
/// still draws them.
///
/// It does not survive a downloaded model. Measured on this machine at
/// 1100x620 (see `test/draw_path_benchmark_test.dart`), for the T-72 at its
/// published 549,035 triangles:
///
/// * projecting and sorting: 218 ms
/// * one `drawPath` per face: 317 ms
/// * the same polygons as one `drawVertices` call: **4.7 ms**
///
/// A frame of 535 ms is two frames a second. The per-face draw call is the
/// wall, and `drawVertices` takes it down by a factor of sixty-seven, because
/// it hands the triangles to the GPU in one go instead of asking the rasteriser
/// to fill half a million separate paths.
///
/// Removing that wall leaves the projection, so this path also stops building
/// objects per face. The mesh is flattened **once** into typed arrays; a frame
/// then walks those arrays writing screen coordinates and packed colours into
/// more typed arrays, allocating nothing per triangle. The depth sort becomes a
/// counting sort over depth buckets rather than a comparator sort over half a
/// million objects — a painter's algorithm never needed a total order, only
/// enough resolution that two faces at visibly different distances land apart.
///
/// Together: **29 ms for 551,977 triangles**, against 535 ms. That is what
/// makes it possible to draw the model as it was downloaded rather than a
/// decimation of it.
///
/// What it deliberately does not do
/// --------------------------------
/// No edge hairlines. `drawVertices` fills triangles; it does not stroke them.
/// Edges are what separate one track link from the next on a *drawn* mesh, and
/// a drawn mesh still goes down the old path, which still strokes them. On an
/// imported model the hairlines were never wanted anyway — at this face count
/// they cover the armour in a web of scribbles.
///
/// No picking. Picking casts against `scene.securingMesh`, which is the gear
/// alone and a few hundred faces, and does not come through here at all.
class RasterMesh {
  /// Nine floats a triangle: three corners, x, y, z. World coordinates.
  final Float32List world;

  /// [SurfaceMaterial.index] per triangle.
  final Uint8List material;

  /// Bit 0: the face is double-sided, so it is never culled and is lit from
  /// whichever side the eye is on. Bit 1: it is drawn at an even brightness
  /// rather than lit, which is what keeps a guide line on the deck readable
  /// whichever way the scene is turned.
  final Uint8List flags;

  /// Index into [parts] per triangle, so a highlight can dim everything that
  /// is not the piece being worked on without storing a string per triangle.
  final Uint16List part;
  final List<String?> parts;

  /// Nine floats a triangle — a normal per corner — or null when no face in
  /// this mesh carried any.
  ///
  /// This is what separates a curve from a heap of facets. A cast turret is
  /// modelled as thousands of small triangles at slightly different angles;
  /// shaded from their own planes they read as speckle, and the shape is lost
  /// in it. Shading each corner from the surface's normal there, and letting
  /// `drawVertices` interpolate between the three, is Gouraud shading — the
  /// same thing that makes the model look right in a modelling package.
  final Float32List? cornerNormals;

  final int triangleCount;

  /// Per-frame working storage, allocated once with the mesh.
  ///
  /// A frame at half a million triangles writes roughly twenty megabytes of
  /// screen coordinates and colours. Allocating that per frame would hand the
  /// collector 600 MB a second at thirty frames — so the buffers are held here
  /// and the frame writes over them, taking a view of the part it filled.
  late final Float32List _screen = Float32List(triangleCount * 6);
  late final Int32List _packed = Int32List(triangleCount * 3);
  late final Float32List _depth = Float32List(triangleCount);
  late final Uint8List _keep = Uint8List(triangleCount);
  late final Int32List _bucketOf = Int32List(triangleCount);
  late final Float32List _positions = Float32List(triangleCount * 6);
  late final Int32List _colors = Int32List(triangleCount * 3);
  late final Int32List _counts = Int32List(SceneRaster._buckets);

  static const int _doubleSided = 1;
  static const int _flatLit = 2;
  static const int _smooth = 4;

  RasterMesh._({
    required this.world,
    required this.material,
    required this.flags,
    required this.part,
    required this.parts,
    required this.triangleCount,
    required this.cornerNormals,
  });

  /// Flattens [mesh] once. Convex polygons come apart into a triangle fan,
  /// which is what the fill would have been anyway.
  ///
  /// This is the expensive step and it is not per frame — hold the result for
  /// as long as the mesh itself lives.
  factory RasterMesh.from(Mesh3 mesh) {
    var count = 0;
    for (final f in mesh.faces) {
      if (f.vertices.length >= 3) count += f.vertices.length - 2;
    }

    var anySmooth = false;
    for (final f in mesh.faces) {
      if (f.vertexNormals != null && f.vertexNormals!.length == f.vertices.length) {
        anySmooth = true;
        break;
      }
    }

    final world = Float32List(count * 9);
    final cornerNormals = anySmooth ? Float32List(count * 9) : null;
    final material = Uint8List(count);
    final flags = Uint8List(count);
    final part = Uint16List(count);
    final parts = <String?>[null];
    final partIndex = <String?, int>{null: 0};

    var t = 0;
    for (final f in mesh.faces) {
      final vs = f.vertices;
      if (vs.length < 3) continue;

      var index = partIndex[f.partId];
      if (index == null) {
        // 65,535 distinct part names is far past anything this scene builds;
        // past it the extra parts simply share the unnamed slot, which costs a
        // highlight, not a crash.
        index = parts.length < 0xFFFF ? parts.length : 0;
        if (index != 0) {
          parts.add(f.partId);
          partIndex[f.partId] = index;
        }
      }

      final vn = f.vertexNormals;
      final smooth = vn != null && vn.length == vs.length;

      var bits = 0;
      if (f.doubleSided) bits |= _doubleSided;
      if (smooth) bits |= _smooth;
      if (f.material == SurfaceMaterial.selectionMarker ||
          f.material == SurfaceMaterial.guideLine) {
        bits |= _flatLit;
      }

      final a = vs[0];
      for (var i = 2; i < vs.length; i++) {
        final b = vs[i - 1], c = vs[i];
        final o = t * 9;
        world[o] = a.x;
        world[o + 1] = a.y;
        world[o + 2] = a.z;
        world[o + 3] = b.x;
        world[o + 4] = b.y;
        world[o + 5] = b.z;
        world[o + 6] = c.x;
        world[o + 7] = c.y;
        world[o + 8] = c.z;
        if (smooth && cornerNormals != null) {
          final na = vn[0], nb = vn[i - 1], nc = vn[i];
          cornerNormals[o] = na.x;
          cornerNormals[o + 1] = na.y;
          cornerNormals[o + 2] = na.z;
          cornerNormals[o + 3] = nb.x;
          cornerNormals[o + 4] = nb.y;
          cornerNormals[o + 5] = nb.z;
          cornerNormals[o + 6] = nc.x;
          cornerNormals[o + 7] = nc.y;
          cornerNormals[o + 8] = nc.z;
        }
        material[t] = f.material.index;
        flags[t] = bits;
        part[t] = index;
        t++;
      }
    }

    return RasterMesh._(
      world: world,
      material: material,
      flags: flags,
      part: part,
      parts: parts,
      triangleCount: t,
      cornerNormals: cornerNormals,
    );
  }
}

/// One frame's worth of triangles, ready for a single `drawVertices`.
class RasterFrame {
  final ui.Vertices vertices;

  /// How many triangles survived the cull and the near plane. Zero means there
  /// is nothing to draw, not that something went wrong.
  final int triangleCount;

  const RasterFrame(this.vertices, this.triangleCount);

  void dispose() => vertices.dispose();
}

/// Projects, shades, depth-sorts and packs [mesh] for one frame.
///
/// The lighting is [SceneProjection]'s, deliberately: the two paths draw the
/// same scene and a trainee moving between a drawn vehicle and an imported one
/// must not see the light move.
class SceneRaster {
  SceneRaster._();

  /// Depth buckets for the counting sort.
  ///
  /// The bucket is the sort's resolution: two triangles that land in the same
  /// one are drawn in whatever order they were stored, which for a painter's
  /// algorithm means the wrong one can end up on top. The scene spans the
  /// whole track bed, some forty metres from the near rail to the far end, so
  /// 2,048 buckets put two surfaces within two centimetres of each other at
  /// the mercy of storage order — and on a hull carrying weld beads, grab
  /// handles and smoke launchers that is most of the surface. It speckled the
  /// turret. 65,536 buckets is sub-millimetre over the same span, and costs
  /// 256 KB and one more pass over an array that fits in cache.
  static const int _buckets = 65536;

  /// How far a colour is pulled towards grey when a highlight is on and the
  /// triangle is not part of it. Matches the 0.62 lerp the painter uses.
  static const double _dimmed = 0.62;
  static const int _dimR = 0x4A, _dimG = 0x50, _dimB = 0x57;

  static RasterFrame? render(
    RasterMesh mesh, {
    required Camera3 camera,
    required double width,
    required double height,
    required int Function(SurfaceMaterial material) colorOf,
    String? highlightPartPrefix,
  }) {
    final n = mesh.triangleCount;
    if (n == 0 || width <= 0 || height <= 0) return null;

    final eye = camera.eye;
    final zAxis = (eye - camera.target).normalized;
    final xAxis = const Vector3(0, 1, 0).cross(zAxis).normalized;
    final yAxis = zAxis.cross(xAxis);
    final scale = (height / 2) / math.tan(camera.fieldOfView / 2);

    // Pulled out of the loop: a field read per triangle is a real cost at half
    // a million of them.
    final ex = eye.x, ey = eye.y, ez = eye.z;
    final zx = zAxis.x, zy = zAxis.y, zz = zAxis.z;
    final xx = xAxis.x, xy = xAxis.y, xz = xAxis.z;
    final yx = yAxis.x, yy = yAxis.y, yz = yAxis.z;
    final cx = width / 2, cy = height / 2;

    final world = mesh.world;
    final normals = mesh.cornerNormals;
    final materials = mesh.material;
    final flagBits = mesh.flags;

    // Which parts the highlight keeps at full strength. Resolved once over the
    // part table rather than per triangle: the table is tens of entries, the
    // triangles are hundreds of thousands.
    Uint8List? lit;
    if (highlightPartPrefix != null) {
      lit = Uint8List(mesh.parts.length);
      for (var i = 0; i < mesh.parts.length; i++) {
        lit[i] = (mesh.parts[i]?.startsWith(highlightPartPrefix) ?? false) ? 1 : 0;
      }
    }
    final partOf = mesh.part;

    final palette = Int32List(SurfaceMaterial.values.length);
    for (final m in SurfaceMaterial.values) {
      palette[m.index] = colorOf(m);
    }

    final screen = mesh._screen;
    final packed = mesh._packed;
    final depth = mesh._depth;
    final keep = mesh._keep;
    keep.fillRange(0, n, 0);
    var kept = 0;
    var near = double.infinity, far = -double.infinity;

    for (var i = 0; i < n; i++) {
      final o = i * 9;
      final ax = world[o] - ex, ay = world[o + 1] - ey, az = world[o + 2] - ez;
      final bx = world[o + 3] - ex, by = world[o + 4] - ey, bz = world[o + 5] - ez;
      final gx = world[o + 6] - ex, gy = world[o + 7] - ey, gz = world[o + 8] - ez;

      final ux = bx - ax, uy = by - ay, uz = bz - az;
      final vx = gx - ax, vy = gy - ay, vz = gz - az;
      var nx = uy * vz - uz * vy;
      var ny = uz * vx - ux * vz;
      var nz = ux * vy - uy * vx;

      // The centroid, which is also the vector from the eye to the face.
      final mx = (ax + bx + gx) / 3, my = (ay + by + gy) / 3, mz = (az + bz + gz) / 3;

      // Facing: the normal against the direction back to the eye, which from
      // eye-relative coordinates is simply -centroid.
      final facing = -(nx * mx + ny * my + nz * mz);
      final bits = flagBits[i];
      final twoSided = (bits & RasterMesh._doubleSided) != 0;
      if (!twoSided && facing <= 0) continue;
      if (twoSided && facing < 0) {
        nx = -nx;
        ny = -ny;
        nz = -nz;
      }

      final da = -(ax * zx + ay * zy + az * zz);
      final db = -(bx * zx + by * zy + bz * zz);
      final dg = -(gx * zx + gy * zy + gz * zz);
      if (da <= 0.05 || db <= 0.05 || dg <= 0.05) continue;

      final s = i * 6;
      screen[s] = cx + (ax * xx + ay * xy + az * xz) * scale / da;
      screen[s + 1] = cy - (ax * yx + ay * yy + az * yz) * scale / da;
      screen[s + 2] = cx + (bx * xx + by * xy + bz * xz) * scale / db;
      screen[s + 3] = cy - (bx * yx + by * yy + bz * yz) * scale / db;
      screen[s + 4] = cx + (gx * xx + gy * xy + gz * xz) * scale / dg;
      screen[s + 5] = cy - (gx * yx + gy * yy + gz * yz) * scale / dg;

      final gloss = SceneLighting.specularFor(
          SurfaceMaterial.values[materials[i]]);
      final flatLit = (bits & RasterMesh._flatLit) != 0;
      final smooth = (bits & RasterMesh._smooth) != 0 && normals != null;
      final dim = lit != null && lit[partOf[i]] == 0;
      final rgb = palette[materials[i]];
      final baseR = (rgb >> 16) & 0xFF, baseG = (rgb >> 8) & 0xFF, baseB = rgb & 0xFF;

      int shaded(({double r, double g, double b}) light) {
        var r = (baseR * light.r).round();
        var g = (baseG * light.g).round();
        var b = (baseB * light.b).round();
        if (dim) {
          r = (r + (_dimR - r) * _dimmed).round();
          g = (g + (_dimG - g) * _dimmed).round();
          b = (b + (_dimB - b) * _dimmed).round();
        }
        return 0xFF000000 | (r << 16) | (g << 8) | b;
      }

      /// [SceneLighting] for a normal that is not yet unit length, at the
      /// point [ex],[ey],[ez] measured from the eye — which is what the loop
      /// already holds, so the direction back to the eye is just its negation.
      ({double r, double g, double b}) lightOf(
          double px, double py, double pz, double qx, double qy, double qz) {
        final len = math.sqrt(px * px + py * py + pz * pz);
        if (len <= 0) return SceneLighting.flat;
        var vx = 0.0, vy = 0.0, vz = 0.0;
        if (gloss > 0) {
          final d = math.sqrt(qx * qx + qy * qy + qz * qz);
          if (d > 0) {
            vx = -qx / d;
            vy = -qy / d;
            vz = -qz / d;
          }
        }
        return SceneLighting.forUnitNormal(px / len, py / len, pz / len,
            vx: vx, vy: vy, vz: vz, specular: gloss);
      }

      final c = i * 3;
      if (flatLit) {
        final flat = shaded(SceneLighting.flat);
        packed[c] = flat;
        packed[c + 1] = flat;
        packed[c + 2] = flat;
      } else if (smooth) {
        // Each corner shaded from the surface's own normal there; the fill
        // interpolates between them, which is what turns facets into a curve.
        // The winding flip a double-sided face gets applies to these too.
        final sign = (twoSided && facing < 0) ? -1.0 : 1.0;
        packed[c] = shaded(lightOf(normals[o] * sign,
            normals[o + 1] * sign, normals[o + 2] * sign, ax, ay, az));
        packed[c + 1] = shaded(lightOf(normals[o + 3] * sign,
            normals[o + 4] * sign, normals[o + 5] * sign, bx, by, bz));
        packed[c + 2] = shaded(lightOf(normals[o + 6] * sign,
            normals[o + 7] * sign, normals[o + 8] * sign, gx, gy, gz));
      } else {
        final flat = shaded(lightOf(nx, ny, nz, mx, my, mz));
        packed[c] = flat;
        packed[c + 1] = flat;
        packed[c + 2] = flat;
      }

      // Sorted on the NEAREST corner, not the centroid.
      //
      // This model carries interior geometry — a breech inside the turret, the
      // underside of a hatch, the far wall of the gun's thermal sleeve — and
      // an interior part sits wholly inside the surface that hides it. Their
      // centroids are at nearly the same distance, so ordering by centroid put
      // them in an arbitrary order and the inside came out on top of the
      // outside, one triangle at a time: the dark speckle over the hull and the
      // stipple along the barrel.
      //
      // The nearest corner is not arbitrary. A surface that encloses another
      // has a nearer nearest-point than anything it encloses, so it sorts
      // last and is painted over the top, which is the right answer. It is
      // still a painter's algorithm and still cannot resolve two shapes that
      // genuinely interpenetrate — only a depth buffer can — but the enclosing
      // case is the one this model is full of.
      final d = da < db ? (da < dg ? da : dg) : (db < dg ? db : dg);
      depth[i] = d;
      if (d < near) near = d;
      if (d > far) far = d;
      keep[i] = 1;
      kept++;
    }

    if (kept == 0) return null;

    // Counting sort into depth buckets, farthest first.
    final counts = mesh._counts..fillRange(0, _buckets, 0);
    final bucketOf = mesh._bucketOf;
    final span = (far - near) <= 0 ? 1.0 : (far - near);
    for (var i = 0; i < n; i++) {
      if (keep[i] == 0) continue;
      var b = (((far - depth[i]) / span) * (_buckets - 1)).toInt();
      if (b < 0) b = 0;
      if (b >= _buckets) b = _buckets - 1;
      bucketOf[i] = b;
      counts[b]++;
    }
    var running = 0;
    for (var b = 0; b < _buckets; b++) {
      final c = counts[b];
      counts[b] = running;
      running += c;
    }

    final positions = mesh._positions;
    final colors = mesh._colors;
    for (var i = 0; i < n; i++) {
      if (keep[i] == 0) continue;
      final k = counts[bucketOf[i]]++;
      final s = i * 6, d = k * 6;
      positions[d] = screen[s];
      positions[d + 1] = screen[s + 1];
      positions[d + 2] = screen[s + 2];
      positions[d + 3] = screen[s + 3];
      positions[d + 4] = screen[s + 4];
      positions[d + 5] = screen[s + 5];
      final cs = i * 3, cd = k * 3;
      colors[cd] = packed[cs];
      colors[cd + 1] = packed[cs + 1];
      colors[cd + 2] = packed[cs + 2];
    }

    // Views of the prefix actually filled, so no copy is made of the tail.
    return RasterFrame(
      ui.Vertices.raw(
        ui.VertexMode.triangles,
        Float32List.sublistView(positions, 0, kept * 6),
        colors: Int32List.sublistView(colors, 0, kept * 3),
      ),
      kept,
    );
  }
}
