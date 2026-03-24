import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WorkoutDaySuggestion extends StatelessWidget {
  final String? routineName;
  final bool completedToday;
  final VoidCallback onTap;

  const WorkoutDaySuggestion({
    super.key,
    required this.routineName,
    this.completedToday = false,
    required this.onTap,
  });

  static String _withDay(String name) {
    if (name.toLowerCase().endsWith('day')) return name;
    return '$name day';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: completedToday ? null : onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          gradient: routineName != null
              ? LinearGradient(
                  colors: completedToday
                      ? [
                          AppTheme.successColor.withOpacity(0.2),
                          AppTheme.successColor.withOpacity(0.1),
                        ]
                      : [
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
              completedToday
                  ? Icons.check_circle
                  : routineName != null
                      ? Icons.play_circle_fill
                      : Icons.settings,
              color: completedToday
                  ? AppTheme.successColor
                  : routineName != null
                      ? AppTheme.primaryColor
                      : AppTheme.textTertiary,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                completedToday
                    ? 'Today was ${_withDay(routineName!)}'
                    : routineName != null
                        ? 'Today is ${_withDay(routineName!)}'
                        : 'Set up your workout rotation',
                style: TextStyle(
                  color: completedToday
                      ? AppTheme.successColor
                      : routineName != null
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (!completedToday)
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
