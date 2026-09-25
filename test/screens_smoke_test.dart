import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/core/theme/app_theme.dart';
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

/// Every screen, built once against the real data.
///
/// There were no screen tests at all: a screen that threw on build — an
/// overflow, a null, a provider that had changed shape under it — would only
/// have been found by running the application and clicking to it. These pump
/// each one and assert nothing was thrown, which is a low bar and exactly the
/// bar that was missing.
void main() {
  setUp(() {
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    // A desktop window. This trainer runs on one, and several screens lay out
    // two columns above 900 px.
    view.physicalSize = const Size(1600, 1200);
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

  Future<void> pumpScreen(WidgetTester tester, Widget screen) async {
    await tester.pumpWidget(ProviderScope(
      child: MaterialApp(theme: AppTheme.dark, home: screen),
    ));
    // Let the asset futures settle; the repository reads real JSON.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(tester.takeException(), isNull);
  }

  final screens = <String, Widget Function()>{
    'main menu': MainMenuScreen.new,
    'consist setup': ConsistSetupScreen.new,
    'vehicle categories': VehicleCategoryScreen.new,
    'vehicle selection': VehicleSelectionScreen.new,
    'wagon type': WagonTypeScreen.new,
    'placement': PlacementScreen.new,
    'equipment': EquipmentSelectionScreen.new,
    'securing': SecuringScreen.new,
    'engineering analysis': EngineeringAnalysisScreen.new,
    'result': ResultScreen.new,
    'reference browser': ReferenceBrowserScreen.new,
  };

  screens.forEach((name, build) {
    testWidgets('$name builds on an empty attempt', (tester) async {
      await pumpScreen(tester, build());
    });
  });

  testWidgets('every screen also builds in a narrow window', (tester) async {
    // The layouts switch to a single column below 900 px, and that branch had
    // never been exercised either.
    final view = TestWidgetsFlutterBinding.ensureInitialized()
        .platformDispatcher
        .views
        .first;
    view.physicalSize = const Size(820, 1000);
    for (final entry in screens.entries) {
      await pumpScreen(tester, entry.value());
    }
  });
}
