import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/blog_repository.dart';
import 'widgets/post_card.dart';

class MyBookmarksScreen extends ConsumerWidget {
  const MyBookmarksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarksAsync = ref.watch(myBookmarksProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Articles'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(myBookmarksProvider),
        child: bookmarksAsync.when(
          loading: () =>
              const LoadingIndicator(message: 'Loading your bookmarks...'),
          error: (err, stack) => ErrorView(
            message: 'Unable to load saved bookmarks',
            onRetry: () => ref.invalidate(myBookmarksProvider),
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return const EmptyState(
                icon: Icons.bookmark_border_rounded,
                title: 'No Bookmarks Yet',
                subtitle:
                    'Tap the bookmark icon on any article to save it for later reading.',
              );
            }

            return ListView.separated(
              padding: const EdgeInsets.all(16.0),
              itemCount: posts.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final post = posts[index];
                return PostCard(
                  post: post,
                  onLikeToggle: () async {
                    await ref
                        .read(blogRepositoryProvider)
                        .toggleLike(post.id, post.isLikedByMe);
                    ref.invalidate(myBookmarksProvider);
                    ref.invalidate(blogFeedProvider);
                  },
                  onBookmarkToggle: () async {
                    await ref
                        .read(blogRepositoryProvider)
                        .toggleBookmark(post.id, post.isBookmarkedByMe);
                    ref.invalidate(myBookmarksProvider);
                    ref.invalidate(blogFeedProvider);
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
