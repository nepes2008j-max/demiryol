import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/chock_arrangement.dart';
import 'package:railsim/domain/models/scene3d.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/scene3d_camera.dart';
import 'package:railsim/domain/usecases/securing_hardware_catalog.dart';
import 'package:railsim/domain/usecases/securing_measurements.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_builder.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_catalog.dart';
import 'package:railsim/domain/usecases/wheeled_vehicle_mesh_builder.dart';
import 'package:railsim/presentation/widgets/visualization/loading_scene_3d_view.dart';

Vehicle _vehicle({
  required String id,
  VehicleCategory category = VehicleCategory.tracked,
  Object? length = 686,
  Object? width = 378,
  Object? height = 223,
  Object? clearance = 49,
  Object? shoe = 580,
  int? axleCount,
}) =>
    Vehicle(
      id: id,
      handbookDesignation: id,
      category: category,
      vehicleClass: 'test',
      lengthCm: HandbookField(length),
      widthCm: HandbookField(width),
      heightCm: HandbookField(height),
      weightT: const HandbookField(46.5),
      groundClearanceCm: HandbookField(clearance),
      trackWidthMm: HandbookField(shoe),
      wheelBaseCm: const HandbookField(427),
      axleCount: axleCount,
      manufacturer: 'test',
      country: 'test',
      approvedSecuringHardwareIds: const [],
      referenceId: 'para-32',
    );

/// A palette shaped like the real one: two stop-block brackets, the second of
/// which is the one this vehicle's weight resolves, plus the pieces plate-02
/// and the iron tables add.
const _chockLight = PlaceableHardware(
  kind: SecuringPieceKind.woodChock,
  typeCode: 'up to 12.0 t',
  heightM: 0.100,
  widthM: 0.150,
  lengthM: 0.783,
  referenceId: 'para-21',
);
const _chockHeavy = PlaceableHardware(
  kind: SecuringPieceKind.woodChock,
  typeCode: '12.1-30.0 t',
  heightM: 0.150,
  widthM: 0.200,
  lengthM: 0.783,
  referenceId: 'para-21',
  matchesVehicle: true,
);
const _insert = PlaceableHardware(
  kind: SecuringPieceKind.woodInsert,
  typeCode: '90-100 x 300-400 mm',
  heightM: 0.095,
  widthM: 0.350,
  lengthM: 0.580,
  referenceId: 'plate-02',
);
const _sideBlock = PlaceableHardware(
  kind: SecuringPieceKind.woodSideBlock,
  typeCode: '100x100x2000 mm',
  heightM: 0.100,
  widthM: 2.000,
  lengthM: 0.100,
  referenceId: 'plate-02',
);
const _staple = PlaceableHardware(
  kind: SecuringPieceKind.staple,
  typeCode: 'Ø12 mm',
  heightM: 0.096,
  widthM: 0.012,
  lengthM: 0.120,
  referenceId: 'plate-02',
);
const _spur = PlaceableHardware(
  kind: SecuringPieceKind.ironSpur,
  typeCode: 'Ş-303',
  heightM: 0.042,
  widthM: 0.140,
  lengthM: 0.500,
  referenceId: 'para-31',
);
const _boot = PlaceableHardware(
  kind: SecuringPieceKind.ironChockBoot,
  typeCode: 'KT-137',
  heightM: 0.028,
  widthM: 0.130,
  lengthM: 0.170,
  referenceId: 'para-32',
);
const _kguub = PlaceableHardware(
  kind: SecuringPieceKind.ironChock,
  typeCode: 'KGUUB-2G',
  heightM: 0.010,
  widthM: 0.280,
  lengthM: 0.240,
  referenceId: 'para-29',
);

const _wire = PlaceableHardware(
  kind: SecuringPieceKind.wireLashing,
  typeCode: 'Ø5 mm',
  heightM: 0.005,
  widthM: 0.005,
  lengthM: 0.005,
  referenceId: 'table-7',
);

const _hardware = <PlaceableHardware>[
  _chockLight,
  _chockHeavy,
  _insert,
  _staple,
  _sideBlock,
  _kguub,
  _spur,
  _boot,
  _wire,
];

/// The label the palette shows for one entry, so a test can pick it.
String _option(PlaceableHardware h) =>
    AppStrings.scene3dHardwareOption(
        AppStrings.scene3dPieceKindLabel(h.kind.name), h.typeCode) +
    (h.matchesVehicle ? AppStrings.scene3dHardwareMatchesVehicle : '');

const _arrangement = ChockArrangement(
  id: 'tracked-standard',
  appliesTo: VehicleCategory.tracked,
  label: 'test',
  chockCount: 4,
  seatingDistance: (minCm: 10, maxCm: 15),
  referenceId: 'plate-02',
);

/// The widget's own view geometry, so a test can aim a pointer at a known
/// point of the scene rather than at a guessed pixel.
const _surfaceWidth = 1200.0;
const _surfaceHeight = _surfaceWidth / 2.35;

class _Harness {
  SecuringLayout? lastLayout;
  double? lastPosition;
}

Future<_Harness> _pump(
  WidgetTester tester, {
  SecuringLayout layout = SecuringLayout.empty,
  List<PlaceableHardware> hardware = const [],
  List<SceneCompanion> companions = const [],
  int? requiredClearanceMm,
  ChockArrangement? arrangement,
  double? snapSeatingDistanceM,
  int? lashingRunCount,
  int? lashingThreads,
  FlatcarMeshSpec flatcar = FlatcarMeshSpec.standardFourAxle,
}) async {
  final harness = _Harness();
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        child: SizedBox(
          width: _surfaceWidth,
          child: StatefulBuilder(
            builder: (context, setState) => LoadingScene3DView(
              vehicleSpec: TrackedVehicleMeshSpec.t90s,
              flatcarSpec: flatcar,
              designation: 'T-90S',
              layout: harness.lastLayout ?? layout,
              onLayoutChanged: (next) => setState(() => harness.lastLayout = next),
              hardware: hardware,
              companions: companions,
              requiredClearanceMm: requiredClearanceMm,
              arrangement: arrangement,
              snapSeatingDistanceM: snapSeatingDistanceM,
              lashingRunCount: lashingRunCount,
              lashingThreads: lashingThreads,
              onPositionChanged: (v) => harness.lastPosition = v,
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle();
  return harness;
}

/// Where a world point lands on the drawing surface, computed exactly the way
/// the widget computes it.
Offset _screenPoint(WidgetTester tester, Vector3 world) {
  final geometry = resolveLoadingGeometry(
    vehicleSpec: TrackedVehicleMeshSpec.t90s,
    flatcarSpec: FlatcarMeshSpec.standardFourAxle,
  );
  final scene = buildLoadingScene(
    vehicleSpec: TrackedVehicleMeshSpec.t90s,
    flatcarSpec: FlatcarMeshSpec.standardFourAxle,
    securing: SecuringLayout.empty,
  );
  final camera = Camera3.framing(
    scene.flatcar.mesh.bounds.union(scene.loadBounds),
    yaw: 0.62,
    pitch: 0.28,
    aspectRatio: _surfaceWidth / _surfaceHeight,
  );
  final local = SceneProjection.project(world,
      camera: camera, width: _surfaceWidth, height: _surfaceHeight)!;
  final surface = tester.getTopLeft(find.byKey(LoadingScene3DView.surfaceKey));
  // Referenced so the analyzer keeps the geometry above, which documents that
  // the test and the widget resolve the same wagon.
  expect(geometry.flatcar.deckTopY, scene.flatcar.deckTopY);
  return surface + Offset(local.x, local.y);
}

/// Chooses a palette entry and puts it on the wagon.
Future<void> _place(WidgetTester tester, PlaceableHardware h) async {
  await tester.tap(find.byType(DropdownButton<String>));
  await tester.pumpAndSettle();
  await tester.tap(find.text(_option(h)).last);
  await tester.pumpAndSettle();
  await tester.tap(find.text(AppStrings.scene3dAddSelected));
  await tester.pumpAndSettle();
}

void main() {
  // A desktop-sized surface. The trainer runs on a desktop window, and the
  // scene needs the width: at the 800x600 test default the readout row wraps
  // and the projected pixel a drag aims at is not where the app puts it.
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.physicalSize = const Size(1400, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher
        .views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  group('VehicleMeshCatalog', () {
    test('models the T-90S from its supplement', () {
      final spec = VehicleMeshCatalog.specFor(_vehicle(id: 'veh-t90s'));
      expect(spec, isA<TrackedVehicleMeshSpec>());
      // The supplement carries the two figures the vehicle record has no field
      // for: the width over the tracks, and the gun overhang.
      final tracked = spec! as TrackedVehicleMeshSpec;
      expect(tracked.widthOverTracksM, closeTo(3.37, 1e-9));
      expect(tracked.gunOverhangM, closeTo(2.67, 1e-9));
    });

    test('models any tracked vehicle whose record carries real dimensions', () {
      final spec = VehicleMeshCatalog.specFor(_vehicle(id: 'veh-hypothetical'));
      expect(spec, isA<TrackedVehicleMeshSpec>());
      final tracked = spec! as TrackedVehicleMeshSpec;
      expect(tracked.hullLengthM, closeTo(6.86, 1e-9));
      expect(tracked.overallWidthM, closeTo(tracked.widthOverTracksM, 1e-9));
      expect(tracked.gunOverhangM, 0);
    });

    test('refuses to model a vehicle whose dimensions are not available', () {
      // Which is every handbook-extracted vehicle in the current catalogue:
      // a solid built from nothing would be the most convincing wrong drawing
      // in the application.
      expect(VehicleMeshCatalog.specFor(_vehicle(id: 'veh-t55', length: null)), isNull);
      expect(VehicleMeshCatalog.specFor(_vehicle(id: 'veh-t55', height: null)), isNull);
      expect(VehicleMeshCatalog.specFor(_vehicle(id: 'veh-t55', shoe: null)), isNull);
      expect(
        VehicleMeshCatalog.specFor(
            _vehicle(id: 'veh-t55', length: 'TODO: Fill from Handbook Page XX')),
        isNull,
      );
    });

    test('a wheeled vehicle gets a wheeled model, not a tracked one', () {
      // With an axle count, because plate 06 counts chocks by it and the
      // builder will not draw wheels it was not given a number for.
      final spec = VehicleMeshCatalog.specFor(_vehicle(
          id: 'veh-ural4320',
          category: VehicleCategory.wheeled,
          axleCount: 3));
      expect(spec, isA<WheeledVehicleMeshSpec>());
      expect(spec, isNot(isA<TrackedVehicleMeshSpec>()));
      // A lorry has nothing overhanging its body, so there is no gun control
      // to offer and no overhang to report beyond its own length.
      expect(spec!.lengthOverGunM, spec.hullLengthM);
    });
  });

  group('the scene and its readouts', () {
    testWidgets('draws the scene and reports what it measures', (tester) async {
      await _pump(tester);
      expect(find.text(AppStrings.scene3dTitle), findsOneWidget);
      expect(find.text(AppStrings.scene3dLoadHeightLabel), findsOneWidget);
      // 1.31 m deck + 2.23 m tank.
      expect(find.text(AppStrings.scene3dMetres(3.54)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('says the wagon is the default one when no platform figures exist',
        (tester) async {
      await _pump(tester);
      expect(find.text(AppStrings.scene3dWagonDefaultGeometryNote), findsOneWidget);
      expect(find.text(AppStrings.scene3dWagonMeasuredGeometryNote), findsNothing);
    });

    testWidgets('says so when the wagon is drawn from a platform record', (tester) async {
      await _pump(tester,
          flatcar: FlatcarMeshSpec.fromPlatformFigures(
              lengthCm: 1400, widthCm: 290, deckHeightCm: 130));
      expect(find.text(AppStrings.scene3dWagonMeasuredGeometryNote), findsOneWidget);
    });

    testWidgets('running the vehicle to the end reports the gun overhanging',
        (tester) async {
      await _pump(tester);
      await tester.drag(find.byType(Slider).first, const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.scene3dOverhangWarning('T-90S')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('sliding the vehicle along the deck tells the caller', (tester) async {
      final harness = await _pump(tester);
      await tester.drag(find.byType(Slider).first, const Offset(160, 0));
      await tester.pumpAndSettle();
      expect(harness.lastPosition, isNotNull);
      expect(harness.lastPosition, greaterThan(0.5));
    });
  });

  group('the palette of everything that can be put on the wagon', () {
    testWidgets('with nothing sized, nothing is offered and the view says why',
        (tester) async {
      await _pump(tester);
      expect(find.text(AppStrings.scene3dHardwareEmpty), findsOneWidget);
      expect(find.byType(DropdownButton<String>), findsNothing);
      expect(find.text(AppStrings.scene3dAddSelected), findsNothing);
    });

    testWidgets('every sized piece is on the list, named with its table row',
        (tester) async {
      await _pump(tester, hardware: _hardware, snapSeatingDistanceM: 0.125);
      await tester.tap(find.byType(DropdownButton<String>));
      await tester.pumpAndSettle();
      for (final h in _hardware) {
        expect(find.text(_option(h)), findsWidgets,
            reason: '${h.kind.name} ${h.typeCode} is not on the palette');
      }
    });

    testWidgets('the row the vehicle resolves is flagged and preselected',
        (tester) async {
      await _pump(tester, hardware: _hardware, snapSeatingDistanceM: 0.125);
      expect(find.text(_option(_chockHeavy)), findsWidgets);
      // Its size is shown under the picker, in millimetres.
      expect(
          find.text(AppStrings.scene3dHardwareSize(150, 200, 783)), findsOneWidget);
    });

    testWidgets('the deck starts empty — nothing is placed for the trainee',
        (tester) async {
      // It is a test. Opening with the handbook's own arrangement already
      // nailed down handed them the answer and left nothing to do but agree.
      final harness = await _pump(tester,
          hardware: _hardware, snapSeatingDistanceM: 0.125);
      expect(find.text(AppStrings.scene3dPieceCount(0, 0)), findsOneWidget);
      expect(find.text(AppStrings.scene3dEmptyDeckHint), findsOneWidget);
      expect(harness.lastLayout, isNull, reason: 'nothing placed yet');
    });

    testWidgets('the distance is chosen before the piece goes down',
        (tester) async {
      await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);
      // Offered for a stop block, with the range the chosen arrangement calls
      // for shown beside it — but not filled in for them.
      expect(find.text(AppStrings.scene3dPlaceAtLabel), findsOneWidget);
      expect(find.text(AppStrings.scene3dPlaceAtRange(10, 15)), findsOneWidget);
    });

    testWidgets('with no arrangement chosen it says the range is not fixed',
        (tester) async {
      await _pump(tester, hardware: _hardware, snapSeatingDistanceM: 0.125);
      expect(find.text(AppStrings.scene3dPlaceAtNoRange), findsOneWidget);
    });

    testWidgets('a resolved bracket needs no such warning', (tester) async {
      await _pump(tester, hardware: _hardware, snapSeatingDistanceM: 0.125);
      expect(find.text(AppStrings.scene3dSizePickerHint), findsNothing);
    });
  });

  group('placing the gear by hand', () {
    testWidgets('every kind on the palette can actually be put down',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware, snapSeatingDistanceM: 0.125);
      for (final h in _hardware) {
        await _place(tester, h);
        final added = harness.lastLayout!.pieces.last;
        expect(added.kind, h.kind, reason: h.typeCode);
        expect(added.sizeTypeCode, h.typeCode, reason: h.typeCode);
        if (added.isBlock) {
          // A wire has no solid to size; the row it came from names its
          // diameter and that is all it carries.
          expect(added.heightM, closeTo(h.heightM, 1e-9), reason: h.typeCode);
          expect(added.widthM, closeTo(h.widthM, 1e-9), reason: h.typeCode);
          expect(added.lengthM, closeTo(h.lengthM, 1e-9), reason: h.typeCode);
        }
      }
      expect(tester.takeException(), isNull);
    });

    testWidgets('a block can be added and lands on the wagon', (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware, snapSeatingDistanceM: 0.125);
      await _place(tester, _chockHeavy);
      expect(harness.lastLayout, isNotNull);
      expect(harness.lastLayout!.stopBlocks.length, 1);
      // The new piece is the selected one, so the trainee can see what they
      // just made.
      expect(find.text(AppStrings.scene3dSelectedHeading), findsOneWidget);
    });

    testWidgets('a block is built to the row chosen in the picker, not the first',
        (tester) async {
      final harness = await _pump(tester, hardware: _hardware);
      await _place(tester, _chockLight);
      final added = harness.lastLayout!.stopBlocks.last;
      expect(added.sizeTypeCode, 'up to 12.0 t');
      expect(added.heightM, closeTo(0.100, 1e-9));
      expect(added.widthM, closeTo(0.150, 1e-9));
    });

    testWidgets('an iron spur carries its own type code and plate size',
        (tester) async {
      final harness = await _pump(tester, hardware: _hardware);
      await _place(tester, _spur);
      final added = harness.lastLayout!.pieces.last;
      expect(added.kind, SecuringPieceKind.ironSpur);
      expect(added.sizeTypeCode, 'Ş-303');
      // Its base plate runs across the wagon, under the track it seats below.
      expect(added.lengthM, closeTo(0.500, 1e-9));
    });

    testWidgets('an insert is shown without a seating verdict it cannot have',
        (tester) async {
      // The plate seats a half-round insert between the road wheels and
      // dimensions no distance from the running gear for it.
      final harness = await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);
      await _place(tester, _insert);
      expect(harness.lastLayout!.pieces.last.kind, SecuringPieceKind.woodInsert);
      expect(find.text(AppStrings.scene3dBlockPositionLabel), findsOneWidget);
      expect(find.text(AppStrings.scene3dSeatingDistanceLabel), findsNothing);
    });

    testWidgets('a KGUUB is measured but judged by its own rule, not the wood one',
        (tester) async {
      await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);
      await _place(tester, _kguub);
      // The distance is a real fact and is shown.
      expect(find.text(AppStrings.scene3dSeatingDistanceLabel), findsOneWidget);
      // But plate-03's 10-15 cm range is written about the wood block.
      expect(find.text(AppStrings.seatingDistanceOtherHardwareDetail),
          findsOneWidget);
    });

    testWidgets('a stop block does still get the wood verdict', (tester) async {
      await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);
      await _place(tester, _chockHeavy);
      expect(find.text(AppStrings.scene3dSeatingDistanceLabel), findsOneWidget);
      expect(find.text(AppStrings.seatingDistanceOtherHardwareDetail), findsNothing);
    });

    testWidgets('tapping a block in the scene selects it', (tester) async {
      final harness =
          await _pump(tester, hardware: _hardware, snapSeatingDistanceM: 0.125);
      expect(find.text(AppStrings.scene3dNothingSelected), findsOneWidget);

      final geometry = resolveLoadingGeometry(
        vehicleSpec: TrackedVehicleMeshSpec.t90s,
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      );
      await _place(tester, _chockHeavy);
      await tester.tapAt(tester.getTopLeft(
              find.byKey(LoadingScene3DView.surfaceKey)) +
          const Offset(20, 18));
      await tester.pumpAndSettle();
      final block = harness.lastLayout!.stopBlocks.single;
      final at = _screenPoint(
        tester,
        Vector3(
          (block.span.face + block.span.back) / 2,
          geometry.flatcar.deckTopY + block.heightM * 0.4,
          block.z,
        ),
      );

      await tester.tapAt(at);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.scene3dNothingSelected), findsNothing);
      expect(find.text(AppStrings.scene3dSelectedHeading), findsOneWidget);
      // The kind is named on the selected-piece panel — and again on the add
      // button, which carries the same words.
      expect(find.text(AppStrings.scene3dPieceKindLabel('woodChock')),
          findsOneWidget);
      // And its seating distance is reported off the model.
      expect(find.text(AppStrings.scene3dSeatingDistanceLabel), findsOneWidget);
    });

    testWidgets('dragging the selected block moves it along the deck',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);

      final geometry = resolveLoadingGeometry(
        vehicleSpec: TrackedVehicleMeshSpec.t90s,
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      );
      await _place(tester, _chockHeavy);
      final block = harness.lastLayout!.stopBlocks.single;
      final at = _screenPoint(
        tester,
        Vector3(
          (block.span.face + block.span.back) / 2,
          geometry.flatcar.deckTopY + block.heightM * 0.4,
          block.z,
        ),
      );

      await tester.dragFrom(at, const Offset(90, 0));
      await tester.pumpAndSettle();

      expect(harness.lastLayout, isNotNull,
          reason: 'dragging a block should have changed the layout');
      final moved = harness.lastLayout!.byId(block.id)!;
      // The pointer drags across the deck plane, so a diagonal drag moves the
      // block in both directions at once — which is the point of being able to
      // put it anywhere. What is guaranteed is that it moved, and that it is
      // still on the wagon.
      expect(moved.x != block.x || moved.z != block.z, isTrue,
          reason: 'the block did not move');
      const spec = FlatcarMeshSpec.standardFourAxle;
      expect(moved.x.abs(), lessThanOrEqualTo(spec.deckLengthM / 2));
      expect(moved.z.abs(), lessThanOrEqualTo(spec.deckWidthM / 2));
      expect(tester.takeException(), isNull);
    });

    testWidgets('a block dragged onto the track is seated against it',
        (tester) async {
      // The assist the trainee actually needs: near enough to the running
      // gear, the block lands under it at the handbook's own distance rather
      // than wherever the pointer happened to stop.
      final harness = await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);

      final geometry = resolveLoadingGeometry(
        vehicleSpec: TrackedVehicleMeshSpec.t90s,
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      );
      await _place(tester, _chockHeavy);
      final block = harness.lastLayout!.stopBlocks.single;
      final from = _screenPoint(
        tester,
        Vector3(
          (block.span.face + block.span.back) / 2,
          geometry.flatcar.deckTopY + block.heightM * 0.4,
          block.z,
        ),
      );
      // Aim at a point a little further along the same track: still well
      // inside the snap's reach.
      final to = _screenPoint(
        tester,
        Vector3(block.x + 0.30, geometry.flatcar.deckTopY, block.z),
      );

      await tester.dragFrom(from, to - from);
      await tester.pumpAndSettle();

      // Dragged onto the running gear, it seats itself at the handbook's own
      // distance rather than wherever the pointer happened to stop.
      final moved = harness.lastLayout!.byId(block.id)!;
      final front = geometry.vehicle.trackContactX.front + geometry.vehicleOffsetX;
      expect(moved.z, closeTo(geometry.vehicle.trackCenterZ, 1e-6));
      expect(moved.x, closeTo(front + 0.125, 1e-6));
      expect(moved.facing, ChockFacing.towardsRear);
    });

    testWidgets('dragging empty space orbits instead of moving anything',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware, snapSeatingDistanceM: 0.125);
      final surface = tester.getTopLeft(find.byKey(LoadingScene3DView.surfaceKey));
      // The top-left corner of the scene is sky.
      await tester.dragFrom(surface + const Offset(20, 18), const Offset(120, -40));
      await tester.pumpAndSettle();
      expect(harness.lastLayout, isNull);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the selected piece can be turned round and removed',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware, snapSeatingDistanceM: 0.125);
      await _place(tester, _chockHeavy);
      final added = harness.lastLayout!.stopBlocks.last;

      await tester.tap(find.text(AppStrings.scene3dFlipFacing));
      await tester.pumpAndSettle();
      expect(harness.lastLayout!.byId(added.id)!.facing, isNot(added.facing));

      await tester.tap(find.text(AppStrings.scene3dRemoveSelected));
      await tester.pumpAndSettle();
      expect(harness.lastLayout!.byId(added.id), isNull);
      expect(find.text(AppStrings.scene3dNothingSelected), findsOneWidget);
    });

    testWidgets('resetting hands back an empty layout, which is the handbook one',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware, snapSeatingDistanceM: 0.125);
      await _place(tester, _chockHeavy);
      await _place(tester, _insert);
      expect(harness.lastLayout!.blocks.length, 2);

      await tester.tap(find.text(AppStrings.scene3dResetLayout));
      await tester.pumpAndSettle();
      // Clearing the deck really clears it — there is no default to fall back
      // to any more.
      expect(harness.lastLayout!.isEmpty, isTrue);
      expect(find.text(AppStrings.scene3dPieceCount(0, 0)), findsOneWidget);
    });

    testWidgets('a wire lashing is on the palette like everything else',
        (tester) async {
      final harness = await _pump(tester, hardware: _hardware);
      await _place(tester, _wire);
      final added = harness.lastLayout!.lashings.last;
      expect(added.ringIndex, isNotNull);
      expect(added.kind, SecuringPieceKind.wireLashing);
    });

  });

  group('placing to the centimetre in the view', () {
    testWidgets('the centimetre panel appears once a block is selected',
        (tester) async {
      await _pump(tester, hardware: _hardware, snapSeatingDistanceM: 0.125);
      expect(find.text(AppStrings.scene3dPreciseHeading), findsNothing);
      await _place(tester, _chockHeavy);
      expect(find.text(AppStrings.scene3dPreciseHeading), findsOneWidget);
      expect(find.text(AppStrings.scene3dSeatingEntryLabel), findsOneWidget);
    });

    testWidgets('a nudge moves the block exactly one centimetre',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware, snapSeatingDistanceM: 0.125);
      await _place(tester, _chockHeavy);
      final before = harness.lastLayout!.stopBlocks.last;

      await tester.tap(find.widgetWithText(OutlinedButton, '+1').first);
      await tester.pumpAndSettle();
      final after = harness.lastLayout!.byId(before.id)!;
      expect(after.x - before.x, closeTo(0.01, 1e-9));
      // And across the wagon with the other pair.
      await tester.tap(find.widgetWithText(OutlinedButton, '−5').last);
      await tester.pumpAndSettle();
      expect(harness.lastLayout!.byId(before.id)!.z - after.z,
          closeTo(-0.05, 1e-9));
    });

    testWidgets('a typed distance seats the block exactly there',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);
      await _place(tester, _chockHeavy);

      await tester.enterText(
          find.byKey(LoadingScene3DView.seatingFieldKey), '11.0');
      await tester.tap(find.widgetWithText(OutlinedButton, AppStrings.scene3dApplyButton));
      await tester.pumpAndSettle();

      final geometry = resolveLoadingGeometry(
        vehicleSpec: TrackedVehicleMeshSpec.t90s,
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      );
      final moved = harness.lastLayout!.stopBlocks.last;
      final measured = measureBlockSeating(
        layout: SecuringLayout([moved]),
        vehicle: geometry.vehicle,
        vehicleOffsetX: geometry.vehicleOffsetX,
      ).single;
      expect(measured.seatingDistanceCm, closeTo(11.0, 1e-6));
    });

    testWidgets('the button that seats it to the plate uses the stated range',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);
      await _place(tester, _chockHeavy);
      await tester.tap(find.widgetWithText(
          OutlinedButton, AppStrings.scene3dSetToTarget(10, 15)));
      await tester.pumpAndSettle();

      final geometry = resolveLoadingGeometry(
        vehicleSpec: TrackedVehicleMeshSpec.t90s,
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      );
      final measured = measureBlockSeating(
        layout: SecuringLayout([harness.lastLayout!.stopBlocks.last]),
        vehicle: geometry.vehicle,
        vehicleOffsetX: geometry.vehicleOffsetX,
      ).single;
      // The middle of 10-15 cm.
      expect(measured.seatingDistanceCm, closeTo(12.5, 1e-6));
    });
  });

  group('working under the vehicle', () {
    testWidgets('the machine can be hidden, and says so while it is',
        (tester) async {
      await _pump(tester, hardware: _hardware, snapSeatingDistanceM: 0.125);
      expect(find.text(AppStrings.scene3dVehicleHiddenNote), findsNothing);

      await tester.tap(find.text(AppStrings.scene3dShowVehicle));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.scene3dVehicleHiddenNote), findsOneWidget);
      // The measurements are unchanged: they come from where the vehicle
      // stands, not from whether it is drawn.
      expect(find.text(AppStrings.scene3dMetres(3.54)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  group('choosing the distance before placing', () {
    testWidgets('a piece goes down at the distance that was typed for it',
        (tester) async {
      // The order the job is done in: pick the block, state the distance, set
      // it. Not: drop it somewhere and shuffle it afterwards.
      final harness = await _pump(tester,
          hardware: _hardware,
          snapSeatingDistanceM: 0.125,
          arrangement: _arrangement);

      await tester.enterText(
          find.byKey(LoadingScene3DView.placeAtFieldKey), '11');
      await tester.pumpAndSettle();
      await _place(tester, _chockHeavy);

      final geometry = resolveLoadingGeometry(
        vehicleSpec: TrackedVehicleMeshSpec.t90s,
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      );
      final measured = measureBlockSeating(
        layout: SecuringLayout([harness.lastLayout!.stopBlocks.single]),
        vehicle: geometry.vehicle,
        vehicleOffsetX: geometry.vehicleOffsetX,
      ).single;
      expect(measured.seatingDistanceCm, closeTo(11.0, 1e-6));
    });

    testWidgets('leaving it blank still places the piece, just not to a figure',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware, snapSeatingDistanceM: 0.125);
      await _place(tester, _chockHeavy);
      expect(harness.lastLayout!.stopBlocks, hasLength(1));
    });

    testWidgets('the field is not offered for a piece it does not apply to',
        (tester) async {
      // A wire lashing has no seating distance.
      await _pump(tester, hardware: const [_wire]);
      expect(find.text(AppStrings.scene3dPlaceAtLabel), findsNothing);
    });
  });

  group('a second vehicle on the same wagon', () {
    const companion = SceneCompanion(
      placementId: 'placement-1',
      designation: 'T-72',
      spec: TrackedVehicleMeshSpec.t72,
      positionFraction: 1.0,
    );

    testWidgets('the space between them is measured and shown', (tester) async {
      await _pump(tester,
          hardware: _hardware,
          companions: const [companion],
          requiredClearanceMm: 100);
      expect(find.text(AppStrings.scene3dGapLabel), findsOneWidget);
      expect(find.text(AppStrings.scene3dGapRequired(100)), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('with one vehicle there is no gap to report', (tester) async {
      await _pump(tester, hardware: _hardware);
      expect(find.text(AppStrings.scene3dGapLabel), findsNothing);
    });

    testWidgets('the gear panel still edits the selected vehicle only',
        (tester) async {
      final harness = await _pump(tester,
          hardware: _hardware,
          companions: const [companion],
          requiredClearanceMm: 100,
          snapSeatingDistanceM: 0.125);
      await _place(tester, _chockHeavy);
      // What comes back is this placement's layout, not the companion's.
      expect(harness.lastLayout!.stopBlocks, hasLength(1));
      expect(tester.takeException(), isNull);
    });
  });

  group('switching between the vehicles on a wagon', () {
    testWidgets('a selection does not follow the trainee to the other machine',
        (tester) async {
      // Piece ids restart at one in every layout, so a stale selection would
      // have pointed at the other machine's block of the same name — and the
      // next nudge would have moved that one.
      final harness = _Harness();
      // Rebuilt with whatever the view hands back, the way the real screen
      // does through its provider.
      Widget view(String placementId, SecuringLayout initial) => MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: SizedBox(
                  width: _surfaceWidth,
                  child: StatefulBuilder(
                    builder: (context, setState) => LoadingScene3DView(
                      vehicleSpec: TrackedVehicleMeshSpec.t90s,
                      flatcarSpec: FlatcarMeshSpec.standardFourAxle,
                      placementId: placementId,
                      designation: 'T-90S',
                      hardware: _hardware,
                      snapSeatingDistanceM: 0.125,
                      layout: harness.lastLayout ?? initial,
                      onLayoutChanged: (next) =>
                          setState(() => harness.lastLayout = next),
                    ),
                  ),
                ),
              ),
            ),
          );

      await tester.pumpWidget(view('placement-0', SecuringLayout.empty));
      await tester.pumpAndSettle();
      await _place(tester, _chockHeavy);
      expect(find.text(AppStrings.scene3dSelectedHeading), findsOneWidget);

      // The screen swaps to the other vehicle on the same wagon, whose layout
      // happens to contain a piece with the very same id.
      await tester.pumpWidget(view('placement-1', harness.lastLayout!));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.scene3dNothingSelected), findsOneWidget);
      expect(find.text(AppStrings.scene3dSelectedHeading), findsNothing);
    });
  });

  group('a lorry, whose blocks bear on its tyres', () {
    Future<_Harness> pumpLorry(WidgetTester tester) async {
      final harness = _Harness();
      const spec = WheeledVehicleMeshSpec(
        hullLengthM: 7.37,
        overallWidthM: 2.50,
        overallHeightM: 2.87,
        axleCount: 3,
      );
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(
              width: _surfaceWidth,
              child: StatefulBuilder(
                builder: (context, setState) => LoadingScene3DView(
                  vehicleSpec: spec,
                  flatcarSpec: FlatcarMeshSpec.standardFourAxle,
                  designation: 'Ural-4320',
                  hardware: _hardware,
                  snapSeatingDistanceM: 0.125,
                  layout: harness.lastLayout ?? SecuringLayout.empty,
                  onLayoutChanged: (next) =>
                      setState(() => harness.lastLayout = next),
                ),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return harness;
    }

    testWidgets('the distance to place at is measured from the wheel',
        (tester) async {
      await pumpLorry(tester);
      expect(find.text(AppStrings.scene3dPlaceAtWheelLabel), findsOneWidget);
      expect(find.text(AppStrings.scene3dPlaceAtLabel), findsNothing);
    });

    testWidgets('and the readout names the axle it is against', (tester) async {
      await pumpLorry(tester);
      await _place(tester, _chockHeavy);
      // "Tigirden aralygy — N-nji ok" rather than a distance from a track.
      expect(
        find.textContaining(AppStrings.scene3dWheelDistanceLabel),
        findsWidgets,
      );
      expect(find.text(AppStrings.scene3dSeatingDistanceLabel), findsNothing);
    });

    testWidgets('a tank still reads from its track', (tester) async {
      await _pump(tester, hardware: _hardware, snapSeatingDistanceM: 0.125);
      expect(find.text(AppStrings.scene3dPlaceAtLabel), findsOneWidget);
      expect(find.text(AppStrings.scene3dPlaceAtWheelLabel), findsNothing);
    });
  });
}
