/// ASCII-art visual style renderer for the Reaction Banner.
///
/// Displays multi-line ASCII art text in a monospace font
/// with a subtle glow. RTL-aware for Kurdish Sorani labels.
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ReactionAsciiArtRenderer extends StatelessWidget {
  const ReactionAsciiArtRenderer({
    super.key,
    required this.art,
    this.label,
  });

  /// The ASCII art string (may contain newlines).
  final String art;

  /// Optional label below the art.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.6),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.cyan.withOpacity(0.2), width: 1),
          ),
          child: Text(
            art,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              height: 1.2,
              color: AppColors.cyan,
            ),
            textAlign: TextAlign.center,
            textDirection: textDirection,
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label!, style: TextStyle(fontSize: 12, color: AppColors.cyan.withOpacity(0.8)), textDirection: textDirection, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
