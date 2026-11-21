import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_repository.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_post.dart';
import 'package:waan_ofii_hub/features/blog/presentation/blog_feed_screen.dart';
import 'package:waan_ofii_hub/features/blog/presentation/widgets/post_card.dart';

void main() {
  final samplePost = BlogPost(
    id: 'test-101',
    authorId: 'auth-001',
    authorName: 'Professor Tariq',
    type: 'text',
    category: BlogCategories.agriculture,
    title: 'Modern Drip Irrigation Systems',
    body: 'How smallholder farmers can conserve water effectively.',
    status: 'published',
    publishedAt: DateTime(2026, 11, 21),
    likesCount: 14,
    commentsCount: 6,
    isLikedByMe: true,
    createdAt: DateTime(2026, 11, 20),
  );

  group('PostCard Widget Tests', () {
    testWidgets('renders title, category pill, author name, likes and comments',
        (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PostCard(
              post: samplePost,
              onLikeToggle: () {},
            ),
          ),
        ),
      );

      expect(find.text('Modern Drip Irrigation Systems'), findsOneWidget);
      expect(find.text('AGRICULTURE'), findsOneWidget);
      expect(find.text('By Professor Tariq'), findsOneWidget);
      expect(find.text('14'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.byIcon(Icons.favorite), findsOneWidget); // Liked by me
    });
  });

  group('BlogFeedScreen Widget Tests', () {
    testWidgets('renders category filter chips and search toggle',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            blogFeedProvider.overrideWith((ref) async => [samplePost]),
          ],
          child: const MaterialApp(
            home: BlogFeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verifies AppBar and Category Chips
      expect(find.text('Blog & Updates'), findsOneWidget);
      expect(find.text('All Topics'), findsOneWidget);
      expect(find.text('Education'), findsOneWidget);
      expect(find.text('Technology & Innovation'), findsOneWidget);
      expect(find.text('Agriculture'), findsOneWidget);

      // Verifies PostCard in feed
      expect(find.text('Modern Drip Irrigation Systems'), findsOneWidget);

      // Verify search icon
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets('displays empty state when no posts are available',
        (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            blogFeedProvider.overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: BlogFeedScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('No Posts Yet'), findsOneWidget);
      expect(
        find.text('Check back later for news, updates, and articles.'),
        findsOneWidget,
      );
    });
  });
}
