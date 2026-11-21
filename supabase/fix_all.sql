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
