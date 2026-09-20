/// Code-style visual renderer for the Reaction Banner.
///
/// Displays a code snippet with syntax-like highlighting
/// using a monospace font. Designed for [CodeReactionType].
library;

import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';

class ReactionCodeRenderer extends StatelessWidget {
  const ReactionCodeRenderer({
    super.key,
    required this.code,
    this.language,
    this.label,
  });

  /// The code snippet text.
  final String code;

  /// Programming language key (e.g. 'dart', 'python').
  final String? language;

  /// Optional label text.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final textDirection = Directionality.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.background.withOpacity(0.8),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: AppColors.cyan.withOpacity(0.25), width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (language != null) Row(
                children: [
                  Icon(Icons.code, size: 12, color: AppColors.cyan.withOpacity(0.6)),
                  const SizedBox(width: 4),
                  Text(language!.toUpperCase(), style: TextStyle(fontSize: 9, color: AppColors.cyan.withOpacity(0.5), fontFamily: 'monospace', letterSpacing: 1)),
                ],
              ),
              const SizedBox(height: 4),
              Text(code, style: TextStyle(fontFamily: 'monospace', fontSize: 10, height: 1.3, color: AppColors.cyan), textDirection: textDirection),
            ],
          ),
        ),
        if (label != null && label!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(label!, style: TextStyle(fontSize: 12, color: AppColors.cyan.withOpacity(0.7)), textDirection: textDirection, textAlign: TextAlign.center),
        ],
      ],
    );
  }
}
