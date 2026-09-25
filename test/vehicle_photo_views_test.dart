import 'package:test/test.dart';

import 'package:railsim/data/models/vehicle_photo.dart';

void main() {
  test('extra views round-trip and resolve to asset keys', () {
    final photo = VehiclePhoto.fromJson(const {
      'vehicleId': 'veh-t72',
      'file': 'images/vehicles/veh-t72.jpg',
      'views': {
        'front': 'images/vehicles/veh-t72-front.jpg',
        'rear': 'images/vehicles/veh-t72-rear.jpg',
      },
      'license': 'CC BY-SA 4.0',
      'author': 'Someone',
    });
    expect(photo.fullViewPath('front'), 'assets/images/vehicles/veh-t72-front.jpg');
    expect(photo.fullViewPath('rear'), 'assets/images/vehicles/veh-t72-rear.jpg');
    // An angle the fetcher could not find is null, not a broken path.
    expect(photo.fullViewPath('side'), isNull);
  });

  test('an entry with no views is still valid and unchanged in shape', () {
    final photo = VehiclePhoto.fromJson(const {
      'vehicleId': 'veh-2s1',
      'file': 'images/vehicles/veh-2s1.jpg',
      'license': 'CC BY-SA 4.0',
      'author': 'Someone',
    });
    expect(photo.views, isEmpty);
    expect(photo.fullAssetPath, 'assets/images/vehicles/veh-2s1.jpg');
    expect(photo.fullViewPath('front'), isNull);
  });
}
