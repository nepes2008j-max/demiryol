import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import '../models/attachment_type.dart';
import '../models/handbook_photo.dart';
import '../models/handbook_reference.dart';
import '../models/handbook_rule.dart';
import '../models/platform.dart';
import '../models/principle.dart';
import '../models/vehicle.dart';
import '../models/vehicle_model_asset.dart';
import '../models/vehicle_photo.dart';

/// Loads every handbook-derived JSON asset and exposes it as typed data.
///
/// This is the Repository-pattern boundary described in the architecture:
/// swapping to SQLite, or adding a second handbook's data files, only means
/// changing this class's load methods — nothing above it (domain/UI) needs
/// to know where the JSON came from.
///
/// Each `get*()` method also merges in the matching Turkmen localization
/// file from `assets/data/localization/*_tk.json` (see
/// docs/turkmen-content-localization-report.md), keyed by the same `id`s as
/// the English source. Loading a localization file is best-effort: if one
/// is missing or malformed, the affected entities simply fall back to their
/// English text via each model's `displayX` getters — localization can
/// never break data loading.
class HandbookRepository {
  List<Vehicle>? _vehicles;
  List<Platform>? _platforms;
  List<AttachmentType>? _attachmentTypes;
  List<Principle>? _principles;
  List<HandbookChapter>? _chapters;
  List<HandbookReference>? _references;
  List<HandbookPhoto>? _photos;
  List<HandbookRule>? _ruleEntries;
  Map<String, VehiclePhoto>? _vehiclePhotos;
  Map<String, VehicleModelAsset>? _vehicleModels;
  Map<String, dynamic>? _rules;
  Map<String, dynamic>? _measurements;

  Future<Map<String, dynamic>> _loadJson(String assetKey) async {
    final raw = await rootBundle.loadString(assetKey);
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>?> _tryLoadJson(String assetKey) async {
    try {
      return await _loadJson(assetKey);
    } catch (_) {
      return null;
    }
  }

  /// Loads a `*_tk.json` localization file and indexes its `listKey` array
  /// by `id`, so callers can look up `tkById[englishEntity.id]`.
  Future<Map<String, Map<String, dynamic>>> _loadTkById(
    String assetKey,
    String listKey,
  ) async {
    final json = await _tryLoadJson(assetKey);
    final list = (json?[listKey] as List?) ?? const [];
    final byId = <String, Map<String, dynamic>>{};
    for (final entry in list) {
      final entryMap = entry as Map<String, dynamic>;
      final id = entryMap['id'] as String?;
      if (id != null) byId[id] = entryMap;
    }
    return byId;
  }

  Future<List<Vehicle>> getVehicles() async {
    if (_vehicles != null) return _vehicles!;
    final json = await _loadJson('assets/data/vehicles.json');
    final tk = await _loadTkById('assets/data/localization/vehicles_tk.json', 'vehicles');
    _vehicles = (json['vehicles'] as List)
        .map((e) => Vehicle.fromJson(e as Map<String, dynamic>))
        .map((v) => v.withTurkmen(tk[v.id]))
        .toList();
    return _vehicles!;
  }

  Future<List<Platform>> getPlatforms() async {
    if (_platforms != null) return _platforms!;
    final json = await _loadJson('assets/data/platforms.json');
    final tk = await _loadTkById('assets/data/localization/platforms_tk.json', 'platforms');
    _platforms = (json['platforms'] as List)
        .map((e) => Platform.fromJson(e as Map<String, dynamic>))
        .map((p) => p.withTurkmen(tk[p.id]))
        .toList();
    return _platforms!;
  }

  Future<List<AttachmentType>> getAttachmentTypes() async {
    if (_attachmentTypes != null) return _attachmentTypes!;
    final json = await _loadJson('assets/data/attachments.json');
    final tk =
        await _loadTkById('assets/data/localization/attachments_tk.json', 'attachmentTypes');
    _attachmentTypes = (json['attachmentTypes'] as List)
        .map((e) => AttachmentType.fromJson(e as Map<String, dynamic>))
        .map((a) => a.withTurkmen(tk[a.id]))
        .toList();
    return _attachmentTypes!;
  }

  Future<List<Principle>> getPrinciples() async {
    if (_principles != null) return _principles!;
    final json = await _loadJson('assets/data/principles.json');
    final tk = await _loadTkById('assets/data/localization/principles_tk.json', 'principles');
    _principles = (json['principles'] as List)
        .map((e) => Principle.fromJson(e as Map<String, dynamic>))
        .map((p) => p.withTurkmen(tk[p.id]))
        .toList();
    return _principles!;
  }

  Future<List<HandbookReference>> getReferences() async {
    if (_references != null) return _references!;
    final json = await _loadJson('assets/data/references.json');
    final tk = await _loadTkById('assets/data/localization/references_tk.json', 'references');
    _chapters = (json['chapters'] as List? ?? [])
        .map((e) => HandbookChapter.fromJson(e as Map<String, dynamic>))
        .toList();
    _references = (json['references'] as List)
        .map((e) => HandbookReference.fromJson(e as Map<String, dynamic>))
        .map((r) => r.withTurkmen(tk[r.id]))
        .toList();
    return _references!;
  }

  Future<List<HandbookChapter>> getChapters() async {
    if (_chapters == null) await getReferences();
    return _chapters!;
  }

  Future<HandbookReference?> getReferenceById(String id) async {
    final refs = await getReferences();
    for (final r in refs) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<List<HandbookPhoto>> getPhotos() async {
    if (_photos != null) return _photos!;
    final json = await _loadJson('assets/data/photos.json');
    final tk = await _loadTkById('assets/data/localization/photos_tk.json', 'photos');
    _photos = (json['photos'] as List)
        .map((e) => HandbookPhoto.fromJson(e as Map<String, dynamic>))
        .map((p) => p.withTurkmen(tk[p.id]))
        .toList();
    return _photos!;
  }

  /// Illustrative vehicle photographs, indexed by vehicle id.
  ///
  /// Loaded best-effort, exactly like a localization file: the manifest is
  /// produced by `tools/fetch_vehicle_photos.py`, which needs network access
  /// and skips any vehicle without a freely-licensed candidate, so a missing
  /// or partial file is a normal state — not an error. A vehicle with no
  /// entry simply shows no photograph, which is what the app did before these
  /// existed at all.
  ///
  /// These are NOT handbook figures; see [VehiclePhoto].
  Future<Map<String, VehiclePhoto>> getVehiclePhotos() async {
    if (_vehiclePhotos != null) return _vehiclePhotos!;
    final json = await _tryLoadJson('assets/data/vehicle_photos.json');
    final list = (json?['photos'] as List?) ?? const [];
    _vehiclePhotos = {
      for (final entry in list)
        (entry as Map<String, dynamic>)['vehicleId'] as String: VehiclePhoto.fromJson(entry),
    };
    return _vehiclePhotos!;
  }

  /// The bundled model files, indexed by vehicle id.
  ///
  /// A record missing its author, source or licence is dropped rather than
  /// loaded: these are other people's models, redistributed under terms that
  /// require their name to travel with them, and a missing string must not be
  /// what causes that name to go missing.
  Future<Map<String, VehicleModelAsset>> getVehicleModels() async {
    if (_vehicleModels != null) return _vehicleModels!;
    final json = await _tryLoadJson('assets/data/vehicle_models.json');
    final list = (json?['models'] as List?) ?? const [];
    _vehicleModels = {
      for (final entry in list)
        if (VehicleModelAsset.fromJson(entry as Map<String, dynamic>)
            case final model when model.isAttributed)
          model.vehicleId: model,
    };
    return _vehicleModels!;
  }

  /// The raw bytes of one model file, or null when it is not in the bundle.
  ///
  /// Bytes and not a string: a binary STL does not survive being decoded as
  /// text, and binary STL is what the sites that publish freely publish.
  /// Missing is the normal case and never an error — a vehicle with no model
  /// file is drawn from its dimensions instead.
  Future<Uint8List?> loadVehicleModelBytes(VehicleModelAsset model) async {
    try {
      final data = await rootBundle.load(model.assetKey);
      return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
    } catch (_) {
      return null;
    }
  }

  /// Raw rules.json — kept as a dynamic map (rather than a rigid model)
  /// because rule shapes vary (simple condition vs. weight-bracket lookup
  /// table vs. angle lookup table). The validation engine interprets these
  /// directly; see domain/usecases/engineering_validator.dart.
  Future<Map<String, dynamic>> getRules() async {
    if (_rules != null) return _rules!;
    _rules = await _loadJson('assets/data/rules.json');
    return _rules!;
  }

  Future<Map<String, dynamic>> getMeasurements() async {
    if (_measurements != null) return _measurements!;
    _measurements = await _loadJson('assets/data/measurements.json');
    return _measurements!;
  }

  /// Typed projection of rules.json's "rules" and "sixApprovedTrackedMethods"
  /// lists, for browsing/search. `getRules()` remains the raw-map accessor
  /// the validation engine interprets directly.
  Future<List<HandbookRule>> getRuleEntries() async {
    // Cached like every other getter here. Without it this re-read and
    // re-merged the Turkmen rules file on every call, and the securing screen
    // calls it on each rebuild.
    if (_ruleEntries != null) return _ruleEntries!;
    final raw = await getRules();
    final tkJson = await _tryLoadJson('assets/data/localization/rules_tk.json');
    final rulesTk = await _loadTkById('assets/data/localization/rules_tk.json', 'rules');
    final methodsTkByNumber = <int, Map<String, dynamic>>{
      for (final entry in (tkJson?['sixApprovedTrackedMethods'] as List?) ?? const [])
        (entry as Map<String, dynamic>)['method'] as int: entry,
    };

    final rules = ((raw['rules'] as List?) ?? [])
        .map((e) => HandbookRule.fromRuleJson(e as Map<String, dynamic>))
        .map((r) => r.withTurkmen(rulesTk[r.id]))
        .toList();
    final methods = ((raw['sixApprovedTrackedMethods'] as List?) ?? [])
        .map((e) => HandbookRule.fromMethodJson(e as Map<String, dynamic>))
        .map((m) => m.withTurkmen(methodsTkByNumber[m.methodNumber]))
        .toList();
    _ruleEntries = [...rules, ...methods];
    return _ruleEntries!;
  }
}
