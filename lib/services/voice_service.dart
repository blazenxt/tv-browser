import 'dart:async';

import 'package:speech_to_text/speech_to_text.dart';

/// Thin wrapper around on-device speech recognition.
///
/// Many Android TVs have no microphone (or no speech service). Every method
/// degrades gracefully so the UI can hide or disable voice features.
class VoiceService {
  VoiceService();

  final SpeechToText _stt = SpeechToText();
  bool? _available;
  bool listening = false;

  Future<bool> isAvailable() async {
    final cached = _available;
    if (cached != null) return cached;
    try {
      _available = await _stt.initialize(
        onError: (_) {},
        onStatus: (_) {},
      );
    } catch (_) {
      _available = false;
    }
    return _available ?? false;
  }

  /// Listens once and returns the final transcription (or null).
  ///
  /// [onPartial] fires with interim results so the UI can show progress.
  Future<String?> listenOnce({
    required void Function(String partial) onPartial,
    void Function(bool isListening)? onState,
  }) async {
    if (!await isAvailable()) return null;
    final completer = Completer<String?>();
    String last = '';
    Timer? timeout;

    void finish(String? value) {
      if (completer.isCompleted) return;
      timeout?.cancel();
      listening = false;
      onState?.call(false);
      _stt.stop();
      completer.complete(value);
    }

    timeout = Timer(const Duration(seconds: 12), () {
      finish(last.isEmpty ? null : last);
    });

    listening = true;
    onState?.call(true);
    try {
      await _stt.listen(
        listenOptions: SpeechListenOptions(
          listenFor: const Duration(seconds: 10),
          pauseFor: const Duration(seconds: 3),
          partialResults: true,
          cancelOnError: true,
        ),
        onResult: (result) {
          last = result.recognizedWords;
          onPartial(last);
          if (result.finalResult) {
            finish(last.isEmpty ? null : last);
          }
        },
      );
    } catch (_) {
      finish(null);
    }
    return completer.future;
  }

  Future<void> cancel() async {
    listening = false;
    await _stt.cancel();
  }
}
