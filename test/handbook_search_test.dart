import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_photo.dart';
import 'package:railsim/data/models/handbook_reference.dart';
import 'package:railsim/domain/usecases/handbook_search.dart';

void main() {
  group('matchesSearch', () {
    test('empty query matches everything', () {
      expect(matchesSearch('', ['anything']), isTrue);
      expect(matchesSearch('   ', ['anything']), isTrue);
    });

    test('is case-insensitive substring match', () {
      expect(matchesSearch('SpUr', ['Iron spur type Ş-303']), isTrue);
    });

    test('ignores null fields without crashing', () {
      expect(matchesSearch('spur', [null, 'Iron spur']), isTrue);
      expect(matchesSearch('missing', [null, 'Iron spur']), isFalse);
    });

    test('does not match unrelated text', () {
      expect(matchesSearch('chain', ['Iron spur type Ş-303']), isFalse);
    });
  });

  group('filterPhotos', () {
    final photos = [
      const HandbookPhoto(
          id: 'fig-1', assetPath: 'images/1.png', figureNumber: '15.13', caption: 'Iron spurs', referenceId: 'para-31'),
      const HandbookPhoto(
          id: 'fig-2',
          assetPath: 'images/2.png',
          figureNumber: '15.14',
          caption: 'Iron chock-boots',
          referenceId: 'para-32'),
    ];

    test('matches by figure number', () {
      expect(filterPhotos(photos, '15.13').map((p) => p.id), ['fig-1']);
    });

    test('matches by caption text', () {
      expect(filterPhotos(photos, 'chock').map((p) => p.id), ['fig-2']);
    });

    test('empty query returns all photos', () {
      expect(filterPhotos(photos, ''), photos);
    });
  });

  group('filterReferences', () {
    final refs = [
      const HandbookReference(id: 'para-51', paragraph: '51', summary: 'Axle load limits.'),
      const HandbookReference(id: 'table-7', table: '7', summary: 'Wire strand count by angle.'),
    ];

    test('matches by paragraph identifier', () {
      expect(filterReferences(refs, 'para-51').map((r) => r.id), ['para-51']);
    });

    test('matches by summary text', () {
      expect(filterReferences(refs, 'strand').map((r) => r.id), ['table-7']);
    });
  });
}
