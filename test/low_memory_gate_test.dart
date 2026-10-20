@Tags(['flutter'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:railsim/data/repositories/admin_catalog.dart';
import 'package:railsim/presentation/providers/handbook_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // The whole point of the setting, proved rather than assumed: with it off a
  // T-72 loads its 548,889-triangle model, with it on the same vehicle loads
  // none and is drawn from its recorded dimensions instead.
  //
  // The gate awaits the setting rather than reading it synchronously. An
  // earlier version did read it synchronously, and the catalogue is loaded
  // from a file — so during the seconds before that file arrived the answer
  // was "no" and the mesh loaded anyway, on exactly the machine the setting
  // exists to protect.
  testWidgets('the gate decides whether the heavy mesh is loaded',
      (tester) async {
    await tester.runAsync(() async {
      // Models ON: veh-t72 has a compiled model, so a mesh comes back.
      final on = ProviderContainer(overrides: [
        adminCatalogProvider.overrideWith(
            (ref) async => AdminCatalog.empty.withLowMemory(false)),
      ]);
      addTearDown(on.dispose);
      final withMesh = await on.read(vehicleMeshProvider('veh-t72').future);
      expect(withMesh, isNotNull, reason: 'T-72 should load its model');
      expect(withMesh!.model.mesh.faces, hasLength(548889));

      // Models OFF: the same vehicle comes back with no mesh at all.
      final off = ProviderContainer(overrides: [
        adminCatalogProvider.overrideWith(
            (ref) async => AdminCatalog.empty.withLowMemory(true)),
      ]);
      addTearDown(off.dispose);
      final none = await off.read(vehicleMeshProvider('veh-t72').future);
      expect(none, isNull, reason: 'low-memory mode must skip the model file');
    });
  });
}
