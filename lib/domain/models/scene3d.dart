import 'dart:math' as math;

/// Pure-Dart 3D geometry for the loading scene.
///
/// Deliberately free of any Flutter import, exactly like [SchematicElement]:
/// the domain layer decides *where the metal is* and *what kind of metal it
/// is*, and the painter decides what colour that gets drawn in. That split is
/// what lets the meshes be unit-tested on the plain Dart VM (`dart test`) with
/// no widget binding — see test/scene3d_test.dart.
///
/// **World frame**, used by every builder in this project and by the camera:
///
/// * `+x` runs along the track, towards the head of the train.
/// * `+y` is up. `y = 0` is the top of the rail head, so a vehicle's
///   ground clearance, the wagon's deck height and the loading gauge are all
///   read off the same zero the railway itself uses.
/// * `+z` is to the right when looking along `+x`.
///
/// Everything is in **metres**. Nothing here converts from the handbook's
/// centimetres: the callers do that once, at the edge, so a mesh can never be
/// built from a number whose unit is in doubt.
class Vector3 {
  final double x;
  final double y;
  final double z;

  const Vector3(this.x, this.y, this.z);

  static const zero = Vector3(0, 0, 0);

  Vector3 operator +(Vector3 other) => Vector3(x + other.x, y + other.y, z + other.z);
  Vector3 operator -(Vector3 other) => Vector3(x - other.x, y - other.y, z - other.z);
  Vector3 operator *(double s) => Vector3(x * s, y * s, z * s);
  Vector3 operator -() => Vector3(-x, -y, -z);

  double dot(Vector3 other) => x * other.x + y * other.y + z * other.z;

  Vector3 cross(Vector3 other) => Vector3(
        y * other.z - z * other.y,
        z * other.x - x * other.z,
        x * other.y - y * other.x,
      );

  double get length => math.sqrt(x * x + y * y + z * z);

  /// The unit vector in this direction, or [zero] for a zero-length vector —
  /// a degenerate face must not produce NaNs that then poison the depth sort.
  Vector3 get normalized {
    final l = length;
    return l == 0 ? zero : Vector3(x / l, y / l, z / l);
  }

  Vector3 lerp(Vector3 other, double t) =>
      Vector3(x + (other.x - x) * t, y + (other.y - y) * t, z + (other.z - z) * t);

  @override
  bool operator ==(Object other) =>
      other is Vector3 && other.x == x && other.y == y && other.z == z;

  @override
  int get hashCode => Object.hash(x, y, z);

  @override
  String toString() =>
      'Vector3(${x.toStringAsFixed(3)}, ${y.toStringAsFixed(3)}, ${z.toStringAsFixed(3)})';
}

/// What a surface *is*, not what colour it is.
///
/// Closed enum for the same reason [SchematicElementKind] is one: the painter
/// switches on it exhaustively, so adding a part to a mesh forces a decision
/// about how it is drawn instead of defaulting to a generic grey.
enum SurfaceMaterial {
  /// Sloped front and roof armour — the plates that catch the light.
  hullArmour,

  /// Vertical hull sides and the sponsons over the tracks.
  hullSide,

  /// The lower tub, between the track runs.
  hullBelly,

  /// Bolt-on reactive armour blocks.
  appliqueArmour,

  turret,
  gunBarrel,

  /// One link of the track band.
  trackLink,
  roadWheel,
  driveSprocket,

  /// Side skirts and mudguards.
  fender,

  /// Stowage: the rear fuel drums, the cupola.
  stowage,

  /// A tyre.
  tyre,

  /// Glass: a windscreen, a cab window.
  glazing,

  /// The canvas tilt over a lorry's cargo bed.
  tilt,

  /// The wagon's wooden load surface.
  deckPlank,

  /// The steel side sill and the folded-down side boards.
  deckEdge,

  /// Underframe, headstocks, couplers.
  wagonFrame,
  bogie,
  wagonWheel,

  railHead,
  sleeper,
  ballast,

  /// A wooden stop block (chock) nailed to the deck.
  woodChock,

  /// A KGUUB-type iron chock or an iron spur.
  ironChock,

  /// One run of a wire lashing.
  wireLashing,

  /// A deck ring the lashing is made fast to.
  tieDownRing,

  /// The outline drawn round the piece of gear the trainee has hold of.
  selectionMarker,

  /// A line laid on the deck showing where the running gear bears — what
  /// "under the tracks" actually means, so a block can be put there on
  /// purpose rather than by eye.
  guideLine,
}

/// A flat convex polygon.
///
/// Wound counter-clockwise seen **from outside the solid**, so [normal] points
/// out of the body. Every primitive in `mesh_primitives.dart` guarantees that,
/// and `test/scene3d_test.dart` holds them to it — get a winding backwards and
/// back-face culling punches a hole straight through the model.
class Face3 {
  final List<Vector3> vertices;
  final SurfaceMaterial material;

  /// Never culled, and lit from whichever side faces the camera. For surfaces
  /// with no inside: a wire run, a plate drawn as a single quad.
  final bool doubleSided;

  /// Which assembly this face belongs to — `'hull'`, `'turret'`, `'chock.1'`.
  /// Carried so a view can pick a part out (dim everything else, name what
  /// the pointer is over) without re-deriving it from geometry.
  final String? partId;

  /// One normal per corner, when the face came from a file that had them.
  ///
  /// Null for everything this project builds from a specification, and it
  /// should stay null there: those meshes are panels, and a panel wants the
  /// flat [normal] its own plane gives it. It is filled in for an imported
  /// model, where the surface is a curve approximated by thousands of small
  /// triangles — shade those from their own planes and a cast turret comes out
  /// as speckle rather than as a shape. See `SceneRaster`, which shades each
  /// corner separately when these are present.
  final List<Vector3>? vertexNormals;

  const Face3(
    this.vertices, {
    required this.material,
    this.doubleSided = false,
    this.partId,
    this.vertexNormals,
  });

  Vector3 get centroid {
    var sum = Vector3.zero;
    for (final v in vertices) {
      sum += v;
    }
    return sum * (1 / vertices.length);
  }

  /// Newell's method rather than one cross product of the first three
  /// vertices: it is the average over the whole polygon, so a face with a
  /// nearly-collinear leading corner — which the lofted turret produces —
  /// still yields the right normal instead of numerical noise.
  Vector3 get normal {
    var nx = 0.0, ny = 0.0, nz = 0.0;
    for (var i = 0; i < vertices.length; i++) {
      final a = vertices[i];
      final b = vertices[(i + 1) % vertices.length];
      nx += (a.y - b.y) * (a.z + b.z);
      ny += (a.z - b.z) * (a.x + b.x);
      nz += (a.x - b.x) * (a.y + b.y);
    }
    return Vector3(nx, ny, nz).normalized;
  }

  /// Maps the corner positions, leaving the corner normals alone.
  ///
  /// Correct for what this project does with it — translating a vehicle along
  /// the deck and scaling a model uniformly to the record — because neither
  /// turns a direction. A rotation would need [mapNormals] as well, which is
  /// why [ObjMeshLoader.reorient] calls both.
  Face3 mapVertices(Vector3 Function(Vector3) f) => Face3(
        vertices.map(f).toList(growable: false),
        material: material,
        doubleSided: doubleSided,
        partId: partId,
        vertexNormals: vertexNormals,
      );

  /// Maps the corner normals, leaving the positions alone.
  Face3 mapNormals(Vector3 Function(Vector3) f) => Face3(
        vertices,
        material: material,
        doubleSided: doubleSided,
        partId: partId,
        vertexNormals:
            vertexNormals?.map((n) => f(n).normalized).toList(growable: false),
      );

  /// The same polygon seen from the other side. Used when mirroring a mesh
  /// across the centre line: mirroring reverses the handedness, so without
  /// this the mirrored half would be inside-out.
  Face3 get flipped => Face3(
        vertices.reversed.toList(growable: false),
        material: material,
        doubleSided: doubleSided,
        partId: partId,
        vertexNormals: vertexNormals?.reversed.toList(growable: false),
      );
}

/// An axis-aligned box around some geometry — what the camera frames on and
/// what the overhang readouts are measured from.
class Bounds3 {
  final Vector3 min;
  final Vector3 max;

  const Bounds3(this.min, this.max);

  Vector3 get center => (min + max) * 0.5;
  Vector3 get size => max - min;

  /// Half the longest diagonal — the radius of a sphere that contains the
  /// whole thing, which is what a "fit this in view" camera distance is
  /// computed from.
  double get radius => (max - min).length / 2;

  Bounds3 union(Bounds3 other) => Bounds3(
        Vector3(math.min(min.x, other.min.x), math.min(min.y, other.min.y),
            math.min(min.z, other.min.z)),
        Vector3(math.max(max.x, other.max.x), math.max(max.y, other.max.y),
            math.max(max.z, other.max.z)),
      );
}

/// A bag of faces. No hierarchy: assemblies are composed by transforming a
/// mesh and merging it, and a face remembers where it came from via
/// [Face3.partId].
class Mesh3 {
  final List<Face3> faces;

  const Mesh3(this.faces);

  static const Mesh3 empty = Mesh3(<Face3>[]);

  bool get isEmpty => faces.isEmpty;

  Mesh3 operator +(Mesh3 other) => Mesh3([...faces, ...other.faces]);

  static Mesh3 merge(Iterable<Mesh3> meshes) =>
      Mesh3([for (final m in meshes) ...m.faces]);

  Mesh3 mapVertices(Vector3 Function(Vector3) f) =>
      Mesh3(faces.map((face) => face.mapVertices(f)).toList(growable: false));

  /// Maps every corner normal. Wanted wherever [mapVertices] turns the
  /// geometry rather than only moving or scaling it, since a rotation turns a
  /// direction too.
  Mesh3 mapNormals(Vector3 Function(Vector3) f) =>
      Mesh3(faces.map((face) => face.mapNormals(f)).toList(growable: false));

  Mesh3 translated(Vector3 delta) => mapVertices((v) => v + delta);

  Mesh3 scaled(double s) => mapVertices((v) => v * s);

  /// Rotated about the vertical axis through [about] — how the turret is
  /// traversed and how a vehicle is turned to face the other end of the train.
  Mesh3 rotatedY(double radians, {Vector3 about = Vector3.zero}) {
    final c = math.cos(radians);
    final s = math.sin(radians);
    return mapVertices((v) {
      final dx = v.x - about.x;
      final dz = v.z - about.z;
      return Vector3(about.x + dx * c + dz * s, v.y, about.z - dx * s + dz * c);
      // A rotation turns the normals too, so they go round with them.
    }).mapNormals((n) => Vector3(n.x * c + n.z * s, n.y, -n.x * s + n.z * c));
  }

  /// The other half of a symmetrical assembly: build one track run, get the
  /// second for nothing. Faces are flipped because mirroring reverses winding.
  Mesh3 mirroredZ() => Mesh3(faces
      .map((face) => face
          .mapVertices((v) => Vector3(v.x, v.y, -v.z))
          .mapNormals((n) => Vector3(n.x, n.y, -n.z))
          .flipped)
      .toList(growable: false));

  /// Every face re-tagged with [partId], for assemblies built from primitives
  /// that were not told their own name.
  Mesh3 taggedAs(String partId) => Mesh3(faces
      .map((f) => Face3(f.vertices,
          material: f.material,
          doubleSided: f.doubleSided,
          partId: partId,
          vertexNormals: f.vertexNormals))
      .toList(growable: false));

  Bounds3 get bounds {
    if (faces.isEmpty) return const Bounds3(Vector3.zero, Vector3.zero);
    var minX = double.infinity, minY = double.infinity, minZ = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity, maxZ = -double.infinity;
    for (final face in faces) {
      for (final v in face.vertices) {
        if (v.x < minX) minX = v.x;
        if (v.y < minY) minY = v.y;
        if (v.z < minZ) minZ = v.z;
        if (v.x > maxX) maxX = v.x;
        if (v.y > maxY) maxY = v.y;
        if (v.z > maxZ) maxZ = v.z;
      }
    }
    return Bounds3(Vector3(minX, minY, minZ), Vector3(maxX, maxY, maxZ));
  }
}
