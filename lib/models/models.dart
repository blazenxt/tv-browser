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
  BrowserTab({
    required this.id,
    this.url,
    String? title,
    this.isIncognito = false,
    this.desktopModeOverride,
    this.pageZoom = 1,
  }) : title = title ?? (isIncognito ? 'Incognito' : 'New Tab');

  final String id;
  String? url;
  String title;
  final bool isIncognito;
  bool? desktopModeOverride;
  double pageZoom;
  bool readerMode = false;
  bool muted = false;
  int progress = 0;
  bool isLoading = false;
  bool canGoBack = false;
  bool canGoForward = false;

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

  bool get isSecure => url?.startsWith('https://') ?? false;

  Map<String, dynamic> toSessionJson() => {
        'url': url,
        'title': title,
        'desktopModeOverride': desktopModeOverride,
        'pageZoom': pageZoom,
      };
}

enum DownloadState { downloading, complete, failed }

class DownloadEntry {
  DownloadEntry({
    required this.id,
    required this.fileName,
    required this.url,
    required this.startedAt,
    this.received = 0,
    this.total,
    this.state = DownloadState.downloading,
    this.error,
    this.savedLocation,
    this.mimeType,
  });

  final String id;
  final String fileName;
  final String url;
  final int startedAt;
  int received;
  int? total;
  DownloadState state;
  String? error;
  String? savedLocation;
  String? mimeType;

  double? get progress => total != null && total! > 0
      ? (received / total!).clamp(0.0, 1.0).toDouble()
      : null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'url': url,
        'startedAt': startedAt,
        'received': received,
        'total': total,
        'state': state.index,
        'error': error,
        'savedLocation': savedLocation,
        'mimeType': mimeType,
      };

  factory DownloadEntry.fromJson(Map<String, dynamic> json) {
    final stateIndex = (json['state'] as num?)?.toInt() ?? 2;
    return DownloadEntry(
      id: (json['id'] ?? '').toString(),
      fileName: (json['fileName'] ?? 'download').toString(),
      url: (json['url'] ?? '').toString(),
      startedAt: (json['startedAt'] as num?)?.toInt() ?? 0,
      received: (json['received'] as num?)?.toInt() ?? 0,
      total: (json['total'] as num?)?.toInt(),
      state: stateIndex >= 0 && stateIndex < DownloadState.values.length
          ? DownloadState.values[stateIndex]
          : DownloadState.failed,
      error: json['error']?.toString(),
      savedLocation: json['savedLocation']?.toString(),
      mimeType: json['mimeType']?.toString(),
    );
  }
}
