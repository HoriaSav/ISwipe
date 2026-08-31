import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../../models/album_sort_status.dart';
import '../../models/cleanup_session.dart';
import '../../models/triage_category.dart';
import '../../providers/app_services.dart';
import '../../providers/deletion_events.dart';
import '../../services/album_sort_service.dart';
import '../../services/session_service.dart';
import '../../utils/format_bytes.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_page_route.dart';
import '../gallery/swipe_sort_screen.dart';
import 'category_gallery_screen.dart';
import 'duplicate_groups_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.onBrowseFolders,
  });

  final VoidCallback? onBrowseFolders;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  LibraryStats? _libraryStats;
  List<TriageCategoryResult> _categories = [];
  List<AlbumSortStatus> _albumsToSort = [];
  bool _loading = true;
  bool _scanning = false;
  bool _smartCleanupBusy = false;
  double _scanProgress = 0;
  DeletionEvents? _events;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _events = context.read<DeletionEvents>();
      _events!.addListener(_onChanged);
      reload();
    });
  }

  @override
  void dispose() {
    _events?.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    reload(silent: true);
  }

  Future<void> reload({bool silent = false}) async {
    if (!mounted) {
      return;
    }
    if (!silent) {
      setState(() => _loading = _libraryStats == null);
    }

    final triage = context.services.triageDetectionService;
    final partition = await AlbumSortService.instance.loadPartition(
      galleryService: context.galleryService,
      reviewService: context.reviewService,
    );
    final stats = await triage.loadLibraryStats();
    final categories = await triage.loadCachedCategories();

    if (!mounted) {
      return;
    }

    setState(() {
      _libraryStats = stats;
      _categories = categories;
      _albumsToSort = partition.toSort;
      _loading = false;
    });
  }

  Future<void> _runScan() async {
    if (_scanning) {
      return;
    }
    setState(() {
      _scanning = true;
      _scanProgress = 0;
    });

    final categories = await context.services.triageDetectionService.scanLibrary(
      onProgress: (value) {
        if (mounted) {
          setState(() => _scanProgress = value);
        }
      },
    );

    if (!mounted) {
      return;
    }
    setState(() {
      _categories = categories;
      _scanning = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Good morning';
    }
    if (hour < 18) {
      return 'Good afternoon';
    }
    return 'Good evening';
  }

  void _openBrowseFolders() {
    widget.onBrowseFolders?.call();
  }

  Future<void> _openAlbumToSort(AlbumSortStatus status) async {
    final album = status.album;
    final assets = await context.galleryService.loadAssetsPage(album, page: 0);
    if (!mounted || assets.isEmpty && status.totalCount > 0) {
      return;
    }

    final session = status.session ??
        await SessionService.instance.startOrResumeAlbumSession(
          albumId: album.id,
          albumName: album.name,
          totalCount: status.totalCount,
        );

    final initialIndex = status.session != null
        ? status.session!.currentIndex.clamp(
            0,
            assets.isEmpty ? 0 : assets.length - 1,
          )
        : 0;

    await _pushSwipe(
      album: album,
      assets: assets,
      initialIndex: initialIndex,
      totalCount: status.totalCount,
      session: session,
    );
  }

  String _continueSubtitle(AlbumSortStatus status) {
    if (status.reviewedCount == 0) {
      return '${status.totalCount} photos';
    }
    return '${status.reviewedCount} / ${status.totalCount} reviewed · ${status.progressPercent}%';
  }

  Future<void> _openCategory(TriageCategoryResult category) async {
    if (_scanning) {
      _showMessage('Please wait for the library scan to finish.');
      return;
    }

    if (category.count == 0 && category.groupCount == 0) {
      _showMessage('No ${category.title.toLowerCase()} found.');
      return;
    }

    final albums = await context.galleryService.loadAlbums();
    if (albums.isEmpty || !mounted) {
      return;
    }

    final album = albums.first;

    if (category.id == TriageCategoryId.duplicates) {
      if (category.duplicateGroups.isEmpty) {
        _showMessage('No duplicate groups found. Pull down to rescan.');
        return;
      }

      await Navigator.of(context).push<void>(
        FadePageRoute<void>(
          page: DuplicateGroupsScreen(
            category: category,
            album: album,
          ),
        ),
      );
      if (mounted) {
        await reload(silent: true);
      }
      return;
    }

    await Navigator.of(context).push<void>(
      FadePageRoute<void>(
        page: CategoryGalleryScreen(
          category: category,
          album: album,
        ),
      ),
    );

    if (mounted) {
      await reload(silent: true);
    }
  }

  Future<void> _pushSwipe({
    required AssetPathEntity album,
    required List<AssetEntity> assets,
    required int initialIndex,
    required int totalCount,
    required CleanupSession session,
  }) async {
    await Navigator.of(context).push<bool>(
      FadePageRoute<bool>(
        page: SwipeSortScreen(
          album: album,
          assets: assets,
          initialIndex: initialIndex,
          totalCount: totalCount,
          session: session,
        ),
      ),
    );
    if (mounted) {
      await reload(silent: true);
    }
  }

  TriageCategoryResult? _bestCleanupCategory() {
    if (_categories.isEmpty) {
      return null;
    }
    final sorted = List<TriageCategoryResult>.from(_categories)
      ..sort((a, b) {
        final aScore = a.id == TriageCategoryId.duplicates ? a.groupCount : a.count;
        final bScore = b.id == TriageCategoryId.duplicates ? b.groupCount : b.count;
        return bScore.compareTo(aScore);
      });

    for (final category in sorted) {
      final score = category.id == TriageCategoryId.duplicates
          ? category.groupCount
          : category.count;
      if (score > 0) {
        return category;
      }
    }
    return null;
  }

  Future<void> _startSmartCleanup() async {
    if (_scanning || _smartCleanupBusy) {
      _showMessage('Please wait for the current scan to finish.');
      return;
    }

    setState(() => _smartCleanupBusy = true);

    try {
      if (_categories.isEmpty) {
        await _runScan();
      }

      if (!mounted) {
        return;
      }

      final best = _bestCleanupCategory();
      if (best == null) {
        _showMessage(
          'Nothing to clean up yet. Scan your library or browse folders manually.',
        );
        return;
      }

      await _openCategory(best);
    } finally {
      if (mounted) {
        setState(() => _smartCleanupBusy = false);
      }
    }
  }

  IconData _iconFor(TriageCategoryId id) {
    switch (id) {
      case TriageCategoryId.duplicates:
        return Icons.copy_all_outlined;
      case TriageCategoryId.screenshots:
        return Icons.mobile_screen_share_outlined;
      case TriageCategoryId.largeFiles:
        return Icons.sd_storage_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final stats = _libraryStats ?? const LibraryStats(photoCount: 0, videoCount: 0);
    final hasCachedScan = _categories.isNotEmpty;

    return RefreshIndicator(
      onRefresh: () async {
        await _runScan();
        await reload(silent: true);
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          Text(
            _greeting(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Your photos never leave this device.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Your library',
                          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${stats.photoCount} photos',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: _openBrowseFolders,
                    child: const Text('Browse folders'),
                  ),
                ],
              ),
            ),
          ),
          if (_scanning) ...[
            const SizedBox(height: 20),
            Text(
              'Scanning library… ${(_scanProgress * 100).round()}%',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: _scanProgress > 0 ? _scanProgress : null,
            ),
          ] else if (!hasCachedScan) ...[
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _runScan,
              icon: const Icon(Icons.search),
              label: const Text('Scan library'),
            ),
          ],
          const SizedBox(height: 24),
          Text(
            'Potential cleanup',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            hasCachedScan
                ? 'Pull down to refresh scan results.'
                : 'Scan your library to find duplicates, screenshots, and large files.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          if (!hasCachedScan && !_scanning)
            const EmptyStateView(
              icon: Icons.search_outlined,
              title: 'No scan results yet',
              subtitle: 'Tap Scan library or pull down to analyze your photos.',
            )
          else if (_categories.isEmpty && !_scanning)
            const EmptyStateView(
              icon: Icons.check_circle_outline,
              title: 'Library looks clean',
              subtitle: 'No duplicates, screenshots, or large files were found.',
            )
          else
            ..._categories.map(
              (category) => _CategoryTile(
                icon: _iconFor(category.id),
                title: category.title,
                countLabel: category.countLabel,
                sizeLabel: category.totalBytes > 0
                    ? formatBytes(category.totalBytes)
                    : null,
                onTap: (category.count > 0 || category.groupCount > 0)
                    ? () => _openCategory(category)
                    : null,
              ),
            ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: (_scanning || _smartCleanupBusy) ? null : _startSmartCleanup,
            child: _smartCleanupBusy
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Start Smart Cleanup'),
          ),
          const SizedBox(height: 8),
          Text(
            'Opens the best cleanup category first — duplicates, then screenshots, then large files.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
            textAlign: TextAlign.center,
          ),
          if (_albumsToSort.isNotEmpty) ...[
            const SizedBox(height: 28),
            Text(
              'Continue',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Folders not fully sorted yet.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 12),
            ..._albumsToSort.map(
              (status) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: const Icon(Icons.folder_outlined),
                  title: Text(status.album.name),
                  subtitle: Text(_continueSubtitle(status)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openAlbumToSort(status),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.icon,
    required this.title,
    required this.countLabel,
    this.sizeLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String countLabel;
  final String? sizeLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: sizeLabel != null ? Text('~$sizeLabel recoverable') : null,
        trailing: Text(
          countLabel,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        enabled: onTap != null,
        onTap: onTap,
      ),
    );
  }
}
