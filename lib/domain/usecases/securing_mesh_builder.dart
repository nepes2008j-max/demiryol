import 'dart:math' as math;

import '../models/scene3d.dart';
import '../models/securing_placement.dart';
import 'flatcar_mesh_builder.dart';
import 'mesh_primitives.dart';
import 'vehicle_mesh_builder.dart';

/// The securing gear as solids on the wagon: the wood stop blocks butted
/// against the running gear, the half-round inserts, the packing, the iron
/// chocks, and the wire lashings run down to the deck rings.
///
/// Every piece is drawn from a [SecuringPiece] the trainee has placed, and
/// every piece's faces carry `securing.<id>` as their part id, so a ray cast
/// into the scene comes back with the id of the block the pointer is over.
/// That identification is the whole reason the gear is modelled piece by
/// piece rather than as one mesh: it is what lets the trainee pick a block up
/// and put it where they judge it should go.
///
/// Sizes are the caller's business, not this file's. The handbook decides
/// them (Table 3 for the wood blocks, Table 8 for the KGUUB chocks) and a
/// piece with no sized source is never invented here.
class SecuringVisual {
  final Mesh3 mesh;

  /// Blocks of every kind drawn.
  final int blockCount;

  /// Lashing runs drawn — one run is one wire from a point on the vehicle to
  /// a ring, whatever number of threads it is twisted from.
  final int lashingRunCount;

  const SecuringVisual({
    required this.mesh,
    required this.blockCount,
    required this.lashingRunCount,
  });

  static const SecuringVisual none =
      SecuringVisual(mesh: Mesh3.empty, blockCount: 0, lashingRunCount: 0);
}

/// Builds the gear in world coordinates for a vehicle standing at
/// [vehicleOffsetX] along [flatcar]'s deck.
///
/// [selectedPieceId] gets an outline on the deck around it, and
/// [showRunningGearGuides] lays a line along each track's bearing surface —
/// between them they answer "which one have I got hold of" and "where is
/// under the track", which are the two questions that make placing a block by
/// hand possible at all.
SecuringVisual buildSecuringVisual({
  required VehicleModel3 vehicle,
  required FlatcarModel3 flatcar,
  required double vehicleOffsetX,
  required SecuringLayout layout,
  String? selectedPieceId,
  bool showRunningGearGuides = false,
  /// Which placement this gear belongs to. It goes into every part id, because
  /// two vehicles on one wagon each number their pieces from one: without it
  /// both wrote `securing.woodChock-1`, and a click on one machine's block
  /// picked up the other machine's.
  String placementId = 'primary',
}) {
  final deck = flatcar.deckTopY;
  final parts = <Mesh3>[];
  var blocks = 0;
  var lashings = 0;

  if (showRunningGearGuides) {
    parts.add(_runningGearGuides(vehicle, vehicleOffsetX, deck));
  }

  for (final piece in layout.pieces) {
    final partId = securingPartId(placementId, piece.id);
    switch (piece.kind) {
      case SecuringPieceKind.woodChock:
        parts.add(_wedge(piece, deck, SurfaceMaterial.woodChock, partId));
        blocks++;
      case SecuringPieceKind.ironChock:
        parts.add(_platedStop(piece, deck, partId, riseM: _kguubRiseM));
        blocks++;
      case SecuringPieceKind.ironSpur:
      case SecuringPieceKind.ironChockBoot:
        // Both are a bolted base plate with something standing proud of it,
        // and for both the table states the plate and the rise, so the whole
        // height is real and nothing has to be assumed.
        parts.add(_platedStop(piece, deck, partId));
        blocks++;
      case SecuringPieceKind.woodSideBlock:
        parts.add(MeshPrimitives.box(
          corner: Vector3(piece.span.back, deck, piece.z - piece.lengthM / 2),
          opposite: Vector3(
              piece.span.face, deck + piece.heightM, piece.z + piece.lengthM / 2),
          material: SurfaceMaterial.woodChock,
          partId: partId,
        ));
        blocks++;
      case SecuringPieceKind.staple:
        parts.add(_staple(piece, deck, partId));
        blocks++;
      case SecuringPieceKind.woodPacking:
        parts.add(MeshPrimitives.box(
          corner: Vector3(piece.span.back, deck, piece.z - piece.lengthM / 2),
          opposite:
              Vector3(piece.span.face, deck + piece.heightM, piece.z + piece.lengthM / 2),
          material: SurfaceMaterial.woodChock,
          partId: partId,
        ));
        blocks++;
      case SecuringPieceKind.woodInsert:
        parts.add(_halfRound(piece, deck, partId));
        blocks++;
      case SecuringPieceKind.wireLashing:
        final run = _lashing(piece, vehicle, flatcar, vehicleOffsetX, deck, partId);
        if (run != null) {
          parts.add(run);
          lashings++;
        }
    }
    // plate-06 nails each wood block to the wagon floor; drawn so a block
    // reads as fixed down rather than resting on the deck.
    if (piece.isNailedDown) {
      parts.add(_nails(piece, deck, partId));
    }
    if (piece.id == selectedPieceId) {
      parts.add(_selectionOutline(piece, deck, vehicle, flatcar, vehicleOffsetX));
    }
  }

  return SecuringVisual(
    mesh: Mesh3.merge(parts),
    blockCount: blocks,
    lashingRunCount: lashings,
  );
}

/// The part id a piece's faces carry: the placement it belongs to and then
/// the piece. Parsed back by [placementOfPart] and [pieceOfPart].
String securingPartId(String placementId, String pieceId) =>
    'securing.$placementId.$pieceId';

/// The placement a securing part id belongs to, or null when the id is not
/// one — the guides and the selection outline are not pieces.
String? placementOfPart(String? partId) => _splitPart(partId)?.$1;

/// The piece a securing part id names, or null as above.
String? pieceOfPart(String? partId) => _splitPart(partId)?.$2;

(String, String)? _splitPart(String? partId) {
  if (partId == null || !partId.startsWith('securing.')) return null;
  final rest = partId.substring('securing.'.length);
  final dot = rest.indexOf('.');
  if (dot <= 0 || dot + 1 >= rest.length) return null;
  return (rest.substring(0, dot), rest.substring(dot + 1));
}

/// The squared stop block: a vertical working face against the running gear,
/// sloping away from it to a low heel. Its long side lies across the wagon,
/// the way the plates lay it.
Mesh3 _wedge(
  SecuringPiece piece,
  double deck,
  SurfaceMaterial material,
  String partId,
) {
  final face = piece.x;
  final back = piece.span.back;
  const heelHeight = 0.045;
  return MeshPrimitives.extrudeZ(
    [
      p2(face, deck),
      p2(back, deck),
      p2(back, deck + math.min(heelHeight, piece.heightM * 0.4)),
      p2(face, deck + piece.heightM),
    ],
    zMin: piece.z - piece.lengthM / 2,
    zMax: piece.z + piece.lengthM / 2,
    material: material,
    partId: partId,
  );
}

/// How far a KGUUB's stop stands above its base plate.
///
/// The reusable-chock table states the plate (280 x 240 x 10 mm for a
/// KGUUB-2G) and the pins that bite into the deck, but not the height of the
/// face that actually stops the track. This is therefore a drawing figure and
/// not a handbook one, which is why the piece is labelled with its type code
/// and its plate size and never with a height.
const double _kguubRiseM = 0.09;

/// A steel base plate with a stop standing proud of it: a KGUUB chock, an
/// iron spur's comb, an iron boot's upstand.
Mesh3 _platedStop(
  SecuringPiece piece,
  double deck,
  String partId, {
  double? riseM,
}) {
  final plateTop = riseM == null ? piece.heightM * 0.35 : piece.heightM;
  final rise = riseM ?? piece.heightM;
  final back = piece.span.back;
  final face = piece.span.face;
  final zMin = piece.z - piece.lengthM / 2;
  final zMax = piece.z + piece.lengthM / 2;
  return Mesh3.merge([
    // The plate, lying flat on the deck.
    MeshPrimitives.box(
      corner: Vector3(math.min(face, back), deck, zMin),
      opposite: Vector3(math.max(face, back), deck + plateTop, zMax),
      material: SurfaceMaterial.ironChock,
      partId: partId,
    ),
    // The stop itself, standing at the working face across the full width.
    MeshPrimitives.box(
      corner: Vector3(face - piece.faceSign * piece.widthM * 0.28, deck, zMin),
      opposite: Vector3(face, deck + plateTop + rise, zMax),
      material: SurfaceMaterial.ironChock,
      partId: partId,
    ),
  ]);
}

/// A bow-shaped iron staple: two legs driven into the wagon floor and the bow
/// between them, nailed against the inner face of the track.
Mesh3 _staple(SecuringPiece piece, double deck, String partId) {
  final r = piece.widthM / 2;
  final halfSpan = piece.lengthM / 2 - r;
  final top = deck + piece.heightM;
  final a = Vector3(piece.x, deck, piece.z - halfSpan);
  final b = Vector3(piece.x, deck, piece.z + halfSpan);
  return MeshPrimitives.rodPath(
    [a, Vector3(a.x, top, a.z), Vector3(b.x, top, b.z), b],
    radius: r,
    material: SurfaceMaterial.ironChock,
    segments: 6,
    partId: partId,
  );
}

/// The nails plate-06 fixes a wood block down with: four to a longitudinal
/// block, driven through it into the deck, with their heads left proud.
Mesh3 _nails(SecuringPiece piece, double deck, String partId) {
  const count = 4;
  final back = piece.span.back;
  final face = piece.span.face;
  final along = (face - back);
  final nails = <Mesh3>[];
  for (var i = 0; i < count; i++) {
    // Two down each side of the block, set in from its ends.
    final t = i < 2 ? 0.25 : 0.75;
    final z = piece.z + (i.isEven ? -1 : 1) * piece.lengthM * 0.3;
    final x = back + along * t;
    // The head sits just above the block at that point; the shank runs down
    // through it into the deck.
    final head = deck + piece.heightM * (piece.isStopBlock ? (1 - t) : 1.0) + 0.006;
    nails.add(MeshPrimitives.rod(
      a: Vector3(x, deck - 0.01, z),
      b: Vector3(x, head, z),
      radius: 0.006,
      material: SurfaceMaterial.ironChock,
      segments: 5,
      partId: partId,
    ));
  }
  return Mesh3.merge(nails);
}

/// The transverse half-round insert, lying across the wagon between the road
/// wheels: a half-cylinder resting flat on the deck.
Mesh3 _halfRound(SecuringPiece piece, double deck, String partId) {
  final r = piece.heightM;
  final cx = piece.x;
  return MeshPrimitives.extrudeZ(
    // The arc alone: it starts at one end of the base and finishes at the
    // other, and the polygon closes along the deck. Adding the base corners
    // as well would repeat those two points and leave zero-length edges.
    MeshPrimitives.arc(
      cx: cx,
      cy: deck,
      radius: r,
      fromAngle: 0,
      toAngle: math.pi,
      steps: 10,
    ),
    zMin: piece.z - piece.lengthM / 2,
    zMax: piece.z + piece.lengthM / 2,
    material: SurfaceMaterial.woodChock,
    partId: partId,
  );
}

/// One wire run, from an attachment point on the vehicle to a ring on the
/// deck. Returns null when either end no longer exists — a lashing whose ring
/// was never chosen is not drawn hanging in the air.
Mesh3? _lashing(
  SecuringPiece piece,
  VehicleModel3 vehicle,
  FlatcarModel3 flatcar,
  double vehicleOffsetX,
  double deck,
  String partId,
) {
  final eyeIndex = piece.eyeIndex;
  final ringIndex = piece.ringIndex;
  if (eyeIndex == null || eyeIndex >= vehicle.lashingEyes.length) return null;
  if (ringIndex == null || ringIndex >= flatcar.tieDownRings.length) return null;
  final eye = vehicle.lashingEyes[eyeIndex];
  final from = Vector3(eye.x + vehicleOffsetX, eye.y + deck, eye.z);
  final ring = flatcar.tieDownRings[ringIndex];
  final threads = math.max(1, piece.threads);
  return Mesh3.merge([
    for (var t = 0; t < threads; t++)
      MeshPrimitives.rod(
        a: Vector3(from.x, from.y, from.z + (t - (threads - 1) / 2) * 0.030),
        b: Vector3(ring.x, ring.y + 0.05, ring.z + (t - (threads - 1) / 2) * 0.018),
        radius: 0.011,
        material: SurfaceMaterial.wireLashing,
        segments: 5,
        partId: partId,
      ),
  ]);
}

/// A flat outline on the deck around the piece the trainee has hold of.
Mesh3 _selectionOutline(
  SecuringPiece piece,
  double deck,
  VehicleModel3 vehicle,
  FlatcarModel3 flatcar,
  double vehicleOffsetX,
) {
  if (piece.kind == SecuringPieceKind.wireLashing) {
    final ringIndex = piece.ringIndex;
    if (ringIndex == null || ringIndex >= flatcar.tieDownRings.length) {
      return Mesh3.empty;
    }
    final ring = flatcar.tieDownRings[ringIndex];
    return _outlineRect(
      x0: ring.x - 0.18,
      x1: ring.x + 0.18,
      z0: ring.z - 0.18,
      z1: ring.z + 0.18,
      y: deck + 0.004,
    );
  }
  final span = piece.span;
  const margin = 0.05;
  return _outlineRect(
    x0: math.min(span.face, span.back) - margin,
    x1: math.max(span.face, span.back) + margin,
    z0: piece.z - piece.lengthM / 2 - margin,
    z1: piece.z + piece.lengthM / 2 + margin,
    y: deck + 0.004,
  );
}

/// A hairline rectangle lying on the deck. Four thin slabs rather than a
/// stroked outline: the renderer fills polygons and has no pen.
Mesh3 _outlineRect({
  required double x0,
  required double x1,
  required double z0,
  required double z1,
  required double y,
  double thickness = 0.025,
  SurfaceMaterial material = SurfaceMaterial.selectionMarker,
  String partId = 'securing.selection',
}) {
  Mesh3 bar(double ax, double az, double bx, double bz) => MeshPrimitives.box(
        corner: Vector3(ax, y, az),
        opposite: Vector3(bx, y + 0.012, bz),
        material: material,
        partId: partId,
      );
  return Mesh3.merge([
    bar(x0, z0, x1, z0 + thickness),
    bar(x0, z1 - thickness, x1, z1),
    bar(x0, z0, x0 + thickness, z1),
    bar(x1 - thickness, z0, x1, z1),
  ]);
}

/// A line laid on the deck under each track, along the length it bears on.
///
/// Without it "under the track" is a judgement made by eye through a
/// perspective view, which is exactly the judgement a perspective view is
/// worst at. With it the trainee can see the bearing line they are seating a
/// block against.
Mesh3 _runningGearGuides(
  VehicleModel3 vehicle,
  double vehicleOffsetX,
  double deck,
) {
  final half = vehicle.spec.runningGearWidthM / 2;
  final wheels = vehicle.wheelContactX;
  return Mesh3.merge([
    for (final side in const [1, -1])
      if (wheels.isEmpty)
        // A track bears continuously, so the guide runs the length of it.
        _outlineRect(
          x0: vehicle.trackContactX.rear + vehicleOffsetX,
          x1: vehicle.trackContactX.front + vehicleOffsetX,
          z0: side * vehicle.trackCenterZ - half,
          z1: side * vehicle.trackCenterZ + half,
          y: deck + 0.002,
          thickness: 0.02,
          material: SurfaceMaterial.guideLine,
          partId: 'securing.guide',
        )
      else
        // A lorry bears at points. One guide per tyre, not a strip down the
        // whole vehicle: the strip said the machine bears everywhere along
        // its length, which is the opposite of what plate-06 is about when it
        // puts a chock under each wheel.
        for (final wheel in wheels)
          _outlineRect(
            x0: wheel + vehicleOffsetX - half,
            x1: wheel + vehicleOffsetX + half,
            z0: side * vehicle.trackCenterZ - half,
            z1: side * vehicle.trackCenterZ + half,
            y: deck + 0.002,
            thickness: 0.02,
            material: SurfaceMaterial.guideLine,
            partId: 'securing.guide',
          ),
  ]);
}
