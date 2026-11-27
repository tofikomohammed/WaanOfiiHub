import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/blog/data/blog_repository.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_category.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_post.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_tag.dart';

void main() {
  group('BlogPost Reading Time & Tags Tests', () {
    test(
      'calculates reading time accurately based on 200 words per minute',
      () {
        final shortPost = BlogPost(
          id: '1',
          authorId: 'u1',
          type: 'text',
          title: 'Short Update',
          body: 'This is a brief announcement about our new platform release.',
          status: 'published',
          createdAt: DateTime.now(),
        );
        // Minimum 1 min
        expect(shortPost.readingTimeMinutes, 1);

        // 450 words -> 3 min
        final longBody = List.generate(450, (i) => 'word$i').join(' ');
        final longPost = shortPost.copyWith(body: longBody);
        expect(longPost.readingTimeMinutes, 3);
      },
    );

    test('parses tags and custom likes/comments count from json', () {
      final json = {
        'id': 'p100',
        'author_id': 'u100',
        'type': 'image',
        'category': 'technology',
        'title': 'AI Advances',
        'body': 'Discussing machine intelligence in community systems.',
        'status': 'published',
        'tags': ['flutter', 'ai', 'cloud'],
        'likes_count': 42,
        'comments_count': 12,
        'created_at': '2026-11-21T10:00:00Z',
        'profiles': {'display_name': 'Dr. Tofik'},
      };

      final post = BlogPost.fromJson(json);
      expect(post.tags, ['flutter', 'ai', 'cloud']);
      expect(post.likesCount, 42);
      expect(post.commentsCount, 12);
      expect(post.authorName, 'Dr. Tofik');
      expect(post.categoryDisplayName, 'Technology & Innovation');
    });
  });

  group('BlogCategory & BlogTag Model Tests', () {
    test('BlogCategory parses from JSON and converts to JSON', () {
      final json = {
        'id': 'cat-1',
        'name': 'Health & Wellness',
        'slug': 'health',
        'description': 'Healthcare articles and wellness tips',
        'created_at': '2026-11-20T12:00:00Z',
      };

      final cat = BlogCategory.fromJson(json);
      expect(cat.id, 'cat-1');
      expect(cat.name, 'Health & Wellness');
      expect(cat.slug, 'health');
      expect(cat.description, 'Healthcare articles and wellness tips');

      final serialized = cat.toJson();
      expect(serialized['slug'], 'health');
    });

    test('BlogTag parses from JSON and converts to JSON', () {
      final json = {
        'id': 'tag-1',
        'name': 'Innovation',
        'slug': 'innovation',
        'created_at': '2026-11-20T12:00:00Z',
      };

      final tag = BlogTag.fromJson(json);
      expect(tag.id, 'tag-1');
      expect(tag.name, 'Innovation');
      expect(tag.slug, 'innovation');

      final serialized = tag.toJson();
      expect(serialized['slug'], 'innovation');
    });
  });

  group('BlogRepository Discovery & Taxonomies Null Safety Tests', () {
    late BlogRepository repo;

    setUp(() {
      repo = BlogRepository(null);
    });

    test('getPublishedPosts returns empty list when uninitialized', () async {
      final posts = await repo.getPublishedPosts(
        category: 'technology',
        postType: 'image',
        tag: 'flutter',
        dateFrom: DateTime.now().subtract(const Duration(days: 7)),
        sortBy: 'likes',
        searchQuery: 'AI',
      );
      expect(posts, isEmpty);
    });

    test('getRelatedPosts returns empty list when uninitialized', () async {
      final related = await repo.getRelatedPosts(
        postId: 'p1',
        category: 'education',
        tags: ['learning'],
      );
      expect(related, isEmpty);
    });

    test('Category & Tag methods safely return without crashing when uninitialized', () async {
      expect(await repo.getCategories(), isEmpty);
      expect(await repo.getTags(), isEmpty);

      // Should complete normally without throwing
      await repo.createCategory(name: 'Test', slug: 'test');
      await repo.renameCategory(id: '1', newName: 'New', newSlug: 'new');
      await repo.mergeCategories(sourceSlug: 'a', targetSlug: 'b');
      await repo.deleteCategory(slug: 'a');

      await repo.createTag('mobile');
      await repo.renameTag(id: '1', newName: 'web', newSlug: 'web');
      await repo.mergeTags(sourceName: 'old', targetName: 'new');
      await repo.deleteTag('old');
    });
  });
}
