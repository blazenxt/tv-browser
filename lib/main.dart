import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/bookmarks_provider.dart';
import 'providers/downloads_provider.dart';
import 'providers/history_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/tabs_provider.dart';
import 'screens/browser_screen.dart';
import 'widgets/tv_button.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(TvBrowserApp(prefs: prefs));
}

class TvBrowserApp extends StatelessWidget {
  const TvBrowserApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
        ChangeNotifierProvider(create: (_) => BookmarksProvider(prefs)),
        ChangeNotifierProvider(create: (_) => HistoryProvider(prefs)),
        ChangeNotifierProvider(create: (_) => DownloadsProvider(prefs)),
        ChangeNotifierProxyProvider<SettingsProvider, TabsProvider>(
          create: (_) => TabsProvider(prefs),
          update: (_, settings, tabs) {
            tabs!.newTabUrlResolver = () => settings.newTabUrl;
            tabs.sessionPersistenceEnabled = settings.restoreTabs;
            return tabs;
          },
        ),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) => MaterialApp(
          title: 'TV Browser',
          debugShowCheckedModeBanner: false,
          themeMode: settings.themeMode,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          home: const BrowserScreen(),
        ),
      ),
    );
  }

  ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final scheme = ColorScheme.fromSeed(
      seedColor: TvStyle.accent,
      brightness: brightness,
      surface: dark ? const Color(0xFF292A2D) : Colors.white,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor:
          dark ? const Color(0xFF202124) : const Color(0xFFF8F9FA),
      focusColor: dark ? TvStyle.accentLight : const Color(0xFF1967D2),
      dialogTheme: DialogTheme(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TvStyle.radius + 4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor:
            dark ? const Color(0xFF3C4043) : const Color(0xFF303134),
        contentTextStyle: const TextStyle(color: Colors.white),
        behavior: SnackBarBehavior.floating,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? const Color(0xFF303134) : Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(
            color: dark ? TvStyle.accentLight : const Color(0xFF1967D2),
            width: 3,
          ),
        ),
      ),
    );
  }
}
