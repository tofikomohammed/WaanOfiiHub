-- ==============================================================================
-- 00010_blog_qa_hardening.sql
-- Blog Phase B9: Quality Assurance, Security Hardening, Abuse Prevention, Bookmarks & Moderation
-- ==============================================================================

-- 1. Create Post Bookmarks Table
CREATE TABLE IF NOT EXISTS public.post_bookmarks (
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (user_id, post_id)
);

CREATE INDEX IF NOT EXISTS idx_post_bookmarks_user ON public.post_bookmarks(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_post_bookmarks_post ON public.post_bookmarks(post_id);

-- RLS for Post Bookmarks
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

-- 2. Extend Reports Table to Support Blog Posts & Comments Moderation
ALTER TABLE public.reports
    ADD COLUMN IF NOT EXISTS post_id UUID REFERENCES public.posts(id) ON DELETE CASCADE,
    ADD COLUMN IF NOT EXISTS comment_id UUID REFERENCES public.post_comments(id) ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_reports_post ON public.reports(post_id);
CREATE INDEX IF NOT EXISTS idx_reports_comment ON public.reports(comment_id);

-- 3. Security Hardening: Enforce Author Immutability on Post Updates
CREATE OR REPLACE FUNCTION public.check_post_author_immutable()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

-- 4. Abuse Prevention: Rate Limiting on Comments (Cooldown between comments)
CREATE OR REPLACE FUNCTION public.check_comment_rate_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

-- 5. Abuse Prevention: Rate Limiting on Moderation Reports
CREATE OR REPLACE FUNCTION public.check_report_rate_limit()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

-- 6. Verification helper for Blog Security
CREATE OR REPLACE FUNCTION public.verify_blog_security_invariants()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- Verify RLS is enabled on all blog tables
    IF EXISTS (
        SELECT 1 FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename IN ('posts', 'post_media', 'post_likes', 'post_comments', 'post_bookmarks', 'blog_categories', 'blog_tags')
          AND rowsecurity = FALSE
    ) THEN
        RAISE EXCEPTION 'Security check failed: RLS is disabled on one or more blog tables!';
    END IF;

    RETURN TRUE;
END;
$$;
