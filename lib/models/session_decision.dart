enum DecisionType { keep, delete, later, favorite }

class SessionDecision {
  const SessionDecision({
    required this.id,
    required this.sessionId,
    required this.assetId,
    required this.albumId,
    required this.decision,
    required this.originalIndex,
    required this.decidedAt,
    this.undone = false,
    this.thumbnailPath,
    this.fileSizeBytes,
    this.title,
  });

  final int id;
  final int sessionId;
  final String assetId;
  final String albumId;
  final DecisionType decision;
  final int originalIndex;
  final DateTime decidedAt;
  final bool undone;
  final String? thumbnailPath;
  final int? fileSizeBytes;
  final String? title;

  factory SessionDecision.fromMap(Map<String, dynamic> map) {
    return SessionDecision(
      id: map['id'] as int,
      sessionId: map['session_id'] as int,
      assetId: map['asset_id'] as String,
      albumId: map['album_id'] as String,
      decision: DecisionType.values.firstWhere(
        (value) => value.name == map['decision'],
        orElse: () => DecisionType.keep,
      ),
      originalIndex: (map['original_index'] as num).toInt(),
      decidedAt: DateTime.parse(map['decided_at'] as String),
      undone: (map['undone'] as int? ?? 0) == 1,
      thumbnailPath: map['thumbnail_path'] as String?,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt(),
      title: map['title'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'session_id': sessionId,
      'asset_id': assetId,
      'album_id': albumId,
      'decision': decision.name,
      'original_index': originalIndex,
      'decided_at': decidedAt.toIso8601String(),
      'undone': undone ? 1 : 0,
      'thumbnail_path': thumbnailPath,
      'file_size_bytes': fileSizeBytes,
      'title': title,
    };
  }
}
