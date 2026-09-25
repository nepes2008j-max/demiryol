import 'dart:io';

import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/usecases/vehicle_mesh_catalog.dart';

/// The vehicles a whole-catalogue sweep actually needs to walk.
///
/// Several tests exist to prove that *every* vehicle survives a screen — the
/// remove button stays reachable, the flow runs end to end, the gear can be
/// seated by hand. They were written against a catalogue of thirty-two and
/// they walked all of it.
///
/// The catalogue is a hundred and thirty-eight now, built from the ministry's
/// transport-characteristics table, and each of those sweeps pumps a whole
/// screen — the three-dimensional scene included — once per vehicle. Walking
/// all of them costs more than the ten-minute test timeout, and a test that
/// cannot finish proves nothing at all.
///
/// So the sweeps walk a sample, and the sample is chosen rather than taken at
/// random, because what these tests are really guarding is the *shape* of a
/// record rather than the record itself:
///
/// * both running gears, because they resolve different gear and different
///   meshes;
/// * a record with full dimensions and one with none, because the second is
///   the branch that falls back to the flat views;
/// * every vehicle carrying a three-dimensional model file, because those are
///   the heaviest thing any screen draws;
/// * the longest designations in the catalogue, because a long name
///   overflowing its row is the exact defect `remove_placement_test` was
///   written for, and it is the longest names that do it.
///
/// Set `RAILSIM_FULL_SWEEP=1` to walk all of them anyway — worth doing after a
/// change to the catalogue or to a shared row, and worth the twenty minutes
/// then.
List<Vehicle> sweepSample(List<Vehicle> all, {int longestNames = 6}) {
  if (Platform.environment['RAILSIM_FULL_SWEEP'] == '1') return all;

  final chosen = <String, Vehicle>{};
  void take(Vehicle? v) {
    if (v != null) chosen[v.id] = v;
  }

  Vehicle? firstWhere(bool Function(Vehicle) test) {
    for (final v in all) {
      if (test(v)) return v;
    }
    return null;
  }

  bool dimensioned(Vehicle v) =>
      v.lengthCm.isAvailable && v.widthCm.isAvailable && v.heightCm.isAvailable;

  for (final category in VehicleCategory.values) {
    take(firstWhere((v) => v.category == category && dimensioned(v)));
    take(firstWhere((v) => v.category == category && !dimensioned(v)));
  }

  // Everything the three-dimensional view can actually build a solid for is
  // exercised, because that is where the cost and the geometry bugs live.
  for (final v in all) {
    if (VehicleMeshCatalog.canModel(v)) take(v);
  }

  final byNameLength = [...all]..sort((a, b) =>
      b.handbookDesignation.length.compareTo(a.handbookDesignation.length));
  for (final v in byNameLength.take(longestNames)) {
    take(v);
  }

  // In catalogue order, so a failure reads in the order a person would look.
  return [
    for (final v in all)
      if (chosen.containsKey(v.id)) v,
  ];
}
