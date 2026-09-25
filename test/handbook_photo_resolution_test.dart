import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/handbook_photo.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/usecases/handbook_photo_resolution.dart';
import 'package:railsim/domain/usecases/reference_linker.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({required String id, String? ironSpurType, String? ironChockBootType}) => Vehicle(
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
      ironSpurType: ironSpurType,
      ironChockBootType: ironChockBootType,
      referenceId: ironSpurType != null ? 'para-31' : 'para-32',
    );

const _photos = [
  HandbookPhoto(
    id: 'fig-15.13a',
    assetPath: 'images/image38.png',
    figureNumber: '15.13',
    caption: 'Iron spurs, view 1',
    referenceId: 'para-31',
  ),
  HandbookPhoto(
    id: 'fig-15.13b',
    assetPath: 'images/image39.png',
    figureNumber: '15.13',
    caption: 'Iron spurs: 1 plate, 2 plate comb...',
    referenceId: 'para-31',
  ),
  HandbookPhoto(
    id: 'fig-15.14',
    assetPath: 'images/image40.png',
    figureNumber: '15.14',
    caption: 'Iron chock-boots: (a) KTT, (b) KT-137, (c) KT-34',
    referenceId: 'para-32',
  ),
  HandbookPhoto(
    id: 'fig-15.10',
    assetPath: 'images/image35.png',
    figureNumber: '15.10',
    caption: 'Reusable lashings (mechanized strops): wire/rope, chain',
    referenceId: 'para-19',
  ),
  HandbookPhoto(
    id: 'fig-15.11',
    assetPath: 'images/image36.png',
    figureNumber: '15.11',
    caption: 'KGUUB-1G reusable universal chock for tracked vehicles',
    referenceId: 'para-29',
  ),
  HandbookPhoto(
    id: 'fig-15.16ab',
    assetPath: 'images/image42.png',
    figureNumber: '15.16',
    caption: 'KGUUB-2G securing sequence: vehicle positioning',
    referenceId: 'para-36',
  ),
  HandbookPhoto(
    id: 'fig-15.16cde',
    assetPath: 'images/image43.png',
    figureNumber: '15.16',
    caption: 'KGUUB-2G securing sequence continued',
    referenceId: 'para-38',
  ),
];

const _linker = ReferenceLinker(
  photos: _photos,
  principles: [],
  rules: [],
  vehicles: [],
  platforms: [],
  attachments: [],
);

void main() {
  group('photoKindOf', () {
    test('classifies known equipment and procedure figures from their own captions', () {
      expect(photoKindOf('fig-15.13a'), HandbookPhotoKind.equipment);
      expect(photoKindOf('fig-15.16ab'), HandbookPhotoKind.procedure);
    });

    test('defaults to equipment for an unrecognized id rather than crashing', () {
      expect(photoKindOf('fig-unknown'), HandbookPhotoKind.equipment);
    });
  });

  group('isVehicleIdentificationPhoto / vehicleIdentificationPhotoFor', () {
    test('no figure in the current extract is a vehicle identification photo', () {
      for (final photo in _photos) {
        expect(isVehicleIdentificationPhoto(photo.id), isFalse);
      }
    });

    test('a vehicle never receives an equipment/procedure figure as its own photo', () {
      final vehicle = _vehicle(id: 'veh-spur', ironSpurType: 'Ş-303');
      // The vehicle's referenceId (para-31) DOES have matching photos
      // (fig-15.13a/b) — but none are vehicle identification photos, so
      // this must still be null, never one of those figures.
      expect(vehicleIdentificationPhotoFor(vehicle, _linker), isNull);
    });
  });

  group('equipmentPhotosFor', () {
    test('iron spur gets exactly its own generic figures, unaffected by any override', () {
      final photos = equipmentPhotosFor('att-iron-spur', 'para-31', _linker);
      expect(photos.map((p) => p.id).toSet(), {'fig-15.13a', 'fig-15.13b'});
    });

    test('wire lashing gets its real photo despite citing a different reference id for sizing', () {
      final photos = equipmentPhotosFor('att-wire-lashing', 'table-7', _linker);
      expect(photos.map((p) => p.id), contains('fig-15.10'));
    });

    test('KGUUB-2G excludes the 1G-captioned figure and includes its own captioned sequence figures', () {
      final photos = equipmentPhotosFor('att-kguub-2g', 'para-29', _linker);
      final ids = photos.map((p) => p.id).toSet();
      expect(ids, isNot(contains('fig-15.11')), reason: 'fig-15.11 is explicitly captioned "KGUUB-1G"');
      expect(ids, containsAll(['fig-15.16ab', 'fig-15.16cde']));
    });

    test('KGUUB-1G (unaffected hardware id) still gets the shared para-29 figure', () {
      final photos = equipmentPhotosFor('att-kguub-1g', 'para-29', _linker);
      expect(photos.map((p) => p.id), contains('fig-15.11'));
    });

    test('never returns a duplicated photo id', () {
      final photos = equipmentPhotosFor('att-kguub-2g', 'para-29', _linker);
      final ids = photos.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });
}
