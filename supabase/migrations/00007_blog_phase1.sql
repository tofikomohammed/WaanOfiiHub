-- ==============================================================================
-- 00007_blog_phase1.sql
-- Blog Phase 1: Categories, Search, Enhanced RLS, Draft Management & Storage
-- ==============================================================================

-- 1. Add Category Column to Posts Table
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

-- 2. Full-Text Search Index on Posts
CREATE INDEX IF NOT EXISTS idx_posts_search_gin 
    ON public.posts USING gin(to_tsvector('english', title || ' ' || body));

-- 3. Hardened RLS Policies on Posts

-- SELECT Policy: Published posts viewable by all, drafts viewable by author or editors
DROP POLICY IF EXISTS "Published posts are readable by all authenticated" ON public.posts;
CREATE POLICY "Published posts are readable by all authenticated"
    ON public.posts FOR SELECT TO authenticated
    USING (
        status = 'published'
        OR author_id = auth.uid()
        OR public.has_permission('blog.edit_any')
    );

-- INSERT Policy: Requires blog.create and author_id = auth.uid()
DROP POLICY IF EXISTS "Create post requires blog.create" ON public.posts;
CREATE POLICY "Create post requires blog.create"
    ON public.posts FOR INSERT TO authenticated
    WITH CHECK (
        author_id = auth.uid()
        AND public.has_permission('blog.create')
    );

-- UPDATE Policy: Enforces that setting status to 'published' strictly requires 'blog.publish'
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

-- DELETE Policy: Authors can delete their own unpublished drafts; deleting published requires blog.delete
DROP POLICY IF EXISTS "Delete post requires blog.delete" ON public.posts;
CREATE POLICY "Delete post requires blog.delete or own draft"
    ON public.posts FOR DELETE TO authenticated
    USING (
        (author_id = auth.uid() AND status = 'draft')
        OR public.has_permission('blog.delete')
    );

-- 4. Storage Policies: Allow authors to manage their own files in blog-media
DROP POLICY IF EXISTS "Delete blog-media requires blog.delete" ON storage.objects;
CREATE POLICY "Delete blog-media requires blog.delete or own folder"
    ON storage.objects FOR DELETE TO authenticated
    USING (
        bucket_id = 'blog-media'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('blog.delete')
        )
    );
