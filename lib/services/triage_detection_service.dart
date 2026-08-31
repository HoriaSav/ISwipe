import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:photo_manager/photo_manager.dart';

import '../models/triage_category.dart';
import 'database_service.dart';
import 'gallery_service.dart';

class TriageDetectionService {
  TriageDetectionService(this._galleryService);

  final GalleryService _galleryService;
  final DatabaseService _db = DatabaseService.instance;

  static const largeFileThresholdBytes = 5 * 1024 * 1024;
  static const _iosScreenshotSubtype = 4;
  static const _fileSizeBatchSize = 20;
  static const _hashBatchSize = 8;

  bool _scanning = false;
  bool get isScanning => _scanning;

  Future<LibraryStats> loadLibraryStats() async {
    final albums = await _galleryService.loadAlbums();
    if (albums.isEmpty) {
      return const LibraryStats(photoCount: 0, videoCount: 0);
    }
    final primary = albums.first;
    final photos = await primary.assetCountAsync;
    return LibraryStats(photoCount: photos, videoCount: 0);
  }

  Future<List<TriageCategoryResult>> loadCachedCategories() async {
    final results = <TriageCategoryResult>[];
    for (final id in TriageCategoryId.values) {
      final cache = await _db.getTriageCache(id.name);
      if (cache == null) {
        continue;
      }
      final ids = _parseIds(cache['asset_ids_json'] as String?);
      final groups = _parseGroups(cache['groups_json'] as String?);
      results.add(
        TriageCategoryResult(
          id: id,
          title: _titleFor(id),
          assetIds: ids,
          duplicateGroups: groups,
          totalBytes: (cache['total_bytes'] as num?)?.toInt() ?? 0,
          scannedAt: DateTime.parse(cache['scanned_at'] as String),
        ),
      );
    }
    return results;
  }

  Future<List<TriageCategoryResult>> scanLibrary({
    void Function(double)? onProgress,
  }) async {
    if (_scanning) {
      return loadCachedCategories();
    }
    _scanning = true;

    try {
      final albums = await _galleryService.loadAlbums();
      if (albums.isEmpty) {
        return [];
      }

      final primary = albums.first;
      final total = await primary.assetCountAsync;
      if (total == 0) {
        return [];
      }

      final screenshotIds = <String>[];
      final largeFileIds = <String>[];
      final fileSizes = <String, int>{};
      final dimBuckets = <String, List<AssetEntity>>{};
      final allAssets = <AssetEntity>[];

      var processed = 0;
      var page = 0;

      while (processed < total) {
        final batch = await _galleryService.loadAssetsPage(
          primary,
          page: page,
        );
        if (batch.isEmpty) {
          break;
        }

        allAssets.addAll(batch);
        for (final asset in batch) {
          processed++;
          if (processed % 80 == 0 || processed == total) {
            onProgress?.call(processed / total * 0.55);
          }

          if (_isScreenshot(asset, primary.name)) {
            screenshotIds.add(asset.id);
          }

          final dimKey = '${asset.width}x${asset.height}';
          dimBuckets.putIfAbsent(dimKey, () => []).add(asset);
        }

        page++;
      }

      onProgress?.call(0.6);

      final duplicateCandidates = <AssetEntity>{};
      for (final bucket in dimBuckets.values) {
        if (bucket.length >= 2) {
          duplicateCandidates.addAll(bucket);
        }
      }

      await _fillFileSizes(duplicateCandidates.toList(), fileSizes, largeFileIds);
      onProgress?.call(0.78);

      final duplicateGroups =
          await _findDuplicateGroups(dimBuckets, fileSizes, duplicateCandidates);
      onProgress?.call(0.88);

      await _fillFileSizes(allAssets, fileSizes, largeFileIds);
      final duplicateIds = duplicateGroups.expand((group) => group).toList();

      var duplicateBytes = 0;
      for (final id in duplicateIds) {
        duplicateBytes += fileSizes[id] ?? 0;
      }

      var screenshotBytes = 0;
      for (final id in screenshotIds) {
        screenshotBytes += fileSizes[id] ?? 0;
      }

      var largeBytes = 0;
      for (final id in largeFileIds) {
        largeBytes += fileSizes[id] ?? 0;
      }

      largeFileIds.sort(
        (a, b) => (fileSizes[b] ?? 0).compareTo(fileSizes[a] ?? 0),
      );

      await _db.saveTriageCache(
        category: TriageCategoryId.duplicates.name,
        assetIds: duplicateIds,
        totalBytes: duplicateBytes,
        groupsJson: _encodeGroups(duplicateGroups),
      );
      await _db.saveTriageCache(
        category: TriageCategoryId.screenshots.name,
        assetIds: screenshotIds,
        totalBytes: screenshotBytes,
      );
      await _db.saveTriageCache(
        category: TriageCategoryId.largeFiles.name,
        assetIds: largeFileIds,
        totalBytes: largeBytes,
      );

      onProgress?.call(1);
      return loadCachedCategories();
    } finally {
      _scanning = false;
    }
  }

  Future<List<AssetEntity>> loadAssetsByIds(
    List<String> ids, {
    int offset = 0,
    int limit = 60,
  }) async {
    if (ids.isEmpty || offset >= ids.length) {
      return [];
    }

    final slice = ids.skip(offset).take(limit).toList();
    final assets = <AssetEntity>[];
    for (var i = 0; i < slice.length; i += _fileSizeBatchSize) {
      final chunk = slice.skip(i).take(_fileSizeBatchSize).toList();
      final loaded = await Future.wait(chunk.map(AssetEntity.fromId));
      assets.addAll(loaded.whereType<AssetEntity>());
    }
    return assets;
  }

  Future<List<AssetEntity>> loadAssetsForGroup(List<String> ids) {
    return loadAssetsByIds(ids, limit: ids.length);
  }

  /// Drops deleted/missing assets from duplicate groups, removes groups with
  /// fewer than two survivors, and writes the updated groups back to cache.
  Future<List<List<String>>> reconcileDuplicateGroups(
    List<List<String>> groups,
  ) async {
    if (groups.isEmpty) {
      return const [];
    }

    final reconciled = <List<String>>[];
    var totalBytes = 0;

    for (final group in groups) {
      final surviving = await _filterExistingAssetIds(group);
      if (surviving.length < 2) {
        continue;
      }

      reconciled.add(surviving);
      for (final id in surviving) {
        final asset = await AssetEntity.fromId(id);
        if (asset == null) {
          continue;
        }
        try {
          totalBytes += await asset.fileSize;
        } catch (_) {
          // Skip unreadable sizes.
        }
      }
    }

    final cache = await _db.getTriageCache(TriageCategoryId.duplicates.name);
    if (cache != null) {
      await _db.saveTriageCache(
        category: TriageCategoryId.duplicates.name,
        assetIds: reconciled.expand((group) => group).toList(),
        totalBytes: totalBytes,
        groupsJson: _encodeGroups(reconciled),
      );
    }

    return reconciled;
  }

  Future<List<String>> _filterExistingAssetIds(List<String> ids) async {
    final surviving = <String>[];
    for (final id in ids) {
      final asset = await AssetEntity.fromId(id);
      if (asset == null) {
        continue;
      }
      if (await asset.exists) {
        surviving.add(id);
      }
    }
    return surviving;
  }

  Future<void> _fillFileSizes(
    List<AssetEntity> batch,
    Map<String, int> fileSizes,
    List<String> largeFileIds,
  ) async {
    for (var i = 0; i < batch.length; i += _fileSizeBatchSize) {
      final chunk = batch.skip(i).take(_fileSizeBatchSize).toList();
      final sizes = await Future.wait(chunk.map((asset) => asset.fileSize));
      for (var j = 0; j < chunk.length; j++) {
        final asset = chunk[j];
        final size = sizes[j];
        fileSizes[asset.id] = size;
        if (size >= largeFileThresholdBytes && !largeFileIds.contains(asset.id)) {
          largeFileIds.add(asset.id);
        }
      }
    }
  }

  Future<List<List<String>>> _findDuplicateGroups(
    Map<String, List<AssetEntity>> dimBuckets,
    Map<String, int> fileSizes,
    Set<AssetEntity> duplicateCandidates,
  ) async {
    final groups = <List<String>>[];

    for (final candidates in dimBuckets.values) {
      if (candidates.length < 2) {
        continue;
      }

      final sizeBuckets = <String, List<AssetEntity>>{};
      for (final asset in candidates) {
        if (!duplicateCandidates.contains(asset)) {
          continue;
        }
        final size = fileSizes[asset.id];
        if (size == null) {
          continue;
        }
        sizeBuckets.putIfAbsent('$size', () => []).add(asset);
      }

      for (final sameSize in sizeBuckets.values) {
        if (sameSize.length < 2) {
          continue;
        }

        final hashBuckets = <String, List<AssetEntity>>{};
        for (var i = 0; i < sameSize.length; i += _hashBatchSize) {
          final chunk = sameSize.skip(i).take(_hashBatchSize).toList();
          final hashes = await Future.wait(chunk.map(_contentHash));
          for (var j = 0; j < chunk.length; j++) {
            final asset = chunk[j];
            final fingerprint =
                '${fileSizes[asset.id]}_${asset.width}_${asset.height}_${hashes[j]}';
            hashBuckets.putIfAbsent(fingerprint, () => []).add(asset);
          }
        }

        for (final group in hashBuckets.values) {
          if (group.length >= 2) {
            groups.add(group.map((asset) => asset.id).toList());
          }
        }
      }
    }

    return groups;
  }

  bool _isScreenshot(AssetEntity asset, String albumName) {
    if (albumName.toLowerCase().contains('screenshot')) {
      return true;
    }
    final title = asset.title?.toLowerCase() ?? '';
    if (title.contains('screenshot') || title.startsWith('screen')) {
      return true;
    }
    if (asset.subtype == _iosScreenshotSubtype) {
      return true;
    }
    return false;
  }

  Future<String> _contentHash(AssetEntity asset) async {
    try {
      final data = await asset.thumbnailDataWithSize(
        const ThumbnailSize.square(32),
      );
      if (data == null || data.isEmpty) {
        return 'none';
      }
      return md5.convert(data).toString();
    } catch (_) {
      return 'none';
    }
  }

  List<String> _parseIds(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return raw.split(',').where((value) => value.isNotEmpty).toList();
  }

  List<List<String>> _parseGroups(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(raw) as List<dynamic>;
    return decoded
        .map(
          (group) => (group as List<dynamic>).map((id) => id as String).toList(),
        )
        .toList();
  }

  String _encodeGroups(List<List<String>> groups) {
    return jsonEncode(groups);
  }

  String _titleFor(TriageCategoryId id) {
    switch (id) {
      case TriageCategoryId.duplicates:
        return 'Duplicates';
      case TriageCategoryId.screenshots:
        return 'Screenshots';
      case TriageCategoryId.largeFiles:
        return 'Large files';
    }
  }
}
