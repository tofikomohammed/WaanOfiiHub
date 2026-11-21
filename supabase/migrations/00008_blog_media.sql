-- ==============================================================================
-- 00008_blog_media.sql
-- Blog Phase B6: Media Uploads, Multi-Image Gallery, Audio & Storage Security
-- ==============================================================================

-- 1. Update Allowed MIME Types & Size for blog-media Bucket (Includes WAV, 25MB max)
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
    file_size_limit = 26214400 -- 25 MB max
WHERE id = 'blog-media';

-- 2. Enhanced RLS Helper for Blog Media Storage
CREATE OR REPLACE FUNCTION public.can_access_blog_media(object_name TEXT)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
SET search_path = ''
STABLE
AS $$
    SELECT (
        -- Admins can read all media
        public.has_permission('blog.edit_any')
        -- Post owner can read their own uploads even when unpublished
        OR (storage.foldername(object_name))[1] = auth.uid()::text
        -- Public / all users can read if media is attached to a published post
        OR EXISTS (
            SELECT 1 FROM public.post_media pm
            JOIN public.posts p ON pm.post_id = p.id
            WHERE pm.storage_path = object_name
              AND p.status = 'published'
        )
        -- Or post cover_url matches this storage path and post is published
        OR EXISTS (
            SELECT 1 FROM public.posts p
            WHERE (p.cover_url LIKE '%' || object_name OR p.cover_url = object_name)
              AND p.status = 'published'
        )
    );
$$;

-- 3. Storage Policies on storage.objects for blog-media
DROP POLICY IF EXISTS "Public read blog-media" ON storage.objects;
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

DROP POLICY IF EXISTS "Delete blog-media requires blog.delete or own folder" ON storage.objects;
CREATE POLICY "Delete blog-media requires blog.delete or own folder"
    ON storage.objects FOR DELETE
    TO authenticated
    USING (
        bucket_id = 'blog-media'
        AND (
            (storage.foldername(name))[1] = auth.uid()::text
            OR public.has_permission('blog.delete')
            OR public.has_permission('blog.edit_any')
        )
    );

-- 4. Enable RLS on post_media
ALTER TABLE public.post_media ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Post media viewable if post is viewable" ON public.post_media;
CREATE POLICY "Post media viewable if post is viewable"
    ON public.post_media FOR SELECT TO authenticated, anon
    USING (
        EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_media.post_id
              AND (
                  p.status = 'published' 
                  OR p.author_id = auth.uid() 
                  OR public.has_permission('blog.edit_any')
              )
        )
    );

DROP POLICY IF EXISTS "Insert post media requires blog.create" ON public.post_media;
CREATE POLICY "Insert post media requires blog.create"
    ON public.post_media FOR INSERT TO authenticated
    WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_media.post_id
              AND (p.author_id = auth.uid() OR public.has_permission('blog.edit_any'))
        )
        AND public.has_permission('blog.create')
    );

DROP POLICY IF EXISTS "Update post media requires author or editor" ON public.post_media;
CREATE POLICY "Update post media requires author or editor"
    ON public.post_media FOR UPDATE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_media.post_id
              AND (p.author_id = auth.uid() OR public.has_permission('blog.edit_any'))
        )
    );

DROP POLICY IF EXISTS "Delete post media requires blog.delete or edit" ON public.post_media;
CREATE POLICY "Delete post media requires author or editor"
    ON public.post_media FOR DELETE TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.posts p
            WHERE p.id = post_media.post_id
              AND (
                  p.author_id = auth.uid() 
                  OR public.has_permission('blog.delete') 
                  OR public.has_permission('blog.edit_any')
              )
        )
    );
