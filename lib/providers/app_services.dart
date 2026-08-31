import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:provider/provider.dart';

import '../services/gallery_service.dart';
import '../services/review_service.dart';
import '../services/triage_detection_service.dart';
import 'deletion_events.dart';

class AppServices extends ChangeNotifier {
  AppServices(this._deletionEvents) : galleryService = GalleryService() {
    reviewService = ReviewService(galleryService, _deletionEvents);
    triageDetectionService = TriageDetectionService(galleryService);
  }

  final DeletionEvents _deletionEvents;
  final GalleryService galleryService;
  late final ReviewService reviewService;
  late final TriageDetectionService triageDetectionService;

  bool _permissionGranted = false;
  bool get permissionGranted => _permissionGranted;

  Future<void> initialize() async {
    _permissionGranted = await galleryService.hasPermission();
    notifyListeners();
  }

  Future<bool> requestPermission() async {
    final state = await galleryService.requestPermission();
    _permissionGranted = state.hasAccess;
    notifyListeners();
    return _permissionGranted;
  }
}

extension AppServicesContext on BuildContext {
  AppServices get services => read<AppServices>();
  GalleryService get galleryService => services.galleryService;
  ReviewService get reviewService => services.reviewService;
  DeletionEvents get deletionEvents => read<DeletionEvents>();
}
