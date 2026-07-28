import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How the D-pad navigates web pages.
enum NavMode { cursor, spatial }

enum SearchEngine { google, bing, duckduckgo }

enum CursorSpeed { slow, normal, fast }

enum UserAgentMode { system, desktop }

enum TextScaleOption { small, medium, large }

enum NewTabPage { startPage, custom }

enum ThemePreference { system, light, dark }

class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._prefs) {
    _navMode =
        _enumValue(NavMode.values, _prefs.getInt(_kNavMode), NavMode.cursor);
    _searchEngine = _enumValue(
      SearchEngine.values,
      _prefs.getInt(_kSearchEngine),
      SearchEngine.google,
    );
    _cursorSpeed = _enumValue(
      CursorSpeed.values,
      _prefs.getInt(_kCursorSpeed),
      CursorSpeed.normal,
    );
    _userAgentMode = _enumValue(
      UserAgentMode.values,
      _prefs.getInt(_kUserAgent),
      UserAgentMode.system,
    );
    _textScale = _enumValue(
      TextScaleOption.values,
      _prefs.getInt(_kTextScale),
      TextScaleOption.medium,
    );
    _newTabPage = _enumValue(
      NewTabPage.values,
      _prefs.getInt(_kNewTabPage),
      NewTabPage.startPage,
    );
    _themePreference = _enumValue(
      ThemePreference.values,
      _prefs.getInt(_kTheme),
      ThemePreference.system,
    );
    _adBlockEnabled = _prefs.getBool(_kAdBlock) ?? true;
    _customHomepage = _prefs.getString(_kCustomHomepage) ?? '';
    _restoreTabs = _prefs.getBool(_kRestoreTabs) ?? true;
    _javaScriptEnabled = _prefs.getBool(_kJavaScript) ?? true;
    _autoplayEnabled = _prefs.getBool(_kAutoplay) ?? true;
    _safeBrowsingEnabled = _prefs.getBool(_kSafeBrowsing) ?? true;
    _thirdPartyCookiesEnabled = _prefs.getBool(_kThirdPartyCookies) ?? true;
    _doNotTrack = _prefs.getBool(_kDoNotTrack) ?? true;
  }

  static const _kNavMode = 'navMode';
  static const _kSearchEngine = 'searchEngine';
  static const _kCursorSpeed = 'cursorSpeed';
  static const _kUserAgent = 'userAgent';
  static const _kAdBlock = 'adBlock';
  static const _kTextScale = 'textScale';
  static const _kNewTabPage = 'newTabPage';
  static const _kCustomHomepage = 'customHomepage';
  static const _kTheme = 'themePreference';
  static const _kRestoreTabs = 'restoreTabs';
  static const _kJavaScript = 'javaScriptEnabled';
  static const _kAutoplay = 'autoplayEnabled';
  static const _kSafeBrowsing = 'safeBrowsingEnabled';
  static const _kThirdPartyCookies = 'thirdPartyCookiesEnabled';
  static const _kDoNotTrack = 'doNotTrack';

  final SharedPreferences _prefs;

  late NavMode _navMode;
  late SearchEngine _searchEngine;
  late CursorSpeed _cursorSpeed;
  late UserAgentMode _userAgentMode;
  late bool _adBlockEnabled;
  late TextScaleOption _textScale;
  late NewTabPage _newTabPage;
  late String _customHomepage;
  late ThemePreference _themePreference;
  late bool _restoreTabs;
  late bool _javaScriptEnabled;
  late bool _autoplayEnabled;
  late bool _safeBrowsingEnabled;
  late bool _thirdPartyCookiesEnabled;
  late bool _doNotTrack;

  NavMode get navMode => _navMode;
  SearchEngine get searchEngine => _searchEngine;
  CursorSpeed get cursorSpeed => _cursorSpeed;
  UserAgentMode get userAgentMode => _userAgentMode;
  bool get adBlockEnabled => _adBlockEnabled;
  TextScaleOption get textScale => _textScale;
  NewTabPage get newTabPage => _newTabPage;
  String get customHomepage => _customHomepage;
  ThemePreference get themePreference => _themePreference;
  bool get restoreTabs => _restoreTabs;
  bool get javaScriptEnabled => _javaScriptEnabled;
  bool get autoplayEnabled => _autoplayEnabled;
  bool get safeBrowsingEnabled => _safeBrowsingEnabled;
  bool get thirdPartyCookiesEnabled => _thirdPartyCookiesEnabled;
  bool get doNotTrack => _doNotTrack;

  ThemeMode get themeMode {
    switch (_themePreference) {
      case ThemePreference.system:
        return ThemeMode.system;
      case ThemePreference.light:
        return ThemeMode.light;
      case ThemePreference.dark:
        return ThemeMode.dark;
    }
  }

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

  static const desktopUserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/124.0.0.0 Safari/537.36';

  String get userAgent =>
      _userAgentMode == UserAgentMode.desktop ? desktopUserAgent : '';

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

  void setNavMode(NavMode mode) => _setEnum(
        mode,
        _navMode,
        (value) => _navMode = value,
        _kNavMode,
      );

  void setSearchEngine(SearchEngine engine) => _setEnum(
        engine,
        _searchEngine,
        (value) => _searchEngine = value,
        _kSearchEngine,
      );

  void setCursorSpeed(CursorSpeed speed) => _setEnum(
        speed,
        _cursorSpeed,
        (value) => _cursorSpeed = value,
        _kCursorSpeed,
      );

  void setUserAgentMode(UserAgentMode mode) => _setEnum(
        mode,
        _userAgentMode,
        (value) => _userAgentMode = value,
        _kUserAgent,
      );

  void setTextScale(TextScaleOption scale) => _setEnum(
        scale,
        _textScale,
        (value) => _textScale = value,
        _kTextScale,
      );

  void setNewTabPage(NewTabPage page) => _setEnum(
        page,
        _newTabPage,
        (value) => _newTabPage = value,
        _kNewTabPage,
      );

  void setThemePreference(ThemePreference preference) => _setEnum(
        preference,
        _themePreference,
        (value) => _themePreference = value,
        _kTheme,
      );

  void setAdBlockEnabled(bool enabled) => _setBool(
        enabled,
        _adBlockEnabled,
        (value) => _adBlockEnabled = value,
        _kAdBlock,
      );

  void setRestoreTabs(bool enabled) => _setBool(
        enabled,
        _restoreTabs,
        (value) => _restoreTabs = value,
        _kRestoreTabs,
      );

  void setJavaScriptEnabled(bool enabled) => _setBool(
        enabled,
        _javaScriptEnabled,
        (value) => _javaScriptEnabled = value,
        _kJavaScript,
      );

  void setAutoplayEnabled(bool enabled) => _setBool(
        enabled,
        _autoplayEnabled,
        (value) => _autoplayEnabled = value,
        _kAutoplay,
      );

  void setSafeBrowsingEnabled(bool enabled) => _setBool(
        enabled,
        _safeBrowsingEnabled,
        (value) => _safeBrowsingEnabled = value,
        _kSafeBrowsing,
      );

  void setThirdPartyCookiesEnabled(bool enabled) => _setBool(
        enabled,
        _thirdPartyCookiesEnabled,
        (value) => _thirdPartyCookiesEnabled = value,
        _kThirdPartyCookies,
      );

  void setDoNotTrack(bool enabled) => _setBool(
        enabled,
        _doNotTrack,
        (value) => _doNotTrack = value,
        _kDoNotTrack,
      );

  void setCustomHomepage(String url) {
    if (_customHomepage == url) return;
    _customHomepage = url;
    _prefs.setString(_kCustomHomepage, url);
    notifyListeners();
  }

  void _setBool(
    bool value,
    bool current,
    void Function(bool) assign,
    String key,
  ) {
    if (value == current) return;
    assign(value);
    _prefs.setBool(key, value);
    notifyListeners();
  }

  void _setEnum<T extends Enum>(
    T value,
    T current,
    void Function(T) assign,
    String key,
  ) {
    if (value == current) return;
    assign(value);
    _prefs.setInt(key, value.index);
    notifyListeners();
  }

  static T _enumValue<T>(List<T> values, int? index, T fallback) {
    if (index == null || index < 0 || index >= values.length) return fallback;
    return values[index];
  }
}
