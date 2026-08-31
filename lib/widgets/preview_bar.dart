import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class PreviewBar extends StatelessWidget {
  const PreviewBar({
    super.key,
    required this.assets,
    required this.currentIndex,
    this.windowSize = 5,
  });

  final List<AssetEntity> assets;
  final int currentIndex;
  final int windowSize;

  @override
  Widget build(BuildContext context) {
    if (assets.isEmpty) {
      return const SizedBox(height: 72);
    }

    final start = (currentIndex - windowSize).clamp(0, assets.length - 1);
    final end = (currentIndex + windowSize).clamp(0, assets.length - 1);
    final visible = assets.sublist(start, end + 1);

    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        itemCount: visible.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, listIndex) {
          final assetIndex = start + listIndex;
          final asset = visible[listIndex];
          final isCurrent = assetIndex == currentIndex;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isCurrent ? 56 : 48,
            height: isCurrent ? 56 : 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isCurrent
                    ? Theme.of(context).colorScheme.primary
                    : Colors.transparent,
                width: 2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Opacity(
                opacity: assetIndex < currentIndex ? 0.45 : 1,
                child: Image(
                  image: AssetEntityImageProvider(
                    asset,
                    isOriginal: false,
                    thumbnailSize: const ThumbnailSize.square(120),
                  ),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
