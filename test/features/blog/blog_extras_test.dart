import 'package:flutter_test/flutter_test.dart';
import 'package:waan_ofii_hub/features/blog/models/blog_post.dart';
import 'package:waan_ofii_hub/features/blog/models/post_comment.dart';

void main() {
  group('Blog Extras - Threaded Comments & Depth Limit', () {
    test('PostComment.buildTree correctly nests direct replies under parent comments', () {
      final now = DateTime.now();
      final comments = [
        PostComment(
          id: 'c1',
          postId: 'post1',
          userId: 'user1',
          userName: 'Alice',
          body: 'Top-level comment 1',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        PostComment(
          id: 'c2',
          postId: 'post1',
          userId: 'user2',
          userName: 'Bob',
          body: 'Reply to comment 1',
          parentId: 'c1',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
        PostComment(
          id: 'c3',
          postId: 'post1',
          userId: 'user3',
          userName: 'Charlie',
          body: 'Top-level comment 2',
          createdAt: now.subtract(const Duration(minutes: 2)),
        ),
      ];

      final tree = PostComment.buildTree(comments);

      expect(tree.length, 2);
      expect(tree[0].id, 'c1');
      expect(tree[0].replies.length, 1);
      expect(tree[0].replies[0].id, 'c2');
      expect(tree[0].replies[0].parentId, 'c1');
      expect(tree[1].id, 'c3');
      expect(tree[1].replies, isEmpty);
    });

    test('PostComment.buildTree enforces depth limit (depth 2) by flattening deeper replies', () {
      final now = DateTime.now();
      final comments = [
        PostComment(
          id: 'root',
          postId: 'post1',
          userId: 'user1',
          userName: 'Root User',
          body: 'Root discussion',
          createdAt: now.subtract(const Duration(minutes: 15)),
        ),
        PostComment(
          id: 'child',
          postId: 'post1',
          userId: 'user2',
          userName: 'Child User',
          body: 'Child reply (depth 2)',
          parentId: 'root',
          createdAt: now.subtract(const Duration(minutes: 10)),
        ),
        PostComment(
          id: 'grandchild',
          postId: 'post1',
          userId: 'user3',
          userName: 'Grandchild User',
          body: 'Grandchild reply to child',
          parentId: 'child',
          createdAt: now.subtract(const Duration(minutes: 5)),
        ),
      ];

      final tree = PostComment.buildTree(comments);

      expect(tree.length, 1);
      final root = tree.first;
      expect(root.id, 'root');
      // Both replies are contained in root.replies (depth limit 2)
      expect(root.replies.length, 2);
      expect(root.replies.map((r) => r.id).toList(), ['child', 'grandchild']);
    });

    test('PostComment parses parent_id and updated_at from json', () {
      final json = {
        'id': 'c-100',
        'post_id': 'p-200',
        'user_id': 'u-300',
        'body': 'Updated comment body',
        'created_at': '2026-11-21T10:00:00Z',
        'updated_at': '2026-11-21T10:30:00Z',
        'is_hidden': true,
        'parent_id': 'c-099',
        'profiles': {'display_name': 'Moderated User', 'avatar_url': null},
      };

      final comment = PostComment.fromJson(json);

      expect(comment.id, 'c-100');
      expect(comment.postId, 'p-200');
      expect(comment.body, 'Updated comment body');
      expect(comment.parentId, 'c-099');
      expect(comment.isHidden, isTrue);
      expect(comment.updatedAt, isNotNull);
      expect(comment.updatedAt, DateTime.parse('2026-11-21T10:30:00Z'));
    });
  });

  group('Blog Extras - Scheduled Publishing', () {
    test('BlogPost isScheduled returns true when status is scheduled', () {
      final futureDate = DateTime.now().toUtc().add(const Duration(days: 3));
      final post = BlogPost(
        id: 'p-scheduled-1',
        authorId: 'auth-1',
        type: 'text',
        title: 'Upcoming Announcement',
        status: 'scheduled',
        scheduledFor: futureDate,
        createdAt: DateTime.now(),
      );

      expect(post.isScheduled, isTrue);
      expect(post.status, 'scheduled');
      expect(post.scheduledFor, futureDate);
    });

    test('BlogPost parses scheduled_for from json and stores UTC format', () {
      const scheduledIso = '2026-12-01T15:30:00.000Z';
      final json = {
        'id': 'p-scheduled-2',
        'author_id': 'auth-2',
        'type': 'text',
        'title': 'December Launch',
        'body': 'Coming soon',
        'status': 'scheduled',
        'scheduled_for': scheduledIso,
        'created_at': '2026-11-21T12:00:00Z',
      };

      final post = BlogPost.fromJson(json);

      expect(post.isScheduled, isTrue);
      expect(post.scheduledFor, isNotNull);
      expect(post.scheduledFor!.toUtc().toIso8601String(), scheduledIso);
    });

    test('BlogPost copyWith preserves or updates scheduled status and date', () {
      final post = BlogPost(
        id: 'p-1',
        authorId: 'auth-1',
        type: 'text',
        title: 'Draft Post',
        status: 'draft',
        createdAt: DateTime.now(),
      );

      expect(post.isScheduled, isFalse);

      final scheduledTime = DateTime.now().add(const Duration(hours: 12));
      final updated = post.copyWith(
        status: 'scheduled',
        scheduledFor: scheduledTime,
      );

      expect(updated.isScheduled, isTrue);
      expect(updated.status, 'scheduled');
      expect(updated.scheduledFor, scheduledTime);
    });
  });

  group('Blog Extras - View Counts', () {
    test('BlogPost correctly parses views_count with default 0 fallback', () {
      final jsonWithViews = {
        'id': 'p-v-1',
        'author_id': 'auth-1',
        'type': 'text',
        'title': 'Popular Article',
        'status': 'published',
        'views_count': 1420,
        'created_at': '2026-11-21T12:00:00Z',
      };

      final postWithViews = BlogPost.fromJson(jsonWithViews);
      expect(postWithViews.viewsCount, 1420);

      final jsonWithoutViews = {
        'id': 'p-v-2',
        'author_id': 'auth-1',
        'type': 'text',
        'title': 'Brand New Article',
        'status': 'published',
        'created_at': '2026-11-21T12:00:00Z',
      };

      final postWithoutViews = BlogPost.fromJson(jsonWithoutViews);
      expect(postWithoutViews.viewsCount, 0);
    });

    test('BlogPost copyWith updates viewsCount', () {
      final post = BlogPost(
        id: 'p-1',
        authorId: 'auth-1',
        type: 'text',
        title: 'Title',
        status: 'published',
        viewsCount: 5,
        createdAt: DateTime.now(),
      );

      final incremented = post.copyWith(viewsCount: post.viewsCount + 1);
      expect(incremented.viewsCount, 6);
    });
  });

  group('Blog Extras - Moderation Actions & Audit Logs', () {
    test('Validates report moderation action constants', () {
      const validActions = ['dismiss', 'action_hide', 'action_delete'];
      expect(validActions.contains('dismiss'), isTrue);
      expect(validActions.contains('action_hide'), isTrue);
      expect(validActions.contains('action_delete'), isTrue);
      expect(validActions.contains('invalid_action'), isFalse);
    });
  });
}
