import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class BookmarksProvider extends ChangeNotifier {
  BookmarksProvider(this._prefs) {
    final raw = _prefs.getString(_kKey);
    if (raw != null) {
      try {
        final list = (jsonDecode(raw) as List<dynamic>)
            .map((e) => Bookmark.fromJson((e as Map).cast<String, dynamic>()))
            .where((b) => b.url.isNotEmpty)
            .toList();
        _bookmarks.addAll(list);
        return;
      } catch (_) {
        // Fall through to defaults.
      }
    }
    // First run: seed a few TV-friendly defaults.
    _bookmarks.addAll([
      Bookmark(title: 'YouTube', url: 'https://www.youtube.com'),
      Bookmark(title: 'Google', url: 'https://www.google.com'),
      Bookmark(title: 'Wikipedia', url: 'https://www.wikipedia.org'),
      Bookmark(title: 'Reddit', url: 'https://www.reddit.com'),
      Bookmark(title: 'Twitch', url: 'https://www.twitch.tv'),
    ]);
    _save();
  }

  static const _kKey = 'bookmarks';

  final SharedPreferences _prefs;
  final List<Bookmark> _bookmarks = [];

  List<Bookmark> get bookmarks => List.unmodifiable(_bookmarks);

  bool isBookmarked(String? url) {
    if (url == null) return false;
    return _bookmarks.any((b) => b.url == url);
  }

  bool toggle(String title, String url) {
    final index = _bookmarks.indexWhere((b) => b.url == url);
    if (index >= 0) {
      _bookmarks.removeAt(index);
      _save();
      notifyListeners();
      return false;
    }
    _bookmarks.add(
        Bookmark(title: title.trim().isEmpty ? url : title.trim(), url: url));
    _save();
    notifyListeners();
    return true;
  }

  void removeAt(int index) {
    if (index < 0 || index >= _bookmarks.length) return;
    _bookmarks.removeAt(index);
    _save();
    notifyListeners();
  }

  void _save() {
    _prefs.setString(
        _kKey, jsonEncode(_bookmarks.map((b) => b.toJson()).toList()));
  }
}
