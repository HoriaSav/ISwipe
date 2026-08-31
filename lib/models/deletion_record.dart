class DeletionRecord {
  const DeletionRecord({
    required this.assetId,
    required this.albumId,
    required this.albumName,
    required this.deletedAt,
    required this.originalIndex,
    this.title,
    this.thumbnailPath,
    this.fileSizeBytes,
  });

  final String assetId;
  final String albumId;
  final String albumName;
  final DateTime deletedAt;
  final int originalIndex;
  final String? title;
  final String? thumbnailPath;
  final int? fileSizeBytes;

  factory DeletionRecord.fromMap(Map<String, dynamic> map) {
    return DeletionRecord(
      assetId: map['asset_id'] as String,
      albumId: map['album_id'] as String,
      albumName: map['album_name'] as String,
      deletedAt: DateTime.parse(map['deleted_at'] as String),
      originalIndex: (map['original_index'] as num).toInt(),
      title: map['title'] as String?,
      thumbnailPath: map['thumbnail_path'] as String?,
      fileSizeBytes: (map['file_size_bytes'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'asset_id': assetId,
      'album_id': albumId,
      'album_name': albumName,
      'deleted_at': deletedAt.toIso8601String(),
      'original_index': originalIndex,
      'title': title,
      'thumbnail_path': thumbnailPath,
      'file_size_bytes': fileSizeBytes,
    };
  }
}
