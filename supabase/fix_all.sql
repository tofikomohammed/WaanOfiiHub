-- ==============================================================================
-- WAAN-OFIIHUB: COMPLETE DATABASE & REALTIME REPAIR SCRIPT (fix_all.sql)
-- Run this in your Supabase SQL Editor (https://supabase.com/dashboard)
-- ==============================================================================

-- ------------------------------------------------------------------------------
-- 1. Helper function with SECURITY DEFINER to eliminate infinite recursion in RLS
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_conversation_member(_conv_id UUID, _user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.conversation_members
        WHERE conversation_id = _conv_id AND user_id = _user_id
    );
$$;

-- ------------------------------------------------------------------------------
-- 2. Fixed RLS Policies on Conversations
-- ------------------------------------------------------------------------------
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Conversations viewable by members or if open community" ON public.conversations;
CREATE POLICY "Conversations viewable by members or if open community"
    ON public.conversations FOR SELECT TO authenticated
    USING (
        (type = 'community' AND is_open = TRUE)
        OR direct_user1 = auth.uid()
        OR direct_user2 = auth.uid()
        OR public.is_conversation_member(id, auth.uid())
    );

DROP POLICY IF EXISTS "Authenticated users can create conversations" ON public.conversations;
CREATE POLICY "Authenticated users can create conversations"
    ON public.conversations FOR INSERT TO authenticated
    WITH CHECK (created_by = auth.uid());

-- ------------------------------------------------------------------------------
-- 3. Fixed RLS Policies on Conversation Members (No recursion)
-- ------------------------------------------------------------------------------
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Members viewable by fellow members or open community" ON public.conversation_members;
CREATE POLICY "Members viewable by fellow members or open community"
    ON public.conversation_members FOR SELECT TO authenticated
    USING (
        user_id = auth.uid()
        OR public.is_conversation_member(conversation_id, auth.uid())
        OR EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = conversation_members.conversation_id AND c.type = 'community' AND c.is_open = TRUE
        )
    );

DROP POLICY IF EXISTS "Conversation creators or members can add members" ON public.conversation_members;
CREATE POLICY "Conversation creators or members can add members"
    ON public.conversation_members FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        OR EXISTS (
            SELECT 1 FROM public.conversations c
            WHERE c.id = conversation_members.conversation_id AND c.created_by = auth.uid()
        )
        OR public.is_conversation_member(conversation_id, auth.uid())
    );

DROP POLICY IF EXISTS "Members can update their own member settings" ON public.conversation_members;
CREATE POLICY "Members can update their own member settings"
    ON public.conversation_members FOR UPDATE TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 4. Fixed RLS Policies on Messages
-- ------------------------------------------------------------------------------
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Messages readable only by conversation members" ON public.messages;
CREATE POLICY "Messages readable only by conversation members"
    ON public.messages FOR SELECT TO authenticated
    USING (
        public.is_conversation_member(conversation_id, auth.uid())
        AND NOT EXISTS (
            SELECT 1 FROM public.message_deletions md
            WHERE md.message_id = messages.id AND md.user_id = auth.uid()
        )
    );

DROP POLICY IF EXISTS "Send message requires membership and not blocked" ON public.messages;
CREATE POLICY "Send message requires membership and not blocked"
    ON public.messages FOR INSERT TO authenticated
    WITH CHECK (
        sender_id = auth.uid()
        AND public.is_conversation_member(conversation_id, auth.uid())
        AND NOT EXISTS (
            SELECT 1 FROM public.conversations c
            JOIN public.blocks b ON (b.blocker_id = c.direct_user1 AND b.blocked_id = auth.uid())
                                 OR (b.blocker_id = c.direct_user2 AND b.blocked_id = auth.uid())
            WHERE c.id = messages.conversation_id
        )
    );

-- ------------------------------------------------------------------------------
-- 5. Receipts & Deletions Policies
-- ------------------------------------------------------------------------------
ALTER TABLE public.message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_deletions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own message receipts" ON public.message_receipts;
CREATE POLICY "Users can manage own message receipts"
    ON public.message_receipts FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can manage own message deletions" ON public.message_deletions;
CREATE POLICY "Users can manage own message deletions"
    ON public.message_deletions FOR ALL TO authenticated
    USING (user_id = auth.uid())
    WITH CHECK (user_id = auth.uid());

-- ------------------------------------------------------------------------------
-- 6. Enable Realtime Broadcasting on messages & conversations
-- ------------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'messages'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.messages;
    END IF;

    IF NOT EXISTS (
        SELECT 1 FROM pg_publication_tables 
        WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'conversations'
    ) THEN
        ALTER PUBLICATION supabase_realtime ADD TABLE public.conversations;
    END IF;
END $$;

ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.conversations REPLICA IDENTITY FULL;

-- ------------------------------------------------------------------------------
-- 7. Stored Procedures & Chat RPCs
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.start_direct_conversation(target_user_id UUID)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    u1 UUID;
    u2 UUID;
    existing_id UUID;
    new_id UUID;
BEGIN
    IF target_user_id = auth.uid() THEN
        RAISE EXCEPTION 'Cannot start conversation with yourself.';
    END IF;

    -- Check if either user has blocked the other
    IF EXISTS (
        SELECT 1 FROM public.blocks
        WHERE (blocker_id = auth.uid() AND blocked_id = target_user_id)
           OR (blocker_id = target_user_id AND blocked_id = auth.uid())
    ) THEN
        RAISE EXCEPTION 'Unable to start conversation due to user block.';
    END IF;

    -- Sort user IDs to enforce unique 1-to-1 constraint
    IF auth.uid() < target_user_id THEN
        u1 := auth.uid();
        u2 := target_user_id;
    ELSE
        u1 := target_user_id;
        u2 := auth.uid();
    END IF;

    -- Check existing
    SELECT id INTO existing_id
    FROM public.conversations
    WHERE direct_user1 = u1 AND direct_user2 = u2;

    IF existing_id IS NOT NULL THEN
        RETURN existing_id;
    END IF;

    -- Create new conversation
    INSERT INTO public.conversations (type, direct_user1, direct_user2, created_by)
    VALUES ('direct', u1, u2, auth.uid())
    RETURNING id INTO new_id;

    -- Add members
    INSERT INTO public.conversation_members (conversation_id, user_id, role)
    VALUES 
        (new_id, u1, 'member'),
        (new_id, u2, 'member')
    ON CONFLICT (conversation_id, user_id) DO NOTHING;

    RETURN new_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.send_chat_message(
    conv_id UUID,
    msg_type TEXT,
    msg_body TEXT,
    media_url TEXT DEFAULT NULL,
    media_mime_type TEXT DEFAULT NULL,
    media_bytes BIGINT DEFAULT NULL,
    media_dur INTEGER DEFAULT NULL,
    reply_msg_id UUID DEFAULT NULL
)
RETURNS UUID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    new_msg_id UUID;
BEGIN
    -- Verify membership
    IF NOT EXISTS (
        SELECT 1 FROM public.conversation_members
        WHERE conversation_id = conv_id AND user_id = auth.uid()
    ) THEN
        RAISE EXCEPTION 'You are not a member of this conversation.';
    END IF;

    -- Insert message
    INSERT INTO public.messages (
        conversation_id,
        sender_id,
        type,
        body,
        media_path,
        media_mime,
        media_size,
        media_duration_seconds,
        reply_to_id
    ) VALUES (
        conv_id,
        auth.uid(),
        msg_type,
        msg_body,
        media_url,
        media_mime_type,
        media_bytes,
        media_dur,
        reply_msg_id
    ) RETURNING id INTO new_msg_id;

    -- Update conversation last message snippet
    UPDATE public.conversations
    SET 
        last_message_text = CASE 
            WHEN msg_type = 'text' THEN left(msg_body, 80)
            WHEN msg_type = 'image' THEN '📷 Photo'
            WHEN msg_type = 'audio' THEN '🎵 Voice note'
            ELSE 'Attachment'
        END,
        last_message_at = NOW()
    WHERE id = conv_id;

    RETURN new_msg_id;
END;
$$;

-- ------------------------------------------------------------------------------
-- 8. Contact Matching Function
-- ------------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.match_contacts(hashes TEXT[])
RETURNS TABLE (
    id UUID,
    public_id TEXT,
    display_name TEXT,
    avatar_url TEXT,
    phone_verified BOOLEAN,
    phone_hash TEXT
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF array_length(hashes, 1) > 1000 THEN
        RAISE EXCEPTION 'Too many hashes provided in a single request (maximum 1000).';
    END IF;

    RETURN QUERY
    SELECT 
        p.id,
        p.public_id,
        p.display_name,
        p.avatar_url,
        p.phone_verified,
        p.phone_hash
    FROM public.profiles p
    WHERE 
        p.is_banned = FALSE
        AND p.allow_phone_discovery = TRUE
        AND p.phone_hash = ANY(hashes)
        AND p.id != auth.uid();
END;
$$;

-- ------------------------------------------------------------------------------
-- 9. Grant Permissions & Superadmin
-- ------------------------------------------------------------------------------
GRANT EXECUTE ON FUNCTION public.is_conversation_member TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.start_direct_conversation TO authenticated;
GRANT EXECUTE ON FUNCTION public.send_chat_message TO authenticated;
GRANT EXECUTE ON FUNCTION public.match_contacts TO authenticated;

INSERT INTO public.user_roles (user_id, role_id)
SELECT u.id, r.id
FROM auth.users u
CROSS JOIN public.roles r
WHERE r.key = 'superadmin'
ON CONFLICT (user_id, role_id) DO NOTHING;


-- ------------------------------------------------------------------------------
-- 10. Blog Phase 1: Categories, Search, Hardened RLS & Storage Policies
-- ------------------------------------------------------------------------------
ALTER TABLE public.posts 
    ADD COLUMN IF NOT EXISTS category TEXT NOT NULL DEFAULT 'news'
    CHECK (category IN (
        'education',
        'technology',
        'health',
        'community',
        'agriculture',
        'business',
        'ethics',
        'news'
    ));

CREATE INDEX IF NOT EXISTS idx_posts_category_published 
    ON public.posts(category, published_at DESC) 
    WHERE status = 'published';

CREATE INDEX IF NOT EXISTS idx_posts_search_gin 
    ON public.posts USING gin(to_tsvector('english', title || ' ' || body));

DROP POLICY IF EXISTS "Published posts are readable by all authenticated" ON public.posts;
CREATE POLICY "Published posts are readable by all authenticated"
    ON public.posts FOR SELECT TO authenticated
    USING (
        status = 'published'
        OR author_id = auth.uid()
        OR public.has_permission('blog.edit_any')
    );

DROP POLICY IF EXISTS "Create post requires blog.create" ON public.posts;
CREATE POLICY "Create post requires blog.create"
    ON public.posts FOR INSERT TO authenticated
    WITH CHECK (
        author_id = auth.uid()
        AND public.has_permission('blog.create')
    );

DROP POLICY IF EXISTS "Edit post requires permissions" ON public.posts;
CREATE POLICY "Edit post requires permissions"
    ON public.posts FOR UPDATE TO authenticated
    USING (
        (author_id = auth.uid() AND public.has_permission('blog.edit_own'))
        OR public.has_permission('blog.edit_any')
    )
    WITH CHECK (
        (
            (author_id = auth.uid() AND public.has_permission('blog.edit_own'))
            AND (status != 'published' OR public.has_permission('blog.publish'))
        )
        OR public.has_permission('blog.edit_any')
    );

DROP POLICY IF EXISTS "Delete post requires blog.delete" ON public.posts;
DROP POLICY IF EXISTS "Delete post requires blog.delete or own draft" ON public.posts;
CREATE POLICY "Delete post requires blog.delete or own draft"
    ON public.posts FOR DELETE TO authenticated
    USING (
        (author_id = auth.uid() AND status = 'draft')
        OR public.has_permission('blog.delete')
    );

DROP POLICY IF EXISTS "Delete blog-media requires blog.delete" ON storage.objects;
DROP POLICY IF EXISTS "Delete blog-media requires blog.delete or own folder" ON storage.objects;
CREATE POLICY "Delete blog-media requires blog.delete or own folder"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'blog-media'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('blog.delete')
        )
    );


-- ------------------------------------------------------------------------------
-- 11. Blog Phase B6: Media Storage, WAV Support & Enhanced Media RLS
-- ------------------------------------------------------------------------------
UPDATE storage.buckets
SET 
    allowed_mime_types = ARRAY[
        'image/jpeg', 
        'image/png', 
        'image/webp',
        'audio/mpeg', 
        'audio/mp4', 
        'audio/aac', 
        'audio/ogg', 
        'audio/x-m4a',
        'audio/wav',
        'audio/x-wav'
    ],
    file_size_limit = 26214400
WHERE id = 'blog-media';

CREATE OR REPLACE FUNCTION public.can_access_blog_media(object_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT (
        public.has_permission('blog.edit_any')
        OR (storage.foldername(object_name))[1] = auth.uid()::text
        OR EXISTS (
            SELECT 1 FROM public.post_media pm
            JOIN public.posts p ON pm.post_id = p.id
            WHERE pm.storage_path = object_name
              AND p.status = 'published'
        )
        OR EXISTS (
            SELECT 1 FROM public.posts p
            WHERE (p.cover_url LIKE '%' || object_name OR p.cover_url = object_name)
              AND p.status = 'published'
        )
    );
$$;

DROP POLICY IF EXISTS "Published or author read blog-media" ON storage.objects;
CREATE POLICY "Published or author read blog-media"
    ON storage.objects FOR SELECT
    TO public
    USING (
        bucket_id = 'blog-media'
        AND public.can_access_blog_media(name)
    );

DROP POLICY IF EXISTS "Write blog-media requires blog.create" ON storage.objects;
CREATE POLICY "Write blog-media requires blog.create"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'blog-media'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('blog.edit_any')
        )
        AND public.has_permission('blog.create')
    );


-- ------------------------------------------------------------------------------
-- 10. Blog Discovery, Taxonomies, Filters, Sorting & Pagination (00009_blog_discovery.sql)
-- ------------------------------------------------------------------------------

-- Categories Table
CREATE TABLE IF NOT EXISTS public.blog_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.blog_categories (name, slug, description)
VALUES
    ('Education', 'education', 'Educational articles, learning resources and knowledge sharing'),
    ('Technology & Innovation', 'technology', 'Tech insights, modern tools, digital literacy and software'),
    ('Health & Wellness', 'health', 'Human, plant and animal health, wellness and medicine'),
    ('Community Development', 'community', 'Community initiatives, social empowerment and local news'),
    ('Agriculture', 'agriculture', 'Farming techniques, agro-business, crops and livestock'),
    ('Business & Entrepreneurship', 'business', 'Startups, business strategy, finance and economics'),
    ('Ethics & Good Deeds', 'ethics', 'Morality, ethical leadership, spirituality and goodwill'),
    ('News & Updates', 'news', 'Official announcements, organizational updates and headlines')
ON CONFLICT (slug) DO UPDATE SET
    name = EXCLUDED.name,
    description = EXCLUDED.description;

-- Tags Table
CREATE TABLE IF NOT EXISTS public.blog_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO public.blog_tags (name, slug)
VALUES
    ('Innovation', 'innovation'),
    ('Flutter', 'flutter'),
    ('Community', 'community'),
    ('Health', 'health'),
    ('Agriculture', 'agriculture'),
    ('Leadership', 'leadership'),
    ('Tips', 'tips'),
    ('Announcement', 'announcement')
ON CONFLICT (slug) DO NOTHING;

-- Add tags, likes_count, and comments_count
ALTER TABLE public.posts
    ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0;

-- Backfill counts
UPDATE public.posts p
SET 
    likes_count = (SELECT COUNT(*) FROM public.post_likes pl WHERE pl.post_id = p.id),
    comments_count = (SELECT COUNT(*) FROM public.post_comments pc WHERE pc.post_id = p.id AND pc.is_hidden = FALSE);

-- Likes trigger function
CREATE OR REPLACE FUNCTION public.handle_post_like_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        UPDATE public.posts
        SET likes_count = likes_count + 1
        WHERE id = NEW.post_id;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        UPDATE public.posts
        SET likes_count = GREATEST(likes_count - 1, 0)
        WHERE id = OLD.post_id;
        RETURN OLD;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_post_likes_count ON public.post_likes;
CREATE TRIGGER trg_post_likes_count
    AFTER INSERT OR DELETE ON public.post_likes
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_post_like_count();

-- Comments trigger function
CREATE OR REPLACE FUNCTION public.handle_post_comment_count()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF (TG_OP = 'INSERT') THEN
        IF (NEW.is_hidden = FALSE) THEN
            UPDATE public.posts
            SET comments_count = comments_count + 1
            WHERE id = NEW.post_id;
        END IF;
        RETURN NEW;
    ELSIF (TG_OP = 'DELETE') THEN
        IF (OLD.is_hidden = FALSE) THEN
            UPDATE public.posts
            SET comments_count = GREATEST(comments_count - 1, 0)
            WHERE id = OLD.post_id;
        END IF;
        RETURN OLD;
    ELSIF (TG_OP = 'UPDATE') THEN
        IF (OLD.is_hidden = FALSE AND NEW.is_hidden = TRUE) THEN
            UPDATE public.posts
            SET comments_count = GREATEST(comments_count - 1, 0)
            WHERE id = NEW.post_id;
        ELSIF (OLD.is_hidden = TRUE AND NEW.is_hidden = FALSE) THEN
            UPDATE public.posts
            SET comments_count = comments_count + 1
            WHERE id = NEW.post_id;
        END IF;
        RETURN NEW;
    END IF;
    RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_post_comments_count ON public.post_comments;
CREATE TRIGGER trg_post_comments_count
    AFTER INSERT OR DELETE OR UPDATE OF is_hidden ON public.post_comments
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_post_comment_count();

-- Indexes for Search, Filters, Sorting & Pagination
CREATE INDEX IF NOT EXISTS idx_posts_tags_gin ON public.posts USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_posts_type_published ON public.posts(type) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_posts_published_date ON public.posts(published_at DESC) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_posts_likes_sort ON public.posts(likes_count DESC, published_at DESC) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_posts_comments_sort ON public.posts(comments_count DESC, published_at DESC) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_posts_full_search_gin ON public.posts USING gin(to_tsvector('english', title || ' ' || body || ' ' || array_to_string(tags, ' ')));

-- RLS
ALTER TABLE public.blog_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blog_tags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Categories readable by all" ON public.blog_categories;
CREATE POLICY "Categories readable by all"
    ON public.blog_categories FOR SELECT
    TO authenticated, anon
    USING (TRUE);

DROP POLICY IF EXISTS "Admin manage categories" ON public.blog_categories;
CREATE POLICY "Admin manage categories"
    ON public.blog_categories FOR ALL
    TO authenticated
    USING (public.has_permission('blog.edit_any'))
    WITH CHECK (public.has_permission('blog.edit_any'));

DROP POLICY IF EXISTS "Tags readable by all" ON public.blog_tags;
CREATE POLICY "Tags readable by all"
    ON public.blog_tags FOR SELECT
    TO authenticated, anon
    USING (TRUE);

DROP POLICY IF EXISTS "Create tags requires blog.create" ON public.blog_tags;
CREATE POLICY "Create tags requires blog.create"
    ON public.blog_tags FOR INSERT
    TO authenticated
    WITH CHECK (public.has_permission('blog.create'));

DROP POLICY IF EXISTS "Admin manage tags" ON public.blog_tags;
CREATE POLICY "Admin manage tags"
    ON public.blog_tags FOR UPDATE
    TO authenticated
    USING (public.has_permission('blog.edit_any'))
    WITH CHECK (public.has_permission('blog.edit_any'));

DROP POLICY IF EXISTS "Admin delete tags" ON public.blog_tags;
CREATE POLICY "Admin delete tags"
    ON public.blog_tags FOR DELETE
    TO authenticated
    USING (public.has_permission('blog.edit_any'));

DROP POLICY IF EXISTS "Published posts are readable by all authenticated" ON public.posts;
DROP POLICY IF EXISTS "Published posts readable publicly" ON public.posts;
CREATE POLICY "Published posts readable publicly"
    ON public.posts FOR SELECT
    TO authenticated, anon
    USING (
        status = 'published'
        OR (
            auth.uid() IS NOT NULL
            AND (author_id = auth.uid() OR public.has_permission('blog.edit_any'))
        )
    );

-- Stored Procedures for Category & Tag Management
CREATE OR REPLACE FUNCTION public.merge_blog_categories(p_source_slug TEXT, p_target_slug TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied. blog.edit_any required.';
    END IF;
    IF p_source_slug = p_target_slug THEN
        RAISE EXCEPTION 'Source and target categories cannot be the same.';
    END IF;
    UPDATE public.posts SET category = p_target_slug, updated_at = NOW() WHERE category = p_source_slug;
    DELETE FROM public.blog_categories WHERE slug = p_source_slug;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_blog_category(p_slug_to_delete TEXT, p_fallback_slug TEXT DEFAULT 'news')
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied. blog.edit_any required.';
    END IF;
    UPDATE public.posts SET category = p_fallback_slug, updated_at = NOW() WHERE category = p_slug_to_delete;
    DELETE FROM public.blog_categories WHERE slug = p_slug_to_delete;
END;
$$;

CREATE OR REPLACE FUNCTION public.merge_blog_tags(p_source_name TEXT, p_target_name TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    src TEXT := lower(trim(p_source_name));
    tgt TEXT := lower(trim(p_target_name));
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied. blog.edit_any required.';
    END IF;
    IF src = tgt THEN
        RAISE EXCEPTION 'Source and target tags cannot be identical.';
    END IF;
    UPDATE public.posts
    SET tags = ARRAY(SELECT DISTINCT t FROM unnest(array_replace(tags, src, tgt)) AS t),
        updated_at = NOW()
    WHERE src = ANY(tags);
    DELETE FROM public.blog_tags WHERE lower(name) = src OR slug = src;
END;
$$;

CREATE OR REPLACE FUNCTION public.delete_blog_tag(p_tag_name TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    tag_cleaned TEXT := lower(trim(p_tag_name));
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied. blog.edit_any required.';
    END IF;
    UPDATE public.posts
    SET tags = array_remove(tags, tag_cleaned), updated_at = NOW()
    WHERE tag_cleaned = ANY(tags);
    DELETE FROM public.blog_tags WHERE lower(name) = tag_cleaned OR slug = tag_cleaned;
END;
$$;


-- ------------------------------------------------------------------------------
-- 11. Blog QA Hardening, Bookmarks, Moderation & Abuse Rate Limits (00010_blog_qa_hardening.sql)
-- ------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.post_bookmarks (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_post_bookmarks_user ON public.post_bookmarks(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_bookmarks_post ON public.post_bookmarks(post_id);

ALTER TABLE public.post_bookmarks ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own bookmarks" ON public.post_bookmarks;
CREATE POLICY "Users can view own bookmarks"
    ON public.post_bookmarks FOR SELECT
    TO authenticated
    USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can add bookmarks" ON public.post_bookmarks;
CREATE POLICY "Users can add bookmarks"
    ON public.post_bookmarks FOR INSERT
    TO authenticated
    WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own bookmarks" ON public.post_bookmarks;
CREATE POLICY "Users can delete own bookmarks"
    ON public.post_bookmarks FOR DELETE
    TO authenticated
    USING (user_id = auth.uid());

-- Extend Reports Table
ALTER TABLE public.reports
    ADD COLUMN IF NOT EXISTS post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS comment_id UUID REFERENCES public.post_comments(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_reports_post ON public.reports(post_id);
CREATE INDEX IF NOT EXISTS idx_reports_comment ON public.reports(comment_id);

-- Enforce Author Immutability
CREATE OR REPLACE FUNCTION public.check_post_author_immutable()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
    IF NEW.author_id <> OLD.author_id THEN
        RAISE EXCEPTION 'Security violation: author_id cannot be altered after creation.';
    END IF;
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_post_author_immutable ON public.posts;
CREATE TRIGGER trg_post_author_immutable
    BEFORE UPDATE ON public.posts
    FOR EACH ROW
    EXECUTE FUNCTION public.check_post_author_immutable();

-- Rate Limiting on Comments
CREATE OR REPLACE FUNCTION public.check_comment_rate_limit()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    last_comment_time TIMESTAMPTZ;
BEGIN
    SELECT created_at INTO last_comment_time
    FROM public.post_comments
    WHERE user_id = NEW.user_id
    ORDER BY created_at DESC
    LIMIT 1;

    IF last_comment_time IS NOT NULL AND (NOW() - last_comment_time) < INTERVAL '5 seconds' THEN
        RAISE EXCEPTION 'Rate limit exceeded: Please wait at least 5 seconds before posting another comment.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_comment_rate_limit ON public.post_comments;
CREATE TRIGGER trg_check_comment_rate_limit
    BEFORE INSERT ON public.post_comments
    FOR EACH ROW
    EXECUTE FUNCTION public.check_comment_rate_limit();

-- Rate Limiting on Reports
CREATE OR REPLACE FUNCTION public.check_report_rate_limit()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE
    recent_reports_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO recent_reports_count
    FROM public.reports
    WHERE reporter_id = NEW.reporter_id
      AND created_at > (NOW() - INTERVAL '1 hour');

    IF recent_reports_count >= 10 THEN
        RAISE EXCEPTION 'Rate limit exceeded: Maximum 10 reports allowed per hour.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_check_report_rate_limit ON public.reports;
CREATE TRIGGER trg_check_report_rate_limit
    BEFORE INSERT ON public.reports
    FOR EACH ROW
    EXECUTE FUNCTION public.check_report_rate_limit();


-- ------------------------------------------------------------------------------
-- 12. Blog Extras: Scheduling, Threaded Replies, Views & Moderation (00011_blog_extras.sql)
-- ------------------------------------------------------------------------------

ALTER TABLE public.posts DROP CONSTRAINT IF EXISTS posts_status_check;
ALTER TABLE public.posts ADD CONSTRAINT posts_status_check CHECK (status IN ('draft', 'published', 'archived', 'scheduled'));
ALTER TABLE public.posts ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ, ADD COLUMN IF NOT EXISTS views_count INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_posts_scheduled ON public.posts(scheduled_for ASC) WHERE status = 'scheduled';
CREATE INDEX IF NOT EXISTS idx_posts_views ON public.posts(views_count DESC);

CREATE OR REPLACE FUNCTION public.publish_due_scheduled_posts()
RETURNS INTEGER LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_updated INTEGER := 0;
BEGIN
    UPDATE public.posts
    SET status = 'published', published_at = NOW(), updated_at = NOW()
    WHERE status = 'scheduled' AND scheduled_for IS NOT NULL AND scheduled_for <= NOW();
    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$;

ALTER TABLE public.post_comments ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.post_comments(id) ON DELETE CASCADE, ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();
CREATE INDEX IF NOT EXISTS idx_post_comments_parent ON public.post_comments(parent_id);

CREATE TABLE IF NOT EXISTS public.post_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    viewer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    session_hash TEXT NOT NULL,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_post_views_dedup ON public.post_views(post_id, session_hash, viewed_at DESC);
ALTER TABLE public.post_views ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Post views insertable" ON public.post_views;
CREATE POLICY "Post views insertable" ON public.post_views FOR INSERT TO authenticated, anon WITH CHECK (TRUE);

CREATE OR REPLACE FUNCTION public.record_post_view(p_post_id UUID, p_session_hash TEXT)
RETURNS BOOLEAN LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_author_id UUID; v_recent_view_exists BOOLEAN;
BEGIN
    SELECT author_id INTO v_author_id FROM public.posts WHERE id = p_post_id;
    IF v_author_id IS NULL THEN RETURN FALSE; END IF;
    IF auth.uid() IS NOT NULL AND auth.uid() = v_author_id THEN RETURN FALSE; END IF;
    SELECT EXISTS (
        SELECT 1 FROM public.post_views
        WHERE post_id = p_post_id AND (session_hash = p_session_hash OR (auth.uid() IS NOT NULL AND viewer_id = auth.uid()))
          AND viewed_at > (NOW() - INTERVAL '6 hours')
    ) INTO v_recent_view_exists;
    IF v_recent_view_exists THEN RETURN FALSE; END IF;
    INSERT INTO public.post_views (post_id, viewer_id, session_hash, viewed_at)
    VALUES (p_post_id, auth.uid(), p_session_hash, NOW());
    UPDATE public.posts SET views_count = views_count + 1 WHERE id = p_post_id;
    RETURN TRUE;
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_hide_comment(p_comment_id UUID, p_hide BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_post_id UUID;
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN RAISE EXCEPTION 'Access denied: requires blog.edit_any permission.'; END IF;
    SELECT post_id INTO v_post_id FROM public.post_comments WHERE id = p_comment_id;
    UPDATE public.post_comments SET is_hidden = p_hide WHERE id = p_comment_id;
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (auth.uid(), CASE WHEN p_hide THEN 'hide_comment' ELSE 'unhide_comment' END, 'post_comments', p_comment_id::TEXT, jsonb_build_object('post_id', v_post_id, 'is_hidden', p_hide));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_comment(p_comment_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_post_id UUID;
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN RAISE EXCEPTION 'Access denied: requires blog.edit_any permission.'; END IF;
    SELECT post_id INTO v_post_id FROM public.post_comments WHERE id = p_comment_id;
    DELETE FROM public.post_comments WHERE id = p_comment_id;
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (auth.uid(), 'delete_comment', 'post_comments', p_comment_id::TEXT, jsonb_build_object('post_id', v_post_id));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_delete_post(p_post_id UUID)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_title TEXT;
BEGIN
    IF NOT public.has_permission('blog.delete') THEN RAISE EXCEPTION 'Access denied: requires blog.delete permission.'; END IF;
    SELECT title INTO v_title FROM public.posts WHERE id = p_post_id;
    DELETE FROM public.posts WHERE id = p_post_id;
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (auth.uid(), 'delete_post', 'posts', p_post_id::TEXT, jsonb_build_object('title', v_title));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_set_publish_status(p_post_id UUID, p_publish BOOLEAN)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_title TEXT; v_new_status TEXT;
BEGIN
    IF NOT public.has_permission('blog.publish') THEN RAISE EXCEPTION 'Access denied: requires blog.publish permission.'; END IF;
    v_new_status := CASE WHEN p_publish THEN 'published' ELSE 'draft' END;
    UPDATE public.posts
    SET status = v_new_status, published_at = CASE WHEN p_publish THEN NOW() ELSE NULL END, updated_at = NOW()
    WHERE id = p_post_id RETURNING title INTO v_title;
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (auth.uid(), CASE WHEN p_publish THEN 'publish_post' ELSE 'unpublish_post' END, 'posts', p_post_id::TEXT, jsonb_build_object('title', v_title, 'status', v_new_status));
END;
$$;

CREATE OR REPLACE FUNCTION public.admin_action_report(p_report_id UUID, p_action TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER AS $$
DECLARE v_post_id UUID; v_comment_id UUID;
BEGIN
    IF NOT public.has_permission('reports.review') THEN RAISE EXCEPTION 'Access denied: requires reports.review permission.'; END IF;
    SELECT post_id, comment_id INTO v_post_id, v_comment_id FROM public.reports WHERE id = p_report_id;
    IF p_action = 'dismiss' THEN
        UPDATE public.reports SET status = 'dismissed', reviewed_by = auth.uid() WHERE id = p_report_id;
    ELSIF p_action = 'action_hide' THEN
        IF v_comment_id IS NOT NULL THEN UPDATE public.post_comments SET is_hidden = TRUE WHERE id = v_comment_id; END IF;
        UPDATE public.reports SET status = 'actioned', reviewed_by = auth.uid() WHERE id = p_report_id;
    ELSIF p_action = 'action_delete' THEN
        IF v_comment_id IS NOT NULL THEN DELETE FROM public.post_comments WHERE id = v_comment_id;
        ELSIF v_post_id IS NOT NULL THEN DELETE FROM public.posts WHERE id = v_post_id; END IF;
        UPDATE public.reports SET status = 'actioned', reviewed_by = auth.uid() WHERE id = p_report_id;
    END IF;
    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (auth.uid(), 'moderation_' || p_action, 'reports', p_report_id::TEXT, jsonb_build_object('action', p_action, 'post_id', v_post_id, 'comment_id', v_comment_id));
END;
$$;
