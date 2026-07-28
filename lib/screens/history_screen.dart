import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../providers/history_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';
import 'home_panel.dart';

/// Searchable browsing history with per-entry delete and clear-all.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final history = context.watch<HistoryProvider>();
    final entries = history.entries;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? entries
        : entries
            .where((entry) =>
                entry.title.toLowerCase().contains(query) ||
                entry.url.toLowerCase().contains(query))
            .toList(growable: false);

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.history_rounded, color: TvStyle.accent),
                  const SizedBox(width: 12),
                  const Text(
                    'History',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 390,
                    child: TextField(
                      controller: _search,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search history',
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (entries.isNotEmpty)
                    TvButton(
                      icon: Icons.delete_sweep_outlined,
                      label: 'Clear all',
                      onPressed: () async {
                        final clear = await confirmDialog(
                          context,
                          'Clear history?',
                          'This cannot be undone.',
                          okLabel: 'Clear',
                        );
                        if (clear && context.mounted) {
                          context.read<HistoryProvider>().clear();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          query.isEmpty ? 'No history yet.' : 'No results',
                          style: TextStyle(
                            color: TvStyle.secondaryTextOf(context),
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entry = filtered[index];
                          final originalIndex = entries.indexWhere(
                            (item) =>
                                item.url == entry.url &&
                                item.visitedAt == entry.visitedAt,
                          );
                          final time = DateFormat('d MMM, HH:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(
                              entry.visitedAt,
                            ),
                          );
                          void remove() {
                            if (originalIndex >= 0) {
                              context
                                  .read<HistoryProvider>()
                                  .removeAt(originalIndex);
                            }
                          }

                          return TvButton(
                            autofocus: index == 0,
                            onPressed: () =>
                                Navigator.of(context).pop(entry.url),
                            onMenu: remove,
                            child: Row(
                              children: [
                                Favicon(url: entry.url),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 15),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        entry.url,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              TvStyle.secondaryTextOf(context),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  time,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: TvStyle.secondaryTextOf(context),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TvButton(
                                  icon: Icons.close_rounded,
                                  padding: const EdgeInsets.all(4),
                                  onPressed: remove,
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
