@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:railsim/data/repositories/handbook_repository.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/securing_hardware_catalog.dart';

/// Every piece the trainee can put on the wagon has a picture of itself.
///
/// The picker names a piece and states its size — "Demir şpor, Ş-303,
/// 180×200×860 mm". Someone who has never held one still does not know what
/// they are about to place, and the extract does contain a figure for every
/// family of gear in that list. This holds the two together.
///
/// It is deliberately not satisfied by pointing every piece at the same plate:
/// `figureReferenceIds` names where each piece is actually drawn, which for
/// the packing board and the wire lashing is not the paragraph their sizes
/// were read off.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late HandbookRepository repository;

  setUp(() => repository = HandbookRepository());

  test('every placeable piece can be shown a handbook figure', () async {
    final measurements = await repository.getMeasurements();
    final rules = await repository.getRules();
    final attachments = await repository.getAttachmentTypes();
    final photos = await repository.getPhotos();
    final vehicles = await repository.getVehicles();

    final figuresByReference = <String, int>{};
    for (final photo in photos) {
      figuresByReference[photo.referenceId] =
          (figuresByReference[photo.referenceId] ?? 0) + 1;
    }

    // One of each running gear, because the two resolve different pieces.
    final kindsSeen = <SecuringPieceKind>{};
    for (final id in ['veh-t72', 'veh-zil131']) {
      final vehicle = vehicles.firstWhere((v) => v.id == id);
      final hardware = placeableHardwareFor(
        vehicle: vehicle,
        measurements: measurements,
        rules: rules,
        attachments: attachments,
      );
      expect(hardware, isNotEmpty, reason: id);

      for (final piece in hardware) {
        kindsSeen.add(piece.kind);
        final count = piece.figureReferenceIds.fold<int>(
            0, (sum, reference) => sum + (figuresByReference[reference] ?? 0));
        expect(count, greaterThan(0),
            reason: '${piece.kind.name} (${piece.typeCode}) has no figure: '
                'looked in ${piece.figureReferenceIds}');
      }
    }

    // The list is worth trusting only if it really covered the gear, so the
    // pieces the plates turn on are named rather than assumed.
    expect(
        kindsSeen,
        containsAll(<SecuringPieceKind>[
          SecuringPieceKind.woodChock,
          SecuringPieceKind.woodInsert,
          SecuringPieceKind.woodPacking,
          SecuringPieceKind.ironChock,
          SecuringPieceKind.ironSpur,
          SecuringPieceKind.ironChockBoot,
          SecuringPieceKind.wireLashing,
        ]));
  });

  test('a figure reference is always a reference that exists', () async {
    final measurements = await repository.getMeasurements();
    final rules = await repository.getRules();
    final references = (await repository.getReferences()).map((r) => r.id).toSet();
    final vehicles = await repository.getVehicles();

    for (final id in ['veh-t72', 'veh-zil131']) {
      final vehicle = vehicles.firstWhere((v) => v.id == id);
      for (final piece in placeableHardwareFor(
          vehicle: vehicle, measurements: measurements, rules: rules)) {
        for (final reference in piece.figureReferenceIds) {
          expect(references, contains(reference),
              reason: '${piece.kind.name} points at a reference nobody has');
        }
      }
    }
  });
}
