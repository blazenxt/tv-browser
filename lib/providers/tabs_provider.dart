import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class TabsProvider extends ChangeNotifier {
  TabsProvider(this._prefs) {
    _sessionPersistenceEnabled = _prefs.getBool('restoreTabs') ?? true;
    if (_sessionPersistenceEnabled) _restoreSession();
    if (_tabs.isEmpty) _tabs.add(BrowserTab(id: _nextId()));
    _currentIndex = _currentIndex.clamp(0, _tabs.length - 1).toInt();
  }

  static const _kSession = 'browserSessionV2';

  final SharedPreferences _prefs;
  final List<BrowserTab> _tabs = [];
  final List<Map<String, dynamic>> _recentlyClosed = [];
  int _currentIndex = 0;
  int _counter = 0;
  bool _sessionPersistenceEnabled = true;

  /// Returns the URL new tabs should open (null = built-in start page).
  String? Function()? newTabUrlResolver;

  String _nextId() => 'tab_${_counter++}';

  List<BrowserTab> get tabs => List.unmodifiable(_tabs);
  int get currentIndex => _currentIndex;
  int get count => _tabs.length;
  bool get canReopenClosedTab => _recentlyClosed.isNotEmpty;

  BrowserTab get current => _tabs[_currentIndex];

  set sessionPersistenceEnabled(bool enabled) {
    if (_sessionPersistenceEnabled == enabled) return;
    _sessionPersistenceEnabled = enabled;
    if (enabled) {
      _persistSession();
    } else {
      _prefs.remove(_kSession);
    }
  }

  BrowserTab? findById(String id) {
    for (final tab in _tabs) {
      if (tab.id == id) return tab;
    }
    return null;
  }

  BrowserTab newTab({
    String? url,
    String? title,
    bool select = true,
    bool incognito = false,
  }) {
    final tab = BrowserTab(
      id: _nextId(),
      url: incognito ? url : (url ?? newTabUrlResolver?.call()),
      title: title,
      isIncognito: incognito,
    );
    _tabs.add(tab);
    if (select) _currentIndex = _tabs.length - 1;
    _changed();
    return tab;
  }

  BrowserTab duplicate(BrowserTab source) => newTab(
        url: source.url,
        title: source.title,
        incognito: source.isIncognito,
      );

  void select(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index >= 0 && index != _currentIndex) {
      _currentIndex = index;
      _changed();
    }
  }

  void closeTab(String id) {
    final index = _tabs.indexWhere((tab) => tab.id == id);
    if (index < 0) return;
    final tab = _tabs[index];
    final wasCurrent = index == _currentIndex;
    if (!tab.isIncognito) {
      _recentlyClosed.add(tab.toSessionJson());
      if (_recentlyClosed.length > 10) _recentlyClosed.removeAt(0);
    }
    _tabs.removeAt(index);
    if (_tabs.isEmpty) {
      _tabs.add(BrowserTab(id: _nextId()));
      _currentIndex = 0;
    } else if (_currentIndex >= _tabs.length) {
      _currentIndex = _tabs.length - 1;
    } else if (!wasCurrent && index < _currentIndex) {
      _currentIndex--;
    }
    _changed();
  }

  BrowserTab? reopenClosedTab() {
    if (_recentlyClosed.isEmpty) return null;
    final json = _recentlyClosed.removeLast();
    final tab = _tabFromSession(json);
    _tabs.add(tab);
    _currentIndex = _tabs.length - 1;
    _changed();
    return tab;
  }

  void goHome(BrowserTab tab) {
    tab.url = null;
    tab.title = tab.isIncognito ? 'Incognito' : 'New Tab';
    tab.error = null;
    tab.progress = 0;
    tab.isLoading = false;
    tab.canGoBack = false;
    tab.canGoForward = false;
    tab.controller = null;
    _changed();
  }

  void setUrl(BrowserTab tab, String url) {
    tab.url = url;
    tab.error = null;
    _changed();
  }

  /// Triggers a rebuild after mutable tab state (title/progress/url) changes.
  void poke({bool saveSession = true}) {
    if (saveSession) _persistSession();
    notifyListeners();
  }

  void _changed() {
    _persistSession();
    notifyListeners();
  }

  void _restoreSession() {
    try {
      final raw = _prefs.getString(_kSession);
      if (raw == null || raw.isEmpty) return;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return;
      final savedTabs = decoded['tabs'];
      if (savedTabs is! List) return;
      for (final value in savedTabs.take(12)) {
        if (value is Map) {
          _tabs.add(_tabFromSession(Map<String, dynamic>.from(value)));
        }
      }
      _currentIndex = (decoded['currentIndex'] as num?)?.toInt() ?? 0;
    } catch (_) {
      _tabs.clear();
      _currentIndex = 0;
    }
  }

  BrowserTab _tabFromSession(Map<String, dynamic> json) => BrowserTab(
        id: _nextId(),
        url: json['url']?.toString(),
        title: json['title']?.toString(),
        desktopModeOverride: json['desktopModeOverride'] as bool?,
        pageZoom: (json['pageZoom'] as num?)?.toDouble() ?? 1,
      );

  void _persistSession() {
    if (!_sessionPersistenceEnabled) return;
    final normalTabs = _tabs.where((tab) => !tab.isIncognito).toList();
    if (normalTabs.isEmpty) {
      _prefs.remove(_kSession);
      return;
    }
    final selected = current.isIncognito
        ? 0
        : normalTabs.indexWhere((tab) => identical(tab, current));
    _prefs.setString(
      _kSession,
      jsonEncode({
        'tabs': normalTabs.map((tab) => tab.toSessionJson()).toList(),
        'currentIndex': selected < 0 ? 0 : selected,
      }),
    );
  }
}
