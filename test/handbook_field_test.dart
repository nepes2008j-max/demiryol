import 'package:test/test.dart';
import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/data/models/handbook_field.dart';

void main() {
  group('HandbookField', () {
    test('numeric value is available and displays with unit', () {
      final f = HandbookField.fromJson(46.5);
      expect(f.isAvailable, isTrue);
      expect(f.isTodo, isFalse);
      expect(f.numericValue, 46.5);
      expect(f.display(unit: 't'), '46.5 t');
    });

    test('integer-valued double displays without decimal point', () {
      final f = HandbookField.fromJson(953.0);
      expect(f.display(unit: 'cm'), '953 cm');
    });

    test('TODO string is not available and is flagged as todo', () {
      final f = HandbookField.fromJson('TODO: Fill from Handbook Page XX');
      expect(f.isAvailable, isFalse);
      expect(f.isTodo, isTrue);
      expect(f.display(), AppStrings.notAvailableInHandbook);
    });

    test('TODO string with a parenthetical note preserves the note', () {
      final f = HandbookField.fromJson(
          'TODO: Fill from Handbook Page XX (Main Battle Tank - not stated in this extract)');
      expect(f.display(),
          '${AppStrings.notAvailableInHandbook} (Main Battle Tank - not stated in this extract)');
    });

    test('null value is treated as todo, never as zero', () {
      final f = HandbookField.fromJson(null);
      expect(f.isAvailable, isFalse);
      expect(f.isTodo, isTrue);
      expect(f.numericValue, isNull);
      expect(f.asDouble, isNull);
      expect(f.display(), AppStrings.notAvailableInHandbook);
    });
  });

  group('presentHandbookText', () {
    test('leaves ordinary text untouched', () {
      expect(presentHandbookText('T-54'), 'T-54');
    });

    test('rewrites a bare TODO marker', () {
      expect(presentHandbookText('TODO: Fill from Handbook Page XX'),
          AppStrings.notAvailableInHandbook);
    });

    test('rewrites a TODO marker with a trailing note, keeping the note', () {
      expect(
        presentHandbookText(
            'TODO: Fill from Handbook Page XX (Armored Personnel Carrier - not explicitly stated in this extract)'),
        '${AppStrings.notAvailableInHandbook} (Armored Personnel Carrier - not explicitly stated in this extract)',
      );
    });

    test('is case-insensitive on the TODO marker', () {
      expect(presentHandbookText('todo: fill from handbook page xx'),
          AppStrings.notAvailableInHandbook);
    });
  });
}
