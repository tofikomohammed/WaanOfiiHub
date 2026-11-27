import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/admin/presentation/admin_taxonomies_screen.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_repository.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_category.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_post.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_tag.dart';
import 'package:waan_ofii_hub/features/blog/presentation/category_tag_posts_screen.dart';
import 'package:waan_ofii_hub/features/blog/presentation/widgets/post_card.dart';

void main() {
  group('PostCard Discovery Features Test', () {
    testWidgets('renders author, reading time and tag pills correctly', (
      tester,
    ) async {
      final post = BlogPost(
        id: 'post-1',
        authorId: 'auth-1',
        authorName: 'Amina Roba',
        type: 'text',
        category: 'health',
        title: 'Community Health Awareness',
        body: 'This is a guide on community wellness and sanitation practices.',
        status: 'published',
        publishedAt: DateTime(2026, 11, 20),
        likesCount: 15,
        commentsCount: 3,
        tags: const ['health', 'community', 'wellness'],
        createdAt: DateTime(2026, 11, 20),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: PostCard(post: post)),
        ),
      );

      expect(find.text('Community Health Awareness'), findsOneWidget);
      expect(find.text('By Amina Roba'), findsOneWidget);
      expect(find.textContaining('1 min read'), findsOneWidget);
      expect(find.text('#health'), findsOneWidget);
      expect(find.text('#community'), findsOneWidget);
    });
  });

  group('CategoryTagPostsScreen Tests', () {
    testWidgets('renders category topic header and empty state when empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoryTagPostsProvider(const TopicParams(category: 'technology'))
                .overrideWith((ref) async => []),
          ],
          child: const MaterialApp(
            home: CategoryTagPostsScreen(category: 'technology'),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Technology & Innovation'), findsAtLeastNWidgets(1));
      expect(find.text('No Posts Found'), findsOneWidget);
    });
  });

  group('AdminTaxonomiesScreen Tests', () {
    testWidgets('renders Categories and Tags tabs and list items', (
      tester,
    ) async {
      final dummyCategories = [
        BlogCategory(
          id: '1',
          name: 'Agriculture',
          slug: 'agriculture',
          description: 'Crops and livestock',
          createdAt: DateTime.now(),
        ),
      ];

      final dummyTags = [
        BlogTag(
          id: '1',
          name: 'innovation',
          slug: 'innovation',
          createdAt: DateTime.now(),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesListProvider.overrideWith((ref) async => dummyCategories),
            tagsListProvider.overrideWith((ref) async => dummyTags),
          ],
          child: const MaterialApp(home: AdminTaxonomiesScreen()),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Categories & Tags'), findsOneWidget);
      expect(find.text('Categories'), findsOneWidget);
      expect(find.text('Tags'), findsOneWidget);
      expect(find.text('Agriculture'), findsOneWidget);
      expect(find.text('Crops and livestock'), findsOneWidget);

      // Switch to Tags Tab
      await tester.tap(find.text('Tags'));
      await tester.pumpAndSettle();

      expect(find.text('#innovation'), findsOneWidget);
    });
  });
}
