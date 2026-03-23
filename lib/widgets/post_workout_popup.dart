import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PostWorkoutPopup {
  /// Show a dialog prompting the user to do a warm-down stretch.
  /// Returns true if user wants to do the stretch, false otherwise.
  static Future<bool> show(BuildContext context, {required String stretchName}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.surfaceColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.self_improvement, color: AppTheme.successColor),
            const SizedBox(width: 10),
            const Text('Warm Down?'),
          ],
        ),
        content: Text(
          'Great workout! Want to do "$stretchName" to cool down?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Skip', style: TextStyle(color: AppTheme.textTertiary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
            ),
            child: const Text("Let's go"),
          ),
        ],
      ),
    ).then((value) => value ?? false);
  }
}
