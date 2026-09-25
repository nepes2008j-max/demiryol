import 'package:test/test.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/handbook_photo.dart';
import 'package:railsim/data/models/handbook_reference.dart';
import 'package:railsim/data/models/handbook_rule.dart';
import 'package:railsim/data/models/localized_text.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/principle.dart';
import 'package:railsim/data/models/vehicle.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

void main() {
  group('preferTurkmen', () {
    test('prefers Turkmen when present and non-empty', () {
      expect(preferTurkmen('English', 'Türkmençe'), 'Türkmençe');
    });

    test('falls back to English when Turkmen is null', () {
      expect(preferTurkmen('English', null), 'English');
    });

    test('falls back to English when Turkmen is empty/whitespace', () {
      expect(preferTurkmen('English', ''), 'English');
      expect(preferTurkmen('English', '   '), 'English');
    });
  });

  group('Principle.withTurkmen', () {
    const english = Principle(
      id: 'principle-x',
      title: 'Title',
      principle: 'Principle',
      purpose: 'Purpose',
      physics: 'Physics',
      engineeringReason: 'Reason',
      militaryRequirement: 'Requirement',
      handbookReferenceId: 'para-1',
    );

    test('unmerged principle displays English (no translation yet)', () {
      expect(english.displayTitle, 'Title');
      expect(english.displayPrinciple, 'Principle');
    });

    test('merging a translation makes displayX return Turkmen, English unchanged', () {
      final merged = english.withTurkmen({
        'titleTk': 'Sözbaşy',
        'principleTk': 'Ýörelge',
      });
      expect(merged.displayTitle, 'Sözbaşy');
      expect(merged.displayPrinciple, 'Ýörelge');
      // Fields with no Tk key in the merge map fall back to English.
      expect(merged.displayPurpose, 'Purpose');
      // The original English source is preserved, never overwritten.
      expect(merged.title, 'Title');
      expect(merged.principle, 'Principle');
    });

    test('merging null leaves the principle untouched', () {
      expect(identical(english.withTurkmen(null), english), isTrue);
    });
  });

  group('HandbookRule Turkmen merge', () {
    test('rule description/failMessage translate independently, condition is untouched', () {
      final rule = HandbookRule.fromRuleJson({
        'id': 'rule-x',
        'description': 'English description.',
        'condition': 'weightT <= 10.0',
        'failMessage': 'English fail message.',
        'referenceId': 'para-1',
      }).withTurkmen({'descriptionTk': 'Türkmen beýany.', 'failMessageTk': 'Türkmen ýalňyşlyk.'});

      expect(rule.displayDescription, 'Türkmen beýany.');
      expect(rule.displayFailMessage, 'Türkmen ýalňyşlyk.');
      expect(rule.condition, 'weightT <= 10.0', reason: 'engineering condition must never be translated');
    });

    test('method title uses the Turkmen approved-method phrasing, not English', () {
      final method = HandbookRule.fromMethodJson({
        'method': 3,
        'name': 'Wood stop-blocks + wire lashings',
        'referenceId': 'para-40',
      }).withTurkmen({'descriptionTk': 'Agaç duruzyjylar + sim çekmeler'});

      expect(method.displayTitle, '3-nji tassyklanan usul: Agaç duruzyjylar + sim çekmeler');
      expect(method.displayTitle, isNot(contains('Approved method')));
    });
  });

  group('AttachmentType.displayNotes', () {
    test('name/category/material are never affected by a Turkmen merge', () {
      const attachment = AttachmentType(
        id: 'att-x',
        category: AttachmentCategory.rope,
        name: 'Steel wire lashing (sim çekme)',
        material: 'Steel wire, twisted strand',
        referenceId: 'table-7',
        notes: 'English note.',
      );
      final merged = attachment.withTurkmen({'notesTk': 'Türkmen belligi.'});
      expect(merged.displayNotes, 'Türkmen belligi.');
      expect(merged.name, 'Steel wire lashing (sim çekme)');
      expect(merged.material, 'Steel wire, twisted strand');
    });

    test('no notes field means displayNotes is null, translated or not', () {
      const attachment = AttachmentType(
        id: 'att-y',
        category: AttachmentCategory.specialLock,
        name: 'KGUUB-2G',
        referenceId: 'para-29',
      );
      expect(attachment.displayNotes, isNull);
      expect(attachment.withTurkmen({'notesTk': 'ignored'}).displayNotes, isNull);
    });
  });

  group('HandbookReference.displaySummary', () {
    test('falls back to English, then prefers Turkmen once merged', () {
      const reference = HandbookReference(id: 'para-1', paragraph: '1', summary: 'English summary.');
      expect(reference.displaySummary, 'English summary.');
      final merged = reference.withTurkmen({'summaryTk': 'Türkmen beýany.'});
      expect(merged.displaySummary, 'Türkmen beýany.');
      expect(merged.summary, 'English summary.');
    });
  });

  group('HandbookPhoto.displayCaption', () {
    test('figureNumber and file are untouched by a caption translation', () {
      const photo = HandbookPhoto(
        id: 'fig-1',
        assetPath: 'images/image1.png',
        figureNumber: '1.1',
        caption: 'English caption',
        referenceId: 'para-1',
      );
      final merged = photo.withTurkmen({'captionTk': 'Türkmen ýazgysy'});
      expect(merged.displayCaption, 'Türkmen ýazgysy');
      expect(merged.figureNumber, '1.1');
      expect(merged.assetPath, 'images/image1.png');
      expect(merged.fullAssetPath, 'assets/images/image1.png');
    });
  });

  group('Vehicle.displayClass and displayNotes', () {
    Vehicle vehicle({String? classDisplayTk, String? notesTk}) => Vehicle(
          id: 'veh-x',
          handbookDesignation: 'Object 999',
          category: VehicleCategory.tracked,
          vehicleClass: 'TODO: Fill from Handbook Page XX (Self-Propelled Artillery - not stated)',
          lengthCm: _todo,
          widthCm: _todo,
          heightCm: _todo,
          weightT: _todo,
          groundClearanceCm: _todo,
          trackWidthMm: _todo,
          wheelBaseCm: _todo,
          manufacturer: 'TODO: Fill from Handbook Page XX',
          country: 'TODO: Fill from Handbook Page XX',
          approvedSecuringHardwareIds: const [],
          referenceId: 'para-31',
          notes: 'English note about this vehicle.',
          classDisplayTk: classDisplayTk,
          notesTk: notesTk,
        );

    test('without classDisplayTk, falls back to presentHandbookText (still Turkmen "not available" wording)', () {
      final v = vehicle();
      expect(v.displayClass, contains('Self-Propelled Artillery - not stated'));
      expect(v.displayClass, isNot(contains('TODO')));
    });

    test('with classDisplayTk, the English parenthetical annotation never appears', () {
      final v = vehicle(classDisplayTk: 'Elýeterli däl (özi ýöreýän artilleriýa)');
      expect(v.displayClass, 'Elýeterli däl (özi ýöreýän artilleriýa)');
      expect(v.displayClass, isNot(contains('Self-Propelled Artillery')));
      // The original English annotation remains recoverable on the model.
      expect(v.vehicleClass, contains('Self-Propelled Artillery'));
    });

    test('displayNotes prefers Turkmen, falls back to English otherwise', () {
      expect(vehicle().displayNotes, 'English note about this vehicle.');
      expect(vehicle(notesTk: 'Türkmen belligi.').displayNotes, 'Türkmen belligi.');
    });
  });

  group('Platform.displayNotes', () {
    test('prefers Turkmen, falls back to English, name is never affected', () {
      const platform = Platform(
        id: 'plat-x',
        name: 'Generic open flatcar (açyk wagon)',
        lengthCm: _todo,
        widthCm: _todo,
        deckHeightCm: _todo,
        maxAxleLoadWheeledT: _todo,
        maxGroundPressureTrackedKgCm2: _todo,
        specialCaseMaxTrackedT: _todo,
        attachmentRings: _todo,
        tieDownRings: _todo,
        woodSupportPositions: _todo,
        allowedVehicleTypes: ['tracked'],
        referenceId: 'para-51',
        notes: 'English platform note.',
      );
      expect(platform.displayNotes, 'English platform note.');
      final merged = platform.withTurkmen({'notesTk': 'Türkmen platforma belligi.'});
      expect(merged.displayNotes, 'Türkmen platforma belligi.');
      expect(merged.name, 'Generic open flatcar (açyk wagon)');
    });
  });
}
