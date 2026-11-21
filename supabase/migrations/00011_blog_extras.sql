-- ==============================================================================
-- 00011_blog_extras.sql
-- Blog Extras: Scheduled Publishing, Threaded Replies, View Counts & Moderation Audit Logs
-- ==============================================================================

-- 1. Scheduled Publishing & View Counts on public.posts
ALTER TABLE public.posts
    DROP CONSTRAINT IF EXISTS posts_status_check;

ALTER TABLE public.posts
    ADD CONSTRAINT posts_status_check
    CHECK (status IN ('draft', 'published', 'archived', 'scheduled'));

ALTER TABLE public.posts
    ADD COLUMN IF NOT EXISTS scheduled_for TIMESTAMPTZ,
    ADD COLUMN IF NOT EXISTS views_count INTEGER NOT NULL DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_posts_scheduled 
    ON public.posts(scheduled_for ASC) 
    WHERE status = 'scheduled';

CREATE INDEX IF NOT EXISTS idx_posts_views 
    ON public.posts(views_count DESC);

-- Scheduled Publishing Worker Function
CREATE OR REPLACE FUNCTION public.publish_due_scheduled_posts()
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated INTEGER := 0;
BEGIN
    UPDATE public.posts
    SET status = 'published',
        published_at = NOW(),
        updated_at = NOW()
    WHERE status = 'scheduled'
      AND scheduled_for IS NOT NULL
      AND scheduled_for <= NOW();

    GET DIAGNOSTICS v_updated = ROW_COUNT;
    RETURN v_updated;
END;
$$;

-- Schedule automatic publishing via pg_cron every minute if extension is installed
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule(
            'job_publish_scheduled_blog_posts',
            '* * * * *',
            'SELECT public.publish_due_scheduled_posts();'
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    NULL;
END $$;

-- 2. Threaded Comments Support on public.post_comments
ALTER TABLE public.post_comments
    ADD COLUMN IF NOT EXISTS parent_id UUID REFERENCES public.post_comments(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW();

CREATE INDEX IF NOT EXISTS idx_post_comments_parent 
    ON public.post_comments(parent_id);

-- Hardened RLS on post_comments: only authors can edit/delete, moderators can hide
DROP POLICY IF EXISTS "Comments are viewable if not hidden" ON public.post_comments;
CREATE POLICY "Comments are viewable if not hidden"
    ON public.post_comments FOR SELECT
    TO authenticated, anon
    USING (
        is_hidden = FALSE
        OR (
            auth.uid() IS NOT NULL
            AND (user_id = auth.uid() OR public.has_permission('blog.edit_any'))
        )
    );

DROP POLICY IF EXISTS "Users can edit own comment" ON public.post_comments;
CREATE POLICY "Users can edit own comment"
    ON public.post_comments FOR UPDATE
    TO authenticated
    USING (user_id = auth.uid() OR public.has_permission('blog.edit_any'))
    WITH CHECK (user_id = auth.uid() OR public.has_permission('blog.edit_any'));

-- 3. Reliable, Deduplicated View Counts
CREATE TABLE IF NOT EXISTS public.post_views (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    viewer_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    session_hash TEXT NOT NULL,
    viewed_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_post_views_dedup 
    ON public.post_views(post_id, session_hash, viewed_at DESC);

ALTER TABLE public.post_views ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Post views insertable" ON public.post_views;
CREATE POLICY "Post views insertable"
    ON public.post_views FOR INSERT
    TO authenticated, anon
    WITH CHECK (TRUE);

-- Atomic & Deduplicated View Recording Function (6 hour window, ignores author)
CREATE OR REPLACE FUNCTION public.record_post_view(
    p_post_id UUID,
    p_session_hash TEXT
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_author_id UUID;
    v_recent_view_exists BOOLEAN;
BEGIN
    -- 1. Fetch post author
    SELECT author_id INTO v_author_id
    FROM public.posts
    WHERE id = p_post_id;

    IF v_author_id IS NULL THEN
        RETURN FALSE;
    END IF;

    -- 2. Ignore author's own views
    IF auth.uid() IS NOT NULL AND auth.uid() = v_author_id THEN
        RETURN FALSE;
    END IF;

    -- 3. Check for existing view in the last 6 hours
    SELECT EXISTS (
        SELECT 1 FROM public.post_views
        WHERE post_id = p_post_id
          AND (
              session_hash = p_session_hash
              OR (auth.uid() IS NOT NULL AND viewer_id = auth.uid())
          )
          AND viewed_at > (NOW() - INTERVAL '6 hours')
    ) INTO v_recent_view_exists;

    IF v_recent_view_exists THEN
        RETURN FALSE; -- Already counted within window
    END IF;

    -- 4. Insert deduplicated view entry
    INSERT INTO public.post_views (post_id, viewer_id, session_hash, viewed_at)
    VALUES (p_post_id, auth.uid(), p_session_hash, NOW());

    -- 5. Atomically increment view count on post
    UPDATE public.posts
    SET views_count = views_count + 1
    WHERE id = p_post_id;

    RETURN TRUE;
END;
$$;

-- 4. Admin Audit Logging Stored Procedures for Blog Moderation

-- Hide / Unhide Comment with Audit Log
CREATE OR REPLACE FUNCTION public.admin_hide_comment(
    p_comment_id UUID,
    p_hide BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_post_id UUID;
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied: requires blog.edit_any permission.';
    END IF;

    SELECT post_id INTO v_post_id
    FROM public.post_comments
    WHERE id = p_comment_id;

    UPDATE public.post_comments
    SET is_hidden = p_hide
    WHERE id = p_comment_id;

    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
        auth.uid(),
        CASE WHEN p_hide THEN 'hide_comment' ELSE 'unhide_comment' END,
        'post_comments',
        p_comment_id::TEXT,
        jsonb_build_object('post_id', v_post_id, 'is_hidden', p_hide)
    );
END;
$$;

-- Delete Comment with Audit Log
CREATE OR REPLACE FUNCTION public.admin_delete_comment(
    p_comment_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_post_id UUID;
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied: requires blog.edit_any permission.';
    END IF;

    SELECT post_id INTO v_post_id
    FROM public.post_comments
    WHERE id = p_comment_id;

    DELETE FROM public.post_comments
    WHERE id = p_comment_id;

    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
        auth.uid(),
        'delete_comment',
        'post_comments',
        p_comment_id::TEXT,
        jsonb_build_object('post_id', v_post_id)
    );
END;
$$;

-- Delete Post with Audit Log
CREATE OR REPLACE FUNCTION public.admin_delete_post(
    p_post_id UUID
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_title TEXT;
BEGIN
    IF NOT public.has_permission('blog.delete') THEN
        RAISE EXCEPTION 'Access denied: requires blog.delete permission.';
    END IF;

    SELECT title INTO v_title
    FROM public.posts
    WHERE id = p_post_id;

    DELETE FROM public.posts
    WHERE id = p_post_id;

    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
        auth.uid(),
        'delete_post',
        'posts',
        p_post_id::TEXT,
        jsonb_build_object('title', v_title)
    );
END;
$$;

-- Publish / Unpublish Post with Audit Log
CREATE OR REPLACE FUNCTION public.admin_set_publish_status(
    p_post_id UUID,
    p_publish BOOLEAN
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_title TEXT;
    v_new_status TEXT;
BEGIN
    IF NOT public.has_permission('blog.publish') THEN
        RAISE EXCEPTION 'Access denied: requires blog.publish permission.';
    END IF;

    v_new_status := CASE WHEN p_publish THEN 'published' ELSE 'draft' END;

    UPDATE public.posts
    SET status = v_new_status,
        published_at = CASE WHEN p_publish THEN NOW() ELSE NULL END,
        updated_at = NOW()
    WHERE id = p_post_id
    RETURNING title INTO v_title;

    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
        auth.uid(),
        CASE WHEN p_publish THEN 'publish_post' ELSE 'unpublish_post' END,
        'posts',
        p_post_id::TEXT,
        jsonb_build_object('title', v_title, 'status', v_new_status)
    );
END;
$$;

-- Action Moderation Report with Audit Log
CREATE OR REPLACE FUNCTION public.admin_action_report(
    p_report_id UUID,
    p_action TEXT -- 'dismiss', 'action_hide', 'action_delete'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_post_id UUID;
    v_comment_id UUID;
BEGIN
    IF NOT public.has_permission('reports.review') THEN
        RAISE EXCEPTION 'Access denied: requires reports.review permission.';
    END IF;

    SELECT post_id, comment_id INTO v_post_id, v_comment_id
    FROM public.reports
    WHERE id = p_report_id;

    IF p_action = 'dismiss' THEN
        UPDATE public.reports
        SET status = 'dismissed', reviewed_by = auth.uid()
        WHERE id = p_report_id;

    ELSIF p_action = 'action_hide' THEN
        IF v_comment_id IS NOT NULL THEN
            UPDATE public.post_comments SET is_hidden = TRUE WHERE id = v_comment_id;
        END IF;
        UPDATE public.reports
        SET status = 'actioned', reviewed_by = auth.uid()
        WHERE id = p_report_id;

    ELSIF p_action = 'action_delete' THEN
        IF v_comment_id IS NOT NULL THEN
            DELETE FROM public.post_comments WHERE id = v_comment_id;
        ELSIF v_post_id IS NOT NULL THEN
            DELETE FROM public.posts WHERE id = v_post_id;
        END IF;
        UPDATE public.reports
        SET status = 'actioned', reviewed_by = auth.uid()
        WHERE id = p_report_id;
    END IF;

    INSERT INTO public.audit_logs (actor_id, action, target_type, target_id, metadata)
    VALUES (
        auth.uid(),
        'moderation_' || p_action,
        'reports',
        p_report_id::TEXT,
        jsonb_build_object('action', p_action, 'post_id', v_post_id, 'comment_id', v_comment_id)
    );
END;
$$;
