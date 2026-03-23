import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RoutineCircle {
  final String id;
  final String name;
  final bool isHighlighted;

  const RoutineCircle({
    required this.id,
    required this.name,
    this.isHighlighted = false,
  });
}

class RoutineCirclesWidget extends StatelessWidget {
  final List<RoutineCircle> circles;
  final ValueChanged<String> onCircleTap;
  final ValueChanged<String>? onCircleLongPress;
  final VoidCallback onSeeAll;
  final String? suggestionText;

  const RoutineCirclesWidget({
    super.key,
    required this.circles,
    required this.onCircleTap,
    this.onCircleLongPress,
    required this.onSeeAll,
    this.suggestionText,
  });

  @override
  Widget build(BuildContext context) {
    if (circles.isEmpty) {
      return _buildEmptyState(context);
    }

    return Column(
      children: [
        if (suggestionText != null) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.successColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Icon(Icons.auto_awesome, size: 16, color: AppTheme.successColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    suggestionText!,
                    style: TextStyle(
                      color: AppTheme.successColor,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: circles.map((circle) => _buildCircle(context, circle)).toList(),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: onSeeAll,
          child: Text(
            'All Routines',
            style: TextStyle(
              color: AppTheme.primaryColor,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCircle(BuildContext context, RoutineCircle circle) {
    return GestureDetector(
      onTap: () => onCircleTap(circle.id),
      onLongPress: onCircleLongPress != null ? () => onCircleLongPress!(circle.id) : null,
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.cardColor,
              border: Border.all(
                color: circle.isHighlighted
                    ? AppTheme.primaryColor
                    : AppTheme.cardColorLight,
                width: circle.isHighlighted ? 3 : 1,
              ),
              boxShadow: circle.isHighlighted
                  ? [
                      BoxShadow(
                        color: AppTheme.primaryColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 2,
                      ),
                    ]
                  : null,
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Text(
                  circle.name,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: circle.isHighlighted
                        ? AppTheme.textPrimary
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: circle.isHighlighted
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Icon(Icons.add_circle_outline, size: 40, color: AppTheme.textTertiary),
          const SizedBox(height: 12),
          Text(
            'Add routines to your rotation to get started',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onSeeAll,
            child: const Text('Manage Rotation'),
          ),
        ],
      ),
    );
  }
}
