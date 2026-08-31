import 'package:photo_manager/photo_manager.dart';

import 'cleanup_session.dart';

class AlbumSortStatus {
  const AlbumSortStatus({
    required this.album,
    required this.totalCount,
    required this.reviewedCount,
    this.session,
  });

  final AssetPathEntity album;
  final int totalCount;
  final int reviewedCount;
  final CleanupSession? session;

  bool get fullySorted => totalCount > 0 && reviewedCount >= totalCount;

  int get progressPercent =>
      totalCount == 0 ? 100 : ((reviewedCount / totalCount) * 100).round();
}

class AlbumSortPartition {
  const AlbumSortPartition({
    required this.toSort,
    required this.sorted,
  });

  final List<AlbumSortStatus> toSort;
  final List<AlbumSortStatus> sorted;
}
