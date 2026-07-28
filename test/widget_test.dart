import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_browser/models/models.dart';
import 'package:tv_browser/providers/downloads_provider.dart';
import 'package:tv_browser/providers/settings_provider.dart';
import 'package:tv_browser/providers/tabs_provider.dart';
import 'package:tv_browser/services/adblock.dart';
import 'package:tv_browser/services/remote_control_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<SettingsProvider> makeSettings() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return SettingsProvider(prefs);
  }

  group('SettingsProvider.toUrl', () {
    test('passes through full URLs', () async {
      final s = await makeSettings();
      expect(s.toUrl('https://example.com/x'), 'https://example.com/x');
      expect(s.toUrl('http://example.com'), 'http://example.com');
    });

    test('adds https:// to plain domains', () async {
      final s = await makeSettings();
      expect(s.toUrl('youtube.com'), 'https://youtube.com');
    });

    test('searches for phrases', () async {
      final s = await makeSettings();
      expect(s.toUrl('dart programming language'),
          'https://www.google.com/search?q=dart%20programming%20language');
    });

    test('returns null for empty input', () async {
      final s = await makeSettings();
      expect(s.toUrl('   '), isNull);
    });
  });

  group('Appearance and privacy settings', () {
    test('persists theme and browser toggles', () async {
      final settings = await makeSettings();
      settings.setThemePreference(ThemePreference.light);
      settings.setRestoreTabs(false);
      settings.setThirdPartyCookiesEnabled(false);

      expect(settings.themePreference, ThemePreference.light);
      expect(settings.restoreTabs, isFalse);
      expect(settings.thirdPartyCookiesEnabled, isFalse);
    });

    test('ignores invalid saved enum indexes', () async {
      SharedPreferences.setMockInitialValues({'themePreference': 999});
      final prefs = await SharedPreferences.getInstance();
      final settings = SettingsProvider(prefs);
      expect(settings.themePreference, ThemePreference.system);
    });
  });

  group('Tab sessions and incognito', () {
    test('reopens a closed normal tab', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tabs = TabsProvider(prefs);
      final tab = tabs.newTab(url: 'https://example.com');
      tabs.closeTab(tab.id);

      expect(tabs.canReopenClosedTab, isTrue);
      final reopened = tabs.reopenClosedTab();
      expect(reopened?.url, 'https://example.com');
    });

    test('does not persist incognito tabs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final tabs = TabsProvider(prefs);
      tabs.newTab(url: 'https://private.example', incognito: true);

      final restored = TabsProvider(prefs);
      expect(restored.tabs.any((tab) => tab.isIncognito), isFalse);
      expect(restored.tabs.any((tab) => tab.url == 'https://private.example'),
          isFalse);
    });
  });

  group('Download history', () {
    test('tracks completion and failure', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final downloads = DownloadsProvider(prefs);
      final complete = downloads.start(
        fileName: 'video.mp4',
        url: 'https://example.com/video.mp4',
        total: 100,
      );
      downloads.progress(complete, 100, 100);
      downloads.complete(complete);
      final failed = downloads.start(
        fileName: 'bad.zip',
        url: 'https://example.com/bad.zip',
      );
      downloads.fail(failed, 'Network error');

      expect(complete.state, DownloadState.complete);
      expect(complete.progress, 1);
      expect(failed.state, DownloadState.failed);
      expect(failed.error, 'Network error');
    });
  });

  group('Android TV / Fire TV remote mapping', () {
    test('maps D-pad directions', () {
      expect(RemoteButton.fromAndroidKeyCode(19), RemoteButton.up);
      expect(RemoteButton.fromAndroidKeyCode(20), RemoteButton.down);
      expect(RemoteButton.fromAndroidKeyCode(21), RemoteButton.left);
      expect(RemoteButton.fromAndroidKeyCode(22), RemoteButton.right);
    });

    test('maps common select, back and menu variants', () {
      for (final code in [23, 66, 96, 109, 160]) {
        expect(RemoteButton.fromAndroidKeyCode(code), RemoteButton.activate);
      }
      for (final code in [4, 97, 111]) {
        expect(RemoteButton.fromAndroidKeyCode(code), RemoteButton.back);
      }
      for (final code in [82, 84, 256, 257]) {
        expect(RemoteButton.fromAndroidKeyCode(code), RemoteButton.menu);
      }
    });

    test('leaves unrelated keys alone', () {
      expect(RemoteButton.fromAndroidKeyCode(85), RemoteButton.unknown);
    });
  });

  group('AdBlocker', () {
    test('blocks exact hosts', () {
      expect(AdBlocker.isBlocked('https://doubleclick.net/ad'), isTrue);
      expect(AdBlocker.isBlocked('https://popads.net/x'), isTrue);
    });

    test('blocks subdomains of listed hosts', () {
      expect(
          AdBlocker.isBlocked('https://stats.doubleclick.net/a.gif'), isTrue);
      expect(AdBlocker.isBlocked('https://ads.eu.criteo.com/'), isTrue);
    });

    test('allows regular sites', () {
      expect(AdBlocker.isBlocked('https://www.youtube.com/watch?v=1'), isFalse);
      expect(
          AdBlocker.isBlocked('https://www.google.com/search?q=ads'), isFalse);
    });

    test('handles malformed input', () {
      expect(AdBlocker.isBlocked(null), isFalse);
      expect(AdBlocker.isBlocked(''), isFalse);
      expect(AdBlocker.isBlocked('not a url'), isFalse);
    });
  });
}
