import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../rbac/data/rbac_repository.dart';
import '../data/blog_repository.dart';
import 'widgets/post_card.dart';

class BlogFeedScreen extends ConsumerWidget {
  const BlogFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final postsAsync = ref.watch(blogFeedProvider);
    final canCreatePost = ref.can('blog.create');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Blog & Updates'),
        actions: [
          if (canCreatePost)
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'New Post',
              onPressed: () => context.push('/blog/create'),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(blogFeedProvider),
        child: postsAsync.when(
          loading: () => const LoadingIndicator(message: 'Loading posts...'),
          error: (err, stack) => ErrorView(
            message: 'Unable to load blog feed',
            onRetry: () => ref.invalidate(blogFeedProvider),
          ),
          data: (posts) {
            if (posts.isEmpty) {
              return EmptyState(
                icon: Icons.article_outlined,
                title: 'No Posts Yet',
                subtitle: 'Check back later for news, updates, and articles.',
                action: canCreatePost
                    ? ElevatedButton.icon(
                        onPressed: () => context.push('/blog/create'),
                        icon: const Icon(Icons.add),
                        label: const Text('Create First Post'),
                      )
                    : null,
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
