import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:photo_manager/photo_manager.dart';

class DeletionThumbnailStore {
  DeletionThumbnailStore._();
  static final DeletionThumbnailStore instance = DeletionThumbnailStore._();

  Future<String?> saveForAsset(AssetEntity asset) async {
    final bytes = await asset.thumbnailDataWithSize(
      const ThumbnailSize.square(400),
    );
    if (bytes == null || bytes.isEmpty) {
      return null;
    }

    final dir = await _thumbDir();
    final file = File(join(dir.path, '${asset.id}.jpg'));
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<void> deleteFile(String? path) async {
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<Directory> _thumbDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(join(base.path, 'deleted_thumbs'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }
}
