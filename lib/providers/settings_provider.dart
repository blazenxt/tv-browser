import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the D-pad navigates web pages.
enum NavMode { cursor, spatial }

enum SearchEngine { google, bing, duckduckgo }

enum CursorSpeed { slow, normal, fast }

enum UserAgentMode { system, desktop }

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _navMode = NavMode.values[_prefs.getInt(_kNavMode) ?? 0];
    _searchEngine =
        SearchEngine.values[_prefs.getInt(_kSearchEngine) ?? 0];
    _cursorSpeed = CursorSpeed.values[_prefs.getInt(_kCursorSpeed) ?? 1];
    _userAgentMode =
        UserAgentMode.values[_prefs.getInt(_kUserAgent) ?? 0];
  }

  static const _kNavMode = 'navMode';
  static const _kSearchEngine = 'searchEngine';
  static const _kCursorSpeed = 'cursorSpeed';
  static const _kUserAgent = 'userAgent';

  final SharedPreferences _prefs;

  late NavMode _navMode;
  late SearchEngine _searchEngine;
  late CursorSpeed _cursorSpeed;
  late UserAgentMode _userAgentMode;

  NavMode get navMode => _navMode;
  SearchEngine get searchEngine => _searchEngine;
  CursorSpeed get cursorSpeed => _cursorSpeed;
  UserAgentMode get userAgentMode => _userAgentMode;

  /// Logical pixels the virtual cursor travels per D-pad press.
  double get cursorStep {
    switch (_cursorSpeed) {
      case CursorSpeed.slow:
        return 28;
      case CursorSpeed.normal:
        return 56;
      case CursorSpeed.fast:
        return 112;
    }
  }

  String get userAgent {
    switch (_userAgentMode) {
      case UserAgentMode.system:
        return '';
      case UserAgentMode.desktop:
        return 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
            'AppleWebKit/537.36 (KHTML, like Gecko) '
            'Chrome/120.0.0.0 Safari/537.36';
    }
  }

  String get searchEngineName {
    switch (_searchEngine) {
      case SearchEngine.google:
        return 'Google';
      case SearchEngine.bing:
        return 'Bing';
      case SearchEngine.duckduckgo:
        return 'DuckDuckGo';
    }
  }

  String searchUrl(String query) {
    final q = Uri.encodeComponent(query);
    switch (_searchEngine) {
      case SearchEngine.google:
        return 'https://www.google.com/search?q=$q';
      case SearchEngine.bing:
        return 'https://www.bing.com/search?q=$q';
      case SearchEngine.duckduckgo:
        return 'https://duckduckgo.com/?q=$q';
    }
  }

  /// Turns raw address-bar input into a URL to load (or null if empty).
  String? toUrl(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    if (s.startsWith('http://') || s.startsWith('https://')) return s;
    final looksLikeDomain = !s.contains(' ') &&
        s.contains('.') &&
        !s.startsWith('.') &&
        !s.endsWith('.') &&
        s.split('.').last.length >= 2;
    if (looksLikeDomain) return 'https://$s';
    return searchUrl(s);
  }

  void setNavMode(NavMode mode) {
    _navMode = mode;
    _prefs.setInt(_kNavMode, mode.index);
    notifyListeners();
  }

  void setSearchEngine(SearchEngine engine) {
    _searchEngine = engine;
    _prefs.setInt(_kSearchEngine, engine.index);
    notifyListeners();
  }

  void setCursorSpeed(CursorSpeed speed) {
    _cursorSpeed = speed;
    _prefs.setInt(_kCursorSpeed, speed.index);
    notifyListeners();
  }

  void setUserAgentMode(UserAgentMode mode) {
    _userAgentMode = mode;
    _prefs.setInt(_kUserAgent, mode.index);
    notifyListeners();
  }
}
