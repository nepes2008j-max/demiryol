import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:railsim/data/models/vehicle_photo.dart';

/// The illustrative vehicle photographs are the only images in the app that
/// did not come out of the handbook, so they are the only ones that can go
/// wrong in ways the handbook figures cannot: a manifest entry pointing at a
/// file that was never fetched, a photograph attached to a vehicle id that
/// does not exist, or a licence that in fact forbids this use.
///
/// These tests read the real manifest and the real files on disk, because a
/// hand-written fixture would prove nothing about what actually ships.
/// Reads an asset file at group-declaration time, so the manifest can be
/// turned into cases once instead of on every test. `expect` is not usable
/// here — it throws `OutsideTestException` outside a running test — so a
/// missing file fails loudly with its own message instead.
Map<String, dynamic> _readJson(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw StateError('$path is missing — run tools/fetch_vehicle_photos.py');
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void main() {
  group('VehiclePhoto', () {
    test('parses a manifest entry', () {
      final photo = VehiclePhoto.fromJson(const {
        'vehicleId': 'veh-t34',
        'file': 'images/vehicles/veh-t34.jpg',
        'sourceTitle': 'File:T-34.jpg',
        'sourceUrl': 'https://commons.wikimedia.org/wiki/File:T-34.jpg',
        'license': 'CC BY-SA 4.0',
        'licenseUrl': 'https://creativecommons.org/licenses/by-sa/4.0',
        'author': 'A. Photographer',
      });
      expect(photo.vehicleId, 'veh-t34');
      expect(photo.fullAssetPath, 'assets/images/vehicles/veh-t34.jpg');
      expect(photo.creditLine, 'A. Photographer · CC BY-SA 4.0');
    });

    test('credit line omits an unrecorded author instead of inventing one', () {
      const photo = VehiclePhoto(
        vehicleId: 'veh-t34',
        assetPath: 'images/vehicles/veh-t34.jpg',
        sourceTitle: '',
        sourceUrl: '',
        license: 'Public domain',
        licenseUrl: '',
        author: '   ',
      );
      expect(photo.creditLine, 'Public domain');
    });

    test('tolerates a manifest entry missing the optional metadata', () {
      final photo = VehiclePhoto.fromJson(const {
        'vehicleId': 'veh-t10',
        'file': 'images/vehicles/veh-t10.jpg',
      });
      expect(photo.license, isEmpty);
      expect(photo.creditLine, isEmpty);
    });
  });

  group('assets/data/vehicle_photos.json', () {
    final manifest = _readJson('assets/data/vehicle_photos.json');
    final entries = (manifest['photos'] as List).cast<Map<String, dynamic>>();
    final photos = entries.map(VehiclePhoto.fromJson).toList();
    final vehicleIds = ((_readJson('assets/data/vehicles.json')['vehicles'] as List)
            .cast<Map<String, dynamic>>())
        .map((v) => v['id'] as String)
        .toSet();

    test('is not empty', () {
      expect(photos, isNotEmpty);
    });

    test('every photograph names a vehicle that exists in vehicles.json', () {
      for (final photo in photos) {
        expect(vehicleIds, contains(photo.vehicleId));
      }
    });

    test('no vehicle has two photographs', () {
      final ids = photos.map((p) => p.vehicleId).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('every photograph file exists and is non-empty', () {
      for (final photo in photos) {
        final file = File('assets/${photo.assetPath}');
        expect(file.existsSync(), isTrue, reason: '${photo.assetPath} is missing');
        expect(file.lengthSync(), greaterThan(0));
      }
    });

    test('every photograph lives under images/vehicles/', () {
      for (final photo in photos) {
        expect(photo.assetPath, startsWith('images/vehicles/'));
      }
    });

    test('every photograph carries a licence and a source page for attribution', () {
      for (final photo in photos) {
        expect(photo.license.trim(), isNotEmpty, reason: '${photo.vehicleId} has no licence');
        expect(photo.sourceUrl, startsWith('https://'),
            reason: '${photo.vehicleId} has no source page');
      }
    });

    test('no photograph carries a NonCommercial or NoDerivatives licence', () {
      final forbidden = RegExp(r'\b(nc|nd|noncommercial|noderiv|non-free|fair use)\b',
          caseSensitive: false);
      for (final photo in photos) {
        expect(forbidden.hasMatch(photo.license), isFalse,
            reason: '${photo.vehicleId}: ${photo.license}');
      }
    });

    test('every recorded cut-out is a PNG that exists on disk', () {
      // A cut-out is optional, but a recorded one must be there: the flatcar
      // scene loads it by the path in this manifest and would show an empty
      // deck if it were missing.
      for (final photo in photos.where((p) => p.hasCutout)) {
        expect(photo.cutoutPath, startsWith('images/vehicles/cutouts/'),
            reason: photo.vehicleId);
        expect(photo.cutoutPath, endsWith('.png'), reason: photo.vehicleId);
        final file = File('assets/${photo.cutoutPath}');
        expect(file.existsSync(), isTrue, reason: '${photo.cutoutPath} is missing');
        expect(file.lengthSync(), greaterThan(0));
      }
    });

    test('at least one vehicle can be shown standing on the flatcar', () {
      // If every cut-out were rejected the placement screen would silently
      // fall back to the drawn elevation for all vehicles, which is a
      // regression worth catching rather than a design choice.
      expect(photos.where((p) => p.hasCutout), isNotEmpty);
    });

    test('every cut-out the manifest names is on disk', () {
      // The direction that matters. A manifest entry pointing at a file that
      // is not there draws a broken image in front of a trainee.
      //
      // The opposite direction is no longer a defect. The catalogue is rebuilt
      // from the ministry's transport-characteristics table, which is the
      // unit's list of what it moves; a vehicle that list drops takes its
      // manifest entry with it, and its cut-out stays on disk as a reserve for
      // the day the list carries that vehicle again. Deleting the artwork
      // because a list changed would throw away work nobody can redo from the
      // app.
      for (final photo in photos.where((p) => p.hasCutout)) {
        expect(File('assets/${photo.cutoutPath}').existsSync(), isTrue,
            reason: '${photo.cutoutPath} is named by the manifest and missing');
      }
    });
  });

  group('assets/images/rolling_stock', () {
    test('the flatcar the scene is built on is present', () {
      final file = File('assets/images/rolling_stock/flatcar-side.png');
      expect(file.existsSync(), isTrue,
          reason: 'flatcar-side.png is what FlatcarScene draws the wagon from');
      expect(file.lengthSync(), greaterThan(0));
    });
  });

  group('assets/data/vehicle_photos.json cut-outs', () {
    final manifest = _readJson('assets/data/vehicle_photos.json');
    final photos = (manifest['photos'] as List)
        .cast<Map<String, dynamic>>()
        .map(VehiclePhoto.fromJson)
        .toList();

    test('no design-bureau object index gets a photograph', () {
      // "Object 429", "137" and the like each cover several different
      // vehicles, so no single photograph could honestly represent one —
      // see the header of tools/fetch_vehicle_photos.py.
      for (final photo in photos) {
        expect(photo.vehicleId, isNot(startsWith('veh-obj')));
      }
    });
  });
}
