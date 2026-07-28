import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../services/voice_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';

/// Chrome-inspired settings with large, remote-friendly controls.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final VoiceService _voice = VoiceService();
  bool? _voiceAvailable;

  @override
  void initState() {
    super.initState();
    _voice.isAvailable().then((ok) {
      if (mounted) setState(() => _voiceAvailable = ok);
    });
  }

  Future<void> _clearBrowsingData() async {
    final clear = await confirmDialog(
      context,
      'Clear browsing data?',
      'History, cookies, site storage and WebView cache will be removed. Bookmarks and downloaded files stay.',
      okLabel: 'Clear data',
    );
    if (!clear || !mounted) return;
    try {
      context.read<HistoryProvider>().clear();
      await CookieManager.instance().deleteAllCookies();
      await WebStorageManager.instance().deleteAllData();
      await InAppWebViewController.clearAllCache();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Browsing data cleared')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not clear all data: $error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(36),
          children: [
            Row(
              children: [
                const Icon(Icons.tune_rounded, color: TvStyle.accent, size: 30),
                const SizedBox(width: 12),
                const Text(
                  'Settings',
                  style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  'TV Browser 1.3.0',
                  style: TextStyle(color: TvStyle.secondaryTextOf(context)),
                ),
              ],
            ),
            const SizedBox(height: 28),
            _Section(
              title: 'Appearance',
              subtitle: 'Chrome-inspired light and dark themes',
              autofocusFirst: true,
              options: [
                _Option(
                  'System',
                  icon: Icons.brightness_auto_rounded,
                  selected: settings.themePreference == ThemePreference.system,
                  onTap: () =>
                      settings.setThemePreference(ThemePreference.system),
                ),
                _Option(
                  'Light',
                  icon: Icons.light_mode_outlined,
                  selected: settings.themePreference == ThemePreference.light,
                  onTap: () =>
                      settings.setThemePreference(ThemePreference.light),
                ),
                _Option(
                  'Dark',
                  icon: Icons.dark_mode_outlined,
                  selected: settings.themePreference == ThemePreference.dark,
                  onTap: () =>
                      settings.setThemePreference(ThemePreference.dark),
                ),
              ],
            ),
            _Section(
              title: 'Remote navigation',
              subtitle: 'Choose how the D-pad moves on websites',
              options: [
                _Option(
                  'Cursor',
                  icon: Icons.near_me_outlined,
                  selected: settings.navMode == NavMode.cursor,
                  onTap: () => settings.setNavMode(NavMode.cursor),
                ),
                _Option(
                  'Jump between controls',
                  icon: Icons.open_with_rounded,
                  selected: settings.navMode == NavMode.spatial,
                  onTap: () => settings.setNavMode(NavMode.spatial),
                ),
              ],
            ),
            _Section(
              title: 'Cursor speed',
              options: [
                _Option(
                  'Slow',
                  selected: settings.cursorSpeed == CursorSpeed.slow,
                  onTap: () => settings.setCursorSpeed(CursorSpeed.slow),
                ),
                _Option(
                  'Normal',
                  selected: settings.cursorSpeed == CursorSpeed.normal,
                  onTap: () => settings.setCursorSpeed(CursorSpeed.normal),
                ),
                _Option(
                  'Fast',
                  selected: settings.cursorSpeed == CursorSpeed.fast,
                  onTap: () => settings.setCursorSpeed(CursorSpeed.fast),
                ),
              ],
            ),
            _Section(
              title: 'Search engine',
              options: [
                _Option(
                  'Google',
                  selected: settings.searchEngine == SearchEngine.google,
                  onTap: () => settings.setSearchEngine(SearchEngine.google),
                ),
                _Option(
                  'Bing',
                  selected: settings.searchEngine == SearchEngine.bing,
                  onTap: () => settings.setSearchEngine(SearchEngine.bing),
                ),
                _Option(
                  'DuckDuckGo',
                  selected: settings.searchEngine == SearchEngine.duckduckgo,
                  onTap: () =>
                      settings.setSearchEngine(SearchEngine.duckduckgo),
                ),
              ],
            ),
            _Section(
              title: 'Privacy & security',
              subtitle: 'WebView security options apply to newly opened tabs',
              options: [
                _Option(
                  'Ad & popup blocking',
                  selected: settings.adBlockEnabled,
                  onTap: () =>
                      settings.setAdBlockEnabled(!settings.adBlockEnabled),
                ),
                _Option(
                  'Safe Browsing',
                  selected: settings.safeBrowsingEnabled,
                  onTap: () => settings.setSafeBrowsingEnabled(
                    !settings.safeBrowsingEnabled,
                  ),
                ),
                _Option(
                  'Third-party cookies',
                  selected: settings.thirdPartyCookiesEnabled,
                  onTap: () => settings.setThirdPartyCookiesEnabled(
                    !settings.thirdPartyCookiesEnabled,
                  ),
                ),
                _Option(
                  'Do Not Track',
                  selected: settings.doNotTrack,
                  onTap: () => settings.setDoNotTrack(!settings.doNotTrack),
                ),
              ],
            ),
            _Section(
              title: 'Website content',
              subtitle: 'Reload or reopen a tab after changing these options',
              options: [
                _Option(
                  'JavaScript',
                  selected: settings.javaScriptEnabled,
                  onTap: () => settings
                      .setJavaScriptEnabled(!settings.javaScriptEnabled),
                ),
                _Option(
                  'Media autoplay',
                  selected: settings.autoplayEnabled,
                  onTap: () =>
                      settings.setAutoplayEnabled(!settings.autoplayEnabled),
                ),
              ],
            ),
            _Section(
              title: 'Text size on websites',
              options: [
                _Option(
                  'Normal',
                  selected: settings.textScale == TextScaleOption.small,
                  onTap: () => settings.setTextScale(TextScaleOption.small),
                ),
                _Option(
                  'Large',
                  selected: settings.textScale == TextScaleOption.medium,
                  onTap: () => settings.setTextScale(TextScaleOption.medium),
                ),
                _Option(
                  'Extra large',
                  selected: settings.textScale == TextScaleOption.large,
                  onTap: () => settings.setTextScale(TextScaleOption.large),
                ),
              ],
            ),
            _Section(
              title: 'Default website mode',
              options: [
                _Option(
                  'TV / mobile',
                  selected: settings.userAgentMode == UserAgentMode.system,
                  onTap: () => settings.setUserAgentMode(UserAgentMode.system),
                ),
                _Option(
                  'Desktop',
                  icon: Icons.desktop_windows_outlined,
                  selected: settings.userAgentMode == UserAgentMode.desktop,
                  onTap: () => settings.setUserAgentMode(UserAgentMode.desktop),
                ),
              ],
            ),
            _Section(
              title: 'On startup',
              options: [
                _Option(
                  'Restore previous tabs',
                  icon: Icons.restore_rounded,
                  selected: settings.restoreTabs,
                  onTap: () => settings.setRestoreTabs(!settings.restoreTabs),
                ),
                _Option(
                  'New tab: start page',
                  selected: settings.newTabPage == NewTabPage.startPage,
                  onTap: () => settings.setNewTabPage(NewTabPage.startPage),
                ),
                _Option(
                  settings.newTabPage == NewTabPage.custom &&
                          settings.customHomepage.isNotEmpty
                      ? settings.customHomepage
                      : 'New tab: custom address…',
                  selected: settings.newTabPage == NewTabPage.custom,
                  onTap: () async {
                    final input = await AddressDialog.show(
                      context,
                      settings.customHomepage,
                      _voice,
                    );
                    if (input != null) {
                      final url = settings.toUrl(input);
                      if (url != null) {
                        settings.setCustomHomepage(url);
                        settings.setNewTabPage(NewTabPage.custom);
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  _voiceAvailable == true ? Icons.mic : Icons.mic_off,
                  color: _voiceAvailable == true
                      ? TvStyle.chromeGreen
                      : TvStyle.secondaryTextOf(context),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _voiceAvailable == true
                      ? 'Voice search available'
                      : _voiceAvailable == false
                          ? 'Voice search is not available on this device'
                          : 'Checking voice search…',
                  style: TextStyle(color: TvStyle.secondaryTextOf(context)),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                TvButton(
                  icon: Icons.cleaning_services_outlined,
                  label: 'Clear browsing data',
                  onPressed: _clearBrowsingData,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'Uses Android System WebView. Google account sync, Chrome extensions and Chrome password manager are not available.',
              style: TextStyle(
                color: TvStyle.secondaryTextOf(context),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option {
  _Option(
    this.label, {
    required this.selected,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
}

class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.options,
    this.subtitle,
    this.autofocusFirst = false,
  });

  final String title;
  final String? subtitle;
  final List<_Option> options;
  final bool autofocusFirst;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 13,
                  color: TvStyle.secondaryTextOf(context),
                ),
              ),
            ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var index = 0; index < options.length; index++)
                TvButton(
                  icon: options[index].icon,
                  label: options[index].label,
                  selected: options[index].selected,
                  autofocus: autofocusFirst && index == 0,
                  onPressed: options[index].onTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
