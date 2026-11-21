import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_view.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../rbac/data/rbac_repository.dart';
import '../data/blog_repository.dart';
import '../models/blog_post.dart';
import 'widgets/post_card.dart';

class BlogFeedScreen extends ConsumerStatefulWidget {
  const BlogFeedScreen({super.key});

  @override
  ConsumerState<BlogFeedScreen> createState() => _BlogFeedScreenState();
}

class _BlogFeedScreenState extends ConsumerState<BlogFeedScreen> {
  final _searchController = TextEditingController();
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(blogSearchQueryProvider);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postsAsync = ref.watch(blogFeedProvider);
    final canCreatePost = ref.can('blog.create');
    final selectedCategory = ref.watch(selectedBlogCategoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search articles and updates...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(blogSearchQueryProvider.notifier).state = '';
                    },
                  ),
                ),
                onChanged: (val) {
                  ref.read(blogSearchQueryProvider.notifier).state = val;
                },
              )
            : const Text('Blog & Updates'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close_rounded : Icons.search_rounded),
            tooltip: _isSearching ? 'Close Search' : 'Search',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  ref.read(blogSearchQueryProvider.notifier).state = '';
                  _isSearching = false;
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
          if (canCreatePost) ...[
            IconButton(
              icon: const Icon(Icons.drafts_outlined),
              tooltip: 'My Drafts',
              onPressed: () => context.push('/blog/drafts'),
            ),
            IconButton(
              icon: const Icon(Icons.add_circle_outline_rounded),
              tooltip: 'New Post',
              onPressed: () => context.push('/blog/create'),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          // Category Filter Chips Carousel
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(50),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                children: [
                  _buildCategoryChip(context, 'all', 'All Topics'),
                  const SizedBox(width: 8),
                  ...BlogCategories.all.map((cat) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildCategoryChip(
                        context,
                        cat,
                        BlogCategories.getDisplayName(cat),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),

          // Main Feed
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(blogFeedProvider),
              child: postsAsync.when(
                loading: () => const LoadingIndicator(message: 'Loading posts...'),
                error: (err, stack) => ErrorView(
                  message: 'Unable to load blog feed',
                  onRetry: () => ref.invalidate(blogFeedProvider),
                ),
                data: (posts) {
                  if (posts.isEmpty) {
                    final isFiltered = selectedCategory != 'all' ||
                        _searchController.text.isNotEmpty;
                    return EmptyState(
                      icon: isFiltered
                          ? Icons.filter_alt_off_rounded
                          : Icons.article_outlined,
                      title: isFiltered ? 'No Matches Found' : 'No Posts Yet',
                      subtitle: isFiltered
                          ? 'Try clearing your search query or selecting another category.'
                          : 'Check back later for news, updates, and articles.',
                      action: isFiltered
                          ? TextButton.icon(
                              icon: const Icon(Icons.refresh_rounded),
                              label: const Text('Reset Filters'),
                              onPressed: () {
                                _searchController.clear();
                                ref.read(blogSearchQueryProvider.notifier).state =
                                    '';
                                ref
                                    .read(selectedBlogCategoryProvider.notifier)
                                    .state = 'all';
                              },
                            )
                          : (canCreatePost
                              ? ElevatedButton.icon(
                                  onPressed: () => context.push('/blog/create'),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Create First Post'),
                                )
                              : null),
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
                          ref.invalidate(blogFeedProvider);
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

  Widget _buildCategoryChip(BuildContext context, String key, String label) {
    final theme = Theme.of(context);
    final selectedCategory = ref.watch(selectedBlogCategoryProvider);
    final isSelected = selectedCategory == key;

    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        color: isSelected
            ? theme.colorScheme.onPrimary
            : theme.colorScheme.onSurfaceVariant,
      ),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.primary,
      checkmarkColor: theme.colorScheme.onPrimary,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant.withAlpha(60),
        ),
      ),
      onSelected: (selected) {
        ref.read(selectedBlogCategoryProvider.notifier).state =
            selected ? key : 'all';
      },
    );
  }
}
