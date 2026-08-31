enum SessionKind { album, category }

class CleanupSession {
  const CleanupSession({
    this.id,
    required this.sessionKey,
    required this.title,
    required this.kind,
    this.albumId,
    this.category,
    required this.totalCount,
    this.currentIndex = 0,
    this.keptCount = 0,
    this.deletedCount = 0,
    this.laterCount = 0,
    this.favoriteCount = 0,
    required this.startedAt,
    required this.updatedAt,
    this.completed = false,
    this.assetIds = const [],
  });

  final int? id;
  final String sessionKey;
  final String title;
  final SessionKind kind;
  final String? albumId;
  final String? category;
  final int totalCount;
  final int currentIndex;
  final int keptCount;
  final int deletedCount;
  final int laterCount;
  final int favoriteCount;
  final DateTime startedAt;
  final DateTime updatedAt;
  final bool completed;
  final List<String> assetIds;

  double get progress =>
      totalCount == 0 ? 0 : (currentIndex / totalCount).clamp(0.0, 1.0);

  int get progressPercent => (progress * 100).round();

  factory CleanupSession.fromMap(Map<String, dynamic> map) {
    final kindRaw = map['kind'] as String? ?? 'album';
    return CleanupSession(
      id: map['id'] as int?,
      sessionKey: map['session_key'] as String,
      title: map['title'] as String,
      kind: kindRaw == 'category' ? SessionKind.category : SessionKind.album,
      albumId: map['album_id'] as String?,
      category: map['category'] as String?,
      totalCount: (map['total_count'] as num?)?.toInt() ?? 0,
      currentIndex: (map['current_index'] as num?)?.toInt() ?? 0,
      keptCount: (map['kept_count'] as num?)?.toInt() ?? 0,
      deletedCount: (map['deleted_count'] as num?)?.toInt() ?? 0,
      laterCount: (map['later_count'] as num?)?.toInt() ?? 0,
      favoriteCount: (map['favorite_count'] as num?)?.toInt() ?? 0,
      startedAt: DateTime.parse(map['started_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      completed: (map['completed'] as int? ?? 0) == 1,
      assetIds: _decodeAssetIds(map['asset_ids_json'] as String?),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'session_key': sessionKey,
      'title': title,
      'kind': kind == SessionKind.category ? 'category' : 'album',
      'album_id': albumId,
      'category': category,
      'total_count': totalCount,
      'current_index': currentIndex,
      'kept_count': keptCount,
      'deleted_count': deletedCount,
      'later_count': laterCount,
      'favorite_count': favoriteCount,
      'started_at': startedAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed': completed ? 1 : 0,
      'asset_ids_json': _encodeAssetIds(assetIds),
    };
  }

  CleanupSession copyWith({
    int? id,
    int? currentIndex,
    int? keptCount,
    int? deletedCount,
    int? laterCount,
    int? favoriteCount,
    DateTime? updatedAt,
    bool? completed,
    int? totalCount,
    List<String>? assetIds,
  }) {
    return CleanupSession(
      id: id ?? this.id,
      sessionKey: sessionKey,
      title: title,
      kind: kind,
      albumId: albumId,
      category: category,
      totalCount: totalCount ?? this.totalCount,
      currentIndex: currentIndex ?? this.currentIndex,
      keptCount: keptCount ?? this.keptCount,
      deletedCount: deletedCount ?? this.deletedCount,
      laterCount: laterCount ?? this.laterCount,
      favoriteCount: favoriteCount ?? this.favoriteCount,
      startedAt: startedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      completed: completed ?? this.completed,
      assetIds: assetIds ?? this.assetIds,
    );
  }

  static List<String> _decodeAssetIds(String? raw) {
    if (raw == null || raw.isEmpty) {
      return const [];
    }
    return raw.split(',').where((id) => id.isNotEmpty).toList();
  }

  static String _encodeAssetIds(List<String> ids) {
    if (ids.isEmpty) {
      return '';
    }
    return ids.join(',');
  }
}
