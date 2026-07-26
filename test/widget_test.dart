import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tv_browser/providers/settings_provider.dart';
import 'package:tv_browser/services/adblock.dart';

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

  group('AdBlocker', () {
    test('blocks exact hosts', () {
      expect(AdBlocker.isBlocked('https://doubleclick.net/ad'), isTrue);
      expect(AdBlocker.isBlocked('https://popads.net/x'), isTrue);
    });

    test('blocks subdomains of listed hosts', () {
      expect(AdBlocker.isBlocked('https://stats.doubleclick.net/a.gif'),
          isTrue);
      expect(AdBlocker.isBlocked('https://ads.eu.criteo.com/'), isTrue);
    });

    test('allows regular sites', () {
      expect(AdBlocker.isBlocked('https://www.youtube.com/watch?v=1'), isFalse);
      expect(AdBlocker.isBlocked('https://www.google.com/search?q=ads'),
          isFalse);
    });

    test('handles malformed input', () {
      expect(AdBlocker.isBlocked(null), isFalse);
      expect(AdBlocker.isBlocked(''), isFalse);
      expect(AdBlocker.isBlocked('not a url'), isFalse);
    });
  });
}
