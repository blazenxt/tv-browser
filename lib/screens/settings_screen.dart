import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../services/voice_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';

/// App settings, laid out in big D-pad friendly rows.
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

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    return Scaffold(
      backgroundColor: TvStyle.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(36),
          children: [
            const Text('Settings',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            _Section(
              title: 'Navigation mode',
              subtitle: 'How the D-pad moves around web pages',
              options: [
                _Option('Cursor', selected: settings.navMode == NavMode.cursor,
                    onTap: () => settings.setNavMode(NavMode.cursor)),
                _Option('Jump between links',
                    selected: settings.navMode == NavMode.spatial,
                    onTap: () => settings.setNavMode(NavMode.spatial)),
              ],
              autofocusFirst: true,
            ),
            _Section(
              title: 'Cursor speed',
              options: [
                _Option('Slow',
                    selected: settings.cursorSpeed == CursorSpeed.slow,
                    onTap: () => settings.setCursorSpeed(CursorSpeed.slow)),
                _Option('Normal',
                    selected: settings.cursorSpeed == CursorSpeed.normal,
                    onTap: () => settings.setCursorSpeed(CursorSpeed.normal)),
                _Option('Fast',
                    selected: settings.cursorSpeed == CursorSpeed.fast,
                    onTap: () => settings.setCursorSpeed(CursorSpeed.fast)),
              ],
            ),
            _Section(
              title: 'Search engine',
              options: [
                _Option('Google',
                    selected: settings.searchEngine == SearchEngine.google,
                    onTap: () =>
                        settings.setSearchEngine(SearchEngine.google)),
                _Option('Bing',
                    selected: settings.searchEngine == SearchEngine.bing,
                    onTap: () => settings.setSearchEngine(SearchEngine.bing)),
                _Option('DuckDuckGo',
                    selected:
                        settings.searchEngine == SearchEngine.duckduckgo,
                    onTap: () =>
                        settings.setSearchEngine(SearchEngine.duckduckgo)),
              ],
            ),
            _Section(
              title: 'Ad & popup blocker',
              subtitle: 'Blocks known ad and tracker networks (applies to new pages)',
              options: [
                _Option('On', selected: settings.adBlockEnabled,
                    onTap: () => settings.setAdBlockEnabled(true)),
                _Option('Off', selected: !settings.adBlockEnabled,
                    onTap: () => settings.setAdBlockEnabled(false)),
              ],
            ),
            _Section(
              title: 'Text size on websites',
              subtitle: 'Applies to tabs opened afterwards',
              options: [
                _Option('Normal',
                    selected: settings.textScale == TextScaleOption.small,
                    onTap: () => settings.setTextScale(TextScaleOption.small)),
                _Option('Large',
                    selected: settings.textScale == TextScaleOption.medium,
                    onTap: () => settings.setTextScale(TextScaleOption.medium)),
                _Option('Extra large',
                    selected: settings.textScale == TextScaleOption.large,
                    onTap: () => settings.setTextScale(TextScaleOption.large)),
              ],
            ),
            _Section(
              title: 'Website requests',
              subtitle: 'Desktop mode can fix sites that look mobile-sized on TV',
              options: [
                _Option('Default (TV/mobile)',
                    selected: settings.userAgentMode == UserAgentMode.system,
                    onTap: () =>
                        settings.setUserAgentMode(UserAgentMode.system)),
                _Option('Desktop',
                    selected: settings.userAgentMode == UserAgentMode.desktop,
                    onTap: () =>
                        settings.setUserAgentMode(UserAgentMode.desktop)),
              ],
            ),
            _Section(
              title: 'New tabs open',
              options: [
                _Option('Start page',
                    selected: settings.newTabPage == NewTabPage.startPage,
                    onTap: () => settings.setNewTabPage(NewTabPage.startPage)),
                _Option(
                    settings.newTabPage == NewTabPage.custom &&
                            settings.customHomepage.isNotEmpty
                        ? settings.customHomepage
                        : 'Custom address…',
                    selected: settings.newTabPage == NewTabPage.custom,
                    onTap: () async {
                      final input = await AddressDialog.show(
                          context, settings.customHomepage, _voice);
                      if (input != null) {
                        final url = settings.toUrl(input);
                        if (url != null) {
                          settings.setCustomHomepage(url);
                          settings.setNewTabPage(NewTabPage.custom);
                        }
                      }
                    }),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  _voiceAvailable == true ? Icons.mic : Icons.mic_off,
                  color: _voiceAvailable == true
                      ? Colors.greenAccent
                      : Colors.white38,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  _voiceAvailable == true
                      ? 'Voice search available'
                      : _voiceAvailable == false
                          ? 'Voice search not available on this device'
                          : 'Checking voice search…',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Row(
              children: [
                TvButton(
                  icon: Icons.delete_sweep,
                  label: 'Clear browsing history',
                  onPressed: () async {
                    final ok = await confirmDialog(
                        context, 'Clear history?', 'This cannot be undone.',
                        okLabel: 'Clear');
                    if (ok && context.mounted) {
                      context.read<HistoryProvider>().clear();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 28),
            const Text('TV Browser 1.0.0 — made with Flutter',
                style: TextStyle(color: Colors.white38, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _Option {
  _Option(this.label, {required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;
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
      padding: const EdgeInsets.only(bottom: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle!,
                  style:
                      const TextStyle(fontSize: 13, color: Colors.white54)),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var i = 0; i < options.length; i++)
                TvButton(
                  label: options[i].label,
                  selected: options[i].selected,
                  autofocus: autofocusFirst && i == 0,
                  onPressed: options[i].onTap,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
