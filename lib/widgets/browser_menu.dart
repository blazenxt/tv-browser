import 'package:flutter/material.dart';

import 'tv_button.dart';

enum BrowserMenuAction {
  newTab,
  newIncognitoTab,
  reopenClosedTab,
  bookmarks,
  history,
  downloads,
  findInPage,
  zoomOut,
  zoomReset,
  zoomIn,
  toggleDesktop,
  toggleNavigation,
  addBookmark,
  copyUrl,
  share,
  translate,
  duplicateTab,
  closeTab,
  clearBrowsingData,
  settings,
}

class BrowserMenu extends StatelessWidget {
  const BrowserMenu({
    super.key,
    required this.isHome,
    required this.isIncognito,
    required this.isBookmarked,
    required this.desktopMode,
    required this.cursorMode,
    required this.canReopenClosedTab,
    required this.zoomPercent,
    required this.host,
  });

  final bool isHome;
  final bool isIncognito;
  final bool isBookmarked;
  final bool desktopMode;
  final bool cursorMode;
  final bool canReopenClosedTab;
  final int zoomPercent;
  final String host;

  static Future<BrowserMenuAction?> show(
    BuildContext context, {
    required bool isHome,
    required bool isIncognito,
    required bool isBookmarked,
    required bool desktopMode,
    required bool cursorMode,
    required bool canReopenClosedTab,
    required int zoomPercent,
    required String host,
  }) {
    return showDialog<BrowserMenuAction>(
      context: context,
      barrierColor: Colors.black54,
      builder: (_) => BrowserMenu(
        isHome: isHome,
        isIncognito: isIncognito,
        isBookmarked: isBookmarked,
        desktopMode: desktopMode,
        cursorMode: cursorMode,
        canReopenClosedTab: canReopenClosedTab,
        zoomPercent: zoomPercent,
        host: host,
      ),
    );
  }

  void _choose(BuildContext context, BrowserMenuAction action) =>
      Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.topRight,
      insetPadding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 12),
                child: Row(
                  children: [
                    Icon(
                      isIncognito
                          ? Icons.visibility_off_rounded
                          : Icons.public_rounded,
                      color: isIncognito
                          ? TvStyle.secondaryTextOf(context)
                          : TvStyle.accent,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        isIncognito
                            ? 'Incognito tab'
                            : (host.isEmpty ? 'TV Browser' : host),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const Text(
                      '1.3',
                      style: TextStyle(fontSize: 12, color: TvStyle.accent),
                    ),
                  ],
                ),
              ),
              Divider(color: Theme.of(context).dividerColor),
              Expanded(
                child: ListView(
                  children: [
                    _item(
                      context,
                      BrowserMenuAction.newTab,
                      Icons.add_box_outlined,
                      'New tab',
                      autofocus: true,
                    ),
                    _item(
                      context,
                      BrowserMenuAction.newIncognitoTab,
                      Icons.visibility_off_outlined,
                      'New incognito tab',
                    ),
                    _item(
                      context,
                      BrowserMenuAction.reopenClosedTab,
                      Icons.restore_rounded,
                      'Reopen closed tab',
                      enabled: canReopenClosedTab,
                    ),
                    const SizedBox(height: 8),
                    _item(
                      context,
                      BrowserMenuAction.bookmarks,
                      Icons.star_border_rounded,
                      'Bookmarks',
                    ),
                    _item(
                      context,
                      BrowserMenuAction.history,
                      Icons.history_rounded,
                      'History',
                    ),
                    _item(
                      context,
                      BrowserMenuAction.downloads,
                      Icons.download_outlined,
                      'Downloads',
                    ),
                    if (!isHome) ...[
                      const SizedBox(height: 8),
                      _item(
                        context,
                        BrowserMenuAction.findInPage,
                        Icons.find_in_page_outlined,
                        'Find in page',
                      ),
                      _zoomRow(context),
                      _item(
                        context,
                        BrowserMenuAction.toggleDesktop,
                        Icons.desktop_windows_outlined,
                        'Desktop site',
                        trailing: desktopMode ? 'On' : 'Off',
                        selected: desktopMode,
                      ),
                      _item(
                        context,
                        BrowserMenuAction.toggleNavigation,
                        cursorMode
                            ? Icons.near_me_outlined
                            : Icons.open_with_rounded,
                        cursorMode ? 'Cursor navigation' : 'Jump navigation',
                        trailing: 'Switch',
                      ),
                      _item(
                        context,
                        BrowserMenuAction.addBookmark,
                        isBookmarked
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        isBookmarked ? 'Remove bookmark' : 'Add bookmark',
                        selected: isBookmarked,
                      ),
                      _item(
                        context,
                        BrowserMenuAction.copyUrl,
                        Icons.content_copy_rounded,
                        'Copy address',
                      ),
                      _item(
                        context,
                        BrowserMenuAction.share,
                        Icons.share_outlined,
                        'Share',
                      ),
                      _item(
                        context,
                        BrowserMenuAction.translate,
                        Icons.translate_rounded,
                        'Translate page',
                      ),
                      _item(
                        context,
                        BrowserMenuAction.duplicateTab,
                        Icons.copy_all_outlined,
                        'Duplicate tab',
                      ),
                      _item(
                        context,
                        BrowserMenuAction.closeTab,
                        Icons.close_rounded,
                        'Close tab',
                      ),
                    ],
                    const SizedBox(height: 8),
                    _item(
                      context,
                      BrowserMenuAction.clearBrowsingData,
                      Icons.cleaning_services_outlined,
                      'Clear browsing data',
                    ),
                    _item(
                      context,
                      BrowserMenuAction.settings,
                      Icons.settings_outlined,
                      'Settings',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _zoomRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Page zoom',
              style: TextStyle(color: TvStyle.secondaryTextOf(context)),
            ),
          ),
          TvButton(
            icon: Icons.remove,
            padding: const EdgeInsets.all(7),
            onPressed: () => _choose(context, BrowserMenuAction.zoomOut),
          ),
          const SizedBox(width: 7),
          TvButton(
            label: '$zoomPercent%',
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            onPressed: () => _choose(context, BrowserMenuAction.zoomReset),
          ),
          const SizedBox(width: 7),
          TvButton(
            icon: Icons.add,
            padding: const EdgeInsets.all(7),
            onPressed: () => _choose(context, BrowserMenuAction.zoomIn),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    BrowserMenuAction action,
    IconData icon,
    String label, {
    bool autofocus = false,
    bool enabled = true,
    bool selected = false,
    String? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: TvButton(
        autofocus: autofocus,
        icon: icon,
        label: label,
        expanded: true,
        selected: selected,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onPressed: enabled ? () => _choose(context, action) : null,
        child: Row(
          children: [
            Icon(
              icon,
              size: 21,
              color: selected ? TvStyle.accent : TvStyle.textOf(context),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: selected ? TvStyle.accent : TvStyle.textOf(context),
                  fontSize: 15,
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(
                  color: TvStyle.secondaryTextOf(context),
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
