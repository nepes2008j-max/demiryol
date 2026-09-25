import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/usecases/wire_lashing_angle.dart';
import '../../providers/consist_providers.dart';
import '../../providers/handbook_providers.dart';
import '../common/handbook_reference_chip.dart';

/// The two angles of a wire lashing as it is actually installed.
///
/// Table 7 gives the number of strands a lashing needs from the angle to the
/// wagon's longitudinal axis and the angle to the floor. Neither is a property
/// of the vehicle, so nothing in the catalogue could ever supply them and the
/// strand count stayed undecided for every configuration in the app. Measured
/// on the wagon and typed here, the table answers it — and the answer is
/// marked as resting on a typed figure, like every other one.
class LashingAngleEntry extends ConsumerWidget {
  final String placementId;

  const LashingAngleEntry({super.key, required this.placementId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final measurements = ref.watch(measurementsProvider).valueOrNull;
    if (measurements == null) return const SizedBox.shrink();

    final dimensions = ref.watch(userDimensionsProvider);
    final axisKey = UserDimensionsNotifier.lashingAxisAngleKey(placementId);
    final floorKey = UserDimensionsNotifier.lashingFloorAngleKey(placementId);
    final cap = maxFloorAngleDeg(measurements);

    return Container(
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: AppColors.panel,
        border: Border.all(color: AppColors.hairline),
        borderRadius: BorderRadius.zero,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(AppStrings.lashingAngleHeading,
                    style: TextStyle(
                        fontSize: AppText.sectionTitle,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ),
              // Bounded for the same reason as in the materials list: the
              // chip is measured with unbounded width as a row child.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: const HandbookReferenceChip(referenceId: 'table-7'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          const Text(AppStrings.lashingAngleSubtitle,
              style: TextStyle(
                  fontSize: AppText.bodySmall, color: AppColors.textSecondary)),
          if (cap != null) ...[
            const SizedBox(height: 4),
            Text(AppStrings.lashingFloorAngleCap(cap),
                style: const TextStyle(
                    fontSize: AppText.bodySmall, color: AppColors.offNominal)),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _AngleField(
                  label: AppStrings.lashingAxisAngleShort,
                  storageKey: axisKey,
                  value: dimensions[axisKey],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _AngleField(
                  label: AppStrings.lashingFloorAngleShort,
                  storageKey: floorKey,
                  value: dimensions[floorKey],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AngleField extends ConsumerStatefulWidget {
  final String label;
  final String storageKey;
  final double? value;

  const _AngleField({
    required this.label,
    required this.storageKey,
    required this.value,
  });

  @override
  ConsumerState<_AngleField> createState() => _AngleFieldState();
}

class _AngleFieldState extends ConsumerState<_AngleField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value == null ? '' : _format(widget.value!));

  static String _format(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toString();

  @override
  void didUpdateWidget(_AngleField old) {
    super.didUpdateWidget(old);
    // The field belongs to one placement; switching to another vehicle must
    // show that vehicle's own measurement rather than the last one typed.
    if (old.storageKey != widget.storageKey) {
      _controller.text = widget.value == null ? '' : _format(widget.value!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _commit(String text) {
    final trimmed = text.trim();
    final notifier = ref.read(userDimensionsProvider.notifier);
    if (trimmed.isEmpty) {
      // Clearing the field withdraws the measurement rather than leaving the
      // last one standing: the check goes back to undecided, which is the
      // truthful state when nothing has been measured.
      notifier.clear(widget.storageKey);
      return;
    }
    final parsed = double.tryParse(trimmed.replaceAll(',', '.'));
    if (parsed == null) return;
    notifier.set(widget.storageKey, parsed);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(fontSize: AppText.body),
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: AppStrings.enterAngleHint,
        suffixText: '°',
      ),
      onChanged: _commit,
      onSubmitted: _commit,
    );
  }
}
