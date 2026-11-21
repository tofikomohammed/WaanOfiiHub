import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../data/blog_repository.dart';
import '../models/blog_post.dart';
import 'widgets/post_card.dart';

class TopicParams {
  final String? category;
  final String? tag;

  const TopicParams({this.category, this.tag});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TopicParams && category == other.category && tag == other.tag;

  @override
  int get hashCode => Object.hash(category, tag);
}

final categoryTagPostsProvider =
    FutureProvider.family<List<BlogPost>, TopicParams>(
  (ref, params) async {
    final repo = ref.watch(blogRepositoryProvider);
    return repo.getPublishedPosts(
      category: params.category,
      tag: params.tag,
      limit: 50,
    );
  },
);

class CategoryTagPostsScreen extends ConsumerWidget {
  final String? category;
  final String? tag;

  const CategoryTagPostsScreen({
    super.key,
    this.category,
    this.tag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isCategory = category != null && category!.isNotEmpty;
    final isTag = tag != null && tag!.isNotEmpty;

    final title = isCategory
        ? BlogCategories.getDisplayName(category!)
        : (isTag ? '#$tag' : 'Topic Posts');

    final params = TopicParams(category: category, tag: tag);
    final postsAsync = ref.watch(categoryTagPostsProvider(params));

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Column(
        children: [
          // Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: isCategory
                  ? theme.colorScheme.primaryContainer.withAlpha(50)
                  : theme.colorScheme.secondaryContainer.withAlpha(50),
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(40),
                ),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      isCategory
                          ? Icons.category_outlined
                          : Icons.tag_rounded,
                      color: theme.colorScheme.primary,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  isCategory
                      ? 'Articles, updates and publications in $title'
                      : 'All posts tagged with #$tag',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),

          // Posts Feed
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(categoryTagPostsProvider(params)),
              child: postsAsync.when(
                loading: () =>
                    const LoadingIndicator(message: 'Loading posts...'),
                error: (err, stack) => ErrorView(
                  message: 'Unable to load posts for this topic',
                  onRetry: () =>
                      ref.invalidate(categoryTagPostsProvider(params)),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    return EmptyState(
                      icon: Icons.article_outlined,
                      title: 'No Posts Found',
                      subtitle: isCategory
                          ? 'No articles published in $title yet.'
                          : 'No articles currently carry the tag #$tag.',
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.all(16.0),
                    itemCount: posts.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return PostCard(
                        post: post,
                        onLikeToggle: () async {
                          await ref
                              .read(blogRepositoryProvider)
                              .toggleLike(post.id, post.isLikedByMe);
                          ref.invalidate(categoryTagPostsProvider(params));
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
