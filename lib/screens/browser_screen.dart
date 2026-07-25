import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/tabs_provider.dart';
import '../services/tv_js.dart';
import '../services/voice_service.dart';
import '../widgets/cursor_overlay.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';
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
  final FocusNode _toolbarNode = FocusNode(debugLabel: 'toolbar');
  final VoiceService _voice = VoiceService();

  Offset _cursor = const Offset(400, 250);
  Size _viewportSize = Size.zero;
  bool _cursorInitialized = false;
  bool _toolbarVisible = false;
  Timer? _toolbarTimer;

  SettingsProvider get _settings => context.read<SettingsProvider>();
  TabsProvider get _tabs => context.read<TabsProvider>();
  HistoryProvider get _history => context.read<HistoryProvider>();

  NavModeLike get _navModeLike => _settings.navMode == NavMode.spatial
      ? NavModeLike.spatial
      : NavModeLike.cursor;

  @override
  void dispose() {
    _toolbarTimer?.cancel();
    _pageKeys.dispose();
    _toolbarNode.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------------ keys

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    final isDown = event is KeyDownEvent;
    final isRepeat = event is KeyRepeatEvent;
    if (!isDown && !isRepeat) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final tab = _tabs.current;

    // While focus sits inside the toolbar let its buttons/traversal work.
    final toolbarFocused = _toolbarVisible && _toolbarNode.hasFocus;
    if (toolbarFocused) {
      _resetToolbarTimer();
      if ((key == LogicalKeyboardKey.arrowDown && isDown) ||
          (isMenuKey(key) && isDown) ||
          (isBackKey(key) && isDown)) {
        _hideToolbar();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (isMenuKey(key) && isDown) {
      _showToolbar();
      return KeyEventResult.handled;
    }
    if (isBackKey(key) && isDown) {
      unawaited(_onBack());
      return KeyEventResult.handled;
    }

    if (tab.isHome) return KeyEventResult.ignored;

    if (key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowLeft ||
        key == LogicalKeyboardKey.arrowRight) {
      _handleArrow(key, isRepeat);
      return KeyEventResult.handled;
    }
    if (isActivateKey(key) && isDown) {
      unawaited(_activate());
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
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
    setState(() => _cursor = Offset(nx, ny));
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
      if (res == 'edge' &&
          key == LogicalKeyboardKey.arrowUp &&
          !isRepeat) {
        final info = await c.evaluateJavascript(source: TvJs.pageInfo);
        if (!mounted) return;
        if (_jsonNum(info, 'y') <= 8) _showToolbar();
      }
    } catch (_) {}
  }

  // ------------------------------------------------------------ activation

  Future<void> _activate() async {
    final tab = _tabs.current;
    if (tab.isHome) return;
    final c = tab.controller;
    if (c == null) return;
    final src = _settings.navMode == NavMode.cursor
        ? TvJs.clickAt(
            _cursor.dx, _cursor.dy, _viewportSize.width, _viewportSize.height)
        : TvJs.spatialEnter;
    try {
      final res = await c.evaluateJavascript(source: src);
      if (!mounted) return;
      if (res is String && res.startsWith('{')) {
        final map = jsonDecode(res);
        if (map is Map && map['kind'] == 'input') {
          unawaited(_openWebInput(tab, map));
        }
      }
    } catch (_) {}
  }

  Future<void> _openWebInput(BrowserTab tab, Map map) async {
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
      return;
    }
    if (_tabs.count > 1) {
      _tabs.closeTab(tab.id);
      return;
    }
    final exit = await confirmDialog(
        context, 'Exit TV Browser?', 'Do you want to close the app?',
        okLabel: 'Exit');
    if (exit) SystemNavigator.pop();
  }

  // --------------------------------------------------------------- toolbar

  void _showToolbar() {
    if (_toolbarVisible) return;
    setState(() => _toolbarVisible = true);
    _resetToolbarTimer();
  }

  void _hideToolbar() {
    _toolbarTimer?.cancel();
    if (!_toolbarVisible) return;
    setState(() => _toolbarVisible = false);
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
    final added =
        context.read<BookmarksProvider>().toggle(tab.title, tab.url!);
    _toast(added ? 'Bookmark added' : 'Bookmark removed');
    _resetToolbarTimer();
  }

  void _toggleNavMode() {
    final s = _settings;
    final next =
        s.navMode == NavMode.cursor ? NavMode.spatial : NavMode.cursor;
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

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return Consumer3<TabsProvider, SettingsProvider, BookmarksProvider>(
      builder: (context, tabsP, settingsP, bookmarksP, _) {
        final tab = tabsP.current;
        return Scaffold(
          backgroundColor: Colors.black,
          body: SafeArea(
            child: Focus(
              focusNode: _pageKeys,
              autofocus: true,
              onKeyEvent: _handleKey,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  _viewportSize = constraints.biggest;
                  if (!_cursorInitialized) {
                    _cursor = Offset(
                        constraints.biggest.width / 2,
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
                      if (!tab.isHome && settingsP.navMode == NavMode.cursor)
                        Positioned.fill(
                            child: CursorOverlay(position: _cursor)),
                      if (_toolbarVisible)
                        Positioned(
                          top: 8,
                          left: 12,
                          right: 12,
                          child: Focus(
                            focusNode: _toolbarNode,
                            child: _buildToolbar(tab, tabsP, bookmarksP),
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
    );
  }

  Widget _buildTabStack(TabsProvider tabsP) {
    return IndexedStack(
      index: tabsP.currentIndex,
      children: [
        for (final t in tabsP.tabs)
          t.isHome
              ? HomePanel(onNavigate: _navigate, voice: _voice)
              : _buildWebView(t),
      ],
    );
  }

  Widget _buildWebView(BrowserTab tab) {
    return InAppWebView(
      key: ValueKey(tab.id),
      initialUrlRequest: URLRequest(url: WebUri(tab.url!)),
      initialUserScripts: UnmodifiableListView<UserScript>([
        UserScript(
          source: TvJs.script,
          injectionTime: UserScriptInjectionTime.AT_DOCUMENT_END,
        ),
      ]),
      initialSettings: InAppWebViewSettings(
        javaScriptEnabled: true,
        useHybridComposition: true,
        mediaPlaybackRequiresUserGesture: false,
        allowsInlineMediaPlayback: true,
        domStorageEnabled: true,
        useWideViewPort: true,
        loadWithOverviewMode: true,
        supportZoom: false,
        userAgent: _settings.userAgent,
        textZoom: 110,
        verticalScrollBarEnabled: false,
        horizontalScrollBarEnabled: false,
      ),
      onWebViewCreated: (controller) {
        tab.controller = controller;
        unawaited(controller.evaluateJavascript(
            source: TvJs.setMode(_navModeLike)));
      },
      onLoadStart: (controller, url) {
        tab.isLoading = true;
        tab.error = null;
        tab.progress = 0;
        if (url != null) tab.url = url.toString();
        _tabs.poke();
      },
      onLoadStop: (controller, url) {
        tab.isLoading = false;
        if (url != null) tab.url = url.toString();
        unawaited(controller.evaluateJavascript(
            source: TvJs.setMode(_navModeLike)));
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
          if (u != null) _history.updateTitle(u, title);
        }
        _tabs.poke();
      },
      onUpdateVisitedHistory: (controller, url, isReload) async {
        if (url == null) return;
        final u = url.toString();
        String title = u;
        try {
          title = (await controller.getTitle()) ?? u;
        } catch (_) {}
        if (!mounted) return;
        _history.add(u, title);
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
      color: TvStyle.background,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off, size: 56, color: Colors.white38),
          const SizedBox(height: 16),
          const Text('Could not load this page',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              tab.error ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
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
      BrowserTab tab, TabsProvider tabsP, BookmarksProvider bookmarksP) {
    final bookmarked = bookmarksP.isBookmarked(tab.url);
    final addressText =
        tab.isHome ? 'Search or enter address' : '${tab.title} — ${tab.host}';
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.88),
          borderRadius: BorderRadius.circular(TvStyle.radius),
          border: Border.all(color: Colors.white24),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            TvButton(
              icon: Icons.arrow_back,
              tooltip: 'Back',
              onPressed: () {
                tab.controller?.goBack();
                _resetToolbarTimer();
              },
            ),
            const SizedBox(width: 6),
            TvButton(
              icon: Icons.arrow_forward,
              tooltip: 'Forward',
              onPressed: () {
                tab.controller?.goForward();
                _resetToolbarTimer();
              },
            ),
            const SizedBox(width: 6),
            TvButton(
              icon: tab.isLoading ? Icons.close : Icons.refresh,
              tooltip: 'Reload / Stop',
              onPressed: () {
                if (tab.isLoading) {
                  tab.controller?.stopLoading();
                } else {
                  tab.controller?.reload();
                }
                _resetToolbarTimer();
              },
            ),
            const SizedBox(width: 6),
            TvButton(
              icon: Icons.home,
              tooltip: 'Home',
              onPressed: () {
                _hideToolbar();
                _tabs.goHome(tab);
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TvButton(
                autofocus: true,
                icon: Icons.search,
                label: addressText,
                expanded: true,
                onPressed: _openAddressDialog,
              ),
            ),
            const SizedBox(width: 10),
            TvButton(
              icon: bookmarked ? Icons.star : Icons.star_border,
              tooltip: 'Bookmark',
              selected: bookmarked,
              onPressed: tab.isHome ? null : _toggleBookmark,
            ),
            const SizedBox(width: 6),
            TvButton(
              icon: _settings.navMode == NavMode.cursor
                  ? Icons.near_me
                  : Icons.open_with,
              label: _settings.navMode == NavMode.cursor ? 'Cursor' : 'Jump',
              tooltip: 'Switch navigation mode',
              selected: _settings.navMode == NavMode.spatial,
              onPressed: _toggleNavMode,
            ),
            const SizedBox(width: 6),
            TvButton(
              icon: Icons.tab,
              label: '${tabsP.count}',
              tooltip: 'Tabs',
              onPressed: () => _pushScreen(const TabsScreen()),
            ),
            const SizedBox(width: 6),
            TvButton(
              icon: Icons.history,
              tooltip: 'History',
              onPressed: () => _pushScreen(const HistoryScreen()),
            ),
            const SizedBox(width: 6),
            TvButton(
              icon: Icons.settings,
              tooltip: 'Settings',
              onPressed: () => _pushScreen(const SettingsScreen()),
            ),
          ],
        ),
      ),
    );
  }
}
