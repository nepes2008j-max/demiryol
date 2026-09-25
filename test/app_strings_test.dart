import 'package:test/test.dart';
import 'package:railsim/core/localization/app_strings.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/data/models/vehicle.dart';

void main() {
  group('AppStrings.vehicleCategoryLabel', () {
    test('every VehicleCategory value has a Turkmen label', () {
      for (final category in VehicleCategory.values) {
        final label = AppStrings.vehicleCategoryLabel(category);
        expect(label, isNotEmpty);
      }
    });
  });

  group('AppStrings.attachmentCategoryLabel', () {
    test('every AttachmentCategory value has a Turkmen label', () {
      for (final category in AttachmentCategory.values) {
        final label = AppStrings.attachmentCategoryLabel(category);
        expect(label, isNotEmpty);
      }
    });
  });

  group('AppStrings.appliesToLabelFor', () {
    test('maps the three known rules.json appliesTo values', () {
      expect(AppStrings.appliesToLabelFor('wheeled'), 'Tigirli');
      expect(AppStrings.appliesToLabelFor('tracked'), 'Gusenisaly');
      expect(AppStrings.appliesToLabelFor('tracked_or_wheeled'), 'Gusenisaly ýa-da tigirli');
    });

    test('falls back to the raw value for anything unrecognized, never hides it', () {
      expect(AppStrings.appliesToLabelFor('amphibious'), 'amphibious');
    });
  });
}
