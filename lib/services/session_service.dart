import '../models/cleanup_session.dart';
import 'database_service.dart';

class SessionService {
  SessionService._();
  static final SessionService instance = SessionService._();

  final DatabaseService _db = DatabaseService.instance;

  Future<CleanupSession> startOrResumeAlbumSession({
    required String albumId,
    required String albumName,
    required int totalCount,
    int currentIndex = 0,
  }) async {
    final key = 'album:$albumId';
    final existing = await _db.getSessionByKey(key);
    final now = DateTime.now();
    if (existing != null && !existing.completed) {
      return existing;
    }
    final session = CleanupSession(
      id: existing?.id,
      sessionKey: key,
      title: albumName,
      kind: SessionKind.album,
      albumId: albumId,
      totalCount: totalCount,
      currentIndex: currentIndex,
      startedAt: existing?.startedAt ?? now,
      updatedAt: now,
    );
    return _db.upsertSession(session);
  }

  Future<CleanupSession> startOrResumeCategorySession({
    required String category,
    required String title,
    required List<String> assetIds,
    int currentIndex = 0,
  }) async {
    final key = 'category:$category';
    final existing = await _db.getSessionByKey(key);
    final now = DateTime.now();
    final session = CleanupSession(
      id: existing?.id,
      sessionKey: key,
      title: title,
      kind: SessionKind.category,
      category: category,
      totalCount: assetIds.length,
      currentIndex: existing?.completed == true ? 0 : (existing?.currentIndex ?? currentIndex),
      keptCount: existing?.completed == true ? 0 : (existing?.keptCount ?? 0),
      deletedCount: existing?.completed == true ? 0 : (existing?.deletedCount ?? 0),
      laterCount: existing?.completed == true ? 0 : (existing?.laterCount ?? 0),
      favoriteCount: existing?.completed == true ? 0 : (existing?.favoriteCount ?? 0),
      startedAt: existing?.startedAt ?? now,
      updatedAt: now,
      completed: false,
      assetIds: assetIds,
    );
    return _db.upsertSession(session);
  }

  Future<void> updateProgress(
    CleanupSession session, {
    int? currentIndex,
    int? keptCount,
    int? deletedCount,
    int? laterCount,
    int? favoriteCount,
    bool? completed,
  }) async {
    final updated = session.copyWith(
      currentIndex: currentIndex,
      keptCount: keptCount,
      deletedCount: deletedCount,
      laterCount: laterCount,
      favoriteCount: favoriteCount,
      completed: completed,
      updatedAt: DateTime.now(),
    );
    await _db.updateSession(updated);
  }

  Future<List<CleanupSession>> activeSessions() => _db.getActiveSessions();

  /// Album/folder sessions only — excludes app triage categories (Screenshots scan, etc.).
  Future<List<CleanupSession>> activeAlbumSessions() =>
      _db.getActiveAlbumSessions();

  Future<CleanupSession?> sessionByKey(String key) => _db.getSessionByKey(key);
}
