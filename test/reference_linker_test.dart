import 'package:test/test.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/handbook_photo.dart';
import 'package:railsim/data/models/handbook_rule.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/principle.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/usecases/reference_linker.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({required String id, required String referenceId}) => Vehicle(
      id: id,
      handbookDesignation: id,
      category: VehicleCategory.tracked,
      vehicleClass: 'TODO: Fill from Handbook Page XX',
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
      referenceId: referenceId,
    );

Platform _platform({required String id, required String referenceId}) => Platform(
      id: id,
      name: id,
      lengthCm: _todo,
      widthCm: _todo,
      deckHeightCm: _todo,
      maxAxleLoadWheeledT: _todo,
      maxGroundPressureTrackedKgCm2: _todo,
      specialCaseMaxTrackedT: _todo,
      attachmentRings: _todo,
      tieDownRings: _todo,
      woodSupportPositions: _todo,
      allowedVehicleTypes: const [],
      referenceId: referenceId,
    );

void main() {
  const photoA = HandbookPhoto(
      id: 'fig-a', assetPath: 'images/a.png', figureNumber: '1', caption: 'A', referenceId: 'para-31');
  const photoB = HandbookPhoto(
      id: 'fig-b', assetPath: 'images/b.png', figureNumber: '2', caption: 'B', referenceId: 'para-32');
  const photoC = HandbookPhoto(
      id: 'fig-c', assetPath: 'images/c.png', figureNumber: '3', caption: 'C', referenceId: 'para-55');

  const principle = Principle(
    id: 'principle-x',
    title: 'X',
    principle: 'p',
    purpose: 'u',
    physics: 'h',
    engineeringReason: 'e',
    militaryRequirement: 'm',
    handbookReferenceId: 'para-31',
  );

  const rule = HandbookRule(
    id: 'rule-x',
    description: 'Rule X',
    referenceId: 'para-31',
  );

  final linker = ReferenceLinker(
    photos: [photoA, photoB, photoC],
    principles: [principle],
    rules: [rule],
    vehicles: [
      _vehicle(id: 'veh-1', referenceId: 'para-31'),
      _vehicle(id: 'veh-2', referenceId: 'para-32'),
    ],
    platforms: [_platform(id: 'plat-1', referenceId: 'para-51')],
    attachments: const [
      AttachmentType(id: 'att-1', category: AttachmentCategory.metalStop, name: 'Iron spur', referenceId: 'para-31'),
    ],
  );

  group('ReferenceLinker', () {
    test('photosFor returns only photos sharing the exact reference id', () {
      expect(linker.photosFor('para-31'), [photoA]);
      expect(linker.photosFor('para-32'), [photoB]);
      expect(linker.photosFor('para-99'), isEmpty);
    });

    test('principlesFor matches by handbookReferenceId', () {
      expect(linker.principlesFor('para-31'), [principle]);
      expect(linker.principlesFor('para-32'), isEmpty);
    });

    test('rulesFor matches by referenceId', () {
      expect(linker.rulesFor('para-31'), [rule]);
    });

    test('vehiclesFor and platformsFor and attachmentsFor match by referenceId', () {
      expect(linker.vehiclesFor('para-31').map((v) => v.id), ['veh-1']);
      expect(linker.platformsFor('para-51').map((p) => p.id), ['plat-1']);
      expect(linker.attachmentsFor('para-31').map((a) => a.id), ['att-1']);
    });

    test('photosForAny deduplicates and only returns explicitly matching ids', () {
      final result = linker.photosForAny(['para-31', 'para-32', 'para-31']);
      expect(result, [photoA, photoB]);
    });

    test('photosForAny returns empty when no id matches (never guesses a relation)', () {
      expect(linker.photosForAny(['para-99']), isEmpty);
    });
  });
}
