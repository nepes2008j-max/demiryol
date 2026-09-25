import 'dart:math' as math;

import '../models/scene3d.dart';

/// A point on the drawing surface, in the painter's own pixels. Kept as a
/// record rather than an `Offset` so this file, like the rest of the domain
/// layer, needs no Flutter import and runs under plain `dart test`.
typedef ScreenPoint = ({double x, double y});

/// An orbit camera looking at [target] from [distance] metres away.
///
/// [yaw] `0` puts the eye on the `+z` side — the side elevation the handbook
/// plates are drawn from — and increases towards the head of the train, so a
/// three-quarter view of a loaded wagon is a small positive yaw. [pitch] is
/// positive looking down on the load, which is the angle a loading officer
/// actually inspects a secured vehicle from.
class Camera3 {
  final Vector3 target;
  final double yaw;
  final double pitch;
  final double distance;

  /// Vertical field of view. A long lens (a small angle) is deliberate: it
  /// keeps a 13-metre wagon from splaying out at the ends, so lengths along
  /// the deck stay comparable by eye.
  final double fieldOfView;

  const Camera3({
    required this.target,
    this.yaw = 0.35,
    this.pitch = 0.30,
    required this.distance,
    this.fieldOfView = 0.5,
  });

  Vector3 get eye => target +
      Vector3(
        distance * math.cos(pitch) * math.sin(yaw),
        distance * math.sin(pitch),
        distance * math.cos(pitch) * math.cos(yaw),
      );

  Camera3 copyWith({double? yaw, double? pitch, double? distance, Vector3? target}) =>
      Camera3(
        target: target ?? this.target,
        yaw: yaw ?? this.yaw,
        pitch: pitch ?? this.pitch,
        distance: distance ?? this.distance,
        fieldOfView: fieldOfView,
      );

  /// A camera that frames [bounds] in a viewport of the given aspect ratio.
  ///
  /// The distance comes from the bounding sphere, so the load stays fully in
  /// frame at every orbit angle — a wagon that fitted head-on and then clipped
  /// its own coupler when the user dragged sideways would make the view
  /// useless for judging overhang, which is one of the things it is for.
  factory Camera3.framing(
    Bounds3 bounds, {
    double yaw = 0.35,
    double pitch = 0.30,
    double aspectRatio = 2.0,
    double fieldOfView = 0.5,
    double margin = 1.12,
  }) {
    // Each axis asks for the room it actually needs.
    //
    // Using the bounding *sphere* for both, as this did, makes a wagon demand
    // as much height as length: the sphere round a 13 m flatcar is nearly 7 m
    // in radius, while the thing standing on it is 2.6 m tall. The camera then
    // backed off far enough to fit seven metres of nothing above and below the
    // deck, and the vehicle — the object the whole view exists to show — sat
    // small in the middle of an empty frame.
    //
    // Height is the only thing the vertical field has to contain. The
    // horizontal still uses the radius in plan, because the scene turns: at
    // any yaw the longest thing across the frame is the diagonal of the
    // footprint.
    final size = bounds.size;
    final halfHeight = math.max(size.y / 2, 0.5);
    final planRadius = math.max(
        math.sqrt(size.x * size.x + size.z * size.z) / 2, 0.5);
    final vertical = halfHeight / math.tan(fieldOfView / 2);
    final horizontalFov = 2 * math.atan(math.tan(fieldOfView / 2) * aspectRatio);
    final horizontal = planRadius / math.tan(horizontalFov / 2);
    return Camera3(
      target: bounds.center,
      yaw: yaw,
      pitch: pitch,
      distance: math.max(vertical, horizontal) * margin,
      fieldOfView: fieldOfView,
    );
  }

  /// World point in camera space: the eye at the origin, looking down `-z`.
  Vector3 toViewSpace(Vector3 world) {
    final zAxis = (eye - target).normalized;
    final xAxis = const Vector3(0, 1, 0).cross(zAxis).normalized;
    final yAxis = zAxis.cross(xAxis);
    final d = world - eye;
    return Vector3(d.dot(xAxis), d.dot(yAxis), d.dot(zAxis));
  }
}

/// One polygon ready to be filled, in painter's pixels.

/// How a surface facing a given direction is lit.
///
/// One place, because two renderers use it — [SceneProjection] for the meshes
/// this project builds from a specification and `SceneRaster` for imported
/// models — and a trainee moving between a drawn vehicle and an imported one
/// must not see the light change.
///
/// It replaces a single sun plus a flat ambient floor. That floor was the
/// problem: every surface the sun did not reach came out at exactly the same
/// brightness, so a turret's whole shadowed half was one dead colour and the
/// shape in it disappeared. Real shade is not uniform — a surface turned
/// upwards catches the sky, one turned down catches what bounces off the
/// ground — and it is that difference which makes a casting read as round.
///
/// So there are three terms, and each carries a colour rather than only a
/// strength:
///
/// * a **key**, warm and directional, standing in for the sun;
/// * a **fill**, cool and weak, from the opposite side, so nothing is a
///   silhouette;
/// * a **hemisphere ambient** that fades from a cool sky above to a warm
///   ground bounce below.
///
/// The result is a multiplier per channel, which is what lets a lit face read
/// warm and a shaded one read cool at the same brightness. It is not a
/// physical model and does not claim to be: it is the cheapest arrangement
/// that makes a shape legible, and everything it does is a few dot products.
class SceneLighting {
  SceneLighting._();

  /// Down, from the observer's left and slightly behind them. Fixed in world
  /// space rather than to the camera, so orbiting moves the highlights across
  /// the armour and the shape reads.
  static final Vector3 keyDirection = const Vector3(-0.45, -1.0, -0.55).normalized;

  /// From the other side and lower, so the side the key misses is described
  /// rather than merely dark.
  static final Vector3 fillDirection = const Vector3(0.65, -0.35, 0.70).normalized;

  static const double keyR = 0.62, keyG = 0.585, keyB = 0.525;
  static const double fillR = 0.13, fillG = 0.155, fillB = 0.20;
  static const double skyR = 0.26, skyG = 0.295, skyB = 0.35;
  static const double groundR = 0.20, groundG = 0.175, groundB = 0.145;

  /// The per-channel multiplier for a surface whose outward normal is [n].
  ///
  /// [n] need not be normalised; a zero-length normal comes back as flat
  /// ambient rather than as a division by zero.
  static ({double r, double g, double b}) forNormal(Vector3 n) {
    final len = math.sqrt(n.x * n.x + n.y * n.y + n.z * n.z);
    if (len <= 0) return (r: skyR, g: skyG, b: skyB);
    final nx = n.x / len, ny = n.y / len, nz = n.z / len;
    return forUnitNormal(nx, ny, nz);
  }

  /// How sharply a surface catches the key light as a highlight.
  ///
  /// Nothing here is a physical reflectance; it is the difference between a
  /// track link reading as worn steel and reading as grey paint. Bare metal
  /// gets a highlight, painted armour barely any, timber and ballast none —
  /// and the highlight is what carries the shape of a curved part when the
  /// diffuse term has gone flat across it.
  static double specularFor(SurfaceMaterial material) {
    switch (material) {
      case SurfaceMaterial.trackLink:
      case SurfaceMaterial.railHead:
      case SurfaceMaterial.ironChock:
      case SurfaceMaterial.tieDownRing:
      case SurfaceMaterial.wireLashing:
        return 0.34;
      case SurfaceMaterial.driveSprocket:
      case SurfaceMaterial.roadWheel:
      case SurfaceMaterial.wagonWheel:
      case SurfaceMaterial.gunBarrel:
        return 0.20;
      case SurfaceMaterial.glazing:
        return 0.55;
      case SurfaceMaterial.hullArmour:
      case SurfaceMaterial.hullSide:
      case SurfaceMaterial.turret:
      case SurfaceMaterial.appliqueArmour:
      case SurfaceMaterial.fender:
      case SurfaceMaterial.wagonFrame:
        return 0.09;
      default:
        return 0.0;
    }
  }

  /// The same, for a normal already known to be unit length, taken as three
  /// doubles so a renderer walking typed arrays never has to build a
  /// [Vector3] per corner.
  ///
  /// [vx], [vy], [vz] are the unit direction from the surface back to the eye.
  /// Pass them with a non-zero [specular] to get a highlight; leave them out
  /// and the result is diffuse only, which is what a matte surface wants.
  static ({double r, double g, double b}) forUnitNormal(
    double nx,
    double ny,
    double nz, {
    double vx = 0,
    double vy = 0,
    double vz = 0,
    double specular = 0,
  }) {
    var key = -(nx * keyDirection.x + ny * keyDirection.y + nz * keyDirection.z);
    if (key < 0) key = 0;
    var fill = -(nx * fillDirection.x + ny * fillDirection.y + nz * fillDirection.z);
    if (fill < 0) fill = 0;

    // 1 straight up, 0 straight down.
    final up = 0.5 + 0.5 * ny;
    final ambR = groundR + (skyR - groundR) * up;
    final ambG = groundG + (skyG - groundG) * up;
    final ambB = groundB + (skyB - groundB) * up;

    var r = ambR + keyR * key + fillR * fill;
    var g = ambG + keyG * key + fillG * fill;
    var b = ambB + keyB * key + fillB * fill;

    if (specular > 0 && key > 0) {
      // Blinn-Phong: the halfway vector between the light and the eye. Raised
      // to the sixteenth by four squarings rather than by pow(), which at a
      // million and a half corners a frame is worth avoiding.
      var hx = -keyDirection.x + vx;
      var hy = -keyDirection.y + vy;
      var hz = -keyDirection.z + vz;
      final hl = math.sqrt(hx * hx + hy * hy + hz * hz);
      if (hl > 0) {
        hx /= hl;
        hy /= hl;
        hz /= hl;
        var d = nx * hx + ny * hy + nz * hz;
        if (d > 0) {
          d *= d;
          d *= d;
          d *= d;
          d *= d;
          final gloss = specular * d;
          // White, because a highlight is the light's own colour bouncing off
          // the surface rather than the surface's colour.
          r += gloss;
          g += gloss;
          b += gloss;
        }
      }
    }

    if (r > 1) r = 1;
    if (g > 1) g = 1;
    if (b > 1) b = 1;
    return (r: r, g: g, b: b);
  }

  /// What a surface drawn at an even brightness gets — a guide line on the
  /// deck has to read the same whichever way the scene is turned.
  static const ({double r, double g, double b}) flat = (r: 1.0, g: 1.0, b: 1.0);
}

class ProjectedFace {
  final List<ScreenPoint> points;

  /// Distance from the eye to the face centre. The renderer returns faces
  /// sorted by this, farthest first.
  final double depth;

  final SurfaceMaterial material;

  /// What [SceneLighting] returned for this face's normal: a multiplier per
  /// channel, each `0..1`. The painter multiplies its material colour by these
  /// and does no lighting of its own.
  final ({double r, double g, double b}) shade;

  final String? partId;

  const ProjectedFace({
    required this.points,
    required this.depth,
    required this.material,
    required this.shade,
    this.partId,
  });
}

/// Turns a [Mesh3] into a sorted list of screen polygons.
///
/// A painter's-algorithm renderer: back faces dropped, the rest sorted far to
/// near and filled in that order. It has the classic limitation — two long
/// faces that interpenetrate can sort wrongly — which is why the models are
/// built from many small separated solids. That is a cheap price for a
/// renderer with no dependency, no shader toolchain and no platform surface,
/// on machines where this trainer has to run offline.
class SceneProjection {
  SceneProjection._();

  /// The key light's direction, kept here because callers name it.
  /// [SceneLighting] owns what the lighting actually is.
  static Vector3 get defaultLight => SceneLighting.keyDirection;

  /// Anything closer than this to the eye is dropped rather than projected —
  /// it is behind or across the lens and would otherwise fling a polygon
  /// across the whole viewport.
  static const double _nearPlane = 0.05;

  static List<ProjectedFace> render(
    Mesh3 mesh, {
    required Camera3 camera,
    required double width,
    required double height,
    bool cullBackFaces = true,
  }) {
    if (mesh.isEmpty || width <= 0 || height <= 0) return const [];

    final eye = camera.eye;
    final zAxis = (eye - camera.target).normalized;
    final xAxis = const Vector3(0, 1, 0).cross(zAxis).normalized;
    final yAxis = zAxis.cross(xAxis);
    final scale = (height / 2) / math.tan(camera.fieldOfView / 2);
    final cx = width / 2;
    final cy = height / 2;

    final out = <ProjectedFace>[];
    for (final face in mesh.faces) {
      if (face.vertices.length < 3) continue;
      final centroid = face.centroid;
      final normal = face.normal;
      final toEye = eye - centroid;
      final facing = normal.dot(toEye);
      if (cullBackFaces && !face.doubleSided && facing <= 0) continue;

      // A double-sided surface is lit by whichever face the eye is on, so a
      // wire lashing seen from below is not a black line.
      final effectiveNormal = face.doubleSided && facing < 0 ? -normal : normal;
      final toEyeUnit = toEye.normalized;
      final shade = SceneLighting.forUnitNormal(
        effectiveNormal.x,
        effectiveNormal.y,
        effectiveNormal.z,
        vx: toEyeUnit.x,
        vy: toEyeUnit.y,
        vz: toEyeUnit.z,
        specular: SceneLighting.specularFor(face.material),
      );

      final points = <ScreenPoint>[];
      var clipped = false;
      for (final v in face.vertices) {
        final d = v - eye;
        final vz = d.dot(zAxis);
        final depth = -vz;
        if (depth <= _nearPlane) {
          clipped = true;
          break;
        }
        points.add((
          x: cx + d.dot(xAxis) * scale / depth,
          y: cy - d.dot(yAxis) * scale / depth,
        ));
      }
      if (clipped) continue;

      out.add(ProjectedFace(
        points: points,
        depth: (centroid - eye).length,
        material: face.material,
        shade: shade,
        partId: face.partId,
      ));
    }

    out.sort((a, b) => b.depth.compareTo(a.depth));
    return out;
  }

  /// Where a single world point lands on the drawing surface, or null when it
  /// is behind the lens. Used to hang a dimension label off a real point of
  /// the model instead of a guessed screen position.
  static ScreenPoint? project(
    Vector3 world, {
    required Camera3 camera,
    required double width,
    required double height,
  }) {
    final eye = camera.eye;
    final zAxis = (eye - camera.target).normalized;
    final xAxis = const Vector3(0, 1, 0).cross(zAxis).normalized;
    final yAxis = zAxis.cross(xAxis);
    final scale = (height / 2) / math.tan(camera.fieldOfView / 2);
    final d = world - eye;
    final depth = -d.dot(zAxis);
    if (depth <= _nearPlane) return null;
    return (
      x: width / 2 + d.dot(xAxis) * scale / depth,
      y: height / 2 - d.dot(yAxis) * scale / depth,
    );
  }
}
