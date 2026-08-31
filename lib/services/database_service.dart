import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/cleanup_session.dart';
import '../models/deletion_record.dart';
import '../models/session_decision.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Database? _db;

  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dbPath = await getDatabasesPath();
    return openDatabase(
      join(dbPath, 'iswipe.db'),
      version: 4,
      onCreate: (db, version) async {
        await _createV1Tables(db);
        await _createV3Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE deletion_records ADD COLUMN thumbnail_path TEXT',
          );
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE deletion_records ADD COLUMN file_size_bytes INTEGER',
          );
          await _createV3Tables(db);
        }
        if (oldVersion < 4) {
          await db.execute(
            'ALTER TABLE triage_scan_cache ADD COLUMN groups_json TEXT',
          );
        }
      },
    );
  }

  Future<void> _createV1Tables(Database db) async {
    await db.execute('''
      CREATE TABLE reviewed_assets (
        asset_id TEXT PRIMARY KEY,
        album_id TEXT NOT NULL,
        reviewed_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE deletion_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        asset_id TEXT NOT NULL,
        album_id TEXT NOT NULL,
        album_name TEXT NOT NULL,
        deleted_at TEXT NOT NULL,
        original_index INTEGER NOT NULL,
        title TEXT,
        thumbnail_path TEXT,
        file_size_bytes INTEGER
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_deletion_deleted_at ON deletion_records(deleted_at)',
    );
  }

  Future<void> _createV3Tables(Database db) async {
    await db.execute('''
      CREATE TABLE cleanup_sessions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_key TEXT NOT NULL UNIQUE,
        title TEXT NOT NULL,
        kind TEXT NOT NULL,
        album_id TEXT,
        category TEXT,
        total_count INTEGER NOT NULL DEFAULT 0,
        current_index INTEGER NOT NULL DEFAULT 0,
        kept_count INTEGER NOT NULL DEFAULT 0,
        deleted_count INTEGER NOT NULL DEFAULT 0,
        later_count INTEGER NOT NULL DEFAULT 0,
        favorite_count INTEGER NOT NULL DEFAULT 0,
        started_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        completed INTEGER NOT NULL DEFAULT 0,
        asset_ids_json TEXT NOT NULL DEFAULT ''
      )
    ''');
    await db.execute('''
      CREATE TABLE session_decisions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id INTEGER NOT NULL,
        asset_id TEXT NOT NULL,
        album_id TEXT NOT NULL,
        decision TEXT NOT NULL,
        original_index INTEGER NOT NULL,
        decided_at TEXT NOT NULL,
        undone INTEGER NOT NULL DEFAULT 0,
        thumbnail_path TEXT,
        file_size_bytes INTEGER,
        title TEXT,
        FOREIGN KEY (session_id) REFERENCES cleanup_sessions(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_session_decisions_session ON session_decisions(session_id)',
    );
    await db.execute('''
      CREATE TABLE favorites (
        asset_id TEXT PRIMARY KEY,
        album_id TEXT NOT NULL,
        favorited_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE later_assets (
        asset_id TEXT PRIMARY KEY,
        album_id TEXT NOT NULL,
        album_name TEXT NOT NULL,
        added_at TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE triage_scan_cache (
        category TEXT PRIMARY KEY,
        asset_ids_json TEXT NOT NULL,
        total_bytes INTEGER NOT NULL DEFAULT 0,
        scanned_at TEXT NOT NULL,
        groups_json TEXT
      )
    ''');
    await db.execute('''
      CREATE TABLE asset_fingerprints (
        asset_id TEXT PRIMARY KEY,
        file_size INTEGER NOT NULL,
        width INTEGER NOT NULL,
        height INTEGER NOT NULL,
        content_hash TEXT,
        scanned_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> markReviewed(String assetId, String albumId) async {
    final db = await database;
    await db.insert(
      'reviewed_assets',
      {
        'asset_id': assetId,
        'album_id': albumId,
        'reviewed_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<bool> isReviewed(String assetId) async {
    final db = await database;
    final rows = await db.query(
      'reviewed_assets',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<Set<String>> reviewedIdsForAlbum(String albumId) async {
    final db = await database;
    final rows = await db.query(
      'reviewed_assets',
      columns: ['asset_id'],
      where: 'album_id = ?',
      whereArgs: [albumId],
    );
    return rows.map((row) => row['asset_id'] as String).toSet();
  }

  Future<Map<String, int>> reviewedCountsByAlbum() async {
    final db = await database;
    final rows = await db.rawQuery(
      'SELECT album_id, COUNT(*) as count FROM reviewed_assets GROUP BY album_id',
    );
    final counts = <String, int>{};
    for (final row in rows) {
      counts[row['album_id'] as String] = (row['count'] as num?)?.toInt() ?? 0;
    }
    return counts;
  }

  Future<void> unmarkReviewed(String assetId) async {
    final db = await database;
    await db.delete(
      'reviewed_assets',
      where: 'asset_id = ?',
      whereArgs: [assetId],
    );
  }

  Future<void> recordDeletion(DeletionRecord record) async {
    final db = await database;
    await db.insert('deletion_records', record.toMap());
  }

  Future<void> removeDeletionRecord(String assetId) async {
    final db = await database;
    await db.delete(
      'deletion_records',
      where: 'asset_id = ?',
      whereArgs: [assetId],
    );
  }

  Future<List<DeletionRecord>> getDeletionRecords() async {
    final db = await database;
    final rows = await db.query(
      'deletion_records',
      orderBy: 'deleted_at DESC',
    );
    return rows.map(DeletionRecord.fromMap).toList();
  }

  Future<Map<String, int>> deletionCountsSince(DateTime since) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COUNT(*) as count
      FROM deletion_records
      WHERE deleted_at >= ?
      ''',
      [since.toIso8601String()],
    );
    return {'count': rows.first['count'] as int? ?? 0};
  }

  Future<int> bytesRecoveredSince(DateTime since) async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(file_size_bytes), 0) as total
      FROM deletion_records
      WHERE deleted_at >= ? AND file_size_bytes IS NOT NULL
      ''',
      [since.toIso8601String()],
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<int> totalBytesRecovered() async {
    final db = await database;
    final rows = await db.rawQuery(
      '''
      SELECT COALESCE(SUM(file_size_bytes), 0) as total
      FROM deletion_records
      WHERE file_size_bytes IS NOT NULL
      ''',
    );
    return (rows.first['total'] as num?)?.toInt() ?? 0;
  }

  Future<List<Map<String, dynamic>>> deletionsGroupedByDay(DateTime since) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT substr(deleted_at, 1, 10) as day, COUNT(*) as count
      FROM deletion_records
      WHERE deleted_at >= ?
      GROUP BY day
      ORDER BY day DESC
      ''',
      [since.toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> deletionsGroupedByMonth(
    DateTime since,
  ) async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT substr(deleted_at, 1, 7) as month, COUNT(*) as count
      FROM deletion_records
      WHERE deleted_at >= ?
      GROUP BY month
      ORDER BY month DESC
      ''',
      [since.toIso8601String()],
    );
  }

  Future<List<Map<String, dynamic>>> deletionsGroupedByYear() async {
    final db = await database;
    return db.rawQuery(
      '''
      SELECT substr(deleted_at, 1, 4) as year, COUNT(*) as count
      FROM deletion_records
      GROUP BY year
      ORDER BY year DESC
      ''',
    );
  }

  Future<int> totalDeletions() async {
    final db = await database;
    final result =
        await db.rawQuery('SELECT COUNT(*) as count FROM deletion_records');
    return result.first['count'] as int? ?? 0;
  }

  Future<CleanupSession> upsertSession(CleanupSession session) async {
    final db = await database;
    final existing = await getSessionByKey(session.sessionKey);
    if (existing != null) {
      final map = session.copyWith(id: existing.id).toMap()..remove('id');
      await db.update(
        'cleanup_sessions',
        map,
        where: 'id = ?',
        whereArgs: [existing.id],
      );
      return session.copyWith(id: existing.id);
    }

    final id = await db.insert(
      'cleanup_sessions',
      session.toMap()..remove('id'),
    );
    return session.copyWith(id: id);
  }

  Future<void> updateSession(CleanupSession session) async {
    if (session.id == null) {
      return;
    }
    final db = await database;
    final map = session.toMap()..remove('id');
    await db.update(
      'cleanup_sessions',
      map,
      where: 'id = ?',
      whereArgs: [session.id],
    );
  }

  Future<CleanupSession?> getSessionByKey(String sessionKey) async {
    final db = await database;
    final rows = await db.query(
      'cleanup_sessions',
      where: 'session_key = ?',
      whereArgs: [sessionKey],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return CleanupSession.fromMap(rows.first);
  }

  Future<List<CleanupSession>> getActiveSessions() async {
    final db = await database;
    final rows = await db.query(
      'cleanup_sessions',
      where: 'completed = 0',
      orderBy: 'updated_at DESC',
    );
    return rows.map(CleanupSession.fromMap).toList();
  }

  Future<List<CleanupSession>> getActiveAlbumSessions() async {
    final db = await database;
    final rows = await db.query(
      'cleanup_sessions',
      where: 'completed = 0 AND kind = ?',
      whereArgs: ['album'],
      orderBy: 'updated_at DESC',
    );
    return rows.map(CleanupSession.fromMap).toList();
  }

  Future<int> insertDecision({
    required int sessionId,
    required String assetId,
    required String albumId,
    required DecisionType decision,
    required int originalIndex,
    String? thumbnailPath,
    int? fileSizeBytes,
    String? title,
  }) async {
    final db = await database;
    return db.insert('session_decisions', {
      'session_id': sessionId,
      'asset_id': assetId,
      'album_id': albumId,
      'decision': decision.name,
      'original_index': originalIndex,
      'decided_at': DateTime.now().toIso8601String(),
      'undone': 0,
      'thumbnail_path': thumbnailPath,
      'file_size_bytes': fileSizeBytes,
      'title': title,
    });
  }

  Future<List<SessionDecision>> getSessionDecisions(int sessionId) async {
    final db = await database;
    final rows = await db.query(
      'session_decisions',
      where: 'session_id = ? AND undone = 0',
      whereArgs: [sessionId],
      orderBy: 'decided_at DESC',
    );
    return rows.map(SessionDecision.fromMap).toList();
  }

  Future<SessionDecision?> getDecisionById(int decisionId) async {
    final db = await database;
    final rows = await db.query(
      'session_decisions',
      where: 'id = ?',
      whereArgs: [decisionId],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SessionDecision.fromMap(rows.first);
  }

  Future<void> markDecisionUndone(int decisionId) async {
    final db = await database;
    await db.update(
      'session_decisions',
      {'undone': 1},
      where: 'id = ?',
      whereArgs: [decisionId],
    );
  }

  Future<void> addFavorite(String assetId, String albumId) async {
    final db = await database;
    await db.insert(
      'favorites',
      {
        'asset_id': assetId,
        'album_id': albumId,
        'favorited_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeFavorite(String assetId) async {
    final db = await database;
    await db.delete(
      'favorites',
      where: 'asset_id = ?',
      whereArgs: [assetId],
    );
  }

  Future<bool> isFavorite(String assetId) async {
    final db = await database;
    final rows = await db.query(
      'favorites',
      where: 'asset_id = ?',
      whereArgs: [assetId],
      limit: 1,
    );
    return rows.isNotEmpty;
  }

  Future<void> addLaterAsset({
    required String assetId,
    required String albumId,
    required String albumName,
  }) async {
    final db = await database;
    await db.insert(
      'later_assets',
      {
        'asset_id': assetId,
        'album_id': albumId,
        'album_name': albumName,
        'added_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> removeLaterAsset(String assetId) async {
    final db = await database;
    await db.delete(
      'later_assets',
      where: 'asset_id = ?',
      whereArgs: [assetId],
    );
  }

  Future<int> laterAssetCount() async {
    final db = await database;
    final rows =
        await db.rawQuery('SELECT COUNT(*) as count FROM later_assets');
    return rows.first['count'] as int? ?? 0;
  }

  Future<List<Map<String, dynamic>>> getLaterAssets() async {
    final db = await database;
    return db.query('later_assets', orderBy: 'added_at DESC');
  }

  Future<void> saveTriageCache({
    required String category,
    required List<String> assetIds,
    required int totalBytes,
    String? groupsJson,
  }) async {
    final db = await database;
    await db.insert(
      'triage_scan_cache',
      {
        'category': category,
        'asset_ids_json': assetIds.join(','),
        'total_bytes': totalBytes,
        'scanned_at': DateTime.now().toIso8601String(),
        'groups_json': groupsJson,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTriageCache(String category) async {
    final db = await database;
    final rows = await db.query(
      'triage_scan_cache',
      where: 'category = ?',
      whereArgs: [category],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return rows.first;
  }

  Future<void> saveAssetFingerprint({
    required String assetId,
    required int fileSize,
    required int width,
    required int height,
    String? contentHash,
  }) async {
    final db = await database;
    await db.insert(
      'asset_fingerprints',
      {
        'asset_id': assetId,
        'file_size': fileSize,
        'width': width,
        'height': height,
        'content_hash': contentHash,
        'scanned_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}
