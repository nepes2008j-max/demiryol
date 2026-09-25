import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/attachment_type.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../data/models/simulation_result.dart';
import '../../../data/models/vehicle.dart';
import '../../../domain/models/equipment_option.dart';
import '../../../domain/usecases/equipment_catalog.dart';
import '../../../domain/usecases/equipment_selection.dart';
import '../../../domain/usecases/handbook_photo_resolution.dart';
import '../../../domain/usecases/wire_lashing_rule.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../common/handbook_reference_chip.dart';
import '../photos/related_photos_row.dart';

/// Builds the selectable card for one required hardware id — shared by
/// [RequiredEquipmentPanel] (shows every slot at once, e.g. on the
/// Engineering Analysis review screen) and `EquipmentConfigurationWizard`
/// (shows one slot at a time on the configuration screen), so both read
/// from exactly the same `equipment_catalog.dart`/`equipment_selection.dart`
/// derivation with no duplicated logic.
EquipmentSelectionCard buildEquipmentCard({
  required String hardwareId,
  required String placementId,
  required Vehicle vehicle,
  required List<AttachmentType> attachments,
  required Map<String, dynamic> measurements,
  required Map<String, dynamic>? rules,
  required List<HandbookPhoto> Function(String hardwareId, String referenceId) photosFor,
  bool initiallyExpanded = true,
}) {
  final matches = attachments.where((a) => a.id == hardwareId);
  final attachment = matches.isEmpty ? null : matches.first;
  final options =
      equipmentOptionsFor(hardwareId, measurements, attachments, category: vehicle.category);
  final relatedPhotos =
      attachment == null ? const <HandbookPhoto>[] : photosFor(hardwareId, attachment.referenceId);
  // `rule-wheeled-lashing-count` (para. 55) is documented as wheeled-only,
  // matching SchematicBuilder's own guard — never reused for a tracked
  // vehicle's method-3 wire lashing, which the extract does not give a
  // count rule for.
  final lashingCount = hardwareId == 'att-wire-lashing' &&
          vehicle.category == VehicleCategory.wheeled &&
          vehicle.bracketWeightT.isAvailable &&
          rules != null
      ? requiredWireLashingCount(vehicle.bracketWeightT.asDouble!, rules)
      : null;
  return EquipmentSelectionCard(
    placementId: placementId,
    hardwareId: hardwareId,
    hardwareName: attachment?.name ?? hardwareId,
    hardwareReferenceId: attachment?.referenceId,
    options: options,
    vehicle: vehicle,
    measurements: measurements,
    relatedPhotos: relatedPhotos,
    lashingCount: lashingCount,
    initiallyExpanded: initiallyExpanded,
  );
}

/// One card per hardware id the engineering validator resolved as required
/// for the current vehicle: shows the real handbook-catalog options for
/// that slot (from `measurements.json`), lets the user pick one and press
/// Apply, and — for slots the handbook fixes to exactly one mandatory type
/// — reports whether the applied selection matches it. Applying a selection
/// only updates presentation state (`placementEquipmentProvider`, read by
/// the schematic); it never calls into `EngineeringValidator` itself.
class RequiredEquipmentPanel extends ConsumerWidget {
  final SimulationResult result;
  final String placementId;
  final Vehicle vehicle;

  const RequiredEquipmentPanel({
    super.key,
    required this.result,
    required this.placementId,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (result.requiredHardwareIds.isEmpty) {
      return const Text(AppStrings.noHardwareResolvedYet,
          style: TextStyle(color: AppColors.textSecondary, fontSize: AppText.bodySmall));
    }

    final attachmentsAsync = ref.watch(attachmentTypesProvider);
    final measurementsAsync = ref.watch(measurementsProvider);
    final rulesAsync = ref.watch(rulesProvider);
    final linker = ref.watch(referenceLinkerProvider).valueOrNull;

    return attachmentsAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text(AppStrings.errorPrefix(e)),
      data: (attachments) => measurementsAsync.when(
        loading: () => const CircularProgressIndicator(),
        error: (e, st) => Text(AppStrings.errorPrefix(e)),
        data: (measurements) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: result.requiredHardwareIds.map((hardwareId) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: buildEquipmentCard(
                hardwareId: hardwareId,
                placementId: placementId,
                vehicle: vehicle,
                attachments: attachments,
                measurements: measurements,
                rules: rulesAsync.valueOrNull,
                photosFor: (hid, refId) =>
                    linker == null ? const [] : equipmentPhotosFor(hid, refId, linker),
                initiallyExpanded: false,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

enum _EquipmentStatus { unknown, notConfigured, configured, pass, fail }

/// Compact status chip mirroring exactly what the card body already shows
/// (no catalog / nothing applied yet / applied with no mandatory type to
/// score / scored PASS / scored FAIL) — computed once in the card from
/// values already derived there, never a second source of truth.
class _EquipmentStatusBadge extends StatelessWidget {
  final _EquipmentStatus status;
  const _EquipmentStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    // The icon is not decoration. This badge is the only thing distinguishing
    // "configured" from "correct" from "not yet configured", and it carried
    // that on colour alone — sand, green and amber, which is the hardest
    // triple to tell apart projected, printed, or with a colour vision
    // deficiency. The shape now says it too.
    final (label, color, icon) = switch (status) {
      _EquipmentStatus.unknown => (
          AppStrings.equipmentStatusUnknown,
          AppColors.textSecondary,
          Icons.help_outline
        ),
      _EquipmentStatus.notConfigured => (
          AppStrings.equipmentStatusNotConfigured,
          AppColors.offNominal,
          Icons.radio_button_unchecked
        ),
      _EquipmentStatus.configured => (
          AppStrings.equipmentStatusConfigured,
          AppColors.label,
          Icons.adjust
        ),
      _EquipmentStatus.pass => (
          AppStrings.equipmentStatusPass,
          AppColors.inTolerance,
          Icons.check_circle
        ),
      _EquipmentStatus.fail => (AppStrings.equipmentStatusFail, AppColors.outOfTolerance, Icons.cancel),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        border: Border.all(color: color),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AppSpace.xs),
          Text(label,
              style:
                  TextStyle(fontSize: AppText.caption, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

/// One enumerated lashing slot within a multi-lashing requirement — all
/// slots share the single diameter choice above (the handbook gives no
/// per-lashing variation), so each chip simply mirrors the card's overall
/// status rather than tracking independent state.
class _LashingChip extends StatelessWidget {
  final int index;
  final _EquipmentStatus status;
  const _LashingChip({required this.index, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      _EquipmentStatus.pass => AppColors.inTolerance,
      _EquipmentStatus.fail => AppColors.outOfTolerance,
      _EquipmentStatus.configured => AppColors.label,
      _ => AppColors.textSecondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color),
        borderRadius: BorderRadius.zero,
      ),
      child: Text(AppStrings.equipmentLashingItemLabel(index),
          style: TextStyle(fontSize: AppText.caption, color: color, fontWeight: FontWeight.bold)),
    );
  }
}

class EquipmentSelectionCard extends ConsumerStatefulWidget {
  final String hardwareId;
  final String hardwareName;
  final String? hardwareReferenceId;
  final List<EquipmentOption> options;
  final Vehicle vehicle;
  final Map<String, dynamic> measurements;
  final List<HandbookPhoto> relatedPhotos;
  final int? lashingCount;

  /// Whether the size/type selector, Apply button, and verdict start
  /// expanded. The single-component wizard keeps this true (there is only
  /// one card visible, no reason to hide it); the all-at-once review panel
  /// passes false so several required slots don't all dump their full
  /// option lists on screen simultaneously.
  final bool initiallyExpanded;

  /// The placed vehicle this card configures. Selections are stored per
  /// placement, so securing the second vehicle on a wagon cannot overwrite
  /// the first one's hardware.
  final String placementId;

  const EquipmentSelectionCard({
    super.key,
    required this.placementId,
    required this.hardwareId,
    required this.hardwareName,
    required this.hardwareReferenceId,
    required this.options,
    required this.vehicle,
    required this.measurements,
    required this.relatedPhotos,
    this.lashingCount,
    this.initiallyExpanded = true,
  });

  @override
  ConsumerState<EquipmentSelectionCard> createState() => EquipmentSelectionCardState();
}

class EquipmentSelectionCardState extends ConsumerState<EquipmentSelectionCard> {
  String? _pending;
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final applied =
        ref.watch(effectivePlacementEquipmentProvider(widget.placementId))[widget.hardwareId];
    _pending ??= applied;
    final requiredType =
        requiredTypeCodeFor(widget.hardwareId, widget.vehicle, measurements: widget.measurements);
    final check = checkEquipmentSelection(
      referenceId: widget.hardwareReferenceId ?? '',
      requiredTypeCode: requiredType,
      selectedTypeCode: applied,
    );
    final weightDependentSizingUnresolved =
        widget.hardwareId == 'att-wood-chock' && !widget.vehicle.bracketWeightT.isAvailable;
    final status = widget.options.isEmpty
        ? _EquipmentStatus.unknown
        : check != null
            ? (check.status == CheckStatus.pass ? _EquipmentStatus.pass : _EquipmentStatus.fail)
            : (applied == null ? _EquipmentStatus.notConfigured : _EquipmentStatus.configured);

    // The card's own leading edge carries its status, so a wrong or missing
    // piece is findable in a stack of cards without reading any of them.
    final edge = switch (status) {
      _EquipmentStatus.pass => AppColors.inTolerance,
      _EquipmentStatus.fail => AppColors.outOfTolerance,
      _EquipmentStatus.notConfigured => AppColors.offNominal,
      _ => AppColors.hairline,
    };
    // The accent is a strip inside the card rather than a thicker left border:
    // Flutter refuses a `borderRadius` on a border whose sides differ in
    // colour, and losing the radius on exactly the cards that need attention
    // would make them look like a different component. It is positioned rather
    // than a stretched Row child because the card is laid out in a scroll
    // view, where a stretching Row has no height to stretch to.
    final accented = edge != AppColors.hairline;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.zero,
      ),
      child: Stack(
        children: [
          if (accented)
            Positioned(left: 0, top: 0, bottom: 0, width: 3, child: ColoredBox(color: edge)),
          Padding(
            padding: EdgeInsets.fromLTRB(
                accented ? AppSpace.md + 3 : AppSpace.md, AppSpace.md, AppSpace.md, AppSpace.md),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.build, size: 14, color: AppColors.label),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(widget.hardwareName,
                            style: const TextStyle(
                                fontSize: AppText.label, fontWeight: FontWeight.bold)),
                      ),
                      _EquipmentStatusBadge(status: status),
                      const SizedBox(width: 6),
                      if (widget.hardwareReferenceId != null)
                        HandbookReferenceChip(referenceId: widget.hardwareReferenceId!),
                      IconButton(
                        icon: Icon(_expanded ? Icons.expand_less : Icons.expand_more, size: 18),
                        tooltip: _expanded
                            ? AppStrings.equipmentHideDetailsButton
                            : AppStrings.equipmentShowDetailsButton,
                        visualDensity: VisualDensity.compact,
                        onPressed: () => setState(() => _expanded = !_expanded),
                      ),
                    ],
                  ),
                  if (!_expanded) ...[
                    const SizedBox(height: 4),
                    Text(
                      status == _EquipmentStatus.notConfigured
                          ? AppStrings.equipmentRequiredBadge
                          : applied ?? AppStrings.equipmentRequiredBadge,
                      style: const TextStyle(
                          fontSize: AppText.bodySmall, color: AppColors.textSecondary),
                    ),
                  ],
                  if (_expanded) ...[
                    if (widget.lashingCount != null && widget.lashingCount! > 1) ...[
                      const SizedBox(height: 6),
                      Text(AppStrings.equipmentLashingCountLabel(widget.lashingCount!),
                          style: const TextStyle(
                              fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 1; i <= widget.lashingCount!; i++)
                            _LashingChip(index: i, status: status),
                        ],
                      ),
                    ],
                    if (widget.options.isEmpty) ...[
                      const SizedBox(height: 6),
                      const Text(AppStrings.equipmentNoCatalogYet,
                          style: TextStyle(
                              fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
                    ] else ...[
                      if (weightDependentSizingUnresolved) ...[
                        const SizedBox(height: 8),
                        const Text(AppStrings.equipmentWeightUnavailableForSizing,
                            style:
                                TextStyle(fontSize: AppText.bodySmall, color: AppColors.offNominal)),
                      ],
                      const SizedBox(height: 10),
                      const Text(AppStrings.equipmentSelectTypeLabel,
                          style:
                              TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold)),
                      RadioGroup<String>(
                        groupValue: _pending,
                        onChanged: (v) => setState(() => _pending = v),
                        child: Column(
                          children: widget.options
                              .map((o) => RadioListTile<String>(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    value: o.typeCode,
                                    title: Text(o.typeCode,
                                        style: const TextStyle(
                                            fontSize: AppText.bodySmall,
                                            fontWeight: FontWeight.bold)),
                                    subtitle: o.specs.isEmpty
                                        ? null
                                        : Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Wrap(
                                              spacing: 12,
                                              runSpacing: 4,
                                              children: o.specs.entries
                                                  .map((e) =>
                                                      _SpecValue(label: e.key, value: e.value))
                                                  .toList(),
                                            ),
                                          ),
                                  ))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton(
                          onPressed: (_pending == null || _pending == applied)
                              ? null
                              : () => ref
                                  .read(placementEquipmentProvider.notifier)
                                  .select(widget.placementId, widget.hardwareId, _pending!),
                          child: const Text(AppStrings.equipmentApplyButton),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    if (widget.relatedPhotos.isNotEmpty)
                      RelatedPhotosRow(photos: widget.relatedPhotos, thumbnailSize: 72)
                    else
                      const Text(AppStrings.equipmentPhotoUnavailable,
                          style:
                              TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary)),
                  ], // end of `if (_expanded)`
                  if (check != null) ...[
                    const SizedBox(height: 6),
                    _EquipmentCheckBanner(
                        check: check, selectedTypeCode: applied!, requiredTypeCode: requiredType!),
                  ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Structured PASS/FAIL readout: "Saýlanan: X" always shown, "Gollanma
/// talaby: Y" added on a mismatch so both values are visible side by side
/// (never just a plain "FAIL"), plus the citation the verdict rests on.
/// The underlying verdict (`check.status`/`check.detail`) is never
/// recomputed here — this only re-lays-out values already produced by
/// `checkEquipmentSelection`.
/// One real handbook value shown prominently — label small and muted, the
/// actual number large and bold, never tucked into a tooltip. Only ever
/// built from a value `equipment_catalog.dart` already resolved from
/// `measurements.json`.
class _SpecValue extends StatelessWidget {
  final String label;
  final String value;
  const _SpecValue({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label,
            style: const TextStyle(fontSize: AppText.caption, color: AppColors.textSecondary)),
        Text(value,
            style: const TextStyle(
                fontSize: AppText.label,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary)),
      ],
    );
  }
}

class _EquipmentCheckBanner extends StatelessWidget {
  final ValidationCheck check;
  final String selectedTypeCode;
  final String requiredTypeCode;

  const _EquipmentCheckBanner({
    required this.check,
    required this.selectedTypeCode,
    required this.requiredTypeCode,
  });

  @override
  Widget build(BuildContext context) {
    final pass = check.status == CheckStatus.pass;
    final color = pass ? AppColors.inTolerance : AppColors.outOfTolerance;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(pass ? Icons.check_circle : Icons.cancel, color: color, size: 16),
              const SizedBox(width: 8),
              Text(
                pass
                    ? AppStrings.equipmentResultCorrectLabel
                    : AppStrings.equipmentResultIncorrectLabel,
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: AppText.bodySmall, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          _KeyValueLine(
              label: AppStrings.equipmentSelectedValueLabel, value: selectedTypeCode, color: color),
          if (!pass)
            _KeyValueLine(
                label: AppStrings.equipmentRequiredValueLabel,
                value: requiredTypeCode,
                color: color),
          const SizedBox(height: 6),
          HandbookReferenceChip(referenceId: check.referenceId),
        ],
      ),
    );
  }
}

class _KeyValueLine extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _KeyValueLine({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: RichText(
        text: TextSpan(
          style: TextStyle(fontSize: AppText.bodySmall, color: color),
          children: [
            TextSpan(text: '$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
            TextSpan(text: value, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
