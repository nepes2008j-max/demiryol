@Tags(['flutter'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/data/repositories/handbook_repository.dart';
import 'package:railsim/presentation/widgets/cards/vehicle_card.dart';
import 'package:railsim/presentation/widgets/common/data_source_badge.dart';

/// The selection entry has to survive the longest thing it can be asked to
/// show, because what it gave up first was the vehicle's name.
///
/// The card once laid the designation, the data-source badge, the completeness
/// badge and the info button out in one Row, with the designation Expanded.
/// Expanded yields before anything else does, so on the T-72 — whose source
/// badge reads ÖNDÜRIJINIŇ MAGLUMATY, twenty-one characters — the name was
/// squeezed away to nothing and the badges overflowed the card by 42 pixels
/// anyway. A trainee looking for the T-72 saw two badges and no T-72.
///
/// Only the vehicles that carry a source badge are exercised: a
/// handbook-sourced record renders none, so it was never the tight case, and
/// pumping all twenty-eight cards costs minutes for no extra coverage.
///
/// The card letters the designation and its control as instrument legends —
/// mono, uppercase — so the finders here uppercase what they look for. What is
/// being checked is unchanged: that the name and the control are still on the
/// card and still inside its cell.
void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    // A surface tall enough to hold an entry at its natural height. The
    // default test window is 600 px, and a stacked entry at 260 px wide is
    // taller than that — measured in a 600 px window it reports an overflow
    // that says nothing about the entry and everything about the window. The
    // height bounds below are what actually guard its growth.
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1400, 1600)
      ..devicePixelRatio = 1.0;
  });

  tearDown(() {
    binding.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  late List<Vehicle> badged;
  final cellKey = GlobalKey();

  setUpAll(() async {
    final all = await HandbookRepository().getVehicles();
    badged = all.where((v) => DataSourceBadge.isVisible(v.dataSource)).toList();
  });

  Future<void> pumpCard(WidgetTester tester, Vehicle vehicle, double width) async {
    // The entry reaches for the photo providers, so it needs a scope even
    // though this test never gives it a picture.
    //
    // The width is pinned and the height is not: the entry is a row in a list
    // now, so it takes the height its content needs. What is checked is that
    // it never overflows sideways, never loses its name, and never grows past
    // the bound it publishes.
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              key: cellKey,
              width: width,
              child: VehicleCard(vehicle: vehicle, onTap: () {}, onInfoTap: () {}),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets('a badged card fits its width, and keeps its name', (tester) async {
    expect(badged, isNotEmpty, reason: 'nothing carries a source badge any more');

    // A width the list actually renders at, then the two narrow cases the
    // stacked fallback has to survive.
    for (final width in <double>[860, 320, 260]) {
      for (final vehicle in badged) {
        await pumpCard(tester, vehicle, width);
        expect(tester.takeException(), isNull,
            reason: '${vehicle.handbookDesignation} overflows at ${width}px');
        expect(find.text(vehicle.handbookDesignation.toUpperCase()), findsOneWidget,
            reason: '${vehicle.handbookDesignation} lost its name at ${width}px');
        expect(find.text(AppStrings.selectVehicleButton.toUpperCase()), findsOneWidget,
            reason: '${vehicle.handbookDesignation} lost its button at ${width}px');
        // The entry clips its own edges, so content running past the bottom is
        // cut without a RenderFlex overflow being reported. Nothing throws;
        // the control is simply half there. So measure it.
        final cell = tester.getRect(find.byKey(cellKey));
        final button = tester.getRect(find.text(AppStrings.selectVehicleButton.toUpperCase()));
        expect(button.bottom, lessThanOrEqualTo(cell.bottom),
            reason: '${vehicle.handbookDesignation} at ${width}px: the control '
                'is clipped by ${(button.bottom - cell.bottom).toStringAsFixed(0)}px');
        final bound = width >= VehicleCard.stackedBelowWidth
            ? VehicleCard.maxRowHeight
            : VehicleCard.maxStackedRowHeight;
        expect(cell.height, lessThanOrEqualTo(bound),
            reason: '${vehicle.handbookDesignation} at ${width}px is '
                '${cell.height.toStringAsFixed(0)}px tall, past the '
                '${bound.toStringAsFixed(0)}px bound the entry publishes');
      }
    }
  });

  testWidgets('the T-72 keeps its name and both of its badges', (tester) async {
    final t72 = badged.firstWhere((v) => v.id == 'veh-t72');
    await pumpCard(tester, t72, 860);

    expect(tester.takeException(), isNull);
    expect(find.text(t72.handbookDesignation.toUpperCase()), findsOneWidget);
    // Moved, not dropped: the source badge and the completeness badge both
    // still say their piece. They are looked for by their own text rather than
    // by a shared word — the catalogue is built from the transport table now,
    // whose badge reads ULAG HÄSIÝETNAMALARY, so the two no longer happen to
    // share the string 'MAGLUMAT'.
    expect(find.text(AppStrings.dataSourceTransportTableBadge), findsOneWidget);
    expect(find.textContaining('MAGLUMAT'), findsOneWidget);
  });
}
