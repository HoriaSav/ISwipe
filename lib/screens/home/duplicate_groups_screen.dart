import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../models/triage_category.dart';
import '../../providers/app_services.dart';
import '../../services/session_service.dart';
import '../../utils/format_bytes.dart';
import '../../widgets/fade_page_route.dart';
import '../gallery/swipe_sort_screen.dart';

class DuplicateGroupsScreen extends StatefulWidget {
  const DuplicateGroupsScreen({
    super.key,
    required this.category,
    required this.album,
  });

  final TriageCategoryResult category;
  final AssetPathEntity album;

  @override
  State<DuplicateGroupsScreen> createState() => _DuplicateGroupsScreenState();
}

class _DuplicateGroupsScreenState extends State<DuplicateGroupsScreen> {
  late List<List<String>> _groups;
  bool _reconciling = false;

  @override
  void initState() {
    super.initState();
    _groups = List<List<String>>.from(widget.category.duplicateGroups);
    WidgetsBinding.instance.addPostFrameCallback((_) => _reconcileGroups());
  }

  Future<void> _reconcileGroups() async {
    if (_reconciling || !mounted) {
      return;
    }
    setState(() => _reconciling = true);

    final updated = await context.services.triageDetectionService
        .reconcileDuplicateGroups(_groups);

    if (!mounted) {
      return;
    }
    setState(() {
      _groups = updated;
      _reconciling = false;
    });
  }

  Future<void> _openGroup(int groupIndex, {int startCopyIndex = 0}) async {
    final groupIds = _groups[groupIndex];
    if (groupIds.isEmpty || !mounted) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    final assets =
        await context.services.triageDetectionService.loadAssetsForGroup(groupIds);

    if (!mounted) {
      return;
    }
    Navigator.of(context, rootNavigator: true).pop();

    if (assets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load these photos.')),
      );
      return;
    }

    final initialIndex = startCopyIndex.clamp(0, assets.length - 1);

    final session = await SessionService.instance.startOrResumeCategorySession(
      category: '${widget.category.id.name}:group:$groupIndex',
      title: 'Duplicate group ${groupIndex + 1}',
      assetIds: assets.map((asset) => asset.id).toList(),
      currentIndex: initialIndex,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<bool>(
      FadePageRoute<bool>(
        page: SwipeSortScreen(
          album: widget.album,
          assets: assets,
          initialIndex: initialIndex,
          totalCount: assets.length,
          assetQueueIds: groupIds,
          session: session,
        ),
      ),
    );

    if (mounted) {
      await _reconcileGroups();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duplicates'),
      ),
      body: _reconciling && _groups.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _groups.isEmpty
          ? Center(
              child: Text(
                'No duplicate groups left.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _groups.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Text(
                    'Identical copies of the same image — often with the same filename. '
                    'Tap a copy to review it first; compare date and folder, keep one, delete the rest.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  );
                }
                final groupIndex = index - 1;
                return _DuplicateGroupCard(
                  groupIds: _groups[groupIndex],
                  groupNumber: groupIndex + 1,
                  onCopyTap: (copyIndex) => _openGroup(groupIndex, startCopyIndex: copyIndex),
                );
              },
            ),
    );
  }
}

class _DuplicateGroupCard extends StatelessWidget {
  const _DuplicateGroupCard({
    required this.groupIds,
    required this.groupNumber,
    required this.onCopyTap,
  });

  final List<String> groupIds;
  final int groupNumber;
  final ValueChanged<int> onCopyTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Group $groupNumber · ${groupIds.length} photos',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                for (var i = 0; i < groupIds.length && i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _DuplicatePhotoTile(
                      assetId: groupIds[i],
                      copyNumber: i + 1,
                      onTap: () => onCopyTap(i),
                    ),
                  ),
                ],
                if (groupIds.length > 3)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton(
                      onPressed: () => onCopyTap(0),
                      child: Text('+${groupIds.length - 3} more'),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DuplicatePhotoTile extends StatelessWidget {
  const _DuplicatePhotoTile({
    required this.assetId,
    required this.copyNumber,
    required this.onTap,
  });

  final String assetId;
  final int copyNumber;
  final VoidCallback onTap;

  Future<_DuplicateDetails> _loadDetails(AssetEntity asset) async {
    final title = await asset.titleAsync;
    final fileSize = await asset.fileSize;
    var folderPath = asset.relativePath;
    if (folderPath == null || folderPath.isEmpty) {
      final file = await asset.originFile;
      if (file != null) {
        folderPath = file.parent.path;
      }
    }
    return _DuplicateDetails(
      title: title,
      fileSize: fileSize,
      folderPath: folderPath,
      created: asset.createDateTime,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(assetId),
      builder: (context, snapshot) {
        final asset = snapshot.data;
        if (asset == null) {
          return AspectRatio(
            aspectRatio: 1,
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          );
        }

        return FutureBuilder<_DuplicateDetails>(
          future: _loadDetails(asset),
          builder: (context, detailsSnapshot) {
            final details = detailsSnapshot.data;
            final dateLabel = details == null
                ? null
                : DateFormat.yMMMd().add_jm().format(details.created);

            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image(
                              fit: BoxFit.cover,
                              image: AssetEntityImageProvider(
                                asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(240),
                              ),
                            ),
                          ),
                          Positioned(
                            top: 6,
                            left: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.65),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Copy $copyNumber',
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall
                                    ?.copyWith(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      details?.title ?? asset.title ?? 'Photo',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    if (details != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '$dateLabel · ${formatBytes(details.fileSize)}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                              fontSize: 10,
                              height: 1.25,
                            ),
                      ),
                      if (details.folderPath != null &&
                          details.folderPath!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          details.folderPath!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style:
                              Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    fontSize: 10,
                                    height: 1.25,
                                  ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _DuplicateDetails {
  const _DuplicateDetails({
    required this.title,
    required this.fileSize,
    required this.created,
    this.folderPath,
  });

  final String title;
  final int fileSize;
  final DateTime created;
  final String? folderPath;
}
