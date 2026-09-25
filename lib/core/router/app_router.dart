import 'package:go_router/go_router.dart';

import '../../presentation/screens/consist/consist_setup_screen.dart';
import '../../presentation/screens/engineering_analysis/engineering_analysis_screen.dart';
import '../../presentation/screens/equipment/equipment_selection_screen.dart';
import '../../presentation/screens/admin/admin_screen.dart';
import '../../presentation/screens/main_menu/main_menu_screen.dart';
import '../../presentation/screens/placement/placement_screen.dart';
import '../../presentation/screens/reference_browser/reference_browser_screen.dart';
import '../../presentation/screens/result/result_screen.dart';
import '../../presentation/screens/securing/securing_screen.dart';
import '../../presentation/screens/vehicle_selection/vehicle_category_screen.dart';
import '../../presentation/screens/vehicle_selection/vehicle_selection_screen.dart';
import '../../presentation/screens/wagon_type/wagon_type_screen.dart';

/// The five-step loading flow:
///
///   Main Menu
///     -> /consist       1. how many wagons
///     -> /vehicles      2. which vehicles and how many (via /vehicle-categories)
///     -> /wagon-type    3. which wagon type
///     -> /placement     4. put the vehicles on the wagons
///     -> /securing      5. secure each placed vehicle
///     -> /analysis         engineering review of one placement
///     -> /result           the whole train
///
/// `/vehicle-categories` is the entry to step 2 rather than a step of its
/// own, which is why the breadcrumb shows five steps and not six.
///
/// The Handbook Reference Browser (/reference) sits outside this flow — every
/// screen can push it as a side lookup and pop back to where it was.
final appRouter = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const MainMenuScreen()),
    GoRoute(
      path: '/consist',
      builder: (context, state) => const ConsistSetupScreen(),
    ),
    GoRoute(
      path: '/vehicle-categories',
      builder: (context, state) => const VehicleCategoryScreen(),
    ),
    GoRoute(
      path: '/vehicles',
      builder: (context, state) => const VehicleSelectionScreen(),
    ),
    GoRoute(
      path: '/wagon-type',
      builder: (context, state) => const WagonTypeScreen(),
    ),
    GoRoute(
      path: '/placement',
      builder: (context, state) => const PlacementScreen(),
    ),
    GoRoute(
      path: '/equipment',
      builder: (context, state) => const EquipmentSelectionScreen(),
    ),
    GoRoute(
      path: '/securing',
      builder: (context, state) => const SecuringScreen(),
    ),
    GoRoute(
      path: '/analysis',
      builder: (context, state) => const EngineeringAnalysisScreen(),
    ),
    GoRoute(
      path: '/result',
      builder: (context, state) => const ResultScreen(),
    ),
    GoRoute(
      path: '/admin',
      builder: (context, state) => const AdminScreen(),
    ),
    GoRoute(
      path: '/reference',
      builder: (context, state) => const ReferenceBrowserScreen(),
    ),
  ],
);
