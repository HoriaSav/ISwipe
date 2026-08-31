enum TriageCategoryId { duplicates, screenshots, largeFiles }

class TriageCategoryResult {
  const TriageCategoryResult({
    required this.id,
    required this.title,
    required this.assetIds,
    required this.totalBytes,
    required this.scannedAt,
    this.duplicateGroups = const [],
  });

  final TriageCategoryId id;
  final String title;
  final List<String> assetIds;
  final List<List<String>> duplicateGroups;
  final int totalBytes;
  final DateTime scannedAt;

  int get count => assetIds.length;

  int get groupCount => duplicateGroups.length;

  String get idKey => id.name;

  String get countLabel {
    if (id == TriageCategoryId.duplicates && groupCount > 0) {
      return '$groupCount groups · $count photos';
    }
    return '$count';
  }
}

class LibraryStats {
  const LibraryStats({
    required this.photoCount,
    required this.videoCount,
  });

  final int photoCount;
  final int videoCount;
}
