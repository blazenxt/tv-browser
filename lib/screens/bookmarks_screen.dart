import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../models/models.dart';
import '../providers/bookmarks_provider.dart';
import '../widgets/dialogs.dart';
import '../widgets/tv_button.dart';
import 'home_panel.dart';

class BookmarksScreen extends StatefulWidget {
  const BookmarksScreen({super.key});

  @override
  State<BookmarksScreen> createState() => _BookmarksScreenState();
}

class _BookmarksScreenState extends State<BookmarksScreen> {
  final TextEditingController _searchController = TextEditingController();
  late final FocusNode _searchNode = FocusNode(
    debugLabel: 'bookmark search',
    onKeyEvent: (node, event) {
      if (event is KeyDownEvent &&
          event.logicalKey == LogicalKeyboardKey.arrowDown) {
        node.nextFocus();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    },
  );
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    _searchNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<BookmarksProvider>();
    final bookmarks = provider.bookmarks;
    final query = _query.trim().toLowerCase();
    final filtered = query.isEmpty
        ? bookmarks
        : bookmarks
            .where((bookmark) =>
                bookmark.title.toLowerCase().contains(query) ||
                bookmark.url.toLowerCase().contains(query))
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
                  const Icon(Icons.star_rounded, color: TvStyle.accent),
                  const SizedBox(width: 12),
                  const Text(
                    'Bookmarks',
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 390,
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchNode,
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search_rounded),
                        hintText: 'Search bookmarks',
                        isDense: true,
                      ),
                      onChanged: (value) => setState(() => _query = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text('${bookmarks.length} saved'),
                ],
              ),
              const SizedBox(height: 22),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Text(
                          query.isEmpty
                              ? 'No bookmarks yet'
                              : 'No matching bookmarks',
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
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final bookmark = filtered[index];
                          return _BookmarkTile(
                            bookmark: bookmark,
                            autofocus: index == 0,
                            onOpen: () =>
                                Navigator.of(context).pop(bookmark.url),
                            onRemove: () async {
                              final remove = await confirmDialog(
                                context,
                                'Remove bookmark?',
                                bookmark.title,
                                okLabel: 'Remove',
                              );
                              if (!remove || !context.mounted) return;
                              final originalIndex =
                                  provider.bookmarks.indexWhere(
                                (item) => item.url == bookmark.url,
                              );
                              if (originalIndex >= 0) {
                                provider.removeAt(originalIndex);
                              }
                            },
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

class _BookmarkTile extends StatelessWidget {
  const _BookmarkTile({
    required this.bookmark,
    required this.autofocus,
    required this.onOpen,
    required this.onRemove,
  });

  final Bookmark bookmark;
  final bool autofocus;
  final VoidCallback onOpen;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return TvButton(
      autofocus: autofocus,
      onPressed: onOpen,
      onMenu: onRemove,
      child: Row(
        children: [
          Favicon(url: bookmark.url, size: 28),
          const SizedBox(width: 12),
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
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  Uri.tryParse(bookmark.url)?.host ?? bookmark.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: TvStyle.secondaryTextOf(context),
                    fontSize: 12,
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
