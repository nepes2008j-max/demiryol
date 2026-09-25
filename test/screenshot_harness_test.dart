@Tags(['flutter'])
library;

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/core/theme/app_theme.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/presentation/providers/consist_providers.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';
import 'package:railsim/presentation/screens/consist/consist_setup_screen.dart';
import 'package:railsim/presentation/screens/engineering_analysis/engineering_analysis_screen.dart';
import 'package:railsim/presentation/screens/equipment/equipment_selection_screen.dart';
import 'package:railsim/presentation/screens/main_menu/main_menu_screen.dart';
import 'package:railsim/presentation/screens/placement/placement_screen.dart';
import 'package:railsim/presentation/screens/reference_browser/reference_browser_screen.dart';
import 'package:railsim/presentation/screens/result/result_screen.dart';
import 'package:railsim/presentation/screens/securing/securing_screen.dart';
import 'package:railsim/presentation/screens/vehicle_selection/vehicle_category_screen.dart';
import 'package:railsim/presentation/screens/vehicle_selection/vehicle_selection_screen.dart';
import 'package:railsim/presentation/screens/wagon_type/wagon_type_screen.dart';

/// Renders every screen to a PNG, for looking at the interface without a
/// window manager.
///
/// The application is a desktop program, and the machine this is developed on
/// has no way to raise its window for a screen capture — an obscured X window
/// captures whatever is in front of it. Pumping each screen in the widget
/// binding and taking the picture off its repaint boundary gives the same
/// pixels, deterministically, at whatever size is asked for.
///
///     RAILSIM_SHOTS=.impeccable/review flutter test test/screenshot_harness_test.dart
///
/// Set `RAILSIM_SHOT_WIDTH`/`RAILSIM_SHOT_HEIGHT` to capture another window
/// size. Without `RAILSIM_SHOTS` the whole file skips, so it costs nothing in
/// an ordinary test run.
void main() {
  final outDir = Platform.environment['RAILSIM_SHOTS'];
  final width = double.parse(Platform.environment['RAILSIM_SHOT_WIDTH'] ?? '1440');
  final height = double.parse(Platform.environment['RAILSIM_SHOT_HEIGHT'] ?? '900');

  setUpAll(() async {
    if (outDir == null) return;
    TestWidgetsFlutterBinding.ensureInitialized();
    // Widget tests letter everything in a placeholder face unless the real
    // ones are loaded, and this harness exists to look at the lettering.
    for (final family in const {
      'NotoSans': ['assets/fonts/NotoSans-Regular.ttf', 'assets/fonts/NotoSans-Bold.ttf'],
      'NotoSansMono': [
        'assets/fonts/NotoSansMono-Regular.ttf',
        'assets/fonts/NotoSansMono-Bold.ttf',
      ],
    }.entries) {
      final loader = FontLoader(family.key);
      for (final path in family.value) {
        loader.addFont(File(path).readAsBytes().then((b) => ByteData.view(b.buffer)));
      }
      await loader.load();
    }
    // The icon font too, or every icon captures as an empty box.
    // Walk up from the test shell to the engine cache it was run out of, and
    // take the icon font from beside it.
    File? iconFile;
    for (var dir = File(Platform.resolvedExecutable).parent;
        dir.path != dir.parent.path;
        dir = dir.parent) {
      final candidate = File('${dir.path}/material_fonts/MaterialIcons-Regular.otf');
      if (candidate.existsSync()) {
        iconFile = candidate;
        break;
      }
    }
    if (iconFile != null) {
      final icons = FontLoader('MaterialIcons');
      icons.addFont(iconFile.readAsBytes().then((b) => ByteData.view(b.buffer)));
      await icons.load();
    }
    Directory(outDir).createSync(recursive: true);
  });

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.physicalSize = Size(width, height);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized().platformDispatcher.views.first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  /// Lets the screen finish arriving before its picture is taken.
  ///
  /// Two different clocks have to run out. The repository reads its JSON off
  /// the real event loop, which only turns inside [WidgetTester.runAsync]; the
  /// entrance motion runs on the test's fake clock, which only advances on
  /// [WidgetTester.pump]. A capture that skips either one photographs a
  /// spinner or a half-settled screen and reads as a defect that is not there.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(seconds: 2));
  }

  /// Takes the picture off a repaint boundary and writes it.
  ///
  /// The image work runs inside [WidgetTester.runAsync] and the image is
  /// disposed: taken on the test's fake clock instead, the frame is rasterised
  /// but the test then never finishes, and every capture costs the ten-minute
  /// test timeout.
  Future<void> capture(WidgetTester tester, GlobalKey key, String path) async {
    final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1.0);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
      image.dispose();
    });
    // ignore: avoid_print
    print('WROTE $path');
  }

  /// Loads the handbook before the screen is built.
  ///
  /// Asset loading only turns on the real event loop, and after the first test
  /// in a file the binding will not resolve a `rootBundle` read raised from
  /// inside a pumped tree at all — the second screen onwards photographs its
  /// own loading spinner. Warming a container first, inside
  /// [WidgetTester.runAsync], means every screen is built against data that
  /// has already arrived, which is also the state a trainee ever sees.
  Future<ProviderContainer> warmed(WidgetTester tester) async {
    final container = ProviderContainer();
    await tester.runAsync(() async {
      await Future.wait([
        container.read(vehiclesProvider.future),
        container.read(platformsProvider.future),
        container.read(attachmentTypesProvider.future),
        container.read(principlesProvider.future),
        container.read(referencesProvider.future),
        container.read(photosProvider.future),
        container.read(vehiclePhotosProvider.future),
        container.read(ruleEntriesProvider.future),
        container.read(measurementsProvider.future),
        container.read(rulesProvider.future),
        container.read(referenceLinkerProvider.future),
        container.read(vehicleModelAssetsProvider.future),
      ]);
    });
    return container;
  }

  Future<void> shoot(WidgetTester tester, String name, Widget screen) async {
    final key = GlobalKey();
    final container = await warmed(tester);
    addTearDown(container.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: key, child: screen),
      ),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull, reason: name);

    await capture(tester, key, '$outDir/$name.png');
  }

  /// Seeds a container with the attempt a trainee actually has in front of
  /// them by the time these screens matter: a consist with wagons of a real
  /// platform type, a vehicle ordered, and that vehicle standing on wagon one.
  /// The empty-attempt captures above show the empty states; these show the
  /// screens doing their job.
  Future<void> loadAttempt(WidgetTester tester, ProviderContainer c) async {
    final platforms = c.read(platformsProvider).valueOrNull!;
    final vehicles = c.read(vehiclesProvider).valueOrNull!;
    final platform = platforms.first;
    final vehicle = vehicles.firstWhere((v) => v.id == 'veh-t72', orElse: () => vehicles.first);
    c.read(wagonCountProvider.notifier).state = 3;
    c.read(selectedWagonTypeProvider.notifier).state = platform.id;
    c.read(vehicleOrdersProvider.notifier).add(vehicle.id);
    c.read(consistProvider.notifier).setWagons(count: 3, platformId: platform.id);
    final wagon = c.read(consistProvider).wagons.first;
    final placementId =
        c.read(consistProvider.notifier).place(vehicleId: vehicle.id, wagonIds: [wagon.id]);
    c.read(selectedPlacementIdProvider.notifier).state = placementId;
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));

    // Choose a chock arrangement and seat two stop blocks against the running
    // gear. Without these the value strip has nothing to draw a band for: a
    // seating distance is only judged once an arrangement states a range, and
    // that pair is what the tolerance scales are made of.
    final arrangements = c.read(placementChockArrangementsProvider(placementId));
    if (arrangements.isNotEmpty) {
      c
          .read(placementChockChoiceProvider.notifier)
          .chooseArrangement(placementId, arrangements.first.id);
    }
    // Hold an iron spur, so the capture shows the handbook figure that the
    // picker now puts beside the piece being placed.
    c.read(placementSecuringLayoutProvider.notifier).put(
          placementId,
          const SecuringLayout([
            SecuringPiece(
              id: 'shot-block-front',
              kind: SecuringPieceKind.woodChock,
              x: -2.25,
              z: 0.9,
              widthM: 0.2,
              heightM: 0.15,
              lengthM: 0.5,
            ),
            SecuringPiece(
              id: 'shot-block-rear',
              kind: SecuringPieceKind.woodChock,
              x: 2.25,
              z: -0.9,
              widthM: 0.2,
              heightM: 0.15,
              lengthM: 0.5,
            ),
            // Two spurs of the four a set carries, one of them the wrong type
            // for a T-72 — so the result sheet has something to report at
            // every one of the four stations: two bare, one wrong, one right.
            SecuringPiece(
              id: 'shot-spur-left-rear',
              kind: SecuringPieceKind.ironSpur,
              x: -2.15,
              z: -0.9,
              widthM: 0.14,
              heightM: 0.042,
              lengthM: 0.585,
              sizeTypeCode: 'Ş-137',
            ),
            SecuringPiece(
              id: 'shot-spur-right-front',
              kind: SecuringPieceKind.ironSpur,
              x: 2.15,
              z: 0.9,
              widthM: 0.13,
              heightM: 0.037,
              lengthM: 0.375,
              facing: ChockFacing.towardsRear,
              sizeTypeCode: 'Ş-350',
            ),
          ]),
        );
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 250)));
  }

  final screens = <String, Widget Function()>{
    'menu': MainMenuScreen.new,
    'consist': ConsistSetupScreen.new,
    'categories': VehicleCategoryScreen.new,
    'vehicles': VehicleSelectionScreen.new,
    'wagon-type': WagonTypeScreen.new,
    'placement': PlacementScreen.new,
    'equipment': EquipmentSelectionScreen.new,
    'securing': SecuringScreen.new,
    'analysis': EngineeringAnalysisScreen.new,
    'result': ResultScreen.new,
    'reference': ReferenceBrowserScreen.new,
  };

  screens.forEach((name, build) {
    testWidgets('shot: $name', (tester) async {
      if (outDir == null) {
        markTestSkipped('set RAILSIM_SHOTS to capture the screens');
        return;
      }
      await shoot(tester, name, build());
    });
  });

  final loaded = <String, Widget Function()>{
    'placement': PlacementScreen.new,
    'equipment': EquipmentSelectionScreen.new,
    'securing': SecuringScreen.new,
    'analysis': EngineeringAnalysisScreen.new,
    'result': ResultScreen.new,
  };

  loaded.forEach((name, build) {
    testWidgets('shot: $name loaded', (tester) async {
      if (outDir == null) {
        markTestSkipped('set RAILSIM_SHOTS to capture the screens');
        return;
      }
      final key = GlobalKey();
      // The result sheet is a long document — the verdict, the readings, the
      // spur stations, the seated blocks and the mark. At the window's own
      // height the capture stops a third of the way down it, which is no use
      // for looking at the part that reports mistakes.
      if (name == 'result') {
        final view = TestWidgetsFlutterBinding.ensureInitialized()
            .platformDispatcher
            .views
            .first;
        view.physicalSize = Size(width, height * 2.4);
      }
      final container = await warmed(tester);
      addTearDown(container.dispose);
      await loadAttempt(tester, container);
      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.dark,
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(key: key, child: build()),
        ),
      ));
      await settle(tester);
      expect(tester.takeException(), isNull, reason: name);
      await capture(tester, key, '$outDir/$name-loaded.png');
    });
  });

  testWidgets('shot: consist with wagons', (tester) async {
    if (outDir == null) {
      markTestSkipped('set RAILSIM_SHOTS to capture the screens');
      return;
    }
    // The counter screen with something on it, so the consist strip is drawn
    // rather than being captured empty.
    final key = GlobalKey();
    final container = await warmed(tester);
    addTearDown(container.dispose);
    container.read(wagonCountProvider.notifier).state = 7;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: RepaintBoundary(key: key, child: const ConsistSetupScreen()),
      ),
    ));
    await settle(tester);
    expect(tester.takeException(), isNull);
    await capture(tester, key, '$outDir/consist-loaded.png');
  });
}
