import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/downloads_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tabs_provider.dart';
import '../services/adblock.dart';
import '../services/download_service.dart';
import '../services/remote_control_service.dart';
import '../services/tv_js.dart';
import '../services/voice_service.dart';
import '../widgets/browser_menu.dart';
import '../widgets/cursor_overlay.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';
import 'bookmarks_screen.dart';
import 'downloads_screen.dart';
import 'history_screen.dart';
import 'home_panel.dart';
import 'settings_screen.dart';
import 'tabs_screen.dart';

/// The main screen: web content + TV toolbar + cursor overlay.
class BrowserScreen extends StatefulWidget {
  const BrowserScreen({super.key});

  @override
  State<BrowserScreen> createState() => _BrowserScreenState();
}

class _BrowserScreenState extends State<BrowserScreen> {
  final FocusNode _pageKeys = FocusNode(debugLabel: 'page');
  final FocusScopeNode _toolbarNode = FocusScopeNode(debugLabel: 'toolbar');
  final FocusNode _addressNode = FocusNode(debugLabel: 'toolbar address');
  final FocusScopeNode _findScope = FocusScopeNode(debugLabel: 'find in page');
  late final FocusNode _findField = FocusNode(
    debugLabel: 'find field',
    onKeyEvent: _handleFindFieldKey,
  );
  final TextEditingController _findController = TextEditingController();
  final Map<String, FindInteractionController> _findInteractions = {};
  final VoiceService _voice = VoiceService();
  final DownloadService _downloads = DownloadService();
  final RemoteControlService _remote = RemoteControlService.instance;

  Offset _cursor = const Offset(400, 250);
  Size _viewportSize = Size.zero;
  bool _cursorInitialized = false;
  bool _toolbarVisible = false;
  bool _findVisible = false;
  bool _backInProgress = false;
  bool _fullscreen = false;
  int _findMatches = 0;
  int _findActive = 0;
  Timer? _toolbarTimer;

  SettingsProvider get _settings => context.read<SettingsProvider>();
  TabsProvider get _tabs => context.read<TabsProvider>();
  HistoryProvider get _history => context.read<HistoryProvider>();

  NavModeLike get _navModeLike => _settings.navMode == NavMode.spatial
      ? NavModeLike.spatial
      : NavModeLike.cursor;

  @override
  void initState() {
    super.initState();
    _remote.keyHandler = _handleNativeRemoteKey;
  }

  @override
  void dispose() {
    _toolbarTimer?.cancel();
    _remote.keyHandler = null;
    _pageKeys.dispose();
    _toolbarNode.dispose();
    _addressNode.dispose();
    _findScope.dispose();
    _findField.dispose();
    _findController.dispose();
    for (final controller in _findInteractions.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // ------------------------------------------------------------------ keys

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    if (isDown && _handleKeyboardShortcut(event.logicalKey)) {
      return KeyEventResult.handled;
    }
    final button = _buttonForLogicalKey(event.logicalKey);
    if (button == null) return KeyEventResult.ignored;
    return _handleRemoteButton(
      button,
      isDown: isDown,
      isRepeat: isRepeat,
    )
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  bool _handleKeyboardShortcut(LogicalKeyboardKey key) {
    final keyboard = HardwareKeyboard.instance;
    final control = keyboard.isControlPressed || keyboard.isMetaPressed;
    if (control && key == LogicalKeyboardKey.keyL) {
      unawaited(_openAddressDialog());
      return true;
    }
    if (control && key == LogicalKeyboardKey.keyT) {
      _tabs.newTab();
      return true;
    }
    if (control && keyboard.isShiftPressed && key == LogicalKeyboardKey.keyN) {
      _tabs.newTab(incognito: true);
      return true;
    }
    if (control && key == LogicalKeyboardKey.keyW) {
      _tabs.closeTab(_tabs.current.id);
      return true;
    }
    if (control && key == LogicalKeyboardKey.keyF) {
      _showFindBar();
      return true;
    }
    if (key == LogicalKeyboardKey.f5 ||
        key == LogicalKeyboardKey.browserRefresh) {
      _tabs.current.controller?.reload();
      return true;
    }
    return false;
  }

  bool _handleNativeRemoteKey(NativeRemoteKeyEvent event) {
    if (!mounted || ModalRoute.of(context)?.isCurrent != true) return false;
    return _handleRemoteButton(
      event.button,
      isDown: event.isDown,
      isRepeat: event.isRepeat,
    );
  }

  RemoteButton? _buttonForLogicalKey(LogicalKeyboardKey key) {
    if (key == LogicalKeyboardKey.arrowUp) return RemoteButton.up;
    if (key == LogicalKeyboardKey.arrowDown) return RemoteButton.down;
    if (key == LogicalKeyboardKey.arrowLeft) return RemoteButton.left;
    if (key == LogicalKeyboardKey.arrowRight) return RemoteButton.right;
    if (isActivateKey(key)) return RemoteButton.activate;
    if (isBackKey(key)) return RemoteButton.back;
    if (isMenuKey(key)) return RemoteButton.menu;
    return null;
  }

  bool _handleRemoteButton(
    RemoteButton button, {
    required bool isDown,
    required bool isRepeat,
  }) {
    if (!isDown && !isRepeat) return false; // key-up
    final initialDown = isDown && !isRepeat;

    if (_findVisible && _findScope.hasFocus) {
      if ((button == RemoteButton.back || button == RemoteButton.menu) &&
          initialDown) {
        _closeFindBar();
        return true;
      }
      return false;
    }

    // While focus sits inside the Chrome-style toolbar, normal D-pad focus
    // traversal is preserved. BACK returns to the page; MENU opens page tools.
    if (_toolbarVisible && _toolbarNode.hasFocus) {
      _resetToolbarTimer();
      if (button == RemoteButton.back && initialDown) {
        _hideToolbar();
        return true;
      }
      if (button == RemoteButton.menu && initialDown) {
        unawaited(_openBrowserMenu());
        return true;
      }
      return false;
    }

    if (button == RemoteButton.menu && initialDown) {
      _showToolbar();
      return true;
    }
    if (button == RemoteButton.back && initialDown) {
      unawaited(_onBack());
      return true;
    }

    final tab = _tabs.current;
    if (tab.isHome) return false;

    final key = switch (button) {
      RemoteButton.up => LogicalKeyboardKey.arrowUp,
      RemoteButton.down => LogicalKeyboardKey.arrowDown,
      RemoteButton.left => LogicalKeyboardKey.arrowLeft,
      RemoteButton.right => LogicalKeyboardKey.arrowRight,
      _ => null,
    };
    if (key != null) {
      _handleArrow(key, isRepeat);
      return true;
    }
    if (button == RemoteButton.activate && initialDown) {
      unawaited(_activate());
      return true;
    }
    return false;
  }

  void _handleArrow(LogicalKeyboardKey key, bool isRepeat) {
    if (_settings.navMode == NavMode.cursor) {
      _moveCursor(key, isRepeat);
    } else {
      unawaited(_spatialMove(key, isRepeat));
    }
  }

  // ---------------------------------------------------------------- cursor

  void _moveCursor(LogicalKeyboardKey key, bool isRepeat) {
    final step = _settings.cursorStep;
    double dx = 0, dy = 0;
    if (key == LogicalKeyboardKey.arrowLeft) dx = -step;
    if (key == LogicalKeyboardKey.arrowRight) dx = step;
    if (key == LogicalKeyboardKey.arrowUp) dy = -step;
    if (key == LogicalKeyboardKey.arrowDown) dy = step;

    final w = _viewportSize.width;
    final h = _viewportSize.height;
    if (w <= 0 || h <= 0) return;

    var nx = (_cursor.dx + dx).clamp(0.0, w);
    var ny = (_cursor.dy + dy).clamp(0.0, h);

    const edge = 60.0;
    if (dy > 0 && ny > h - edge) {
      ny = h - edge;
      _scrollPage(0, step);
    } else if (dy < 0 && ny < edge) {
      ny = edge;
      unawaited(_handleUpAtTop(step, isRepeat));
    }
    if (dx > 0 && nx > w - edge) {
      nx = w - edge;
      _scrollPage(step.round(), 0);
    } else if (dx < 0 && nx < edge) {
      nx = edge;
      _scrollPage(-step.round(), 0);
    }

    setState(() => _cursor = Offset(nx, ny));
    unawaited(_remote.movePointer(nx / w, ny / h));
  }

  Future<void> _handleUpAtTop(double step, bool isRepeat) async {
    final c = _tabs.current.controller;
    if (c == null) return;
    try {
      final res = await c.evaluateJavascript(source: TvJs.pageInfo);
      final y = _jsonNum(res, 'y');
      if (!mounted) return;
      if (y > 8) {
        unawaited(
            c.evaluateJavascript(source: TvJs.scrollBy(0, -step.round())));
      } else if (!isRepeat) {
        _showToolbar();
      }
    } catch (_) {}
  }

  void _scrollPage(int dx, double dy) {
    unawaited(_tabs.current.controller
        ?.evaluateJavascript(source: TvJs.scrollBy(dx, dy.round())));
  }

  // --------------------------------------------------------------- spatial

  Future<void> _spatialMove(LogicalKeyboardKey key, bool isRepeat) async {
    final c = _tabs.current.controller;
    if (c == null) return;
    String src;
    if (key == LogicalKeyboardKey.arrowUp) {
      src = TvJs.spatialMoveUp;
    } else if (key == LogicalKeyboardKey.arrowDown) {
      src = TvJs.spatialMoveDown;
    } else if (key == LogicalKeyboardKey.arrowLeft) {
      src = TvJs.spatialMoveLeft;
    } else {
      src = TvJs.spatialMoveRight;
    }
    try {
      final res = await c.evaluateJavascript(source: src);
      final state = res?.toString().replaceAll('"', '');
      if (state != 'edge' && state != 'none') return;

      final info = await c.evaluateJavascript(source: TvJs.pageInfo);
      if (!mounted) return;
      final y = _jsonNum(info, 'y');
      final maxY = _jsonNum(info, 'max');
      final viewportHeight = _jsonNum(info, 'viewportHeight');

      if (key == LogicalKeyboardKey.arrowUp) {
        if (y <= 8) {
          if (!isRepeat) _showToolbar();
        } else {
          _scrollPage(
            0,
            -(viewportHeight * 0.7).clamp(180.0, 720.0).toDouble(),
          );
        }
      } else if (key == LogicalKeyboardKey.arrowDown && y < maxY - 8) {
        _scrollPage(
          0,
          (viewportHeight * 0.7).clamp(180.0, 720.0).toDouble(),
        );
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------ activation

  Future<void> _activate() async {
    final tab = _tabs.current;
    if (tab.isHome || _viewportSize.width <= 0 || _viewportSize.height <= 0) {
      return;
    }
    final c = tab.controller;
    if (c == null) return;
    final cursorMode = _settings.navMode == NavMode.cursor;
    final src = cursorMode
        ? TvJs.inspectAt(
            _cursor.dx, _cursor.dy, _viewportSize.width, _viewportSize.height)
        : TvJs.spatialEnter;
    try {
      final res = await c.evaluateJavascript(source: src);
      if (!mounted) return;
      final map = _jsMap(res);
      if (map?['kind'] == 'input') {
        unawaited(_openWebInput(tab, map!));
        return;
      }

      // In cursor mode even a page without the injected bridge can receive a
      // native tap. In jump mode a null result means the first target was only
      // highlighted, so SELECT should not click anything yet.
      if (map?['kind'] == 'tap' || (cursorMode && map == null)) {
        final didTap = map == null
            ? await _remote.tap(
                _cursor.dx / _viewportSize.width,
                _cursor.dy / _viewportSize.height,
              )
            : await _tapDescriptor(map);
        if (didTap || !mounted) return;

        // Older OEM WebViews may not expose a native platform view. Keep the
        // JavaScript click as a compatibility fallback.
        await c.evaluateJavascript(
          source: cursorMode
              ? TvJs.clickAt(_cursor.dx, _cursor.dy, _viewportSize.width,
                  _viewportSize.height)
              : TvJs.spatialClickFallback,
        );
      }
    } catch (_) {}
  }

  Future<bool> _tapDescriptor(Map<String, dynamic> map) {
    final x = (map['x'] as num?)?.toDouble() ?? 0;
    final y = (map['y'] as num?)?.toDouble() ?? 0;
    final width = (map['width'] as num?)?.toDouble() ?? 0;
    final height = (map['height'] as num?)?.toDouble() ?? 0;
    if (width <= 0 || height <= 0) return Future<bool>.value(false);
    return _remote.tap(x / width, y / height);
  }

  Map<String, dynamic>? _jsMap(dynamic value) {
    dynamic decoded = value;
    for (var i = 0; i < 2; i++) {
      if (decoded is! String) break;
      final text = decoded.trim();
      if (text.isEmpty || text == 'null') return null;
      try {
        decoded = jsonDecode(text);
      } catch (_) {
        return null;
      }
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Future<void> _openWebInput(BrowserTab tab, Map map) async {
    await _remote.focusFlutter();
    if (!mounted) return;
    final result = await WebInputDialog.show(
      context,
      initial: (map['value'] ?? '').toString(),
      multiline: map['multiline'] == true,
      voice: _voice,
    );
    if (result == null) return;
    final c = tab.controller;
    if (c == null) return;
    await c.evaluateJavascript(source: TvJs.setPendingValue(result.text));
    if (result.submit) {
      await c.evaluateJavascript(source: TvJs.submitPending);
    }
  }

  // ------------------------------------------------------------------ back

  Future<void> _onBack() async {
    if (_backInProgress) return;
    _backInProgress = true;
    try {
      if (_fullscreen) {
        await _tabs.current.controller?.evaluateJavascript(
          source: 'document.exitFullscreen && document.exitFullscreen();',
        );
        if (mounted) setState(() => _fullscreen = false);
        await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
        return;
      }
      if (_findVisible) {
        _closeFindBar();
        return;
      }
      if (_toolbarVisible) {
        _hideToolbar();
        return;
      }
      final tab = _tabs.current;
      if (!tab.isHome) {
        final c = tab.controller;
        try {
          if (c != null && await c.canGoBack()) {
            unawaited(c.goBack());
            return;
          }
        } catch (_) {}
        if (!mounted) return;
        if (_tabs.count > 1) {
          _tabs.closeTab(tab.id);
        } else {
          _tabs.goHome(tab);
        }
        unawaited(_remote.focusFlutter());
        return;
      }
      if (_tabs.count > 1) {
        _tabs.closeTab(tab.id);
        unawaited(_remote.focusFlutter());
        return;
      }
      final exit = await confirmDialog(
          context, 'Exit TV Browser?', 'Do you want to close the app?',
          okLabel: 'Exit');
      if (exit) SystemNavigator.pop();
    } finally {
      _backInProgress = false;
    }
  }

  // --------------------------------------------------------------- toolbar

  void _showToolbar() {
    unawaited(_remote.focusFlutter());
    if (_toolbarVisible) {
      _addressNode.requestFocus();
      _resetToolbarTimer();
      return;
    }
    setState(() => _toolbarVisible = true);
    _resetToolbarTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _toolbarVisible) _addressNode.requestFocus();
    });
  }

  void _hideToolbar() {
    _toolbarTimer?.cancel();
    if (!_toolbarVisible) return;
    _toolbarNode.unfocus();
    setState(() => _toolbarVisible = false);
    unawaited(_remote.focusFlutter());
    _pageKeys.requestFocus();
  }

  void _resetToolbarTimer() {
    _toolbarTimer?.cancel();
    _toolbarTimer = Timer(const Duration(seconds: 8), () {
      if (mounted) _hideToolbar();
    });
  }

  // -------------------------------------------------------------- navigate

  void _navigate(String input, {bool newTab = false}) {
    final url = _settings.toUrl(input);
    if (url == null) return;
    if (newTab) {
      _tabs.newTab(url: url, title: url);
      return;
    }
    final tab = _tabs.current;
    final hadWebView = tab.controller != null && !tab.isHome;
    _tabs.setUrl(tab, url);
    tab.title = url;
    _tabs.poke();
    if (hadWebView) {
      unawaited(
          tab.controller!.loadUrl(urlRequest: URLRequest(url: WebUri(url))));
    }
  }

  Future<void> _openAddressDialog() async {
    final tab = _tabs.current;
    _hideToolbar();
    final input = await AddressDialog.show(
        context, tab.isHome ? '' : (tab.url ?? ''), _voice);
    if (!mounted) return;
    if (input != null) _navigate(input);
  }

  Future<void> _pushScreen(Widget screen) async {
    _hideToolbar();
    final result = await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => screen));
    if (!mounted) return;
    // HistoryScreen pops with a URL string to open.
    if (result is String) {
      _navigate(result);
      return;
    }
    if (!_toolbarVisible) _pageKeys.requestFocus();
  }

  void _toggleBookmark() {
    final tab = _tabs.current;
    if (tab.isHome) return;
    final added = context.read<BookmarksProvider>().toggle(tab.title, tab.url!);
    _toast(added ? 'Bookmark added' : 'Bookmark removed');
    _resetToolbarTimer();
  }

  void _toggleNavMode() {
    final s = _settings;
    final next = s.navMode == NavMode.cursor ? NavMode.spatial : NavMode.cursor;
    s.setNavMode(next);
    final c = _tabs.current.controller;
    if (c != null) {
      unawaited(c.evaluateJavascript(
          source: TvJs.setMode(next == NavMode.spatial
              ? NavModeLike.spatial
              : NavModeLike.cursor)));
    }
    _toast(next == NavMode.cursor
        ? 'Cursor mode — move the pointer with the D-pad'
        : 'Jump mode — focus hops between links');
    _resetToolbarTimer();
  }

  bool _desktopMode(BrowserTab tab) =>
      tab.desktopModeOverride ??
      (_settings.userAgentMode == UserAgentMode.desktop);

  Future<void> _openBrowserMenu() async {
    _toolbarTimer?.cancel();
    await _remote.focusFlutter();
    if (!mounted) return;
    final tab = _tabs.current;
    final action = await BrowserMenu.show(
      context,
      isHome: tab.isHome,
      isIncognito: tab.isIncognito,
      isBookmarked: context.read<BookmarksProvider>().isBookmarked(tab.url),
      desktopMode: _desktopMode(tab),
      cursorMode: _settings.navMode == NavMode.cursor,
      canReopenClosedTab: _tabs.canReopenClosedTab,
      zoomPercent: (tab.pageZoom * 100).round(),
      host: tab.host,
    );
    if (!mounted || action == null) {
      _resetToolbarTimer();
      return;
    }
    _hideToolbar();
    switch (action) {
      case BrowserMenuAction.newTab:
        _tabs.newTab();
      case BrowserMenuAction.newIncognitoTab:
        _tabs.newTab(incognito: true);
      case BrowserMenuAction.reopenClosedTab:
        _tabs.reopenClosedTab();
      case BrowserMenuAction.bookmarks:
        await _pushScreen(const BookmarksScreen());
      case BrowserMenuAction.history:
        await _pushScreen(const HistoryScreen());
      case BrowserMenuAction.downloads:
        await _pushScreen(const DownloadsScreen());
      case BrowserMenuAction.findInPage:
        _showFindBar();
      case BrowserMenuAction.zoomOut:
        await _setPageZoom(tab, tab.pageZoom - 0.1);
      case BrowserMenuAction.zoomReset:
        await _setPageZoom(tab, 1);
      case BrowserMenuAction.zoomIn:
        await _setPageZoom(tab, tab.pageZoom + 0.1);
      case BrowserMenuAction.toggleDesktop:
        await _toggleDesktopMode(tab);
      case BrowserMenuAction.toggleNavigation:
        _toggleNavMode();
      case BrowserMenuAction.addBookmark:
        _toggleBookmark();
      case BrowserMenuAction.copyUrl:
        if (tab.url != null) {
          await Clipboard.setData(ClipboardData(text: tab.url!));
          _toast('Address copied');
        }
      case BrowserMenuAction.share:
        if (tab.url != null) {
          final shared = await _remote.shareText(
            '${tab.title}\n${tab.url}',
            title: 'Share ${tab.title}',
          );
          if (!shared) _toast('No sharing app is available');
        }
      case BrowserMenuAction.translate:
        if (tab.url != null) {
          final translated =
              'https://translate.google.com/translate?sl=auto&tl=en&u=${Uri.encodeComponent(tab.url!)}';
          _navigate(translated);
        }
      case BrowserMenuAction.duplicateTab:
        _tabs.duplicate(tab);
      case BrowserMenuAction.closeTab:
        _tabs.closeTab(tab.id);
      case BrowserMenuAction.clearBrowsingData:
        await _clearBrowsingData();
      case BrowserMenuAction.settings:
        await _pushScreen(const SettingsScreen());
    }
  }

  Future<void> _setPageZoom(
    BrowserTab tab,
    double requested, {
    bool announce = true,
  }) async {
    final target = requested.clamp(0.5, 2.0).toDouble();
    final controller = tab.controller;
    if (controller == null) return;
    try {
      final current = await controller.getZoomScale() ?? tab.pageZoom;
      if (current > 0) {
        await controller.zoomBy(zoomFactor: target / current, animated: true);
      }
      tab.pageZoom = target;
      _tabs.poke();
      if (announce) _toast('Page zoom ${(target * 100).round()}%');
    } catch (_) {
      _toast('Zoom is not supported on this page');
    }
  }

  Future<void> _toggleDesktopMode(BrowserTab tab) async {
    final enabled = !_desktopMode(tab);
    tab.desktopModeOverride = enabled;
    _tabs.poke();
    try {
      await tab.controller?.setSettings(
        settings: InAppWebViewSettings(
          userAgent: enabled ? SettingsProvider.desktopUserAgent : '',
        ),
      );
      await tab.controller?.reload();
      _toast(enabled ? 'Desktop site enabled' : 'TV site enabled');
    } catch (_) {}
  }

  FindInteractionController _findInteraction(BrowserTab tab) =>
      _findInteractions.putIfAbsent(
        tab.id,
        () => FindInteractionController(
          onFindResultReceived: (
            controller,
            activeMatchOrdinal,
            numberOfMatches,
            isDoneCounting,
          ) {
            if (!mounted || tab.id != _tabs.current.id) return;
            setState(() {
              _findActive = activeMatchOrdinal + (numberOfMatches > 0 ? 1 : 0);
              _findMatches = numberOfMatches;
            });
          },
        ),
      );

  KeyEventResult _handleFindFieldKey(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.arrowDown) {
      node.nextFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _showFindBar() {
    final controller = _tabs.current.controller;
    if (controller == null) return;
    _hideToolbar();
    setState(() => _findVisible = true);
    unawaited(_remote.focusFlutter());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _findVisible) _findField.requestFocus();
    });
  }

  void _closeFindBar() {
    unawaited(_findInteraction(_tabs.current).clearMatches());
    if (_findVisible) setState(() => _findVisible = false);
    _findScope.unfocus();
    _pageKeys.requestFocus();
  }

  void _findInPage(String query) {
    final controller = _tabs.current.controller;
    if (controller == null) return;
    if (query.trim().isEmpty) {
      unawaited(_findInteraction(_tabs.current).clearMatches());
      setState(() {
        _findMatches = 0;
        _findActive = 0;
      });
    } else {
      unawaited(_findInteraction(_tabs.current).findAll(find: query));
    }
  }

  Future<void> _clearBrowsingData() async {
    await _remote.focusFlutter();
    if (!mounted) return;
    final clear = await confirmDialog(
      context,
      'Clear browsing data?',
      'History, cookies, site storage and cache will be removed. Bookmarks and downloaded files stay.',
      okLabel: 'Clear data',
    );
    if (!clear || !mounted) return;
    try {
      _history.clear();
      await CookieManager.instance().deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
      await InAppWebViewController.clearAllCache();
      _toast('Browsing data cleared');
    } catch (error) {
      _toast('Could not clear all data');
    }
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ));
  }

  // ------------------------------------------------------------------ misc

  double _jsonNum(dynamic res, String k) {
    try {
      final map = res is String ? jsonDecode(res) : res;
      final v = (map as Map)[k];
      return (v as num?)?.toDouble() ?? 0;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _updateNavigationState(BrowserTab tab) async {
    final controller = tab.controller;
    if (controller == null) return;
    try {
      final canBack = await controller.canGoBack();
      final canForward = await controller.canGoForward();
      if (!mounted) return;
      tab.canGoBack = canBack;
      tab.canGoForward = canForward;
      _tabs.poke(saveSession: false);
    } catch (_) {}
  }

  Future<JsAlertResponse> _handleJsAlert(JsAlertRequest request) async {
    await _remote.focusFlutter();
    if (mounted) {
      await messageDialog(
        context,
        Uri.tryParse(request.url?.toString() ?? '')?.host ?? 'Website message',
        request.message ?? '',
      );
    }
    return JsAlertResponse(
      handledByClient: true,
      action: JsAlertResponseAction.CONFIRM,
    );
  }

  Future<JsConfirmResponse> _handleJsConfirm(JsConfirmRequest request) async {
    await _remote.focusFlutter();
    final confirmed = mounted &&
        await confirmDialog(
          context,
          'Website confirmation',
          request.message ?? '',
          okLabel: 'OK',
        );
    return JsConfirmResponse(
      handledByClient: true,
      action: confirmed
          ? JsConfirmResponseAction.CONFIRM
          : JsConfirmResponseAction.CANCEL,
    );
  }

  Future<JsPromptResponse> _handleJsPrompt(JsPromptRequest request) async {
    await _remote.focusFlutter();
    final value = mounted
        ? await textPromptDialog(
            context,
            title: 'Website prompt',
            message: request.message ?? '',
            initial: request.defaultValue ?? '',
          )
        : null;
    return JsPromptResponse(
      handledByClient: true,
      value: value,
      action: value == null
          ? JsPromptResponseAction.CANCEL
          : JsPromptResponseAction.CONFIRM,
    );
  }

  Future<PermissionResponse?> _handlePermissionRequest(
    BrowserTab tab,
    PermissionRequest request,
  ) async {
    await _remote.focusFlutter();
    if (!mounted) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }
    final labels = <String>[];
    if (request.resources.contains(PermissionResourceType.CAMERA)) {
      labels.add('camera');
    }
    if (request.resources.contains(PermissionResourceType.MICROPHONE)) {
      labels.add('microphone');
    }
    final description =
        labels.isEmpty ? 'protected device resources' : labels.join(' and ');
    final allow = await confirmDialog(
      context,
      'Allow site permission?',
      '${tab.host} wants to use your $description.',
      okLabel: 'Allow',
      cancelLabel: 'Block',
    );
    if (!allow) {
      return PermissionResponse(
        resources: request.resources,
        action: PermissionResponseAction.DENY,
      );
    }

    var systemAllowed = true;
    if (request.resources.contains(PermissionResourceType.CAMERA)) {
      systemAllowed = (await Permission.camera.request()).isGranted;
    }
    if (systemAllowed &&
        request.resources.contains(PermissionResourceType.MICROPHONE)) {
      systemAllowed = (await Permission.microphone.request()).isGranted;
    }
    return PermissionResponse(
      resources: request.resources,
      action: systemAllowed
          ? PermissionResponseAction.GRANT
          : PermissionResponseAction.DENY,
    );
  }

  Future<GeolocationPermissionShowPromptResponse> _handleGeolocation(
    String origin,
  ) async {
    await _remote.focusFlutter();
    final host = Uri.tryParse(origin)?.host ?? origin;
    final allow = mounted &&
        await confirmDialog(
          context,
          'Allow location?',
          '$host wants to know your location.',
          okLabel: 'Allow',
          cancelLabel: 'Block',
        );
    final systemAllowed =
        allow && (await Permission.location.request()).isGranted;
    return GeolocationPermissionShowPromptResponse(
      origin: origin,
      allow: systemAllowed,
      retain: false,
    );
  }

  // ------------------------------------------------------------- downloads

  Future<void> _handleDownload(DownloadStartRequest request) async {
    await _remote.focusFlutter();
    if (!mounted) return;
    final url = request.url.toString();
    var name = request.suggestedFilename ?? 'download.bin';
    if (name.isEmpty) {
      try {
        final seg = Uri.parse(url).pathSegments;
        name =
            seg.isNotEmpty && seg.last.isNotEmpty ? seg.last : 'download.bin';
      } catch (_) {
        name = 'download.bin';
      }
    }
    final size = DownloadService.formatSize(request.contentLength);
    final ok = await confirmDialog(
      context,
      'Download file?',
      size.isEmpty ? name : '$name  ($size)',
      okLabel: 'Download',
    );
    if (!ok || !mounted) return;

    final downloadsProvider = context.read<DownloadsProvider>();
    final downloadEntry = downloadsProvider.start(
      fileName: name,
      url: url,
      total: request.contentLength,
    );
    final progress = ValueNotifier<String>(
        size.isEmpty ? 'Downloading…' : 'Downloading… 0%');
    unawaited(showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: TvStyle.surfaceOf(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(TvStyle.radius)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 18),
              ValueListenableBuilder<String>(
                valueListenable: progress,
                builder: (context, text, _) => Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5)),
                    const SizedBox(width: 14),
                    Text(text),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ));

    final error = await _downloads.downloadAndSave(
      url: url,
      fileName: name,
      mimeType: request.mimeType,
      onProgress: (received, total) {
        downloadsProvider.progress(downloadEntry, received, total);
        if (total != null && total > 0) {
          final pct = (received * 100 / total).clamp(0, 100).toStringAsFixed(0);
          progress.value = 'Downloading… $pct%';
        } else {
          progress.value =
              'Downloading… ${DownloadService.formatSize(received)}';
        }
      },
    );
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pop(); // close progress
    progress.dispose();
    if (error == null) {
      downloadsProvider.complete(downloadEntry);
    } else {
      downloadsProvider.fail(downloadEntry, error);
    }
    _toast(error == null ? 'Saved to Downloads ✔' : 'Download failed: $error');
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_onBack());
      },
      child: Consumer3<TabsProvider, SettingsProvider, BookmarksProvider>(
        builder: (context, tabsP, settingsP, bookmarksP, _) {
          final tab = tabsP.current;
          return Scaffold(
            backgroundColor: TvStyle.backgroundOf(context),
            body: SafeArea(
              child: Focus(
                focusNode: _pageKeys,
                autofocus: true,
                onKeyEvent: _handleKey,
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    _viewportSize = constraints.biggest;
                    if (!_cursorInitialized) {
                      _cursor = Offset(constraints.biggest.width / 2,
                          constraints.biggest.height / 2);
                      _cursorInitialized = true;
                    }
                    _cursor = Offset(
                      _cursor.dx.clamp(0.0, constraints.biggest.width),
                      _cursor.dy.clamp(0.0, constraints.biggest.height),
                    );
                    return Stack(
                      children: [
                        Positioned.fill(child: _buildTabStack(tabsP)),
                        if (tab.isLoading && tab.progress < 100)
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: LinearProgressIndicator(
                              value: tab.progress / 100,
                              minHeight: 3,
                              color: TvStyle.accent,
                              backgroundColor: Colors.transparent,
                            ),
                          ),
                        if (!tab.isHome && tab.error != null)
                          Positioned.fill(child: _buildError(tab)),
                        if (!tab.isHome &&
                            !_fullscreen &&
                            settingsP.navMode == NavMode.cursor)
                          Positioned.fill(
                            child: CursorOverlay(position: _cursor),
                          ),
                        if (_toolbarVisible && !_fullscreen)
                          Positioned(
                            top: 8,
                            left: 12,
                            right: 12,
                            child: FocusScope(
                              node: _toolbarNode,
                              child: FocusTraversalGroup(
                                policy: ReadingOrderTraversalPolicy(),
                                child: _buildToolbar(tab, tabsP, bookmarksP),
                              ),
                            ),
                          ),
                        if (_findVisible && !_fullscreen)
                          Positioned(
                            top: 10,
                            right: 18,
                            child: FocusScope(
                              node: _findScope,
                              child: _buildFindBar(tab),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTabStack(TabsProvider tabsP) {
    return IndexedStack(
      index: tabsP.currentIndex,
      children: [
        for (final t in tabsP.tabs)
          t.isHome
              ? HomePanel(
                  onNavigate: _navigate,
                  voice: _voice,
                  incognito: t.isIncognito,
                  autofocusSearch: t.id == tabsP.current.id,
                )
              : _buildWebView(t),
      ],
    );
  }

  Widget _buildWebView(BrowserTab tab) {
    return InAppWebView(
      key: ValueKey(tab.id),
      findInteractionController: _findInteraction(tab),
      initialUrlRequest: URLRequest(
        url: WebUri(tab.url!),
        headers: _settings.doNotTrack ? {'DNT': '1'} : null,
      ),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: TvJs.script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: _settings.javaScriptEnabled,
        javaScriptCanOpenWindowsAutomatically: false,
        useHybridComposition: true,
        mediaPlaybackRequiresUserGesture: !_settings.autoplayEnabled,
        allowsInlineMediaPlayback: true,
        domStorageEnabled: !tab.isIncognito,
        databaseEnabled: !tab.isIncognito,
        cacheEnabled: !tab.isIncognito,
        incognito: tab.isIncognito,
        safeBrowsingEnabled: _settings.safeBrowsingEnabled,
        thirdPartyCookiesEnabled: _settings.thirdPartyCookiesEnabled,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        supportZoom: true,
        builtInZoomControls: true,
        displayZoomControls: false,
        userAgent: _desktopMode(tab) ? SettingsProvider.desktopUserAgent : '',
        textZoom: _settings.textZoom,
        verticalScrollBarEnabled: false,
        horizontalScrollBarEnabled: false,
        supportMultipleWindows: false,
        geolocationEnabled: true,
      ),
      shouldInterceptRequest: (controller, request) async {
        if (!_settings.adBlockEnabled) return null;
        final url = request.url.toString();
        if (url.startsWith('http') && AdBlocker.isBlocked(url)) {
          return WebResourceResponse(
            data: Uint8List(0),
            statusCode: 204,
            reasonPhrase: 'No Content',
            contentType: 'text/plain',
          );
        }
        return null;
      },
      shouldOverrideUrlLoading: (controller, navigationAction) async {
        final request = navigationAction.request;
        final url = request.url?.toString() ?? '';
        final isMainFrame = navigationAction.isForMainFrame;
        if (!isMainFrame) return NavigationActionPolicy.ALLOW;
        final scheme = Uri.tryParse(url)?.scheme.toLowerCase() ?? '';
        const webSchemes = {'http', 'https', 'about', 'data', 'blob', 'file'};
        if (url.isNotEmpty && !webSchemes.contains(scheme)) {
          final opened = await _remote.openExternal(url);
          if (!opened && mounted) _toast('No app can open this link');
          return NavigationActionPolicy.CANCEL;
        }
        // Pop-ups / new windows: never open a real new window (we have no
        // multi-window support). Gestured pop-ups load in the current tab,
        // silent ad pop-ups are cancelled.
        final asksNewWindow = navigationAction.targetFrame == null;
        if (asksNewWindow && url.isNotEmpty) {
          final gestured = navigationAction.hasGesture ?? false;
          if (gestured) {
            unawaited(
                controller.loadUrl(urlRequest: URLRequest(url: WebUri(url))));
          }
          return NavigationActionPolicy.CANCEL;
        }
        return NavigationActionPolicy.ALLOW;
      },
      onDownloadStartRequest: (controller, request) {
        unawaited(_handleDownload(request));
      },
      onJsAlert: (controller, request) => _handleJsAlert(request),
      onJsConfirm: (controller, request) => _handleJsConfirm(request),
      onJsPrompt: (controller, request) => _handleJsPrompt(request),
      onPermissionRequest: (controller, request) =>
          _handlePermissionRequest(tab, request),
      onGeolocationPermissionsShowPrompt: (controller, origin) =>
          _handleGeolocation(origin),
      onEnterFullscreen: (controller) {
        setState(() => _fullscreen = true);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      },
      onExitFullscreen: (controller) {
        setState(() => _fullscreen = false);
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      },
      onWebViewCreated: (controller) {
        tab.controller = controller;
        unawaited(
            controller.evaluateJavascript(source: TvJs.setMode(_navModeLike)));
      },
      onLoadStart: (controller, url) {
        tab.isLoading = true;
        tab.error = null;
        tab.progress = 0;
        tab.canGoBack = false;
        tab.canGoForward = false;
        if (url != null) tab.url = url.toString();
        _tabs.poke();
      },
      onLoadStop: (controller, url) {
        tab.isLoading = false;
        if (url != null) tab.url = url.toString();
        unawaited(
            controller.evaluateJavascript(source: TvJs.setMode(_navModeLike)));
        unawaited(_updateNavigationState(tab));
        if ((tab.pageZoom - 1).abs() > 0.01) {
          unawaited(_setPageZoom(tab, tab.pageZoom, announce: false));
        }
        _tabs.poke();
      },
      onProgressChanged: (controller, progress) {
        tab.progress = progress;
        _tabs.poke();
      },
      onTitleChanged: (controller, title) {
        if (title != null && title.isNotEmpty) {
          tab.title = title;
          final u = tab.url;
          if (u != null && !tab.isIncognito) {
            _history.updateTitle(u, title);
          }
        }
        _tabs.poke();
      },
      onUpdateVisitedHistory: (controller, url, isReload) async {
        if (url == null || tab.isIncognito) return;
        final u = url.toString();
        String title = u;
        try {
          title = (await controller.getTitle()) ?? u;
        } catch (_) {}
        if (!mounted) return;
        _history.add(u, title);
        unawaited(_updateNavigationState(tab));
      },
      onReceivedError: (controller, request, error) {
        if (request.isForMainFrame ?? false) {
          tab.error = error.description;
          tab.isLoading = false;
          _tabs.poke();
        }
      },
    );
  }

  Widget _buildError(BrowserTab tab) {
    return Container(
      color: TvStyle.backgroundOf(context),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wifi_off,
            size: 56,
            color: TvStyle.secondaryTextOf(context),
          ),
          const SizedBox(height: 16),
          const Text('Could not load this page',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              tab.error ?? '',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: TvStyle.secondaryTextOf(context),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TvButton(
                icon: Icons.refresh,
                label: 'Retry',
                selected: true,
                autofocus: true,
                onPressed: () {
                  tab.error = null;
                  tab.controller?.reload();
                  _tabs.poke();
                },
              ),
              const SizedBox(width: 14),
              TvButton(
                icon: Icons.home,
                label: 'Home',
                onPressed: () => _tabs.goHome(tab),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToolbar(
    BrowserTab tab,
    TabsProvider tabsP,
    BookmarksProvider bookmarksP,
  ) {
    final bookmarked = bookmarksP.isBookmarked(tab.url);
    final addressText = tab.isHome ? 'Search or type a web address' : tab.url!;
    final borderColor = Theme.of(context).dividerColor.withOpacity(0.8);
    final chromeColor = TvStyle.surfaceOf(context).withOpacity(0.97);

    return Material(
      color: Colors.transparent,
      elevation: 14,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: chromeColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildTabStrip(tabsP),
            Divider(height: 1, color: borderColor),
            Focus(
              onKeyEvent: (node, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.arrowDown) {
                  _hideToolbar();
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
                child: Row(
                  children: [
                    TvButton(
                      icon: Icons.arrow_back_rounded,
                      tooltip: 'Back',
                      padding: const EdgeInsets.all(9),
                      onPressed: tab.canGoBack
                          ? () {
                              tab.controller?.goBack();
                              _resetToolbarTimer();
                            }
                          : null,
                    ),
                    const SizedBox(width: 5),
                    TvButton(
                      icon: Icons.arrow_forward_rounded,
                      tooltip: 'Forward',
                      padding: const EdgeInsets.all(9),
                      onPressed: tab.canGoForward
                          ? () {
                              tab.controller?.goForward();
                              _resetToolbarTimer();
                            }
                          : null,
                    ),
                    const SizedBox(width: 5),
                    TvButton(
                      icon: tab.isLoading
                          ? Icons.close_rounded
                          : Icons.refresh_rounded,
                      tooltip: 'Reload / Stop',
                      padding: const EdgeInsets.all(9),
                      onPressed: tab.isHome
                          ? null
                          : () {
                              if (tab.isLoading) {
                                tab.controller?.stopLoading();
                              } else {
                                tab.controller?.reload();
                              }
                              _resetToolbarTimer();
                            },
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TvButton(
                        focusNode: _addressNode,
                        autofocus: true,
                        icon: tab.isIncognito
                            ? Icons.visibility_off_outlined
                            : tab.isHome
                                ? Icons.search_rounded
                                : tab.isSecure
                                    ? Icons.lock_outline_rounded
                                    : Icons.info_outline_rounded,
                        label: addressText,
                        expanded: true,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 11,
                        ),
                        onPressed: _openAddressDialog,
                      ),
                    ),
                    const SizedBox(width: 8),
                    TvButton(
                      icon: bookmarked
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      tooltip: 'Bookmark',
                      selected: bookmarked,
                      padding: const EdgeInsets.all(9),
                      onPressed: tab.isHome ? null : _toggleBookmark,
                    ),
                    const SizedBox(width: 5),
                    TvButton(
                      icon: _settings.navMode == NavMode.cursor
                          ? Icons.near_me_outlined
                          : Icons.open_with_rounded,
                      label: _settings.navMode == NavMode.cursor
                          ? 'Cursor'
                          : 'Jump',
                      selected: _settings.navMode == NavMode.spatial,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 9,
                      ),
                      onPressed: _toggleNavMode,
                    ),
                    const SizedBox(width: 5),
                    TvButton(
                      icon: Icons.more_vert_rounded,
                      tooltip: 'Browser menu',
                      padding: const EdgeInsets.all(9),
                      onPressed: _openBrowserMenu,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabStrip(TabsProvider tabsP) {
    return SizedBox(
      height: 52,
      child: Row(
        children: [
          const SizedBox(width: 8),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: tabsP.tabs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final tab = tabsP.tabs[index];
                final selected = tab.id == tabsP.current.id;
                return SizedBox(
                  width: 205,
                  child: TvButton(
                    selected: selected,
                    padding: const EdgeInsets.fromLTRB(10, 6, 5, 6),
                    onPressed: () {
                      tabsP.select(tab.id);
                      _resetToolbarTimer();
                    },
                    child: Row(
                      children: [
                        Icon(
                          tab.isIncognito
                              ? Icons.visibility_off_outlined
                              : tab.isHome
                                  ? Icons.public_rounded
                                  : tab.isSecure
                                      ? Icons.lock_outline_rounded
                                      : Icons.public_rounded,
                          size: 16,
                          color: tab.isIncognito
                              ? TvStyle.secondaryTextOf(context)
                              : TvStyle.accent,
                        ),
                        const SizedBox(width: 7),
                        Expanded(
                          child: Text(
                            tab.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight:
                                  selected ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                        ),
                        TvButton(
                          icon: Icons.close_rounded,
                          padding: const EdgeInsets.all(3),
                          onPressed: () => tabsP.closeTab(tab.id),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          TvButton(
            icon: Icons.add_rounded,
            tooltip: 'New tab',
            padding: const EdgeInsets.all(7),
            onPressed: () => tabsP.newTab(),
          ),
          const SizedBox(width: 5),
          TvButton(
            icon: Icons.tab_rounded,
            label: '${tabsP.count}',
            tooltip: 'Tab overview',
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            onPressed: () => _pushScreen(const TabsScreen()),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildFindBar(BrowserTab tab) {
    return Material(
      elevation: 14,
      borderRadius: BorderRadius.circular(14),
      color: TvStyle.surfaceOf(context),
      child: Container(
        width: 500,
        padding: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                controller: _findController,
                focusNode: _findField,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Find in page',
                  isDense: true,
                  contentPadding:
                      EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: _findInPage,
                onSubmitted: (_) =>
                    _findInteraction(tab).findNext(forward: true),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 70,
              child: Text(
                _findMatches == 0 ? '0 / 0' : '$_findActive / $_findMatches',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: TvStyle.secondaryTextOf(context),
                  fontSize: 12,
                ),
              ),
            ),
            TvButton(
              icon: Icons.keyboard_arrow_up_rounded,
              padding: const EdgeInsets.all(6),
              onPressed: () => _findInteraction(tab).findNext(forward: false),
            ),
            const SizedBox(width: 4),
            TvButton(
              icon: Icons.keyboard_arrow_down_rounded,
              padding: const EdgeInsets.all(6),
              onPressed: () => _findInteraction(tab).findNext(forward: true),
            ),
            const SizedBox(width: 4),
            TvButton(
              icon: Icons.close_rounded,
              padding: const EdgeInsets.all(6),
              onPressed: _closeFindBar,
            ),
          ],
        ),
      ),
    );
  }
}
