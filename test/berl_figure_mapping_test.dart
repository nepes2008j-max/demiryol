import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_photo.dart';
import 'package:railsim/domain/usecases/handbook_photo_resolution.dart';
import 'package:railsim/domain/usecases/reference_linker.dart';

/// Figures published on the training plates issued with the handbook and
/// republished as panels in `Программа учин.docx`, wired in from `Berl/`.
///
/// Several of them share a citation with a figure of a *different* variant of
/// the same equipment — KGUUB-1K with 2K under para-30, the S-765 clamp with
/// the MK-765 clamp-tensioner under para-33. Showing the wrong one is exactly
/// the failure `docs/handbook-photo-mapping-report.md` was written about, so
/// each pairing is pinned here.
const _photos = [
  HandbookPhoto(
    id: 'fig-kguub-1k',
    assetPath: 'images/figures/kguub-1k.jpg',
    figureNumber: 'B-19',
    caption: 'KGUUB-1K reusable universal chock, for wheeled vehicles up to 15 t.',
    referenceId: 'para-30',
  ),
  HandbookPhoto(
    id: 'fig-kguub-2k',
    assetPath: 'images/figures/kguub-2k.jpg',
    figureNumber: 'B-20',
    caption: 'KGUUB-2K reusable universal chock, for wheeled vehicles of 15.1-26 t.',
    referenceId: 'para-30',
  ),
  HandbookPhoto(
    id: 'fig-kguub-wheeled-under-tyre',
    assetPath: 'images/figures/kguub-wheeled-under-tyre.jpg',
    figureNumber: 'B-18',
    caption: "A reusable universal chock seated under a wheeled vehicle's tyre.",
    referenceId: 'para-30',
  ),
  HandbookPhoto(
    id: 'fig-clamp-s765',
    assetPath: 'images/figures/clamp-s765.jpg',
    figureNumber: 'B-27',
    caption: 'S-765 clamp, with its parts labelled.',
    referenceId: 'para-33',
  ),
  HandbookPhoto(
    id: 'fig-clamp-mk765',
    assetPath: 'images/figures/clamp-mk765.jpg',
    figureNumber: 'B-28',
    caption: 'MK-765 clamp-tensioner, with its parts labelled.',
    referenceId: 'para-33',
  ),
  HandbookPhoto(
    id: 'fig-15.15',
    assetPath: 'images/image41.png',
    figureNumber: '15.15',
    caption: '(a) MK-765 clamp-tensioner, (b) S-765 clamp',
    referenceId: 'para-33',
  ),
  HandbookPhoto(
    id: 'fig-wood-chock-shapes',
    assetPath: 'images/figures/wood-chock-shapes.jpg',
    figureNumber: 'B-11',
    caption: 'The permitted shapes of the longitudinal quadrilateral wood chock.',
    referenceId: 'para-21',
  ),
  HandbookPhoto(
    id: 'fig-wheeled-chock-layout-cases',
    assetPath: 'images/figures/wheeled-chock-layout-cases.jpg',
    figureNumber: 'B-25',
    caption: 'Where the longitudinal and lateral chocks go under the tyres, in six cases.',
    referenceId: 'plate-06',
  ),
  HandbookPhoto(
    id: 'fig-wheeled-chock-securing',
    assetPath: 'images/figures/wheeled-chock-securing.jpg',
    figureNumber: 'B-26',
    caption: 'Wheeled vehicles secured with longitudinal and lateral wood chocks.',
    referenceId: 'plate-06',
  ),
  HandbookPhoto(
    id: 'fig-wire-lashings-and-consumables',
    assetPath: 'images/figures/wire-lashings-and-consumables.jpg',
    figureNumber: 'B-22',
    caption: 'Single-use lashings — wire/rope and chain — and the consumables table.',
    referenceId: 'para-19',
  ),
  HandbookPhoto(
    id: 'fig-tracked-method-1',
    assetPath: 'images/figures/tracked-method-1-banner.jpg',
    figureNumber: 'B-02',
    caption: 'Tracked method 1: by reusable universal chocks (KGUUB).',
    referenceId: 'plate-04',
  ),
  HandbookPhoto(
    id: 'fig-tracked-method-3',
    assetPath: 'images/figures/tracked-method-3-banner.jpg',
    figureNumber: 'B-04',
    caption: 'Tracked method 3: by wood chocks and single-use wire lashings.',
    referenceId: 'plate-03',
  ),
  HandbookPhoto(
    id: 'fig-tracked-method-6',
    assetPath: 'images/figures/tracked-method-6-banner.jpg',
    figureNumber: 'B-07',
    caption: 'Tracked method 6: by clamp-tensioners and clamps.',
    referenceId: 'plate-02',
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

List<String> _idsFor(String hardwareId, String referenceId) =>
    equipmentPhotosFor(hardwareId, referenceId, _linker).map((p) => p.id).toList();

void main() {
  group('KGUUB wheeled variants must not borrow each other\'s figure', () {
    test('KGUUB-1K shows its own figure, never the 2K one', () {
      final ids = _idsFor('att-kguub-1k', 'para-30');
      expect(ids, contains('fig-kguub-1k'));
      expect(ids, isNot(contains('fig-kguub-2k')));
    });

    test('KGUUB-2K shows its own figure, never the 1K one', () {
      final ids = _idsFor('att-kguub-2k', 'para-30');
      expect(ids, contains('fig-kguub-2k'));
      expect(ids, isNot(contains('fig-kguub-1k')));
    });

    test('the generic under-tyre photo is correct for both variants', () {
      // It is captioned without naming a variant, so it is not excluded from
      // either — the exclusions are for figures that name one designation.
      expect(_idsFor('att-kguub-1k', 'para-30'), contains('fig-kguub-wheeled-under-tyre'));
      expect(_idsFor('att-kguub-2k', 'para-30'), contains('fig-kguub-wheeled-under-tyre'));
    });
  });

  group('clamp and clamp-tensioner must not borrow each other\'s figure', () {
    test('the clamp-tensioner shows MK-765, never S-765', () {
      final ids = _idsFor('att-clamp-tensioner', 'para-33');
      expect(ids, contains('fig-clamp-mk765'));
      expect(ids, isNot(contains('fig-clamp-s765')));
    });

    test('the clamp shows S-765, never MK-765', () {
      final ids = _idsFor('att-clamp', 'para-33');
      expect(ids, contains('fig-clamp-s765'));
      expect(ids, isNot(contains('fig-clamp-mk765')));
    });

    test('the figure showing both together is kept for either', () {
      expect(_idsFor('att-clamp-tensioner', 'para-33'), contains('fig-15.15'));
      expect(_idsFor('att-clamp', 'para-33'), contains('fig-15.15'));
    });
  });

  group('figures filed under a plate still reach their equipment', () {
    test('the wood chock gets the layout figures despite their plate citation', () {
      final ids = _idsFor('att-wood-chock', 'para-21');
      expect(ids, contains('fig-wood-chock-shapes'), reason: 'reached by the shared para-21');
      expect(ids, contains('fig-wheeled-chock-layout-cases'), reason: 'filed under plate-06');
      expect(ids, contains('fig-wheeled-chock-securing'), reason: 'filed under plate-06');
    });

    test('the wire lashing gets the lashings figure despite its para-19 citation', () {
      expect(_idsFor('att-wire-lashing', 'table-7'),
          contains('fig-wire-lashings-and-consumables'));
    });

    test('a plate-filed figure does not leak to unrelated hardware', () {
      expect(_idsFor('att-iron-spur', 'para-31'),
          isNot(contains('fig-wheeled-chock-layout-cases')));
    });

    test('no figure is listed twice when it matches by both routes', () {
      final ids = _idsFor('att-wood-chock', 'para-21');
      expect(ids.toSet().length, ids.length);
    });
  });

  group('trackedMethodFigure', () {
    test('returns the banner whose number matches the method', () {
      expect(trackedMethodFigure(1, _linker)!.id, 'fig-tracked-method-1');
      expect(trackedMethodFigure(3, _linker)!.id, 'fig-tracked-method-3');
      expect(trackedMethodFigure(6, _linker)!.id, 'fig-tracked-method-6');
    });

    test('returns null rather than another method\'s banner when absent', () {
      // Methods 2, 4 and 5 are deliberately not in this fixture's photo list.
      expect(trackedMethodFigure(2, _linker), isNull);
      expect(trackedMethodFigure(4, _linker), isNull);
      expect(trackedMethodFigure(5, _linker), isNull);
    });

    test('an out-of-range method number resolves to nothing', () {
      expect(trackedMethodFigure(0, _linker), isNull);
      expect(trackedMethodFigure(7, _linker), isNull);
    });
  });

  group('classification', () {
    test('equipment renderings are equipment, arrangements are procedure', () {
      expect(photoKindOf('fig-kguub-1k'), HandbookPhotoKind.equipment);
      expect(photoKindOf('fig-clamp-mk765'), HandbookPhotoKind.equipment);
      expect(photoKindOf('fig-wood-chock-shapes'), HandbookPhotoKind.equipment);
      expect(photoKindOf('fig-wheeled-chock-layout-cases'), HandbookPhotoKind.procedure);
      expect(photoKindOf('fig-tracked-method-1'), HandbookPhotoKind.procedure);
    });

    test('no plate figure is an identification photo of a named vehicle', () {
      // The plates draw generic tracked and wheeled vehicles to illustrate an
      // arrangement; none is a photograph of a designated vehicle, so a
      // vehicle card must still show "photo not in source".
      for (final photo in _photos) {
        expect(isVehicleIdentificationPhoto(photo.id), isFalse, reason: photo.id);
      }
    });
  });
}
