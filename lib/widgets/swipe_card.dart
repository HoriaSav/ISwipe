import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../theme/app_theme.dart';

enum SwipeDirection { left, right }

class SwipeCard extends StatefulWidget {
  const SwipeCard({
    super.key,
    required this.asset,
    required this.onSwipe,
  });

  final AssetEntity asset;
  final ValueChanged<SwipeDirection> onSwipe;

  @override
  State<SwipeCard> createState() => _SwipeCardState();
}

class _SwipeCardState extends State<SwipeCard> {
  Offset _dragOffset = Offset.zero;
  bool _isAnimatingOut = false;

  static const _threshold = 120.0;

  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimatingOut) return;
    setState(() {
      _dragOffset += details.delta;
    });
  }

  Future<void> _onPanEnd(DragEndDetails details) async {
    if (_isAnimatingOut) return;

    if (_dragOffset.dx <= -_threshold) {
      await _animateOut(SwipeDirection.left);
    } else if (_dragOffset.dx >= _threshold) {
      await _animateOut(SwipeDirection.right);
    } else {
      setState(() => _dragOffset = Offset.zero);
    }
  }

  Future<void> _animateOut(SwipeDirection direction) async {
    setState(() => _isAnimatingOut = true);
    final targetX = direction == SwipeDirection.left ? -500.0 : 500.0;
    setState(() => _dragOffset = Offset(targetX, _dragOffset.dy));
    await Future<void>.delayed(const Duration(milliseconds: 180));
    widget.onSwipe(direction);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rotation = (_dragOffset.dx / 1000).clamp(-0.12, 0.12);
    final deleteOpacity = (-_dragOffset.dx / _threshold).clamp(0.0, 1.0);
    final keepOpacity = (_dragOffset.dx / _threshold).clamp(0.0, 1.0);

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Transform.translate(
        offset: _dragOffset,
        child: Transform.rotate(
          angle: rotation,
          child: Stack(
            alignment: Alignment.center,
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image(
                    image: AssetEntityImageProvider(
                      widget.asset,
                      isOriginal: true,
                    ),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: double.infinity,
                  ),
                ),
              ),
              Positioned(
                top: 24,
                left: 24,
                child: _SwipeLabel(
                  text: 'Delete',
                  color: AppTheme.delete,
                  opacity: deleteOpacity,
                ),
              ),
              Positioned(
                top: 24,
                right: 24,
                child: _SwipeLabel(
                  text: 'Keep',
                  color: AppTheme.keep,
                  opacity: keepOpacity,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SwipeLabel extends StatelessWidget {
  const _SwipeLabel({
    required this.text,
    required this.color,
    required this.opacity,
  });

  final String text;
  final Color color;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: opacity,
      duration: const Duration(milliseconds: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          border: Border.all(color: color, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
    );
  }
}
