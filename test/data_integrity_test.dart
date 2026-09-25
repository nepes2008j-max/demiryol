import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Guards the shape of the shipped data.
///
/// Every one of these failed at some point on real data: nine citations
/// pointed at paragraphs that had no entry, so a trainee tapping them got a
/// raw id and no text, and twenty-two entities shipped with no Turkmen at all,
/// which shows as English inside an interface that is otherwise entirely in
/// Turkmen. Both are the kind of defect that is invisible in code review and
/// obvious in a test.
Map<String, dynamic> _read(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

Iterable<Map<String, dynamic>> _list(Map<String, dynamic> json, String key) =>
    (json[key] as List).cast<Map<String, dynamic>>();

void main() {
  final references = _read('assets/data/references.json');
  final referenceIds = _list(references, 'references').map((r) => r['id'] as String).toSet();

  final sources = <String, String>{
    'assets/data/vehicles.json': 'vehicles',
    'assets/data/platforms.json': 'platforms',
    'assets/data/attachments.json': 'attachmentTypes',
    'assets/data/photos.json': 'photos',
    'assets/data/principles.json': 'principles',
  };

  group('citations', () {
    test('every referenceId resolves to an entry in references.json', () {
      final dangling = <String>[];
      for (final entry in sources.entries) {
        for (final item in _list(_read(entry.key), entry.value)) {
          for (final key in ['referenceId', 'handbookReferenceId']) {
            final id = item[key] as String?;
            if (id != null && !referenceIds.contains(id)) {
              dangling.add('${entry.key}: ${item['id']} -> $id');
            }
          }
        }
      }
      final rules = _read('assets/data/rules.json');
      for (final rule in _list(rules, 'rules')) {
        final id = rule['referenceId'] as String?;
        if (id != null && !referenceIds.contains(id)) {
          dangling.add('rules.json: ${rule['id']} -> $id');
        }
        for (final clearance in (rule['clearances'] as List?) ?? const []) {
          final cid = (clearance as Map<String, dynamic>)['referenceId'] as String?;
          if (cid != null && !referenceIds.contains(cid)) {
            dangling.add('rules.json: ${rule['id']} clearance -> $cid');
          }
        }
      }
      for (final method in _list(rules, 'sixApprovedTrackedMethods')) {
        final id = method['referenceId'] as String?;
        if (id != null && !referenceIds.contains(id)) {
          dangling.add('rules.json: method ${method['method']} -> $id');
        }
      }
      expect(dangling, isEmpty,
          reason: 'these citations would render as a raw id with no text');
    });

    test('every reference names a section that exists', () {
      final sectionIds = <String>{
        for (final chapter in _list(references, 'chapters'))
          for (final section in (chapter['sections'] as List?) ?? const [])
            (section as Map<String, dynamic>)['id'] as String,
      };
      for (final reference in _list(references, 'references')) {
        final sectionId = reference['sectionId'] as String?;
        if (sectionId != null) {
          expect(sectionIds, contains(sectionId), reason: reference['id'] as String);
        }
      }
    });

    test('hardware a vehicle approves exists in attachments.json', () {
      final hardwareIds = _list(_read('assets/data/attachments.json'), 'attachmentTypes')
          .map((a) => a['id'] as String)
          .toSet();
      for (final vehicle in _list(_read('assets/data/vehicles.json'), 'vehicles')) {
        for (final id in (vehicle['approvedSecuringHardware'] as List?) ?? const []) {
          expect(hardwareIds, contains(id), reason: vehicle['id'] as String);
        }
      }
    });
  });

  group('Turkmen coverage', () {
    // The interface is entirely in Turkmen; an entity with no entry here falls
    // back to its English text in front of the trainee.
    final pairs = <({String source, String localization, String key})>[
      (source: 'assets/data/vehicles.json',
          localization: 'assets/data/localization/vehicles_tk.json', key: 'vehicles'),
      (source: 'assets/data/platforms.json',
          localization: 'assets/data/localization/platforms_tk.json', key: 'platforms'),
      (source: 'assets/data/attachments.json',
          localization: 'assets/data/localization/attachments_tk.json',
          key: 'attachmentTypes'),
      (source: 'assets/data/principles.json',
          localization: 'assets/data/localization/principles_tk.json', key: 'principles'),
      (source: 'assets/data/references.json',
          localization: 'assets/data/localization/references_tk.json', key: 'references'),
      (source: 'assets/data/photos.json',
          localization: 'assets/data/localization/photos_tk.json', key: 'photos'),
      (source: 'assets/data/rules.json',
          localization: 'assets/data/localization/rules_tk.json', key: 'rules'),
    ];

    for (final pair in pairs) {
      test('every ${pair.key} entry has Turkmen text', () {
        final sourceIds =
            _list(_read(pair.source), pair.key).map((e) => e['id'] as String).toSet();
        final translatedIds = _list(_read(pair.localization), pair.key)
            .map((e) => e['id'] as String)
            .toSet();
        expect(sourceIds.difference(translatedIds), isEmpty,
            reason: 'untranslated ${pair.key} would show English in the interface');
      });

      test('no ${pair.key} translation is left behind for a deleted entry', () {
        final sourceIds =
            _list(_read(pair.source), pair.key).map((e) => e['id'] as String).toSet();
        final translatedIds = _list(_read(pair.localization), pair.key)
            .map((e) => e['id'] as String)
            .toSet();
        expect(translatedIds.difference(sourceIds), isEmpty);
      });
    }
  });
}
