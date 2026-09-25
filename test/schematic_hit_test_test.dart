import 'package:test/test.dart';
import 'package:railsim/domain/models/schematic_element.dart';
import 'package:railsim/domain/usecases/schematic_hit_test.dart';

SchematicElement _rect(SchematicElementKind kind, double left, double top, double right, double bottom) =>
    SchematicElement(
      kind: kind,
      label: kind.name,
      sourceEntityId: kind.name,
      points: [SchematicPoint(left, top), SchematicPoint(right, bottom)],
      isPositionHandbookSupported: false,
      isGeometrySchematic: true,
    );

SchematicElement _line(SchematicElementKind kind, double x1, double y1, double x2, double y2) =>
    SchematicElement(
      kind: kind,
      label: kind.name,
      sourceEntityId: kind.name,
      points: [SchematicPoint(x1, y1), SchematicPoint(x2, y2)],
      isPositionHandbookSupported: false,
      isGeometrySchematic: true,
    );

void main() {
  group('hitTestSchematicElement', () {
    test('a tap inside a rect element (e.g. the vehicle body) hits it', () {
      final vehicle = _rect(SchematicElementKind.vehicleBody, 0.30, 0.40, 0.70, 0.60);
      final hit = hitTestSchematicElement([vehicle], 0.5, 0.5);
      expect(hit, same(vehicle));
    });

    test('a tap outside every element hits nothing', () {
      final vehicle = _rect(SchematicElementKind.vehicleBody, 0.30, 0.40, 0.70, 0.60);
      expect(hitTestSchematicElement([vehicle], 0.05, 0.05), isNull);
    });

    test('a tap near a line element (e.g. an iron-spur marker) within the hit radius hits it', () {
      final spur = _line(SchematicElementKind.ironSpurPair, 0.40, 0.40, 0.40, 0.60);
      expect(hitTestSchematicElement([spur], 0.41, 0.50), same(spur));
    });

    test('a tap far from a line element misses it', () {
      final spur = _line(SchematicElementKind.ironSpurPair, 0.40, 0.40, 0.40, 0.60);
      expect(hitTestSchematicElement([spur], 0.90, 0.90), isNull);
    });

    test('pure visual conventions (symmetry axis, rail direction) are never hit-testable', () {
      final axis = _line(SchematicElementKind.symmetryAxis, 0.06, 0.5, 0.94, 0.5);
      expect(hitTestSchematicElement([axis], 0.5, 0.5), isNull);
    });

    test('the topmost (last-drawn) element wins when two overlap', () {
      final platform = _rect(SchematicElementKind.platformDeck, 0.06, 0.30, 0.94, 0.70);
      final vehicle = _rect(SchematicElementKind.vehicleBody, 0.30, 0.40, 0.70, 0.60);
      final hit = hitTestSchematicElement([platform, vehicle], 0.5, 0.5);
      expect(hit, same(vehicle));
    });

    test('an empty element list never crashes and simply misses', () {
      expect(hitTestSchematicElement(const [], 0.5, 0.5), isNull);
    });
  });

  group('spacer board regression', () {
    test('a spacer board can be tapped like every other hardware pair', () {
      // Its two points share an x (near and far side of the vehicle), so
      // treating them as opposite corners of a rectangle gave a zero-width
      // hit box: the one hardware kind that could never be inspected.
      const element = SchematicElement(
        kind: SchematicElementKind.spacerBoard,
        label: 'ara goýulýan agaç',
        sourceEntityId: 'att-wood-packing',
        points: [SchematicPoint(0.5, 0.40), SchematicPoint(0.5, 0.60)],
        isPositionHandbookSupported: true,
        isGeometrySchematic: true,
      );
      expect(hitTestSchematicElement([element], 0.5, 0.5)?.sourceEntityId,
          'att-wood-packing');
      // And still misses when the tap is nowhere near it.
      expect(hitTestSchematicElement([element], 0.1, 0.5), isNull);
    });
  });
}
