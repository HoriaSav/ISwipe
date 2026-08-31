import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../providers/app_services.dart';
import '../../services/review_service.dart';
import '../../utils/format_bytes.dart';

class ReviewCommitScreen extends StatefulWidget {
  const ReviewCommitScreen({super.key});

  @override
  State<ReviewCommitScreen> createState() => _ReviewCommitScreenState();
}

class _ReviewCommitScreenState extends State<ReviewCommitScreen> {
  late List<PendingDelete> _items;
  bool _committing = false;

  @override
  void initState() {
    super.initState();
    _items = List<PendingDelete>.from(context.reviewService.pendingDeletes);
  }

  int get _totalBytes => _items.fold<int>(
        0,
        (sum, item) => sum + (item.fileSizeBytes ?? 0),
      );

  Future<void> _remove(PendingDelete item) async {
    await context.reviewService.removePendingDelete(item.asset.id);
    setState(() {
      _items.removeWhere((entry) => entry.asset.id == item.asset.id);
    });
  }

  Future<void> _commit() async {
    setState(() => _committing = true);
    final result = await context.reviewService.flushPendingDeletes();
    if (!mounted) {
      return;
    }
    if (!result.success) {
      setState(() => _committing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Delete cancelled. Photos were kept.')),
      );
      return;
    }

    await context.reviewService.completeSession();
    if (!mounted) {
      return;
    }
    Navigator.of(context).pop(
      ReviewCommitResult(
        appliedCount: result.appliedCount,
        bytesRecovered: result.bytesRecovered,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review deletes'),
      ),
      body: _items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle_outline, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Nothing queued for deletion',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            )
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${_items.length} photo${_items.length == 1 ? '' : 's'} selected',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Recover ${formatBytes(_totalBytes)} if deleted',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.info_outline),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image(
                              image: AssetEntityImageProvider(
                                item.asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(240),
                              ),
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: IconButton.filledTonal(
                              style: IconButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: Theme.of(context)
                                    .colorScheme
                                    .surface
                                    .withValues(alpha: 0.92),
                              ),
                              onPressed: _committing
                                  ? null
                                  : () => _remove(item),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                SafeArea(
                  minimum: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      FilledButton(
                        onPressed: _committing ? null : _commit,
                        child: _committing
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(
                                'Move ${_items.length} to trash',
                              ),
                      ),
                      TextButton(
                        onPressed: _committing
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Keep all for now'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class ReviewCommitResult {
  const ReviewCommitResult({
    required this.appliedCount,
    required this.bytesRecovered,
  });

  final int appliedCount;
  final int bytesRecovered;
}
