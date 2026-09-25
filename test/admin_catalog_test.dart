import 'package:test/test.dart';

import 'package:railsim/data/models/vehicle.dart';
import 'package:railsim/data/repositories/admin_catalog.dart';
import 'package:railsim/domain/models/securing_placement.dart';

void main() {
  test('an added vehicle round-trips and parses as a real Vehicle', () {
    final row = <String, dynamic>{
      'id': 'admin-1',
      'handbookDesignation': 'BTR-82A',
      'category': 'wheeled',
      'lengthCm': 768,
      'weightT': 15.4,
      'axleCount': 4,
      'referenceId': 'doc-transport-characteristics',
    };
    final saved = AdminCatalog(vehicleRows: [row], photos: const {
      'admin-1': {'front': '/tmp/f.jpg'}
    });

    final back = AdminCatalog.fromJson(saved.toJson());
    expect(back.vehicleRows, hasLength(1));
    expect(back.photos['admin-1']!['front'], '/tmp/f.jpg');

    final vehicle = back.vehicles.single;
    expect(vehicle.handbookDesignation, 'BTR-82A');
    expect(vehicle.category, VehicleCategory.wheeled);
    expect(vehicle.weightT.asDouble, 15.4);
  });

  test('an empty store is empty, not an error', () {
    expect(AdminCatalog.fromJson(const {}).isEmpty, isTrue);
    expect(AdminCatalog.empty.vehicles, isEmpty);
  });

  test('a gear photograph stores under its own key and round-trips', () {
    final saved = AdminCatalog(photos: {
      gearPhotoKey(SecuringPieceKind.ironSpur): {'figure': '/tmp/spur.jpg'},
    });
    final back = AdminCatalog.fromJson(saved.toJson());
    expect(back.photos[gearPhotoKey(SecuringPieceKind.ironSpur)]!['figure'],
        '/tmp/spur.jpg');
    // A gear key cannot collide with a vehicle id.
    expect(gearPhotoKey(SecuringPieceKind.ironSpur), startsWith('gear:'));
    // And a photograph on its own adds no catalogue row.
    expect(back.isEmpty, isTrue);
  });
}
