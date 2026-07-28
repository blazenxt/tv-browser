import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

class DownloadsProvider extends ChangeNotifier {
  DownloadsProvider(this._prefs) {
    try {
      final raw = _prefs.getString(_key);
      if (raw != null) {
        final decoded = jsonDecode(raw) as List;
        _entries.addAll(
          decoded.whereType<Map>().map(
                (value) => DownloadEntry.fromJson(
                  Map<String, dynamic>.from(value),
                ),
              ),
        );
        for (final entry in _entries) {
          if (entry.state == DownloadState.downloading) {
            entry.state = DownloadState.failed;
            entry.error = 'Download was interrupted';
          }
        }
        _save();
      }
    } catch (_) {
      _entries.clear();
    }
  }

  static const _key = 'downloadsHistory';
  final SharedPreferences _prefs;
  final List<DownloadEntry> _entries = [];

  List<DownloadEntry> get entries => List.unmodifiable(_entries.reversed);

  DownloadEntry start({
    required String fileName,
    required String url,
    int? total,
    String? mimeType,
  }) {
    final entry = DownloadEntry(
      id: 'dl_${DateTime.now().microsecondsSinceEpoch}',
      fileName: fileName,
      url: url,
      startedAt: DateTime.now().millisecondsSinceEpoch,
      total: total,
      mimeType: mimeType,
    );
    _entries.add(entry);
    _trimAndSave();
    notifyListeners();
    return entry;
  }

  void progress(DownloadEntry entry, int received, int? total) {
    entry.received = received;
    entry.total = total ?? entry.total;
    notifyListeners();
  }

  void complete(DownloadEntry entry, {String? savedLocation}) {
    entry.state = DownloadState.complete;
    entry.error = null;
    entry.savedLocation = savedLocation;
    _trimAndSave();
    notifyListeners();
  }

  void fail(DownloadEntry entry, String error) {
    entry.state = DownloadState.failed;
    entry.error = error;
    _trimAndSave();
    notifyListeners();
  }

  void remove(String id) {
    _entries.removeWhere((entry) => entry.id == id);
    _save();
    notifyListeners();
  }

  void clear() {
    _entries.clear();
    _prefs.remove(_key);
    notifyListeners();
  }

  void _trimAndSave() {
    while (_entries.length > 100) {
      _entries.removeAt(0);
    }
    _save();
  }

  void _save() => _prefs.setString(
        _key,
        jsonEncode(_entries.map((entry) => entry.toJson()).toList()),
      );
}
