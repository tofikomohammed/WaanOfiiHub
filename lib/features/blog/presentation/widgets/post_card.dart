import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/blog_post.dart';
import '../../models/post_media.dart';
import 'audio_player_widget.dart';

class PostCard extends StatefulWidget {
  final BlogPost post;
  final VoidCallback? onLikeToggle;
  final VoidCallback? onBookmarkToggle;

  const PostCard({
    super.key,
    required this.post,
    this.onLikeToggle,
    this.onBookmarkToggle,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool _isExpanded = false;

  String _formatRelativeTime(DateTime? dateTime) {
    if (dateTime == null) return 'Draft';
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return DateFormat.MMMd().format(dateTime);
    }
  }

  void _openLightbox(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            iconTheme: const IconThemeData(color: Colors.white),
            title: Text(
              '${initialIndex + 1} / ${imageUrls.length}',
              style: const TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
          body: PageView.builder(
            controller: PageController(initialPage: initialIndex),
            itemCount: imageUrls.length,
            itemBuilder: (ctx, idx) {
              return Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[idx],
                    memCacheWidth: 1200,
                    fit: BoxFit.contain,
                    placeholder: (_, _) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, _, _) => const Icon(
                      Icons.broken_image,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _copyPostLink(BuildContext context) {
    final shareText =
        '${widget.post.title}\n\nRead more on WAAN-OFIIHUB:\nhttps://waanofii.hub/blog/${widget.post.id}';
    Clipboard.setData(ClipboardData(text: shareText));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Post link copied to clipboard!'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final post = widget.post;

    final dateStr = post.isScheduled && post.scheduledFor != null
        ? 'Scheduled for ${DateFormat.MMMd().add_jm().format(post.scheduledFor!.toLocal())}'
        : _formatRelativeTime(post.publishedAt);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withAlpha(70),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              theme.brightness == Brightness.dark ? 0.2 : 0.04,
            ),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Facebook-Style Post Header
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Author Avatar
                GestureDetector(
                  onTap: () => context.push('/blog/${post.id}'),
                  child: CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primaryContainer,
                    child: Text(
                      post.authorName != null && post.authorName!.isNotEmpty
                          ? post.authorName![0].toUpperCase()
                          : 'A',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // Author Name & Metadata Column
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              'By ${post.authorName ?? "Admin"}',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 14.5,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (post.isPinned) ...[
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.push_pin,
                              size: 14,
                              color: Colors.amber,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            dateStr,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Text(
                            ' • ',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          Icon(
                            Icons.public,
                            size: 12,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 1.5,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.secondaryContainer
                                  .withAlpha(160),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              post.categoryDisplayName.toUpperCase(),
                              style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w700,
                                color: theme.colorScheme.onSecondaryContainer,
                              ),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '• ${post.readingTimeMinutes} min read',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: 11.5,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (post.isScheduled) ...[
                            const SizedBox(width: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withAlpha(30),
                                border: Border.all(
                                  color: Colors.purple.withAlpha(120),
                                ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text(
                                'SCHEDULED',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                // Bookmark Icon Button
                if (widget.onBookmarkToggle != null)
                  IconButton(
                    icon: Icon(
                      post.isBookmarkedByMe
                          ? Icons.bookmark
                          : Icons.bookmark_border_rounded,
                      size: 20,
                      color: post.isBookmarkedByMe
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                    tooltip: post.isBookmarkedByMe
                        ? 'Remove Bookmark'
                        : 'Save Post',
                    onPressed: widget.onBookmarkToggle,
                  ),

                // Facebook 3-Dot Options Menu
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz,
                    size: 22,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  tooltip: 'Options',
                  onSelected: (val) {
                    if (val == 'share') {
                      _copyPostLink(context);
                    } else if (val == 'view') {
                      context.push('/blog/${post.id}');
                    } else if (val == 'bookmark' &&
                        widget.onBookmarkToggle != null) {
                      widget.onBookmarkToggle!();
                    }
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(Icons.link, size: 18),
                          SizedBox(width: 8),
                          Text('Copy Link'),
                        ],
                      ),
                    ),
                    if (widget.onBookmarkToggle != null)
                      PopupMenuItem(
                        value: 'bookmark',
                        child: Row(
                          children: [
                            Icon(
                              post.isBookmarkedByMe
                                  ? Icons.bookmark
                                  : Icons.bookmark_border_rounded,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(post.isBookmarkedByMe ? 'Saved' : 'Save Post'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'view',
                      child: Row(
                        children: [
                          Icon(Icons.open_in_new, size: 18),
                          SizedBox(width: 8),
                          Text('Open Post'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Post Body & Title
          InkWell(
            onTap: () => context.push('/blog/${post.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 4.0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    post.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      height: 1.3,
                    ),
                  ),
                  if (post.body.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    if (!_isExpanded && post.body.length > 180) ...[
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${post.body.substring(0, 180)}... ',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                            WidgetSpan(
                              child: GestureDetector(
                                onTap: () => setState(() => _isExpanded = true),
                                child: Text(
                                  'See more',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      Text(
                        post.body,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          height: 1.4,
                        ),
                      ),
                    ],
                  ],
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: post.tags.map((tag) {
                        return Text(
                          '#$tag',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.primary,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 6),

          // 3. Facebook Media Display (Flush / Edge-to-Edge)
          if (post.imageMedia.isNotEmpty)
            _buildFacebookImageCollage(context, post.imageMedia)
          else if (post.coverUrl != null && post.coverUrl!.isNotEmpty)
            _buildSingleCoverImage(context, post.coverUrl!)
          else if (post.type == 'audio' && post.coverUrl != null)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 14.0,
                vertical: 6.0,
              ),
              child: AudioPlayerWidget(
                audioUrl: post.coverUrl!,
                title: post.title,
              ),
            ),

          // 4. Facebook Reactions & Engagement Metrics Row
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 8),
            child: Row(
              children: [
                // Overlapping Facebook Reaction Icons (Thumbs Up + Heart)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 20,
                      height: 20,
                      decoration: const BoxDecoration(
                        color: Color(0xFF1877F2), // Facebook Blue
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.thumb_up,
                        size: 11,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${post.likesCount}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                const Spacer(),

                // Comments & Views Count
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${post.commentsCount}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'comments  •  ${post.viewsCount} views',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12.5,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 5. Subtle Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14.0),
            child: Divider(
              height: 1,
              thickness: 0.6,
              color: theme.dividerColor.withAlpha(50),
            ),
          ),

          // 6. Facebook 3-Button Action Bar (Like, Comment, Share)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 2.0),
            child: Row(
              children: [
                // LIKE ACTION BUTTON
                Expanded(
                  child: InkWell(
                    onTap: widget.onLikeToggle,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            post.isLikedByMe
                                ? Icons.favorite
                                : Icons.favorite_border,
                            size: 19,
                            color: post.isLikedByMe
                                ? Colors.red
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Like',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: post.isLikedByMe
                                  ? Colors.red
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // COMMENT ACTION BUTTON
                Expanded(
                  child: InkWell(
                    onTap: () => context.push('/blog/${post.id}'),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Comment',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // SHARE ACTION BUTTON
                Expanded(
                  child: InkWell(
                    onTap: () => _copyPostLink(context),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.share_outlined,
                            size: 18,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Share',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Single Cover Image Builder
  Widget _buildSingleCoverImage(BuildContext context, String coverUrl) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _openLightbox(context, [coverUrl], 0),
      child: CachedNetworkImage(
        imageUrl: coverUrl,
        memCacheWidth: 1000,
        height: 240,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          height: 240,
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (context, url, error) => Container(
          height: 240,
          color: theme.colorScheme.surfaceContainerHighest,
          child: const Icon(Icons.broken_image, size: 48),
        ),
      ),
    );
  }

  // Facebook Photo Collage Grid Builder
  Widget _buildFacebookImageCollage(
    BuildContext context,
    List<PostMedia> mediaList,
  ) {
    final theme = Theme.of(context);
    final urls = mediaList
        .map((m) => m.publicUrl ?? '')
        .where((u) => u.isNotEmpty)
        .toList();
    if (urls.isEmpty) return const SizedBox.shrink();

    if (urls.length == 1) {
      return _buildSingleCoverImage(context, urls.first);
    }

    if (urls.length == 2) {
      return SizedBox(
        height: 220,
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () => _openLightbox(context, urls, 0),
                child: _buildGridItem(urls[0], theme),
              ),
            ),
            const SizedBox(width: 2),
            Expanded(
              child: GestureDetector(
                onTap: () => _openLightbox(context, urls, 1),
                child: _buildGridItem(urls[1], theme),
              ),
            ),
          ],
        ),
      );
    }

    if (urls.length == 3) {
      return SizedBox(
        height: 260,
        child: Column(
          children: [
            Expanded(
              flex: 3,
              child: GestureDetector(
                onTap: () => _openLightbox(context, urls, 0),
                child: _buildGridItem(urls[0], theme),
              ),
            ),
            const SizedBox(height: 2),
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openLightbox(context, urls, 1),
                      child: _buildGridItem(urls[1], theme),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => _openLightbox(context, urls, 2),
                      child: _buildGridItem(urls[2], theme),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    // 4 or more photos: Facebook 2x2 grid with overlay on the 4th
    return SizedBox(
      height: 280,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openLightbox(context, urls, 0),
                    child: _buildGridItem(urls[0], theme),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openLightbox(context, urls, 1),
                    child: _buildGridItem(urls[1], theme),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openLightbox(context, urls, 2),
                    child: _buildGridItem(urls[2], theme),
                  ),
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _openLightbox(context, urls, 3),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _buildGridItem(urls[3], theme),
                        if (urls.length > 4)
                          Container(
                            color: Colors.black.withOpacity(0.55),
                            child: Center(
                              child: Text(
                                '+${urls.length - 4}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGridItem(String url, ThemeData theme) {
    return CachedNetworkImage(
      imageUrl: url,
      memCacheWidth: 600,
      width: double.infinity,
      height: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      errorWidget: (_, _, _) => Container(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Icon(Icons.broken_image, size: 36),
      ),
    );
  }
}
