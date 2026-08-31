import 'package:photo_manager/photo_manager.dart';

import '../models/cleanup_session.dart';
import '../models/deletion_record.dart';
import '../models/session_decision.dart';
import '../providers/deletion_events.dart';
import 'database_service.dart';
import 'deletion_thumbnail_store.dart';
import 'gallery_service.dart';
import 'session_service.dart';

class PendingDelete {
  PendingDelete({
    required this.asset,
    required this.albumId,
    required this.albumName,
    required this.originalIndex,
    this.thumbnailPath,
    this.fileSizeBytes,
    this.decisionId,
  });

  final AssetEntity asset;
  final String albumId;
  final String albumName;
  final int originalIndex;
  final String? thumbnailPath;
  final int? fileSizeBytes;
  final int? decisionId;

  DeletionRecord toRecord(DateTime deletedAt) {
    return DeletionRecord(
      assetId: asset.id,
      albumId: albumId,
      albumName: albumName,
      deletedAt: deletedAt,
      originalIndex: originalIndex,
      title: asset.title,
      thumbnailPath: thumbnailPath,
      fileSizeBytes: fileSizeBytes,
    );
  }
}

class FlushDeleteResult {
  const FlushDeleteResult({
    required this.success,
    required this.appliedCount,
    this.bytesRecovered = 0,
    this.userCancelled = false,
    this.restored = const [],
  });

  final bool success;
  final int appliedCount;
  final int bytesRecovered;
  final bool userCancelled;
  final List<PendingDelete> restored;
}

class ReviewService {
  ReviewService(this._galleryService, this._deletionEvents);

  final GalleryService _galleryService;
  final DeletionEvents _deletionEvents;
  final DatabaseService _db = DatabaseService.instance;
  final DeletionThumbnailStore _thumbnails = DeletionThumbnailStore.instance;
  final SessionService _sessions = SessionService.instance;

  final List<PendingDelete> _pendingDeletes = [];
  CleanupSession? _activeSession;

  List<PendingDelete> get pendingDeletes => List.unmodifiable(_pendingDeletes);

  void beginDeleteSession() {
    _pendingDeletes.clear();
    _activeSession = null;
  }

  Future<void> beginSession(CleanupSession session) async {
    _pendingDeletes.clear();
    _activeSession = session;
  }

  CleanupSession? get activeSession => _activeSession;

  int get pendingDeleteCount => _pendingDeletes.length;

  Future<int?> _assetFileSize(AssetEntity asset) async {
    try {
      return await asset.fileSize;
    } catch (_) {
      return null;
    }
  }

  Future<void> _logDecision({
    required AssetEntity asset,
    required String albumId,
    required DecisionType decision,
    required int originalIndex,
    String? thumbnailPath,
    int? fileSizeBytes,
  }) async {
    final session = _activeSession;
    if (session?.id == null) {
      return;
    }

    await _db.insertDecision(
      sessionId: session!.id!,
      assetId: asset.id,
      albumId: albumId,
      decision: decision,
      originalIndex: originalIndex,
      thumbnailPath: thumbnailPath,
      fileSizeBytes: fileSizeBytes,
      title: asset.title,
    );

    await _sessions.updateProgress(
      session,
      currentIndex: originalIndex + 1,
      keptCount: decision == DecisionType.keep
          ? session.keptCount + 1
          : session.keptCount,
      deletedCount: decision == DecisionType.delete
          ? session.deletedCount + 1
          : session.deletedCount,
      laterCount: decision == DecisionType.later
          ? session.laterCount + 1
          : session.laterCount,
      favoriteCount: decision == DecisionType.favorite
          ? session.favoriteCount + 1
          : session.favoriteCount,
    );

    _activeSession = await _db.getSessionByKey(session.sessionKey);
  }

  Future<void> markKept(
    AssetEntity asset,
    String albumId, {
    bool notifyGallery = true,
    int? originalIndex,
  }) async {
    await _db.markReviewed(asset.id, albumId);
    await _logDecision(
      asset: asset,
      albumId: albumId,
      decision: DecisionType.keep,
      originalIndex: originalIndex ?? 0,
      fileSizeBytes: await _assetFileSize(asset),
    );
    if (notifyGallery) {
      _deletionEvents.notifyChanged();
    }
  }

  Future<void> markFavorite(
    AssetEntity asset,
    String albumId, {
    int? originalIndex,
  }) async {
    await _db.addFavorite(asset.id, albumId);
    await _db.markReviewed(asset.id, albumId);
    await _logDecision(
      asset: asset,
      albumId: albumId,
      decision: DecisionType.favorite,
      originalIndex: originalIndex ?? 0,
      fileSizeBytes: await _assetFileSize(asset),
    );
    _deletionEvents.notifyChanged();
  }

  Future<void> markLater({
    required AssetEntity asset,
    required String albumId,
    required String albumName,
    int? originalIndex,
  }) async {
    await _db.addLaterAsset(
      assetId: asset.id,
      albumId: albumId,
      albumName: albumName,
    );
    await _logDecision(
      asset: asset,
      albumId: albumId,
      decision: DecisionType.later,
      originalIndex: originalIndex ?? 0,
      fileSizeBytes: await _assetFileSize(asset),
    );
    _deletionEvents.notifyChanged();
  }

  Future<bool> isReviewed(String assetId) {
    return _db.isReviewed(assetId);
  }

  Future<Set<String>> reviewedIdsForAlbum(String albumId) {
    return _db.reviewedIdsForAlbum(albumId);
  }

  Future<Map<String, int>> reviewedCountsByAlbum() {
    return _db.reviewedCountsByAlbum();
  }

  Future<bool> queueDelete({
    required AssetEntity asset,
    required String albumId,
    required String albumName,
    required int originalIndex,
  }) async {
    final thumbnailPath = await _thumbnails.saveForAsset(asset);
    final fileSizeBytes = await _assetFileSize(asset);
    final decisionId = _activeSession?.id == null
        ? null
        : await _db.insertDecision(
            sessionId: _activeSession!.id!,
            assetId: asset.id,
            albumId: albumId,
            decision: DecisionType.delete,
            originalIndex: originalIndex,
            thumbnailPath: thumbnailPath,
            fileSizeBytes: fileSizeBytes,
            title: asset.title,
          );

    _pendingDeletes.add(
      PendingDelete(
        asset: asset,
        albumId: albumId,
        albumName: albumName,
        originalIndex: originalIndex,
        thumbnailPath: thumbnailPath,
        fileSizeBytes: fileSizeBytes,
        decisionId: decisionId,
      ),
    );

    final session = _activeSession;
    if (session != null) {
      await _sessions.updateProgress(
        session,
        currentIndex: originalIndex + 1,
        deletedCount: session.deletedCount + 1,
      );
      _activeSession = await _db.getSessionByKey(session.sessionKey);
    }

    return true;
  }

  Future<void> removePendingDelete(String assetId) async {
    final index = _pendingDeletes.indexWhere((item) => item.asset.id == assetId);
    if (index == -1) {
      return;
    }
    final item = _pendingDeletes.removeAt(index);
    await _thumbnails.deleteFile(item.thumbnailPath);
    if (item.decisionId != null) {
      await _db.markDecisionUndone(item.decisionId!);
    }
  }

  Future<PendingDelete?> undoPendingDelete() async {
    if (_pendingDeletes.isEmpty) {
      return null;
    }
    final item = _pendingDeletes.removeLast();
    await _thumbnails.deleteFile(item.thumbnailPath);
    if (item.decisionId != null) {
      await _db.markDecisionUndone(item.decisionId!);
    }
    return item;
  }

  Future<List<SessionDecision>> sessionDecisions() async {
    final sessionId = _activeSession?.id;
    if (sessionId == null) {
      return [];
    }
    return _db.getSessionDecisions(sessionId);
  }

  Future<SessionDecision?> undoDecision(int decisionId) async {
    final decision = await _db.getDecisionById(decisionId);
    if (decision == null || decision.undone) {
      return null;
    }

    await _db.markDecisionUndone(decisionId);

    if (decision.decision == DecisionType.delete) {
      final index = _pendingDeletes.indexWhere(
        (item) => item.asset.id == decision.assetId,
      );
      if (index != -1) {
        final item = _pendingDeletes.removeAt(index);
        await _thumbnails.deleteFile(item.thumbnailPath);
      }
    } else if (decision.decision == DecisionType.keep ||
        decision.decision == DecisionType.favorite) {
      await _db.unmarkReviewed(decision.assetId);
    } else if (decision.decision == DecisionType.later) {
      await _db.removeLaterAsset(decision.assetId);
    }

    if (decision.decision == DecisionType.favorite) {
      await _db.removeFavorite(decision.assetId);
    }

    return decision;
  }

  Future<FlushDeleteResult> flushPendingDeletes() async {
    if (_pendingDeletes.isEmpty) {
      return const FlushDeleteResult(success: true, appliedCount: 0);
    }

    final batch = List<PendingDelete>.from(_pendingDeletes);
    final assets = batch.map((item) => item.asset).toList();
    final moved = await _galleryService.moveToTrash(assets);

    if (!moved) {
      return FlushDeleteResult(
        success: false,
        appliedCount: 0,
        userCancelled: true,
        restored: batch,
      );
    }

    final deletedAt = DateTime.now();
    var bytesRecovered = 0;
    for (final item in batch) {
      await _db.unmarkReviewed(item.asset.id);
      await _db.recordDeletion(item.toRecord(deletedAt));
      bytesRecovered += item.fileSizeBytes ?? 0;
    }

    _pendingDeletes.clear();
    await _galleryService.refreshMediaIndex();
    _deletionEvents.notifyChanged();

    return FlushDeleteResult(
      success: true,
      appliedCount: batch.length,
      bytesRecovered: bytesRecovered,
    );
  }

  Future<void> completeSession() async {
    final session = _activeSession;
    if (session?.id == null) {
      return;
    }
    await _sessions.updateProgress(session!, completed: true);
    _activeSession = null;
  }

  void notifyGalleryChanged() {
    _deletionEvents.notifyChanged();
  }

  Future<DeletionRecord?> lastDeletionRecord() async {
    return (await _db.getDeletionRecords()).firstOrNull;
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
