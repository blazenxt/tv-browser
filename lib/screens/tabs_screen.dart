import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/tabs_provider.dart';
import '../widgets/tv_button.dart';

/// Full-screen tab switcher, D-pad friendly.
class TabsScreen extends StatelessWidget {
  const TabsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tabsP = context.watch<TabsProvider>();
    return Scaffold(
      backgroundColor: TvStyle.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Tabs',
                  style:
                      TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  crossAxisSpacing: 18,
                  mainAxisSpacing: 18,
                  childAspectRatio: 2.1,
                  children: [
                    for (final tab in tabsP.tabs)
                      _TabCard(
                        tab: tab,
                        isCurrent:
                            tab.id == tabsP.tabs[tabsP.currentIndex].id,
                        onOpen: () {
                          context.read<TabsProvider>().select(tab.id);
                          Navigator.of(context).pop();
                        },
                        onClose: () {
                          final p = context.read<TabsProvider>();
                          final wasLast = p.count == 1;
                          p.closeTab(tab.id);
                          if (wasLast) Navigator.of(context).pop();
                        },
                      ),
                    TvButton(
                      onPressed: () {
                        context.read<TabsProvider>().newTab();
                        Navigator.of(context).pop();
                      },
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add, size: 30, color: TvStyle.accent),
                          SizedBox(height: 8),
                          Text('New tab', style: TextStyle(fontSize: 15)),
                        ],
                      ),
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
}

class _TabCard extends StatelessWidget {
  const _TabCard({
    required this.tab,
    required this.isCurrent,
    required this.onOpen,
    required this.onClose,
  });

  final BrowserTab tab;
  final bool isCurrent;
  final VoidCallback onOpen;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return TvButton(
      onPressed: onOpen,
      selected: isCurrent,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                tab.isHome ? Icons.home_outlined : Icons.public,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ),
              const SizedBox(width: 6),
              TvButton(
                icon: Icons.close,
                padding: const EdgeInsets.all(4),
                onPressed: onClose,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            tab.isHome ? 'Start page' : tab.host,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, color: Colors.white54),
          ),
          if (isCurrent)
            const Padding(
              padding: EdgeInsets.only(top: 4),
              child: Text('Current',
                  style: TextStyle(fontSize: 12, color: TvStyle.accent)),
            ),
        ],
      ),
    );
  }
}
