import 'dart:async';

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
  final _scrollController = ScrollController();
  bool _isSearching = false;
  Timer? _debounceTimer;

  // Pagination state
  final List<BlogPost> _appendedPosts = [];
  bool _isLoadingMore = false;
  bool _hasMore = true;
  String? _paginationError;
  static const int _pageSize = 10;

  @override
  void initState() {
    super.initState();
    _searchController.text = ref.read(blogSearchQueryProvider);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore &&
        _hasMore) {
      _loadMorePosts();
    }
  }

  Future<void> _loadMorePosts() async {
    if (_isLoadingMore || !_hasMore) return;

    final initialPosts = ref.read(blogFeedProvider).valueOrNull ?? [];
    final currentCount = initialPosts.length + _appendedPosts.length;
    if (currentCount == 0) return;

    setState(() {
      _isLoadingMore = true;
      _paginationError = null;
    });

    try {
      final category = ref.read(selectedBlogCategoryProvider);
      final type = ref.read(selectedBlogTypeProvider);
      final tag = ref.read(selectedBlogTagProvider);
      final dateFilter = ref.read(selectedBlogDateFilterProvider);
      final sortBy = ref.read(selectedBlogSortProvider);
      final query = ref.read(blogSearchQueryProvider);

      DateTime? dateFrom;
      if (dateFilter == 'today') {
        dateFrom = DateTime.now().subtract(const Duration(days: 1));
      } else if (dateFilter == 'week') {
        dateFrom = DateTime.now().subtract(const Duration(days: 7));
      } else if (dateFilter == 'month') {
        dateFrom = DateTime.now().subtract(const Duration(days: 30));
      } else if (dateFilter == 'year') {
        dateFrom = DateTime.now().subtract(const Duration(days: 365));
      }

      final more = await ref.read(blogRepositoryProvider).getPublishedPosts(
            category: category == 'all' ? null : category,
            postType: type == 'all' ? null : type,
            tag: tag,
            dateFrom: dateFrom,
            sortBy: sortBy,
            searchQuery: query.isEmpty ? null : query,
            offset: currentCount,
            limit: _pageSize,
          );

      if (mounted) {
        setState(() {
          if (more.isEmpty || more.length < _pageSize) {
            _hasMore = false;
          }
          _appendedPosts.addAll(more);
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
          _paginationError = 'Failed to load more posts';
        });
      }
    }
  }

  void _onSearchChanged(String val) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 350), () {
      if (mounted) {
        ref.read(blogSearchQueryProvider.notifier).state = val;
        _resetPagination();
      }
    });
  }

  void _resetPagination() {
    setState(() {
      _appendedPosts.clear();
      _hasMore = true;
      _isLoadingMore = false;
      _paginationError = null;
    });
  }

  void _clearAllFilters() {
    _searchController.clear();
    ref.read(blogSearchQueryProvider.notifier).state = '';
    ref.read(selectedBlogCategoryProvider.notifier).state = 'all';
    ref.read(selectedBlogTypeProvider.notifier).state = 'all';
    ref.read(selectedBlogTagProvider.notifier).state = null;
    ref.read(selectedBlogDateFilterProvider.notifier).state = 'all';
    ref.read(selectedBlogSortProvider.notifier).state = 'latest';
    _resetPagination();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final postsAsync = ref.watch(blogFeedProvider);
    final canCreatePost = ref.can('blog.create');
    final selectedCategory = ref.watch(selectedBlogCategoryProvider);
    final selectedType = ref.watch(selectedBlogTypeProvider);
    final selectedTag = ref.watch(selectedBlogTagProvider);
    final selectedDate = ref.watch(selectedBlogDateFilterProvider);
    final selectedSort = ref.watch(selectedBlogSortProvider);
    final searchQuery = ref.watch(blogSearchQueryProvider);

    final hasActiveFilters = selectedCategory != 'all' ||
        selectedType != 'all' ||
        selectedTag != null ||
        selectedDate != 'all' ||
        selectedSort != 'latest' ||
        searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search by title, content, author, tag...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.clear_rounded),
                    onPressed: () {
                      _searchController.clear();
                      ref.read(blogSearchQueryProvider.notifier).state = '';
                      _resetPagination();
                    },
                  ),
                ),
                onChanged: _onSearchChanged,
              )
            : const Text('Blog & Updates'),
        actions: [
          IconButton(
            icon: Icon(
              _isSearching ? Icons.close_rounded : Icons.search_rounded,
            ),
            tooltip: _isSearching ? 'Close Search' : 'Search',
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _searchController.clear();
                  ref.read(blogSearchQueryProvider.notifier).state = '';
                  _resetPagination();
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
          // Row 1: Categories Carousel
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(40),
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

          // Row 2: Secondary Filters & Sort Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerLowest,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outlineVariant.withAlpha(40),
                ),
              ),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Type Filters
                  _buildTypeChip('all', 'All Formats'),
                  const SizedBox(width: 6),
                  _buildTypeChip('text', 'Articles'),
                  const SizedBox(width: 6),
                  _buildTypeChip('image', 'Galleries'),
                  const SizedBox(width: 6),
                  _buildTypeChip('audio', 'Podcasts'),
                  const SizedBox(width: 12),

                  // Sort Dropdown
                  PopupMenuButton<String>(
                    tooltip: 'Sort Posts',
                    initialValue: selectedSort,
                    onSelected: (val) {
                      ref.read(selectedBlogSortProvider.notifier).state = val;
                      _resetPagination();
                    },
                    child: Chip(
                      avatar: const Icon(Icons.sort_rounded, size: 16),
                      label: Text(
                        selectedSort == 'likes'
                            ? 'Most Liked'
                            : (selectedSort == 'comments'
                                ? 'Most Commented'
                                : 'Latest'),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(
                        value: 'latest',
                        child: Text('Latest Published'),
                      ),
                      PopupMenuItem(
                        value: 'likes',
                        child: Text('Most Liked'),
                      ),
                      PopupMenuItem(
                        value: 'comments',
                        child: Text('Most Commented'),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),

                  // Date Filter Dropdown
                  PopupMenuButton<String>(
                    tooltip: 'Filter by Date',
                    initialValue: selectedDate,
                    onSelected: (val) {
                      ref.read(selectedBlogDateFilterProvider.notifier).state =
                          val;
                      _resetPagination();
                    },
                    child: Chip(
                      avatar: const Icon(Icons.calendar_today_rounded, size: 14),
                      label: Text(
                        selectedDate == 'today'
                            ? 'Past 24h'
                            : (selectedDate == 'week'
                                ? 'Past Week'
                                : (selectedDate == 'month'
                                    ? 'Past Month'
                                    : (selectedDate == 'year'
                                        ? 'Past Year'
                                        : 'Any Time'))),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'all', child: Text('Any Time')),
                      PopupMenuItem(value: 'today', child: Text('Past 24 Hours')),
                      PopupMenuItem(value: 'week', child: Text('Past 7 Days')),
                      PopupMenuItem(value: 'month', child: Text('Past 30 Days')),
                      PopupMenuItem(value: 'year', child: Text('Past Year')),
                    ],
                  ),

                  // Active Tag Indicator
                  if (selectedTag != null) ...[
                    const SizedBox(width: 6),
                    InputChip(
                      label: Text('#$selectedTag'),
                      onDeleted: () {
                        ref.read(selectedBlogTagProvider.notifier).state = null;
                        _resetPagination();
                      },
                    ),
                  ],

                  // Clear All Action
                  if (hasActiveFilters) ...[
                    const SizedBox(width: 8),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                      ),
                      icon: const Icon(Icons.clear_all, size: 16),
                      label: const Text('Reset', style: TextStyle(fontSize: 12)),
                      onPressed: _clearAllFilters,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Main Feed
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                _resetPagination();
                ref.invalidate(blogFeedProvider);
              },
              child: postsAsync.when(
                loading: () =>
                    const LoadingIndicator(message: 'Loading posts...'),
                error: (err, stack) => ErrorView(
                  message: 'Unable to load blog feed',
                  onRetry: () {
                    _resetPagination();
                    ref.invalidate(blogFeedProvider);
                  },
                ),
                data: (initialPosts) {
                  final allPosts = [...initialPosts, ..._appendedPosts];

                  if (allPosts.isEmpty) {
                    // Distinct empty state vs no-results state (Requirement 1)
                    if (hasActiveFilters) {
                      return EmptyState(
                        icon: Icons.search_off_rounded,
                        title: 'No Matching Posts',
                        subtitle:
                            'No articles match your current filters or search terms.',
                        action: TextButton.icon(
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Reset Filters'),
                          onPressed: _clearAllFilters,
                        ),
                      );
                    } else {
                      return EmptyState(
                        icon: Icons.article_outlined,
                        title: 'No Posts Yet',
                        subtitle:
                            'Check back later for news, updates, and articles.',
                        action: canCreatePost
                            ? ElevatedButton.icon(
                                onPressed: () => context.push('/blog/create'),
                                icon: const Icon(Icons.add),
                                label: const Text('Create First Post'),
                              )
                            : null,
                      );
                    }
                  }

                  return ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16.0),
                    itemCount: allPosts.length +
                        (_isLoadingMore || _paginationError != null ? 1 : 0),
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      if (index == allPosts.length) {
                        if (_paginationError != null) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _paginationError!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  TextButton(
                                    onPressed: _loadMorePosts,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }
                        return const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      }

                      final post = allPosts[index];
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
        _resetPagination();
      },
    );
  }

  Widget _buildTypeChip(String key, String label) {
    final theme = Theme.of(context);
    final selectedType = ref.watch(selectedBlogTypeProvider);
    final isSelected = selectedType == key;

    return ChoiceChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      selected: isSelected,
      onSelected: (selected) {
        ref.read(selectedBlogTypeProvider.notifier).state =
            selected ? key : 'all';
        _resetPagination();
      },
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      selectedColor: theme.colorScheme.secondaryContainer,
    );
  }
}
