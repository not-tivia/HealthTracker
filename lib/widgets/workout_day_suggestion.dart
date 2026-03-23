import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WorkoutDaySuggestion extends StatelessWidget {
  final String? routineName;
  final VoidCallback onTap;

  const WorkoutDaySuggestion({
    super.key,
    required this.routineName,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: routineName != null
              ? LinearGradient(
                  colors: [
                    AppTheme.primaryColor.withOpacity(0.2),
                    AppTheme.secondaryColor.withOpacity(0.1),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: routineName == null ? AppTheme.cardColor : null,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              routineName != null ? Icons.play_circle_fill : Icons.settings,
              color: routineName != null
                  ? AppTheme.primaryColor
                  : AppTheme.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                routineName != null
                    ? 'Today is $routineName day'
                    : 'Set up your workout rotation',
                style: TextStyle(
                  color: routineName != null
                      ? AppTheme.textPrimary
                      : AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: AppTheme.textTertiary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
