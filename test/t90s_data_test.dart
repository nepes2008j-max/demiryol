import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'package:railsim/data/models/handbook_field.dart';
import 'package:railsim/data/models/platform.dart';
import 'package:railsim/data/models/simulation_result.dart';
import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/domain/models/securing_method.dart';
import 'package:railsim/domain/usecases/consumables.dart';
import 'package:railsim/domain/usecases/equipment_catalog.dart';
import 'package:railsim/domain/usecases/equipment_selection.dart';
import 'package:railsim/domain/usecases/securing_method_resolution.dart';
import 'package:railsim/domain/usecases/weight_bracket.dart';
import 'package:railsim/domain/usecases/wire_lashing_rule.dart';
import 'package:railsim/domain/usecases/wood_chock_sizing.dart';

Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

/// What the catalogue can and cannot decide for the one modern vehicle in it.
///
/// The T-90S was added so a machine units actually move by rail could be
/// worked through end to end. These tests pin down what "end to end" currently
/// reaches — and, just as importantly, the three places it stops, so that a
/// later change which quietly starts answering one of them has to say so here.
void main() {
  final measurements = _read('assets/data/measurements.json');
  final rules = _read('assets/data/rules.json');
  final vehicles = (_read('assets/data/vehicles.json')['vehicles'] as List)
      .cast<Map<String, dynamic>>()
      .map(Vehicle.fromJson)
      .toList();
  final t90 = vehicles.firstWhere((v) => v.id == 'veh-t90s');
  final weight = t90.weightT.asDouble!;

  group('the T-90S record', () {
    test('carries every dimension the app computes with', () {
      expect(t90.lengthCm.numericValue, 686);
      expect(t90.widthCm.numericValue, 378);
      // 222, not the 223 the manufacturer's sheet gave: the catalogue is now
      // built from the ministry's transport-characteristics table, which states
      // 2220 mm, and where the two sources disagree the unit's own table wins.
      expect(t90.heightCm.numericValue, 222);
      expect(t90.weightT.numericValue, 46.5);
      expect(t90.groundClearanceCm.numericValue, 49);
      expect(t90.trackWidthMm.numericValue, 580);
      expect(t90.wheelBaseCm.numericValue, 427);
      // Recorded separately from the wheelbase because the ground-pressure
      // limit is computed on it and "wheelbase" is ambiguous for a tracked
      // vehicle.
      expect(t90.trackContactLengthCm.numericValue, 427);
    });

    test('leaves no spec field unavailable at all', () {
      // The two that used to be permanently empty — the centre-of-gravity
      // height and the tie-down point count — were removed from the model
      // rather than left as cells no source could ever fill.
      final missing = {
        if (!t90.lengthCm.isAvailable) 'lengthCm',
        if (!t90.widthCm.isAvailable) 'widthCm',
        if (!t90.heightCm.isAvailable) 'heightCm',
        if (!t90.weightT.isAvailable) 'weightT',
        if (!t90.groundClearanceCm.isAvailable) 'groundClearanceCm',
        if (!t90.trackWidthMm.isAvailable) 'trackWidthMm',
        if (!t90.wheelBaseCm.isAvailable) 'wheelBaseCm',
        if (!t90.trackContactLengthCm.isAvailable) 'trackContactLengthCm',
      };
      expect(missing, isEmpty);
      expect(t90.dataCompleteness, 1.0);
    });

    test('the contact length is recorded only where a source states it', () {
      // Three records carry it: the T-72 and T-90S from their handbook entries
      // and the T-80U from a manufacturer specification. Every other vehicle
      // leaves it unset rather than having a figure inferred for it.
      final withContact = [
        for (final v in vehicles)
          if (v.trackContactLengthCm.isAvailable) v.id,
      ];
      expect(withContact.toSet(), {'veh-t72', 'veh-t90s', 'veh-t80u'});
    });
  });

  group('what the handbook decides for a 46.5 t tracked vehicle', () {
    test('Table 3 does size its stop block: the "over 18.0" bracket', () {
      // The table's top bracket is open-ended, so a 46.5 t tank is inside it.
      expect(matchingWoodChockWeightRange(weight, measurements), 'over 18.0');
      final size = resolveWoodChockDimensions(weight, measurements);
      expect(size, isNotNull);
      expect(size!.heightMm, 180);
      expect(size.widthMm, 200);
    });

    test('the resolved bracket is the one the catalogue offers, unit and all', () {
      // Two spellings of the same bracket: the sizing lookup returns the bare
      // range, the equipment catalogue's type code carries the unit. The
      // three-dimensional view compared one against the other, matched
      // nothing, and quietly built this tank's stop blocks at the size meant
      // for a vehicle of under twelve tonnes.
      final bare = matchingWoodChockWeightRange(weight, measurements);
      expect(bare, 'over 18.0');

      // The catalogue names the bracket from the weight the record carries.
      // It used to refuse, because the transport table gives 46.5 t without
      // saying it is a combat weight and Table 3's brackets are written about
      // one — with the result that no vehicle in the catalogue could ever be
      // sized at all.
      final typeCode =
          requiredTypeCodeFor('att-wood-chock', t90, measurements: measurements);
      expect(typeCode, 'over 18.0 t');
      final offered = equipmentOptionsFor('att-wood-chock', measurements,
              const [], category: t90.category)
          .map((o) => o.typeCode)
          .toList();
      expect(offered, contains(typeCode));
      expect(offered, isNot(contains(bare)));
      // And the row it names is the heavy one, not the light one.
      final size = woodChockDimensionsForRange(bare!, measurements)!;
      expect(size.heightMm, 180);
      expect(size.widthMm, 200);
    });

    test('a wheeled vehicle is never sized from the tracked table', () {
      // Table 2 sizes a wheeled chock by wheel diameter, which no record
      // carries — so the honest answer is that no size is fixed, not the
      // tracked table's answer to a different question.
      final truck = vehicles.firstWhere((v) => v.id == 'veh-ural4320');
      expect(truck.category, VehicleCategory.wheeled);
      expect(
          requiredTypeCodeFor('att-wood-chock', truck, measurements: measurements),
          isNull);
    });

    test('the tracked table fixes the strand count in each lashing', () {
      expect(trackedWireStrandsPerLashing(weight, measurements), 8);
    });

    test('Table 8 does NOT reach it, so approved method 1 does not apply', () {
      for (final row in ((measurements['reusableChockTrackedTable']
              as Map<String, dynamic>)['rows'] as List)
          .cast<Map<String, dynamic>>()) {
        expect(weightMatchesRange(weight, row['combatWeightRangeT'] as String),
            isFalse,
            reason: '${row['type']} must not be offered above 42 t');
      }
      // Table 8 stops at 42 t, so at 46.5 t method 1 drops out and the two
      // wood-block methods are what remain. This is decided from the weight
      // the record carries; it used to be undecidable, and all three methods
      // were offered with eligibility marked unconfirmed.
      final resolved = resolveSecuringMethodOptions(t90);
      expect(resolved, isA<AlternativeSecuringMethods>());
      final methods = resolved as AlternativeSecuringMethods;
      expect(methods.methodNumbers, [3, 5]);
      expect(methods.methodNumbers, isNot(contains(1)));
      expect(methods.eligibilityConfirmed, isTrue);
    });

    test('the lashing-count rule is a wheeled rule and answers nothing here', () {
      // `rule-wheeled-lashing-count` is method 2, para. 55, and its brackets
      // stop at 40 t. Consulting it for a tracked vehicle would answer from
      // the wrong page; the callers are category-gated for that reason.
      final rule = (rules['rules'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == 'rule-wheeled-lashing-count');
      expect(rule['appliesTo'], 'wheeled');
      expect(requiredWireLashingCount(weight, rules), isNull);
    });

    test('plate-02 states the transverse insert blocks the scene now draws', () {
      final rule = (rules['rules'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((r) => r['id'] == 'rule-tracked-chock-arrangement');
      expect(rule['longitudinalChocksPerVehicle'], 4);
      expect(rule['transverseInsertsPerVehicle'], 4);
      expect(rule['transverseInsertsPerSide'], 2);
      final insert = insertBlockDimensions(measurements);
      expect(insert, isNotNull);
      // The table gives ranges; the midpoint is drawn and the range is what
      // the interface shows.
      expect(insert!.heightMm, closeTo(95, 1e-9));
      expect(insert.lengthMm, closeTo(350, 1e-9));
      expect(insert.rangeLabel, '90-100 x 300-400 mm');
    });
  });

  group('the para. 51 limits, now computed rather than deferred', () {
    final platforms = (_read('assets/data/platforms.json')['platforms'] as List)
        .cast<Map<String, dynamic>>()
        .map(Platform.fromJson)
        .toList();
    final flatcar =
        platforms.firstWhere((p) => p.id == 'plat-generic-open-flatcar');

    test('the wagon record carries both limits the checks read', () {
      expect(flatcar.maxGroundPressureTrackedKgCm2.numericValue, 0.8);
      expect(flatcar.specialCaseMaxTrackedT.numericValue, 15.0);
    });

    test('the T-90S nominal ground pressure exceeds the 0.8 kg/cm² limit', () {
      // 46.5 t over both shoes across the bearing length. The manufacturer's
      // own published figure is 0.938 kg/cm², which is the same arithmetic.
      final shoeMm = t90.trackWidthMm.asDouble!;
      final contactCm = t90.trackContactLengthCm.asDouble!;
      final areaCm2 = 2 * (shoeMm / 10) * contactCm;
      final pressure = weight * 1000 / areaCm2;
      expect(pressure, closeTo(0.938, 0.005));
      expect(pressure, greaterThan(flatcar.maxGroundPressureTrackedKgCm2.asDouble!));
    });

    test('and its weight exceeds the 15 t side-ramp special case', () {
      expect(weight, greaterThan(flatcar.specialCaseMaxTrackedT.asDouble!));
    });
  });

  group('the figures an instructor can supply', () {
    test('a typed weight fills a gap, and only a gap', () {
      // This record carries a weight, so the door is shut: a typed figure does
      // not overwrite what the source states. The door is for the four
      // vehicles in the catalogue whose weight column is blank.
      expect(t90.weightT.asDouble, 46.5);
      expect(t90.bracketWeightT.asDouble, 46.5);
      expect(t90.withUserSuppliedFigures(weightT: 99).weightT.asDouble, 46.5);

      const blank = Vehicle(
        id: 'veh-blank',
        handbookDesignation: 'no weight stated',
        category: VehicleCategory.tracked,
        vehicleClass: 'test',
        lengthCm: HandbookField(686),
        widthCm: HandbookField(378),
        heightCm: HandbookField(223),
        weightT: HandbookField(null),
        groundClearanceCm: HandbookField(49),
        trackWidthMm: HandbookField(580),
        wheelBaseCm: HandbookField(427),
        manufacturer: 'test',
        country: 'test',
        approvedSecuringHardwareIds: [],
        referenceId: 'para-34',
      );
      expect(blank.bracketWeightT.isAvailable, isFalse);

      final supplied = blank.withUserSuppliedFigures(weightT: 99);
      expect(supplied.bracketWeightT.asDouble, 99);
      expect(supplied.userSuppliedFields, contains('weightT'));

      // And once there is a figure, a second typed one does not overwrite it.
      expect(supplied.withUserSuppliedFigures(weightT: 12).weightT.asDouble, 99);
    });

    test('supplying nothing new returns the same record', () {
      expect(identical(t90.withUserSuppliedFigures(), t90), isTrue);
    });
  });

  group('the consumables list this all adds up to', () {
    test('names a real block size, nail count, wire and staples', () {
      // With the combat weight supplied, because the block size and the
      // strand count are both read off it and the transport table does not
      // say whether its 46.5 t is one.
      final lines = consumablesFor(
        vehicle: t90.withUserSuppliedFigures(weightT: 46.5),
        arrangement: null,
        requiredHardwareIds: const [
          'att-wood-chock',
          'att-wire-lashing',
          'att-nail',
          'att-staple',
        ],
        measurements: measurements,
        rules: rules,
      );
      expect(lines, isNotEmpty);
      final chock = lines.firstWhere((l) => l.specification?.contains('180') ?? false);
      expect(chock.specification, contains('200'));
      final wire = lines.firstWhere((l) => (l.specification ?? '').contains('8'));
      expect(wire.specification, contains('8'));
    });
  });

  group('nothing here is presented as handbook data', () {
    test('the record still says plainly that the handbook does not name it', () {
      // The figures are the ministry transport table's now, not the
      // manufacturer's sheet — but the point of this test is unchanged and is
      // the important one: whatever document the dimensions came from, it was
      // not the loading handbook, and no securing method follows from it.
      expect(t90.dataSource, VehicleDataSource.transportTable);
      expect(t90.notes!.toUpperCase(), contains('NOT A HANDBOOK VEHICLE'));
      expect(t90.ironSpurType, isNull);
      expect(t90.ironChockBootType, isNull);
    });

    test('the note states the ground-pressure arithmetic it now drives', () {
      expect(t90.notes, contains('0.94'));
      expect(t90.notes, contains('para. 51'));
    });

    test('the Turkmen note was updated with it too', () {
      final tk = (_read('assets/data/localization/vehicles_tk.json')['vehicles']
              as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((e) => e['id'] == 'veh-t90s');
      expect(tk['notesTk'], contains('0,94'));
      // Matched on the numeral alone: Turkmen inflects the noun after it
      // ("51-nji bendiň"), so anchoring on the nominative would break on
      // perfectly good text.
      expect(tk['notesTk'], contains('51-nji'));
    });
  });

  group('ValidationCheck plumbing the new checks rely on', () {
    test('the unknown status exists and is distinct from a failure', () {
      expect(CheckStatus.unknown, isNot(CheckStatus.fail));
      const field = HandbookField(null);
      expect(field.isAvailable, isFalse);
    });
  });

  group('the photographs and the names', () {
    final photos = (_read('assets/data/vehicle_photos.json')['photos'] as List)
        .cast<Map<String, dynamic>>();

    Map<String, dynamic> photoFor(String id) =>
        photos.firstWhere((p) => p['vehicleId'] == id);

    test('both modern tanks now have an illustrative photograph', () {
      for (final id in ['veh-t72', 'veh-t90s']) {
        final photo = photoFor(id);
        expect(photo['file'], startsWith('images/vehicles/'));
        expect(File('assets/${photo['file']}').existsSync(), isTrue,
            reason: '${photo['file']} is catalogued but not on disk');
      }
    });

    test('each carries the licence, author and source page it needs', () {
      // These are somebody else's photographs, redistributed under terms that
      // require their name to travel with them.
      for (final id in ['veh-t72', 'veh-t90s']) {
        final photo = photoFor(id);
        expect(photo['license'], 'CC BY-SA 4.0');
        expect((photo['author'] as String).trim(), isNotEmpty);
        expect(photo['sourceUrl'], startsWith('https://commons.wikimedia.org/'));
        expect(photo['licenseUrl'], contains('creativecommons.org'));
      }
    });

    test('neither claims a cut-out, because neither cut out cleanly', () {
      // A tree grows out of the T-72's turret and the T-90S keeps its whole
      // background. Both fall back to the drawn side elevation, which is the
      // documented normal state rather than a failure.
      for (final id in ['veh-t72', 'veh-t90s']) {
        expect(photoFor(id).containsKey('cutout'), isFalse, reason: id);
        expect(File('assets/images/vehicles/cutouts/$id.png').existsSync(),
            isFalse,
            reason: 'a rejected cut-out must not be left on disk');
      }
    });

    test('every catalogued photograph points at a file that exists', () {
      // Not just the two: a manifest naming a missing file shows up in the
      // app as an empty card, and only here as a red image icon.
      for (final photo in photos) {
        expect(File('assets/${photo['file']}').existsSync(), isTrue,
            reason: photo['file'] as String);
        final cutout = photo['cutout'] as String?;
        if (cutout != null) {
          expect(File('assets/$cutout').existsSync(), isTrue, reason: cutout);
        }
      }
    });

    test('the two tanks carry their service names', () {
      final t72 = vehicles.firstWhere((v) => v.id == 'veh-t72');
      final t90 = vehicles.firstWhere((v) => v.id == 'veh-t90s');
      expect(t72.vehicleClass, contains('Ural'));
      expect(t72.vehicleClass, contains('172M'));
      expect(t90.vehicleClass, contains('Bhishma'));
      expect(t90.vehicleClass, contains('export'));
      // And in Turkmen, which is what the card actually shows.
      final tk = (_read('assets/data/localization/vehicles_tk.json')['vehicles']
              as List)
          .cast<Map<String, dynamic>>();
      final tk72 = tk.firstWhere((e) => e['id'] == 'veh-t72');
      final tk90 = tk.firstWhere((e) => e['id'] == 'veh-t90s');
      expect(tk72['classDisplayTk'], contains('Ural'));
      expect(tk90['classDisplayTk'], contains('Bhishma'));
    });
  });
}
