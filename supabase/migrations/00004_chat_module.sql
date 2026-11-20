-- ==============================================================================
-- 00004_chat_module.sql
-- Chat Conversations, Realtime Messages, Media, Receipts, Blocks & Reports
-- ==============================================================================

-- 1. Conversations Table
CREATE TABLE IF NOT EXISTS public.conversations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT NOT NULL CHECK (type IN ('direct', 'group', 'community')),
    title TEXT,
    avatar_url TEXT,
    description TEXT,
    created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    is_announcement_only BOOLEAN NOT NULL DEFAULT FALSE,
    is_open BOOLEAN NOT NULL DEFAULT TRUE,
    direct_user1 UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    direct_user2 UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    last_message_text TEXT,
    last_message_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT direct_pair_unique UNIQUE (direct_user1, direct_user2)
);

CREATE INDEX IF NOT EXISTS idx_conversations_type ON public.conversations(type);
CREATE INDEX IF NOT EXISTS idx_conversations_last_msg ON public.conversations(last_message_at DESC);

-- 2. Conversation Members
CREATE TABLE IF NOT EXISTS public.conversation_members (
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member' CHECK (role IN ('member', 'admin', 'owner')),
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    muted_until TIMESTAMPTZ,
    last_read_message_id UUID,
    last_read_at TIMESTAMPTZ,
    is_archived BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_members_user ON public.conversation_members(user_id);

-- 3. Messages Table
CREATE TABLE IF NOT EXISTS public.messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversation_id UUID NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
    sender_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL DEFAULT 'text' CHECK (type IN ('text', 'image', 'audio', 'system')),
    body TEXT NOT NULL DEFAULT '',
    media_path TEXT,
    media_mime TEXT,
    media_size BIGINT,
    media_duration_seconds INTEGER,
    reply_to_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    edited_at TIMESTAMPTZ,
    deleted_for_everyone BOOLEAN NOT NULL DEFAULT FALSE
);

CREATE INDEX IF NOT EXISTS idx_messages_conv_created ON public.messages(conversation_id, created_at DESC);

-- 4. Receipts & Deletions
CREATE TABLE IF NOT EXISTS public.message_receipts (
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    delivered_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    read_at TIMESTAMPTZ,
    PRIMARY KEY (message_id, user_id)
);

CREATE TABLE IF NOT EXISTS public.message_deletions (
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (message_id, user_id)
);

-- 5. Blocks & Reports
CREATE TABLE IF NOT EXISTS public.blocks (
    blocker_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    blocked_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (blocker_id, blocked_id)
);

CREATE TABLE IF NOT EXISTS public.reports (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    reported_user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    conversation_id UUID REFERENCES public.conversations(id) ON DELETE CASCADE,
    message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
    reason TEXT NOT NULL,
    details TEXT,
    status TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'reviewed', 'dismissed', 'actioned')),
    reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_reports_status ON public.reports(status, created_at DESC);

-- 6. Private Storage Bucket for Chat Media
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'chat-media',
    'chat-media',
    FALSE,
    15728640, -- 15 MB
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'audio/aac', 'audio/ogg', 'audio/x-m4a', 'audio/mpeg']
)
ON CONFLICT (id) DO UPDATE SET
    public = FALSE,
    file_size_limit = 15728640;

DROP POLICY IF EXISTS "Chat media accessed by members" ON storage.objects;
CREATE POLICY "Chat media accessed by members"
    ON storage.objects FOR SELECT
    TO authenticated
    USING (bucket_id = 'chat-media');

DROP POLICY IF EXISTS "Chat media uploaded by authenticated users" ON storage.objects;
CREATE POLICY "Chat media uploaded by authenticated users"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (bucket_id = 'chat-media');

-- 7. RLS Policies
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_receipts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_deletions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;

-- Helper function with SECURITY DEFINER to eliminate infinite recursion in RLS policies
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

-- Conversations RLS
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

-- Members RLS
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

-- Messages RLS
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

-- Receipts & Deletions RLS
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

-- Blocks RLS
DROP POLICY IF EXISTS "Users can manage own blocks" ON public.blocks;
CREATE POLICY "Users can manage own blocks"
    ON public.blocks FOR ALL TO authenticated
    USING (blocker_id = auth.uid())
    WITH CHECK (blocker_id = auth.uid());

-- Reports RLS
DROP POLICY IF EXISTS "Users can create reports" ON public.reports;
CREATE POLICY "Users can create reports"
    ON public.reports FOR INSERT TO authenticated
    WITH CHECK (reporter_id = auth.uid());

DROP POLICY IF EXISTS "Moderators can view reports" ON public.reports;
CREATE POLICY "Moderators can view reports"
    ON public.reports FOR SELECT TO authenticated
    USING (reporter_id = auth.uid() OR public.has_permission('reports.review'));

DROP POLICY IF EXISTS "Moderators can update reports" ON public.reports;
CREATE POLICY "Moderators can update reports"
    ON public.reports FOR UPDATE TO authenticated
    USING (public.has_permission('reports.review'))
    WITH CHECK (public.has_permission('reports.review'));

-- 8. Stored Procedures & Chat RPCs
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
        (new_id, u2, 'member');

    RETURN new_id;
END;
$$;

-- Message sending with rate-limit and conversation last message update
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
    recent_count INTEGER;
BEGIN
    -- Rate limit: max 60 messages per minute per user
    SELECT COUNT(*) INTO recent_count
    FROM public.messages
    WHERE sender_id = auth.uid()
      AND created_at > NOW() - INTERVAL '1 minute';

    IF recent_count >= 60 THEN
        RAISE EXCEPTION 'Rate limit reached. Please wait before sending more messages.';
    END IF;

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

-- Edit message (within 15 minutes, text only, sender only)
CREATE OR REPLACE FUNCTION public.edit_chat_message(msg_id UUID, new_text TEXT)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.messages
    SET body = new_text, edited_at = NOW()
    WHERE id = msg_id
      AND sender_id = auth.uid()
      AND type = 'text'
      AND created_at > NOW() - INTERVAL '15 minutes';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Message cannot be edited (time limit exceeded or unauthorized).';
    END IF;
END;
$$;

-- Delete for everyone (within 1 hour, sender only)
CREATE OR REPLACE FUNCTION public.delete_chat_message_for_everyone(msg_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    UPDATE public.messages
    SET 
        deleted_for_everyone = TRUE,
        body = 'This message was deleted.',
        media_path = NULL
    WHERE id = msg_id
      AND sender_id = auth.uid()
      AND created_at > NOW() - INTERVAL '1 hour';

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Message cannot be deleted for everyone (time limit exceeded or unauthorized).';
    END IF;
END;
$$;
