@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/presentation/providers/consist_providers.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';
import 'package:railsim/presentation/widgets/equipment/consumables_panel.dart';
import 'package:railsim/presentation/widgets/equipment/lashing_angle_entry.dart';

/// The two panels added to the securing screen, pumped at the width they get
/// there.
///
/// A layout that overflows throws during a widget test, which is the same
/// defect the screenshot pass looks for and catches it without a display.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  Future<String> seedLorryOnWagon() async {
    await container.read(vehiclesProvider.future);
    await container.read(platformsProvider.future);
    await container.read(attachmentTypesProvider.future);
    await container.read(rulesProvider.future);
    await container.read(measurementsProvider.future);
    await container.read(referencesProvider.future);
    final platforms = await container.read(platformsProvider.future);
    final flatcar = platforms.first;
    container.read(selectedWagonTypeProvider.notifier).state = flatcar.id;
    container
        .read(consistProvider.notifier)
        .setWagons(count: 1, platformId: flatcar.id);
    return container
        .read(consistProvider.notifier)
        .place(vehicleId: 'veh-zil131', wagonIds: ['wagon-1']);
  }

  Future<void> pump(WidgetTester tester, Widget child, {double width = 900}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: SizedBox(width: width, child: child),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('the materials list lays out and names what is missing',
      (tester) async {
    // The catalogue is loaded from real asset files, so it has to run outside
    // the widget test's fake clock — inside it, the load never completes.
    final placementId = (await tester.runAsync(seedLorryOnWagon))!;
    final vehicles = (await tester.runAsync(
        () => container.read(vehiclesProvider.future)))!;
    final lorry = vehicles.firstWhere((v) => v.id == 'veh-zil131');

    await pump(
      tester,
      ConsumablesPanel(
        placementId: placementId,
        vehicle: lorry,
        requiredHardwareIds: const ['att-wood-chock', 'att-wire-lashing'],
      ),
    );

    expect(find.text(AppStrings.consumablesHeading), findsOneWidget);
    expect(find.text(AppStrings.consumableWoodChock), findsOneWidget);
    // No arrangement has been chosen and this lorry carries no weight, so the
    // quantities cannot be worked out — the lines must still be listed, with
    // the reason, rather than dropped.
    expect(find.text(AppStrings.consumableNeedsArrangement), findsWidgets);
  });

  testWidgets('a typed angle reaches the store and clearing it withdraws it',
      (tester) async {
    final placementId = (await tester.runAsync(seedLorryOnWagon))!;
    await pump(tester, LashingAngleEntry(placementId: placementId));

    expect(find.text(AppStrings.lashingAngleHeading), findsOneWidget);

    final axisField = find.byType(TextField).first;
    await tester.enterText(axisField, '30');
    await tester.pump();
    expect(
      container
          .read(userDimensionsProvider)[
              UserDimensionsNotifier.lashingAxisAngleKey(placementId)],
      30,
    );

    await tester.enterText(axisField, '');
    await tester.pump();
    expect(
      container.read(userDimensionsProvider).containsKey(
          UserDimensionsNotifier.lashingAxisAngleKey(placementId)),
      isFalse,
      reason: 'an emptied field must withdraw the measurement, not keep the '
          'last one standing',
    );
  });

  testWidgets('both panels lay out in a narrow workspace too', (tester) async {
    // The securing workspace shares the window with the placement picker, so
    // the panels have to hold together well below the full window width. An
    // overflow throws here, which is what this is for.
    final placementId = (await tester.runAsync(seedLorryOnWagon))!;
    final vehicles = (await tester.runAsync(
        () => container.read(vehiclesProvider.future)))!;
    final lorry = vehicles.firstWhere((v) => v.id == 'veh-zil131');

    await pump(
      tester,
      Column(children: [
        ConsumablesPanel(
          placementId: placementId,
          vehicle: lorry,
          requiredHardwareIds: const ['att-wood-chock', 'att-wire-lashing'],
        ),
        LashingAngleEntry(placementId: placementId),
      ]),
      width: 460,
    );

    expect(tester.takeException(), isNull);
  });

}
