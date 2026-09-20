/// Custom visual renderer for the Reaction Banner.
///
/// Displays a generic icon + text card for reactions that
/// don't fit into the other visual style categories.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ReactionCustomVisualRenderer extends StatelessWidget {
  const ReactionCustomVisualRenderer({
    super.key,
    this.icon,
    this.title,
    required this.body,
    this.accentColor,
  });

  /// Optional leading icon.
  final IconData? icon;

  /// Optional title text.
  final String? title;

  /// Main body text.
  final String body;

  /// Accent color override (defaults to primary cyan).
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    final accent = accentColor ?? AppColors.cyan;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.background.withOpacity(0.6),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.25), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: textDirection,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: accent),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null && title!.isNotEmpty)
                  Text(title!, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accent), textDirection: textDirection),
                const SizedBox(height: 2),
                Text(body, style: TextStyle(fontSize: 11, color: Colors.white70), textDirection: textDirection),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
