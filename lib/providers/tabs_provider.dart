import 'package:flutter/foundation.dart';

import '../models/models.dart';

class TabsProvider extends ChangeNotifier {
  TabsProvider() {
    _tabs.add(BrowserTab(id: _nextId()));
    _currentIndex = 0;
  }

  final List<BrowserTab> _tabs = [];
  late int _currentIndex;
  int _counter = 0;

  String _nextId() => 'tab_${_counter++}';

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get currentIndex => _currentIndex;
  int get count => _tabs.length;

  BrowserTab get current => _tabs[_currentIndex];

  BrowserTab? findById(String id) {
    for (final t in _tabs) {
      if (t.id == id) return t;
    }
    return null;
  }

  BrowserTab newTab({String? url, String? title, bool select = true}) {
    final tab = BrowserTab(id: _nextId(), url: url, title: title);
    _tabs.add(tab);
    if (select) _currentIndex = _tabs.length - 1;
    notifyListeners();
    return tab;
  }

  void select(String id) {
    final i = _tabs.indexWhere((t) => t.id == id);
    if (i >= 0 && i != _currentIndex) {
      _currentIndex = i;
      notifyListeners();
    }
  }

  void closeTab(String id) {
    final i = _tabs.indexWhere((t) => t.id == id);
    if (i < 0) return;
    final wasCurrent = i == _currentIndex;
    _tabs.removeAt(i);
    if (_tabs.isEmpty) {
      _tabs.add(BrowserTab(id: _nextId()));
      _currentIndex = 0;
    } else if (_currentIndex >= _tabs.length) {
      _currentIndex = _tabs.length - 1;
    } else if (wasCurrent) {
      // keep same index (now the next tab)
    }
    notifyListeners();
  }

  void goHome(BrowserTab tab) {
    tab.url = null;
    tab.title = 'New Tab';
    tab.error = null;
    tab.progress = 0;
    tab.isLoading = false;
    tab.controller = null;
    notifyListeners();
  }

  void setUrl(BrowserTab tab, String url) {
    tab.url = url;
    tab.error = null;
    notifyListeners();
  }

  /// Triggers a rebuild of listeners (tab title / progress changed in place).
  void poke() => notifyListeners();
}
