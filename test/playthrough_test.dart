import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/core/theme/app_theme.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/data/repositories/handbook_repository.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_catalog.dart';
import 'package:railsim/presentation/providers/consist_providers.dart';
import 'package:railsim/presentation/screens/engineering_analysis/engineering_analysis_screen.dart';
import 'package:railsim/presentation/screens/placement/placement_screen.dart';
import 'package:railsim/presentation/screens/result/result_screen.dart';
import 'package:railsim/presentation/screens/securing/securing_screen.dart';
import 'package:railsim/presentation/screens/vehicle_selection/vehicle_selection_screen.dart';
import 'package:railsim/presentation/screens/wagon_type/wagon_type_screen.dart';

import 'support/catalogue_sample.dart';

/// A full attempt, for every vehicle in the catalogue.
///
/// The screens had only ever been *built*; nothing had ever loaded one with a
/// real vehicle on a real wagon and walked it to the result sheet. This does
/// that once per vehicle: it puts the machine on the train the way the
/// interface does, pumps every screen of the flow in order, and asserts that
/// nothing throws and nothing overflows anywhere along the way.
void main() {
  late ProviderContainer container;

  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(1700, 1400);
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

  final problems = <String>[];

  Future<void> pump(WidgetTester tester, Widget screen, String where) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: AppTheme.dark, home: screen),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));
    final thrown = tester.takeException();
    if (thrown != null) {
      // Collected rather than thrown, so one bad screen does not hide the
      // other five and the next twenty-five vehicles.
      final text = thrown.toString().split('\n').first;
      problems.add('$where: $text');
    }
  }

  /// Everything the interface would have set by the time step 4 is reached.
  Future<String> loadOne(Vehicle vehicle, {int copies = 1}) async {
    container.read(traineeProvider.notifier).set('Aman', 'Amanow');
    container.read(wagonCountProvider.notifier).state = 1;
    container.read(selectedWagonTypeProvider.notifier).state =
        'plat-generic-open-flatcar';
    container
        .read(consistProvider.notifier)
        .setWagons(count: 1, platformId: 'plat-generic-open-flatcar');
    final wagon = container.read(consistProvider).wagons.first;
    var first = '';
    for (var i = 0; i < copies; i++) {
      final id = container
          .read(consistProvider.notifier)
          .place(vehicleId: vehicle.id, wagonIds: [wagon.id]);
      if (i == 0) first = id;
    }
    container.read(selectedPlacementIdProvider.notifier).state = first;
    return first;
  }

  final repository = HandbookRepository();

  testWidgets('every vehicle walks the whole flow', (tester) async {
      // Inside runAsync: the repository reads the catalogue off the asset
      // bundle and that is real I/O, which a widget test's fake clock never
      // gives a turn. Awaited outside runAsync it never completes and the
      // test sits until the timeout — which is what happened the moment the
      // catalogue grew past the size that used to resolve without one.
      late final List<Vehicle> vehicles;
      await tester.runAsync(() async {
        vehicles = sweepSample(await repository.getVehicles());
      });
    expect(vehicles, isNotEmpty);

    final report = <String>[];
    for (final vehicle in vehicles) {
      container = ProviderContainer();
      addTearDown(container.dispose);
      final placementId = await loadOne(vehicle);

      for (final entry in <String, Widget>{
        'vehicles': const VehicleSelectionScreen(),
        'wagon-type': const WagonTypeScreen(),
        'placement': const PlacementScreen(),
        'securing': const SecuringScreen(),
        'analysis': const EngineeringAnalysisScreen(),
        'result': const ResultScreen(),
      }.entries) {
        await pump(tester, entry.value, '${vehicle.id} / ${entry.key}');
      }

      // What the engine made of it, recorded so the walk reports rather than
      // only passing.
      final results = container.read(placementResultsProvider).valueOrNull;
      final result = results?[placementId];
      final modelled = VehicleMeshCatalog.canModel(vehicle);
      report.add('${vehicle.id.padRight(20)} '
          '${modelled ? '3D' : '  '} '
          'checks=${result?.checks.length ?? 0} '
          'pass=${result?.passCount ?? 0} '
          'fail=${result?.failCount ?? 0} '
          'unknown=${result?.unknownCount ?? 0} '
          'hardware=${result?.requiredHardwareIds.join(',') ?? ''}');
    }

    // ignore: avoid_print
    print('\n=== one attempt per vehicle ===');
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
    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));

  testWidgets('and again with two of it on the one wagon', (tester) async {
    // The wagon takes more than one machine, and a second one changes what
    // every screen has to say: the gap between them is measured, the overhang
    // is measured from where they actually stand, and the securing step has
    // to know which of the two the trainee is working on. None of that had
    // ever been walked end to end.
    //
    // Two of most of these vehicles do not fit a 13.30 m deck at all. That is
    // a legitimate answer for the screens to give — it is not a reason for
    // them to throw, which is what this checks.
      // Inside runAsync: the repository reads the catalogue off the asset
      // bundle and that is real I/O, which a widget test's fake clock never
      // gives a turn. Awaited outside runAsync it never completes and the
      // test sits until the timeout — which is what happened the moment the
      // catalogue grew past the size that used to resolve without one.
      late final List<Vehicle> vehicles;
      await tester.runAsync(() async {
        vehicles = sweepSample(await repository.getVehicles());
      });
    final report = <String>[];
    for (final vehicle in vehicles) {
      if (!VehicleMeshCatalog.canModel(vehicle)) continue;
      container = ProviderContainer();
      addTearDown(container.dispose);
      final placementId = await loadOne(vehicle, copies: 2);

      for (final entry in <String, Widget>{
        'placement': const PlacementScreen(),
        'securing': const SecuringScreen(),
        'analysis': const EngineeringAnalysisScreen(),
        'result': const ResultScreen(),
      }.entries) {
        await pump(tester, entry.value, '${vehicle.id} x2 / ${entry.key}');
      }

      final consist = container.read(consistProvider);
      final wagonId = consist.wagons.first.id;
      final overhang = container.read(wagonOverhangProvider(wagonId));
      final results = container.read(placementResultsProvider).valueOrNull;
      report.add('${vehicle.id.padRight(18)} '
          'placements=${consist.placements.length} '
          'overhang=${overhang?.toStringAsFixed(2) ?? 'none'} '
          'checked=${results?[placementId] != null}');
    }

    // ignore: avoid_print
    print('\n=== two per wagon ===');
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
    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
