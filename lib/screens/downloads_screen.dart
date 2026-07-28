import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/downloads_provider.dart';
import '../services/download_service.dart';
import '../services/remote_control_service.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  Future<void> _openDownload(
    BuildContext context,
    DownloadEntry entry,
  ) async {
    final location = entry.savedLocation;
    final opened = location != null &&
        await RemoteControlService.instance.openDownload(
          location,
          mimeType: entry.mimeType,
        );
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          opened
              ? 'Opening ${entry.fileName}'
              : 'No installed app can open this file',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<DownloadsProvider>();
    final entries = provider.entries;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.download_rounded, color: TvStyle.accent),
                  const SizedBox(width: 12),
                  const Text(
                    'Downloads',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  if (entries.isNotEmpty)
                    TvButton(
                      icon: Icons.delete_sweep_outlined,
                      label: 'Clear list',
                      onPressed: () async {
                        final clear = await confirmDialog(
                          context,
                          'Clear download list?',
                          'Downloaded files will stay in the TV Downloads folder.',
                          okLabel: 'Clear',
                        );
                        if (clear && context.mounted) {
                          context.read<DownloadsProvider>().clear();
                        }
                      },
                    ),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: entries.isEmpty
                    ? Center(
                        child: Text(
                          'Files you download will appear here.',
                          style: TextStyle(
                            color: TvStyle.secondaryTextOf(context),
                            fontSize: 17,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: entries.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final entry = entries[index];
                          return TvButton(
                            autofocus: index == 0,
                            onPressed: entry.state == DownloadState.complete
                                ? () => _openDownload(context, entry)
                                : null,
                            onMenu: () => context
                                .read<DownloadsProvider>()
                                .remove(entry.id),
                            child: Row(
                              children: [
                                Icon(
                                  _icon(entry.state),
                                  color: _color(entry.state),
                                  size: 30,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.fileName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 5),
                                      if (entry.state ==
                                          DownloadState.downloading)
                                        LinearProgressIndicator(
                                          value: entry.progress,
                                          minHeight: 4,
                                        )
                                      else
                                        Text(
                                          _subtitle(entry),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: TvStyle.secondaryTextOf(
                                              context,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Text(
                                  DateFormat('d MMM, HH:mm').format(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      entry.startedAt,
                                    ),
                                  ),
                                  style: TextStyle(
                                    color: TvStyle.secondaryTextOf(context),
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                TvButton(
                                  icon: Icons.close,
                                  padding: const EdgeInsets.all(5),
                                  onPressed: () => context
                                      .read<DownloadsProvider>()
                                      .remove(entry.id),
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

  static IconData _icon(DownloadState state) {
    switch (state) {
      case DownloadState.downloading:
        return Icons.downloading_rounded;
      case DownloadState.complete:
        return Icons.check_circle_rounded;
      case DownloadState.failed:
        return Icons.error_rounded;
    }
  }

  static Color _color(DownloadState state) {
    switch (state) {
      case DownloadState.downloading:
        return TvStyle.accent;
      case DownloadState.complete:
        return TvStyle.chromeGreen;
      case DownloadState.failed:
        return TvStyle.chromeRed;
    }
  }

  static String _subtitle(DownloadEntry entry) {
    if (entry.state == DownloadState.failed) {
      return entry.error ?? 'Download failed';
    }
    final size = DownloadService.formatSize(entry.received);
    return size.isEmpty ? 'Saved to Downloads' : '$size • Saved to Downloads';
  }
}
