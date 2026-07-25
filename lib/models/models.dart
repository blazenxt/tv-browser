import 'package:flutter_inappwebview/flutter_inappwebview.dart';

/// A saved bookmark.
class Bookmark {
  Bookmark({required this.title, required this.url});

  final String title;
  final String url;

  Map<String, dynamic> toJson() => {'title': title, 'url': url};

  factory Bookmark.fromJson(Map<String, dynamic> json) => Bookmark(
        title: (json['title'] ?? '') as String,
        url: (json['url'] ?? '') as String,
      );
}

/// A single browsing-history record.
class HistoryEntry {
  HistoryEntry({
    required this.title,
    required this.url,
    required this.visitedAt,
  });

  String title;
  final String url;
  final int visitedAt; // millisecondsSinceEpoch

  Map<String, dynamic> toJson() =>
      {'title': title, 'url': url, 'visitedAt': visitedAt};

  factory HistoryEntry.fromJson(Map<String, dynamic> json) => HistoryEntry(
        title: (json['title'] ?? '') as String,
        url: (json['url'] ?? '') as String,
        visitedAt: (json['visitedAt'] ?? 0) as int,
      );
}

/// One browser tab. A tab with [url] == null shows the built-in start page.
class BrowserTab {
  BrowserTab({required this.id, this.url, String? title})
      : title = title ?? 'New Tab';

  final String id;
  String? url;
  String title;
  int progress = 0;
  bool isLoading = false;

  /// Set when the main frame fails to load; shows an error overlay.
  String? error;

  /// Live WebView controller (null while the tab shows the start page).
  InAppWebViewController? controller;

  bool get isHome => url == null;

  String get host {
    final u = url;
    if (u == null) return '';
    try {
      return Uri.parse(u).host;
    } catch (_) {
      return u;
    }
  }
}
