import 'dart:math' as math;

import '../models/scene3d.dart';

/// A point on a two-dimensional profile, in metres, in the world's `xy`
/// plane — the plane the handbook's side elevations are drawn in.
typedef Profile2 = ({double x, double y});

Profile2 p2(double x, double y) => (x: x, y: y);

/// The solid builders every model in this project is assembled from.
///
/// All of them emit polygons wound counter-clockwise seen from outside the
/// solid, which is the contract [Face3] states and `test/scene3d_test.dart`
/// enforces on each primitive: the renderer culls back faces, so a single
/// reversed winding is a hole in the hull, not a shading glitch.
///
/// Concave profiles are allowed. A concave cap is still one polygon — its
/// normal comes out right because [Face3.normal] uses Newell's method, and it
/// fills correctly because the painter fills by non-zero winding. What a
/// concave part does cost is sorting accuracy, so the models below are built
/// from many small convex pieces (a track is a chain of links, not one filled
/// silhouette) rather than a few large concave ones.
class MeshPrimitives {
  MeshPrimitives._();

  /// An axis-aligned box spanned by two opposite corners, in either order.
  static Mesh3 box({
    required Vector3 corner,
    required Vector3 opposite,
    required SurfaceMaterial material,
    String? partId,
  }) {
    final ax = math.min(corner.x, opposite.x), bx = math.max(corner.x, opposite.x);
    final ay = math.min(corner.y, opposite.y), by = math.max(corner.y, opposite.y);
    final az = math.min(corner.z, opposite.z), bz = math.max(corner.z, opposite.z);

    Face3 f(List<Vector3> v) =>
        Face3(v, material: material, partId: partId);

    return Mesh3([
      // +x, -x
      f([Vector3(bx, ay, az), Vector3(bx, by, az), Vector3(bx, by, bz), Vector3(bx, ay, bz)]),
      f([Vector3(ax, ay, az), Vector3(ax, ay, bz), Vector3(ax, by, bz), Vector3(ax, by, az)]),
      // +y, -y
      f([Vector3(ax, by, az), Vector3(ax, by, bz), Vector3(bx, by, bz), Vector3(bx, by, az)]),
      f([Vector3(ax, ay, az), Vector3(bx, ay, az), Vector3(bx, ay, bz), Vector3(ax, ay, bz)]),
      // +z, -z
      f([Vector3(ax, ay, bz), Vector3(bx, ay, bz), Vector3(bx, by, bz), Vector3(ax, by, bz)]),
      f([Vector3(ax, ay, az), Vector3(ax, by, az), Vector3(bx, by, az), Vector3(bx, ay, az)]),
    ]);
  }

  /// A box given as a centre and its full extents — the form the wagon
  /// underframe and the stowage boxes are dimensioned in.
  static Mesh3 boxAt({
    required Vector3 center,
    required Vector3 size,
    required SurfaceMaterial material,
    String? partId,
  }) =>
      box(
        corner: center - size * 0.5,
        opposite: center + size * 0.5,
        material: material,
        partId: partId,
      );

  /// Twice the signed area of a profile. Positive when the profile is wound
  /// counter-clockwise in `xy`, which is the orientation [extrudeZ] needs.
  static double signedArea(List<Profile2> profile) {
    var sum = 0.0;
    for (var i = 0; i < profile.length; i++) {
      final a = profile[i];
      final b = profile[(i + 1) % profile.length];
      sum += a.x * b.y - b.x * a.y;
    }
    return sum;
  }

  /// A side profile given in `xy` — a hull silhouette, a chock's wedge — swept
  /// across the vehicle from [zMin] to [zMax].
  ///
  /// The profile may be given either way round; it is normalised here, so a
  /// caller can list the points in whatever order reads best next to the
  /// handbook plate it came from.
  static Mesh3 extrudeZ(
    List<Profile2> profile, {
    required double zMin,
    required double zMax,
    required SurfaceMaterial material,
    SurfaceMaterial? capMaterial,
    String? partId,
    bool capped = true,
  }) {
    if (profile.length < 3) return Mesh3.empty;
    final ring = signedArea(profile) >= 0 ? profile : profile.reversed.toList();
    final lo = math.min(zMin, zMax);
    final hi = math.max(zMin, zMax);
    final faces = <Face3>[];

    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      faces.add(Face3([
        Vector3(a.x, a.y, lo),
        Vector3(b.x, b.y, lo),
        Vector3(b.x, b.y, hi),
        Vector3(a.x, a.y, hi),
      ], material: material, partId: partId));
    }

    if (capped) {
      final capMat = capMaterial ?? material;
      faces.add(Face3([for (final p in ring) Vector3(p.x, p.y, hi)],
          material: capMat, partId: partId));
      faces.add(Face3([for (final p in ring.reversed) Vector3(p.x, p.y, lo)],
          material: capMat, partId: partId));
    }
    return Mesh3(faces);
  }

  /// Rings ordered counter-clockwise seen from above, as [loft] requires.
  static List<Vector3> _ccwFromAbove(List<Vector3> ring) {
    var sum = 0.0;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      // Twice the signed area projected onto the ground plane. Positive is
      // counter-clockwise seen from +y.
      sum += a.z * b.x - b.z * a.x;
    }
    return sum >= 0 ? ring : ring.reversed.toList();
  }

  /// The solid between two horizontal rings of the same point count.
  ///
  /// This is how every sloped-armour part is built — a turret is its plan
  /// outline at the ring level and the same outline drawn in at the roof, and
  /// the faces between them are the slope. Both rings are normalised to
  /// counter-clockwise seen from above.
  static Mesh3 loft(
    List<Vector3> bottom,
    List<Vector3> top, {
    required SurfaceMaterial material,
    String? partId,
    bool capBottom = true,
    bool capTop = true,
  }) {
    if (bottom.length != top.length || bottom.length < 3) return Mesh3.empty;
    final b = _ccwFromAbove(bottom);
    final t = _ccwFromAbove(top);
    final faces = <Face3>[];
    for (var i = 0; i < b.length; i++) {
      final j = (i + 1) % b.length;
      faces.add(Face3([b[i], b[j], t[j], t[i]], material: material, partId: partId));
    }
    if (capTop) faces.add(Face3(t, material: material, partId: partId));
    if (capBottom) {
      faces.add(Face3(b.reversed.toList(), material: material, partId: partId));
    }
    return Mesh3(faces);
  }

  /// A cylinder about the `z` axis — the axis every wheel in the scene turns
  /// on, so road wheels, sprockets and wagon wheels all come from here.
  static Mesh3 cylinderZ({
    required Vector3 center,
    required double radius,
    required double length,
    required SurfaceMaterial material,
    int segments = 16,
    String? partId,
    bool capped = true,
  }) {
    final n = math.max(3, segments);
    final lo = center.z - length / 2;
    final hi = center.z + length / 2;
    List<Vector3> ring(double z) => [
          for (var k = 0; k < n; k++)
            Vector3(
              center.x + radius * math.cos(2 * math.pi * k / n),
              center.y + radius * math.sin(2 * math.pi * k / n),
              z,
            ),
        ];
    final low = ring(lo);
    final high = ring(hi);
    final faces = <Face3>[];
    for (var k = 0; k < n; k++) {
      final j = (k + 1) % n;
      faces.add(Face3([low[k], low[j], high[j], high[k]],
          material: material, partId: partId));
    }
    if (capped) {
      faces.add(Face3(high, material: material, partId: partId));
      faces.add(Face3(low.reversed.toList(), material: material, partId: partId));
    }
    return Mesh3(faces);
  }

  /// Rodrigues' rotation taking the unit vector [from] onto [to]. Returns the
  /// identity when they already agree, and a half turn about an arbitrary
  /// perpendicular when they are exactly opposed — the case that would
  /// otherwise divide by a zero-length cross product.
  static Vector3 Function(Vector3) rotationAligning(Vector3 from, Vector3 to) {
    final f = from.normalized;
    final t = to.normalized;
    final d = f.dot(t).clamp(-1.0, 1.0);
    if (d > 0.999999) return (v) => v;
    Vector3 axis;
    double angle;
    if (d < -0.999999) {
      angle = math.pi;
      // Any axis perpendicular to f will do; cross with whichever of x/y is
      // less parallel to it.
      final helper = f.x.abs() < 0.9 ? const Vector3(1, 0, 0) : const Vector3(0, 1, 0);
      axis = f.cross(helper).normalized;
    } else {
      angle = math.acos(d);
      axis = f.cross(t).normalized;
    }
    final c = math.cos(angle);
    final s = math.sin(angle);
    return (v) => v * c + axis.cross(v) * s + axis * (axis.dot(v) * (1 - c));
  }

  /// A round bar from [a] to [b] — a lashing wire run, a tie rod, a gun
  /// barrel that is not aligned with an axis. Zero-length returns nothing
  /// rather than a degenerate solid.
  static Mesh3 rod({
    required Vector3 a,
    required Vector3 b,
    required double radius,
    required SurfaceMaterial material,
    int segments = 8,
    String? partId,
  }) {
    final axis = b - a;
    final len = axis.length;
    if (len < 1e-6) return Mesh3.empty;
    final base = cylinderZ(
      center: Vector3.zero,
      radius: radius,
      length: len,
      material: material,
      segments: segments,
      partId: partId,
    );
    final rotate = rotationAligning(const Vector3(0, 0, 1), axis);
    final mid = (a + b) * 0.5;
    return base.mapVertices((v) => rotate(v) + mid);
  }

  /// A polyline of round bar — a wire that passes over a towing eye and down
  /// to a deck ring keeps its thickness around the bend.
  static Mesh3 rodPath(
    List<Vector3> path, {
    required double radius,
    required SurfaceMaterial material,
    int segments = 6,
    String? partId,
  }) =>
      Mesh3.merge([
        for (var i = 0; i + 1 < path.length; i++)
          rod(
            a: path[i],
            b: path[i + 1],
            radius: radius,
            material: material,
            segments: segments,
            partId: partId,
          ),
      ]);

  /// A closed chain of links following [centerline], each link a solid of
  /// [thickness] and width `zMin..zMax`.
  ///
  /// This is the track. Building it as separate links rather than one filled
  /// silhouette is what lets the road wheels show through between the top and
  /// bottom runs, the way they do on the handbook's side elevations.
  static Mesh3 linkChain(
    List<Profile2> centerline, {
    required double thickness,
    required double zMin,
    required double zMax,
    required SurfaceMaterial material,
    double linkGap = 0.0,
    String? partId,
  }) {
    if (centerline.length < 2) return Mesh3.empty;
    final faces = <Face3>[];
    for (var i = 0; i < centerline.length; i++) {
      final p = centerline[i];
      final q = centerline[(i + 1) % centerline.length];
      final dx = q.x - p.x;
      final dy = q.y - p.y;
      final len = math.sqrt(dx * dx + dy * dy);
      if (len < 1e-9) continue;
      // Shorten each link by half the gap at both ends, along its own axis.
      final trim = math.min(linkGap / 2, len / 3);
      final ux = dx / len, uy = dy / len;
      final a = p2(p.x + ux * trim, p.y + uy * trim);
      final b = p2(q.x - ux * trim, q.y - uy * trim);
      // Outward normal of the segment in xy.
      final nx = uy, ny = -ux;
      final h = thickness / 2;
      faces.addAll(extrudeZ(
        [
          p2(a.x + nx * h, a.y + ny * h),
          p2(b.x + nx * h, b.y + ny * h),
          p2(b.x - nx * h, b.y - ny * h),
          p2(a.x - nx * h, a.y - ny * h),
        ],
        zMin: zMin,
        zMax: zMax,
        material: material,
        partId: partId,
      ).faces);
    }
    return Mesh3(faces);
  }

  /// An arc of profile points, for the rounded ends of a track run.
  /// Angles in radians, measured the usual way in the `xy` plane.
  static List<Profile2> arc({
    required double cx,
    required double cy,
    required double radius,
    required double fromAngle,
    required double toAngle,
    int steps = 8,
  }) =>
      [
        for (var i = 0; i <= steps; i++)
          p2(
            cx + radius * math.cos(fromAngle + (toAngle - fromAngle) * i / steps),
            cy + radius * math.sin(fromAngle + (toAngle - fromAngle) * i / steps),
          ),
      ];

  /// A flat ring lying on the deck — a tie-down ring, drawn as a low annulus
  /// of [segments] boxes rather than a torus, which at this scale reads the
  /// same and costs a tenth of the faces.
  static Mesh3 ringZUp({
    required Vector3 center,
    required double radius,
    required double barRadius,
    required SurfaceMaterial material,
    int segments = 8,
    String? partId,
  }) {
    final points = [
      for (var k = 0; k <= segments; k++)
        Vector3(
          center.x + radius * math.cos(2 * math.pi * k / segments),
          center.y + radius * math.sin(2 * math.pi * k / segments) * 0.35,
          center.z,
        ),
    ];
    return Mesh3.merge([
      for (var i = 0; i + 1 < points.length; i++)
        rod(
          a: points[i],
          b: points[i + 1],
          radius: barRadius,
          material: material,
          segments: 4,
          partId: partId,
        ),
    ]);
  }
}
