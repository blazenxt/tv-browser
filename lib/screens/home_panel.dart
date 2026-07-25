import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../services/voice_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';

/// Built-in start page shown for fresh tabs.
class HomePanel extends StatelessWidget {
  const HomePanel({
    super.key,
    required this.onNavigate,
    required this.voice,
    this.autofocusSearch = true,
  });

  final void Function(String input) onNavigate;
  final VoiceService voice;
  final bool autofocusSearch;

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<BookmarksProvider>();
    final history = context.watch<HistoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final recent = history.recentSites(6);
    final firstSearch = ValueNotifier<bool>(autofocusSearch);

    return Container(
      color: TvStyle.background,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(48, 36, 48, 48),
          children: [
            Row(
              children: [
                const Icon(Icons.public, size: 34, color: TvStyle.accent),
                const SizedBox(width: 12),
                const Text('TV Browser',
                    style:
                        TextStyle(fontSize: 28, fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  'Search: ${settings.searchEngineName}',
                  style: const TextStyle(color: Colors.white54, fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 28),
            ValueListenableBuilder<bool>(
              valueListenable: firstSearch,
              builder: (context, first, _) => Row(
                children: [
                  Expanded(
                    child: TvButton(
                      autofocus: first,
                      icon: Icons.search,
                      label: 'Search the web or enter an address',
                      expanded: true,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 16),
                      onPressed: () async {
                        final input =
                            await AddressDialog.show(context, '', voice);
                        if (input != null) onNavigate(input);
                      },
                    ),
                  ),
                  const SizedBox(width: 14),
                  TvButton(
                    icon: Icons.mic_none,
                    tooltip: 'Voice search',
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 16),
                    onPressed: () async {
                      final said = await voice.listenOnce(onPartial: (_) {});
                      if (said != null) onNavigate(said);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const _SectionTitle('Bookmarks'),
            const SizedBox(height: 12),
            if (bookmarks.bookmarks.isEmpty)
              const Text('No bookmarks yet. Press the ★ button on any page.',
                  style: TextStyle(color: Colors.white54))
            else
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (var i = 0; i < bookmarks.bookmarks.length; i++)
                    _BookmarkCard(
                      bookmark: bookmarks.bookmarks[i],
                      onOpen: onNavigate,
                      onDelete: () => bookmarks.removeAt(i),
                    ),
                ],
              ),
            if (recent.isNotEmpty) ...[
              const SizedBox(height: 32),
              const _SectionTitle('Recent'),
              const SizedBox(height: 12),
              Wrap(
                spacing: 14,
                runSpacing: 14,
                children: [
                  for (final e in recent)
                    _RecentChip(entry: e, onOpen: onNavigate),
                ],
              ),
            ],
            const SizedBox(height: 40),
            const Text(
              'Controls:  MENU opens the address bar  •  D-pad moves  •  OK clicks  •  BACK goes back',
              style: TextStyle(color: Colors.white38, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600));
  }
}

class _BookmarkCard extends StatelessWidget {
  const _BookmarkCard({
    required this.bookmark,
    required this.onOpen,
    required this.onDelete,
  });

  final Bookmark bookmark;
  final void Function(String input) onOpen;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return TvButton(
      onPressed: () => onOpen(bookmark.url),
      onMenu: () async {
        if (await confirmDialog(
            context, 'Remove bookmark?', bookmark.title,
            okLabel: 'Remove')) {
          onDelete();
        }
      },
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SizedBox(
        width: 170,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _Favicon(url: bookmark.url, size: 30),
            const SizedBox(height: 10),
            Text(
              bookmark.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 2),
            Text(
              _host(bookmark.url),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: Colors.white54),
            ),
          ],
        ),
      ),
    );
  }

  static String _host(String url) {
    try {
      final h = Uri.parse(url).host;
      return h.startsWith('www.') ? h.substring(4) : h;
    } catch (_) {
      return url;
    }
  }
}

class _RecentChip extends StatelessWidget {
  const _RecentChip({required this.entry, required this.onOpen});

  final HistoryEntry entry;
  final void Function(String input) onOpen;

  @override
  Widget build(BuildContext context) {
    return TvButton(
      onPressed: () => onOpen(entry.url),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _Favicon(url: entry.url, size: 18),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Text(
              entry.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}

/// Site favicon via Google's S2 service, with a graceful fallback icon.
class Favicon extends StatelessWidget {
  const Favicon({super.key, required this.url, this.size = 22});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) => _Favicon(url: url, size: size);
}

class _Favicon extends StatelessWidget {
  const _Favicon({required this.url, this.size = 22});

  final String url;
  final double size;

  @override
  Widget build(BuildContext context) {
    String host;
    try {
      host = Uri.parse(url).host;
    } catch (_) {
      host = '';
    }
    if (host.isEmpty) {
      return Icon(Icons.public, size: size, color: Colors.white70);
    }
    final src =
        'https://www.google.com/s2/favicons?domain=$host&sz=64';
    return Image.network(
      src,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) =>
          Icon(Icons.public, size: size, color: Colors.white70),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Icon(Icons.public, size: size, color: Colors.white38),
    );
  }
}
