import 'package:test/test.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/schematic_element.dart';
import 'package:railsim/domain/usecases/schematic_builder.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({
  required String id,
  VehicleCategory category = VehicleCategory.tracked,
  String? ironSpurType,
  String? ironChockBootType,
  String referenceId = 'para-31',
  HandbookField? weightT,
}) =>
    Vehicle(
      id: id,
      handbookDesignation: id,
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
      ironSpurType: ironSpurType,
      ironChockBootType: ironChockBootType,
      referenceId: referenceId,
    );

const _platform = Platform(
  id: 'plat-1',
  name: 'Generic open flatcar',
  lengthCm: _todo,
  widthCm: _todo,
  deckHeightCm: _todo,
  maxAxleLoadWheeledT: _todo,
  maxGroundPressureTrackedKgCm2: _todo,
  specialCaseMaxTrackedT: _todo,
  attachmentRings: _todo,
  tieDownRings: _todo,
  woodSupportPositions: _todo,
  allowedVehicleTypes: ['tracked', 'wheeled'],
  referenceId: 'para-51',
);

const _attachments = [
  AttachmentType(
      id: 'att-iron-spur', category: AttachmentCategory.metalStop, name: 'Iron spur', referenceId: 'para-31'),
  AttachmentType(
      id: 'att-iron-chock-boot',
      category: AttachmentCategory.metalStop,
      name: 'Iron stop-boot',
      referenceId: 'para-32'),
  AttachmentType(
      id: 'att-kguub-1g', category: AttachmentCategory.specialLock, name: 'KGUUB-1G', referenceId: 'para-29'),
  AttachmentType(
      id: 'att-wire-lashing', category: AttachmentCategory.rope, name: 'Wire lashing', referenceId: 'table-7'),
  AttachmentType(
      id: 'att-wood-chock', category: AttachmentCategory.woodBlock, name: 'Wood stop-block', referenceId: 'para-21'),
];

const _measurements = {
  'trackChockByWeightTable': {
    'rows': [
      {'combatWeightRangeT': 'up to 12.0', 'chockHeightMm': 75, 'chockWidthMm': 150},
      {'combatWeightRangeT': '12.1-18.0', 'chockHeightMm': 100, 'chockWidthMm': 180},
    ],
  },
};

const _rules = {
  'rules': [
    {
      'id': 'rule-wheeled-lashing-count',
      'lookup': [
        {'combatWeightMaxT': 24.0, 'lashingsRequired': 4},
        {'combatWeightMaxT': 40.0, 'lashingsRequired': 8},
      ],
    },
  ],
};

bool _isNormalized(double v) => v >= 0.0 && v <= 1.0;

void main() {
  group('SchematicBuilder — base elements', () {
    test('always includes platform, vehicle, symmetry axis identified by their own source ids', () {
      final vehicle = _vehicle(id: 'veh-1', ironSpurType: 'Ş-303');
      final diagram = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const [],
        attachments: _attachments,
      );

      final platformDeck = diagram.elementsOfKind(SchematicElementKind.platformDeck).single;
      expect(platformDeck.sourceEntityId, _platform.id);

      final vehicleBody = diagram.elementsOfKind(SchematicElementKind.vehicleBody).single;
      expect(vehicleBody.sourceEntityId, vehicle.id);
      expect(vehicleBody.relatedReferenceIds, contains('para-34'));

      final axis = diagram.elementsOfKind(SchematicElementKind.symmetryAxis).single;
      expect(axis.relatedReferenceIds, contains('para-34'));
      expect(axis.isPositionHandbookSupported, isTrue);
    });

    test('no hardware resolved -> no hardware-kind elements are fabricated', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-1'),
        platform: _platform,
        requiredHardwareIds: const [],
        attachments: _attachments,
      );
      const hardwareKinds = {
        SchematicElementKind.ironSpurPair,
        SchematicElementKind.ironChockBootPair,
        SchematicElementKind.reusableChockPair,
        SchematicElementKind.wireLashing,
      };
      expect(diagram.elements.where((e) => hardwareKinds.contains(e.kind)), isEmpty);
    });

    test('tracked vehicles get track-run elements, wheeled vehicles get wheel-run elements', () {
      final tracked = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-t', category: VehicleCategory.tracked),
        platform: _platform,
        requiredHardwareIds: const [],
        attachments: _attachments,
      );
      expect(tracked.elementsOfKind(SchematicElementKind.trackRun), isNotEmpty);
      expect(tracked.elementsOfKind(SchematicElementKind.wheelRun), isEmpty);

      final wheeled = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-w', category: VehicleCategory.wheeled),
        platform: _platform,
        requiredHardwareIds: const [],
        attachments: _attachments,
      );
      expect(wheeled.elementsOfKind(SchematicElementKind.wheelRun), isNotEmpty);
      expect(wheeled.elementsOfKind(SchematicElementKind.trackRun), isEmpty);
    });
  });

  group('SchematicBuilder — resolved hardware produces the right elements', () {
    test('att-iron-spur produces two labeled spur-pair elements citing para-31', () {
      final vehicle = _vehicle(id: 'veh-spur', ironSpurType: 'Ş-303');
      final diagram = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.ironSpurPair);
      expect(pairs, hasLength(2));
      for (final pair in pairs) {
        expect(pair.sourceEntityId, 'att-iron-spur');
        expect(pair.relatedReferenceIds, ['para-31']);
        expect(pair.label, contains('Ş-303'));
        expect(pair.points, hasLength(2));
        expect(pair.isGeometrySchematic, isTrue);
      }
    });

    test('att-iron-chock-boot produces two labeled chock-boot-pair elements citing para-32', () {
      final vehicle = _vehicle(id: 'veh-boot', ironChockBootType: 'KT-137');
      final diagram = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-chock-boot'],
        attachments: _attachments,
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.ironChockBootPair);
      expect(pairs, hasLength(2));
      expect(pairs.every((p) => p.relatedReferenceIds.contains('para-32')), isTrue);
      expect(pairs.every((p) => p.label.contains('KT-137')), isTrue);
    });

    test('att-kguub-1g produces handbook-supported reusable-chock pairs citing para-29 and para-36', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-kguub'),
        platform: _platform,
        requiredHardwareIds: const ['att-kguub-1g'],
        attachments: _attachments,
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.reusableChockPair);
      expect(pairs, hasLength(2));
      for (final pair in pairs) {
        expect(pair.isPositionHandbookSupported, isTrue,
            reason: 'chock placement near the last road wheel is explicit handbook text');
        expect(pair.relatedReferenceIds, containsAll(['para-29', 'para-36']));
      }
    });

    test('att-wire-lashing produces lashing lines with attachment-point markers', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-wire'),
        platform: _platform,
        requiredHardwareIds: const ['att-wire-lashing'],
        attachments: _attachments,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.wireLashing), hasLength(4));
      expect(diagram.elementsOfKind(SchematicElementKind.attachmentPoint), hasLength(4));
    });

    test('unresolved hardware ids in the vehicle-specific fields do not appear without requiredHardwareIds', () {
      // Vehicle has an iron spur type recorded, but the caller didn't pass
      // 'att-iron-spur' as resolved — the builder must not infer or
      // fabricate the hardware element from the vehicle field alone.
      final vehicle = _vehicle(id: 'veh-spur-2', ironSpurType: 'Ş-303');
      final diagram = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const [],
        attachments: _attachments,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.ironSpurPair), isEmpty);
    });
  });

  group('SchematicBuilder — selected equipment type overrides the drawn label', () {
    test('a selected iron-spur type replaces the vehicle-resolved one on the drawing', () {
      final vehicle = _vehicle(id: 'veh-spur', ironSpurType: 'Ş-303');
      final diagram = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
        selectedHardwareTypes: const {'att-iron-spur': 'Ş-350'},
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.ironSpurPair);
      expect(pairs.every((p) => p.label.contains('Ş-350')), isTrue);
      expect(pairs.every((p) => !p.label.contains('Ş-303')), isTrue,
          reason: 'a wrong/alternate selection must still be what is drawn, not silently corrected');
    });

    test('with no selection made, the vehicle-resolved type is drawn as before (unchanged default)', () {
      final vehicle = _vehicle(id: 'veh-boot', ironChockBootType: 'KT-137');
      final diagram = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-chock-boot'],
        attachments: _attachments,
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.ironChockBootPair);
      expect(pairs.every((p) => p.label.contains('KT-137')), isTrue);
    });
  });

  group('SchematicBuilder — selection-mismatch marking', () {
    test('a selection matching the vehicle-mandated type is never flagged mismatched', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-spur', ironSpurType: 'Ş-303'),
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
        selectedHardwareTypes: const {'att-iron-spur': 'Ş-303'},
      );
      expect(
        diagram.elementsOfKind(SchematicElementKind.ironSpurPair).every((p) => !p.isSelectionMismatch),
        isTrue,
      );
    });

    test('a selection contradicting the vehicle-mandated type is flagged mismatched but still drawn as picked', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-spur', ironSpurType: 'Ş-303'),
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
        selectedHardwareTypes: const {'att-iron-spur': 'Ş-350'},
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.ironSpurPair);
      expect(pairs.every((p) => p.isSelectionMismatch), isTrue);
      expect(pairs.every((p) => p.label.contains('Ş-350')), isTrue,
          reason: 'the wrong selection is never silently replaced with the correct one');
    });

    test('no selection made yet is never flagged mismatched (nothing to score)', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-spur', ironSpurType: 'Ş-303'),
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
      );
      expect(
        diagram.elementsOfKind(SchematicElementKind.ironSpurPair).every((p) => !p.isSelectionMismatch),
        isTrue,
      );
    });

    test('missing engineering information (no combat weight) never produces a fabricated mismatch verdict', () {
      // No vehicle-specific hardware type at all and no combat weight: no
      // hardware is resolved, so there is nothing to flag as mismatched.
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-unknown'),
        platform: _platform,
        requiredHardwareIds: const [],
        attachments: _attachments,
        selectedHardwareTypes: const {'att-iron-spur': 'Ş-303'},
      );
      expect(diagram.elements.any((e) => e.isSelectionMismatch), isFalse);
    });
  });

  group('SchematicBuilder — wood chock (Table 3, para. 21)', () {
    test('produces a distinct, handbook-supported pair with the real resolved dimensions', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-wood', weightT: const HandbookField(10.0)),
        platform: _platform,
        requiredHardwareIds: const ['att-wood-chock'],
        attachments: _attachments,
        measurements: _measurements,
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.woodChockPair);
      expect(pairs, hasLength(2));
      expect(pairs.every((p) => p.isPositionHandbookSupported), isTrue,
          reason: 'para-21 explicitly states the relational placement (against the wheel/track)');
      expect(pairs.every((p) => p.label.contains('75×150 mm')), isTrue);
      expect(pairs.every((p) => p.relatedReferenceIds.contains('para-21')), isTrue);
    });

    test('without measurements data, no dimension is fabricated — the label omits it', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-wood', weightT: const HandbookField(10.0)),
        platform: _platform,
        requiredHardwareIds: const ['att-wood-chock'],
        attachments: _attachments,
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.woodChockPair);
      expect(pairs, hasLength(2));
      expect(pairs.every((p) => !p.label.contains('mm')), isTrue);
    });

    test('selecting a bracket that does not match the vehicle\'s own weight draws that selection, marked mismatched', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-wood', weightT: const HandbookField(10.0)), // -> "up to 12.0"
        platform: _platform,
        requiredHardwareIds: const ['att-wood-chock'],
        attachments: _attachments,
        measurements: _measurements,
        selectedHardwareTypes: const {'att-wood-chock': '12.1-18.0 t'},
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.woodChockPair);
      expect(pairs.every((p) => p.isSelectionMismatch), isTrue);
      expect(pairs.every((p) => p.label.contains('100×180 mm')), isTrue,
          reason: 'the wrongly-selected bracket\'s own dimensions are drawn, never silently corrected');
    });

    test('selecting the bracket that matches the vehicle\'s own weight is never flagged mismatched', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-wood', weightT: const HandbookField(10.0)),
        platform: _platform,
        requiredHardwareIds: const ['att-wood-chock'],
        attachments: _attachments,
        measurements: _measurements,
        selectedHardwareTypes: const {'att-wood-chock': 'up to 12.0 t'},
      );
      final pairs = diagram.elementsOfKind(SchematicElementKind.woodChockPair);
      expect(pairs.every((p) => !p.isSelectionMismatch), isTrue);
    });
  });

  group('SchematicBuilder — spacer/packing board (para. 24)', () {
    test('att-wood-packing produces a distinct spacer-board element, schematic and cumulative with wood chock', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-wood', weightT: const HandbookField(10.0)),
        platform: _platform,
        requiredHardwareIds: const ['att-wood-chock', 'att-wood-packing'],
        attachments: _attachments,
        measurements: _measurements,
      );
      final boards = diagram.elementsOfKind(SchematicElementKind.spacerBoard);
      expect(boards, hasLength(1));
      expect(boards.single.relatedReferenceIds, contains('para-24'));
      expect(boards.single.isGeometrySchematic, isTrue);
      expect(diagram.elementsOfKind(SchematicElementKind.woodChockPair), isNotEmpty,
          reason: 'method 5 = wood chock + spacer board together — both must appear');
    });

    test('att-wood-packing alone does not fabricate a wood chock', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-wood'),
        platform: _platform,
        requiredHardwareIds: const ['att-wood-packing'],
        attachments: _attachments,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.spacerBoard), hasLength(1));
      expect(diagram.elementsOfKind(SchematicElementKind.woodChockPair), isEmpty);
    });
  });

  group('SchematicBuilder — wire lashing count reflects the actual rule', () {
    test('a weight in the 4-lashing bracket draws exactly 4 connections', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(
          id: 'veh-wheeled',
          category: VehicleCategory.wheeled,
          weightT: const HandbookField(20.0),
        ),
        platform: _platform,
        requiredHardwareIds: const ['att-wire-lashing'],
        attachments: _attachments,
        rules: _rules,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.wireLashing), hasLength(4));
      expect(diagram.elementsOfKind(SchematicElementKind.attachmentPoint), hasLength(4));
    });

    test('a weight in the 8-lashing bracket draws exactly 8 connections, not a fixed 4', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(
          id: 'veh-wheeled-heavy',
          category: VehicleCategory.wheeled,
          weightT: const HandbookField(30.0),
        ),
        platform: _platform,
        requiredHardwareIds: const ['att-wire-lashing'],
        attachments: _attachments,
        rules: _rules,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.wireLashing), hasLength(8));
      expect(diagram.elementsOfKind(SchematicElementKind.attachmentPoint), hasLength(8));
      for (final e in diagram.elements) {
        for (final p in e.points) {
          expect(_isNormalized(p.dx), isTrue, reason: '${e.kind} dx out of 0..1');
          expect(_isNormalized(p.dy), isTrue, reason: '${e.kind} dy out of 0..1');
        }
      }
    });

    test('without rules data, falls back to the previous default of 4 rather than guessing', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(
          id: 'veh-wheeled',
          category: VehicleCategory.wheeled,
          weightT: const HandbookField(30.0),
        ),
        platform: _platform,
        requiredHardwareIds: const ['att-wire-lashing'],
        attachments: _attachments,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.wireLashing), hasLength(4));
    });
  });

  group('SchematicBuilder — never fabricates real geometry', () {
    test('every element stays within normalized 0..1 layout space, never a claimed cm coordinate', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-1', ironSpurType: 'Ş-303'),
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
      );
      for (final element in diagram.elements) {
        for (final point in element.points) {
          expect(_isNormalized(point.dx), isTrue, reason: '${element.kind} dx out of 0..1');
          expect(_isNormalized(point.dy), isTrue, reason: '${element.kind} dy out of 0..1');
        }
      }
    });

    test('the diagram is never reported as fully-to-scale with the current handbook extract', () {
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle(id: 'veh-1', ironSpurType: 'Ş-303'),
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
      );
      expect(diagram.isFullyToScale, isFalse);
    });
  });
}
