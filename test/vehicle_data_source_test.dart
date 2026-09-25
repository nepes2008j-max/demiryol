import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:railsim/data/models/vehicle.dart';

/// Where every figure in the catalogue came from, held in place.
///
/// The catalogue is built by `tools/import_transport_table.py` from the
/// ministry's vehicle transport-characteristics table — the unit's own list of
/// what it moves, and the only source in this project that states a length,
/// width, height and weight. Annex 14 of the loading handbook states none of
/// those; what it does state is which vehicles take which iron spur (Table 13)
/// and which iron chock-boot (Table 11).
///
/// So the catalogue has two kinds of fact in it, and the whole point of these
/// tests is that the two never merge: a dimension is the transport table's, a
/// named securing method is the handbook's, and neither document is ever made
/// to say something it did not.
Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) throw StateError('$path is missing');
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  final raw = (_readJson('assets/data/vehicles.json')['vehicles'] as List)
      .cast<Map<String, dynamic>>();
  final vehicles = raw.map(Vehicle.fromJson).toList();
  final referenceIds = (_readJson('assets/data/references.json')['references'] as List)
      .cast<Map<String, dynamic>>()
      .map((e) => e['id'] as String)
      .toSet();

  group('vehicle provenance', () {
    test('every record parses to a known data source', () {
      for (final entry in raw) {
        final source = entry['dataSource'];
        expect(
            source,
            anyOf(isNull, 'handbook', 'designMockup', 'manufacturerSpec',
                'transportTable'),
            reason: '${entry['id']} has an unrecognised dataSource');
      }
    });

    test('a record with no dataSource counts as handbook-extracted', () {
      final vehicle = Vehicle.fromJson({...raw.first}..remove('dataSource'));
      expect(vehicle.dataSource, VehicleDataSource.handbook);
    });

    test('every transport-table record cites the transport table', () {
      for (final entry in raw) {
        if (entry['dataSource'] != 'transportTable') continue;
        expect(entry['referenceId'], 'doc-transport-characteristics',
            reason: '${entry['id']} carries the table\'s figures without its citation');
      }
    });

    test('every citation a record makes resolves to a real reference', () {
      for (final entry in raw) {
        expect(referenceIds, contains(entry['referenceId']), reason: entry['id'] as String);
        final securing = entry['securingReferenceId'];
        if (securing != null) {
          expect(referenceIds, contains(securing), reason: entry['id'] as String);
        }
      }
    });

    test('no securing method is assigned that the handbook did not give', () {
      // This is the one that matters. The transport table lists vehicles and
      // their sizes; it says nothing at all about how to secure them. A record
      // that named an iron spur or an iron chock-boot without a handbook
      // citation behind it would be this project inventing an engineering
      // decision, which is the single thing it exists not to do.
      for (final entry in raw) {
        final named = entry['ironSpurType'] ?? entry['ironChockBootType'];
        if (named == null) continue;
        expect(entry['securingReferenceId'], isNotNull,
            reason: '${entry['id']} names $named with no handbook citation');
        expect(entry['securingReferenceId'], isNot('doc-transport-characteristics'),
            reason: '${entry['id']} credits the transport table for a securing '
                'method that table does not state');
      }
    });

    test('the handbook assignments that survived the rebuild are still there', () {
      // Table 13 lists Object 172 — the T-72 — inside the Objects-137 family
      // and assigns that group iron spur Ş-137. The transport table calls the
      // same machine T-72/M. Only the identification crosses documents; the
      // securing method stays the handbook's, with the handbook's citation.
      final t72 = vehicles.firstWhere((v) => v.id == 'veh-t72');
      expect(t72.ironSpurType, 'Ş-137');
      expect(t72.approvedSecuringHardwareIds, contains('att-iron-spur'));
      expect(raw.firstWhere((e) => e['id'] == 'veh-t72')['securingReferenceId'],
          'para-31');
    });

    test('a vehicle the handbook never named carries no named hardware', () {
      // The T-90S is in the transport table with real dimensions and is in no
      // Annex 14 table at all, so no spur and no chock-boot may be attached to
      // it and the app reports its securing method unconfirmed.
      final t90 = vehicles.firstWhere((v) => v.id == 'veh-t90s');
      expect(t90.ironSpurType, isNull);
      expect(t90.ironChockBootType, isNull);
    });
  });

  group('the figures themselves', () {
    test('dimensions are centimetres, not the millimetres the table states', () {
      // The import divides by ten. A slip there would put every vehicle in the
      // catalogue out by a factor of ten and nothing else would notice: the
      // scene would still draw, the budget would still compute, and every
      // answer would be wrong. No vehicle in this table is shorter than a
      // metre or longer than twenty.
      for (final v in vehicles) {
        for (final (name, field) in [
          ('length', v.lengthCm),
          ('width', v.widthCm),
          ('height', v.heightCm),
        ]) {
          if (!field.isAvailable) continue;
          expect(field.numericValue!, greaterThan(40),
              reason: '${v.id} $name looks like metres');
          expect(field.numericValue!, lessThan(2000),
              reason: '${v.id} $name looks like millimetres');
        }
      }
    });

    test('a weight the table gives as a range is not collapsed to a number', () {
      // One row reads "10,7–11,4 t". Picking either end, or the middle, would
      // be this project stating a figure nobody stated.
      final ranged = vehicles.firstWhere((v) => v.handbookDesignation.startsWith('BAZ-5937'));
      expect(ranged.weightT.isAvailable, isFalse);
      expect(ranged.weightT.display(), contains('10,7'));
    });

    test('a vehicle the table leaves blank has no invented figures', () {
      final blank = vehicles.firstWhere((v) => v.handbookDesignation == 'TRM-A');
      expect(blank.lengthCm.isAvailable, isFalse);
      expect(blank.widthCm.isAvailable, isFalse);
      expect(blank.heightCm.isAvailable, isFalse);
      expect(blank.weightT.isAvailable, isFalse);
    });

    test('every vehicle has Turkmen text of its own', () {
      final tk = (_readJson('assets/data/localization/vehicles_tk.json')['vehicles'] as List)
          .cast<Map<String, dynamic>>()
          .map((e) => e['id'] as String)
          .toSet();
      for (final v in vehicles) {
        expect(tk, contains(v.id), reason: '${v.id} has no Turkmen entry');
      }
    });

    test('no two records share an id', () {
      final ids = vehicles.map((v) => v.id).toList();
      expect(ids.toSet().length, ids.length);
    });
  });

  group('catalogue coverage', () {
    test('the catalogue carries both running gears, so both rule sets are reachable', () {
      // Plates 05 and 06 — wheeled chock count, lateral gap, three-axle
      // doubling, KGUUB-1K/2K — were dead code while every vehicle was tracked.
      expect(vehicles.where((v) => v.category == VehicleCategory.wheeled), isNotEmpty);
      expect(vehicles.where((v) => v.category == VehicleCategory.tracked), isNotEmpty);
    });

    test('every vehicle is assigned the class hardware for its running gear', () {
      // Not a per-model assignment and not invented: plate 05 dimensions the
      // wooden stop blocks and wire lashings for a wheeled vehicle on a
      // flatcar, plate 02 does the same for a tracked one, and both are
      // written for the class rather than for a named machine.
      for (final v in vehicles) {
        expect(v.approvedSecuringHardwareIds, contains('att-wood-chock'), reason: v.id);
        expect(v.approvedSecuringHardwareIds, contains('att-wire-lashing'), reason: v.id);
      }
    });

    test('the vehicles carrying a 3-D model file are still in the catalogue', () {
      // The model files are keyed by vehicle id. A rebuild that renamed one
      // would leave the mesh orphaned and the vehicle drawn from its dimensions
      // instead, silently.
      final ids = vehicles.map((v) => v.id).toSet();
      final models = (_readJson('assets/data/vehicle_models.json')['models'] as List)
          .cast<Map<String, dynamic>>();
      final orphans = models
          .map((m) => m['vehicleId'] as String)
          .where((id) => !ids.contains(id))
          .toSet();
      expect(orphans, isEmpty,
          reason: 'a model file points at a vehicle the catalogue no longer has');
    });
  });
}
