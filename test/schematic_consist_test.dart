import 'package:test/test.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/schematic_element.dart';
import 'package:railsim/domain/usecases/schematic_builder.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({
  String id = 'veh-1',
  String designation = 'veh-1',
  VehicleCategory category = VehicleCategory.tracked,
  String? ironSpurType,
}) =>
    Vehicle(
      id: id,
      handbookDesignation: designation,
      category: category,
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
      referenceId: 'para-31',
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
  allowedVehicleTypes: ['tracked'],
  referenceId: 'para-51',
);

const _attachments = [
  AttachmentType(
      id: 'att-iron-spur',
      category: AttachmentCategory.metalStop,
      name: 'Iron spur',
      referenceId: 'para-31'),
];

double _left(SchematicElement e) => e.points.first.dx;
double _right(SchematicElement e) => e.points.last.dx;

void main() {
  group('buildConsist — wagon elements', () {
    test('the deck, rails and axis are emitted once regardless of vehicle count', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(placementId: 'p1', vehicle: _vehicle(id: 'veh-a')),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-b')),
          ConsistPlacement(placementId: 'p3', vehicle: _vehicle(id: 'veh-c')),
        ],
      );

      expect(diagram.elementsOfKind(SchematicElementKind.platformDeck), hasLength(1));
      expect(diagram.elementsOfKind(SchematicElementKind.symmetryAxis), hasLength(1));
      expect(diagram.elementsOfKind(SchematicElementKind.railDirection), hasLength(2));
    });

    test('wagon elements carry no placementId — they belong to the platform', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [ConsistPlacement(placementId: 'p1', vehicle: _vehicle())],
      );

      for (final kind in [
        SchematicElementKind.platformDeck,
        SchematicElementKind.railDirection,
        SchematicElementKind.symmetryAxis,
      ]) {
        for (final e in diagram.elementsOfKind(kind)) {
          expect(e.placementId, isNull, reason: '$kind must not belong to a vehicle');
        }
      }
    });

    test('an empty consist still draws the wagon', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: const [],
      );
      expect(diagram.elementsOfKind(SchematicElementKind.platformDeck), hasLength(1));
      expect(diagram.elementsOfKind(SchematicElementKind.vehicleBody), isEmpty);
      expect(diagram.placementIds, isEmpty);
    });
  });

  group('buildConsist — several vehicles on one wagon', () {
    test('each placed vehicle gets its own body element', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(placementId: 'p1', vehicle: _vehicle(id: 'veh-a', designation: 'T-54')),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-b', designation: '2S3')),
        ],
      );

      final bodies = diagram.elementsOfKind(SchematicElementKind.vehicleBody);
      expect(bodies, hasLength(2));
      expect(bodies.map((e) => e.label), ['T-54', '2S3']);
      expect(diagram.placementIds, ['p1', 'p2']);
    });

    test('two copies of the same designation stay distinguishable by placement', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(placementId: 'p1', vehicle: _vehicle(id: 'veh-t54')),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-t54')),
        ],
      );

      final bodies = diagram.elementsOfKind(SchematicElementKind.vehicleBody);
      expect(bodies.map((e) => e.sourceEntityId).toSet(), {'veh-t54'},
          reason: 'both are the same designation');
      expect(bodies.map((e) => e.placementId), ['p1', 'p2'],
          reason: 'but they must be separately selectable');
    });

    test('two vehicles are laid side by side and do not overlap', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(placementId: 'p1', vehicle: _vehicle(id: 'veh-a')),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-b')),
        ],
      );

      final bodies = diagram.elementsOfKind(SchematicElementKind.vehicleBody);
      expect(_right(bodies[0]), lessThan(_left(bodies[1])));
    });

    test('every vehicle stays within the drawn deck', () {
      for (final count in [1, 2, 3, 4]) {
        final diagram = SchematicBuilder.buildConsist(
          platform: _platform,
          attachments: _attachments,
          placements: [
            for (var i = 0; i < count; i++)
              ConsistPlacement(placementId: 'p$i', vehicle: _vehicle(id: 'veh-$i')),
          ],
        );
        final deck = diagram.elementsOfKind(SchematicElementKind.platformDeck).single;
        for (final body in diagram.elementsOfKind(SchematicElementKind.vehicleBody)) {
          expect(_left(body), greaterThanOrEqualTo(_left(deck)),
              reason: 'with $count vehicles');
          expect(_right(body), lessThanOrEqualTo(_right(deck)),
              reason: 'with $count vehicles');
        }
      }
    });

    test('a single placement is laid out exactly where build() puts it', () {
      // The slot mapping must be the identity for one vehicle, so the
      // multi-vehicle path cannot quietly shift the familiar drawing.
      final single = SchematicBuilder.build(
        vehicle: _vehicle(),
        platform: _platform,
        requiredHardwareIds: const [],
        attachments: _attachments,
      );
      final consist = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [ConsistPlacement(placementId: 'p1', vehicle: _vehicle())],
      );

      final a = single.elementsOfKind(SchematicElementKind.vehicleBody).single;
      final b = consist.elementsOfKind(SchematicElementKind.vehicleBody).single;
      expect(_left(b), closeTo(_left(a), 1e-9));
      expect(_right(b), closeTo(_right(a), 1e-9));
    });
  });

  group('buildConsist — per-placement hardware and offsets', () {
    test('hardware is resolved per placement, not shared across the wagon', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(
            placementId: 'p1',
            vehicle: _vehicle(id: 'veh-a', ironSpurType: 'Ş-303'),
            requiredHardwareIds: const ['att-iron-spur'],
          ),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-b')),
        ],
      );

      final spurs = diagram.elementsOfKind(SchematicElementKind.ironSpurPair);
      expect(spurs, isNotEmpty);
      expect(spurs.map((e) => e.placementId).toSet(), {'p1'},
          reason: 'the second vehicle required no spur and must not be given one');
      expect(diagram.elementsForPlacement('p2')
          .any((e) => e.kind == SchematicElementKind.ironSpurPair), isFalse);
    });

    test("one placement's hardware sits with its own vehicle body", () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(placementId: 'p1', vehicle: _vehicle(id: 'veh-a')),
          ConsistPlacement(
            placementId: 'p2',
            vehicle: _vehicle(id: 'veh-b', ironSpurType: 'Ş-303'),
            requiredHardwareIds: const ['att-iron-spur'],
          ),
        ],
      );

      final body = diagram
          .elementsForPlacement('p2')
          .firstWhere((e) => e.kind == SchematicElementKind.vehicleBody);
      final spurs = diagram.elementsOfKind(SchematicElementKind.ironSpurPair);
      for (final spur in spurs) {
        expect(spur.points.first.dx, greaterThanOrEqualTo(_left(body)));
        expect(spur.points.first.dx, lessThanOrEqualTo(_right(body)));
      }
    });

    test('dragging one placement does not move another', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(
            placementId: 'p1',
            vehicle: _vehicle(id: 'veh-a'),
            offset: const SchematicPoint(0.1, 0),
          ),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-b')),
        ],
      );
      final undragged = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(placementId: 'p1', vehicle: _vehicle(id: 'veh-a')),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-b')),
        ],
      );

      final movedBody = diagram
          .elementsForPlacement('p1')
          .firstWhere((e) => e.kind == SchematicElementKind.vehicleBody);
      final stillBody = diagram
          .elementsForPlacement('p2')
          .firstWhere((e) => e.kind == SchematicElementKind.vehicleBody);
      final baselineMoved = undragged
          .elementsForPlacement('p1')
          .firstWhere((e) => e.kind == SchematicElementKind.vehicleBody);
      final baselineStill = undragged
          .elementsForPlacement('p2')
          .firstWhere((e) => e.kind == SchematicElementKind.vehicleBody);

      expect(_left(movedBody), isNot(closeTo(_left(baselineMoved), 1e-9)));
      expect(_left(stillBody), closeTo(_left(baselineStill), 1e-9),
          reason: 'the old single global offset moved every vehicle at once');
    });

    test('an out-of-range offset is clamped, never drawn off the deck', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(
            placementId: 'p1',
            vehicle: _vehicle(),
            offset: const SchematicPoint(99, 99),
          ),
        ],
      );
      final deck = diagram.elementsOfKind(SchematicElementKind.platformDeck).single;
      final body = diagram.elementsOfKind(SchematicElementKind.vehicleBody).single;
      expect(_right(body), lessThanOrEqualTo(_right(deck)));
    });
  });

  group('buildConsist — geometry honesty', () {
    test('nothing claims to be to scale, since no vehicle has real dimensions', () {
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(placementId: 'p1', vehicle: _vehicle(id: 'veh-a')),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-b')),
        ],
      );
      expect(diagram.isFullyToScale, isFalse);
      expect(diagram.elements.every((e) => e.isGeometrySchematic), isTrue);
    });

    test('side-by-side layout is not presented as a measured clearance', () {
      // Two vehicles are drawn apart for legibility. That gap is a layout
      // choice, not the handbook's 100 mm minimum, and the elements must not
      // imply otherwise.
      final diagram = SchematicBuilder.buildConsist(
        platform: _platform,
        attachments: _attachments,
        placements: [
          ConsistPlacement(placementId: 'p1', vehicle: _vehicle(id: 'veh-a')),
          ConsistPlacement(placementId: 'p2', vehicle: _vehicle(id: 'veh-b')),
        ],
      );
      for (final body in diagram.elementsOfKind(SchematicElementKind.vehicleBody)) {
        expect(body.isGeometrySchematic, isTrue);
      }
    });
  });
}
