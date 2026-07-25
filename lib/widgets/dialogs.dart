import 'package:flutter/material.dart';

import '../services/voice_service.dart';
import 'tv_button.dart';

/// Result of the web text-input dialog.
class WebInputResult {
  WebInputResult({required this.text, required this.submit});

  final String text;
  final bool submit; // press "Enter" on the page afterwards
}

/// Address-bar dialog: type a URL or search, optionally by voice.
class AddressDialog extends StatefulWidget {
  const AddressDialog({
    super.key,
    required this.initial,
    required this.voice,
  });

  final String initial;
  final VoiceService voice;

  static Future<String?> show(
      BuildContext context, String initial, VoiceService voice) {
    return showDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (_) => AddressDialog(initial: initial, voice: voice),
    );
  }

  @override
  State<AddressDialog> createState() => _AddressDialogState();
}

class _AddressDialogState extends State<AddressDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  bool _listening = false;
  bool _voiceAvailable = true;

  @override
  void initState() {
    super.initState();
    widget.voice.isAvailable().then((ok) {
      if (mounted) setState(() => _voiceAvailable = ok);
    });
    _controller.selection =
        TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
  }

  Future<void> _listen() async {
    if (_listening) {
      await widget.voice.cancel();
      setState(() => _listening = false);
      return;
    }
    final result = await widget.voice.listenOnce(
      onPartial: (p) {
        if (mounted) {
          setState(() {
            _controller.text = p;
            _controller.selection =
                TextSelection.collapsed(offset: _controller.text.length);
          });
        }
      },
      onState: (on) {
        if (mounted) setState(() => _listening = on);
      },
    );
    if (result != null && mounted) {
      setState(() => _controller.text = result);
    }
  }

  void _go() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) Navigator.of(context).pop(text);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TvStyle.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TvStyle.radius)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Search or enter address',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                filled: true,
                fillColor: TvStyle.background,
                hintText: 'e.g. youtube.com',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TvStyle.radius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TvStyle.radius),
                  borderSide: const BorderSide(
                      color: TvStyle.focusBorder, width: TvStyle.borderWidth),
                ),
              ),
              onSubmitted: (_) => _go(),
              textInputAction: TextInputAction.go,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (_voiceAvailable)
                  TvButton(
                    icon: _listening ? Icons.mic : Icons.mic_none,
                    label: _listening ? 'Listening…' : 'Voice',
                    selected: _listening,
                    onPressed: _listen,
                  ),
                const Spacer(),
                TvButton(
                  icon: Icons.search,
                  label: 'Go',
                  selected: true,
                  onPressed: _go,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Tip: DPAD select + type with the on-screen keyboard',
              style: TextStyle(fontSize: 13, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog shown when a web page text field is "clicked". The WebView cannot
/// pop the Android keyboard without holding native focus, so text is typed
/// here and written into the page element via JavaScript.
class WebInputDialog extends StatefulWidget {
  const WebInputDialog({
    super.key,
    required this.initial,
    required this.multiline,
    required this.voice,
  });

  final String initial;
  final bool multiline;
  final VoiceService voice;

  static Future<WebInputResult?> show(
    BuildContext context, {
    required String initial,
    required bool multiline,
    required VoiceService voice,
  }) {
    return showDialog<WebInputResult>(
      context: context,
      barrierDismissible: true,
      builder: (_) => WebInputDialog(
          initial: initial, multiline: multiline, voice: voice),
    );
  }

  @override
  State<WebInputDialog> createState() => _WebInputDialogState();
}

class _WebInputDialogState extends State<WebInputDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);
  bool _listening = false;
  bool _voiceAvailable = true;

  @override
  void initState() {
    super.initState();
    widget.voice.isAvailable().then((ok) {
      if (mounted) setState(() => _voiceAvailable = ok);
    });
    _controller.selection =
        TextSelection.collapsed(offset: _controller.text.length);
  }

  Future<void> _listen() async {
    if (_listening) {
      await widget.voice.cancel();
      setState(() => _listening = false);
      return;
    }
    final result = await widget.voice.listenOnce(
      onPartial: (p) {
        if (mounted) {
          setState(() {
            _controller.text = p;
            _controller.selection =
                TextSelection.collapsed(offset: _controller.text.length);
          });
        }
      },
      onState: (on) {
        if (mounted) setState(() => _listening = on);
      },
    );
    if (result != null && mounted) setState(() => _controller.text = result);
  }

  void _finish(bool submit) {
    Navigator.of(context)
        .pop(WebInputResult(text: _controller.text, submit: submit));
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: TvStyle.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TvStyle.radius)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enter text on page',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              maxLines: widget.multiline ? 4 : 1,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                filled: true,
                fillColor: TvStyle.background,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TvStyle.radius),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(TvStyle.radius),
                  borderSide: const BorderSide(
                      color: TvStyle.focusBorder, width: TvStyle.borderWidth),
                ),
              ),
              onSubmitted: widget.multiline ? null : (_) => _finish(true),
              textInputAction:
                  widget.multiline ? TextInputAction.newline : TextInputAction.go,
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (_voiceAvailable)
                  TvButton(
                    icon: _listening ? Icons.mic : Icons.mic_none,
                    label: _listening ? 'Listening…' : 'Voice',
                    selected: _listening,
                    onPressed: _listen,
                  ),
                const Spacer(),
                TvButton(
                  icon: Icons.check,
                  label: 'Done',
                  onPressed: () => _finish(false),
                ),
                const SizedBox(width: 12),
                TvButton(
                  icon: Icons.subdirectory_arrow_left,
                  label: 'Done + Enter',
                  selected: true,
                  onPressed: () => _finish(true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple two-option confirm dialog.
Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String okLabel = 'Yes', String cancelLabel = 'Cancel'}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: TvStyle.surface,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(TvStyle.radius)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TvButton(
                  label: cancelLabel,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                const SizedBox(width: 12),
                TvButton(
                  label: okLabel,
                  selected: true,
                  autofocus: true,
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return result ?? false;
}
