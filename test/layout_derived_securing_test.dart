import 'package:test/test.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/securing_placement.dart';
import 'package:railsim/domain/usecases/layout_derived_securing.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({
  VehicleCategory category = VehicleCategory.tracked,
  HandbookField? weightT,
}) =>
    Vehicle(
      id: 'veh-x',
      handbookDesignation: 'veh-x',
      category: category,
      vehicleClass: 'TODO: Fill from Handbook Page XX',
      lengthCm: _todo,
      widthCm: _todo,
      heightCm: _todo,
      weightT: weightT ?? _todo,
      groundClearanceCm: _todo,
      trackWidthMm: _todo,
      wheelBaseCm: _todo,
      manufacturer: 'TODO: Fill from Handbook Page XX',
      country: 'TODO: Fill from Handbook Page XX',
      approvedSecuringHardwareIds: const [],
      referenceId: 'para-31',
    );

SecuringPiece _piece(SecuringPieceKind kind, {String? sizeTypeCode, String? id}) =>
    SecuringPiece(
      id: id ?? '${kind.name}-1',
      kind: kind,
      x: 1.0,
      z: 0.0,
      sizeTypeCode: sizeTypeCode,
    );

void main() {
  group('equipmentAnsweredByLayout — the placement is the answer', () {
    test('an empty layout answers nothing at all', () {
      expect(equipmentAnsweredByLayout(SecuringLayout.empty, _vehicle()), isEmpty);
    });

    test('a seated stop block answers the wood chock slot with its own table row', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.woodChock, sizeTypeCode: 'up to 12.0 t'),
      ]);
      expect(equipmentAnsweredByLayout(layout, _vehicle()),
          {'att-wood-chock': 'up to 12.0 t'});
    });

    test('a piece placed without a stated size answers nothing — no invented figure', () {
      final layout = SecuringLayout([_piece(SecuringPieceKind.woodChock)]);
      expect(equipmentAnsweredByLayout(layout, _vehicle()), isEmpty);
    });

    test('the insert and side block have no equipment slot and answer nothing', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.woodInsert, sizeTypeCode: '100-200 mm'),
        _piece(SecuringPieceKind.woodSideBlock, sizeTypeCode: '100x100x2000 mm'),
      ]);
      expect(equipmentAnsweredByLayout(layout, _vehicle()), isEmpty);
    });

    test('a KGUUB chock needs a recorded weight before its variant can be named', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.ironChock, sizeTypeCode: '1G'),
      ]);
      expect(equipmentAnsweredByLayout(layout, _vehicle()), isEmpty);
      expect(
        equipmentAnsweredByLayout(
            layout, _vehicle(weightT: const HandbookField(20.0))),
        {'att-kguub-1g': '1G'},
      );
    });
  });

  group('methodAnsweredByLayout — only when the pieces name exactly one method', () {
    test('an empty layout names no method', () {
      expect(methodAnsweredByLayout(SecuringLayout.empty, _vehicle()), isNull);
    });

    test('blocks alone are ambiguous between methods 3 and 5, so nothing is assumed', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.woodChock, sizeTypeCode: 'up to 12.0 t'),
      ]);
      expect(methodAnsweredByLayout(layout, _vehicle()), isNull);
    });

    test('blocks with wire lashings name method 3', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.woodChock, sizeTypeCode: 'up to 12.0 t'),
        _piece(SecuringPieceKind.wireLashing, sizeTypeCode: 'Ø6 mm'),
      ]);
      expect(methodAnsweredByLayout(layout, _vehicle()), 3);
    });

    test('blocks with packing name method 5', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.woodChock, sizeTypeCode: 'up to 12.0 t'),
        _piece(SecuringPieceKind.woodPacking, sizeTypeCode: '≥ 25 mm'),
      ]);
      expect(methodAnsweredByLayout(layout, _vehicle()), 5);
    });

    test('iron spurs name method 2', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.ironSpur, sizeTypeCode: 'S-1'),
      ]);
      expect(methodAnsweredByLayout(layout, _vehicle()), 2);
    });

    test('staples fix other pieces down and never name a method by themselves', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.staple, sizeTypeCode: 'Ø8 mm'),
      ]);
      expect(methodAnsweredByLayout(layout, _vehicle()), isNull);
    });

    test('staples alongside blocks and lashings still leave method 3 named', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.woodChock, sizeTypeCode: 'up to 12.0 t'),
        _piece(SecuringPieceKind.wireLashing, sizeTypeCode: 'Ø6 mm'),
        _piece(SecuringPieceKind.staple, sizeTypeCode: 'Ø8 mm'),
      ]);
      expect(methodAnsweredByLayout(layout, _vehicle()), 3);
    });

    test('hardware from two different methods names neither', () {
      final layout = SecuringLayout([
        _piece(SecuringPieceKind.ironSpur, sizeTypeCode: 'S-1'),
        _piece(SecuringPieceKind.ironChockBoot, sizeTypeCode: 'KTP'),
      ]);
      expect(methodAnsweredByLayout(layout, _vehicle()), isNull);
    });
  });

  group('equipmentStillUnanswered — what the securing screen may ask about', () {
    test('nothing is left to ask when the layout covers every required id', () {
      expect(
        equipmentStillUnanswered(
          requiredHardwareIds: const ['att-wood-chock', 'att-wire-lashing'],
          answered: const {
            'att-wood-chock': 'up to 12.0 t',
            'att-wire-lashing': 'Ø6 mm',
          },
        ),
        isEmpty,
      );
    });

    test('only the uncovered ids are still asked about', () {
      expect(
        equipmentStillUnanswered(
          requiredHardwareIds: const ['att-wood-chock', 'att-wire-lashing'],
          answered: const {'att-wood-chock': 'up to 12.0 t'},
        ),
        ['att-wire-lashing'],
      );
    });
  });
}
