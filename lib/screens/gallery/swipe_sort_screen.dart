import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../../models/cleanup_session.dart';
import '../../models/session_decision.dart';
import '../../services/gallery_service.dart';
import '../../providers/app_services.dart';
import '../../screens/review/review_commit_screen.dart';
import '../../theme/app_theme.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/preview_bar.dart';
import '../../widgets/session_history_sheet.dart';
import '../../widgets/swipe_card.dart';

class SwipeSortScreen extends StatefulWidget {
  const SwipeSortScreen({
    super.key,
    required this.album,
    required this.assets,
    required this.initialIndex,
    this.totalCount,
    this.nextPage = 1,
    this.session,
    this.assetQueueIds,
  });

  final AssetPathEntity album;
  final List<AssetEntity> assets;
  final int initialIndex;
  final int? totalCount;
  final int nextPage;
  final CleanupSession? session;
  /// When set, pagination loads from this ID list (category/duplicate queues)
  /// instead of the next page of the whole album.
  final List<String>? assetQueueIds;

  @override
  State<SwipeSortScreen> createState() => _SwipeSortScreenState();
}

class _SwipeSortScreenState extends State<SwipeSortScreen> {
  late List<AssetEntity> _assets;
  late int _currentIndex;
  late int _nextPage;
  late int _totalCount;
  bool _busy = false;
  bool _loadingMore = false;
  bool _changed = false;
  String? _message;

  bool get _usesQueue => widget.assetQueueIds != null;

  bool get _hasMore => _assets.length < _totalCount;

  @override
  void initState() {
    super.initState();
    _assets = List<AssetEntity>.from(widget.assets);
    _currentIndex = widget.initialIndex.clamp(
      0,
      _assets.isEmpty ? 0 : _assets.length - 1,
    );
    _totalCount = _usesQueue
        ? widget.assetQueueIds!.length
        : (widget.totalCount ?? _assets.length);
    _nextPage = _initialNextPage();
    if (widget.session != null) {
      context.reviewService.beginSession(widget.session!);
    } else {
      context.reviewService.beginDeleteSession();
    }
    _maybePrefetch();
  }

  int _initialNextPage() {
    if (_usesQueue) {
      return 0;
    }
    final pagesAlreadyLoaded =
        (_assets.length / GalleryService.assetPageSize).ceil();
    return pagesAlreadyLoaded > widget.nextPage
        ? pagesAlreadyLoaded
        : widget.nextPage;
  }

  Future<void> _loadNextPage() async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    _loadingMore = true;
    try {
      final List<AssetEntity> page;
      if (_usesQueue) {
        page = await context.services.triageDetectionService.loadAssetsByIds(
          widget.assetQueueIds!,
          offset: _assets.length,
          limit: GalleryService.assetPageSize,
        );
      } else {
        page = await context.galleryService.loadAssetsPage(
          widget.album,
          page: _nextPage,
        );
        _nextPage++;
      }

      if (!mounted) {
        return;
      }

      if (page.isEmpty) {
        setState(() => _totalCount = _assets.length);
        return;
      }

      final existingIds = _assets.map((asset) => asset.id).toSet();
      final fresh = page.where((asset) => !existingIds.contains(asset.id)).toList();

      setState(() {
        _assets.addAll(fresh);
        if (fresh.isEmpty) {
          _totalCount = _assets.length;
        }
      });

      if (fresh.isEmpty && _hasMore && !_usesQueue) {
        await _loadNextPage();
      }
    } finally {
      _loadingMore = false;
    }
  }

  void _maybePrefetch() {
    if (!_hasMore || _loadingMore) {
      return;
    }
    if (_currentIndex >= _assets.length - 15) {
      _loadNextPage();
    }
  }

  AssetEntity? get _currentAsset {
    if (_currentIndex < 0 || _currentIndex >= _assets.length) {
      return null;
    }
    return _assets[_currentIndex];
  }

  int get _pendingCount => context.reviewService.pendingDeleteCount;

  Future<void> _handleSwipe(SwipeDirection direction) async {
    final asset = _currentAsset;
    if (asset == null || _busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    if (direction == SwipeDirection.right) {
      await context.reviewService.markKept(
        asset,
        widget.album.id,
        notifyGallery: false,
        originalIndex: _currentIndex,
      );
      _changed = true;
      _consumeCurrentAsset();
    } else {
      final queued = await context.reviewService.queueDelete(
        asset: asset,
        albumId: widget.album.id,
        albumName: widget.album.name,
        originalIndex: _currentIndex,
      );

      if (!queued) {
        setState(() {
          _busy = false;
          _message = 'Could not queue image for delete.';
        });
        return;
      }

      _changed = true;
      _consumeCurrentAsset();
    }
  }

  Future<void> _markLater() async {
    final asset = _currentAsset;
    if (asset == null || _busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    await context.reviewService.markLater(
      asset: asset,
      albumId: widget.album.id,
      albumName: widget.album.name,
      originalIndex: _currentIndex,
    );
    _changed = true;
    _consumeCurrentAsset();
  }

  Future<void> _markFavorite() async {
    final asset = _currentAsset;
    if (asset == null || _busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    await context.reviewService.markFavorite(
      asset,
      widget.album.id,
      originalIndex: _currentIndex,
    );
    _changed = true;
    _consumeCurrentAsset();
  }

  void _consumeCurrentAsset() {
    if (!mounted) {
      return;
    }

    setState(() {
      if (_currentIndex >= 0 && _currentIndex < _assets.length) {
        _assets.removeAt(_currentIndex);
      }
      if (_currentIndex >= _assets.length && _assets.isNotEmpty) {
        _currentIndex = _assets.length - 1;
      }
      _busy = false;
    });

    if (_assets.isEmpty) {
      _ensureDeckHasPhotos();
      return;
    }

    _maybePrefetch();
  }

  Future<void> _ensureDeckHasPhotos() async {
    if (_hasMore) {
      await _loadNextPage();
      if (!mounted) {
        return;
      }
      if (_assets.isNotEmpty) {
        setState(() {
          _currentIndex = _currentIndex.clamp(0, _assets.length - 1);
        });
        _maybePrefetch();
        return;
      }
    }

    if (mounted) {
      await _close();
    }
  }

  Future<void> _undo() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    final pending = await context.reviewService.undoPendingDelete();
    if (pending == null) {
      setState(() {
        _busy = false;
        _message = 'Nothing to undo.';
      });
      return;
    }

    setState(() {
      final insertAt = pending.originalIndex.clamp(0, _assets.length);
      _assets.insert(insertAt, pending.asset);
      _currentIndex = insertAt;
      _busy = false;
      _message = null;
    });
  }

  Future<void> _undoDecision(SessionDecision decision) async {
    if (_busy) return;
    setState(() => _busy = true);

    final undone = await context.reviewService.undoDecision(decision.id);
    if (undone == null) {
      setState(() {
        _busy = false;
        _message = 'Could not undo that decision.';
      });
      return;
    }

    if (undone.decision == DecisionType.delete) {
      final asset = await AssetEntity.fromId(undone.assetId);
      if (asset != null) {
        final insertAt = undone.originalIndex.clamp(0, _assets.length);
        setState(() {
          _assets.insert(insertAt, asset);
          _currentIndex = insertAt;
          _busy = false;
        });
        return;
      }
    }

    setState(() => _busy = false);
  }

  Future<void> _close() async {
    if (_busy) return;

    setState(() {
      _busy = true;
      _message = null;
    });

    final pending = _pendingCount;
    if (pending > 0) {
      if (!mounted) {
        return;
      }
      final result = await Navigator.of(context).push<ReviewCommitResult>(
        FadePageRoute<ReviewCommitResult>(
          page: const ReviewCommitScreen(),
        ),
      );

      if (!mounted) {
        return;
      }

      if (result == null) {
        setState(() => _busy = false);
        return;
      }

      if (_changed) {
        context.reviewService.notifyGalleryChanged();
      }

      Navigator.of(context).pop(_changed);
      return;
    }

    if (_changed) {
      context.reviewService.notifyGalleryChanged();
    }

    if (mounted) {
      Navigator.of(context).pop(_changed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final asset = _currentAsset;
    final pending = _pendingCount;
    final session = context.reviewService.activeSession ?? widget.session;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _close();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            session?.title ?? widget.album.name,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          actions: [
            IconButton(
              tooltip: 'Session history',
              icon: const Icon(Icons.history),
              onPressed: _busy
                  ? null
                  : () => showSessionHistorySheet(
                        context,
                        onUndo: _undoDecision,
                      ),
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (session != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                  child: LinearProgressIndicator(
                    value: session.progress,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              PreviewBar(
                assets: _assets,
                currentIndex: _currentIndex,
              ),
              if (pending > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.delete.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      pending == 1
                          ? '1 photo queued — review when you close'
                          : '$pending photos queued — review when you close',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.delete,
                            fontWeight: FontWeight.w500,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              if (_message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    _message!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                    textAlign: TextAlign.center,
                  ),
                ),
              Expanded(
                child: asset == null
                    ? Center(
                        child: pending > 0
                            ? Text(
                                'Tap close to review $pending photo(s)',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                textAlign: TextAlign.center,
                              )
                            : Text(
                                'All done!',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                      )
                    : Padding(
                        padding: const EdgeInsets.all(16),
                        child: SwipeCard(
                          key: ValueKey(asset.id),
                          asset: asset,
                          onSwipe: _handleSwipe,
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton.icon(
                      onPressed: _busy ? null : _markLater,
                      icon: const Icon(Icons.schedule_outlined),
                      label: const Text('Later'),
                    ),
                    TextButton.icon(
                      onPressed: _busy ? null : _markFavorite,
                      icon: const Icon(Icons.star_outline),
                      label: const Text('Favorite'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _ActionChip(
                      icon: Icons.close_rounded,
                      label: 'Delete',
                      color: AppTheme.delete,
                      onPressed: _busy ? null : () => _handleSwipe(SwipeDirection.left),
                    ),
                    FilledButton.tonal(
                      onPressed: _busy ? null : _undo,
                      child: const Icon(Icons.undo_rounded),
                    ),
                    _ActionChip(
                      icon: Icons.check_rounded,
                      label: 'Keep',
                      color: AppTheme.keep,
                      onPressed: _busy ? null : () => _handleSwipe(SwipeDirection.right),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: TextButton(
                  onPressed: _busy ? null : _close,
                  child: Text(
                    pending > 0 ? 'Close & review deletes' : 'Close',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton.filled(
          onPressed: onPressed,
          icon: Icon(icon),
          color: Colors.white,
          style: IconButton.styleFrom(backgroundColor: color),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}
