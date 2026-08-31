import 'dart:async';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../../providers/app_services.dart';
import '../../providers/deletion_events.dart';
import '../../services/album_sort_service.dart';
import '../../services/gallery_service.dart';
import '../../services/session_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_page_route.dart';
import '../../widgets/folder_card.dart';
import '../../widgets/reviewed_badge.dart';
import '../settings/settings_screen.dart';
import 'swipe_sort_screen.dart';

class AlbumListScreen extends StatefulWidget {
  const AlbumListScreen({super.key});

  @override
  State<AlbumListScreen> createState() => AlbumListScreenState();
}

class AlbumListScreenState extends State<AlbumListScreen>
    with WidgetsBindingObserver {
  List<AssetPathEntity> _toSortAlbums = [];
  List<AssetPathEntity> _sortedAlbums = [];
  bool _initialLoading = true;
  String? _error;
  int _coverRefreshHint = 0;
  DeletionEvents? _galleryEvents;
  Timer? _refreshDebounce;
  int _reloadSerial = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _galleryEvents = context.read<DeletionEvents>();
      _galleryEvents!.addListener(_onGalleryChanged);
      reload();
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _galleryEvents?.removeListener(_onGalleryChanged);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _scheduleSilentRefresh(refreshCache: true);
    }
  }

  void _onGalleryChanged() {
    _scheduleSilentRefresh(refreshCache: true, bumpCovers: true);
  }

  void _scheduleSilentRefresh({
    bool refreshCache = false,
    bool bumpCovers = false,
  }) {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 450), () {
      reload(silent: true, refreshCache: refreshCache, bumpCovers: bumpCovers);
    });
  }

  Future<void> reload({
    bool silent = false,
    bool refreshCache = false,
    bool bumpCovers = false,
  }) async {
    if (!mounted) return;
    final serial = ++_reloadSerial;

    if (!silent) {
      setState(() {
        _initialLoading = _toSortAlbums.isEmpty && _sortedAlbums.isEmpty;
        _error = null;
      });
    }

    try {
      final partition = await AlbumSortService.instance.loadPartition(
        galleryService: context.galleryService,
        reviewService: context.reviewService,
        refreshCache: refreshCache,
      );
      if (!mounted || serial != _reloadSerial) return;

      setState(() {
        _toSortAlbums = partition.toSort.map((status) => status.album).toList();
        _sortedAlbums = partition.sorted.map((status) => status.album).toList();
        _initialLoading = false;
        if (bumpCovers) {
          _coverRefreshHint++;
        }
        if (_toSortAlbums.isEmpty && _sortedAlbums.isEmpty) {
          _error = 'empty';
        } else {
          _error = null;
        }
      });
    } on GalleryPermissionException catch (error) {
      if (!mounted || serial != _reloadSerial) return;
      setState(() {
        _initialLoading = false;
        _error = _permissionMessage(error.state);
      });
    } catch (error) {
      if (!mounted || serial != _reloadSerial) return;
      setState(() {
        _initialLoading = false;
        if (!silent || (_toSortAlbums.isEmpty && _sortedAlbums.isEmpty)) {
          _error = 'Could not load albums: $error';
        }
      });
    }
  }

  String _permissionMessage(PermissionState state) {
    switch (state) {
      case PermissionState.denied:
        return 'Photo access is required. Tap Retry to grant permission.';
      case PermissionState.restricted:
        return 'Photo access is restricted on this device.';
      case PermissionState.limited:
        return 'Limited photo access granted, but no albums were found. '
            'Try granting access to more photos in system settings.';
      case PermissionState.authorized:
        return 'Permission granted but no albums loaded. Pull down to refresh.';
      case PermissionState.notDetermined:
        return 'Photo permission not determined. Tap Retry.';
    }
  }

  Future<void> _openSettings() async {
    await openAppSettings();
    if (mounted) {
      await reload(refreshCache: true, bumpCovers: true);
    }
  }

  Future<void> _openAlbum(AssetPathEntity album) async {
    await Navigator.of(context).push<void>(
      FadePageRoute<void>(
        page: AlbumGalleryScreen(album: album),
      ),
    );
    if (mounted) {
      await reload(silent: true, bumpCovers: true);
    }
  }

  static const _folderGridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: 3,
    crossAxisSpacing: 12,
    mainAxisSpacing: 12,
    childAspectRatio: 0.76,
  );

  SliverGrid _folderGridSliver(List<AssetPathEntity> albums) {
    return SliverGrid(
      gridDelegate: _folderGridDelegate,
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final album = albums[index];
          return FolderCard(
            key: ValueKey(album.id),
            album: album,
            coverRefreshHint: _coverRefreshHint,
            onTap: () => _openAlbum(album),
          );
        },
        childCount: albums.length,
      ),
    );
  }

  List<Widget> _folderGridSlivers() {
    final hasToSort = _toSortAlbums.isNotEmpty;
    final hasSorted = _sortedAlbums.isNotEmpty;
    final showSections = hasToSort && hasSorted;

    Widget paddedGrid(List<AssetPathEntity> albums) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        sliver: _folderGridSliver(albums),
      );
    }

    return [
      if (showSections)
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              'To sort',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        ),
      if (hasToSort) paddedGrid(_toSortAlbums),
      if (showSections)
        const SliverToBoxAdapter(
          child: _AlbumSectionDivider(label: 'Sorted'),
        ),
      if (hasSorted) paddedGrid(_sortedAlbums),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final hasAlbums = _toSortAlbums.isNotEmpty || _sortedAlbums.isNotEmpty;

    Widget body;
    if (_initialLoading && !hasAlbums) {
      body = const Center(child: CircularProgressIndicator());
    } else if (_error != null && _error != 'empty' && !hasAlbums) {
      body = EmptyStateView(
        icon: Icons.photo_library_outlined,
        title: 'Cannot access photos',
        subtitle: _error,
        action: Column(
          children: [
            FilledButton(
              onPressed: () => reload(refreshCache: true, bumpCovers: true),
              child: const Text('Retry'),
            ),
            TextButton(
              onPressed: _openSettings,
              child: const Text('Open system settings'),
            ),
          ],
        ),
      );
    } else if (!hasAlbums) {
      body = RefreshIndicator(
        onRefresh: () => reload(refreshCache: true, bumpCovers: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyStateView(
                icon: Icons.folder_open_outlined,
                title: 'No folders yet',
                subtitle: 'Add photos to your device, then pull down to refresh.',
              ),
            ),
          ],
        ),
      );
    } else {
      body = RefreshIndicator(
        onRefresh: () => reload(refreshCache: true, bumpCovers: true),
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            const SliverPadding(padding: EdgeInsets.only(top: 8)),
            ..._folderGridSlivers(),
            const SliverPadding(padding: EdgeInsets.only(bottom: 24)),
          ],
        ),
      );
    }

    return body;
  }
}

class _AlbumSectionDivider extends StatelessWidget {
  const _AlbumSectionDivider({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dividerColor = Theme.of(context).colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      child: Row(
        children: [
          Expanded(child: Divider(color: dividerColor)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(child: Divider(color: dividerColor)),
        ],
      ),
    );
  }
}

class AlbumGalleryScreen extends StatefulWidget {
  const AlbumGalleryScreen({
    super.key,
    required this.album,
  });

  final AssetPathEntity album;

  @override
  State<AlbumGalleryScreen> createState() => _AlbumGalleryScreenState();
}

class _AlbumGalleryScreenState extends State<AlbumGalleryScreen> {
  late AssetPathEntity _album;
  final ScrollController _scrollController = ScrollController();
  final List<AssetEntity> _assets = [];
  Set<String> _reviewedIds = {};
  int _totalCount = 0;
  int _nextPage = 0;
  bool _initialLoading = true;
  bool _loadingMore = false;
  bool _prefetchScheduled = false;
  DeletionEvents? _galleryEvents;
  Timer? _refreshDebounce;
  int _reloadSerial = 0;

  bool get _hasMore => _assets.length < _totalCount;

  @override
  void initState() {
    super.initState();
    _album = widget.album;
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _galleryEvents = context.read<DeletionEvents>();
      _galleryEvents!.addListener(_onGalleryChanged);
      _loadGallery();
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _galleryEvents?.removeListener(_onGalleryChanged);
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || !_hasMore) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 480) {
      _loadMoreAssets();
    }
  }

  void _onGalleryChanged() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 450), () {
      _loadGallery(silent: true, refreshCache: true);
    });
  }

  Future<void> _loadGallery({
    bool silent = false,
    bool refreshCache = false,
  }) async {
    if (!mounted) return;
    final serial = ++_reloadSerial;

    if (!silent) {
      setState(() => _initialLoading = _assets.isEmpty);
    }

    final galleryService = context.galleryService;
    final reviewService = context.reviewService;

    if (refreshCache) {
      final refreshed = await galleryService.findAlbumById(
        widget.album.id,
        refreshCache: true,
      );
      if (!mounted || serial != _reloadSerial) return;
      if (refreshed != null) {
        _album = refreshed;
      }
    }

    final results = await Future.wait<Object?>([
      galleryService.loadAssetCount(_album),
      reviewService.reviewedIdsForAlbum(_album.id),
      galleryService.loadAssetsPage(_album, page: 0),
    ]);

    if (!mounted || serial != _reloadSerial) return;

    final totalCount = results[0]! as int;
    final reviewed = results[1]! as Set<String>;
    final firstPage = results[2]! as List<AssetEntity>;

    setState(() {
      _totalCount = totalCount;
      _reviewedIds = reviewed;
      _assets
        ..clear()
        ..addAll(firstPage);
      _nextPage = firstPage.isEmpty ? 0 : 1;
      _initialLoading = false;
      _prefetchScheduled = false;
    });

    _scheduleBackgroundPrefetch(serial);
  }

  void _scheduleBackgroundPrefetch(int serial) {
    if (_prefetchScheduled || !_hasMore) {
      return;
    }
    _prefetchScheduled = true;
    Future<void>(() async {
      while (mounted && serial == _reloadSerial && _hasMore) {
        await _loadMoreAssets(serial: serial);
        await Future<void>.delayed(const Duration(milliseconds: 16));
      }
      if (mounted && serial == _reloadSerial) {
        _prefetchScheduled = false;
      }
    });
  }

  Future<void> _loadMoreAssets({int? serial}) async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    _loadingMore = true;

    try {
      final page = await context.galleryService.loadAssetsPage(
        _album,
        page: _nextPage,
      );

      if (!mounted) {
        return;
      }
      if (serial != null && serial != _reloadSerial) {
        return;
      }
      if (page.isEmpty) {
        setState(() => _totalCount = _assets.length);
        return;
      }

      setState(() {
        _assets.addAll(page);
        _nextPage++;
      });
    } finally {
      _loadingMore = false;
    }
  }

  Future<void> _ensureAssetsThrough(int index) async {
    while (_assets.length <= index && _hasMore && mounted) {
      await _loadMoreAssets();
    }
  }

  Future<void> _openSwipe(int initialIndex) async {
    if (!mounted) return;

    final needsLoad = initialIndex >= _assets.length && _hasMore;
    if (needsLoad) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading photo…'),
                ],
              ),
            ),
          ),
        ),
      );
    }

    await _ensureAssetsThrough(initialIndex);

    if (!mounted) return;
    if (needsLoad) {
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (initialIndex >= _assets.length) {
      return;
    }

    final session = await SessionService.instance.startOrResumeAlbumSession(
      albumId: _album.id,
      albumName: _album.name,
      totalCount: _totalCount,
      currentIndex: initialIndex,
    );

    await Navigator.of(context).push<bool>(
      FadePageRoute<bool>(
        page: SwipeSortScreen(
          album: _album,
          assets: List<AssetEntity>.from(_assets),
          initialIndex: initialIndex,
          totalCount: _totalCount,
          nextPage: _nextPage,
          session: session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _album.name,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () {
              Navigator.of(context).push(
                FadePageRoute<void>(page: const SettingsScreen()),
              );
            },
          ),
        ],
      ),
      body: _initialLoading && _assets.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? const EmptyStateView(
                  icon: Icons.photo_outlined,
                  title: 'This folder is empty',
                  subtitle: 'There are no photos here to sort.',
                )
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _assets.length + (_hasMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _assets.length) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    }

                    final asset = _assets[index];
                    final isReviewed = _reviewedIds.contains(asset.id);

                    return Material(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      clipBehavior: Clip.antiAlias,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: InkWell(
                        onTap: () => _openSwipe(index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image(
                              key: ValueKey(asset.id),
                              image: AssetEntityImageProvider(
                                asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(240),
                              ),
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                            if (isReviewed) const ReviewedBadge(),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
