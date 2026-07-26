import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the D-pad navigates web pages.
enum NavMode { cursor, spatial }

enum SearchEngine { google, bing, duckduckgo }

enum CursorSpeed { slow, normal, fast }

enum UserAgentMode { system, desktop }

enum TextScaleOption { small, medium, large }

enum NewTabPage { startPage, custom }

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _navMode = NavMode.values[_prefs.getInt(_kNavMode) ?? 0];
    _searchEngine =
        SearchEngine.values[_prefs.getInt(_kSearchEngine) ?? 0];
    _cursorSpeed = CursorSpeed.values[_prefs.getInt(_kCursorSpeed) ?? 1];
    _userAgentMode =
        UserAgentMode.values[_prefs.getInt(_kUserAgent) ?? 0];
    _adBlockEnabled = _prefs.getBool(_kAdBlock) ?? true;
    _textScale =
        TextScaleOption.values[_prefs.getInt(_kTextScale) ?? 1];
    _newTabPage = NewTabPage.values[_prefs.getInt(_kNewTabPage) ?? 0];
    _customHomepage = _prefs.getString(_kCustomHomepage) ?? '';
  }

  static const _kNavMode = 'navMode';
  static const _kSearchEngine = 'searchEngine';
  static const _kCursorSpeed = 'cursorSpeed';
  static const _kUserAgent = 'userAgent';
  static const _kAdBlock = 'adBlock';
  static const _kTextScale = 'textScale';
  static const _kNewTabPage = 'newTabPage';
  static const _kCustomHomepage = 'customHomepage';

  final SharedPreferences _prefs;

  late NavMode _navMode;
  late SearchEngine _searchEngine;
  late CursorSpeed _cursorSpeed;
  late UserAgentMode _userAgentMode;
  late bool _adBlockEnabled;
  late TextScaleOption _textScale;
  late NewTabPage _newTabPage;
  late String _customHomepage;

  NavMode get navMode => _navMode;
  SearchEngine get searchEngine => _searchEngine;
  CursorSpeed get cursorSpeed => _cursorSpeed;
  UserAgentMode get userAgentMode => _userAgentMode;
  bool get adBlockEnabled => _adBlockEnabled;
  TextScaleOption get textScale => _textScale;
  NewTabPage get newTabPage => _newTabPage;
  String get customHomepage => _customHomepage;

  /// WebView textZoom value for the selected text size.
  int get textZoom {
    switch (_textScale) {
      case TextScaleOption.small:
        return 100;
      case TextScaleOption.medium:
        return 112;
      case TextScaleOption.large:
        return 125;
    }
  }

  /// URL new tabs should open, or null for the built-in start page.
  String? get newTabUrl =>
      _newTabPage == NewTabPage.custom ? toUrl(_customHomepage) : null;

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

  void setAdBlockEnabled(bool enabled) {
    _adBlockEnabled = enabled;
    _prefs.setBool(_kAdBlock, enabled);
    notifyListeners();
  }

  void setTextScale(TextScaleOption scale) {
    _textScale = scale;
    _prefs.setInt(_kTextScale, scale.index);
    notifyListeners();
  }

  void setNewTabPage(NewTabPage page) {
    _newTabPage = page;
    _prefs.setInt(_kNewTabPage, page.index);
    notifyListeners();
  }

  void setCustomHomepage(String url) {
    _customHomepage = url;
    _prefs.setString(_kCustomHomepage, url);
    notifyListeners();
  }
}
