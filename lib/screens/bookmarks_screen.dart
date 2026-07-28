import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/bookmarks_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';
import 'home_panel.dart';

class BookmarksScreen extends StatelessWidget {
  const BookmarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookmarksProvider>();
    final bookmarks = provider.bookmarks;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: TvStyle.accent),
                  const SizedBox(width: 12),
                  const Text(
                    'Bookmarks',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  Text('${bookmarks.length} saved'),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: bookmarks.isEmpty
                    ? Center(
                        child: Text(
                          'No bookmarks yet',
                          style: TextStyle(
                            color: TvStyle.secondaryTextOf(context),
                            fontSize: 17,
                          ),
                        ),
                      )
                    : GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                          childAspectRatio: 3.2,
                        ),
                        itemCount: bookmarks.length,
                        itemBuilder: (context, index) {
                          final bookmark = bookmarks[index];
                          return TvButton(
                            autofocus: index == 0,
                            onPressed: () =>
                                Navigator.of(context).pop(bookmark.url),
                            onMenu: () async {
                              final remove = await confirmDialog(
                                context,
                                'Remove bookmark?',
                                bookmark.title,
                                okLabel: 'Remove',
                              );
                              if (remove && context.mounted) {
                                context
                                    .read<BookmarksProvider>()
                                    .removeAt(index);
                              }
                            },
                            child: Row(
                              children: [
                                Favicon(url: bookmark.url, size: 28),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        bookmark.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        Uri.tryParse(bookmark.url)?.host ??
                                            bookmark.url,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color:
                                              TvStyle.secondaryTextOf(context),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
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
