import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class DownloadSaveResult {
  const DownloadSaveResult({this.savedLocation, this.error});

  final String? savedLocation;
  final String? error;

  bool get success => error == null;
}

/// Downloads files triggered by the WebView and hands them to Android's
/// public Downloads collection via a small platform channel.
class DownloadService {
  DownloadService();

  static const _channel = MethodChannel('tvbrowser/downloads');
  final HttpClient _client = HttpClient()..autoUncompress = true;

  /// Human-readable size, or '' when unknown.
  static String formatSize(int? bytes) {
    if (bytes == null || bytes <= 0) return '';
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unit = 0;
    while (size >= 1024 && unit < units.length - 1) {
      size /= 1024;
      unit++;
    }
    return '${size.toStringAsFixed(size >= 10 || unit == 0 ? 0 : 1)} ${units[unit]}';
  }

  /// Downloads [url] and saves it in the public Downloads folder.
  Future<DownloadSaveResult> downloadAndSave({
    required String url,
    required String fileName,
    String? mimeType,
    void Function(int received, int? total)? onProgress,
  }) async {
    File? temp;
    try {
      final request = await _client.getUrl(Uri.parse(url));
      final response = await request.close();
      if (response.statusCode >= 400) {
        return DownloadSaveResult(
          error: 'Server returned HTTP ${response.statusCode}',
        );
      }
      final dir = await getTemporaryDirectory();
      final safe = fileName.replaceAll(RegExp(r'[^\w\-. ]'), '_');
      temp = File(
        '${dir.path}/tv_dl_${DateTime.now().millisecondsSinceEpoch}_$safe',
      );
      final sink = temp.openWrite();
      final total = response.contentLength >= 0 ? response.contentLength : null;
      var received = 0;
      await for (final chunk in response) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total);
      }
      await sink.close();

      final savedLocation = await _channel.invokeMethod<String>(
        'saveToDownloads',
        {
          'path': temp.path,
          'name': safe,
          'mime': mimeType ?? 'application/octet-stream',
        },
      );
      if (savedLocation == null || savedLocation.isEmpty) {
        await temp.delete().catchError((_) => temp!);
        return const DownloadSaveResult(
          error: 'Could not save to Downloads',
        );
      }
      return DownloadSaveResult(savedLocation: savedLocation);
    } catch (error) {
      try {
        await temp?.delete();
      } catch (_) {}
      return DownloadSaveResult(error: error.toString());
    }
  }
}
