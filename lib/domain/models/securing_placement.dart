import 'dart:math' as math;

/// A piece of securing gear the trainee has put on the wagon.
///
/// Until now the three-dimensional scene generated its blocks and wires
/// automatically at fixed positions, which made them scenery: they could be
/// looked at but not worked with. The handbook's plates, though, dimension
/// exactly one thing about a stop block — **how far it is seated from the
/// running gear** (10–15 cm for a tracked vehicle, 20–30 mm from a tyre's
/// outer face for a wheeled one) — and that is a distance, not a picture. A
/// piece the trainee can pick up and put down is what turns that dimension
/// into something they can get right or wrong.
enum SecuringPieceKind {
  /// The squared wood stop block (direg dörtgyraň agaç bölegi), laid with its
  /// long side across the wagon and its working face against the running gear.
  woodChock,

  /// The half-round transverse insert block the tracked plates seat between
  /// the road wheels.
  woodInsert,

  /// A packing / spacer board (ara goýulýan agaç).
  woodPacking,

  /// A squared side block, 100 x 100 x 2000 mm, laid along the inner and
  /// outer faces of the track. One of plate-02's two ways of restraining a
  /// tracked vehicle sideways.
  woodSideBlock,

  /// A bow-shaped iron staple nailed to the wagon floor against the inner
  /// face of the track — plate-02's other lateral restraint, twelve per
  /// vehicle in groups of three.
  staple,

  /// A KGUUB reusable universal chock.
  ironChock,

  /// An iron spur (demir spor, S-series): a bolted base plate with a raised
  /// comb that bites into the track.
  ironSpur,

  /// An iron stop-boot (demir basmak: KTP, KT-34, KT-137, KTT).
  ironChockBoot,

  /// One wire lashing run, from a point on the vehicle to a ring on the deck.
  wireLashing,
}

/// Which face of a block does the work, and therefore which way the wedge
/// points.
enum ChockFacing {
  /// The working face looks towards `+x` — the block sits behind the running
  /// gear and stops the vehicle moving that way.
  towardsFront,

  /// The working face looks towards `-x` — the block sits ahead of it.
  towardsRear,
}

/// One placed piece, in world metres on the wagon.
///
/// [x] is the position of the **working face**, not of the block's centre: the
/// working face is the one whose distance from the running gear the handbook
/// dimensions, so keeping it as the anchor means moving a block never changes
/// what is being measured. The body extends away from that face by [widthM].
class SecuringPiece {
  final String id;
  final SecuringPieceKind kind;

  /// Along the wagon. For a block, the working face; for a lashing, unused.
  final double x;

  /// Across the wagon, at the piece's centre.
  final double z;

  /// The block's dimension along the wagon — Table 3's chock *width*.
  final double widthM;

  /// Its height above the deck — Table 3's chock *height*.
  final double heightM;

  /// Its dimension across the wagon. Not a handbook figure: the plates size a
  /// block's cross-section and say its long side lies across the wagon, but
  /// give no length, so this follows the running gear it is seated against.
  final double lengthM;

  final ChockFacing facing;

  /// Which handbook table row this block's size came from — Table 3's weight
  /// bracket, e.g. `"up to 12.0 t"`. Null for a piece with no sized source.
  final String? sizeTypeCode;

  /// For [SecuringPieceKind.wireLashing]: the vehicle attachment point it
  /// runs from, and the deck ring it is made fast to.
  final int? eyeIndex;
  final int? ringIndex;

  /// Threads laid up in this lashing.
  final int threads;

  const SecuringPiece({
    required this.id,
    required this.kind,
    required this.x,
    required this.z,
    this.widthM = 0.2,
    this.heightM = 0.16,
    this.lengthM = 0.6,
    this.facing = ChockFacing.towardsFront,
    this.sizeTypeCode,
    this.eyeIndex,
    this.ringIndex,
    this.threads = 4,
  });

  bool get isBlock => kind != SecuringPieceKind.wireLashing;

  /// True for the pieces whose working face bears against the running gear,
  /// and whose distance from it is therefore a real quantity: the wood stop
  /// block and the three iron stop devices.
  ///
  /// Deliberately narrower than [isBlock]. A half-round insert is seated
  /// *between* the road wheels, a packing board is not seated against the
  /// running gear at all, a side block lies alongside it and a staple is
  /// nailed beside it — none of them has a seating distance. Measuring one
  /// anyway reported a metre-and-a-bit of "distance" on a piece lying exactly
  /// where plate-02 puts it.
  ///
  /// Note that being measured is not the same as being *judged*: plate-03's
  /// 10-15 cm range is written about the wood chock, and the KGUUB has a rule
  /// of its own (`rule-kguub-chock-spacing`, 0.5 m from where the track rests
  /// on the rail). Only [SecuringPieceKind.woodChock] is checked against the
  /// wood range — see `checkSeatingDistance`.
  bool get isStopBlock =>
      kind == SecuringPieceKind.woodChock ||
      kind == SecuringPieceKind.ironChock ||
      kind == SecuringPieceKind.ironSpur ||
      kind == SecuringPieceKind.ironChockBoot;

  /// True for the pieces plate-06 nails to the wagon floor.
  bool get isNailedDown =>
      kind == SecuringPieceKind.woodChock ||
      kind == SecuringPieceKind.woodSideBlock;

  /// `+1` when the working face looks towards `+x`.
  int get faceSign => facing == ChockFacing.towardsFront ? 1 : -1;

  /// The two ends of the piece along the wagon, working face first.
  ///
  /// A stop block is anchored on its **working face**, because that is the
  /// face whose distance from the running gear the plates dimension: moving
  /// the block then never changes what is being measured. Everything else is
  /// anchored on its **centre**, which is what dragging a two-metre side
  /// block by one end would otherwise make awkward.
  ({double face, double back}) get span => isStopBlock
      ? (face: x, back: x - faceSign * widthM)
      : (face: x + widthM / 2, back: x - widthM / 2);

  SecuringPiece copyWith({
    double? x,
    double? z,
    double? widthM,
    double? heightM,
    double? lengthM,
    ChockFacing? facing,
    String? sizeTypeCode,
    int? eyeIndex,
    int? ringIndex,
    int? threads,
  }) =>
      SecuringPiece(
        id: id,
        kind: kind,
        x: x ?? this.x,
        z: z ?? this.z,
        widthM: widthM ?? this.widthM,
        heightM: heightM ?? this.heightM,
        lengthM: lengthM ?? this.lengthM,
        facing: facing ?? this.facing,
        sizeTypeCode: sizeTypeCode ?? this.sizeTypeCode,
        eyeIndex: eyeIndex ?? this.eyeIndex,
        ringIndex: ringIndex ?? this.ringIndex,
        threads: threads ?? this.threads,
      );

  @override
  bool operator ==(Object other) =>
      other is SecuringPiece &&
      other.id == id &&
      other.kind == kind &&
      other.x == x &&
      other.z == z &&
      other.widthM == widthM &&
      other.heightM == heightM &&
      other.lengthM == lengthM &&
      other.facing == facing &&
      other.sizeTypeCode == sizeTypeCode &&
      other.eyeIndex == eyeIndex &&
      other.ringIndex == ringIndex &&
      other.threads == threads;

  @override
  int get hashCode => Object.hash(id, kind, x, z, widthM, heightM, lengthM,
      facing, sizeTypeCode, eyeIndex, ringIndex, threads);
}

/// Everything securing one vehicle to one wagon.
///
/// Immutable, and every edit returns a new layout, so the provider holding it
/// behaves like every other piece of state in this project and an undo could
/// be added without touching this class.
class SecuringLayout {
  final List<SecuringPiece> pieces;

  const SecuringLayout(this.pieces);

  static const SecuringLayout empty = SecuringLayout(<SecuringPiece>[]);

  bool get isEmpty => pieces.isEmpty;

  Iterable<SecuringPiece> get blocks => pieces.where((p) => p.isBlock);

  /// Only the pieces a seating distance is measured on. See
  /// [SecuringPiece.isStopBlock].
  Iterable<SecuringPiece> get stopBlocks => pieces.where((p) => p.isStopBlock);

  Iterable<SecuringPiece> get lashings =>
      pieces.where((p) => p.kind == SecuringPieceKind.wireLashing);

  int countOf(SecuringPieceKind kind) =>
      pieces.where((p) => p.kind == kind).length;

  SecuringPiece? byId(String id) {
    for (final piece in pieces) {
      if (piece.id == id) return piece;
    }
    return null;
  }

  SecuringLayout add(SecuringPiece piece) => SecuringLayout([...pieces, piece]);

  SecuringLayout remove(String id) =>
      SecuringLayout([for (final p in pieces) if (p.id != id) p]);

  SecuringLayout replace(SecuringPiece piece) => SecuringLayout([
        for (final p in pieces) if (p.id == piece.id) piece else p,
      ]);

  /// Moves one piece to a new spot on the deck.
  SecuringLayout moveTo(String id, {required double x, required double z}) {
    final piece = byId(id);
    if (piece == null) return this;
    return replace(piece.copyWith(x: x, z: z));
  }

  /// An id no piece in this layout is using.
  String nextId(SecuringPieceKind kind) {
    final prefix = kind.name;
    var n = 1;
    while (byId('$prefix-$n') != null) {
      n++;
    }
    return '$prefix-$n';
  }

  /// The block nearest a point on the deck, and how far away it is — how a
  /// tap finds the piece it meant even when it misses by a few centimetres.
  ({SecuringPiece piece, double distance})? nearestBlock(double x, double z) {
    ({SecuringPiece piece, double distance})? best;
    for (final piece in blocks) {
      final d = math.sqrt(math.pow(piece.x - x, 2) + math.pow(piece.z - z, 2));
      if (best == null || d < best.distance) best = (piece: piece, distance: d);
    }
    return best;
  }
}
