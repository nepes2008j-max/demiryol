import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/core/theme/app_theme.dart';
import 'package:railsim/data/repositories/handbook_repository.dart';
import 'package:railsim/presentation/providers/consist_providers.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';
import 'package:railsim/presentation/screens/placement/placement_screen.dart';

import 'support/catalogue_sample.dart';

/// A vehicle that has been put on a wagon must be removable again.
///
/// It was not. The row that carries the delete button laid the vehicle's
/// designation out at its full intrinsic width, so on any vehicle with a long
/// name the row overflowed to the right and the button was pushed past the
/// edge of the panel — where a clipped child is neither drawn nor hit-tested.
/// The trainee saw no way to take the machine off the train and could not tap
/// the button even knowing where it should be. This walks every vehicle in
/// the catalogue, taps the button, and checks the placement is gone.
void main() {
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

  testWidgets('every vehicle can be taken off the wagon again', (tester) async {
      // Inside runAsync: the repository reads the catalogue off the asset
      // bundle and that is real I/O, which a widget test's fake clock never
      // gives a turn. Awaited outside runAsync it never completes and the
      // test sits until the timeout — which is what happened the moment the
      // catalogue grew past the size that used to resolve without one.
      late final List<Vehicle> vehicles;
      await tester.runAsync(() async {
        vehicles = sweepSample(await HandbookRepository().getVehicles());
      });
    final problems = <String>[];

    for (final vehicle in vehicles) {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      container.read(traineeProvider.notifier).set('Aman', 'Amanow');
      container.read(wagonCountProvider.notifier).state = 1;
      container.read(selectedWagonTypeProvider.notifier).state =
          'plat-generic-open-flatcar';
      container
          .read(consistProvider.notifier)
          .setWagons(count: 1, platformId: 'plat-generic-open-flatcar');
      final wagon = container.read(consistProvider).wagons.first;
      final placementId = container
          .read(consistProvider.notifier)
          .place(vehicleId: vehicle.id, wagonIds: [wagon.id]);
      container.read(selectedPlacementIdProvider.notifier).state = placementId;

      // The screen's own providers read the catalogue off the asset bundle,
      // so they are warmed on the real clock before the tree is built. Pumped
      // cold, the screen is still showing its loading spinner when the button
      // is looked for, and the test reports a missing control that is simply
      // not drawn yet.
      await tester.runAsync(() async {
        await container.read(vehiclesProvider.future);
        await container.read(platformsProvider.future);
        await container.read(attachmentTypesProvider.future);
        await container.read(measurementsProvider.future);
        await container.read(rulesProvider.future);
        await container.read(referenceLinkerProvider.future);
      });

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: AppTheme.dark, home: const PlacementScreen()),
      ));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final button = find.byTooltip(AppStrings.placementRemove);
      if (button.evaluate().isEmpty) {
        problems.add('${vehicle.id}: no remove button on the placement row');
        continue;
      }
      // Without scrolling. The button was reachable in principle before this
      // — it was simply about 2,600 pixels down the card, past every diagram,
      // and one scroll to the end of the list did not get there. A control
      // the trainee cannot find is a control they do not have.
      final rect = tester.getRect(button.first);
      final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
      if (rect.bottom > screen.height || rect.top < 0) {
        problems.add('${vehicle.id}: the remove button is off-screen at '
            'y=${rect.top.toStringAsFixed(0)}..${rect.bottom.toStringAsFixed(0)} '
            'on a ${screen.height.toStringAsFixed(0)}px screen');
        continue;
      }
      await tester.tap(button.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 120));

      final thrown = tester.takeException();
      if (thrown != null) {
        problems.add('${vehicle.id}: ${thrown.toString().split('\n').first}');
        continue;
      }
      if (container.read(consistProvider).placements.isNotEmpty) {
        problems.add('${vehicle.id}: tapping remove left the vehicle on the '
            'wagon');
      }
    }

    // ignore: avoid_print
    print('\n=== remove problems (${problems.length}) ===');
    for (final p in problems) {
      // ignore: avoid_print
      print('  $p');
    }
    expect(problems, isEmpty);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
