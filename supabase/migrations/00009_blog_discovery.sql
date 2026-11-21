-- ==============================================================================
-- 00009_blog_discovery.sql
-- Blog Phase B7: Discovery, Search, Taxonomies, Filters, Sorting & Pagination
-- ==============================================================================

-- 1. Create Categories Table
CREATE TABLE IF NOT EXISTS public.blog_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed initial core categories
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

-- 2. Create Tags Table
CREATE TABLE IF NOT EXISTS public.blog_tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL UNIQUE,
    slug TEXT NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Seed initial popular tags
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

-- 3. Enhance public.posts with tags, likes_count, and comments_count
ALTER TABLE public.posts
    ADD COLUMN IF NOT EXISTS tags TEXT[] NOT NULL DEFAULT '{}',
    ADD COLUMN IF NOT EXISTS likes_count INTEGER NOT NULL DEFAULT 0,
    ADD COLUMN IF NOT EXISTS comments_count INTEGER NOT NULL DEFAULT 0;

-- Backfill counts from existing relations
UPDATE public.posts p
SET 
    likes_count = (SELECT COUNT(*) FROM public.post_likes pl WHERE pl.post_id = p.id),
    comments_count = (SELECT COUNT(*) FROM public.post_comments pc WHERE pc.post_id = p.id AND pc.is_hidden = FALSE);

-- 4. Triggers to maintain likes_count and comments_count automatically

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

-- 5. Comprehensive Indexes for Search, Filters, Sorting & Pagination (Requirement 9)
CREATE INDEX IF NOT EXISTS idx_posts_tags_gin ON public.posts USING gin(tags);
CREATE INDEX IF NOT EXISTS idx_posts_type_published ON public.posts(type) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_posts_published_date ON public.posts(published_at DESC) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_posts_likes_sort ON public.posts(likes_count DESC, published_at DESC) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_posts_comments_sort ON public.posts(comments_count DESC, published_at DESC) WHERE status = 'published';
CREATE INDEX IF NOT EXISTS idx_posts_full_search_gin ON public.posts USING gin(to_tsvector('english', title || ' ' || body || ' ' || array_to_string(tags, ' ')));

-- 6. Strict RLS on Categories, Tags and Posts (Requirement 8)
ALTER TABLE public.blog_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blog_tags ENABLE ROW LEVEL SECURITY;

-- Blog Categories RLS
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

-- Blog Tags RLS
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

-- Hardened Posts RLS: strictly only published posts accessible publicly
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

-- 7. Admin Stored Procedures for Category & Tag Management (Rename, Merge, Delete safely)

-- Category Merge Procedure
CREATE OR REPLACE FUNCTION public.merge_blog_categories(
    p_source_slug TEXT,
    p_target_slug TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied. blog.edit_any required.';
    END IF;

    IF p_source_slug = p_target_slug THEN
        RAISE EXCEPTION 'Source and target categories cannot be the same.';
    END IF;

    -- Update all posts from source category to target category
    UPDATE public.posts
    SET category = p_target_slug,
        updated_at = NOW()
    WHERE category = p_source_slug;

    -- Delete source category
    DELETE FROM public.blog_categories WHERE slug = p_source_slug;
END;
$$;

-- Category Safe Delete Procedure
CREATE OR REPLACE FUNCTION public.delete_blog_category(
    p_slug_to_delete TEXT,
    p_fallback_slug TEXT DEFAULT 'news'
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied. blog.edit_any required.';
    END IF;

    -- Reassign existing posts to fallback category
    UPDATE public.posts
    SET category = p_fallback_slug,
        updated_at = NOW()
    WHERE category = p_slug_to_delete;

    -- Delete the category
    DELETE FROM public.blog_categories WHERE slug = p_slug_to_delete;
END;
$$;

-- Tag Merge Procedure
CREATE OR REPLACE FUNCTION public.merge_blog_tags(
    p_source_name TEXT,
    p_target_name TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

    -- Replace source tag with target tag in posts array, eliminating duplicates
    UPDATE public.posts
    SET tags = ARRAY(
        SELECT DISTINCT t FROM unnest(array_replace(tags, src, tgt)) AS t
    ),
    updated_at = NOW()
    WHERE src = ANY(tags);

    -- Delete source tag
    DELETE FROM public.blog_tags WHERE lower(name) = src OR slug = src;
END;
$$;

-- Tag Safe Delete Procedure
CREATE OR REPLACE FUNCTION public.delete_blog_tag(
    p_tag_name TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    tag_cleaned TEXT := lower(trim(p_tag_name));
BEGIN
    IF NOT public.has_permission('blog.edit_any') THEN
        RAISE EXCEPTION 'Access denied. blog.edit_any required.';
    END IF;

    -- Remove tag from all posts
    UPDATE public.posts
    SET tags = array_remove(tags, tag_cleaned),
        updated_at = NOW()
    WHERE tag_cleaned = ANY(tags);

    -- Delete tag record
    DELETE FROM public.blog_tags WHERE lower(name) = tag_cleaned OR slug = tag_cleaned;
END;
$$;
