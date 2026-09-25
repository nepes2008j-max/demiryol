import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

/// Shared dialog shell (title bar + close button + scrollable body) used by
/// every "detail" dialog in the Reference Browser and contextual info
/// popups, so they read as one consistent desktop UI.
Future<void> showDetailDialog({
  required BuildContext context,
  required String title,
  required List<Widget> children,
}) {
  return showDialog(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: AppColors.panel,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: AppText.sectionTitle),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...children,
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
