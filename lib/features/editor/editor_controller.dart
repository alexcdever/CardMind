import 'package:flutter/foundation.dart';

class EditorController extends ChangeNotifier {
  bool _dirty = false;
  bool _saved = false;

  bool get dirty => _dirty;
  bool get saved => _saved;

  void onContentChanged() {
    _dirty = true;
    _saved = false;
    notifyListeners();
  }

  void saveLocal() {
    _dirty = false;
    _saved = true;
    notifyListeners();
  }
}
