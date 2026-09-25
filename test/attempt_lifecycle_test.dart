import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/models/trainee.dart';
import 'package:railsim/presentation/providers/consist_providers.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';
import 'package:railsim/presentation/widgets/common/trainee_dialog.dart';

/// One attempt from beginning to end: who sat it, and that finishing it really
/// does leave nothing behind for the next one.
void main() {
  group('the trainee', () {
    test('needs both halves of a name before an attempt can begin', () {
      expect(Trainee.unknown.isComplete, isFalse);
      expect(const Trainee(givenName: 'Aman', familyName: '').isComplete, isFalse);
      expect(const Trainee(givenName: '', familyName: 'Amanow').isComplete, isFalse);
      // Whitespace is not a name.
      expect(const Trainee(givenName: '  ', familyName: 'Amanow').isComplete,
          isFalse);
      expect(const Trainee(givenName: 'Aman', familyName: 'Amanow').isComplete,
          isTrue);
    });

    test('reads family name first, the way a register is written', () {
      const t = Trainee(givenName: ' Aman ', familyName: ' Amanow ');
      expect(t.displayName, 'Amanow Aman');
      expect(Trainee.unknown.displayName, isEmpty);
    });
  });

  group('finishing an attempt', () {
    test('clears every piece of state the attempt touched', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Put the container in the state a finished attempt leaves it in.
      container.read(traineeProvider.notifier).set('Aman', 'Amanow');
      container.read(vehicleOrdersProvider.notifier).add('veh-t72');
      container.read(equipmentOrdersProvider.notifier).add(
          EquipmentOrdersNotifier.keyFor(SecuringPieceKind.ironSpur, 'Ş-137'));
      container.read(wagonCountProvider.notifier).state = 3;
      container.read(selectedWagonTypeProvider.notifier).state = 'plat-x';
      container.read(selectedPlacementIdProvider.notifier).state = 'placement-0';
      container
          .read(consistProvider.notifier)
          .setWagons(count: 2, platformId: 'plat-x');
      final placementId = container
          .read(consistProvider.notifier)
          .place(vehicleId: 'veh-t72', wagonIds: ['wagon-0']);
      container
          .read(placementEquipmentProvider.notifier)
          .select(placementId, 'att-iron-spur', 'Ş-137');
      container.read(placementSecuringMethodProvider.notifier).apply(placementId, 3);
      container.read(placementSecuringLayoutProvider.notifier).put(
            placementId,
            const SecuringLayout([
              SecuringPiece(
                  id: 'woodChock-1',
                  kind: SecuringPieceKind.woodChock,
                  x: 1,
                  z: 1),
            ]),
          );
      container
          .read(userDimensionsProvider.notifier)
          .set(UserDimensionsNotifier.weightKey('veh-t72'), 41);

      expect(container.read(consistProvider).placements, isNotEmpty);

      // A widget ref is what `resetAttempt` takes, so drive it through one.
      final tester = _RefHarness(container);
      resetAttempt(tester.ref);

      expect(container.read(traineeProvider), Trainee.unknown);
      expect(container.read(consistProvider).placements, isEmpty);
      expect(container.read(consistProvider).wagons, isEmpty);
      // The two order tallies are on `resetAttempt`'s list and were the two
      // entries this test did not hold it to.
      expect(container.read(vehicleOrdersProvider), isEmpty);
      expect(container.read(equipmentOrdersProvider), isEmpty);
      expect(container.read(placementEquipmentProvider), isEmpty);
      expect(container.read(placementSecuringMethodProvider), isEmpty);
      expect(container.read(placementChockChoiceProvider), isEmpty);
      expect(container.read(placementSecuringLayoutProvider), isEmpty);
      expect(container.read(userDimensionsProvider), isEmpty);
      expect(container.read(attemptLogProvider), isEmpty);
      expect(container.read(wagonCountProvider), 0);
      expect(container.read(selectedWagonTypeProvider), isNull);
      expect(container.read(selectedPlacementIdProvider), isNull);
      expect(container.read(selectedVehicleCategoryProvider), isNull);
    });
  });

  group('the name dialog', () {
    testWidgets('will not let an attempt begin without both halves',
        (tester) async {
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            captured = ref;
            return Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTraineeDialog(context, ref),
                  child: const Text('start'),
                ),
              ),
            );
          }),
        ),
      ));

      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.traineeDialogTitle), findsOneWidget);

      // The begin button is dead until both fields are filled.
      final begin = find.widgetWithText(ElevatedButton, AppStrings.traineeBeginButton);
      expect(tester.widget<ElevatedButton>(begin).onPressed, isNull);
      expect(find.text(AppStrings.traineeIncompleteNote), findsOneWidget);

      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.traineeFamilyNameHint), 'Amanow');
      await tester.pumpAndSettle();
      // Still only half a name.
      expect(tester.widget<ElevatedButton>(begin).onPressed, isNull);

      await tester.enterText(
          find.widgetWithText(TextField, AppStrings.traineeGivenNameHint), 'Aman');
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(begin).onPressed, isNotNull);
      expect(find.text(AppStrings.traineeIncompleteNote), findsNothing);

      await tester.tap(begin);
      await tester.pumpAndSettle();
      expect(captured.read(traineeProvider).displayName, 'Amanow Aman');
    });

    testWidgets('cancelling leaves the name unset', (tester) async {
      late WidgetRef captured;
      await tester.pumpWidget(ProviderScope(
        child: MaterialApp(
          home: Consumer(builder: (context, ref, _) {
            captured = ref;
            return Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showTraineeDialog(context, ref),
                  child: const Text('start'),
                ),
              ),
            );
          }),
        ),
      ));
      await tester.tap(find.text('start'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.traineeCancelButton));
      await tester.pumpAndSettle();
      expect(captured.read(traineeProvider).isComplete, isFalse);
    });
  });
}

/// `resetAttempt` takes a [WidgetRef]; this hands it one backed by a plain
/// container so the reset can be tested without pumping a widget tree.
class _RefHarness {
  final ProviderContainer container;
  _RefHarness(this.container);
  WidgetRef get ref => _ContainerRef(container);
}

class _ContainerRef implements WidgetRef {
  final ProviderContainer _container;
  _ContainerRef(this._container);

  @override
  BuildContext get context => throw UnimplementedError();

  @override
  T read<T>(ProviderListenable<T> provider) => _container.read(provider);

  @override
  noSuchMethod(Invocation invocation) => throw UnimplementedError();
}
