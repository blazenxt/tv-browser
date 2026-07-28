import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';
import 'home_panel.dart';

/// Browsing history with per-entry delete and clear-all.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final entries = history.entries;
    return Scaffold(
      backgroundColor: TvStyle.backgroundOf(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('History',
                      style:
                          TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  if (entries.isNotEmpty)
                    TvButton(
                      icon: Icons.delete_sweep,
                      label: 'Clear all',
                      onPressed: () async {
                        final ok = await confirmDialog(
                            context, 'Clear history?', 'This cannot be undone.',
                            okLabel: 'Clear');
                        if (ok && context.mounted) {
                          context.read<HistoryProvider>().clear();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          'No history yet.',
                          style: TextStyle(
                            color: TvStyle.secondaryTextOf(context),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          final time = DateFormat('d MMM, HH:mm').format(
                              DateTime.fromMillisecondsSinceEpoch(e.visitedAt));
                          return TvButton(
                            autofocus: i == 0,
                            onPressed: () => Navigator.of(context).pop(e.url),
                            onMenu: () => history.removeAt(i),
                            child: Row(
                              children: [
                                Favicon(url: e.url),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(e.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(fontSize: 15)),
                                      const SizedBox(height: 2),
                                      Text(e.url,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              fontSize: 12,
                                              color: TvStyle.secondaryTextOf(
                                                  context))),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(time,
                                    style: TextStyle(
                                        fontSize: 12,
                                        color:
                                            TvStyle.secondaryTextOf(context))),
                                const SizedBox(width: 10),
                                TvButton(
                                  icon: Icons.close,
                                  padding: const EdgeInsets.all(4),
                                  onPressed: () => history.removeAt(i),
                                ),
                              ],
                            ),
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
