import 'package:test/test.dart';
import 'package:railsim/domain/usecases/flatcar_mesh_builder.dart';
import 'package:railsim/domain/usecases/loading_scene_builder.dart';
import 'package:railsim/domain/usecases/wheeled_vehicle_mesh_builder.dart';

/// plate-05 dimensions the overhang past ONE end of the wagon and caps it at
/// 400 mm. The consist check was handed `front + rear`.
void main() {
  test('a load standing past both ends is not one overhang of their sum', () {
    // A lorry half a metre longer than its deck, centred: a quarter of a metre
    // off each end. Neither end is near the 400 mm limit; their sum is past it.
    const lorry = WheeledVehicleMeshSpec(
      hullLengthM: 6.90,
      overallWidthM: 2.50,
      overallHeightM: 2.48,
      groundClearanceM: 0.40,
      axleCount: 3,
      wheelRadiusM: 0.47,
      tyreWidthM: 0.32,
      axleFractions: [0.63, -0.32, -0.70],
    );
    final scene = buildLoadedWagonScene(
      loads: [
        const PlacedLoad(
            placementId: 'a', designation: 'a', spec: lorry, positionFraction: 0.5),
      ],
      flatcarSpec: FlatcarMeshSpec.fromPlatformFigures(
          lengthCm: 640, widthCm: 287, deckHeightCm: 131),
      includeTrackBed: false,
    );
    final front = scene.clearances.frontOverhangM;
    final rear = scene.clearances.rearOverhangM;
    expect(front, closeTo(0.25, 0.001));
    expect(rear, closeTo(0.25, 0.001));
    // The figure the guard-wagon rule is asked about is the larger end.
    expect(front + rear, greaterThan(0.400),
        reason: 'the summed figure is what used to be reported, and it fails');
    expect(front > rear ? front : rear, lessThanOrEqualTo(0.400),
        reason: 'neither end actually exceeds the plate-05 limit');
  });
}
