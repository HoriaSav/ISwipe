import '../models/album_sort_status.dart';
import 'gallery_service.dart';
import 'review_service.dart';
import 'session_service.dart';

class AlbumSortService {
  AlbumSortService._();
  static final AlbumSortService instance = AlbumSortService._();

  Future<AlbumSortPartition> loadPartition({
    required GalleryService galleryService,
    required ReviewService reviewService,
    bool refreshCache = false,
  }) async {
    final albums = await galleryService.loadAlbums(refreshCache: refreshCache);
    final reviewedCounts = await reviewService.reviewedCountsByAlbum();
    final sessions = await SessionService.instance.activeAlbumSessions();
    final sessionByAlbumId = {
      for (final session in sessions)
        if (session.albumId != null) session.albumId!: session,
    };

    final statuses = await Future.wait(
      albums.map((album) async {
        final total = await album.assetCountAsync;
        return AlbumSortStatus(
          album: album,
          totalCount: total,
          reviewedCount: reviewedCounts[album.id] ?? 0,
          session: sessionByAlbumId[album.id],
        );
      }),
    );

    final toSort = statuses.where((status) => !status.fullySorted).toList()
      ..sort(_compareToSort);

    final sorted = statuses.where((status) => status.fullySorted).toList()
      ..sort(
        (a, b) => a.album.name.toLowerCase().compareTo(b.album.name.toLowerCase()),
      );

    return AlbumSortPartition(toSort: toSort, sorted: sorted);
  }

  int _compareToSort(AlbumSortStatus a, AlbumSortStatus b) {
    final aSession = a.session;
    final bSession = b.session;
    if (aSession != null && bSession == null) {
      return -1;
    }
    if (aSession == null && bSession != null) {
      return 1;
    }
    if (aSession != null && bSession != null) {
      return bSession.updatedAt.compareTo(aSession.updatedAt);
    }

    final progressCompare = b.progressPercent.compareTo(a.progressPercent);
    if (progressCompare != 0) {
      return progressCompare;
    }

    return a.album.name.toLowerCase().compareTo(b.album.name.toLowerCase());
  }
}
