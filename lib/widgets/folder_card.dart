import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

class FolderCard extends StatefulWidget {
  const FolderCard({
    super.key,
    required this.album,
    required this.coverRefreshHint,
    required this.onTap,
  });

  final AssetPathEntity album;
  final int coverRefreshHint;
  final VoidCallback onTap;

  @override
  State<FolderCard> createState() => _FolderCardState();
}

class _FolderCardState extends State<FolderCard> {
  AssetEntity? _cover;

  @override
  void initState() {
    super.initState();
    _loadCover();
  }

  @override
  void didUpdateWidget(covariant FolderCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coverRefreshHint != widget.coverRefreshHint ||
        oldWidget.album.id != widget.album.id) {
      _loadCover();
    }
  }

  Future<void> _loadCover() async {
    final count = await widget.album.assetCountAsync;
    AssetEntity? cover;
    if (count > 0) {
      final assets = await widget.album.getAssetListRange(start: 0, end: 1);
      cover = assets.isEmpty ? null : assets.first;
    }
    if (!mounted) return;
    setState(() => _cover = cover);
  }

  @override
  Widget build(BuildContext context) {
    final cover = _cover;

    return Material(
      color: Theme.of(context).cardTheme.color,
      shape: Theme.of(context).cardTheme.shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: widget.onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: cover == null
                  ? ColoredBox(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest,
                      child: Icon(
                        Icons.photo_library_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    )
                  : AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Image(
                        key: ValueKey(cover.id),
                        fit: BoxFit.cover,
                        width: double.infinity,
                        height: double.infinity,
                        image: AssetEntityImageProvider(
                          cover,
                          isOriginal: false,
                          thumbnailSize: const ThumbnailSize.square(400),
                        ),
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: Text(
                widget.album.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      height: 1.2,
                      fontSize: 12,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
