import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/localization/app_strings.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/consist_providers.dart';

/// Asks who is sitting the attempt, before it starts.
///
/// Returns true when a name was given and the attempt may begin. There is no
/// way past it without both halves: the result sheet an instructor is handed
/// has to say whose it is, and a blank field on a test paper is the one thing
/// nobody can fix afterwards.
/// The name that opens the admin panel instead of starting an attempt.
///
/// A name rather than a password because this runs on an individual desk with
/// no accounts and nothing secret behind it — the panel edits the local
/// catalogue, it does not hold marks or trainee records. It keeps the door out
/// of a trainee's way without adding a login screen to a program that has no
/// users.
const String kAdminName = 'admin admin';

/// True when what was typed opens the admin panel.
bool isAdminName(String given, String family) =>
    '${given.trim()} ${family.trim()}'.toLowerCase() == kAdminName;

Future<bool> showTraineeDialog(BuildContext context, WidgetRef ref) async {
  final trainee = ref.read(traineeProvider);
  final given = TextEditingController(text: trainee.givenName);
  final family = TextEditingController(text: trainee.familyName);

  final began = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) => _TraineeDialog(given: given, family: family),
  );

  if (began == true) {
    if (isAdminName(given.text, family.text)) {
      if (context.mounted) context.go('/admin');
      return false;
    }
    ref.read(traineeProvider.notifier).set(given.text, family.text);
    return true;
  }
  return false;
}

class _TraineeDialog extends StatefulWidget {
  final TextEditingController given;
  final TextEditingController family;

  const _TraineeDialog({required this.given, required this.family});

  @override
  State<_TraineeDialog> createState() => _TraineeDialogState();
}

class _TraineeDialogState extends State<_TraineeDialog> {
  bool get _complete =>
      widget.given.text.trim().isNotEmpty && widget.family.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.panel,
      title: const Text(AppStrings.traineeDialogTitle,
          style: TextStyle(fontSize: AppText.sectionTitle)),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              AppStrings.traineeDialogIntro,
              style: TextStyle(
                  fontSize: AppText.bodySmall, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: widget.family,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: AppStrings.traineeFamilyNameLabel,
                hintText: AppStrings.traineeFamilyNameHint,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.given,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: AppStrings.traineeGivenNameLabel,
                hintText: AppStrings.traineeGivenNameHint,
              ),
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) {
                if (_complete) Navigator.of(context).pop(true);
              },
            ),
            if (!_complete) ...[
              const SizedBox(height: 10),
              const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: AppColors.offNominal),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(AppStrings.traineeIncompleteNote,
                        style: TextStyle(
                            fontSize: AppText.caption, color: AppColors.offNominal)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text(AppStrings.traineeCancelButton),
        ),
        ElevatedButton(
          onPressed: _complete ? () => Navigator.of(context).pop(true) : null,
          child: const Text(AppStrings.traineeBeginButton),
        ),
      ],
    );
  }
}
