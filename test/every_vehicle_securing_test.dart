import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/data/repositories/handbook_repository.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/securing_hardware_catalog.dart';
import 'package:railsim/domain/usecases/securing_measurements.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_catalog.dart';
import 'package:railsim/presentation/widgets/visualization/loading_scene_3d_view.dart';

import 'support/catalogue_sample.dart';

/// The securing step, played through by hand on every vehicle that has a
/// model — not merely built, but *used*.
///
/// `playthrough_test.dart` walks the six screens and proves none of them
/// throws. This goes one level in: for each modellable vehicle it takes the
/// palette that vehicle's own record resolves, and for every entry on it
/// states a distance, puts the piece down, and checks that the piece landed
/// where the trainee asked for it. That is the whole examination loop, and
/// until this existed it had only ever been exercised on the T-90S.
///
/// Two things it is specifically watching for: a palette entry that cannot be
/// placed at all, and a piece that reports a seating distance other than the
/// one that was typed — either of which would mark a trainee wrong for the
/// application's mistake.
void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1400, 1400);
    view.devicePixelRatio = 1.0;
  });

  tearDown(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.resetPhysicalSize();
    view.resetDevicePixelRatio();
  });

  const surfaceWidth = 1200.0;
  final repository = HandbookRepository();
  final problems = <String>[];
  final report = <String>[];

  String optionLabel(PlaceableHardware h) =>
      AppStrings.scene3dHardwareOption(
          AppStrings.scene3dPieceKindLabel(h.kind.name), h.typeCode) +
      (h.matchesVehicle ? AppStrings.scene3dHardwareMatchesVehicle : '');

  testWidgets('every modellable vehicle can be secured by hand',
      (tester) async {
      // Inside runAsync: the repository reads the catalogue off the asset
      // bundle and that is real I/O, which a widget test's fake clock never
      // gives a turn. Awaited outside runAsync it never completes and the
      // test sits until the timeout — which is what happened the moment the
      // catalogue grew past the size that used to resolve without one.
      late final List<Vehicle> vehicles;
      late final Map<String, dynamic> measurements;
      late final Map<String, dynamic> rules;
      late final List<AttachmentType> attachments;
      await tester.runAsync(() async {
        vehicles = sweepSample(await repository.getVehicles());
        measurements = await repository.getMeasurements();
        rules = await repository.getRules();
        attachments = await repository.getAttachmentTypes();
      });

    var played = 0;
    for (final vehicle in vehicles) {
      final spec = VehicleMeshCatalog.specFor(vehicle);
      if (spec == null) continue;
      played++;

      final palette = placeableHardwareFor(
        vehicle: vehicle,
        measurements: measurements,
        rules: rules,
        attachments: attachments,
      );
      if (palette.isEmpty) {
        problems.add('${vehicle.id}: nothing on the palette to place');
        continue;
      }

      final geometry = resolveLoadingGeometry(
        vehicleSpec: spec,
        flatcarSpec: FlatcarMeshSpec.standardFourAxle,
      );

      var placed = 0;
      for (final piece in palette) {
        SecuringLayout? layout;
        await tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SizedBox(
                width: surfaceWidth,
                child: StatefulBuilder(
                  builder: (context, setState) => LoadingScene3DView(
                    vehicleSpec: spec,
                    flatcarSpec: FlatcarMeshSpec.standardFourAxle,
                    designation: vehicle.handbookDesignation,
                    layout: layout ?? SecuringLayout.empty,
                    onLayoutChanged: (next) => setState(() => layout = next),
                    hardware: palette,
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final wantsDistance =
            find.byKey(LoadingScene3DView.placeAtFieldKey).evaluate().isNotEmpty;
        if (wantsDistance) {
          await tester.enterText(
              find.byKey(LoadingScene3DView.placeAtFieldKey), '11');
          await tester.pumpAndSettle();
        }

        // When the piece is already the row the dropdown shows shut — which is
        // whichever one the vehicle resolves by default — its label is on
        // screen without opening the menu, and it is already the selection.
        // Tapping that label would only *open* the menu (and drop it over the
        // "add" button, so the add never lands), so in that case go straight
        // to adding it. Otherwise open the menu, scroll the row into view, and
        // pick it.
        final alreadyShown =
            find.text(optionLabel(piece)).evaluate().isNotEmpty;
        if (!alreadyShown) {
          // The dropdown shows one entry at a time; open it to reach the rest.
          await tester.tap(find.byType(DropdownButton<String>));
          await tester.pumpAndSettle();
          if (find.text(optionLabel(piece)).evaluate().isEmpty) {
            // The open menu is a list, and it opens scrolled to whichever row
            // the vehicle already resolves, so an entry above or below that one
            // is not built yet. A trainee scrolls to it; so does this.
            await tester.scrollUntilVisible(
              find.text(optionLabel(piece)),
              -60,
              scrollable: find.byType(Scrollable).last,
              maxScrolls: 60,
            );
            await tester.pumpAndSettle();
          }
          if (find.text(optionLabel(piece)).evaluate().isEmpty) {
            problems.add('${vehicle.id}: "${optionLabel(piece)}" is not on the '
                'palette the view offers');
            continue;
          }
          await tester.tap(find.text(optionLabel(piece)).last);
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text(AppStrings.scene3dAddSelected));
        await tester.pumpAndSettle();

        final thrown = tester.takeException();
        if (thrown != null) {
          problems.add('${vehicle.id} / ${piece.kind.name} ${piece.typeCode}: '
              '${thrown.toString().split('\n').first}');
          continue;
        }
        if (layout == null || layout!.pieces.length != 1) {
          problems.add('${vehicle.id} / ${piece.kind.name} ${piece.typeCode}: '
              'tapping "add" put ${layout?.pieces.length ?? 0} pieces on the '
              'deck, not one');
          continue;
        }
        placed++;

        // Where it says it is, measured the way the result sheet measures it.
        final put = layout!.pieces.single;
        if (put.isStopBlock && wantsDistance) {
          final measured = measureBlockSeating(
            layout: SecuringLayout([put]),
            vehicle: geometry.vehicle,
            vehicleOffsetX: geometry.vehicleOffsetX,
          ).single;
          if ((measured.seatingDistanceCm - 11.0).abs() > 0.05) {
            problems.add('${vehicle.id} / ${piece.kind.name} '
                '${piece.typeCode}: asked for 11 cm, seated at '
                '${measured.seatingDistanceCm.toStringAsFixed(1)} cm');
          }
        }

        // And on the wagon, not beside it.
        final deck = geometry.flatcar.mesh.bounds;
        if (put.x < deck.min.x - 0.01 || put.x > deck.max.x + 0.01) {
          problems.add('${vehicle.id} / ${piece.kind.name} ${piece.typeCode}: '
              'landed at x=${put.x.toStringAsFixed(2)} m, off a deck running '
              '${deck.min.x.toStringAsFixed(2)}..${deck.max.x.toStringAsFixed(2)} m');
        }
      }

      report.add('${vehicle.id.padRight(18)} '
          '${vehicle.category.name.padRight(8)} '
          'palette=${palette.length.toString().padLeft(2)} '
          'placed=${placed.toString().padLeft(2)}');
    }

    // ignore: avoid_print
    print('\n=== securing played by hand ===');
    for (final line in report) {
      // ignore: avoid_print
      print(line);
    }
    // ignore: avoid_print
    print('\n=== problems (${problems.length}) ===');
    for (final p in problems) {
      // ignore: avoid_print
      print('  $p');
    }

    expect(played, greaterThan(4), reason: 'no vehicle was actually played');
    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 15)));
}
