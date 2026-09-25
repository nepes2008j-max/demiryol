import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/handbook_rule.dart';
import '../../../data/models/simulation_result.dart';
import '../../../domain/models/securing_method.dart';
import '../../../domain/usecases/securing_method_resolution.dart';
import '../../../data/models/vehicle.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../../../data/models/handbook_photo.dart';
import '../../../domain/usecases/handbook_photo_resolution.dart';
import '../common/handbook_reference_chip.dart';
import '../common/user_figure_dialog.dart';
import '../photos/handbook_photo_thumbnail.dart';

/// Shown only for tracked vehicles the handbook does NOT already assign one
/// mandatory securing method to by name (iron spur/chock-boot vehicles have
/// nothing to choose between and never reach this selector). Lets the user
/// pick exactly one of the approved alternative methods (Annex 14 §4) this
/// vehicle's data supports and Apply it — only that one method's hardware
/// becomes required; the others are never silently included at the same
/// time.
class SecuringMethodSelector extends ConsumerWidget {
  final SimulationResult result;
  final String placementId;
  final Vehicle vehicle;

  const SecuringMethodSelector({
    super.key,
    required this.result,
    required this.placementId,
    required this.vehicle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The applied method is keyed by placement, so it cannot leak between two
    // vehicles on the same wagon and needs no reset when the selection moves.
    if (vehicle.ironSpurType != null || vehicle.ironChockBootType != null) {
      return const SizedBox.shrink();
    }

    final resolution = resolveSecuringMethodOptions(vehicle);
    if (resolution is! AlternativeSecuringMethods) return const SizedBox.shrink();

    final rulesAsync = ref.watch(ruleEntriesProvider);
    return rulesAsync.when(
      loading: () => const CircularProgressIndicator(),
      error: (e, st) => Text(AppStrings.errorPrefix(e)),
      data: (rules) {
        final methodRules = <int, HandbookRule>{
          for (final r in rules)
            if (r.isMethod && r.methodNumber != null) r.methodNumber!: r,
        };
        final check =
            result.checks.firstWhereOrNull((c) => c.ruleId == 'rule-securing-method-alternatives');
        // The handbook's own numbered banner for each offered method, so the
        // trainee picks by the panel they will recognise from the plate.
        // Absent for a method the source has no panel for — never filled in
        // with another method's picture.
        final linker = ref.watch(referenceLinkerProvider).valueOrNull;
        final methodFigures = <int, HandbookPhoto>{
          if (linker != null)
            for (final m in resolution.methodNumbers)
              if (trackedMethodFigure(m, linker) != null) m: trackedMethodFigure(m, linker)!,
        };
        return _SecuringMethodCard(
          placementId: placementId,
          methodNumbers: resolution.methodNumbers,
          eligibilityConfirmed: resolution.eligibilityConfirmed,
          vehicleId: vehicle.id,
          designation: vehicle.handbookDesignation,
          methodRules: methodRules,
          methodFigures: methodFigures,
          check: check,
        );
      },
    );
  }
}

class _SecuringMethodCard extends ConsumerStatefulWidget {
  final String placementId;
  final List<int> methodNumbers;
  final Map<int, HandbookRule> methodRules;
  final Map<int, HandbookPhoto> methodFigures;
  final ValidationCheck? check;
  final String vehicleId;
  final String designation;

  /// False when the vehicle's combat weight is missing, so the methods are
  /// offered but their weight-dependent limits could not be checked.
  final bool eligibilityConfirmed;

  const _SecuringMethodCard({
    required this.placementId,
    required this.methodNumbers,
    required this.methodRules,
    required this.methodFigures,
    required this.check,
    required this.vehicleId,
    required this.designation,
    required this.eligibilityConfirmed,
  });

  @override
  ConsumerState<_SecuringMethodCard> createState() => _SecuringMethodCardState();
}

class _SecuringMethodCardState extends ConsumerState<_SecuringMethodCard> {
  int? _pending;

  @override
  Widget build(BuildContext context) {
    final applied = ref.watch(placementSecuringMethodProvider)[widget.placementId];
    _pending ??= applied;

    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.labelDim),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(AppStrings.securingMethodSelectLabel,
              style: TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold)),
          if (!widget.eligibilityConfirmed) ...[
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 14, color: AppColors.offNominal),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppStrings.securingMethodEligibilityUnconfirmedNote,
                      style: TextStyle(fontSize: AppText.caption, color: AppColors.offNominal),
                    ),
                  ),
                ],
              ),
            ),
            // The weight is what is missing, so it can be given here rather
            // than leaving the trainee with a permanent "cannot be decided".
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: UserFigureButton(
                label: AppStrings.enterCombatWeightButton,
                onPressed: () => showUserFigureDialog(
                  context,
                  ref,
                  title:
                      '${AppStrings.enterCombatWeightButton} — ${widget.designation}',
                  storageKey: UserDimensionsNotifier.weightKey(widget.vehicleId),
                  hint: AppStrings.enterCombatWeightHint,
                ),
              ),
            ),
          ],
          RadioGroup<int>(
            groupValue: _pending,
            onChanged: (v) => setState(() => _pending = v),
            child: Column(
              children: widget.methodNumbers.map((m) {
                final rule = widget.methodRules[m];
                final figure = widget.methodFigures[m];
                return RadioListTile<int>(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  value: m,
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(rule?.displayTitle ?? '$m-nji usul',
                            style: const TextStyle(fontSize: AppText.bodySmall, fontWeight: FontWeight.bold)),
                      ),
                      if (rule != null) HandbookReferenceChip(referenceId: rule.referenceId),
                    ],
                  ),
                  subtitle: figure == null
                      ? null
                      : Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 2),
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: HandbookPhotoThumbnail(photo: figure, size: 132),
                          ),
                        ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: (_pending == null || _pending == applied)
                  ? null
                  : () => ref
                      .read(placementSecuringMethodProvider.notifier)
                      .apply(widget.placementId, _pending!),
              child: const Text(AppStrings.equipmentApplyButton),
            ),
          ),
          if (widget.check != null) ...[
            const SizedBox(height: 6),
            _MethodCheckBanner(check: widget.check!),
          ],
        ],
      ),
    );
  }
}

class _MethodCheckBanner extends StatelessWidget {
  final ValidationCheck check;
  const _MethodCheckBanner({required this.check});

  @override
  Widget build(BuildContext context) {
    final color = check.status == CheckStatus.pass
        ? AppColors.inTolerance
        : check.status == CheckStatus.fail
            ? AppColors.outOfTolerance
            : AppColors.offNominal;
    final icon = check.status == CheckStatus.pass
        ? Icons.check_circle
        : check.status == CheckStatus.fail
            ? Icons.cancel
            : Icons.help;
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        border: Border.all(color: color),
        borderRadius: BorderRadius.zero,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(check.detail, style: TextStyle(fontSize: AppText.bodySmall, color: color))),
        ],
      ),
    );
  }
}
