import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/repositories/admin_catalog.dart';
import '../../../domain/models/securing_placement.dart';
import '../../providers/handbook_providers.dart';
import '../../widgets/common/app_surfaces.dart';
import '../../widgets/common/instrument.dart';

/// Where the instructor adds a vehicle or a wagon the handbook extract does
/// not carry, with photographs of it.
///
/// Reached by typing the admin name into the dialog that asks who is sitting
/// the attempt, rather than from a button on the menu: a trainee should not be
/// looking at a way to edit the catalogue they are about to be tested on.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(adminCatalogProvider);
    return InstrumentScaffold(
      title: AppStrings.adminTitle,
      subtitle: AppStrings.adminSubtitle,
      showRail: false,
      onBack: () => context.go('/'),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(AppStrings.errorPrefix(e))),
        data: (data) => SingleChildScrollView(
          padding: AppSpace.screen,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AddBar(
                    onVehicle: () => _addVehicle(context, ref, data),
                    onWagon: () => _addWagon(context, ref, data),
                  ),
                  const SizedBox(height: AppSpace.xl),
                  const SectionHeading(AppStrings.adminVehiclesHeading),
                  const SizedBox(height: 8),
                  if (data.vehicleRows.isEmpty)
                    const Text(AppStrings.adminNothingAdded,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppText.bodySmall))
                  else
                    for (final row in data.vehicleRows)
                      _AddedRow(
                        title: row['handbookDesignation'] as String? ?? '—',
                        subtitle: _vehicleSummary(row),
                        photos: data.photos[row['id']] ?? const {},
                        onPhotos: () =>
                            _managePhotos(context, ref, data, row['id'] as String),
                        onRemove: () => _removeVehicle(ref, data, row['id'] as String),
                      ),
                  const SizedBox(height: AppSpace.xl),
                  const SectionHeading(AppStrings.adminCatalogueHeading),
                  const SizedBox(height: 8),
                  const Text(AppStrings.adminCatalogueIntro,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppText.bodySmall)),
                  const SizedBox(height: 8),
                  _CataloguePhotos(catalog: data, onPhotos: (id) =>
                      _managePhotos(context, ref, data, id)),
                  const SizedBox(height: AppSpace.xl),
                  const SectionHeading(AppStrings.adminGearHeading),
                  const SizedBox(height: 8),
                  const Text(AppStrings.adminGearIntro,
                      style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: AppText.bodySmall)),
                  const SizedBox(height: 8),
                  for (final kind in SecuringPieceKind.values)
                    _AddedRow(
                      title: AppStrings.pieceKindName(kind).toUpperCase(),
                      subtitle: data.photos[gearPhotoKey(kind)] == null
                          ? AppStrings.adminGearNoPhoto
                          : AppStrings.adminGearHasPhoto,
                      photos: data.photos[gearPhotoKey(kind)] ?? const {},
                      onPhotos: () => _manageGearPhoto(context, ref, data, kind),
                      onRemove: () => _removeGearPhoto(ref, data, kind),
                    ),
                  const SizedBox(height: AppSpace.xl),
                  const SectionHeading(AppStrings.adminWagonsHeading),
                  const SizedBox(height: 8),
                  if (data.platformRows.isEmpty)
                    const Text(AppStrings.adminNothingAdded,
                        style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: AppText.bodySmall))
                  else
                    for (final row in data.platformRows)
                      _AddedRow(
                        title: row['name'] as String? ?? '—',
                        subtitle: _wagonSummary(row),
                        photos: const {},
                        onRemove: () => _removeWagon(ref, data, row['id'] as String),
                      ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _vehicleSummary(Map<String, dynamic> row) => [
        row['category'],
        if (row['lengthCm'] != null) '${row['lengthCm']} sm',
        if (row['weightT'] != null) '${row['weightT']} t',
      ].where((e) => e != null).join(' · ');

  static String _wagonSummary(Map<String, dynamic> row) => [
        row['kind'],
        if (row['lengthCm'] != null) '${row['lengthCm']} sm',
      ].where((e) => e != null).join(' · ');

  Future<void> _save(WidgetRef ref, AdminCatalog next) async {
    await ref.read(adminCatalogStoreProvider).save(next);
    ref.invalidate(adminCatalogProvider);
  }

  Future<void> _addVehicle(
      BuildContext context, WidgetRef ref, AdminCatalog data) async {
    final row = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _VehicleForm(),
    );
    if (row == null) return;
    await _save(
        ref,
        AdminCatalog(
          vehicleRows: [...data.vehicleRows, row],
          platformRows: data.platformRows,
          photos: data.photos,
        ));
  }

  Future<void> _addWagon(
      BuildContext context, WidgetRef ref, AdminCatalog data) async {
    final row = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const _WagonForm(),
    );
    if (row == null) return;
    await _save(
        ref,
        AdminCatalog(
          vehicleRows: data.vehicleRows,
          platformRows: [...data.platformRows, row],
          photos: data.photos,
        ));
  }

  Future<void> _removeVehicle(
          WidgetRef ref, AdminCatalog data, String id) async =>
      _save(
          ref,
          AdminCatalog(
            vehicleRows: [
              for (final r in data.vehicleRows)
                if (r['id'] != id) r,
            ],
            platformRows: data.platformRows,
            photos: {...data.photos}..remove(id),
          ));

  Future<void> _removeWagon(
          WidgetRef ref, AdminCatalog data, String id) async =>
      _save(
          ref,
          AdminCatalog(
            vehicleRows: data.vehicleRows,
            platformRows: [
              for (final r in data.platformRows)
                if (r['id'] != id) r,
            ],
            photos: data.photos,
          ));

  Future<void> _manageGearPhoto(BuildContext context, WidgetRef ref,
      AdminCatalog data, SecuringPieceKind kind) async {
    final key = gearPhotoKey(kind);
    final added = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _PhotoForm(
        store: ref.read(adminCatalogStoreProvider),
        vehicleId: key,
        existing: data.photos[key] ?? const {},
        views: _PhotoForm.gearViews,
      ),
    );
    if (added == null) return;
    await _save(
        ref,
        AdminCatalog(
          vehicleRows: data.vehicleRows,
          platformRows: data.platformRows,
          photos: {...data.photos, key: added},
        ));
  }

  Future<void> _removeGearPhoto(
          WidgetRef ref, AdminCatalog data, SecuringPieceKind kind) async =>
      _save(
          ref,
          AdminCatalog(
            vehicleRows: data.vehicleRows,
            platformRows: data.platformRows,
            photos: {...data.photos}..remove(gearPhotoKey(kind)),
          ));

  Future<void> _managePhotos(BuildContext context, WidgetRef ref,
      AdminCatalog data, String vehicleId) async {
    final added = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => _PhotoForm(
        store: ref.read(adminCatalogStoreProvider),
        vehicleId: vehicleId,
        existing: data.photos[vehicleId] ?? const {},
      ),
    );
    if (added == null) return;
    await _save(
        ref,
        AdminCatalog(
          vehicleRows: data.vehicleRows,
          platformRows: data.platformRows,
          photos: {...data.photos, vehicleId: added},
        ));
  }
}

/// Every vehicle in the catalogue, searchable, so the instructor can put their
/// own photographs on one that shipped with the app.
///
/// Filtered rather than listed whole: a hundred and thirty-eight rows is a
/// scroll nobody reads, and the instructor always knows which machine they
/// came here for.
class _CataloguePhotos extends ConsumerStatefulWidget {
  final AdminCatalog catalog;
  final void Function(String vehicleId) onPhotos;

  const _CataloguePhotos({required this.catalog, required this.onPhotos});

  @override
  ConsumerState<_CataloguePhotos> createState() => _CataloguePhotosState();
}

class _CataloguePhotosState extends ConsumerState<_CataloguePhotos> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final vehicles = ref.watch(vehiclesProvider).valueOrNull ?? const [];
    final q = _query.trim().toLowerCase();
    final matches = q.isEmpty
        ? const []
        : [
            for (final v in vehicles)
              if (v.handbookDesignation.toLowerCase().contains(q)) v,
          ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          decoration: const InputDecoration(
            labelText: AppStrings.adminCatalogueSearch,
            isDense: true,
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.search, size: 18),
          ),
          onChanged: (text) => setState(() => _query = text),
        ),
        const SizedBox(height: 8),
        if (q.isEmpty)
          const Padding(
            padding: EdgeInsets.only(bottom: 4),
            child: Text(AppStrings.adminCatalogueHint,
                style: TextStyle(
                    color: AppColors.labelDim, fontSize: AppText.caption)),
          )
        else if (matches.isEmpty)
          const Text(AppStrings.adminCatalogueNoMatch,
              style: TextStyle(
                  color: AppColors.textSecondary, fontSize: AppText.bodySmall))
        else
          for (final v in matches.take(12))
            _AddedRow(
              title: v.handbookDesignation,
              subtitle: widget.catalog.photos[v.id] == null
                  ? AppStrings.adminCatalogueShipped
                  : AppStrings.adminCatalogueReplaced,
              photos: widget.catalog.photos[v.id] ?? const {},
              onPhotos: () => widget.onPhotos(v.id),
              onRemove: () => _clear(v.id),
            ),
      ],
    );
  }

  /// Drops the instructor's photographs, so the vehicle falls back to whatever
  /// the app shipped rather than to nothing.
  Future<void> _clear(String vehicleId) async {
    final next = AdminCatalog(
      vehicleRows: widget.catalog.vehicleRows,
      platformRows: widget.catalog.platformRows,
      photos: {...widget.catalog.photos}..remove(vehicleId),
    );
    await ref.read(adminCatalogStoreProvider).save(next);
    ref.invalidate(adminCatalogProvider);
  }
}

class _AddBar extends StatelessWidget {
  final VoidCallback onVehicle;
  final VoidCallback onWagon;

  const _AddBar({required this.onVehicle, required this.onWagon});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 280,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.adminAddVehicle),
              onPressed: onVehicle,
            ),
          ),
          SizedBox(
            width: 280,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text(AppStrings.adminAddWagon),
              onPressed: onWagon,
            ),
          ),
        ],
      );
}

class _AddedRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final Map<String, String> photos;
  final VoidCallback? onPhotos;
  final VoidCallback onRemove;

  const _AddedRow({
    required this.title,
    required this.subtitle,
    required this.photos,
    required this.onRemove,
    this.onPhotos,
  });

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: const BoxDecoration(
          color: AppColors.panel,
          border: Border(bottom: BorderSide(color: AppColors.hairline)),
        ),
        child: Row(
          children: [
            for (final view in photos.keys)
              if (photos[view] != null)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Image.file(File(photos[view]!),
                      width: 52, height: 40, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox(width: 52)),
                ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.legend(
                          size: AppText.bodySmall,
                          color: AppColors.textPrimary,
                          tracking: 1.0)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: AppText.caption,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            if (onPhotos != null)
              TextButton(
                onPressed: onPhotos,
                child: const Text(AppStrings.adminPhotosButton),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.outOfTolerance),
              onPressed: onRemove,
              tooltip: AppStrings.adminRemove,
            ),
          ],
        ),
      );
}

/// A labelled field that writes into [values] under [key].
class _Field extends StatelessWidget {
  final String label;
  final String fieldKey;
  final Map<String, dynamic> values;
  final bool number;

  const _Field(this.label, this.fieldKey, this.values, {this.number = false});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
          ),
          keyboardType: number ? TextInputType.number : TextInputType.text,
          onChanged: (text) {
            final trimmed = text.trim();
            if (trimmed.isEmpty) {
              values.remove(fieldKey);
            } else {
              values[fieldKey] =
                  number ? num.tryParse(trimmed.replaceAll(',', '.')) : trimmed;
            }
          },
        ),
      );
}

class _VehicleForm extends StatefulWidget {
  const _VehicleForm();

  @override
  State<_VehicleForm> createState() => _VehicleFormState();
}

class _VehicleFormState extends State<_VehicleForm> {
  final _values = <String, dynamic>{'category': 'tracked'};

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text(AppStrings.adminAddVehicle),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(AppStrings.adminFieldDesignation, 'handbookDesignation',
                    _values),
                DropdownButtonFormField<String>(
                  initialValue: _values['category'] as String,
                  decoration: const InputDecoration(
                    labelText: AppStrings.adminFieldCategory,
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'tracked', child: Text('gusenisaly')),
                    DropdownMenuItem(value: 'wheeled', child: Text('tigirli')),
                  ],
                  onChanged: (v) => setState(() => _values['category'] = v),
                ),
                const SizedBox(height: 10),
                _Field(AppStrings.adminFieldLength, 'lengthCm', _values,
                    number: true),
                _Field(AppStrings.adminFieldWidth, 'widthCm', _values,
                    number: true),
                _Field(AppStrings.adminFieldHeight, 'heightCm', _values,
                    number: true),
                _Field(AppStrings.adminFieldWeight, 'weightT', _values,
                    number: true),
                _Field(AppStrings.adminFieldClearance, 'groundClearanceCm',
                    _values,
                    number: true),
                _Field(AppStrings.adminFieldTrackWidth, 'trackWidthMm', _values,
                    number: true),
                _Field(AppStrings.adminFieldAxles, 'axleCount', _values,
                    number: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.traineeCancelButton),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _values['handbookDesignation'] as String?;
              if (name == null || name.isEmpty) return;
              Navigator.pop(context, {
                ..._values,
                'id': 'admin-${DateTime.now().millisecondsSinceEpoch}',
                'dataSource': 'designMockup',
                'referenceId': 'doc-transport-characteristics',
                'approvedSecuringHardware': const <String>[],
              });
            },
            child: const Text(AppStrings.adminSaveButton),
          ),
        ],
      );
}

class _WagonForm extends StatefulWidget {
  const _WagonForm();

  @override
  State<_WagonForm> createState() => _WagonFormState();
}

class _WagonFormState extends State<_WagonForm> {
  final _values = <String, dynamic>{'kind': 'openFlatcar'};

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text(AppStrings.adminAddWagon),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _Field(AppStrings.adminFieldWagonName, 'name', _values),
                _Field(AppStrings.adminFieldLength, 'lengthCm', _values,
                    number: true),
                _Field(AppStrings.adminFieldWidth, 'widthCm', _values,
                    number: true),
                _Field(AppStrings.adminFieldDeckHeight, 'deckHeightCm', _values,
                    number: true),
                _Field(AppStrings.adminFieldTieDownRings, 'tieDownRings',
                    _values,
                    number: true),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.traineeCancelButton),
          ),
          ElevatedButton(
            onPressed: () {
              final name = _values['name'] as String?;
              if (name == null || name.isEmpty) return;
              Navigator.pop(context, {
                ..._values,
                'id': 'admin-wagon-${DateTime.now().millisecondsSinceEpoch}',
                'referenceId': 'doc-transport-characteristics',
              });
            },
            child: const Text(AppStrings.adminSaveButton),
          ),
        ],
      );
}

/// Attaches a photograph of each side of the machine.
///
/// The path is typed or pasted rather than chosen from a file dialog. Flutter
/// has no native file picker on Linux desktop without a plugin, and a text
/// field with a live preview is a few lines against a new dependency — the
/// preview is what makes it verifiable: a wrong path shows nothing.
///
/// ponytail: typed path, swap for `file_picker` if instructors find it awkward.
class _PhotoForm extends StatefulWidget {
  final AdminCatalogStore store;
  final String vehicleId;
  final Map<String, String> existing;

  /// Which views to ask for. A machine gets three; a piece of securing gear is
  /// one object and gets one.
  final List<String> views;

  const _PhotoForm({
    required this.store,
    required this.vehicleId,
    required this.existing,
    this.views = vehicleViews,
  });

  /// The three views the plates draw a machine from.
  static const vehicleViews = ['front', 'side', 'rear'];
  static const gearViews = ['figure'];

  @override
  State<_PhotoForm> createState() => _PhotoFormState();
}

class _PhotoFormState extends State<_PhotoForm> {
  late final Map<String, String> _paths = {...widget.existing};
  late final _typed = <String, TextEditingController>{
    for (final view in widget.views) view: TextEditingController(),
  };
  String? _error;

  @override
  void dispose() {
    for (final c in _typed.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _attach(String view) async {
    final path = _typed[view]!.text.trim();
    if (path.isEmpty) return;
    final file = File(path);
    if (!file.existsSync()) {
      setState(() => _error = AppStrings.adminPhotoNotFound(path));
      return;
    }
    final saved = await widget.store.importPhoto(widget.vehicleId, view, file);
    setState(() {
      _paths[view] = saved;
      _error = null;
      _typed[view]!.clear();
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        backgroundColor: AppColors.panel,
        title: const Text(AppStrings.adminPhotosTitle),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(AppStrings.adminPhotosIntro,
                    style: TextStyle(
                        fontSize: AppText.bodySmall,
                        color: AppColors.textSecondary)),
                const SizedBox(height: 12),
                for (final view in widget.views) ...[
                  Text(AppStrings.adminPhotoView(view),
                      style: AppText.legend(
                          size: AppText.caption,
                          color: AppColors.label,
                          tracking: 1.4)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (_paths[view] != null)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Image.file(File(_paths[view]!),
                              width: 64, height: 48, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const SizedBox(width: 64)),
                        ),
                      Expanded(
                        child: TextField(
                          controller: _typed[view],
                          decoration: const InputDecoration(
                            hintText: '/home/…/photo.jpg',
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                          onSubmitted: (_) => _attach(view),
                        ),
                      ),
                      const SizedBox(width: 6),
                      TextButton(
                        onPressed: () => _attach(view),
                        child: const Text(AppStrings.adminPhotoAttach),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
                if (_error != null)
                  Text(_error!,
                      style: const TextStyle(
                          color: AppColors.outOfTolerance,
                          fontSize: AppText.bodySmall)),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(AppStrings.traineeCancelButton),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, _paths),
            child: const Text(AppStrings.adminSaveButton),
          ),
        ],
      );
}
