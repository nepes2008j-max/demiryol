import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_photo.dart';
import 'package:railsim/domain/usecases/photo_presentation.dart';

void main() {
  group('imageUnavailableCaption', () {
    test('always includes the figure number and caption, never crashes on missing image', () {
      const photo = HandbookPhoto(
        id: 'fig-15.13a',
        assetPath: 'images/image38.png',
        figureNumber: '15.13',
        caption: 'Iron spurs, view 1',
        referenceId: 'para-31',
      );
      final message = imageUnavailableCaption(photo);
      expect(message, contains('15.13'));
      expect(message, contains('Iron spurs, view 1'));
      expect(message, contains('elýeterli däl'));
    });
  });

  group('HandbookPhoto.fullAssetPath', () {
    test('prefixes the stored asset path with assets/', () {
      const photo = HandbookPhoto(
        id: 'fig-x',
        assetPath: 'images/image99.png',
        figureNumber: '1',
        caption: 'x',
        referenceId: 'para-1',
      );
      expect(photo.fullAssetPath, 'assets/images/image99.png');
    });
  });
}
