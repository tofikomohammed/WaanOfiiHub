-- ==============================================================================
-- 00005_contact_sync.sql
-- Privacy-Preserving Contact Matching (Salted Hash Lookup)
-- ==============================================================================

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
    -- Protection against enumeration: limit to max 1000 hashes per request
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
