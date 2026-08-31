import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class ReviewedBadge extends StatelessWidget {
  const ReviewedBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 8,
      right: 8,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          color: AppTheme.keep,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 6,
            ),
          ],
        ),
        child: const Icon(
          Icons.check_rounded,
          size: 15,
          color: Colors.white,
        ),
      ),
    );
  }
}
