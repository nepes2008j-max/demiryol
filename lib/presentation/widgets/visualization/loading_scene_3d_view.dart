import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/simulation_result.dart';
import '../../../domain/models/chock_arrangement.dart';
import '../../../domain/models/scene3d.dart';
import '../../../domain/models/securing_placement.dart';
import '../../../domain/usecases/flatcar_mesh_builder.dart';
import '../../../domain/usecases/loading_scene_builder.dart';
import '../../../domain/usecases/scene3d_camera.dart';
import '../../../domain/usecases/scene3d_raster.dart';
import '../../../domain/usecases/scene3d_picking.dart';
import '../../../domain/usecases/securing_hardware_catalog.dart';
import '../../../domain/usecases/securing_layout_builder.dart';
import '../../../domain/usecases/securing_mesh_builder.dart';
import '../../../domain/usecases/securing_measurements.dart';
import '../../../domain/usecases/securing_snap.dart';
import '../../../domain/usecases/vehicle_mesh_builder.dart';
import '../../../domain/usecases/wheeled_vehicle_mesh_builder.dart';
import '../../../data/models/handbook_photo.dart';
import '../common/handbook_reference_chip.dart';
import '../photos/handbook_photo_thumbnail.dart';
import 'scene3d_painter.dart';



/// Another vehicle standing on the same wagon.
///
/// Drawn and measured against, but not edited here: the view always works on
/// one placement at a time, and which one is a choice the screen already makes
/// (`selectedPlacementIdProvider`). Selecting the other vehicle in the list
/// swaps which is being worked on and which is a companion.
class SceneCompanion {
  final String placementId;
  final String designation;
  final VehicleMeshSpec spec;
  final double positionFraction;
  final double turretTraverse;
  final SecuringLayout layout;
  final Mesh3? meshOverride;

  const SceneCompanion({
    required this.placementId,
    required this.designation,
    required this.spec,
    this.positionFraction = 0.5,
    this.turretTraverse = 0.0,
    this.layout = SecuringLayout.empty,
    this.meshOverride,
  });
}

/// The loaded wagon in three dimensions, with the securing gear the trainee
/// can pick up and put where they judge it should go.
///
/// The scene answers what the flat views cannot: whether the machine sits
/// square on the deck, how far the gun reaches past the headstock, and — since
/// the gear became movable — whether a block is actually under the track and
/// how far off it is seated. That last one is the only dimension the handbook
/// gives about a stop block, and it is a distance, so it needs a scene built
/// from real metres and a block the trainee placed themselves. Both now exist.
///
/// What the view must never become is a source of verdicts it cannot support.
/// The measurements under the scene are readings; the seating-distance check
/// is a real handbook check only because the chosen [ChockArrangement] carries
/// a stated range, and where it carries none the check reports "not
/// determined" rather than inventing one.
class LoadingScene3DView extends StatefulWidget {
  /// The drawing surface itself, so a caller — or a test — can aim at a known
  /// point of the scene.
  static const Key surfaceKey = Key('loading-scene-3d-surface');

  /// The distance a piece will be placed at, chosen before it goes down.
  static const Key placeAtFieldKey = Key('loading-scene-3d-place-at');

  /// The distance the piece already on the deck is being adjusted to.
  static const Key seatingFieldKey = Key('loading-scene-3d-seating');

  final VehicleMeshSpec vehicleSpec;
  final FlatcarMeshSpec flatcarSpec;

  /// Which placement is being worked on.
  ///
  /// Held so the view can tell that it has been handed a *different* vehicle
  /// rather than an edit to the same one. Piece ids restart at one in every
  /// layout, so without it a selection made on one machine stayed selected
  /// when the trainee switched to the other — and then pointed at that
  /// machine's block of the same name.
  final String placementId;

  /// The vehicle's handbook designation, for the caption.
  final String designation;

  /// The other vehicles on the same wagon. Drawn, and the space between them
  /// measured, but edited by selecting them rather than here.
  final List<SceneCompanion> companions;

  /// What the plates require between this vehicle and its neighbour, in
  /// millimetres — 100 between two tracked vehicles on one flatcar. Null when
  /// the extract fixes none for the pair.
  final int? requiredClearanceMm;

  /// A model file loaded for this vehicle and already fitted to its recorded
  /// dimensions, to draw instead of the built one. Null draws the built one,
  /// which is what every vehicle without a file does.
  final Mesh3? vehicleMesh;

  /// The credit the model file is redistributed under. Shown under the scene
  /// whenever [vehicleMesh] is drawn — the licence requires it, and a reader
  /// is owed the difference between a model somebody made and a shape this
  /// application derived from a table.
  final String? vehicleMeshCredit;

  /// The gear as placed. Empty starts the trainee off at the handbook
  /// arrangement rather than on a bare deck.
  final SecuringLayout layout;

  /// Called whenever the trainee adds, moves, turns or removes a piece.
  ///
  /// The view holds no layout of its own: every edit is handed back here and
  /// comes round again through [layout]. Leaving this null therefore makes the
  /// scene **read-only** — an edit is computed, handed to nobody and lost.
  /// That is a legitimate way to use it for display, and a trap if editing was
  /// what you wanted, so it is spelled out rather than left to be discovered.
  final ValueChanged<SecuringLayout>? onLayoutChanged;

  /// Everything the trainee can put on the wagon, each at the size the
  /// handbook gives it: every stop-block weight bracket, the half-round
  /// insert, the side block, the staple, the packing board, both KGUUB
  /// variants, all eleven iron spurs and all four stop-boots.
  ///
  /// Empty means no piece has a stated size — nothing can be added, and the
  /// view says why rather than offering a solid of invented dimensions.
  final List<PlaceableHardware> hardware;

  /// The handbook's figures for a paragraph, used to show the trainee what the
  /// piece they are about to place actually looks like — 15.13 for the iron
  /// spurs, 15.14 for the stop-boots, and so on. A callback rather than a
  /// provider read, so this view stays a widget that draws what it is handed.
  /// Null draws no figures, which is what a caller with no reference index
  /// does.
  final List<HandbookPhoto> Function(String referenceId)? figuresFor;

  /// The arrangement the trainee has **chosen**, whose stated seating distance
  /// the placed blocks are checked against. Null leaves the distance measured
  /// but unchecked — which is the normal state for a tracked vehicle, since
  /// the case is chosen by combat weight and nothing may pre-select one for
  /// them.
  final ChockArrangement? arrangement;

  /// Where snapping seats a block, in metres off the running gear. The caller
  /// takes it from the seating distance the handbook's arrangements state, so
  /// the assist lands on a documented position rather than a round number of
  /// this widget's choosing. Null falls back to the midpoint of the tracked
  /// plates' 10–15 cm.
  final double? snapSeatingDistanceM;

  /// Threads in one wire lashing, from Table 7. Null draws a plain two-strand
  /// wire and says the thread count is not determined.
  final int? lashingThreads;

  /// How many wire lashings the handbook requires, when the weight resolves a
  /// count. Null lays out one run per attachment point, marked indicative.
  final int? lashingRunCount;

  /// Where along the deck the vehicle starts: 0 hard against the rear end,
  /// 1 hard against the front.
  final double initialPositionFraction;

  /// Called when the trainee slides the vehicle, so the flat views can follow.
  final ValueChanged<double>? onPositionChanged;

  const LoadingScene3DView({
    super.key,
    required this.vehicleSpec,
    required this.flatcarSpec,
    this.placementId = 'primary',
    required this.designation,
    this.companions = const [],
    this.requiredClearanceMm,
    this.vehicleMesh,
    this.vehicleMeshCredit,
    this.layout = SecuringLayout.empty,
    this.onLayoutChanged,
    this.hardware = const [],
    this.figuresFor,
    this.arrangement,
    this.snapSeatingDistanceM,
    this.lashingThreads,
    this.lashingRunCount,
    this.initialPositionFraction = 0.5,
    this.onPositionChanged,
  });

  @override
  State<LoadingScene3DView> createState() => _LoadingScene3DViewState();
}

/// What a drag on the drawing surface is doing.
enum _DragMode { orbit, movePiece }

/// The scene's name for the placement this view is editing. The companions
/// carry their own placement ids, which is what keeps their pieces from being
/// picked up by mistake.
const String _primaryPlacementId = 'primary';

class _LoadingScene3DViewState extends State<LoadingScene3DView> {
  static const _defaultYaw = 0.62;
  static const _defaultPitch = 0.28;

  double _yaw = _defaultYaw;
  double _pitch = _defaultPitch;
  double _zoom = 1.0;
  late double _position = widget.initialPositionFraction;
  double _traverse = 0.0;

  bool _showLashings = true;
  bool _showTrackBed = true;
  /// A hairline along every polygon edge is what separates one track link
  /// from the next on the meshes this project builds from a specification:
  /// those are coarse enough that one face is one panel, and without the
  /// hairlines the running gear reads as a single dark mass.
  ///
  /// An imported model is the opposite case. At twenty-odd thousand faces the
  /// same hairlines cover the armour in a web of scribbles and bury the
  /// shading that gives a turret casting its shape — the model already carries
  /// the detail the edges were standing in for. So the default follows the
  /// geometry rather than being fixed, and the control in the panel below
  /// still overrides it either way.
  /// Null until the trainee touches the control, so the default can follow the
  /// mesh. It has to be read on every build rather than settled once: the model
  /// arrives from an asynchronous provider, so the first build of this view
  /// runs with no mesh at all and a value fixed there would always be the
  /// drawn-mesh default.
  bool? _drawEdgesChosen;

  bool get _drawEdges =>
      _drawEdgesChosen ??
      (widget.vehicleMesh?.faces.length ?? 0) < _edgeHairlineFaceLimit;

  /// Above this many faces in the vehicle mesh, edges are off by default.
  /// Set from what the drawn meshes actually cost: a built T-72 is around two
  /// thousand faces, so anything an order of magnitude past that is an
  /// imported model.
  static const int _edgeHairlineFaceLimit = 12000;

  bool _showGuides = true;
  bool _snapToRun = true;
  bool _showVehicle = true;

  String? _selectedPieceId;

  /// Which palette entry the "put on the wagon" button will place. Held as
  /// the entry's own label so it survives the list being rebuilt.
  String? _hardwareKey;

  /// How far off the running gear a newly placed stop block is seated, in
  /// centimetres. Chosen before the piece goes down, because that is the
  /// order the job is done in: you pick the block, you know the distance the
  /// plate calls for, and then you set it.
  double? _placeAtCm;

  _DragMode _dragMode = _DragMode.orbit;

  double _dragYaw = 0;
  double _dragPitch = 0;
  double _pinchZoom = 1;

  LoadingScene3? _scene;
  List<Object?>? _sceneKey;

  static String _keyOf(PlaceableHardware h) => '${h.kind.name}|${h.typeCode}';

  /// The palette entry that will be placed: the trainee's choice, else the
  /// row the vehicle's own record resolves, else the first row offered.
  PlaceableHardware? get _activeHardware {
    if (widget.hardware.isEmpty) return null;
    for (final h in widget.hardware) {
      if (_keyOf(h) == _hardwareKey) return h;
    }
    for (final h in widget.hardware) {
      if (h.matchesVehicle) return h;
    }
    return widget.hardware.first;
  }

  /// The distance a snapped block is seated at.
  double get _seatingDistanceM =>
      widget.snapSeatingDistanceM ?? SecuringLayoutBuilder.defaultSeatingDistanceM;

  /// The gear on the wagon — nothing until the trainee puts something there.
  ///
  /// The deck starts **empty** on purpose. It used to open with the
  /// handbook's own arrangement already nailed down, which was the wrong way
  /// round for a trainer used as a test: it handed the trainee the answer and
  /// left them nothing to do but agree with it. They now choose the piece,
  /// choose the distance, and put it down themselves — which is also what
  /// makes the result sheet's comparison mean anything.
  ///
  /// [SecuringLayoutBuilder.handbookArrangement] still exists and is still
  /// what the plates call for; it is simply not applied on the trainee's
  /// behalf.
  SecuringLayout get _effectiveLayout => widget.layout;

  LoadingGeometry get _geometry => resolveLoadingGeometry(
        vehicleSpec: widget.vehicleSpec,
        flatcarSpec: widget.flatcarSpec,
        positionFraction: _position,
        turretTraverse: _traverse,
      );

  LoadingScene3 _sceneFor(SecuringLayout layout) => buildLoadedWagonScene(
        loads: [
          PlacedLoad(
            placementId: _primaryPlacementId,
            designation: widget.designation,
            spec: widget.vehicleSpec,
            positionFraction: _position,
            turretTraverse: _traverse,
            meshOverride: widget.vehicleMesh,
            securing:
                _showLashings ? layout : SecuringLayout([...layout.blocks]),
          ),
          // The other machines on this wagon, drawn where they stand with
          // their own gear, so the space between them is a real measurement
          // rather than something the trainee has to imagine.
          for (final companion in widget.companions)
            PlacedLoad(
              placementId: companion.placementId,
              designation: companion.designation,
              spec: companion.spec,
              positionFraction: companion.positionFraction,
              turretTraverse: companion.turretTraverse,
              meshOverride: companion.meshOverride,
              securing: _showLashings
                  ? companion.layout
                  : SecuringLayout([...companion.layout.blocks]),
            ),
        ],
        flatcarSpec: widget.flatcarSpec,
        includeTrackBed: _showTrackBed,
        includeVehicles: _showVehicle,
        selectedPieceId: _selectedPieceId,
        showRunningGearGuides: _showGuides,
      );

  LoadingScene3 get _currentScene {
    final layout = _effectiveLayout;
    // Compared field by field rather than by a hash: a hash collision would
    // silently leave a stale wagon on screen.
    final key = <Object?>[
      _position,
      _traverse,
      _showLashings,
      _showTrackBed,
      _showGuides,
      _showVehicle,
      _selectedPieceId,
      widget.vehicleMesh,
      widget.vehicleSpec.hullLengthM,
      for (final c in widget.companions) ...[
        c.placementId, c.positionFraction, c.turretTraverse,
        for (final piece in c.layout.pieces) ...[piece.id, piece.x, piece.z],
      ],
      widget.flatcarSpec.deckLengthM,
      widget.flatcarSpec.deckWidthM,
      widget.flatcarSpec.deckHeightM,
      for (final piece in layout.pieces) ...[
        piece.id, piece.x, piece.z, piece.widthM, piece.heightM,
        piece.lengthM, piece.facing, piece.ringIndex, piece.threads,
      ],
    ];
    final cached = _scene;
    if (cached != null && listEquals(key, _sceneKey)) return cached;
    final built = _sceneFor(layout);
    _scene = built;
    _sceneKey = key;
    return built;
  }

  @override
  void didUpdateWidget(LoadingScene3DView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The trainee can also move the vehicle by dragging the flat views, which
    // reaches this widget as a new starting fraction. Following it keeps the
    // views of one wagon from drifting apart.
    final incoming = widget.initialPositionFraction;
    if (incoming != oldWidget.initialPositionFraction &&
        (incoming - _position).abs() > 1e-6) {
      _position = incoming;
    }
    // A different vehicle is a different set of pieces, whatever they are
    // called.
    if (widget.placementId != oldWidget.placementId) {
      _selectedPieceId = null;
    }
    // And a piece that has been removed — by a reset, or by the placement
    // being cleared — must not stay selected.
    if (_selectedPieceId != null &&
        widget.layout.byId(_selectedPieceId!) == null &&
        !widget.layout.isEmpty) {
      _selectedPieceId = null;
    }
  }

  void _commit(SecuringLayout layout) {
    widget.onLayoutChanged?.call(layout);
    setState(() {});
  }

  void _addSelectedHardware() {
    final chosen = _activeHardware;
    if (chosen == null) return;
    _addPiece(chosen.kind, chosen);
  }

  void _addPiece(SecuringPieceKind kind, [PlaceableHardware? chosen]) {
    final geometry = _geometry;
    final layout = _effectiveLayout;
    if (kind == SecuringPieceKind.wireLashing) {
      final runs = SecuringLayoutBuilder.defaultLashings(
        vehicle: geometry.vehicle,
        flatcar: geometry.flatcar,
        vehicleOffsetX: geometry.vehicleOffsetX,
        runs: layout.countOf(kind) + 1,
        threads: widget.lashingThreads ?? 2,
      );
      if (runs.length <= layout.countOf(kind)) return;
      final piece = runs.last.copyWith();
      final added = SecuringPiece(
        id: layout.nextId(kind),
        kind: kind,
        x: piece.x,
        z: piece.z,
        eyeIndex: piece.eyeIndex,
        ringIndex: piece.ringIndex,
        threads: piece.threads,
        // The wire's own diameter, so a piece always names the row it came
        // from — a lashing is no more anonymous than a stop block.
        sizeTypeCode: chosen?.typeCode,
      );
      _selectedPieceId = added.id;
      _commit(layout.add(added));
      return;
    }
    final piece = SecuringLayoutBuilder.newPiece(
      layout: layout,
      kind: kind,
      vehicle: geometry.vehicle,
      vehicleOffsetX: geometry.vehicleOffsetX,
      heightM: chosen?.heightM,
      widthM: chosen?.widthM,
      lengthM: chosen?.lengthM,
      sizeTypeCode: chosen?.typeCode,
      seatingDistanceM: _seatingDistanceM,
    );
    // Seated at the distance chosen in the palette, if one was, and against
    // whichever end of the bearing length it landed nearest.
    final cm = _placeAtCm;
    var placed = piece;
    if (cm != null && piece.isStopBlock) {
      final seating = measureBlockSeating(
        layout: SecuringLayout([piece]),
        vehicle: geometry.vehicle,
        vehicleOffsetX: geometry.vehicleOffsetX,
      ).firstOrNull;
      if (seating != null) {
        placed = piece.copyWith(
          x: xForSeatingDistance(
            seating: seating,
            vehicle: geometry.vehicle,
            vehicleOffsetX: geometry.vehicleOffsetX,
            distanceM: cm / 100,
          ),
        );
      }
    }
    _selectedPieceId = placed.id;
    _commit(layout.add(placed));
  }

  void _removeSelected() {
    final id = _selectedPieceId;
    if (id == null) return;
    _selectedPieceId = null;
    _commit(_effectiveLayout.remove(id));
  }

  /// Moves the selected piece by whole centimetres.
  ///
  /// [alongCm] runs down the wagon and [acrossCm] over it. The snap assist is
  /// deliberately not applied: a trainee stepping a block a centimetre at a
  /// time has said exactly where they want it, and having it jump back to the
  /// assist's idea of the right place would make the control useless.
  void _nudgeSelected({double alongCm = 0, double acrossCm = 0}) {
    final id = _selectedPieceId;
    final layout = _effectiveLayout;
    final piece = id == null ? null : layout.byId(id);
    if (piece == null || !piece.isBlock) return;
    _commit(layout.replace(piece.copyWith(
      x: piece.x + alongCm / 100,
      z: piece.z + acrossCm / 100,
    )));
  }

  /// Seats the selected stop block exactly [cm] centimetres from the end of
  /// the bearing length it is against — the figure the plate dimensions.
  void _setSeatingDistance(double cm) {
    final id = _selectedPieceId;
    final layout = _effectiveLayout;
    final piece = id == null ? null : layout.byId(id);
    if (piece == null || !piece.isStopBlock) return;
    final geometry = _geometry;
    final seating = measureBlockSeating(
      layout: SecuringLayout([piece]),
      vehicle: geometry.vehicle,
      vehicleOffsetX: geometry.vehicleOffsetX,
    ).firstOrNull;
    if (seating == null) return;
    _commit(layout.replace(piece.copyWith(
      x: xForSeatingDistance(
        seating: seating,
        vehicle: geometry.vehicle,
        vehicleOffsetX: geometry.vehicleOffsetX,
        distanceM: cm / 100,
      ),
    )));
  }

  /// Puts the selected block on the centre line of the track it is nearest,
  /// exactly. The lateral offset the plate cares about is zero.
  void _centreOnRun() {
    final id = _selectedPieceId;
    final layout = _effectiveLayout;
    final piece = id == null ? null : layout.byId(id);
    if (piece == null || !piece.isBlock) return;
    final trackZ = _geometry.vehicle.trackCenterZ;
    _commit(layout.replace(
        piece.copyWith(z: piece.z >= 0 ? trackZ : -trackZ)));
  }

  void _flipSelected() {
    final id = _selectedPieceId;
    final layout = _effectiveLayout;
    final piece = id == null ? null : layout.byId(id);
    if (piece == null || !piece.isBlock) return;
    _commit(layout.replace(piece.copyWith(
      facing: piece.facing == ChockFacing.towardsFront
          ? ChockFacing.towardsRear
          : ChockFacing.towardsFront,
    )));
  }

  void _resetLayout() {
    _selectedPieceId = null;
    // Handing back an empty layout puts the placement back on the handbook
    // arrangement, which `_effectiveLayout` rebuilds from the current
    // position of the vehicle rather than from where it used to stand.
    _commit(SecuringLayout.empty);
  }

  void _resetView() => setState(() {
        _yaw = _defaultYaw;
        _pitch = _defaultPitch;
        _zoom = 1.0;
      });

  /// The id of the piece a pick landed on, or null for sky, deck, vehicle —
  /// or for a piece belonging to one of the *other* machines on this wagon.
  ///
  /// The placement is part of the id because two vehicles on one wagon each
  /// number their pieces from one. Without it, clicking the companion's first
  /// stop block selected this vehicle's first stop block and then moved it.
  String? _pieceIdOf(ScenePick? pick) {
    if (placementOfPart(pick?.partId) != _primaryPlacementId) return null;
    final id = pieceOfPart(pick?.partId);
    if (id == null) return null;
    return _effectiveLayout.byId(id) == null ? null : id;
  }

  void _onTapPick(ScenePick? pick) {
    final id = _pieceIdOf(pick);
    if (id == _selectedPieceId) return;
    setState(() => _selectedPieceId = id);
  }

  void _onGestureStart(ScenePick? pick, Vector3? deckPoint) {
    _dragYaw = _yaw;
    _dragPitch = _pitch;
    _pinchZoom = _zoom;
    final pieceId = _pieceIdOf(pick);
    if (pieceId != null) {
      setState(() {
        _selectedPieceId = pieceId;
        _dragMode = _DragMode.movePiece;
      });
    } else {
      _dragMode = _DragMode.orbit;
    }
  }

  void _onGestureUpdate(double dx, double dy, double scale, Vector3? deckPoint) {
    if (_dragMode == _DragMode.movePiece) {
      _movePieceTo(deckPoint);
      return;
    }
    setState(() {
      _yaw = _dragYaw - dx * 0.006;
      // Dragging up raises the eye, so the trainee pulls the view up to look
      // down onto the deck — the same direction the hand moves. Held between
      // just above the rail head and almost overhead.
      _pitch = (_dragPitch - dy * 0.005).clamp(-0.05, 1.30);
      _zoom = (_pinchZoom * scale).clamp(0.45, 4.0);
    });
  }

  void _onGestureEnd() {
    // Selection is the tap recogniser's business; an orbit that happened to
    // start over empty deck must not clear what the trainee had selected.
    _dragMode = _DragMode.orbit;
  }

  void _movePieceTo(Vector3? deckPoint) {
    final id = _selectedPieceId;
    if (id == null || deckPoint == null) return;
    final layout = _effectiveLayout;
    final piece = layout.byId(id);
    if (piece == null) return;
    final geometry = _geometry;

    if (piece.kind == SecuringPieceKind.wireLashing) {
      // A wire is made fast to a ring or to nothing, so its loose end chooses
      // among the rings that exist rather than landing anywhere on the deck —
      // and on a wagon with no rings at all there is nothing to choose.
      if (geometry.flatcar.tieDownRings.isEmpty) return;
      final ringIndex = SecuringSnap.nearestRingIndex(
          geometry.flatcar, deckPoint.x, deckPoint.z);
      if (ringIndex == piece.ringIndex) return;
      final ring = geometry.flatcar.tieDownRings[ringIndex];
      _commit(layout.replace(
          piece.copyWith(ringIndex: ringIndex, x: ring.x, z: ring.z)));
      return;
    }

    final snap = SecuringSnap.forBlock(
      piece: piece,
      x: deckPoint.x,
      z: deckPoint.z,
      vehicle: geometry.vehicle,
      flatcarSpec: widget.flatcarSpec,
      vehicleOffsetX: geometry.vehicleOffsetX,
      seatingDistanceM: _seatingDistanceM,
      enabled: _snapToRun,
    );
    if (snap.x == piece.x && snap.z == piece.z && snap.facing == piece.facing) {
      return;
    }
    _commit(layout.replace(
        piece.copyWith(x: snap.x, z: snap.z, facing: snap.facing)));
  }

  @override
  Widget build(BuildContext context) {
    final scene = _currentScene;
    final layout = _effectiveLayout;
    final seatings = measureBlockSeating(
      layout: layout,
      vehicle: scene.vehicle,
      vehicleOffsetX: scene.vehicleOffsetX,
    );
    final selected = _selectedPieceId == null ? null : layout.byId(_selectedPieceId!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppStrings.scene3dTitle.toUpperCase(),
              style: AppText.legend(),
            ),
            const SizedBox(width: 12),
            // Expanded rather than a Spacer plus a fixed Text: on a narrow
            // window the count is what gives way, not the layout.
            Expanded(
              child: Text(
                AppStrings.scene3dPieceCount(
                    layout.blocks.length, layout.lashings.length),
                textAlign: TextAlign.right,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: AppText.caption, color: AppColors.textSecondary),
              ),
            ),
            const SizedBox(width: 8),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text(AppStrings.scene3dResetView),
              onPressed: _resetView,
            ),
          ],
        ),
        const SizedBox(height: 6),
        _SceneSurface(
          scene: scene,
          yaw: _yaw,
          pitch: _pitch,
          zoom: _zoom,
          drawEdges: _drawEdges,
          onTap: _onTapPick,
          onGestureStart: _onGestureStart,
          onGestureUpdate: _onGestureUpdate,
          onGestureEnd: _onGestureEnd,
          onScroll: (delta) =>
              setState(() => _zoom = (_zoom * (delta > 0 ? 0.90 : 1.11)).clamp(0.45, 4.0)),
        ),
        const SizedBox(height: 4),
        const Text(
          AppStrings.scene3dDragHint,
          style: TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),
        _EditBar(
          hardware: widget.hardware,
          active: _activeHardware,
          placeAtCm: _placeAtCm,
          suggestedCm: widget.arrangement?.seatingDistance == null
              ? null
              : (widget.arrangement!.seatingDistance!.minCm +
                      widget.arrangement!.seatingDistance!.maxCm) /
                  2,
          range: widget.arrangement?.seatingDistance,
          onPlaceAtChanged: (cm) => setState(() => _placeAtCm = cm),
          wheeled: widget.vehicleSpec is WheeledVehicleMeshSpec,
          figuresFor: widget.figuresFor,
          hasSelection: selected != null,
          selectionIsBlock: selected?.isBlock ?? false,
          onAdd: _addSelectedHardware,
          onRemove: _removeSelected,
          onFlip: _flipSelected,
          onReset: _resetLayout,
          onHardwareChanged: (key) => setState(() => _hardwareKey = key),
        ),
        if (layout.isEmpty) ...[
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.panel,
              border: Border.all(color: AppColors.labelDim),
              borderRadius: BorderRadius.zero,
            ),
            child: const Text(
              AppStrings.scene3dEmptyDeckHint,
              style: TextStyle(
                  fontSize: AppText.bodySmall, color: AppColors.textSecondary),
            ),
          ),
        ],
        const SizedBox(height: 8),
        _SelectedPanel(
          piece: selected,
          seating: selected == null
              ? null
              : seatings.where((s) => s.pieceId == selected.id).firstOrNull,
          arrangement: widget.arrangement,
          vehicleOffsetX: scene.vehicleOffsetX,
          onNudge: _nudgeSelected,
          onSeatingDistance: _setSeatingDistance,
          onCentreOnRun: _centreOnRun,
        ),
        if (!_showVehicle) ...[
          const SizedBox(height: 6),
          const Text(
            AppStrings.scene3dVehicleHiddenNote,
            style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal),
          ),
        ],
        const SizedBox(height: 10),
        _Controls(
          position: _position,
          traverse: _traverse,
          showLashings: _showLashings,
          showTrackBed: _showTrackBed,
          drawEdges: _drawEdges,
          showGuides: _showGuides,
          snapToRun: _snapToRun,
          showVehicle: _showVehicle,
          // A lorry has no gun to traverse, so it is not offered the control.
          gunOverhangs: widget.vehicleSpec.lengthOverGunM >
              widget.vehicleSpec.hullLengthM,
          onPosition: (v) {
            setState(() => _position = v);
            widget.onPositionChanged?.call(v);
          },
          onTraverse: (v) => setState(() => _traverse = v),
          onToggle: (which, value) => setState(() {
            switch (which) {
              case _Toggle.lashings:
                _showLashings = value;
              case _Toggle.trackBed:
                _showTrackBed = value;
              case _Toggle.edges:
                _drawEdgesChosen = value;
              case _Toggle.guides:
                _showGuides = value;
              case _Toggle.snap:
                _snapToRun = value;
              case _Toggle.vehicle:
                _showVehicle = value;
            }
          }),
        ),
        const SizedBox(height: 10),
        _Readouts(
          clearances: scene.clearances,
          designation: widget.designation,
          blockCount: layout.blocks.length,
          // Counted as drawn, not as held: a caption about the wire lashings
          // is noise while the wire lashings are switched off.
          lashingCount: _showLashings ? layout.lashings.length : 0,
          chockSizeKnown:
              widget.hardware.any((h) => h.kind == SecuringPieceKind.woodChock &&
                  h.matchesVehicle),
          sizeOptionsExist: widget.hardware.isNotEmpty,
          lashingCountKnown: widget.lashingRunCount != null,
          lashingThreads: widget.lashingThreads,
          wagonGeometryIsDefault: widget.flatcarSpec.isDefaultGeometry,
          modelCredit: widget.vehicleMeshCredit,
          gaps: scene.gaps,
          requiredClearanceMm: widget.requiredClearanceMm,
        ),
      ],
    );
  }
}

/// The drawing surface: it owns the camera, and it is the only place that can
/// turn a point on the screen back into a point in the scene.
class _SceneSurface extends StatefulWidget {
  final LoadingScene3 scene;
  final double yaw;
  final double pitch;
  final double zoom;
  final bool drawEdges;
  final void Function(ScenePick? pick) onTap;
  final void Function(ScenePick? pick, Vector3? deckPoint) onGestureStart;
  final void Function(double dx, double dy, double scale, Vector3? deckPoint)
      onGestureUpdate;
  final VoidCallback onGestureEnd;
  final ValueChanged<double> onScroll;

  const _SceneSurface({
    required this.scene,
    required this.yaw,
    required this.pitch,
    required this.zoom,
    required this.drawEdges,
    required this.onTap,
    required this.onGestureStart,
    required this.onGestureUpdate,
    required this.onGestureEnd,
    required this.onScroll,
  });

  @override
  State<_SceneSurface> createState() => _SceneSurfaceState();
}

class _SceneSurfaceState extends State<_SceneSurface> {
  /// Where the current drag began. The orbit angles are computed from the
  /// total offset since then rather than from per-frame increments, so a slow
  /// drag and a fast one across the same distance end at the same angle.
  Offset _dragOrigin = Offset.zero;
  Camera3? _camera;
  Size _viewport = Size.zero;

  /// The scene mesh, flattened for [SceneRaster], and the mesh it came from.
  ///
  /// Flattening is the one expensive step of the fast path, so it is done when
  /// the scene changes — a vehicle moved along the deck, a block placed — and
  /// not when only the camera does. Orbiting and zooming reuse it, which is
  /// what most of the interaction is.
  Mesh3? _rasterSource;
  RasterMesh? _raster;

  /// Above this many triangles the edge hairlines are dropped whatever the
  /// control says, because stroking them means the per-face draw path and a
  /// frame of half a second. Well above anything this project builds from a
  /// specification, so only an imported model reaches it.
  static const int _edgeStrokeLimit = 60000;

  RasterMesh _flattened(Mesh3 mesh) {
    if (!identical(mesh, _rasterSource) || _raster == null) {
      _rasterSource = mesh;
      _raster = RasterMesh.from(mesh);
      _dropFrame();
    }
    return _raster!;
  }

  /// The last projected frame, and what it was projected from.
  ///
  /// Projecting is the expensive step — a T-72's imported hull is 548,889
  /// triangles, and projecting, shading and depth-sorting them measures at
  /// roughly three quarters of a second in a debug build. It was being redone
  /// inside `build`, so *any* rebuild of this subtree paid it in full: a
  /// checkbox toggled, a slider moved, a provider anywhere above it emitting,
  /// a pointer entering a button. None of those change a single vertex.
  ///
  /// The frame depends on the mesh, the camera and the viewport, and on
  /// nothing else. So it is kept until one of those actually changes, which
  /// leaves the cost where it belongs — on orbiting, zooming and moving the
  /// load — and takes it off everything else. The mesh itself is untouched:
  /// what is drawn is still every triangle the model file carries.
  RasterFrame? _frame;
  RasterMesh? _frameMesh;
  Camera3? _frameCamera;
  Size _frameViewport = Size.zero;

  void _dropFrame() {
    _frame?.dispose();
    _frame = null;
    _frameMesh = null;
    _frameCamera = null;
  }

  static bool _sameCamera(Camera3 a, Camera3 b) =>
      a.yaw == b.yaw &&
      a.pitch == b.pitch &&
      a.distance == b.distance &&
      a.fieldOfView == b.fieldOfView &&
      a.target.x == b.target.x &&
      a.target.y == b.target.y &&
      a.target.z == b.target.z;

  RasterFrame? _projected(
    RasterMesh flat, {
    required Camera3 camera,
    required Size viewport,
    required int Function(SurfaceMaterial material) colorOf,
  }) {
    final cached = _frame;
    if (cached != null &&
        identical(flat, _frameMesh) &&
        _frameCamera != null &&
        _sameCamera(_frameCamera!, camera) &&
        _frameViewport == viewport) {
      return cached;
    }
    _frame?.dispose();
    _frame = SceneRaster.render(
      flat,
      camera: camera,
      width: viewport.width,
      height: viewport.height,
      colorOf: colorOf,
    );
    _frameMesh = flat;
    _frameCamera = camera;
    _frameViewport = viewport;
    return _frame;
  }

  @override
  void dispose() {
    _dropFrame();
    super.dispose();
  }

  /// What was under the pointer when it went down, captured before any
  /// recogniser has had a say.
  ///
  /// A scale gesture is only accepted after the pointer has travelled the
  /// touch slop, and it reports its focal point as of that moment — by which
  /// time the pointer has left the block it was pressed on. Picking at
  /// pointer-down instead means a drag grabs the piece the trainee actually
  /// put their finger on.
  ScenePick? _pressPick;
  Offset _pressLocal = Offset.zero;

  ScenePick? _pickAt(Offset local) {
    final camera = _camera;
    if (camera == null) return null;
    // Cast against the gear alone, so a block standing behind the tank is
    // still selectable — the trainee is reaching for the piece, not for
    // whatever happens to be in front of it.
    return ScenePicking.pickNear(
      widget.scene.securingMesh,
      camera,
      width: _viewport.width,
      height: _viewport.height,
      px: local.dx,
      py: local.dy,
      accept: (face) => face.partId?.startsWith('securing.') == true &&
          face.material != SurfaceMaterial.selectionMarker &&
          face.material != SurfaceMaterial.guideLine,
    );
  }

  Vector3? _deckPointAt(Offset local) {
    final camera = _camera;
    if (camera == null) return null;
    final ray = ScenePicking.through(
      camera: camera,
      width: _viewport.width,
      height: _viewport.height,
      px: local.dx,
      py: local.dy,
    );
    return ScenePicking.planeY(ray, widget.scene.flatcar.deckTopY);
  }

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.35,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.well,
          border: Border.fromBorderSide(BorderSide(color: AppColors.hairline)),
        ),
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final height = constraints.maxHeight;

              // Framed on the wagon and its load, not on the track bed, which
              // runs half again as long and would push the wagon into the
              // distance.
              final framing =
                  widget.scene.flatcar.mesh.bounds.union(widget.scene.loadBounds);
              final base = Camera3.framing(
                framing,
                yaw: widget.yaw,
                pitch: widget.pitch,
                aspectRatio: width / math.max(height, 1),
              );
              final camera = base.copyWith(distance: base.distance / widget.zoom);
              _camera = camera;
              _viewport = Size(width, height);

              // Two draw paths, chosen by what the scene actually holds.
              // A mesh this project built from a specification is a few
              // thousand faces and wants its edges stroked, which only the
              // per-face path can do. An imported model is hundreds of
              // thousands and cannot be drawn that way at all — see
              // [SceneRaster] for the measurements.
              final flat = _flattened(widget.scene.mesh);
              final strokeEdges =
                  widget.drawEdges && flat.triangleCount <= _edgeStrokeLimit;

              CustomPainter? painter;
              if (strokeEdges) {
                painter = Scene3Painter(
                  SceneProjection.render(
                    widget.scene.mesh,
                    camera: camera,
                    width: width,
                    height: height,
                  ),
                  drawEdges: true,
                );
              } else {
                final frame = _projected(
                  flat,
                  camera: camera,
                  viewport: Size(width, height),
                  colorOf: (m) =>
                      Scene3Painter.materialColor(m).toARGB32() & 0x00FFFFFF,
                );
                painter = frame == null ? null : RasterScenePainter(frame);
              }

              return Listener(
                onPointerDown: (event) {
                  _pressLocal = event.localPosition;
                  _pressPick = _pickAt(event.localPosition);
                },
                onPointerSignal: (event) {
                  if (event is PointerScrollEvent) {
                    widget.onScroll(event.scrollDelta.dy);
                  }
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // A tap needs its own recogniser: the scale recogniser only
                  // reports once a gesture has been accepted, which a tap that
                  // never moves never is — so selecting a piece by tapping it
                  // would silently do nothing.
                  onTapUp: (details) => widget.onTap(_pickAt(details.localPosition)),
                  // One scale recogniser handles every gesture: a drag either
                  // moves the piece under the pointer or orbits the scene, and
                  // two fingers pinch to zoom. A separate pan recogniser would
                  // fight this one in the gesture arena.
                  onScaleStart: (details) {
                    // Measured from where the pointer went down, not from
                    // where the recogniser accepted: the two differ by the
                    // touch slop, and the difference is the whole block.
                    _dragOrigin = _pressLocal;
                    widget.onGestureStart(
                      _pressPick,
                      _deckPointAt(_pressLocal),
                    );
                  },
                  onScaleUpdate: (details) {
                    final delta = details.localFocalPoint - _dragOrigin;
                    widget.onGestureUpdate(
                      delta.dx,
                      delta.dy,
                      details.scale,
                      _deckPointAt(details.localFocalPoint),
                    );
                  },
                  onScaleEnd: (_) => widget.onGestureEnd(),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.grab,
                    child: RepaintBoundary(
                      child: CustomPaint(
                        // Keyed so a test can find the drawing surface among
                        // the several CustomPaints a slider and a checkbox
                        // bring with them, and aim a tap at a known point of
                        // the scene.
                        key: LoadingScene3DView.surfaceKey,
                        size: Size(width, height),
                        painter: painter,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Choosing a piece of hardware, putting it on the wagon, and taking it off.
///
/// One list rather than a button per kind: the handbook offers eleven iron
/// spurs, four stop-boots, two KGUUB variants and three stop-block weight
/// brackets, and a row of buttons could carry none of that. Each row names the
/// piece, the table row it came from and the size that row states — and a
/// piece with no stated size is not in the list, which is the only reason the
/// list can be trusted.
class _EditBar extends StatelessWidget {
  final List<PlaceableHardware> hardware;
  final PlaceableHardware? active;

  /// The seating distance a newly placed stop block will be set to, in
  /// centimetres, or null to drop it where a new piece normally lands.
  final double? placeAtCm;

  /// The middle of the range the chosen arrangement calls for, offered as a
  /// one-tap answer rather than pre-filled: the trainee is meant to know the
  /// figure, not to have it entered for them.
  final double? suggestedCm;

  final ({int minCm, int maxCm})? range;
  final ValueChanged<double?> onPlaceAtChanged;

  /// True for a lorry: it changes what the distance is measured from.
  final bool wheeled;

  /// The handbook figures for a paragraph, for the picture beside the piece.
  final List<HandbookPhoto> Function(String referenceId)? figuresFor;

  final bool hasSelection;
  final bool selectionIsBlock;
  final VoidCallback onAdd;
  final VoidCallback onRemove;
  final VoidCallback onFlip;
  final VoidCallback onReset;
  final ValueChanged<String> onHardwareChanged;

  const _EditBar({
    required this.hardware,
    required this.active,
    required this.placeAtCm,
    required this.suggestedCm,
    required this.range,
    required this.onPlaceAtChanged,
    required this.wheeled,
    required this.figuresFor,
    required this.hasSelection,
    required this.selectionIsBlock,
    required this.onAdd,
    required this.onRemove,
    required this.onFlip,
    required this.onReset,
    required this.onHardwareChanged,
  });

  static String keyOf(PlaceableHardware h) => '${h.kind.name}|${h.typeCode}';

  static String labelOf(PlaceableHardware h) =>
      AppStrings.scene3dHardwareOption(
          AppStrings.scene3dPieceKindLabel(h.kind.name), h.typeCode) +
      (h.matchesVehicle ? AppStrings.scene3dHardwareMatchesVehicle : '');

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.scene3dEditHeading,
            style: TextStyle(
              fontSize: AppText.caption,
              color: AppColors.label,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 8),
          if (hardware.isEmpty)
            const Text(
              AppStrings.scene3dHardwareEmpty,
              style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal),
            )
          else ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                const Text(
                  AppStrings.scene3dHardwareLabel,
                  style: TextStyle(
                      fontSize: AppText.bodySmall, color: AppColors.textSecondary),
                ),
                DropdownButton<String>(
                  value: active == null ? null : keyOf(active!),
                  dropdownColor: AppColors.panelRaised,
                  style: const TextStyle(
                      fontSize: AppText.bodySmall, color: AppColors.textPrimary),
                  items: [
                    for (final h in hardware)
                      DropdownMenuItem(value: keyOf(h), child: Text(labelOf(h))),
                  ],
                  onChanged: (value) {
                    if (value != null) onHardwareChanged(value);
                  },
                ),
                _AddButton(
                  label: AppStrings.scene3dAddSelected,
                  icon: Icons.add,
                  onPressed: onAdd,
                ),
              ],
            ),
            if (active?.kind == SecuringPieceKind.woodChock ||
                active?.kind == SecuringPieceKind.ironChock ||
                active?.kind == SecuringPieceKind.ironSpur ||
                active?.kind == SecuringPieceKind.ironChockBoot) ...[
              const SizedBox(height: 8),
              _PlaceAtEntry(
                wheeled: wheeled,
                placeAtCm: placeAtCm,
                suggestedCm: suggestedCm,
                range: range,
                onChanged: onPlaceAtChanged,
              ),
            ],
            if (active != null) ...[
              const SizedBox(height: 4),
              Text(
                // The size it will be built to, and the paragraph or plate it
                // was read off.
                AppStrings.scene3dHardwareSize(
                  (active!.heightM * 1000).round(),
                  (active!.widthM * 1000).round(),
                  (active!.lengthM * 1000).round(),
                ),
                style: const TextStyle(
                    fontSize: AppText.caption,
                    fontFamily: AppText.mono,
                    color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpace.sm),
              _HardwareFigures(hardware: active!, figuresFor: figuresFor),
            ],
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (selectionIsBlock)
                _AddButton(
                  label: AppStrings.scene3dFlipFacing,
                  icon: Icons.swap_horiz,
                  onPressed: onFlip,
                ),
              if (hasSelection)
                _AddButton(
                  label: AppStrings.scene3dRemoveSelected,
                  icon: Icons.delete_outline,
                  onPressed: onRemove,
                  danger: true,
                ),
              _AddButton(
                label: AppStrings.scene3dResetLayout,
                icon: Icons.restart_alt,
                onPressed: onReset,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The distance a piece will be seated at, chosen before it is put down.
///
/// The order matters: the trainee picks the block, states the distance the
/// plate calls for, and then places it. Offering the figure only after the
/// piece is already on the deck would make the distance an afterthought,
/// which is the one thing about a stop block the handbook actually dimensions.
class _PlaceAtEntry extends StatefulWidget {
  /// True for a lorry, whose blocks are seated against a tyre rather than
  /// against the end of a track.
  final bool wheeled;

  final double? placeAtCm;
  final double? suggestedCm;
  final ({int minCm, int maxCm})? range;
  final ValueChanged<double?> onChanged;

  const _PlaceAtEntry({
    required this.wheeled,
    required this.placeAtCm,
    required this.suggestedCm,
    required this.range,
    required this.onChanged,
  });

  @override
  State<_PlaceAtEntry> createState() => _PlaceAtEntryState();
}

class _PlaceAtEntryState extends State<_PlaceAtEntry> {
  late final TextEditingController _controller = TextEditingController(
      text: widget.placeAtCm == null
          ? ''
          : widget.placeAtCm!.toStringAsFixed(1));

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _push(String text) {
    final cm = double.tryParse(text.replaceAll(',', '.'));
    widget.onChanged(text.trim().isEmpty ? null : cm);
  }

  @override
  Widget build(BuildContext context) {
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 6,
      children: [
        Text(
          widget.wheeled
              ? AppStrings.scene3dPlaceAtWheelLabel
              : AppStrings.scene3dPlaceAtLabel,
          style: const TextStyle(
              fontSize: AppText.bodySmall, color: AppColors.textSecondary),
        ),
        SizedBox(
          width: 96,
          child: TextField(
            key: LoadingScene3DView.placeAtFieldKey,
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(
                fontFamily: AppText.mono, fontSize: AppText.bodySmall),
            decoration: const InputDecoration(
                isDense: true, hintText: AppStrings.scene3dPlaceAtHint),
            onChanged: _push,
            onSubmitted: _push,
          ),
        ),
        if (widget.range != null)
          Text(
            AppStrings.scene3dPlaceAtRange(
                widget.range!.minCm, widget.range!.maxCm),
            style: const TextStyle(
                fontSize: AppText.caption, color: AppColors.textSecondary),
          )
        else
          const Text(
            AppStrings.scene3dPlaceAtNoRange,
            style:
                TextStyle(fontSize: AppText.caption, color: AppColors.offNominal),
          ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool danger;

  const _AddButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        icon: Icon(icon, size: 15),
        label: Text(label, style: const TextStyle(fontSize: AppText.caption)),
        style: OutlinedButton.styleFrom(
          foregroundColor: danger ? AppColors.outOfTolerance : AppColors.textPrimary,
          side: BorderSide(color: danger ? AppColors.outOfTolerance : AppColors.hairline),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onPressed,
      );
}

/// How the piece the trainee is holding actually sits.
class _SelectedPanel extends StatelessWidget {
  final SecuringPiece? piece;
  final BlockSeating? seating;
  final ChockArrangement? arrangement;
  final double vehicleOffsetX;

  /// Step the piece by whole centimetres, along the wagon and across it.
  final void Function({double alongCm, double acrossCm}) onNudge;

  /// Seat a stop block exactly this many centimetres off the running gear.
  final ValueChanged<double> onSeatingDistance;

  /// Put it on the track's centre line exactly.
  final VoidCallback onCentreOnRun;

  const _SelectedPanel({
    required this.piece,
    required this.seating,
    required this.arrangement,
    required this.vehicleOffsetX,
    required this.onNudge,
    required this.onSeatingDistance,
    required this.onCentreOnRun,
  });

  @override
  Widget build(BuildContext context) {
    final selected = piece;
    if (selected == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          AppStrings.scene3dNothingSelected,
          style: TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary),
        ),
      );
    }

    final check = seating == null
        ? null
        : checkSeatingDistance(
            seating: seating!,
            arrangement: arrangement,
            kind: selected.kind,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.labelDim),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                AppStrings.scene3dSelectedHeading,
                style: TextStyle(
                  fontSize: AppText.caption,
                  color: AppColors.label,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppStrings.scene3dPieceKindLabel(selected.kind.name),
                style: const TextStyle(
                    fontSize: AppText.bodySmall,
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold),
              ),
              if (selected.sizeTypeCode != null) ...[
                const SizedBox(width: 8),
                Text(
                  selected.sizeTypeCode!,
                  style: const TextStyle(
                      fontSize: AppText.caption, color: AppColors.textSecondary),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 26,
            runSpacing: 4,
            children: [
              if (selected.isBlock)
                _Readout(
                  AppStrings.scene3dBlockSizeLabel,
                  '${(selected.heightM * 1000).round()}×${(selected.widthM * 1000).round()} mm',
                ),
              _Readout(
                AppStrings.scene3dBlockPositionLabel,
                AppStrings.scene3dMetres(selected.x),
              ),
              if (seating != null && selected.isBlock) ...[
                _Readout(
                  // A lorry's block is seated against a particular tyre, and
                  // the readout says which: "Tigirden aralygy — 2-nji ok".
                  seating!.axleNumber == null
                      ? AppStrings.scene3dSeatingDistanceLabel
                      : '${AppStrings.scene3dWheelDistanceLabel} — '
                          '${AppStrings.scene3dAxleLabel(seating!.axleNumber!)}',
                  AppStrings.scene3dCentimetres(seating!.seatingDistanceCm),
                  warn: check?.status == CheckStatus.fail,
                ),
                _Readout(
                  AppStrings.scene3dLateralOffsetLabel,
                  seating!.underRunningGear
                      ? AppStrings.scene3dCentimetres(seating!.lateralOffsetM * 100)
                      : AppStrings.scene3dNotUnderRun,
                  warn: !seating!.underRunningGear,
                ),
              ],
            ],
          ),
          if (selected.isBlock) ...[
            const SizedBox(height: 10),
            _PreciseControls(
              piece: selected,
              seating: seating,
              range: selected.kind == SecuringPieceKind.woodChock
                  ? arrangement?.seatingDistance
                  : null,
              onNudge: onNudge,
              onSeatingDistance: onSeatingDistance,
              onCentreOnRun: onCentreOnRun,
            ),
          ],
          if (check != null) ...[
            const SizedBox(height: 6),
            Text(
              check.detail,
              style: TextStyle(
                fontSize: AppText.caption,
                color: switch (check.status) {
                  CheckStatus.pass => AppColors.inTolerance,
                  CheckStatus.fail => AppColors.outOfTolerance,
                  _ => AppColors.textSecondary,
                },
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Centimetre controls for the piece in hand.
///
/// A centimetre on the deck is a pixel or two on the screen, so dragging can
/// get a block roughly where it belongs and never exactly there. The plate
/// dimensions the seating distance in centimetres; this offers centimetres —
/// typed, stepped, or set straight to the range the plate calls for.
class _PreciseControls extends StatefulWidget {
  final SecuringPiece piece;
  final BlockSeating? seating;
  final ({int minCm, int maxCm})? range;
  final void Function({double alongCm, double acrossCm}) onNudge;
  final ValueChanged<double> onSeatingDistance;
  final VoidCallback onCentreOnRun;

  const _PreciseControls({
    required this.piece,
    required this.seating,
    required this.range,
    required this.onNudge,
    required this.onSeatingDistance,
    required this.onCentreOnRun,
  });

  @override
  State<_PreciseControls> createState() => _PreciseControlsState();
}

class _PreciseControlsState extends State<_PreciseControls> {
  final _seating = TextEditingController();
  String? _lastShown;

  @override
  void dispose() {
    _seating.dispose();
    super.dispose();
  }

  void _syncField() {
    final seating = widget.seating;
    if (seating == null) return;
    final text = seating.seatingDistanceCm.toStringAsFixed(1);
    // Only overwrite what the trainee is typing when the piece has actually
    // moved underneath them — otherwise every rebuild would eat the keystroke
    // they were part-way through.
    if (text != _lastShown) {
      _lastShown = text;
      _seating.text = text;
    }
  }

  @override
  Widget build(BuildContext context) {
    _syncField();
    final seating = widget.seating;
    final range = widget.range;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          AppStrings.scene3dPreciseHeading,
          style: TextStyle(
            fontSize: AppText.caption,
            color: AppColors.label,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.6,
          ),
        ),
        const SizedBox(height: 6),
        if (seating != null && widget.piece.isStopBlock)
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Text(
                  seating.axleNumber == null
                      ? AppStrings.scene3dSeatingEntryLabel
                      : AppStrings.scene3dSeatingEntryLabelForWheel(
                          seating.axleNumber!),
                  style: const TextStyle(
                      fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
              SizedBox(
                width: 90,
                child: TextField(
                  key: LoadingScene3DView.seatingFieldKey,
                  controller: _seating,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(
                      fontFamily: AppText.mono, fontSize: AppText.bodySmall),
                  decoration: const InputDecoration(isDense: true),
                  onSubmitted: (text) {
                    final cm = double.tryParse(text.replaceAll(',', '.'));
                    if (cm != null) widget.onSeatingDistance(cm);
                  },
                ),
              ),
              _Step(label: AppStrings.scene3dApplyButton, onPressed: () {
                final cm = double.tryParse(_seating.text.replaceAll(',', '.'));
                if (cm != null) widget.onSeatingDistance(cm);
              }),
              if (range != null)
                _Step(
                  label: AppStrings.scene3dSetToTarget(range.minCm, range.maxCm),
                  onPressed: () =>
                      widget.onSeatingDistance((range.minCm + range.maxCm) / 2),
                ),
            ],
          ),
        const SizedBox(height: 6),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 6,
          runSpacing: 6,
          children: [
            const Text(AppStrings.scene3dAlongEntryLabel,
                style: TextStyle(
                    fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
            _Step(label: '−5', onPressed: () => widget.onNudge(alongCm: -5)),
            _Step(label: '−1', onPressed: () => widget.onNudge(alongCm: -1)),
            _Step(label: '+1', onPressed: () => widget.onNudge(alongCm: 1)),
            _Step(label: '+5', onPressed: () => widget.onNudge(alongCm: 5)),
            const SizedBox(width: 10),
            const Text(AppStrings.scene3dLateralEntryLabel,
                style: TextStyle(
                    fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
            _Step(label: '−5', onPressed: () => widget.onNudge(acrossCm: -5)),
            _Step(label: '−1', onPressed: () => widget.onNudge(acrossCm: -1)),
            _Step(label: '+1', onPressed: () => widget.onNudge(acrossCm: 1)),
            _Step(label: '+5', onPressed: () => widget.onNudge(acrossCm: 5)),
            _Step(
              label: AppStrings.scene3dCentreOnRun,
              onPressed: widget.onCentreOnRun,
            ),
          ],
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _Step({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, 30),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          visualDensity: VisualDensity.compact,
          side: const BorderSide(color: AppColors.hairline),
          foregroundColor: AppColors.textPrimary,
        ),
        onPressed: onPressed,
        child: Text(label,
            style: const TextStyle(
                fontSize: AppText.caption, fontFamily: AppText.mono)),
      );
}

enum _Toggle { lashings, trackBed, edges, guides, snap, vehicle }

class _Controls extends StatelessWidget {
  final double position;
  final double traverse;
  final bool showLashings;
  final bool showTrackBed;
  final bool drawEdges;
  final bool showGuides;
  final bool snapToRun;
  final bool showVehicle;
  final bool gunOverhangs;
  final ValueChanged<double> onPosition;
  final ValueChanged<double> onTraverse;
  final void Function(_Toggle which, bool value) onToggle;

  const _Controls({
    required this.position,
    required this.traverse,
    required this.showLashings,
    required this.showTrackBed,
    required this.drawEdges,
    required this.showGuides,
    required this.snapToRun,
    required this.showVehicle,
    required this.gunOverhangs,
    required this.onPosition,
    required this.onTraverse,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SliderRow(
          label: AppStrings.scene3dPositionLabel,
          value: position,
          onChanged: onPosition,
        ),
        if (gunOverhangs)
          _SliderRow(
            label: AppStrings.scene3dTurretLabel,
            value: traverse / math.pi,
            minLabel: AppStrings.scene3dTurretForward,
            maxLabel: AppStrings.scene3dTurretRear,
            onChanged: (v) => onTraverse(v * math.pi),
          ),
        const SizedBox(height: 4),
        Wrap(
          spacing: 14,
          children: [
            _ToggleChip(
              label: AppStrings.scene3dSnapToRun,
              value: snapToRun,
              onChanged: (v) => onToggle(_Toggle.snap, v),
            ),
            // Hiding the machine is the only practical way to work on a piece
            // that sits under it: from every angle that shows the deck
            // underneath, the machine is in the way.
            _ToggleChip(
              label: AppStrings.scene3dShowVehicle,
              value: showVehicle,
              onChanged: (v) => onToggle(_Toggle.vehicle, v),
            ),
            _ToggleChip(
              label: AppStrings.scene3dShowGuides,
              value: showGuides,
              onChanged: (v) => onToggle(_Toggle.guides, v),
            ),
            _ToggleChip(
              label: AppStrings.scene3dShowLashings,
              value: showLashings,
              onChanged: (v) => onToggle(_Toggle.lashings, v),
            ),
            _ToggleChip(
              label: AppStrings.scene3dShowTrackBed,
              value: showTrackBed,
              onChanged: (v) => onToggle(_Toggle.trackBed, v),
            ),
            _ToggleChip(
              label: AppStrings.scene3dShowEdges,
              value: drawEdges,
              onChanged: (v) => onToggle(_Toggle.edges, v),
            ),
          ],
        ),
      ],
    );
  }
}

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final String? minLabel;
  final String? maxLabel;
  final ValueChanged<double> onChanged;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.minLabel,
    this.maxLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 210,
          child: Text(
            label,
            style: const TextStyle(
                fontSize: AppText.bodySmall, color: AppColors.textSecondary),
          ),
        ),
        if (minLabel != null)
          Text(minLabel!,
              style: const TextStyle(
                  fontSize: AppText.caption, color: AppColors.textSecondary)),
        Expanded(
          child: Slider(value: value.clamp(0.0, 1.0), onChanged: onChanged),
        ),
        if (maxLabel != null)
          Text(maxLabel!,
              style: const TextStyle(
                  fontSize: AppText.caption, color: AppColors.textSecondary)),
      ],
    );
  }
}

class _ToggleChip extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _ToggleChip({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    // The label toggles it too. A checkbox whose caption is dead is a small
    // thing that makes a dense control strip feel broken.
    return InkWell(
      onTap: () => onChanged(!value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Checkbox(value: value, onChanged: (v) => onChanged(v ?? false)),
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: Text(label,
                style: const TextStyle(
                    fontSize: AppText.bodySmall, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

/// What the model measures, stated as measurements.
class _Readouts extends StatelessWidget {
  final LoadingClearances clearances;
  final String designation;
  final int blockCount;
  final int lashingCount;
  final bool chockSizeKnown;
  final bool sizeOptionsExist;
  final bool lashingCountKnown;

  /// Strands the handbook lays up in one lashing for this weight, when its
  /// table covers it. Reported separately from the *count* of lashings —
  /// the extract fixes the strand count for a tracked vehicle by weight, and
  /// the number of lashings only for a wheeled one.
  final int? lashingThreads;
  final bool wagonGeometryIsDefault;

  /// The credit line for a model file, when one is being drawn.
  final String? modelCredit;

  /// The space between each neighbouring pair of vehicles on this wagon.
  final List<LoadGap> gaps;

  /// What the plates require of it.
  final int? requiredClearanceMm;

  const _Readouts({
    required this.clearances,
    required this.designation,
    required this.blockCount,
    required this.lashingCount,
    required this.chockSizeKnown,
    required this.sizeOptionsExist,
    required this.lashingCountKnown,
    required this.lashingThreads,
    required this.wagonGeometryIsDefault,
    this.gaps = const [],
    this.requiredClearanceMm,
    this.modelCredit,
  });

  @override
  Widget build(BuildContext context) {
    String metres(double m) =>
        m <= 0.001 ? AppStrings.scene3dNone : AppStrings.scene3dMetres(m);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            AppStrings.scene3dMeasurementsHeading,
            style: TextStyle(
              fontSize: AppText.caption,
              color: AppColors.label,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 26,
            runSpacing: 4,
            children: [
              _Readout(AppStrings.scene3dLoadHeightLabel,
                  AppStrings.scene3dMetres(clearances.loadTopAboveRailM)),
              _Readout(AppStrings.scene3dDeckHeightLabel,
                  AppStrings.scene3dMetres(clearances.deckHeightM)),
              _Readout(AppStrings.scene3dLoadWidthLabel,
                  AppStrings.scene3dMetres(clearances.loadWidthM)),
              _Readout(AppStrings.scene3dFrontOverhangLabel,
                  metres(clearances.frontOverhangM),
                  warn: clearances.frontOverhangM > 0.001),
              _Readout(AppStrings.scene3dRearOverhangLabel,
                  metres(clearances.rearOverhangM),
                  warn: clearances.rearOverhangM > 0.001),
              _Readout(AppStrings.scene3dLateralOverhangLabel,
                  metres(clearances.lateralOverhangM),
                  warn: clearances.lateralOverhangM > 0.001),
              _Readout(AppStrings.scene3dFreeDeckLabel,
                  AppStrings.scene3dMetres(clearances.freeDeckLengthM)),
              // One per pair of neighbours: the plates dimension this and it
              // could not be measured at all while the scene drew one vehicle.
              for (final gap in gaps)
                _Readout(
                  AppStrings.scene3dGapLabel,
                  gap.overlaps
                      ? AppStrings.scene3dCentimetres(gap.gapM * 100)
                      : '${gap.gapMm.toStringAsFixed(0)} mm',
                  warn: gap.overlaps ||
                      (requiredClearanceMm != null &&
                          gap.gapMm < requiredClearanceMm!),
                ),
            ],
          ),
          if (gaps.isNotEmpty && requiredClearanceMm != null) ...[
            const SizedBox(height: 4),
            Text(
              AppStrings.scene3dGapRequired(requiredClearanceMm!),
              style: const TextStyle(
                  fontSize: AppText.caption, color: AppColors.textSecondary),
            ),
          ],
          if (clearances.overhangsDeck) ...[
            const SizedBox(height: 6),
            Text(
              AppStrings.scene3dOverhangWarning(designation),
              style: const TextStyle(
                  fontSize: AppText.caption,
                  color: AppColors.offNominal,
                  fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 8),
          const Text(
            AppStrings.scene3dMeasurementNote,
            style: TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            wagonGeometryIsDefault
                ? AppStrings.scene3dWagonDefaultGeometryNote
                : AppStrings.scene3dWagonMeasuredGeometryNote,
            style: const TextStyle(
                fontSize: AppText.caption, color: AppColors.textSecondary),
          ),
          if (modelCredit != null) ...[
            const SizedBox(height: 4),
            Text(
              AppStrings.scene3dModelCredit(modelCredit!),
              style: const TextStyle(
                  fontSize: AppText.caption, color: AppColors.textSecondary),
            ),
          ],
          if (!chockSizeKnown && sizeOptionsExist) ...[
            const SizedBox(height: 4),
            const Text(
              AppStrings.scene3dSizePickerHint,
              style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal),
            ),
          ],
          if (lashingCount > 0) ...[
            const SizedBox(height: 4),
            Text(
              lashingCountKnown
                  ? AppStrings.scene3dLashingEyeNote
                  : AppStrings.scene3dLashingIndicativeNote,
              style: TextStyle(
                fontSize: AppText.caption,
                color: lashingCountKnown
                    ? AppColors.textSecondary
                    : AppColors.offNominal,
              ),
            ),
            if (lashingThreads != null) ...[
              const SizedBox(height: 4),
              Text(
                AppStrings.scene3dLashingStrandsResolved(lashingThreads!),
                style: const TextStyle(
                    fontSize: AppText.caption, color: AppColors.textSecondary),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _Readout extends StatelessWidget {
  final String label;
  final String value;
  final bool warn;

  const _Readout(this.label, this.value, {this.warn = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: AppText.caption, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: AppText.body,
            fontFamily: AppText.mono,
            color: warn ? AppColors.offNominal : AppColors.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}


/// The handbook's own photograph of the piece about to be placed.
///
/// The picker names a piece and states its size — "Demir şpor, Ş-303,
/// 180×200×860 mm" — and a trainee who has not held one still does not know
/// what they are putting on the wagon. The extract contains a figure for every
/// family of gear in that list: 15.13 for the iron spurs, 15.14 for the
/// chock-boots, 15.11 and 15.12 for the reusable universal chocks, 15.10 for
/// the lashings, 15.8 for the wood stop-blocks. Each piece already carries the
/// paragraph it was read off, and the figures are indexed by that same
/// paragraph, so the picture is a lookup rather than a new mapping anybody has
/// to maintain.
///
/// Tapping one opens it full size, with its caption and figure number, exactly
/// as the reference browser does.
class _HardwareFigures extends StatelessWidget {
  final PlaceableHardware hardware;

  /// The figures for a paragraph, supplied by the caller.
  ///
  /// A callback rather than a provider read: this view is a plain widget that
  /// draws what it is handed, and a provider dependency buried inside it would
  /// oblige every caller and every test to wrap it in a scope for the sake of
  /// one thumbnail strip.
  final List<HandbookPhoto> Function(String referenceId)? figuresFor;

  const _HardwareFigures({required this.hardware, required this.figuresFor});

  @override
  Widget build(BuildContext context) {
    // Every reference this piece can be pictured from, in order, with each
    // figure shown once however many of them cite it.
    final photos = <HandbookPhoto>[];
    final seen = <String>{};
    for (final referenceId in hardware.figureReferenceIds) {
      for (final photo in figuresFor?.call(referenceId) ?? const <HandbookPhoto>[]) {
        if (seen.add(photo.id)) photos.add(photo);
      }
    }
    if (photos.isEmpty) {
      // No figure for this paragraph in the extract. Said plainly rather than
      // left as an empty strip the trainee reads as a loading failure.
      return Row(
        children: [
          const Icon(Icons.image_not_supported_outlined,
              size: 14, color: AppColors.labelDim),
          const SizedBox(width: AppSpace.sm),
          Flexible(
            child: Text(
              AppStrings.scene3dHardwareNoFigure,
              style: AppText.prose(size: AppText.tick, color: AppColors.labelDim),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppStrings.scene3dHardwareFigureHeading.toUpperCase(),
          style: AppText.legend(
            size: AppText.tick,
            color: AppColors.labelDim,
            weight: FontWeight.w400,
            tracking: 1.4,
          ),
        ),
        const SizedBox(height: AppSpace.xs),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: photos.length,
            separatorBuilder: (_, __) => const SizedBox(width: AppSpace.sm),
            itemBuilder: (context, i) {
              final photo = photos[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  HandbookPhotoThumbnail(photo: photo, width: 112, height: 70),
                  const SizedBox(height: 3),
                  Text(
                    photo.figureNumber,
                    style: AppText.value(size: AppText.tick, color: AppColors.label),
                  ),
                ],
              );
            },
          ),
        ),
        const SizedBox(height: AppSpace.sm),
        HandbookReferenceChip(referenceId: hardware.referenceId),
      ],
    );
  }
}
