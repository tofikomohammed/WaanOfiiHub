import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_post.dart';

void main() {
  group('BlogPost Model Tests', () {
    test('parses complete json correctly with category and profile data', () {
      final json = {
        'id': 'post-123',
        'author_id': 'author-456',
        'type': 'text',
        'category': 'technology',
        'title': 'AI Innovations in 2026',
        'body': 'Deep dive into decentralized technologies.',
        'cover_url': 'https://example.com/ai.png',
        'status': 'published',
        'published_at': '2026-11-20T10:00:00Z',
        'is_pinned': true,
        'created_at': '2026-11-19T08:00:00Z',
        'profiles': {'display_name': 'Dr. Aisha', 'avatar_url': null},
        'post_likes': [
          {'user_id': 'user-1'},
          {'user_id': 'user-current'},
        ],
        'post_comments': [
          {'id': 'c-1'},
          {'id': 'c-2'},
          {'id': 'c-3'},
        ],
      };

      final post = BlogPost.fromJson(json, currentUserId: 'user-current');

      expect(post.id, 'post-123');
      expect(post.authorId, 'author-456');
      expect(post.authorName, 'Dr. Aisha');
      expect(post.type, 'text');
      expect(post.category, 'technology');
      expect(post.categoryDisplayName, 'Technology & Innovation');
      expect(post.title, 'AI Innovations in 2026');
      expect(post.body, 'Deep dive into decentralized technologies.');
      expect(post.coverUrl, 'https://example.com/ai.png');
      expect(post.status, 'published');
      expect(post.isPinned, isTrue);
      expect(post.likesCount, 2);
      expect(post.commentsCount, 3);
      expect(post.isLikedByMe, isTrue);
    });

    test('falls back to default category when missing in json', () {
      final json = {
        'id': 'post-minimal',
        'author_id': 'author-1',
        'title': 'Brief News',
      };

      final post = BlogPost.fromJson(json);

      expect(post.category, BlogCategories.news);
      expect(post.categoryDisplayName, 'News & Updates');
      expect(post.type, 'text');
      expect(post.status, 'draft');
      expect(post.isLikedByMe, isFalse);
    });

    test('copyWith updates properties correctly', () {
      final original = BlogPost(
        id: 'post-1',
        authorId: 'auth-1',
        type: 'text',
        category: BlogCategories.health,
        title: 'Original Title',
        status: 'draft',
        createdAt: DateTime.now(),
      );

      final updated = original.copyWith(
        title: 'Updated Title',
        category: BlogCategories.agriculture,
        status: 'published',
        likesCount: 5,
        isLikedByMe: true,
      );

      expect(updated.id, 'post-1');
      expect(updated.title, 'Updated Title');
      expect(updated.category, BlogCategories.agriculture);
      expect(updated.categoryDisplayName, 'Agriculture');
      expect(updated.status, 'published');
      expect(updated.likesCount, 5);
      expect(updated.isLikedByMe, isTrue);
    });

    test('all 8 designated domains return distinct readable display names', () {
      expect(BlogCategories.all.length, 8);
      for (final cat in BlogCategories.all) {
        final name = BlogCategories.getDisplayName(cat);
        expect(name.isNotEmpty, isTrue);
        expect(name, isNot(cat)); // display name is capitalized/formatted
      }
    });
  });
}
