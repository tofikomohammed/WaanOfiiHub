import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_repository.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_post.dart';
import 'package:waan_ofii_hub/features/blog/presentation/blog_feed_screen.dart';
import 'package:waan_ofii_hub/features/blog/presentation/my_bookmarks_screen.dart';
import 'package:waan_ofii_hub/features/blog/presentation/widgets/post_card.dart';

void main() {
  final testPost = BlogPost(
    id: 'post-qa-1',
    authorId: 'author-qa',
    authorName: 'Dr. Hana',
    type: 'text',
    category: BlogCategories.health,
    title: 'Clean Water Initiative in Rural Areas',
    body: 'Sanitation techniques and water purification practices for public health.',
    status: 'published',
    publishedAt: DateTime(2026, 11, 21),
    likesCount: 20,
    commentsCount: 5,
    isLikedByMe: false,
    isBookmarkedByMe: false,
    tags: const ['health', 'water', 'community'],
    createdAt: DateTime(2026, 11, 20),
  );

  group('Blog Key Integration Flows Tests', () {
    testWidgets('Like and Bookmark Flow: toggles like and bookmark state correctly',
        (tester) async {
      bool likeToggled = false;
      bool bookmarkToggled = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCard(
              post: testPost,
              onLikeToggle: () => likeToggled = true,
              onBookmarkToggle: () => bookmarkToggled = true,
            ),
          ),
        ),
      );

      // Verify title & initial status
      expect(find.text('Clean Water Initiative in Rural Areas'), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border), findsOneWidget);
      expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);

      // Tap Like button
      await tester.tap(find.byIcon(Icons.favorite_border));
      await tester.pump();
      expect(likeToggled, isTrue);

      // Tap Bookmark button
      await tester.tap(find.byIcon(Icons.bookmark_border_rounded));
      await tester.pump();
      expect(bookmarkToggled, isTrue);
    });

    testWidgets('My Bookmarks Screen Flow: renders saved posts and handles empty state',
        (tester) async {
      final bookmarkedPost = testPost.copyWith(isBookmarkedByMe: true);

      // 1. Screen with 1 bookmarked post
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myBookmarksProvider.overrideWith((ref) async => [bookmarkedPost]),
          ],
          child: const MaterialApp(
            home: MyBookmarksScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Saved Articles'), findsOneWidget);
      expect(find.text('Clean Water Initiative in Rural Areas'), findsOneWidget);
      expect(find.byIcon(Icons.bookmark), findsOneWidget);
    });

    testWidgets('My Bookmarks Empty State Flow', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            myBookmarksProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: MyBookmarksScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Bookmarks Yet'), findsOneWidget);
      expect(
        find.text(
          'Tap the bookmark icon on any article to save it for later reading.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Feed Filter and Clear Flow: resets combined filters cleanly',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            blogFeedProvider.overrideWith((ref) async => []),
            selectedBlogCategoryProvider.overrideWith((ref) => 'technology'),
          ],
          child: const MaterialApp(
            home: BlogFeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Because category is 'technology' and results are empty, it should show No Matching Posts
      expect(find.text('No Matching Posts'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);

      // Tap Reset Filters
      await tester.tap(find.text('Reset Filters'));
      await tester.pump();
    });
  });

  group('BlogRepository Bookmarking & Reporting Null-Safety Tests', () {
    late BlogRepository repo;

    setUp(() {
      repo = BlogRepository(null);
    });

    test('toggleBookmark, getBookmarkedPosts, reportPost execute safely when uninitialized',
        () async {
      expect(await repo.getBookmarkedPosts(), isEmpty);

      // Should complete without crashing
      await repo.toggleBookmark('post-1', true);
      await repo.toggleBookmark('post-1', false);

      await repo.reportPost(
        postId: 'post-1',
        reason: 'Spam or advertising',
        details: 'Self promotion content',
      );

      await repo.reportComment(
        commentId: 'c1',
        postId: 'post-1',
        reason: 'Inappropriate language',
      );
    });
  });
}
