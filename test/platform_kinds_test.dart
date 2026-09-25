import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/vehicle.dart';

/// The wagon-type step is an exercise with a right answer and two wrong ones,
/// so the wrong ones have to stay wrong: a covered wagon that quietly gained
/// an `allowedVehicleTypes` entry would become loadable, and one that lost its
/// `notApprovedReason` would be rejected with no explanation.
List<Platform> _loadPlatforms() {
  final json = jsonDecode(File('assets/data/platforms.json').readAsStringSync())
      as Map<String, dynamic>;
  final tkFile = File('assets/data/localization/platforms_tk.json');
  final tkById = <String, Map<String, dynamic>>{};
  if (tkFile.existsSync()) {
    final tk = jsonDecode(tkFile.readAsStringSync()) as Map<String, dynamic>;
    for (final entry in (tk['platforms'] as List).cast<Map<String, dynamic>>()) {
      tkById[entry['id'] as String] = entry;
    }
  }
  return (json['platforms'] as List)
      .cast<Map<String, dynamic>>()
      .map(Platform.fromJson)
      .map((p) => p.withTurkmen(tkById[p.id]))
      .toList();
}

void main() {
  final platforms = _loadPlatforms();
  final selectable = platforms.where((p) => p.isSelectableWagon).toList();

  group('platforms.json wagon kinds', () {
    test('the trainee is offered more than one wagon to choose between', () {
      expect(selectable.length, greaterThan(1));
    });

    test('exactly one selectable wagon may carry tracked vehicles', () {
      final loadable = selectable
          .where((p) => p.acceptsAll([VehicleCategory.tracked.name]))
          .toList();
      expect(loadable.length, 1);
      expect(loadable.single.kind, PlatformKind.openFlatcar);
    });

    test('every unloadable wagon says why, in both languages, with a citation', () {
      final unloadable =
          selectable.where((p) => p.kind != PlatformKind.openFlatcar).toList();
      expect(unloadable, isNotEmpty);
      for (final p in unloadable) {
        expect(p.allowedVehicleTypes, isEmpty, reason: '${p.id} would be loadable');
        expect(p.notApprovedReason, isNotNull, reason: '${p.id} has no reason');
        expect(p.notApprovedReasonTk, isNotNull, reason: '${p.id} has no Turkmen reason');
        expect(p.displayNotApprovedReason, p.notApprovedReasonTk,
            reason: '${p.id} should show the Turkmen reason');
        expect(p.referenceId, isNotEmpty, reason: '${p.id} cites nothing');
      }
    });

    test('the echelon weight classes are never offered as wagons to load', () {
      final echelon = platforms.where((p) => p.kind == PlatformKind.echelonClass);
      expect(echelon, isNotEmpty);
      for (final p in echelon) {
        expect(p.isSelectableWagon, isFalse, reason: '${p.id} is not rolling stock to load');
      }
    });

    test('a wagon with no approved category accepts nothing, even an empty load', () {
      // acceptsAll([]) is vacuously true for "every category is allowed", so
      // the emptiness of allowedVehicleTypes has to be checked on its own —
      // otherwise a load with no vehicles in it would make a tank wagon valid.
      final tankWagon =
          selectable.firstWhere((p) => p.kind == PlatformKind.tankWagon);
      expect(tankWagon.acceptsAll(const []), isFalse);
    });
  });
}
