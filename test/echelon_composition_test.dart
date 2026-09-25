import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/domain/usecases/echelon_composition.dart';

List<Platform> _platforms() =>
    ((jsonDecode(File('assets/data/platforms.json').readAsStringSync())
                as Map<String, dynamic>)['platforms'] as List)
        .cast<Map<String, dynamic>>()
        .map(Platform.fromJson)
        .toList();

Map<String, dynamic> _rules() =>
    jsonDecode(File('assets/data/rules.json').readAsStringSync()) as Map<String, dynamic>;

void main() {
  final classes = echelonClassesFrom(_platforms());
  final rules = _rules();

  group('echelon classes', () {
    test('are read from the data, smallest first', () {
      // These sat unused in platforms.json since the extraction; nothing ever
      // compared a train against one.
      expect(classes, hasLength(2));
      expect(classes.first.conditionalWagons, 40);
      expect(classes.first.maxTrainWeightT, 1500);
      expect(classes.last.conditionalWagons, 57);
      expect(classes.last.maxTrainWeightT, 3000);
    });

    test('a train picks the smallest class it fits', () {
      expect(classForWagonCount(12, classes)?.conditionalWagons, 40);
      expect(classForWagonCount(40, classes)?.conditionalWagons, 40);
      expect(classForWagonCount(41, classes)?.conditionalWagons, 57);
      expect(classForWagonCount(58, classes), isNull);
    });

    test('a train longer than every class fails, naming the largest', () {
      final check = checkEchelonComposition(wagonCount: 60, classes: classes);
      expect(check.status, CheckStatus.fail);
      expect(check.detail, contains('57'));
    });

    test('a normal train passes and says which class it is in', () {
      final check = checkEchelonComposition(wagonCount: 8, classes: classes);
      expect(check.status, CheckStatus.pass);
      expect(check.detail, contains('40'));
    });

    test('an empty train cannot be classified rather than passing by default', () {
      expect(checkEchelonComposition(wagonCount: 0, classes: classes).status,
          CheckStatus.unknown);
    });
  });

  group('guard wagon', () {
    test('an overhang past the limit requires a guard wagon', () {
      final check = checkGuardWagon(overhangMm: 620, rules: rules);
      expect(check.status, CheckStatus.fail);
      expect(check.detail, contains('400'));
      expect(check.referenceId, 'plate-05');
    });

    test('an overhang inside the limit does not', () {
      expect(checkGuardWagon(overhangMm: 0, rules: rules).status, CheckStatus.pass);
      expect(checkGuardWagon(overhangMm: 400, rules: rules).status, CheckStatus.pass);
    });

    test('an unknown overhang stays unknown and says what it needs', () {
      final check = checkGuardWagon(overhangMm: null, rules: rules);
      expect(check.status, CheckStatus.unknown);
      expect(check.detail, contains('400'));
    });
  });
}
