import 'dart:math' as math;

import '../models/scene3d.dart';
import 'scene3d_camera.dart';

/// A ray in world space — an eye and a direction.
class Ray3 {
  final Vector3 origin;

  /// Unit length.
  final Vector3 direction;

  Ray3(this.origin, Vector3 direction) : direction = direction.normalized;

  Vector3 at(double t) => origin + direction * t;
}

/// What the pointer is over.
class ScenePick {
  /// The [Face3.partId] of the surface hit — `'securing.woodChock-1'`,
  /// `'wagon.deck'`, `'track'`.
  final String? partId;

  /// Where on that surface, in world metres.
  final Vector3 point;

  /// Distance from the eye.
  final double distance;

  final SurfaceMaterial material;

  const ScenePick({
    required this.partId,
    required this.point,
    required this.distance,
    required this.material,
  });
}

/// Turns a point on the drawing surface into a question about the solid.
///
/// This is what makes the scene something the trainee can work in rather than
/// look at: without it a block on the deck is a picture of a block, and there
/// is no way to say "that one" or "put it there". The same arithmetic answers
/// both — which piece the pointer is on, and where on the deck a drag has
/// reached.
class ScenePicking {
  ScenePicking._();

  /// Parallel-to-the-surface tolerance. Below this the ray runs along the
  /// plane and any intersection it reports is numerical noise.
  static const double _parallelEpsilon = 1e-9;

  /// The ray from the eye through a point on the drawing surface. The inverse
  /// of [SceneProjection.project], and it must stay that way — a picker that
  /// disagrees with the renderer by even a little makes pieces appear to jump
  /// away from the pointer.
  static Ray3 through({
    required Camera3 camera,
    required double width,
    required double height,
    required double px,
    required double py,
  }) {
    final eye = camera.eye;
    final zAxis = (eye - camera.target).normalized;
    final xAxis = const Vector3(0, 1, 0).cross(zAxis).normalized;
    final yAxis = zAxis.cross(xAxis);
    final scale = (height / 2) / math.tan(camera.fieldOfView / 2);
    // In view space the surface sits one focal length down -z.
    final vx = (px - width / 2) / scale;
    final vy = -(py - height / 2) / scale;
    final dir = xAxis * vx + yAxis * vy + zAxis * -1.0;
    return Ray3(eye, dir);
  }

  /// Where a ray crosses a horizontal plane, or null when it never does.
  /// The deck is such a plane, which is what a block is dragged across.
  static Vector3? planeY(Ray3 ray, double y) {
    final dy = ray.direction.y;
    if (dy.abs() < _parallelEpsilon) return null;
    final t = (y - ray.origin.y) / dy;
    if (t <= 0) return null;
    return ray.at(t);
  }

  /// The nearest surface the ray strikes.
  ///
  /// [accept] filters which faces are candidates — pick only the securing
  /// gear, or only the deck — so one mesh can answer several different
  /// questions without being rebuilt.
  static ScenePick? pick(
    Mesh3 mesh,
    Ray3 ray, {
    bool Function(Face3 face)? accept,
  }) {
    ScenePick? best;
    for (final face in mesh.faces) {
      if (face.vertices.length < 3) continue;
      if (accept != null && !accept(face)) continue;
      final normal = face.normal;
      final denom = normal.dot(ray.direction);
      // Only surfaces turned towards the eye are pickable, for the same
      // reason they are the only ones drawn: the back of a block is behind
      // its own front.
      if (denom >= -_parallelEpsilon && !face.doubleSided) continue;
      if (denom.abs() < _parallelEpsilon) continue;
      final t = normal.dot(face.centroid - ray.origin) / denom;
      if (t <= 0) continue;
      final point = ray.at(t);
      if (!_containsPoint(face.vertices, normal, point)) continue;
      if (best == null || t < best.distance) {
        best = ScenePick(
          partId: face.partId,
          point: point,
          distance: t,
          material: face.material,
        );
      }
    }
    return best;
  }

  /// The nearest surface within [radiusPixels] of a point on the drawing
  /// surface, not just the one exactly under it.
  ///
  /// A stop block is 150 mm wide. Seen from across a 13-metre wagon that is a
  /// handful of pixels, and a pointer that has to land inside them exactly
  /// makes the gear feel unpickable — worse on a drag, which only reports its
  /// position after the pointer has already travelled the gesture slop. So the
  /// search widens in rings until it finds something, nearest ring first, and
  /// a piece the trainee has plainly aimed at is picked up.
  static ScenePick? pickNear(
    Mesh3 mesh,
    Camera3 camera, {
    required double width,
    required double height,
    required double px,
    required double py,
    double radiusPixels = 18,
    bool Function(Face3 face)? accept,
  }) {
    const ringSteps = 8;
    for (final radius in [0.0, radiusPixels / 2, radiusPixels]) {
      final samples = radius == 0 ? 1 : ringSteps;
      for (var i = 0; i < samples; i++) {
        final angle = 2 * math.pi * i / samples;
        final hit = pick(
          mesh,
          through(
            camera: camera,
            width: width,
            height: height,
            px: px + radius * math.cos(angle),
            py: py + radius * math.sin(angle),
          ),
          accept: accept,
        );
        if (hit != null) return hit;
      }
    }
    return null;
  }

  /// Point-in-polygon, done in whichever plane the polygon is most spread
  /// across. Projecting onto the axis plane the normal is *least* aligned
  /// with keeps the test away from an edge-on degenerate projection.
  static bool _containsPoint(
    List<Vector3> vertices,
    Vector3 normal,
    Vector3 point,
  ) {
    final ax = normal.x.abs(), ay = normal.y.abs(), az = normal.z.abs();
    double u(Vector3 v) => ax >= ay && ax >= az ? v.y : v.x;
    double w(Vector3 v) => az >= ax && az >= ay ? v.y : v.z;

    final pu = u(point), pw = w(point);
    var inside = false;
    for (var i = 0, j = vertices.length - 1; i < vertices.length; j = i++) {
      final iu = u(vertices[i]), iw = w(vertices[i]);
      final ju = u(vertices[j]), jw = w(vertices[j]);
      if ((iw > pw) != (jw > pw) &&
          pu < (ju - iu) * (pw - iw) / (jw - iw) + iu) {
        inside = !inside;
      }
    }
    return inside;
  }
}
