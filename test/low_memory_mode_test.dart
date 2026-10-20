import 'package:test/test.dart';

import 'package:railsim/data/repositories/admin_catalog.dart';
import 'package:railsim/data/repositories/system_memory.dart';

void main() {
  test('the setting round-trips, and absent means "nobody chose"', () {
    expect(AdminCatalog.empty.lowMemory, isNull);
    expect(AdminCatalog.fromJson(const {}).lowMemory, isNull);
    // Absent from the file rather than written as null, so an older file and a
    // new one mean the same thing.
    expect(AdminCatalog.empty.toJson().containsKey('lowMemory'), isFalse);

    for (final value in [true, false]) {
      final saved = AdminCatalog.empty.withLowMemory(value);
      expect(AdminCatalog.fromJson(saved.toJson()).lowMemory, value);
    }
  });

  test('turning it on keeps everything else the instructor added', () {
    const full = AdminCatalog(
      vehicleRows: [
        {'id': 'admin-1', 'handbookDesignation': 'X', 'referenceId': 'r'}
      ],
      platformRows: [
        {'id': 'admin-w', 'name': 'W', 'referenceId': 'r'}
      ],
      photos: {
        'admin-1': {'front': '/tmp/a.jpg'}
      },
    );
    final after = AdminCatalog.fromJson(full.withLowMemory(true).toJson());
    expect(after.lowMemory, isTrue);
    expect(after.vehicleRows, hasLength(1));
    expect(after.platformRows, hasLength(1));
    expect(after.photos['admin-1']!['front'], '/tmp/a.jpg');
  });

  test('the threshold sits above 2 GB, which is the case it exists for', () {
    // A 2 GB machine has roughly 1 GB after Windows, and the program needs
    // about 790 MB with one tank's mesh loaded.
    expect(kLowMemoryThresholdMb, greaterThan(2048));
  });

  test('this machine reports a plausible amount of memory', () async {
    final mb = await totalSystemMemoryMb();
    // Linux reads /proc/meminfo, so this must answer here.
    expect(mb, isNotNull);
    expect(mb!, greaterThan(512));
    expect(mb, lessThan(1024 * 1024));
  });
}
