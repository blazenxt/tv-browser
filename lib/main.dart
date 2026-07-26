import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers/bookmarks_provider.dart';
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
        ChangeNotifierProxyProvider<SettingsProvider, TabsProvider>(
          create: (_) => TabsProvider(),
          update: (_, settings, tabs) =>
              tabs!..newTabUrlResolver = () => settings.newTabUrl,
        ),
      ],
      child: MaterialApp(
        title: 'TV Browser',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          brightness: Brightness.dark,
          colorScheme: ColorScheme.fromSeed(
            seedColor: TvStyle.accent,
            brightness: Brightness.dark,
          ),
          scaffoldBackgroundColor: TvStyle.background,
          snackBarTheme: const SnackBarThemeData(
            backgroundColor: TvStyle.surfaceAlt,
            contentTextStyle: TextStyle(color: Colors.white),
          ),
        ),
        home: const BrowserScreen(),
      ),
    );
  }
}
