import 'package:test/test.dart';
import 'package:railsim/data/models/attachment_type.dart';
import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/schematic_element.dart';
import 'package:railsim/domain/usecases/schematic_builder.dart';
import 'package:railsim/domain/usecases/securing_method_resolution.dart';

const _todo = HandbookField('TODO: Fill from Handbook Page XX');

const _vehicle = Vehicle(
  id: 'veh-generic-tracked',
  handbookDesignation: 'veh-generic-tracked',
  category: VehicleCategory.tracked,
  vehicleClass: 'TODO: Fill from Handbook Page XX',
  lengthCm: _todo,
  widthCm: _todo,
  heightCm: _todo,
  weightT: HandbookField(20.0),
  groundClearanceCm: _todo,
  trackWidthMm: _todo,
  wheelBaseCm: _todo,
  manufacturer: 'TODO: Fill from Handbook Page XX',
  country: 'TODO: Fill from Handbook Page XX',
  approvedSecuringHardwareIds: [],
  referenceId: 'para-34',
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
      id: 'att-kguub-1g', category: AttachmentCategory.specialLock, name: 'KGUUB-1G', referenceId: 'para-29'),
  AttachmentType(
      id: 'att-wood-chock', category: AttachmentCategory.woodBlock, name: 'Wood stop-block', referenceId: 'para-21'),
  AttachmentType(
      id: 'att-wire-lashing', category: AttachmentCategory.rope, name: 'Wire lashing', referenceId: 'table-7'),
];

void main() {
  group('Selecting one alternative securing method shows only that method\'s equipment', () {
    test('selecting method 1 (KGUUB) displays KGUUB only — no wood chock, no wire lashing', () {
      final hardwareIds = hardwareIdsForSecuringMethod(1, _vehicle);
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle,
        platform: _platform,
        requiredHardwareIds: hardwareIds,
        attachments: _attachments,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.reusableChockPair), isNotEmpty);
      expect(diagram.elementsOfKind(SchematicElementKind.woodChockPair), isEmpty);
      expect(diagram.elementsOfKind(SchematicElementKind.wireLashing), isEmpty);
    });

    test('selecting method 5 (wood chock + spacer boards) displays wood chock only — no KGUUB, no wire lashing', () {
      final hardwareIds = hardwareIdsForSecuringMethod(5, _vehicle);
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle,
        platform: _platform,
        requiredHardwareIds: hardwareIds,
        attachments: _attachments,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.woodChockPair), isNotEmpty);
      expect(diagram.elementsOfKind(SchematicElementKind.reusableChockPair), isEmpty);
      expect(diagram.elementsOfKind(SchematicElementKind.wireLashing), isEmpty);
    });

    test('changing the applied method from KGUUB to wood chock removes KGUUB from the drawing', () {
      final kguubDiagram = SchematicBuilder.build(
        vehicle: _vehicle,
        platform: _platform,
        requiredHardwareIds: hardwareIdsForSecuringMethod(1, _vehicle),
        attachments: _attachments,
      );
      expect(kguubDiagram.elementsOfKind(SchematicElementKind.reusableChockPair), isNotEmpty);

      final woodChockDiagram = SchematicBuilder.build(
        vehicle: _vehicle,
        platform: _platform,
        requiredHardwareIds: hardwareIdsForSecuringMethod(5, _vehicle),
        attachments: _attachments,
      );
      expect(woodChockDiagram.elementsOfKind(SchematicElementKind.reusableChockPair), isEmpty,
          reason: 'switching methods must not leave the previous method\'s equipment behind');
      expect(woodChockDiagram.elementsOfKind(SchematicElementKind.woodChockPair), isNotEmpty);
    });

    test('method 3\'s genuinely cumulative equipment (wood chock + wire lashing) still appears together', () {
      final hardwareIds = hardwareIdsForSecuringMethod(3, _vehicle);
      final diagram = SchematicBuilder.build(
        vehicle: _vehicle,
        platform: _platform,
        requiredHardwareIds: hardwareIds,
        attachments: _attachments,
      );
      expect(diagram.elementsOfKind(SchematicElementKind.woodChockPair), isNotEmpty,
          reason: 'method 3 = wood stop-blocks + wire lashings, both are part of the SAME approved method');
      expect(diagram.elementsOfKind(SchematicElementKind.wireLashing), isNotEmpty);
      expect(diagram.elementsOfKind(SchematicElementKind.reusableChockPair), isEmpty,
          reason: 'method 1 (KGUUB) was not the applied method, so it must not appear alongside method 3');
    });

    test('no two alternative methods\' hardware ever appear simultaneously for the same vehicle', () {
      for (final method in [1, 3, 5]) {
        final hardwareIds = hardwareIdsForSecuringMethod(method, _vehicle);
        final diagram = SchematicBuilder.build(
          vehicle: _vehicle,
          platform: _platform,
          requiredHardwareIds: hardwareIds,
          attachments: _attachments,
        );
        final hardwareKindsPresent = {
          SchematicElementKind.reusableChockPair: diagram.elementsOfKind(SchematicElementKind.reusableChockPair).isNotEmpty,
          SchematicElementKind.woodChockPair: diagram.elementsOfKind(SchematicElementKind.woodChockPair).isNotEmpty,
        };
        // Exactly one of {KGUUB, wood chock} may be present per applied
        // method — 1 uses KGUUB only, 3 and 5 use wood chock only.
        final presentCount = hardwareKindsPresent.values.where((v) => v).length;
        expect(presentCount, lessThanOrEqualTo(1),
            reason: 'method $method must not draw both KGUUB and wood chock at once');
      }
    });
  });
}
