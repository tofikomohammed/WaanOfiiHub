-- ==============================================================================
-- 00003_blog_module.sql
-- Blog Posts, Media, Likes, Comments, Storage & RLS
-- ==============================================================================

-- 1. Posts Table
CREATE TABLE IF NOT EXISTS public.posts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type TEXT NOT NULL CHECK (type IN ('text', 'image', 'audio')),
    title TEXT NOT NULL,
    body TEXT NOT NULL DEFAULT '',
    cover_url TEXT,
    status TEXT NOT NULL DEFAULT 'draft' CHECK (status IN ('draft', 'published', 'archived')),
    published_at TIMESTAMPTZ,
    is_pinned BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_posts_status_published ON public.posts(status, published_at DESC);
CREATE INDEX IF NOT EXISTS idx_posts_author ON public.posts(author_id);

-- 2. Post Media Gallery
CREATE TABLE IF NOT EXISTS public.post_media (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    kind TEXT NOT NULL CHECK (kind IN ('image', 'audio')),
    storage_path TEXT NOT NULL,
    mime TEXT NOT NULL,
    size_bytes BIGINT NOT NULL,
    duration_seconds INTEGER,
    sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX IF NOT EXISTS idx_post_media_post ON public.post_media(post_id, sort_order ASC);

-- 3. Post Likes
CREATE TABLE IF NOT EXISTS public.post_likes (
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (post_id, user_id)
);

-- 4. Post Comments
CREATE TABLE IF NOT EXISTS public.post_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    post_id UUID NOT NULL REFERENCES public.posts(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    body TEXT NOT NULL CHECK (length(trim(body)) > 0 AND length(body) <= 1000),
    is_hidden BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_post_comments_post ON public.post_comments(post_id, created_at ASC);

-- 5. Storage Bucket Configuration for Blog Media
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
    'blog-media',
    'blog-media',
    TRUE,
    20971520, -- 20 MB max file size
    ARRAY['image/jpeg', 'image/png', 'image/webp', 'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/x-m4a']
)
ON CONFLICT (id) DO UPDATE SET
    public = TRUE,
    file_size_limit = 20971520,
    allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp', 'audio/mpeg', 'audio/mp4', 'audio/aac', 'audio/ogg', 'audio/x-m4a'];

-- Storage RLS
CREATE POLICY "Public read blog-media"
    ON storage.objects FOR SELECT
    TO public
    USING (bucket_id = 'blog-media');

CREATE POLICY "Write blog-media requires blog.create"
    ON storage.objects FOR INSERT
    TO authenticated
    WITH CHECK (
        bucket_id = 'blog-media'
        AND public.has_permission('blog.create')
    );

CREATE POLICY "Delete blog-media requires blog.delete"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'blog-media'
        AND public.has_permission('blog.delete')
    );

-- 6. Table RLS Policies
ALTER TABLE public.posts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.post_comments ENABLE ROW LEVEL SECURITY;

-- Posts SELECT
CREATE POLICY "Published posts are readable by all authenticated"
    ON public.posts FOR SELECT TO authenticated
    USING (
        status = 'published'
        OR author_id = auth.uid()
        OR public.has_permission('blog.edit_any')
    );

-- Posts INSERT
CREATE POLICY "Create post requires blog.create"
    ON public.posts FOR INSERT TO authenticated
    WITH CHECK (
        author_id = auth.uid()
        AND public.has_permission('blog.create')
    );

-- Posts UPDATE
CREATE POLICY "Edit post requires permissions"
    ON public.posts FOR UPDATE TO authenticated
    USING (
        (author_id = auth.uid() AND public.has_permission('blog.edit_own'))
        OR public.has_permission('blog.edit_any')
    )
    WITH CHECK (
        (author_id = auth.uid() AND public.has_permission('blog.edit_own'))
        OR public.has_permission('blog.edit_any')
    );

-- Posts DELETE
CREATE POLICY "Delete post requires blog.delete"
    ON public.posts FOR DELETE TO authenticated
    USING (public.has_permission('blog.delete'));

-- Post Media RLS
CREATE POLICY "Post media viewable if post is viewable"
    ON public.post_media FOR SELECT TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_media.post_id
              AND (p.status = 'published' OR p.author_id = auth.uid() OR public.has_permission('blog.edit_any'))
        )
    );

CREATE POLICY "Insert post media requires blog.create"
    ON public.post_media FOR INSERT TO authenticated
    WITH CHECK (public.has_permission('blog.create'));

CREATE POLICY "Delete post media requires blog.delete or edit"
    ON public.post_media FOR DELETE TO authenticated
    USING (public.has_permission('blog.edit_any') OR public.has_permission('blog.delete'));

-- Likes RLS
CREATE POLICY "Likes are viewable by authenticated users"
    ON public.post_likes FOR SELECT TO authenticated
    USING (TRUE);

CREATE POLICY "Users can like posts"
    ON public.post_likes FOR INSERT TO authenticated
    WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can unlike posts"
    ON public.post_likes FOR DELETE TO authenticated
    USING (user_id = auth.uid());

-- Comments RLS
CREATE POLICY "Comments are viewable if not hidden"
    ON public.post_comments FOR SELECT TO authenticated
    USING (
        is_hidden = FALSE
        OR user_id = auth.uid()
        OR public.has_permission('blog.edit_any')
    );

CREATE POLICY "Users can comment on published posts"
    ON public.post_comments FOR INSERT TO authenticated
    WITH CHECK (
        user_id = auth.uid()
        AND EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_id AND p.status = 'published'
        )
    );

CREATE POLICY "Users can delete own comment or moderator can delete"
    ON public.post_comments FOR DELETE TO authenticated
    USING (
        user_id = auth.uid()
        OR public.has_permission('blog.edit_any')
    );

CREATE POLICY "Moderators can hide comments"
    ON public.post_comments FOR UPDATE TO authenticated
    USING (public.has_permission('blog.edit_any'))
    WITH CHECK (public.has_permission('blog.edit_any'));
