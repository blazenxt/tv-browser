import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/tabs_provider.dart';
import '../widgets/tv_button.dart';

/// Chrome-style tab overview with normal and incognito tabs in one grid.
class TabsScreen extends StatelessWidget {
  const TabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tabsProvider = context.watch<TabsProvider>();
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.tab_rounded, color: TvStyle.accent),
                  const SizedBox(width: 12),
                  const Text(
                    'Tabs',
                    style: TextStyle(fontSize: 27, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text(
                    '${tabsProvider.count} open',
                    style: TextStyle(
                      color: TvStyle.secondaryTextOf(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                    childAspectRatio: 2.25,
                  ),
                  itemCount: tabsProvider.tabs.length + 2,
                  itemBuilder: (context, index) {
                    if (index == tabsProvider.tabs.length) {
                      return TvButton(
                        onPressed: () {
                          context.read<TabsProvider>().newTab();
                          Navigator.of(context).pop();
                        },
                        child: const _NewTabContent(
                          icon: Icons.add_rounded,
                          title: 'New tab',
                        ),
                      );
                    }
                    if (index == tabsProvider.tabs.length + 1) {
                      return TvButton(
                        onPressed: () {
                          context.read<TabsProvider>().newTab(incognito: true);
                          Navigator.of(context).pop();
                        },
                        child: const _NewTabContent(
                          icon: Icons.visibility_off_outlined,
                          title: 'New incognito tab',
                        ),
                      );
                    }
                    final tab = tabsProvider.tabs[index];
                    return _TabCard(
                      tab: tab,
                      autofocus: index == 0,
                      isCurrent: tab.id == tabsProvider.current.id,
                      onOpen: () {
                        context.read<TabsProvider>().select(tab.id);
                        Navigator.of(context).pop();
                      },
                      onClose: () =>
                          context.read<TabsProvider>().closeTab(tab.id),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NewTabContent extends StatelessWidget {
  const _NewTabContent({required this.icon, required this.title});

  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 31, color: TvStyle.accent),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 15)),
      ],
    );
  }
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.autofocus,
    required this.isCurrent,
    required this.onOpen,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool autofocus;
  final bool isCurrent;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TvButton(
      autofocus: autofocus,
      onPressed: onOpen,
      onMenu: onClose,
      selected: isCurrent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tab.isIncognito
                    ? Icons.visibility_off_outlined
                    : tab.isHome
                        ? Icons.public_rounded
                        : Icons.language_rounded,
                size: 19,
                color: tab.isIncognito
                    ? TvStyle.secondaryTextOf(context)
                    : TvStyle.accent,
              ),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TvButton(
                icon: Icons.close_rounded,
                padding: const EdgeInsets.all(4),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            tab.isHome
                ? (tab.isIncognito ? 'Private new tab' : 'New tab page')
                : tab.host,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              color: TvStyle.secondaryTextOf(context),
            ),
          ),
          if (isCurrent)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Current',
                style: TextStyle(fontSize: 12, color: TvStyle.accent),
              ),
            ),
        ],
      ),
    );
  }
}
