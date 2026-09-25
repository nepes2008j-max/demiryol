import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/platform.dart';
import '../models/vehicle.dart';
import '../../domain/models/securing_placement.dart';

/// Vehicles and wagons the instructor added, stored next to the exported
/// result sheets rather than in the app bundle.
///
/// The bundled `assets/data/*.json` is read-only at runtime — it ships inside
/// the executable — so anything added on the machine has to live somewhere
/// writable. One JSON file and a folder of copied images in the application
/// documents directory is the whole mechanism; the records use the same
/// `Vehicle.fromJson` / `Platform.fromJson` the bundle does, so nothing
/// downstream can tell the difference between a handbook vehicle and one the
/// instructor typed in.
class AdminCatalog {
  /// The records exactly as the admin form built them, in the same shape
  /// `assets/data/vehicles.json` uses.
  ///
  /// Kept as raw maps rather than as parsed objects because that is what round
  /// -trips: `Vehicle` and `Platform` have `fromJson` and no `toJson`, and
  /// writing a serialiser for two large models to save a handful of records
  /// would be more code than the feature.
  final List<Map<String, dynamic>> vehicleRows;
  final List<Map<String, dynamic>> platformRows;

  /// Photographs per vehicle id: view name ("front", "side", "rear") to the
  /// absolute path of the copied image file.
  final Map<String, Map<String, String>> photos;

  const AdminCatalog({
    this.vehicleRows = const [],
    this.platformRows = const [],
    this.photos = const {},
  });

  static const empty = AdminCatalog();

  bool get isEmpty => vehicleRows.isEmpty && platformRows.isEmpty;

  List<Vehicle> get vehicles =>
      [for (final row in vehicleRows) Vehicle.fromJson(row)];

  List<Platform> get platforms =>
      [for (final row in platformRows) Platform.fromJson(row)];

  Map<String, dynamic> toJson() => {
        'vehicles': vehicleRows,
        'platforms': platformRows,
        'photos': photos,
      };

  factory AdminCatalog.fromJson(Map<String, dynamic> json) => AdminCatalog(
        vehicleRows: [
          for (final v in (json['vehicles'] as List?) ?? const [])
            (v as Map).cast<String, dynamic>(),
        ],
        platformRows: [
          for (final p in (json['platforms'] as List?) ?? const [])
            (p as Map).cast<String, dynamic>(),
        ],
        photos: {
          for (final entry
              in ((json['photos'] as Map?) ?? const {}).entries)
            entry.key as String: {
              for (final view in (entry.value as Map).entries)
                view.key as String: view.value as String,
            },
        },
      );
}

/// The key a piece of securing gear's photograph is stored under.
///
/// Gear photographs share [AdminCatalog.photos] with the vehicles rather than
/// getting a map of their own — the store is "a picture of this thing", and a
/// prefix keeps the two kinds of thing from colliding.
String gearPhotoKey(SecuringPieceKind kind) => 'gear:${kind.name}';

/// Reads and writes [AdminCatalog] on disk.
class AdminCatalogStore {
  const AdminCatalogStore();

  Future<Directory> _dir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'railsim'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  Future<File> _file() async => File(p.join((await _dir()).path, 'admin_catalog.json'));

  Future<AdminCatalog> load() async {
    try {
      final file = await _file();
      if (!file.existsSync()) return AdminCatalog.empty;
      return AdminCatalog.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (_) {
      // Empty rather than an error, for two cases that both mean "there is
      // nothing added here": a half-written or hand-edited file, and no
      // documents directory at all — which is every `flutter test` run, where
      // `path_provider` has no platform channel behind it. The catalogue
      // providers merge this into the bundle, so throwing here would take down
      // every screen that lists a vehicle.
      return AdminCatalog.empty;
    }
  }

  Future<void> save(AdminCatalog catalog) async {
    final file = await _file();
    await file.writeAsString(
        const JsonEncoder.withIndent('  ').convert(catalog.toJson()));
  }

  /// Copies [source] into the store and returns the copy's path.
  ///
  /// Copied rather than referenced, because a photograph pointed at somebody's
  /// Downloads folder disappears the first time they tidy up, and a vehicle
  /// card with a missing image is worse than one with none.
  Future<String> importPhoto(String vehicleId, String view, File source) async {
    final dir = Directory(p.join((await _dir()).path, 'photos'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    final target = File(
        p.join(dir.path, '$vehicleId-$view${p.extension(source.path)}'));
    await source.copy(target.path);
    return target.path;
  }
}
