import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';

void main() {
  testWidgets('BTR models load, fit and are credited', (tester) async {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    for (final id in ['veh-btr80', 'veh-btr70', 'veh-btr60']) {
      // Inside runAsync, because the provider reads the catalogue and the
      // model file off the asset bundle and that is real I/O. A widget test
      // runs on a fake clock, which never gives those reads a turn: awaited
      // outside runAsync they simply never complete, and the test sits there
      // until the ten-minute timeout kills it.
      FittedVehicleMesh? fitted;
      await tester.runAsync(() async {
        fitted = await c.read(vehicleMeshProvider(id).future);
      });
      expect(fitted, isNotNull, reason: '$id should load its asset model');
      expect(fitted!.model.mesh.faces, isNotEmpty);
      expect(fitted!.creditLine, isNotEmpty);
      final b = fitted!.model.mesh.bounds;
      // Fitted on width; the mesh stands on the ground.
      expect(b.min.y, closeTo(0.0, 0.02), reason: '$id should be seated');
      // ignore: avoid_print
      print('$id  L=${(b.max.x-b.min.x).toStringAsFixed(2)} '
            'W=${(b.max.z-b.min.z).toStringAsFixed(2)} '
            'H=${(b.max.y-b.min.y).toStringAsFixed(2)}  ${fitted!.creditLine}');
    }
  });
}
