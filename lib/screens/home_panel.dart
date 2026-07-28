import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/bookmarks_provider.dart';
import '../providers/history_provider.dart';
import '../providers/settings_provider.dart';
import '../services/voice_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';

/// Chrome-inspired new-tab page, laid out for a TV viewing distance.
class HomePanel extends StatelessWidget {
  const HomePanel({
    super.key,
    required this.onNavigate,
    required this.voice,
    this.autofocusSearch = true,
    this.incognito = false,
  });

  final void Function(String input) onNavigate;
  final VoiceService voice;
  final bool autofocusSearch;
  final bool incognito;

  @override
  Widget build(BuildContext context) {
    final bookmarks = context.watch<BookmarksProvider>();
    final history = context.watch<HistoryProvider>();
    final settings = context.watch<SettingsProvider>();
    final recent = incognito ? <HistoryEntry>[] : history.recentSites(6);
    final shortcuts = incognito
        ? <Bookmark>[]
        : bookmarks.bookmarks.take(8).toList(growable: false);

    return ColoredBox(
      color: TvStyle.backgroundOf(context),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(60, 44, 60, 46),
          children: [
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 980),
                child: Column(
                  children: [
                    _BrowserMark(incognito: incognito),
                    const SizedBox(height: 14),
                    Text(
                      incognito ? 'Incognito' : 'TV Browser',
                      style: const TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      incognito
                          ? 'Pages from this tab are not added to history.'
                          : 'Search with ${settings.searchEngineName}',
                      style: TextStyle(
                        color: TvStyle.secondaryTextOf(context),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 26),
                    Row(
                      children: [
                        Expanded(
                          child: TvButton(
                            autofocus: autofocusSearch,
                            icon: incognito
                                ? Icons.visibility_off_outlined
                                : Icons.search_rounded,
                            label: 'Search or type a web address',
                            expanded: true,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 22,
                              vertical: 17,
                            ),
                            onPressed: () async {
                              final input = await AddressDialog.show(
                                context,
                                '',
                                voice,
                              );
                              if (input != null) onNavigate(input);
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        TvButton(
                          icon: Icons.mic_none_rounded,
                          label: 'Voice',
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 17,
                          ),
                          onPressed: () async {
                            final said =
                                await voice.listenOnce(onPartial: (_) {});
                            if (said != null) onNavigate(said);
                          },
                        ),
                      ],
                    ),
                    if (incognito) ...[
                      const SizedBox(height: 34),
                      _IncognitoInfo(),
                    ] else ...[
                      if (shortcuts.isNotEmpty) ...[
                        const SizedBox(height: 34),
                        const _SectionHeader(
                          title: 'Shortcuts',
                          subtitle: 'MENU on a shortcut removes it',
                        ),
                        const SizedBox(height: 13),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 4,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 14,
                            childAspectRatio: 2.35,
                          ),
                          itemCount: shortcuts.length,
                          itemBuilder: (context, index) {
                            final bookmark = shortcuts[index];
                            return _ShortcutCard(
                              bookmark: bookmark,
                              onOpen: onNavigate,
                              onDelete: () {
                                final originalIndex = bookmarks.bookmarks
                                    .indexWhere(
                                        (item) => item.url == bookmark.url);
                                if (originalIndex >= 0) {
                                  bookmarks.removeAt(originalIndex);
                                }
                              },
                            );
                          },
                        ),
                      ],
                      if (recent.isNotEmpty) ...[
                        const SizedBox(height: 30),
                        const _SectionHeader(title: 'Recently visited'),
                        const SizedBox(height: 13),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          children: [
                            for (final entry in recent)
                              _RecentChip(entry: entry, onOpen: onNavigate),
                          ],
                        ),
                      ],
                    ],
                    const SizedBox(height: 36),
                    Text(
                      'MENU: browser controls  •  D-pad: move  •  OK: select  •  BACK: go back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: TvStyle.secondaryTextOf(context),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowserMark extends StatelessWidget {
  const _BrowserMark({required this.incognito});

  final bool incognito;

  @override
  Widget build(BuildContext context) {
    if (incognito) {
      return Container(
        width: 68,
        height: 68,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TvStyle.surfaceAltOf(context),
        ),
        child: const Icon(Icons.visibility_off_rounded, size: 34),
      );
    }
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const SweepGradient(
          colors: [
            TvStyle.chromeRed,
            TvStyle.chromeYellow,
            TvStyle.chromeGreen,
            TvStyle.accent,
            TvStyle.chromeRed,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(15),
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: TvStyle.surfaceOf(context),
        ),
        child:
            const Icon(Icons.public_rounded, color: TvStyle.accent, size: 29),
      ),
    );
  }
}

class _IncognitoInfo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: TvStyle.surfaceOf(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.shield_outlined, color: TvStyle.accent, size: 30),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Private on this device',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 7),
                Text(
                  'History and form data from incognito tabs are not saved. Downloads and bookmarks are still kept. Your network and websites may still see your activity.',
                  style: TextStyle(
                    color: TvStyle.secondaryTextOf(context),
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        if (subtitle != null) ...[
          const Spacer(),
          Text(
            subtitle!,
            style: TextStyle(
              color: TvStyle.secondaryTextOf(context),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _ShortcutCard extends StatelessWidget {
  const _ShortcutCard({
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
        final remove = await confirmDialog(
          context,
          'Remove shortcut?',
          bookmark.title,
          okLabel: 'Remove',
        );
        if (remove) onDelete();
      },
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          Favicon(url: bookmark.url, size: 30),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bookmark.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _host(bookmark.url),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    color: TvStyle.secondaryTextOf(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _host(String url) {
    final host = Uri.tryParse(url)?.host ?? url;
    return host.startsWith('www.') ? host.substring(4) : host;
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
          Favicon(url: entry.url, size: 18),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 190),
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
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? '';
    if (host.isEmpty) {
      return Icon(
        Icons.public,
        size: size,
        color: TvStyle.secondaryTextOf(context),
      );
    }
    final src = 'https://www.google.com/s2/favicons?domain=$host&sz=64';
    return Image.network(
      src,
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.public,
        size: size,
        color: TvStyle.secondaryTextOf(context),
      ),
      loadingBuilder: (context, child, progress) => progress == null
          ? child
          : Icon(
              Icons.public,
              size: size,
              color: TvStyle.secondaryTextOf(context).withOpacity(0.55),
            ),
    );
  }
}
