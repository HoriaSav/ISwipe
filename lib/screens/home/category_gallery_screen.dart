import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

import '../../models/triage_category.dart';
import '../../providers/app_services.dart';
import '../../services/session_service.dart';
import '../../utils/format_bytes.dart';
import '../../widgets/fade_page_route.dart';
import '../gallery/swipe_sort_screen.dart';

class CategoryGalleryScreen extends StatefulWidget {
  const CategoryGalleryScreen({
    super.key,
    required this.category,
    required this.album,
  });

  final TriageCategoryResult category;
  final AssetPathEntity album;

  @override
  State<CategoryGalleryScreen> createState() => _CategoryGalleryScreenState();
}

class _CategoryGalleryScreenState extends State<CategoryGalleryScreen> {
  static const _pageSize = 60;

  final ScrollController _scrollController = ScrollController();
  final List<AssetEntity> _assets = [];
  final Map<String, int> _fileSizes = {};

  bool _loading = true;
  bool _loadingMore = false;
  int _loadedIds = 0;

  List<String> get _allIds => widget.category.assetIds;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadInitial();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients || _loadingMore || _loadedIds >= _allIds.length) {
      return;
    }
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  Future<void> _loadInitial() async {
    final batch = await context.services.triageDetectionService.loadAssetsByIds(
      _allIds,
      limit: _pageSize,
    );
    if (!mounted) {
      return;
    }
    await _attachSizes(batch);
    setState(() {
      _assets.addAll(batch);
      _loadedIds = batch.length;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _loadedIds >= _allIds.length) {
      return;
    }
    _loadingMore = true;

    final batch = await context.services.triageDetectionService.loadAssetsByIds(
      _allIds,
      offset: _loadedIds,
      limit: _pageSize,
    );

    if (!mounted) {
      return;
    }
    await _attachSizes(batch);
    setState(() {
      _assets.addAll(batch);
      _loadedIds += batch.length;
      _loadingMore = false;
    });
  }

  Future<void> _attachSizes(List<AssetEntity> batch) async {
    if (widget.category.id != TriageCategoryId.largeFiles) {
      return;
    }
    for (final asset in batch) {
      _fileSizes[asset.id] = await asset.fileSize;
    }
  }

  Future<void> _openSwipe(int index) async {
    final session = await SessionService.instance.startOrResumeCategorySession(
      category: widget.category.id.name,
      title: widget.category.title,
      assetIds: _allIds,
      currentIndex: index,
    );

    if (!mounted) {
      return;
    }

    await Navigator.of(context).push<bool>(
      FadePageRoute<bool>(
        page: SwipeSortScreen(
          album: widget.album,
          assets: List<AssetEntity>.from(_assets),
          initialIndex: index,
          totalCount: _allIds.length,
          assetQueueIds: _allIds,
          session: session,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.category.title),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _assets.isEmpty
              ? const Center(child: Text('No photos in this category.'))
              : GridView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: _assets.length + (_loadedIds < _allIds.length ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= _assets.length) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final asset = _assets[index];
                    final size = _fileSizes[asset.id];

                    return Material(
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(12),
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: InkWell(
                        onTap: () => _openSwipe(index),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image(
                              fit: BoxFit.cover,
                              image: AssetEntityImageProvider(
                                asset,
                                isOriginal: false,
                                thumbnailSize: const ThumbnailSize.square(240),
                              ),
                            ),
                            if (size != null)
                              Positioned(
                                left: 6,
                                bottom: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    formatBytes(size),
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
                    );
                  },
                ),
    );
  }
}
