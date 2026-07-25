import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class HistoryProvider extends ChangeNotifier {
  HistoryProvider(this._prefs) {
    final raw = _prefs.getString(_kKey);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List<dynamic>)
          .map((e) => HistoryEntry.fromJson((e as Map).cast<String, dynamic>()))
          .where((h) => h.url.isNotEmpty)
          .toList();
      _entries.addAll(list);
    } catch (_) {
      // Corrupt history - start fresh.
    }
  }

  static const _kKey = 'history';
  static const _kMax = 300;

  final SharedPreferences _prefs;
  final List<HistoryEntry> _entries = []; // newest first

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  void add(String url, String title) {
    if (url.isEmpty) return;
    if (url.startsWith('data:') || url.startsWith('about:')) return;
    // Move repeat visits of the same page to the top instead of duplicating.
    _entries.removeWhere((e) => e.url == url);
    _entries.insert(
      0,
      HistoryEntry(
        title: title.trim().isEmpty ? url : title.trim(),
        url: url,
        visitedAt: DateTime.now().millisecondsSinceEpoch,
      ),
    );
    if (_entries.length > _kMax) {
      _entries.removeRange(_kMax, _entries.length);
    }
    _save();
    notifyListeners();
  }

  void updateTitle(String url, String title) {
    for (final e in _entries) {
      if (e.url == url) {
        e.title = title;
        _save();
        notifyListeners();
        return;
      }
    }
  }

  void removeAt(int index) {
    if (index < 0 || index >= _entries.length) return;
    _entries.removeAt(index);
    _save();
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    _save();
    notifyListeners();
  }

  /// Up to [count] most-recently visited distinct sites (by host).
  List<HistoryEntry> recentSites(int count) {
    final seen = <String>{};
    final out = <HistoryEntry>[];
    for (final e in _entries) {
      final host = _hostOf(e.url);
      if (host.isEmpty || seen.contains(host)) continue;
      seen.add(host);
      out.add(e);
      if (out.length >= count) break;
    }
    return out;
  }

  static String _hostOf(String url) {
    try {
      return Uri.parse(url).host;
    } catch (_) {
      return '';
    }
  }

  void _save() {
    _prefs.setString(
        _kKey, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }
}
