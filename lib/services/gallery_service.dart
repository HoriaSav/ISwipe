import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:photo_manager/photo_manager.dart';

class GalleryPermissionException implements Exception {
  GalleryPermissionException(this.state);

  final PermissionState state;

  @override
  String toString() => 'Gallery permission not granted ($state)';
}

class GalleryService {
  static const assetPageSize = 120;

  static const _permissionOption = PermissionRequestOption(
    androidPermission: AndroidPermission(
      type: RequestType.image,
      mediaLocation: false,
    ),
  );

  static final _pathListFilter = FilterOptionGroup(
    imageOption: FilterOption(
      sizeConstraint: SizeConstraint(ignoreSize: true),
    ),
    orders: [
      OrderOption(type: OrderOptionType.createDate, asc: false),
    ],
  );

  Future<PermissionState> requestPermission() {
    return PhotoManager.requestPermissionExtend(
      requestOption: _permissionOption,
    );
  }

  Future<PermissionState> currentPermission() {
    return PhotoManager.getPermissionState(
      requestOption: _permissionOption,
    );
  }

  Future<bool> hasPermission() async {
    final state = await currentPermission();
    return state.hasAccess;
  }

  List<AssetPathEntity>? _cachedAlbums;

  Future<List<AssetPathEntity>> _fetchAlbumList() {
    return PhotoManager.getAssetPathList(
      type: RequestType.image,
      hasAll: true,
      filterOption: _pathListFilter,
    );
  }

  Future<List<AssetPathEntity>> _getAlbumList({bool refreshCache = false}) async {
    if (refreshCache) {
      await refreshMediaIndex();
      _cachedAlbums = null;
    }
    _cachedAlbums ??= await _fetchAlbumList();
    return _cachedAlbums!;
  }

  /// Clears cached album/asset handles so lists reflect recent deletes.
  Future<void> refreshMediaIndex() async {
    await PhotoManager.releaseCache();
    _cachedAlbums = null;
  }

  Future<bool> canSkipDeleteConfirmations() async {
    if (!Platform.isAndroid) {
      return true;
    }
    return PhotoManager.canManageMedia();
  }

  Future<bool> openManageMediaSettings() {
    return PhotoManager.requestManageMedia();
  }

  Future<List<AssetPathEntity>> loadAlbums({bool refreshCache = false}) async {
    final permitted = await requestPermission();
    if (!permitted.hasAccess) {
      throw GalleryPermissionException(permitted);
    }

    final albums = await _getAlbumList(refreshCache: refreshCache);

    if (albums.isEmpty) {
      return [];
    }

    final nonEmpty = <AssetPathEntity>[];
    for (final album in albums) {
      final count = await album.assetCountAsync;
      if (count > 0) {
        nonEmpty.add(album);
      }
    }

    return nonEmpty;
  }

  Future<AssetPathEntity?> findAlbumById(
    String albumId, {
    bool refreshCache = false,
  }) async {
    final albums = await _getAlbumList(refreshCache: refreshCache);
    for (final album in albums) {
      if (album.id == albumId) {
        return album;
      }
    }
    return null;
  }

  Future<int> loadAssetCount(AssetPathEntity album) {
    return album.assetCountAsync;
  }

  Future<List<AssetEntity>> loadAssetsPage(
    AssetPathEntity album, {
    required int page,
    int size = assetPageSize,
  }) {
    return album.getAssetListPaged(page: page, size: size);
  }

  Future<List<AssetEntity>> loadAssets(
    AssetPathEntity album, {
    bool refreshCache = false,
  }) async {
    final resolved = refreshCache
        ? await findAlbumById(album.id, refreshCache: true)
        : album;
    if (resolved == null) {
      return [];
    }

    final count = await resolved.assetCountAsync;
    if (count == 0) {
      return [];
    }

    final assets = <AssetEntity>[];
    var page = 0;
    while (assets.length < count) {
      final batch = await loadAssetsPage(resolved, page: page);
      if (batch.isEmpty) {
        break;
      }
      assets.addAll(batch);
      page++;
    }
    return assets;
  }

  Future<bool> moveToTrash(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return false;
    }

    try {
      if (Platform.isAndroid) {
        final trashed = await PhotoManager.editor.android.moveToTrash(assets);
        return trashed.isNotEmpty;
      }

      if (Platform.isIOS) {
        final ids = assets.map((asset) => asset.id).toList();
        final trashed = await PhotoManager.editor.deleteWithIds(ids);
        return trashed.isNotEmpty;
      }
    } catch (error, stackTrace) {
      debugPrint('moveToTrash failed: $error\n$stackTrace');
    }

    return false;
  }

  Future<bool> restoreFromTrash(List<AssetEntity> assets) async {
    if (assets.isEmpty) {
      return false;
    }

    try {
      if (Platform.isAndroid) {
        final restored =
            await PhotoManager.editor.android.restoreFromTrash(assets);
        return restored.isNotEmpty;
      }

      return false;
    } catch (error, stackTrace) {
      debugPrint('restoreFromTrash failed: $error\n$stackTrace');
    }

    return false;
  }
}
