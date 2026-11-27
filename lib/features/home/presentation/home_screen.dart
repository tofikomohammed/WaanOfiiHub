import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../blog/data/blog_repository.dart';
import '../../blog/models/blog_post.dart';
import '../../chat/data/chat_repository.dart';
import '../../profile/data/profile_repository.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _selectedCategory = 'All';
  final TextEditingController _quickChatController = TextEditingController();

  final List<String> _categories = [
    'All',
    'Health',
    'Technology',
    'Business',
    'Community',
  ];

  @override
  void dispose() {
    _quickChatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final blogPosts = ref.watch(blogFeedProvider).valueOrNull ?? [];
    final bookmarkedPosts = ref.watch(myBookmarksProvider).valueOrNull ?? [];

    // Featured post (first post or default fallback)
    final featuredPost = blogPosts.isNotEmpty
        ? blogPosts.first
        : BlogPost(
            id: 'featured-1',
            authorId: 'auth-1',
            authorName: 'Dr. Bilal Ahmed',
            type: 'text',
            category: 'agriculture',
            title: 'Modern Drip Irrigation Systems for Smallholder Farmers',
            body: 'Conserving water through high-efficiency gravity-fed micro irrigation.',
            status: 'published',
            likesCount: 48,
            commentsCount: 12,
            createdAt: DateTime(2026, 11, 27),
          );

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.darkBackground
          : AppColors.lightBackground,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isLargeScreen = constraints.maxWidth >= 1050;

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(blogFeedProvider);
              ref.invalidate(myBookmarksProvider);
              ref.invalidate(currentProfileProvider);
              ref.invalidate(conversationsListProvider);
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: isLargeScreen
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left & Middle Content (Hero, Stats, Community)
                        Expanded(
                          flex: 7,
                          child: _buildMainFeedSection(
                            context,
                            featuredPost,
                            blogPosts,
                            bookmarkedPosts.length,
                          ),
                        ),
                        const SizedBox(width: 20),

                        // Right Column: Messages & Stories Quick Chat Panel
                        SizedBox(
                          width: 360,
                          child: _buildRightMessagesPanel(context),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildMainFeedSection(
                          context,
                          featuredPost,
                          blogPosts,
                          bookmarkedPosts.length,
                        ),
                        const SizedBox(height: 24),
                        _buildRightMessagesPanel(context),
                      ],
                    ),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MAIN FEED SECTION (Hero Banner, Stats Cards, Community Cards)
  // ---------------------------------------------------------------------------
  Widget _buildMainFeedSection(
    BuildContext context,
    BlogPost featuredPost,
    List<BlogPost> allPosts,
    int savedCount,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Top Hero Featured Banner (Forest Green with decorative circular accents)
        _buildHeroBanner(context, featuredPost),
        const SizedBox(height: 20),

        // 2. Stats Row (3 Cards: Saved Posts, Posts Liked, Unread Replies)
        _buildStatsCardsRow(
          context,
          savedCount: savedCount > 0 ? savedCount : 12,
        ),
        const SizedBox(height: 24),

        // 3. "Latest from the community" Section Header & Filter Pills
        _buildCommunityHeader(context),
        const SizedBox(height: 16),

        // 4. Community Cards (Article, Audio, Gallery)
        _buildCommunityCardsRow(context, allPosts),
      ],
    );
  }

  // Hero Featured Banner (Matches design.html)
  Widget _buildHeroBanner(BuildContext context, BlogPost post) {
    return Container(
      height: 210,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0B3B32), // Deep Emerald
            Color(0xFF0F5445), // Forest Accent
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0B3B32).withOpacity(0.18),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Decorative circular glow shapes (matching design.html)
          Positioned(
            right: -30,
            top: -20,
            child: Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF137562).withOpacity(0.35),
              ),
            ),
          ),
          Positioned(
            right: 50,
            bottom: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF082822).withOpacity(0.4),
              ),
            ),
          ),

          // Content
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 26.0,
              vertical: 22.0,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Reading Time Tag
                Text(
                  '${post.readingTimeMinutes > 0 ? post.readingTimeMinutes : 6} min read',
                  style: const TextStyle(
                    color: Color(0xFFA3C6B9),
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),

                // Featured Post Title
                Text(
                  post.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 18),

                // Action Buttons: "Read article" & "Save"
                Row(
                  children: [
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentAmber,
                        foregroundColor: const Color(0xFF1E1E1E),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        elevation: 0,
                      ),
                      onPressed: () => context.push('/blog/${post.id}'),
                      child: const Text(
                        'Read article',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(
                          color: Colors.white.withOpacity(0.35),
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 12,
                        ),
                      ),
                      icon: const Icon(Icons.bookmark_border_rounded, size: 16),
                      label: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      onPressed: () async {
                        await ref
                            .read(blogRepositoryProvider)
                            .toggleBookmark(post.id, post.isBookmarkedByMe);
                        ref.invalidate(myBookmarksProvider);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Article saved to your bookmarks!'),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 3 Stats Cards (Matches design.html)
  Widget _buildStatsCardsRow(BuildContext context, {required int savedCount}) {
    return Row(
      children: [
        // 1. Saved posts
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.bookmark_border_rounded,
            iconBg: AppColors.mintContainer,
            iconColor: AppColors.primary,
            count: '$savedCount',
            label: 'Saved posts',
            onTap: () => context.push('/blog/bookmarks'),
          ),
        ),
        const SizedBox(width: 12),

        // 2. Posts you liked
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.favorite_border_rounded,
            iconBg: AppColors.accentAmberContainer,
            iconColor: const Color(0xFFD6981C),
            count: '48',
            label: 'Posts you liked',
            onTap: () => context.go(RouteNames.blog),
          ),
        ),
        const SizedBox(width: 12),

        // 3. Unread replies
        Expanded(
          child: _buildStatCard(
            context,
            icon: Icons.chat_bubble_outline_rounded,
            iconBg: AppColors.coralContainer,
            iconColor: const Color(0xFFE05345),
            count: '5',
            label: 'Unread replies',
            onTap: () => context.go(RouteNames.chat),
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    BuildContext context, {
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String count,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    count,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF0F2620),
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B8A7E),
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Community Section Header & Category Filter Pills
  Widget _buildCommunityHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Latest from the community',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            color: Color(0xFF0F2620),
          ),
        ),
        const SizedBox(height: 12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _categories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(
                    cat,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF0F2620),
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: const Color(0xFF0B3B32),
                  backgroundColor: Colors.white,
                  showCheckmark: false,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFF0B3B32)
                          : Colors.transparent,
                    ),
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _selectedCategory = cat);
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // Community Content Cards (Article, Audio, Gallery)
  Widget _buildCommunityCardsRow(BuildContext context, List<BlogPost> posts) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = constraints.maxWidth >= 600
            ? (constraints.maxWidth - 24) / 3
            : 260.0;

        return SingleChildScrollView(
          scrollDirection: constraints.maxWidth >= 600
              ? Axis.vertical
              : Axis.horizontal,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Card 1: Article
              SizedBox(
                width: cardWidth,
                child: _buildCommunityCard(
                  context,
                  badge: 'Article',
                  badgeColor: Colors.white,
                  badgeTextColor: AppColors.primary,
                  boxColor: AppColors.mintContainer,
                  centerWidget: const Icon(
                    Icons.menu_book_rounded,
                    size: 38,
                    color: AppColors.primary,
                  ),
                  title: 'Seven signs your goats need a vet this week',
                  author: 'Dr. Bilal Ahmed',
                  onTap: () => context.go(RouteNames.blog),
                ),
              ),
              const SizedBox(width: 12),

              // Card 2: Audio
              SizedBox(
                width: cardWidth,
                child: _buildCommunityCard(
                  context,
                  badge: 'Audio',
                  badgeColor: Colors.white,
                  badgeTextColor: const Color(0xFFB88014),
                  boxColor: AppColors.accentAmberContainer,
                  centerWidget: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Row(
                        children: List.generate(
                          10,
                          (i) => Container(
                            width: 3,
                            height: (i % 3 + 1) * 9.0 + 8,
                            margin: const EdgeInsets.symmetric(horizontal: 1.5),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  title: 'Starting a small shop: a 12 minute conversation',
                  author: 'Hana Tadesse',
                  onTap: () => context.go(RouteNames.blog),
                ),
              ),
              const SizedBox(width: 12),

              // Card 3: Gallery
              SizedBox(
                width: cardWidth,
                child: _buildCommunityCard(
                  context,
                  badge: 'Gallery',
                  badgeColor: Colors.white,
                  badgeTextColor: AppColors.primary,
                  boxColor: const Color(0xFFE3EFEA),
                  centerWidget: const Icon(
                    Icons.collections_outlined,
                    size: 38,
                    color: AppColors.primary,
                  ),
                  title: 'Clean water project: before and after in Dire Dawa',
                  author: 'Community Team',
                  onTap: () => context.go(RouteNames.blog),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommunityCard(
    BuildContext context, {
    required String badge,
    required Color badgeColor,
    required Color badgeTextColor,
    required Color boxColor,
    required Widget centerWidget,
    required String title,
    required String author,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Preview Container
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: boxColor,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(10),
              child: Stack(
                children: [
                  // Badge (Article / Audio / Gallery)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.bold,
                        color: badgeTextColor,
                      ),
                    ),
                  ),
                  // Center Icon or Waveform
                  Center(child: centerWidget),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Card Title
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14.5,
                color: Color(0xFF0F2620),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),

            // Author
            Text(
              author,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B8A7E),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // RIGHT MESSAGES & STORIES QUICK CHAT PANEL (Matches design.html)
  // ---------------------------------------------------------------------------
  Widget _buildRightMessagesPanel(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: "Messages" & Search Icon
          Row(
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF0F2620),
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => context.go(RouteNames.chat),
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: const BoxDecoration(
                    color: AppColors.lightBackground,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.search,
                    size: 18,
                    color: Color(0xFF0F2620),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 2. Horizontal Story / Online Contacts
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildContactStory(
                  initials: 'AH',
                  name: 'Amina',
                  bgColor: const Color(0xFFC5E0D5),
                  isOnline: true,
                ),
                const SizedBox(width: 14),
                _buildContactStory(
                  initials: 'BA',
                  name: 'Bilal',
                  bgColor: const Color(0xFFFCE2A6),
                  isOnline: true,
                ),
                const SizedBox(width: 14),
                _buildContactStory(
                  initials: 'HT',
                  name: 'Hana',
                  bgColor: const Color(0xFFFAD5D0),
                  isOnline: false,
                ),
                const SizedBox(width: 14),
                _buildContactStory(
                  initials: 'YM',
                  name: 'Yusuf',
                  bgColor: const Color(0xFFDFDBF5),
                  isOnline: true,
                ),
                const SizedBox(width: 14),
                _buildContactStory(
                  initials: 'SK',
                  name: 'Sara',
                  bgColor: const Color(0xFFC5E5E2),
                  isOnline: false,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // 3. Active Chat Header (Amina Hassen - Online now)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.mintContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Color(0xFFB4D8CA),
                  child: Text(
                    'AH',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0B3B32),
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Amina Hassen',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: Color(0xFF0B3B32),
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'Online now',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF0B7D64),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 4. Chat Messages Thread Preview
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: const Color(0xFFE2EBE6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                'Today',
                style: TextStyle(fontSize: 10.5, color: Color(0xFF6B8A7E)),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Inbound Message (White bubble)
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F8F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2EBE6)),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Did you read my irrigation article yet?',
                    style: TextStyle(fontSize: 13, color: Color(0xFF0F2620)),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '2:41 PM',
                    style: TextStyle(fontSize: 9.5, color: Color(0xFF8BA097)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Outbound Message (Deep Forest Green bubble)
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 240),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Yes, the cost table is very useful. Sharing it with the farmers\' group.',
                    style: TextStyle(fontSize: 13, color: Colors.white),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '2:43 PM',
                    style: TextStyle(fontSize: 9.5, color: Color(0xFFA3C6B9)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 5. Bottom Message Input Bar
          Row(
            children: [
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(
                  Icons.attach_file_rounded,
                  color: Color(0xFF6B8A7E),
                  size: 20,
                ),
                onPressed: () {},
              ),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F7F5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFDEE7E3)),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: TextField(
                    controller: _quickChatController,
                    decoration: const InputDecoration(
                      hintText: 'Write a message...',
                      hintStyle: TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFF8BA097),
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.only(bottom: 10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.accentAmber,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.send_rounded,
                    color: Colors.black,
                    size: 18,
                  ),
                  onPressed: () {
                    _quickChatController.clear();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Message sent! Opening chat...'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                    context.go(RouteNames.chat);
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactStory({
    required String initials,
    required String name,
    required Color bgColor,
    required bool isOnline,
  }) {
    return InkWell(
      onTap: () => context.go(RouteNames.chat),
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: bgColor,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F2620),
                  ),
                ),
              ),
              if (isOnline)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B8A7E),
            ),
          ),
        ],
      ),
    );
  }
}
