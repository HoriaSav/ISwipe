import 'package:flutter/foundation.dart';

/// Notifies listeners when deletion records change (delete or undo).
class DeletionEvents extends ChangeNotifier {
  void notifyChanged() {
    notifyListeners();
  }
}
