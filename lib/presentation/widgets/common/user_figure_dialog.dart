import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/consist_providers.dart';

/// Takes one figure from the instructor — a deck length, a vehicle length, a
/// combat weight — for the fields the handbook extract does not carry.
///
/// Shared by every place that offers one so the wording, the storage and the
/// warning are identical: the dialog says plainly that the number is theirs
/// and not the handbook's, because everything else in this app arrives with a
/// citation and this will not.
Future<void> showUserFigureDialog(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  required String storageKey,
  required String hint,
}) async {
  final controller = TextEditingController(
    text: ref.read(userDimensionsProvider)[storageKey]?.toStringAsFixed(0) ?? '',
  );
  await showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppColors.panel,
      title: Text(title, style: const TextStyle(fontSize: AppText.sectionTitle)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: controller,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: hint),
          ),
          const SizedBox(height: 10),
          const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: AppColors.offNominal),
              SizedBox(width: 6),
              Expanded(
                child: Text(AppStrings.wagonCapacityUserValueNote,
                    style:
                        TextStyle(fontSize: AppText.caption, color: AppColors.offNominal)),
              ),
            ],
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(userDimensionsProvider.notifier).clear(storageKey);
            Navigator.of(context).pop();
          },
          child: const Text(AppStrings.wagonCapacityClearButton),
        ),
        ElevatedButton(
          onPressed: () {
            final value = double.tryParse(controller.text.replaceAll(',', '.'));
            if (value != null) {
              ref.read(userDimensionsProvider.notifier).set(storageKey, value);
            }
            Navigator.of(context).pop();
          },
          child: const Text(AppStrings.wagonCapacitySaveButton),
        ),
      ],
    ),
  );
}

/// The button that opens it, styled the same wherever a figure can be given.
class UserFigureButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const UserFigureButton({super.key, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.straighten, size: 16),
        label: Text(label, style: const TextStyle(fontSize: AppText.caption)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.label,
          side: const BorderSide(color: AppColors.labelDim),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );
}
