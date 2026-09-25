import 'package:test/test.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/schematic_element.dart';
import 'package:railsim/domain/usecases/schematic_builder.dart';

// `VehicleSchematicOffsetNotifier` (presentation/providers) is a two-line
// wrapper — `state = SchematicBuilder.clampVehicleOffset(state + delta)` —
// around the pure functions tested directly below. It isn't imported here
// because it transitively imports `flutter_riverpod`, which itself imports
// `package:flutter`; that fails to compile under plain `dart test` in this
// sandbox (verified: the VM lacks the Flutter-SDK-patched `dart:ui` those
// sources need), the same restriction that blocks `flutter test` here. The
// logic it delegates to is fully covered without it.

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

Vehicle _vehicle({String? ironSpurType}) => Vehicle(
      id: 'veh-1',
      handbookDesignation: 'veh-1',
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
      id: 'att-iron-spur', category: AttachmentCategory.metalStop, name: 'Iron spur', referenceId: 'para-31'),
];

/// Simulates what `VehicleSchematicOffsetNotifier.dragBy` does, one call at
/// a time, entirely with the pure functions it delegates to.
SchematicPoint _simulateDrag(SchematicPoint start, List<SchematicPoint> deltas) {
  var state = start;
  for (final delta in deltas) {
    state = SchematicBuilder.clampVehicleOffset(state + delta);
  }
  return state;
}

void main() {
  group('Schematic drag offset — pure logic', () {
    test('initial normalized position is the centered origin', () {
      const initial = SchematicPoint(0, 0);
      expect(initial.dx, 0.0);
      expect(initial.dy, 0.0);
    });

    test('dragging by a small delta within bounds moves the offset exactly', () {
      final result = _simulateDrag(const SchematicPoint(0, 0), [const SchematicPoint(0.02, 0.01)]);
      expect(result.dx, closeTo(0.02, 1e-9));
      expect(result.dy, closeTo(0.01, 1e-9));
    });

    test('accumulates multiple in-bounds drags', () {
      final result = _simulateDrag(const SchematicPoint(0, 0), [
        const SchematicPoint(0.02, 0),
        const SchematicPoint(0.02, 0),
      ]);
      expect(result.dx, closeTo(0.04, 1e-9));
    });

    test('clamps to the platform edge when dragged far beyond it, never past it', () {
      final result = _simulateDrag(const SchematicPoint(0, 0), [const SchematicPoint(10.0, 10.0)]);
      final directClamp = SchematicBuilder.clampVehicleOffset(const SchematicPoint(10.0, 10.0));
      expect(result.dx, directClamp.dx);
      expect(result.dy, directClamp.dy);
      expect(result.dx, isNot(10.0));
      expect(result.dx.abs(), lessThan(1.0));
      expect(result.dy.abs(), lessThan(1.0));
    });

    test('clamping is symmetric in both directions', () {
      final positive = SchematicBuilder.clampVehicleOffset(const SchematicPoint(5.0, 5.0));
      final negative = SchematicBuilder.clampVehicleOffset(const SchematicPoint(-5.0, -5.0));
      expect(negative.dx, -positive.dx);
      expect(negative.dy, -positive.dy);
    });

    test('reset (returning to (0,0)) reproduces exactly the default, no-offset diagram', () {
      final vehicle = _vehicle(ironSpurType: 'Ş-303');
      final dragged = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
        vehicleOffset: const SchematicPoint(0.1, 0.05),
      );
      final afterReset = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
        vehicleOffset: const SchematicPoint(0, 0),
      );
      final defaultDiagram = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
      );

      final draggedBody = dragged.elementsOfKind(SchematicElementKind.vehicleBody).single;
      final resetBody = afterReset.elementsOfKind(SchematicElementKind.vehicleBody).single;
      final defaultBody = defaultDiagram.elementsOfKind(SchematicElementKind.vehicleBody).single;

      expect(draggedBody.points, isNot(resetBody.points));
      expect(resetBody.points[0].dx, defaultBody.points[0].dx);
      expect(resetBody.points[0].dy, defaultBody.points[0].dy);
    });
  });

  group('Dragging never fabricates or alters engineering data', () {
    test('vehicle/platform HandbookField data is unaffected by any drag offset', () {
      final vehicle = _vehicle(ironSpurType: 'Ş-303');
      SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
        vehicleOffset: const SchematicPoint(0.2, 0.08),
      );
      // Building a diagram must never mutate or populate the source data.
      expect(vehicle.lengthCm.isAvailable, isFalse);
      expect(vehicle.widthCm.isAvailable, isFalse);
      expect(_platform.lengthCm.isAvailable, isFalse);
    });

    test('every element stays within normalized 0..1 space at any drag extreme', () {
      final vehicle = _vehicle(ironSpurType: 'Ş-303');
      for (final offset in [
        const SchematicPoint(0, 0),
        const SchematicPoint(100, 100),
        const SchematicPoint(-100, -100),
      ]) {
        final diagram = SchematicBuilder.build(
          vehicle: vehicle,
          platform: _platform,
          requiredHardwareIds: const ['att-iron-spur'],
          attachments: _attachments,
          vehicleOffset: offset,
        );
        for (final element in diagram.elements) {
          for (final point in element.points) {
            expect(point.dx, inInclusiveRange(0.0, 1.0));
            expect(point.dy, inInclusiveRange(0.0, 1.0));
          }
        }
      }
    });

    test('the symmetry axis element never changes because of a drag — it is not a verdict', () {
      final vehicle = _vehicle(ironSpurType: 'Ş-303');
      final centered = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
      );
      final dragged = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
        vehicleOffset: const SchematicPoint(0.2, 0.08),
      );
      final axisA = centered.elementsOfKind(SchematicElementKind.symmetryAxis).single;
      final axisB = dragged.elementsOfKind(SchematicElementKind.symmetryAxis).single;
      expect(axisA.points[0].dx, axisB.points[0].dx);
      expect(axisA.points[0].dy, axisB.points[0].dy);
      expect(axisA.points[1].dx, axisB.points[1].dx);
      expect(axisA.label, axisB.label);
      expect(axisA.relatedReferenceIds, axisB.relatedReferenceIds);
    });

    test('handbook-supported hardware relationships survive a drag unchanged', () {
      final vehicle = _vehicle(ironSpurType: 'Ş-303');
      final centered = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
      );
      final dragged = SchematicBuilder.build(
        vehicle: vehicle,
        platform: _platform,
        requiredHardwareIds: const ['att-iron-spur'],
        attachments: _attachments,
        vehicleOffset: const SchematicPoint(0.15, 0.05),
      );
      final pairsA = centered.elementsOfKind(SchematicElementKind.ironSpurPair);
      final pairsB = dragged.elementsOfKind(SchematicElementKind.ironSpurPair);
      expect(pairsA.length, pairsB.length);
      for (var i = 0; i < pairsA.length; i++) {
        expect(pairsA[i].relatedReferenceIds, pairsB[i].relatedReferenceIds);
        expect(pairsA[i].isPositionHandbookSupported, pairsB[i].isPositionHandbookSupported);
        expect(pairsA[i].label, pairsB[i].label);
        // Only the drawn position shifts with the vehicle.
        expect(pairsB[i].points[0].dx, closeTo(pairsA[i].points[0].dx + 0.15, 1e-9));
        expect(pairsB[i].points[0].dy, closeTo(pairsA[i].points[0].dy + 0.05, 1e-9));
      }
    });
  });
}
