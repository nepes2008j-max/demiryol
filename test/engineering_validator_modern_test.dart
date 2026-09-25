import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/repositories/handbook_repository.dart';
import 'package:railsim/domain/usecases/engineering_validator.dart';

/// The validator running against real assets, for the two vehicles whose
/// records are complete enough to reach a verdict.
///
/// It had never been tested at all, because it needs `rootBundle` — which
/// `flutter test` does provide, from the assets the pubspec declares. Worth
/// having now: two of its checks used to report "cannot be decided" no matter
/// what they were given, and the only way to show they now decide something is
/// to run them on the real catalogue.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late EngineeringValidator validator;
  late HandbookRepository repository;

  setUp(() {
    repository = HandbookRepository();
    validator = EngineeringValidator(repository);
  });

  Future<SimulationResult> evaluateT90() async {
    final vehicles = await repository.getVehicles();
    final platforms = await repository.getPlatforms();
    return validator.evaluate(
      vehicle: vehicles.firstWhere((v) => v.id == 'veh-t90s'),
      platform:
          platforms.firstWhere((p) => p.id == 'plat-generic-open-flatcar'),
    );
  }

  ValidationCheck check(SimulationResult r, String ruleId) =>
      r.checks.firstWhere((c) => c.ruleId == ruleId,
          orElse: () => throw StateError('no check $ruleId in '
              '${r.checks.map((c) => c.ruleId).toList()}'));


  group('what still cannot be decided, and why', () {
    test('the para. 34 centre-of-gravity check is gone, not silently failing',
        () async {
      // It read a field no source ever filled, so it reported "cannot be
      // decided" on every evaluation and diluted every score. The rule stays
      // in `rules.json` and stays readable in the reference browser; what was
      // removed is the check.
      final r = await evaluateT90();
      expect(r.checks.map((c) => c.ruleId),
          isNot(contains('rule-cog-height-method-eligibility')));
    });

  });


  group('the T-72, which the handbook does cover', () {
    Future<SimulationResult> evaluateT72() async {
      final vehicles = await repository.getVehicles();
      final platforms = await repository.getPlatforms();
      return validator.evaluate(
        vehicle: vehicles.firstWhere((v) => v.id == 'veh-t72'),
        platform:
            platforms.firstWhere((p) => p.id == 'plat-generic-open-flatcar'),
      );
    }

    test('its securing method is not a choice — Table 13 names the spur',
        () async {
      // This is the whole difference from the T-90S. Annex 14's Table 13
      // lists Object 172 in the Objects-137 family and assigns that group
      // iron spur Ş-137, so the method is resolved by name rather than
      // offered as alternatives for the trainee to pick between.
      final r = await evaluateT72();
      expect(r.requiredHardwareIds, ['att-iron-spur']);
      final c = check(r, 'rule-vehicle-specific-hardware-lookup');
      expect(c.status, CheckStatus.pass);
      expect(c.detail, contains('Ş-137'));
    });

  });
}
