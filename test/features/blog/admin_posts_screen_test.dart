import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/admin/presentation/admin_posts_screen.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_repository.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_post.dart';

void main() {
  group('AdminPostsFilter Tests', () {
    test('default filter parameters are all and empty search', () {
      const filter = AdminPostsFilter();
      expect(filter.status, 'all');
      expect(filter.type, 'all');
      expect(filter.searchQuery, '');
    });

    test('value equality and hashCode work correctly', () {
      const filter1 = AdminPostsFilter(
        status: 'published',
        type: 'audio',
        searchQuery: 'health',
      );
      const filter2 = AdminPostsFilter(
        status: 'published',
        type: 'audio',
        searchQuery: 'health',
      );
      const filter3 = AdminPostsFilter(
        status: 'draft',
        type: 'audio',
        searchQuery: 'health',
      );

      expect(filter1, equals(filter2));
      expect(filter1.hashCode, equals(filter2.hashCode));
      expect(filter1, isNot(equals(filter3)));
    });
  });

  group('BlogRepository Admin Posts Methods', () {
    test('getAllPostsAdmin returns empty list when uninitialized', () async {
      final repo = BlogRepository(null);
      final res = await repo.getAllPostsAdmin();
      expect(res, isEmpty);
    });

    test('togglePinPost executes safely when uninitialized', () async {
      final repo = BlogRepository(null);
      await expectLater(repo.togglePinPost('post-1', true), completes);
    });

    test('setPostStatus executes safely when uninitialized', () async {
      final repo = BlogRepository(null);
      await expectLater(repo.setPostStatus('post-1', 'archived'), completes);
    });
  });

  group('AdminPostsScreen Widget Tests', () {
    testWidgets('renders search field, filter chips, and empty state', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            adminPostsProvider.overrideWith((ref, filter) async => []),
          ],
          child: const MaterialApp(home: AdminPostsScreen()),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Header & Search
      expect(find.text('Articles & Content Manager'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify Status Filter Chips
      expect(find.text('Status: '), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Published'), findsOneWidget);
      expect(find.text('Scheduled'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Archived'), findsOneWidget);

      // Verify Type Filter Chips
      expect(find.text('Type: '), findsOneWidget);
      expect(find.text('All Types'), findsOneWidget);
      expect(find.text('Text'), findsOneWidget);
      expect(find.text('Image'), findsOneWidget);
      expect(find.text('Audio'), findsOneWidget);

      // Verify Floating Action Button
      expect(find.text('New Article'), findsOneWidget);

      // Verify Empty State
      expect(find.text('No Articles Found'), findsOneWidget);
    });

    testWidgets(
      'renders post items with status badge, metrics and fast actions',
      (tester) async {
        final dummyPosts = [
          BlogPost(
            id: 'admin-post-1',
            authorId: 'auth-1',
            authorName: 'Admin Leader',
            type: 'text',
            category: 'technology',
            title: 'Artificial Intelligence in Agriculture',
            body:
                'How AI and modern tools are revolutionizing crop management.',
            status: 'published',
            publishedAt: DateTime(2026, 11, 25),
            isPinned: true,
            likesCount: 42,
            commentsCount: 12,
            viewsCount: 230,
            createdAt: DateTime(2026, 11, 20),
          ),
          BlogPost(
            id: 'admin-post-2',
            authorId: 'auth-2',
            authorName: 'Author 2',
            type: 'audio',
            category: 'health',
            title: 'Health & Wellness Audio Guide',
            body: 'Audio guide description.',
            status: 'scheduled',
            scheduledFor: DateTime(2026, 12, 1, 10, 0),
            createdAt: DateTime(2026, 11, 21),
          ),
        ];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              adminPostsProvider.overrideWith(
                (ref, filter) async => dummyPosts,
              ),
            ],
            child: const MaterialApp(home: AdminPostsScreen()),
          ),
        );

        await tester.pumpAndSettle();

        // Check titles
        expect(
          find.text('Artificial Intelligence in Agriculture'),
          findsOneWidget,
        );
        expect(find.text('Health & Wellness Audio Guide'), findsOneWidget);

        // Check badges
        expect(find.text('PUBLISHED'), findsOneWidget);
        expect(find.text('SCHEDULED'), findsOneWidget);
        expect(find.text('PINNED'), findsOneWidget);

        // Check metrics counters
        expect(find.text('230'), findsOneWidget); // views
        expect(find.text('42'), findsOneWidget); // likes
        expect(find.text('12'), findsOneWidget); // comments

        // Check action buttons
        expect(find.text('Unpublish'), findsOneWidget);
        expect(find.text('Publish'), findsOneWidget);
        expect(find.text('Edit'), findsNWidgets(2));
      },
    );
  });
}
