/// Emoji visual style renderer for the Reaction Banner.
///
/// Displays a large centered emoji with optional label text
/// below it. RTL-aware layout for Kurdish Sorani.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

/// Renders an emoji-style reaction inside the banner.
///
/// Expects [emoji] from the reaction payload (key: 'emoji'),
/// and optionally [label] (key: 'label').
class ReactionEmojiRenderer extends StatelessWidget {
  const ReactionEmojiRenderer({
    super.key,
    required this.emoji,
    this.label,
  });

  /// The emoji character to display.
  final String emoji;

  /// Optional short label below the emoji.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          emoji,
          style: const TextStyle(fontSize: 36),
          textDirection: textDirection,
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            label!,
            style: TextStyle(
              fontSize: 13,
              color: AppColors.cyan.withOpacity(0.9),
              fontWeight: FontWeight.w500,
            ),
            textDirection: textDirection,
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }
}
